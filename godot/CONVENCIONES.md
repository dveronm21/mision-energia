# Misión Energía en Godot 4.7: convenciones del proyecto

Esta es la versión 1.0 del juego, que reemplaza a la versión web de `app/` (TypeScript + three.js). La versión web queda como **referencia funcional**: hay que portar su comportamiento, sus números y su balance, no inventarlos de nuevo.

## Motor y plataformas
- Godot **4.7.2**, renderer **GL Compatibility** (OpenGL ES 3 / WebGL2): es el que más TVs Android, boxes y tablets soporta.
- Destinos:
  - APK teléfono/tablet: táctil, 1 jugador.
  - APK **Android TV**: control remoto de TV y hasta **2 jugadores** con tablets por Wi-Fi.
  - La app "Control" para tablets sigue siendo la WebView Java de `android/control/`.
- Pantalla horizontal, con base de diseño 1280×720, `stretch canvas_items` y `expand`.

## Código
- **GDScript con tipado estático en todo**: variables, parámetros, retornos y `Array[T]`. Cada clase con `class_name`.
- POO: una clase por archivo, responsabilidades chicas, dependencias por constructor (`_init`) o por `setup()`.
  - Nodos solo donde haga falta escena o ciclo de vida.
  - La lógica de dominio (sim, niveles, economía) en clases `RefCounted` puras, sin nodos, testeables en headless.
- Señales para eventos; nada de `get_node` con rutas frágiles entre sistemas.
- Autoloads (los agrega quien integra; documentá si proponés alguno): `Services` (composición de servicios) y `Bus` (señales globales).
- Archivos en `snake_case.gd`, clases en `PascalCase`, constantes en `UPPER_CASE`.
- Comentarios y textos al jugador en **español rioplatense** ("tocá", "instalá").

## Carpetas
```
scripts/core      guardado (user://), bus de eventos, audio sintetizado, ajustes
scripts/sim       simulador energético, clima (Zonda/nubes), impacto de tormenta, puntaje
scripts/levels    definiciones de los 5 niveles, catálogo, progreso
scripts/economy   Soles (billetera), inventario, catálogo, tienda, pagos (demo/stub), control parental, recompensas, boosters
scripts/remote    servidor HTTP+WebSocket+UDP, host de jugadores remotos, codificador QR, lobby
scripts/world     mundo 3D, jugador(es), cámara, interacción, entidades
scripts/ui        HUD y pantallas
scripts/app       composición y navegación
scenes/           escenas .tscn
assets/models     .glb exportados de los modelos procedurales de la versión web
assets/fonts      Fredoka / Nunito (woff2)
controller/       página web de control (copiada de app/dist/controller), la sirve el tele por HTTP
tests/            tests headless: godot --headless --path . -s res://tests/run_tests.gd
tools/            scripts de desarrollo (capturas, exportación de modelos)
```

## Pruebas y capturas (en este contenedor)
- Godot Linux: `godot` (4.7.2). Importar: `godot --headless --path godot --import`.
- Tests: `godot --headless --path godot -s res://tests/run_tests.gd`. Tiene que terminar con código 0.
- Capturas con render real (llvmpipe):
  `xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --rendering-driver opengl3 <escena o -s script>`
  y guardar con `get_viewport().get_texture().get_image().save_png(...)`. Mirá cada PNG con la herramienta Read.
- Sin red, salvo npm.

## Referencia web (leer el código, no adivinar)
`app/src/contracts.ts`, `app/src/sim`, `app/src/levels`, `app/src/economy`, `app/src/core`, `app/src/world`, `app/src/world/assets` (gráficos), `app/src/ui`, `app/src/remote` (+ `protocol.ts`), `app/src/controller`, `docs/REMOTE_PROTOCOL.md`.
