class_name City
extends Node3D
## Los edificios que abastece la planta, los postes y la línea aérea desde el tablero
## (equivale a `entities/City.ts`). De noche, si la planta entrega energía, se iluminan
## las ventanas.

const LINE_COLOR: Color = Color("#2a2a2a")

## Línea aérea desde el tablero hasta la ciudad.
var line: CableVisual

var _lights: Array[BuildingVisual] = []
var _lit: float = -1.0


func _init(layout: CityLayout, line_from: Vector3, cables: CableNetwork) -> void:
	name = "city"
	var group: Node3D = Node3D.new()
	group.position = layout.origin
	add_child(group)
	for i: int in layout.buildings.size():
		var b: BuildingVisual = BuildingVisual.new(i + 1)
		var spot: CityBuilding = layout.buildings[i]
		b.position = Vector3(spot.x, 0.0, spot.z)
		group.add_child(b)
		_lights.append(b)

	var anchors: PackedVector3Array = PackedVector3Array([line_from])
	for i: int in layout.poles.size():
		var pole: PowerPoleVisual = PowerPoleVisual.new()
		pole.position = layout.poles[i]
		pole.rotation.y = -0.5 + i * 0.05
		add_child(pole)
		anchors.append(pole.wire_anchor_global(1))
	anchors.append(layout.origin + Vector3(-1.5, 3.0, 2.0))
	line = cables.run(anchors, LINE_COLOR, 0.03)

	var label: LabelVisual = LabelVisual.new(layout.city_name, 0.9)
	label.position = layout.label
	add_child(label)


## `factor` 0..1: luz de las ventanas (noche × planta entregando).
func set_lit(factor: float) -> void:
	var v: float = roundf(factor * 50.0) / 50.0
	if v == _lit:
		return
	_lit = v
	for b: BuildingVisual in _lights:
		b.set_lights(v)
