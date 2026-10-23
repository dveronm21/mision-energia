class_name BoosterSlot
extends RefCounted
## Un booster disponible en la barra del HUD durante la partida (equivale a la forma de
## los slots que arma `GameSession.refreshBoosterBar()` para `BoosterBar.ts`).

var id: StringName
var label: String
var icon: StringName
var count: int


func _init(p_id: StringName, p_label: String, p_icon: StringName, p_count: int) -> void:
	id = p_id
	label = p_label
	icon = p_icon
	count = p_count
