class_name ControlConsole
extends RefCounted
## Consola de activación de la planta (equivale a `ControlConsole` de `entities/Equipment.ts`).

var visual: ConsoleVisual
var approach: Vector3


func _init(pos: Vector3) -> void:
	visual = ConsoleVisual.new()
	visual.position = pos
	approach = Vector3(pos.x, 0.0, pos.z + 1.25)


func set_active(on: bool = true) -> void:
	visual.set_active(on)
