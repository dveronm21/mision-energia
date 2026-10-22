# Protocolo de control remoto (Misión Energía TV)

El juego corre en un Android TV / Google TV (app **Misión Energía TV**) y hasta **2 tablets** lo
controlan por la red Wi-Fi local, desde el navegador (escaneando el QR) o con la app
**Misión Energía Control** (tablets fijas de feria).

La fuente de verdad de tipos y constantes es `app/src/remote/protocol.ts`. Este documento la explica
y documenta lo que agrega el lado nativo (Java), siempre de forma compatible.

```
 Tablet (navegador o app Control)                 Tele (app Misión Energía TV)
 ┌──────────────────────────────┐   UDP 8766    ┌──────────────────────────────────────────┐
 │ Discovery (solo app Control) │ ─────────────▶│ DiscoveryResponder                       │
 │                              │ ◀───────────── │   responde DiscoveryReply (unicast)      │
 │ página de control (HTML/JS)  │   TCP 8765    │ RemoteServer                             │
 │   GET /         ─────────────┼──────────────▶│   HttpServer: assets/controller/*        │
 │   GET /ws (WebSocket) ◀──────┼──────────────▶│   WebSocketConnection ─▶ EventQueue      │
 └──────────────────────────────┘               │        ▲ send/close        │ poll()       │
                                                │   window.RemoteBridge (JavascriptInterface)│
                                                │        └──────── juego (RemoteHost.ts) ◀───┘
                                                └──────────────────────────────────────────┘
```

## 1. Transporte

| Qué | Valor |
|---|---|
| HTTP + WebSocket | TCP **8765** (`HTTP_PORT`). Si está ocupado, el tele prueba 8775 y 8785; la URL del QR y el `DiscoveryReply` llevan el puerto real. |
| Descubrimiento | UDP **8766** (`DISCOVERY_PORT`) |
| Consulta | el texto ASCII exacto `MISION-ENERGIA-DISCOVER-1` (`DISCOVERY_QUERY`) |
| Versión | `PROTOCOL_VERSION = 1` (va en `hello`, `welcome` y `DiscoveryReply`) |

### HTTP (tele)
- `GET /` → `controller/index.html`; `GET /x/y.js` → `controller/x/y.js`; `GET /carpeta/` → `carpeta/index.html`.
  Solo `GET` y `HEAD` (otro método → 405). Keep-alive de hasta 32 peticiones, 5 s de inactividad.
- MIME por extensión (html, js/mjs, css, json, svg, png, jpg, webp, ico, woff/woff2, ttf, mp3, ogg, wav, wasm…),
  `Cache-Control: no-store`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`.
- Nunca sale de la carpeta `controller/`: se decodifica `%xx` y se rechaza (400) `..`, `.`, archivos ocultos,
  `\`, NUL, `//`, `%` mal formado y caracteres fuera de `[A-Za-z0-9._~ -/]`. En escritorio, además,
  `DirectoryAssetSource` compara la ruta canónica (bloquea symlinks hacia afuera).
- Cabecera de la petición: máximo 8 KB (431 si se excede). Archivos: máximo 16 MB.
- **Extensión compatible** `GET /api/info` → el mismo JSON que `DiscoveryReply`, con
  `Access-Control-Allow-Origin: *`. Lo usan la conexión manual (si el UDP está bloqueado) y el vigilante de la app Control.

### WebSocket (RFC 6455) en `GET /ws`
- Handshake estándar (`Upgrade: websocket`, `Sec-WebSocket-Version: 13`, si no → 426; clave Base64 de 16 bytes, si no → 400).
- **Origen**: sin `Origin` (apps nativas) o con el mismo host que `Host` → aceptado. Otro origen http(s) → 403
  (evita que una web de Internet abierta en la tablet use el navegador para meterse al juego).
