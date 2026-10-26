class_name PauseDeps
extends RefCounted
## Dependencias del menú de pausa (equivale a `PauseDeps` de `PauseMenu.ts`).

## null = sin botón de sonido.
var audio: AudioSynth
var level_name: String = ""
## Velocidad del reloj (`GameSpeed.OPTIONS`); `on_speed_change` vacío = sin botón.
var speed: int = 1
## Callable(v: int) -> void.
var on_speed_change: Callable
## Callable() -> void, cada uno.
var on_resume: Callable
var on_restart: Callable
var on_exit_to_map: Callable
