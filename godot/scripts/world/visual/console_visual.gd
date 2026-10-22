class_name ConsoleVisual
extends EquipmentVisual
## Consola con el gran botón ACTIVAR PLANTA. Activo: el botón late con brillo fuerte y baja un poco.

var _button: MeshInstance3D
var _mat: StandardMaterial3D
var _active := false
var _time := 0.0


func _init() -> void:
	super(&"console", Vector3(0, 0.25, 0.3))
	name = "console"
	_button = part("button") as MeshInstance3D
	_mat = ModelLibrary.own_material(_button) as StandardMaterial3D
	if _mat != null:
		_mat.emission_enabled = true
		_mat.emission = VisualMaterials.C_SUN


func set_active(on: bool = true) -> void:
	_active = on


func is_active() -> bool:
	return _active


func _process(dt: float) -> void:
	_time += dt
	var pulse := 0.5 + 0.5 * sin(_time * 4.2)
	if _mat != null:
		_mat.emission_energy_multiplier = (1.0 + pulse * 1.2) if _active else (0.12 + pulse * 0.1)
	if _button != null:
		_button.position.y = 0.085 if _active else 0.1
