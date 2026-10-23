class_name Switchboard
extends RefCounted
## Tablero general: reparte hacia la ciudad (equivale a `Switchboard` de `entities/Equipment.ts`).

var visual: SwitchboardVisual
var approach: Vector3
var terminal: Vector3
## Salida hacia la línea de la ciudad (arriba del gabinete).
var line_out: Vector3


func _init(pos: Vector3) -> void:
	visual = SwitchboardVisual.new()
	visual.position = pos
	approach = Vector3(pos.x, 0.0, pos.z + 1.5)
	terminal = visual.terminal_global()
	line_out = pos + Vector3(0.25, 2.1, 0.1)
