class_name Inverter
extends RefCounted
## Inversor: convierte lo que llega de los paneles y reparte a baterías/tablero (equivale a
## `Inverter` de `entities/Equipment.ts`). Envuelve el visual ya portado `InverterVisual`.

var visual: InverterVisual
var approach: Vector3
var terminal: Vector3

var _last_screen: String = ""


func _init(pos: Vector3) -> void:
	visual = InverterVisual.new()
	visual.position = pos
	approach = Vector3(pos.x, 0.0, pos.z + 1.5)
	terminal = visual.terminal_global()


## Punto de entrada para cada color (los prensacables están separados).
func terminal_for(kind: StringName) -> Vector3:
	var dx: float = -0.3 if kind == &"pv" else (-0.1 if kind == &"bat" else 0.1)
	return terminal + Vector3(dx, 0.0, 0.0)


func set_screen(text: String, color: Color = Color("#8fa7a1")) -> void:
	var key: String = text + color.to_html()
	if key == _last_screen:
		return
	_last_screen = key
	visual.set_screen(text, color)
