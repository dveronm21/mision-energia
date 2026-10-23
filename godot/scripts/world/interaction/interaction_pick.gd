class_name InteractionPick
extends RefCounted
## Resultado de un `InteractionSystem.update()`: la acción y la ficha de "Revisar" más
## cercanas al jugador (cualquiera de las dos puede ser null).

var action: WorldAction
var inspect: InspectEntry


func _init(p_action: WorldAction, p_inspect: InspectEntry) -> void:
	action = p_action
	inspect = p_inspect
