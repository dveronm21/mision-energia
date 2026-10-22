class_name RowPostVisual
extends EquipmentVisual
## Poste de fila con palanca de defensa contra el Zonda (palanca abajo = normal, arriba = defensa).

const ANGLE_NORMAL := -0.35
const ANGLE_DEFENSE := 2.35

var _pivot: Node3D
var _defense := false
var _ang := ANGLE_NORMAL


func _init() -> void:
	super(&"row_post", Vector3(0.12, 1.16, 0.15))
	name = "row_post"
	_pivot = part("lever_pivot")
	if _pivot != null:
		_pivot.rotation.x = _ang
	set_process(false)


func set_defense(on: bool, instant: bool = false) -> void:
	_defense = on
	if instant:
		_ang = ANGLE_DEFENSE if on else ANGLE_NORMAL
		if _pivot != null:
			_pivot.rotation.x = _ang
		set_process(false)
	else:
		set_process(true)


func is_defense() -> bool:
	return _defense


func _process(dt: float) -> void:
	var target := ANGLE_DEFENSE if _defense else ANGLE_NORMAL
	_ang = damp(_ang, target, 6.0, dt)
	if absf(_ang - target) < 0.001:
		_ang = target
		set_process(false)
	if _pivot != null:
		_pivot.rotation.x = _ang
