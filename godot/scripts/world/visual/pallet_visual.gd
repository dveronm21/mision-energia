class_name PalletVisual
extends Node3D
## Pallet con pila de paneles (MultiMesh: una sola llamada de dibujo para toda la pila).

const STEP := 0.046
const BASE_Y := 0.137

var model: Node3D
var _stack: MultiMeshInstance3D
var _count := 0


func _init(count: int = 8) -> void:
	name = "pallet"
	model = ModelLibrary.instantiate(&"pallet")
	add_child(model)
	_stack = MultiMeshInstance3D.new()
	_stack.name = "stack"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = ModelLibrary.first_mesh(&"panel")
	_stack.multimesh = mm
	add_child(_stack)
	set_count(count)


## Cantidad de paneles apilados (crece la capacidad si hace falta).
func set_count(n: int) -> void:
	n = maxi(0, n)
	_count = n
	var mm := _stack.multimesh
	if mm.instance_count < n or mm.instance_count == 0:
		mm.instance_count = maxi(12, n)
		var rng := RandomNumberGenerator.new()
		rng.seed = 4
		for i: int in mm.instance_count:
			var b := Basis(Vector3.UP, (rng.randf() - 0.5) * 0.03)
			mm.set_instance_transform(i, Transform3D(b, Vector3((rng.randf() - 0.5) * 0.02, BASE_Y + i * STEP, (rng.randf() - 0.5) * 0.02)))
	mm.visible_instance_count = n
	_stack.visible = n > 0


func count() -> int:
	return _count
