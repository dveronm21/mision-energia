class_name ResultDeps
extends RefCounted
## Dependencias de la pantalla de resultado (equivale a `ResultDeps` de `ResultScreen.ts`).

var result: LevelResult
var level_name: String = ""
## Soles acreditados por estrellas nuevas.
var soles_earned: int = 0
## "" si no se desbloqueó nada.
var unlocked_name: String = ""
var has_next: bool = false
## -1 = sin récord previo.
var best_score: int = -1
## null = estrellas sin sonido.
var audio: AudioSynth
## Callable() -> void, cada uno.
var on_retry: Callable
var on_next: Callable
var on_map: Callable
