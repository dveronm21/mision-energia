class_name WorldAction
extends RefCounted
## Acción contextual en el mundo (equivale a `WorldAction` de `interaction/types.ts`).
## `pos` es el punto de acceso en el piso (fuera de los colisionadores).

var id: String
var label: String
var pos: Vector3
## Callable() -> void: qué hacer si el jugador toca el botón de acción.
var run: Callable


func _init(p_id: String, p_label: String, p_pos: Vector3, p_run: Callable) -> void:
	id = p_id
	label = p_label
	pos = p_pos
	run = p_run
