class_name SettingsDeps
extends RefCounted
## Dependencias de la pantalla de ajustes (equivale a `SettingsDeps` de `SettingsScreen.ts`).

const QUALITY_LOW: StringName = &"low"
const QUALITY_MEDIUM: StringName = &"medium"
const QUALITY_HIGH: StringName = &"high"

## "low" | "medium" | "high".
var quality: StringName = QUALITY_MEDIUM
## Velocidad del reloj (`GameSpeed.OPTIONS`).
var speed: int = 1
## Callable(v: int) -> void.
var on_speed_change: Callable
## Tamaño de la interfaz (`UiScale.SMALL` | `NORMAL` | `LARGE`).
var ui_size: StringName = UiScale.NORMAL
## Callable(v: StringName) -> void.
var on_ui_size_change: Callable
## null = sin control de sonido.
var audio: AudioSynth
var version: String = ""
## Callable(q: StringName) -> void.
var on_quality_change: Callable
## Callable() -> void.
var on_reset_progress: Callable
## Callable() -> void.
var on_back: Callable
