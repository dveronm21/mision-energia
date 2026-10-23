class_name Pump
extends RefCounted
## Bomba solar (nivel "finca"): carga diurna extra (equivale a `Pump` de `entities/Equipment.ts`).

var visual: PumpVisual
var approach: Vector3
var terminal: Vector3

var _running: bool = false


func _init(pos: Vector3) -> void:
	visual = PumpVisual.new()
	visual.position = pos
	approach = Vector3(pos.x, 0.0, pos.z + 2.6)
	terminal = visual.terminal_global()


func set_running(on: bool) -> void:
	if on == _running:
		return
	_running = on
	visual.set_running(on)
