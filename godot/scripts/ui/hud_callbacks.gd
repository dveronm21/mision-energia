class_name HudCallbacks
extends RefCounted
## Callbacks que el HUD dispara hacia quien lo usa (equivale a `HudCallbacks` de `Hud.ts`).
## Todas opcionales salvo `on_use_booster`/`on_toggle_load` (si no se usan, no pasa nada raro:
## el HUD solo llama si `is_valid()`).

## Callable() -> void.
var on_action: Callable = Callable()
## Callable() -> void.
var on_inspect: Callable = Callable()
## Callable() -> void.
var on_meter: Callable = Callable()
## Callable() -> void.
var on_pause: Callable = Callable()
## Callable(v: Vector2) -> void.
var on_joystick: Callable = Callable()
## Callable(booster_id: String) -> void.
var on_use_booster: Callable = Callable()
## Callable(label: String, on: bool) -> void.
var on_toggle_load: Callable = Callable()
## Callable() -> void.
var on_inspect_close: Callable = Callable()
