# Modo TV: servidor remoto en GDScript — pruebas, página de control y exportación

Código: `scripts/remote/` (servidor, host, QR, lobby). Protocolo: `docs/REMOTE_PROTOCOL.md` y
`app/src/remote/protocol.ts` (fuente de verdad). Este servidor reemplaza al Java de `android/remote-core/`
con el mismo comportamiento hacia las tablets.

## Página de control (`godot/controller/`)

Es la copia de `app/dist/controller/` (index.html, controller.js, fonts/*.woff2). El tele la sirve por HTTP
desde `res://controller/`. Para actualizarla después de tocar `app/src/controller`:

```bash
./godot/tools/remote_test/update_controller.sh
```

El script corre `npm run build` en `app/`, copia `dist/controller/` y escribe para cada `.woff2` un
`.import` con `importer="keep"`. Eso último es necesario: si Godot importa las fuentes como `FontFile`,
el export guarda solo el `.fontdata` convertido y el navegador recibiría otra cosa. Con `keep` se
exportan tal cual (comprobado: firma `wOF2` dentro del PCK).

## Exportación (Android TV)

En el preset de exportación (`export_presets.cfg`, lo arma el integrador):

| Opción | Valor |
|---|---|
| `include_filter` | `controller/*` (los `.html`/`.js` no son recursos: sin el filtro no entran; verificado) |
| `permissions/internet` | `true` (servidor TCP/UDP) |
| `permissions/access_network_state` | `true` |
| `permissions/access_wifi_state` | `true` |
| `permissions/change_wifi_multicast_state` | `true` (MulticastLock para recibir el broadcast del descubrimiento) |

Los archivos se leen con `FileAccess` directo desde `res://controller/` dentro del APK/PCK: no hace falta
copiarlos a `user://`. Si alguna vez se quisiera servir otra carpeta, `RemoteServer.controller_root`
acepta `user://...`.

Verificación hecha con `--export-pack` (preset Linux, mismo mecanismo de PCK que el APK):

```bash
# en una copia del proyecto con export_presets.cfg (include_filter="controller/*, tools/remote_test/export_check.gd")
godot --headless --path . --export-pack "Linux" /tmp/t.pck
godot --headless --main-pack /tmp/t.pck -s res://tools/remote_test/export_check.gd
```

**MulticastLock**: `AndroidMulticastLock` lo toma al arrancar el descubrimiento (singleton
`AndroidRuntime` + JavaObject; no probado en un equipo real en este contenedor). Si falla, el
descubrimiento sigue funcionando por unicast (la app Control pregunta al último tele), por QR y por
`/api/info`.

**Ciclo de vida**: `RemoteServer.pause_in_background = true` detiene el servidor con
`NOTIFICATION_APPLICATION_PAUSED` (close 1001 a las tablets) y lo vuelve a abrir al reanudar, como
`onStop`/`onStart` de la app Java.

## Pruebas

```bash
# Unitarias (host, validación, entrada, QR, parser HTTP, WS, rutas, IPs) — misma lista que app/tests/remote.test.ts
godot --headless --path godot -s res://tests/remote/run_remote_tests.gd

# QR decodificado por OpenCV
godot --headless --path godot -s res://tools/remote_test/qr_export.gd -- /tmp/qr && python3 godot/tools/remote_test/qr_check.py /tmp/qr

# Integración: Godot headless (scenes/remote/RemoteTestServer.tscn) + Node ws + UDP + Chromium
./godot/tools/remote_test/run.sh          # FPS=0 para medir sin tope de frames

# Capturas del lobby y prueba de D-pad (render real)
xvfb-run -a -s "-screen 0 1920x1080x24" godot --path godot --rendering-driver opengl3 --resolution 1920x1080 \
  -s res://tools/remote_test/lobby_capture.gd -- $PWD/godot/tools/remote_test/out 1080
```

## Por qué el WebSocket está hecho a mano

`WebSocketPeer.accept_stream()` hace su propio handshake leyendo un `StreamPeerTCP` "virgen". El
servidor necesita leer antes la cabecera HTTP (para enrutar `/`, `/api/info` y `/ws` en el mismo
puerto, y para controlar `Origin`), y en 4.7 `accept_stream` rechaza cualquier otro `StreamPeer`
(`StreamPeerExtension` → `ERR_INVALID_PARAMETER`), así que no hay forma de devolverle esos bytes.
`WsConnection` implementa RFC 6455 (handshake, máscara, fragmentación, ping/pong, close, 1002/1003/1007/1009)
sobre `StreamPeerTCP`, como la referencia Java.

## Latencia

El servidor atiende la red una vez por frame (`process_priority = -100`, antes del juego). La ida y
vuelta queda dominada por la cadencia de frames: a 60 fps, ≤1 frame. Godot headless además duerme
6,9 ms por iteración (modo de bajo consumo), por eso el eco sin tope ronda 7 ms en este contenedor.
