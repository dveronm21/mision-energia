class_name PumpVisual
extends EquipmentVisual
## Bomba de riego con motor, acople giratorio, chorro y bebedero que se llena.

var _rotor: Node3D
var _water: Node3D
var _stream: Node3D
var _running := false
var _spin := 0.0
var _level := 0.0
var _time := 0.0


func _init() -> void:
	super(&"pump", Vector3(0.05, 0.66, 0.08))
	name = "pump"
	_rotor = part("rotor")
	_water = part("water")
	_stream = part("stream")
	if _stream != null:
		_stream.visible = false


func set_running(on: bool = true) -> void:
	_running = on


func is_running() -> bool:
	return _running


func _process(dt: float) -> void:
	_time += dt
	_spin = damp(_spin, 22.0 if _running else 0.0, 2.0, dt)
	if _rotor != null:
		_rotor.rotation.x += _spin * dt
	_level = damp(_level, 1.0 if _running else 0.0, 0.4, dt)
	if _water != null:
		_water.position.y = 0.36 + _level * 0.12 + (sin(_time * 6.0) * 0.004 if _running else 0.0)
	if _stream != null:
		_stream.visible = _running
		_stream.scale.y = 1.0 + sin(_time * 30.0) * 0.02
