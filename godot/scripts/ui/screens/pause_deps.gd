class_name PauseDeps
extends RefCounted
## Dependencias del menú de pausa (equivale a `PauseDeps` de `PauseMenu.ts`).

## null = sin botón de sonido.
var audio: AudioSynth
var level_name: String = ""
## Callable() -> void, cada uno.
var on_resume: Callable
var on_restart: Callable
var on_exit_to_map: Callable
