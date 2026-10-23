class_name JunctionBox
extends RefCounted
## Caja de conexión donde llegan los cables del campo solar (equivale a `JunctionBox` de
## `entities/Equipment.ts`).

var visual: JunctionBoxVisual
var approach: Vector3
var terminal: Vector3


func _init(pos: Vector3) -> void:
	visual = JunctionBoxVisual.new()
	visual.position = pos
	approach = Vector3(pos.x, 0.0, pos.z + 1.25)
	terminal = visual.terminal_global()
