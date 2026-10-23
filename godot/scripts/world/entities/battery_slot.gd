class_name BatterySlot
extends Node3D
## Base donde va una batería: arranca como silueta (ghost) hasta que el jugador la instala
## (equivale a `BatterySlot` de `entities/Equipment.ts`).

var index: int
var approach: Vector3
var terminal: Vector3

var _ghost: MeshInstance3D
var _model: BatteryVisual


func _init(p_index: int, pos: Vector3) -> void:
	index = p_index
	name = "battery_slot_%d" % index
	position = pos
	approach = Vector3(pos.x, 0.0, pos.z + 1.3)
	_ghost = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1.0, 1.4, 0.6)
	_ghost.mesh = box
	_ghost.material_override = VisualMaterials.ghost()
	_ghost.position = Vector3(0.0, 0.7, 0.0)
	add_child(_ghost)
	terminal = pos + Vector3(0.35, 1.25, 0.34)


func installed() -> bool:
	return _model != null


func install() -> void:
	if _model != null:
		return
	_model = BatteryVisual.new()
	add_child(_model)
	_ghost.visible = false
	terminal = position + _model.terminal_local


func set_ghost_visible(on: bool) -> void:
	_ghost.visible = on and _model == null


func set_charge(p: float) -> void:
	if _model != null:
		_model.set_charge(p)
