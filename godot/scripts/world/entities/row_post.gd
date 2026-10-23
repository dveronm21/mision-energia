class_name RowPost
extends RefCounted
## Poste amarillo de cada fila: palanca de defensa contra el Zonda, limpieza y trabas
## (equivale a `entities/RowPost.ts`). Envuelve el visual ya portado `RowPostVisual`.

var row: int
## Nodo visual: agregalo a la escena antes de usar.
var visual: RowPostVisual
## Punto de acceso frente al poste.
var approach: Vector3


func _init(p_row: int, pos: Vector3) -> void:
	row = p_row
	visual = RowPostVisual.new()
	visual.position = pos
	visual.rotation.y = PI / 2.0
	var label: LabelVisual = LabelVisual.new("FILA %d" % (row + 1), 0.55)
	label.position = Vector3(0.0, 1.62, 0.0)
	visual.add_child(label)
	approach = Vector3(pos.x + 0.95, 0.0, pos.z + 0.55)


func in_defense() -> bool:
	return visual.is_defense()


func set_defense(on: bool, instant: bool = false) -> void:
	visual.set_defense(on, instant)
