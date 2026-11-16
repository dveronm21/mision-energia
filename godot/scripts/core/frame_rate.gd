class_name FrameRate
extends RefCounted
## Tope de cuadros por segundo que elige el jugador (Ajustes): "Auto" dibuja al ritmo de la
## pantalla (120 en un teléfono de 120 Hz); "60" se ve igual de fluido y gasta menos batería
## y calienta menos el teléfono en partidas largas.

const KEY: String = "settings.fps"
const AUTO: StringName = &"auto"
const FPS_60: StringName = &"60"
const OPTIONS: Array[StringName] = [AUTO, FPS_60]


## Lee el tope guardado; cualquier valor raro vuelve a "Auto".
static func load_from(store: SaveStore) -> StringName:
	var v: StringName = StringName(str(store.load_value(KEY, String(AUTO))))
	return v if OPTIONS.has(v) else AUTO


static func save_to(store: SaveStore, v: StringName) -> void:
	store.save_value(KEY, String(v if OPTIONS.has(v) else AUTO))


## `Engine.max_fps`: 0 = sin tope (lo marca la sincronización con la pantalla).
static func max_fps(v: StringName) -> int:
	return 60 if v == FPS_60 else 0


static func apply(v: StringName) -> void:
	Engine.max_fps = max_fps(v)


static func label(v: StringName) -> String:
	return "60" if v == FPS_60 else "Auto"
