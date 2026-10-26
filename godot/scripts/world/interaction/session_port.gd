class_name SessionPort
extends RefCounted
## Lo que las estrategias de interacción pueden ver y pedir de la partida (equivale a
## `SessionPort` de `interaction/SessionPort.ts`). `GameSession` lo implementa de verdad;
## las reglas del juego viven ahí, no en las estrategias. Mismo patrón que `IPaymentProvider`:
## esta base son valores/no-ops por defecto, las subclases sobrescriben.

const PHASE_BUILD: StringName = &"build"
const PHASE_RUNNING: StringName = &"running"
const PHASE_FINISHED: StringName = &"finished"


func level() -> LevelDefinition:
	return null


func world() -> PlantWorld:
	return null


func hands() -> HandsController:
	return null


## "build" | "running" | "finished".
func phase() -> StringName:
	return PHASE_BUILD


## "calm" | "zonda-warning" | "zonda-storm" | "zonda-over" (ver `WeatherSchedule`).
func weather() -> String:
	return WeatherSchedule.CALM


func is_night() -> bool:
	return false


func toast(_text: String, _kind: StringName = &"info") -> void:
	pass


func sfx(_name: String) -> void:
	pass


func take_from_pallet() -> void:
	pass


func take_pickup(_p: Pickup) -> void:
	pass


func install_panel(_m: Mount) -> void:
	pass


func install_protection() -> void:
	pass


func install_battery(_slot: int) -> void:
	pass


func install_kit(_row: int) -> void:
	pass


func take_cable(_color: StringName, _from: StringName, _point: Vector3) -> void:
	pass


func connect_cable(_to: StringName) -> void:
	pass


func auto_connect(_color: StringName) -> void:
	pass


func can_auto_connect(_color: StringName) -> bool:
	return false


func measure_rows() -> void:
	pass


func measure_panel(_m: Mount) -> void:
	pass


func repair_panel(_m: Mount) -> void:
	pass


func set_defense(_row: int) -> void:
	pass


func clean_row(_row: int) -> void:
	pass


func try_activate() -> void:
	pass
