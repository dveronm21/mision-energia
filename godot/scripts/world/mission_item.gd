class_name MissionItem
extends RefCounted
## Renglón interno de `MissionTracker` antes de convertirse en `MissionObjective`
## (equivale a la interfaz privada `Item` de `MissionTracker.ts`).

var step: StringName
var text: String
var ok: bool
var alert: bool


func _init(p_step: StringName, p_text: String, p_ok: bool, p_alert: bool = false) -> void:
	step = p_step
	text = p_text
	ok = p_ok
	alert = p_alert
