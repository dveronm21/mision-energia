class_name MissionObjective
extends RefCounted
## Un renglón del panel de misión (equivale a `MissionObjective` de `ui/types.ts`).

const STATE_OK: StringName = &"ok"
const STATE_ALERT: StringName = &"alert"
const STATE_NOW: StringName = &"now"
const STATE_TODO: StringName = &"todo"

var id: StringName
var text: String
## "ok" | "alert" | "now" | "todo".
var state: StringName


func _init(p_id: StringName, p_text: String, p_state: StringName) -> void:
	id = p_id
	text = p_text
	state = p_state