- Solo mensajes de **texto** UTF-8 (JSON). Binario → close 1003; UTF-8 inválido → 1007; frame sin máscara → 1002.
- Fragmentación soportada (continuaciones, control intercalado). Ping → pong con el mismo contenido.
- **Tamaño máximo de mensaje: 64 KB** (entrante → close 1009; saliente demasiado grande se descarta).
- `TCP_NODELAY` activado (sin Nagle: cada `input` sale en el momento).
- Máximo 8 WebSockets simultáneos (2 jugadores + margen para reconexiones y respuestas `full`); más → 503.
  Máximo 32 sockets TCP en total.
- El tele no bloquea nunca al JS: `send()` encola y un hilo escritor por conexión envía. Si la cola de un
  cliente supera 512 mensajes (cliente colgado), se lo cierra con 1008 "cliente lento".

## 2. Mensajes

Todos son JSON de texto. Tipos completos en `protocol.ts`.

**Tablet → tele (`ClientMsg`)**

| `t` | Campos | Cuándo |
|---|---|---|
| `hello` | `v`, `name`, `token?`, `device: 'browser'\|'app'` | al abrir el WebSocket; `token` para recuperar el asiento |
| `input` | `s: InputState {seq, x, y, held, taps{action,inspect,tool,pause}}` | al cambiar y cada `KEEPALIVE_MS` |
| `ping` | `at` (reloj de la tablet) | para medir latencia |
| `bye` | — | salida voluntaria |

**Tele → tablet (`ServerMsg`)**: `welcome {slot, token, color, colorName, tvName}`, `full {reason}`,
`ctx {c: ControllerContext}`, `haptic {pattern}`, `toast {text, kind}`, `pong {at}`, `kick {reason}`.

**Estado, no eventos.** Cada `input` lleva el estado completo (último gana, `seq` creciente). Los toques
usan contadores acumulativos (`taps`): si se pierde un mensaje, el siguiente igual trae el contador
nuevo y el tele detecta la pulsación. No hacen falta acks ni reenvíos.

**Puente Java ⇄ JS en el tele** (`window.RemoteBridge`, `NativeRemoteBridge`):

| Método | Java (`RemoteServer`) |
|---|---|
| `getControllerUrl()` | `http://<IP LAN>:<puerto>/` o `""` si no hay red **o el servidor todavía no arrancó** (el JS debe reintentar) |
| `getTvName()` | nombre del dispositivo (Ajustes › Acerca de) o el modelo |
| `poll()` | JSON `BridgeEvent[]`: `{e:'open',id,addr}`, `{e:'msg',id,data}`, `{e:'close',id}` |
| `send(id, json)` | encola un `ServerMsg` (máx. 64 KB) |
| `close(id, reason)` | close 1000 con ese motivo (≤123 bytes) |

Garantías de `poll()`: `open` siempre antes que los `msg` de esa conexión; un único `close` por cada `open`.
Si el JS deja de leer, se guardan hasta 4096 `msg` (después se descartan los nuevos; `open`/`close` nunca).
Al detener el servidor (la app del tele pasa a segundo plano) todas las conexiones reciben close 1001
y el JS recibe sus `close` en el siguiente `poll()`.

## 3. Descubrimiento

1. La app Control manda `MISION-ENERGIA-DISCOVER-1` por UDP a `255.255.255.255`, al broadcast de cada
   interfaz LAN (ej. `192.168.0.255`) y por **unicast al último tele usado** (funciona aunque el router
   filtre broadcast). Reenvía a los 0, 300 y 800 ms por si se pierde un paquete; escucha 1,5 s.
2. El tele responde por unicast al puerto de origen:
   `{"app":"mision-energia-tv","v":1,"name":"Sala","ip":"192.168.0.23","port":8765,"players":1,"max":2}`.
   `ip` es la de la interfaz por la que se llega a quien preguntó (no la primera que aparezca, ni datos móviles,
   ni IPv6, ni VPN). `players` = WebSockets abiertos (tope 2). Máximo 50 respuestas/s; cualquier otro contenido se ignora.
3. Ambas apps mantienen un `WifiManager.MulticastLock` mientras escuchan/buscan (muchos equipos descartan
   broadcast sin él).

Con el navegador no hay UDP: se escanea el QR del tele, que lleva la URL directa.

## 4. Tiempos

| Constante | Valor | Dónde |
|---|---|---|
| `KEEPALIVE_MS` | 100 ms | la tablet reenvía `input` aunque no cambie |
| `PLAYER_TIMEOUT_MS` | 3 s | sin mensajes → jugador "desconectado" (personaje quieto) |
| `RESUME_WINDOW_MS` | 60 s | asiento reservado para el mismo `token` |
| Ping WebSocket del tele | cada 5 s sin tráfico saliente | `WebSocketConnection.PING_INTERVAL_MS` |
| Lectura sin datos | 15 s → conexión muerta | `READ_TIMEOUT_MS` |
| Cierre ordenado | espera el close del cliente 1 s | `CLOSE_WAIT_MS` |
| Cabecera HTTP | 5 s | `HttpServer.HEAD_TIMEOUT_MS` |
| Vigilante de la app Control | `/api/info` cada 2 s; 2 fallas → vuelve a buscar | `ControlActivity` |
| Latencia medida (escritorio, loopback) | mediana ≈0,4 ms (Node) / 0,7 ms (Chromium) | `android/remote-test` |

## 5. Seguridad

- Solo red local: no hay nada en Internet, ni cuentas, ni datos personales (el `name` del jugador lo elige él y se muestra en el tele).
- Nada de lo que llega por la red se ejecuta: el tele solo **encola texto** para el JS del juego, que lo valida (`app/src/remote/validate.ts`).
  La única respuesta automática del lado Java es el `DiscoveryReply`.
- Todos los tamaños están acotados (cabecera 8 KB, mensaje 64 KB, cola 512, consulta UDP 64 B, 8 WS, 32 sockets).
- Sin path traversal; `Cache-Control: no-store`; Origin verificado en el WebSocket.
- El tráfico es HTTP/WS sin cifrar (`usesCleartextTraffic`): aceptable en una red de feria; no usar en una red con desconocidos si importa la privacidad de los nombres.
- La app Control solo navega a sus propios assets o al tele elegido (kiosco). Sus interfaces JS (`Discovery`, `Haptics`, `ControlApp`) quedan visibles para la página del tele; solo permiten buscar, vibrar (≤1 s) y volver a la búsqueda.

## 6. Diferencias con BombSquad Remote

| BombSquad Remote | Misión Energía |
|---|---|
| UDP 43210 propio, estados en buffer circular de 256 con reenvío de hasta 11 no confirmados y acks | WebSocket sobre TCP (orden y entrega garantizados) + estado completo y contadores de toques: sin acks propios |
| Descubrimiento por broadcast; si falla hay que escribir la IP | Broadcast **+ unicast al último tele + QR + conexión manual con verificación** (UDP o HTTP `/api/info`) |
| Cortes y "no reconecta" | Token de asiento (60 s), reconexión automática en la página, vigilante en la app que vuelve a buscar y se reconecta solo |
| Lag | `TCP_NODELAY`, mensajes chicos, latencia medida ≈1 ms en LAN local; el tele vacía la cola una vez por frame |
| El control no recibe nada del juego | Bidireccional: contexto del botón, objetivo, color, vibración, toasts, ping/pong |
| App obligatoria | También funciona desde cualquier navegador (QR) |

## 7. Solución de problemas de red

1. **Misma red**: la tablet y el tele tienen que estar en la **misma red Wi-Fi** (mismo SSID y misma subred,
   ej. ambos `192.168.0.x`). Una banda de 5 GHz y otra de 2,4 GHz del mismo router suelen ser la misma red.
2. **Aislamiento de clientes / red de invitados**: muchos routers (y casi todas las redes "Invitados" o de
   hoteles/ferias) impiden que los dispositivos se vean entre sí. Síntoma: no aparece ningún tele, el QR no
   abre y la conexión manual dice "No responde". Solución: desactivar *AP isolation / client isolation /
   aislamiento de clientes* en el router, o llevar un router propio para el stand (recomendado).
3. **Broadcast bloqueado pero unicast permitido**: la búsqueda falla pero **Conectar por dirección** funciona.
   La app recuerda ese tele y le pregunta por unicast en cada búsqueda.
4. **Firewall** (raro en Android, común si el "tele" es una PC de prueba): permitir TCP 8765 y UDP 8766 entrantes.
5. **Conectar a mano**: la dirección aparece en el tele debajo del QR (`http://IP:8765/`). En la app Control:
   *Conectar por dirección* → `192.168.0.23` (o `192.168.0.23:8775` si el tele usó otro puerto). Desde un navegador:
   abrir esa URL. Prueba rápida desde una PC en la misma red: `curl http://IP:8765/api/info`.
6. **Datos móviles / VPN** en la tablet: desactivarlos; el tele siempre informa su IP Wi-Fi/Ethernet.
7. **IP del tele cambió** (DHCP): la app Control lo reencuentra por nombre. En el router conviene reservar la IP del tele.
   Si cambia la IP, el navegador pierde el token (se guarda por origen) y el jugador vuelve a entrar como nuevo.
8. **Se cortó**: la página reintenta sola; si el tele no responde 2 veces seguidas (≈4 s) la app vuelve a la
   búsqueda y se reconecta con cuenta regresiva de 3 s (cancelable).

## 8. Apps Android

**Misión Energía TV** (`ar.com.inkfusion.misionenergia.tv`): WebView con `file:///android_asset/index.html?tv=1`,
`RemoteServer` sobre los assets `controller/` (de `app/dist/controller/`), `window.RemoteBridge`. El servidor
arranca en `onStart` y se detiene en `onStop` (en un hilo aparte). Teclas: flechas → WebView tal cual;
`DPAD_CENTER`/`A`/`NUMPAD_ENTER` → **Enter**; `MENU`/`START` → **Escape**; `BACK` (y `B`) → `window.meHandleBack()`.
Lanzador normal y LEANBACK con banner 320×180.

**Misión Energía Control** (`ar.com.inkfusion.misionenergia.control`): `assets/discovery.html` con
`window.Discovery` (`scan(ms)`, `probe(dir)`, `connect(tvJson)`, `getLast()`, `forget()`, `getLocalIp()`,
`getVersion()`; resultados por `window.onNativeEvent('scan'|'probe', datos)`). Al elegir un tele navega a
`http://IP:PUERTO/?app=1`. En esa página quedan `window.Haptics.vibrate(ms)` / `pattern("[..]")` (y un
`navigator.vibrate` de respaldo si falta) y `window.ControlApp.backToDiscovery()` / `getTv()`.
Kiosco liviano: inmersivo, pantalla encendida, BACK no sale. **Salida oculta**: mantener apretada la esquina
superior izquierda 5 s → PIN (por defecto **1234**) → menú de operador (buscar, olvidar tele, cambiar PIN, salir).

## 9. Compilar y probar

```bash
# APKs (misma firma para los tres)
KS=/ruta/keystore.jks KS_PASS=... ./android/build-variant.sh phone|tv|control
#   → android/build/MisionEnergia.apk, MisionEnergiaTV.apk, MisionEnergiaControl.apk

# Pruebas de escritorio del núcleo de red (JVM + Node ws + UDP + Chromium)
./android/remote-test/run-tests.sh
```

Código: `android/remote-core/src/ar/com/inkfusion/misionenergia/remote/` (Java 8 puro, sin Android):
`RemoteServer`, `HttpServer`, `HttpRequest`, `WebSocketConnection`, `DiscoveryResponder`, `DiscoveryClient`,
`ConnectionRegistry`, `EventQueue`, `NetUtils`, `AssetSource`, `DirectoryAssetSource`, `TvInfo`, `Json`,
`Base64Codec`, `Protocol`, `RemoteLog`.
