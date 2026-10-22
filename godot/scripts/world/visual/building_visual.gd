class_name BuildingVisual
extends Node3D
## Edificio de la ciudad (4 variantes exportadas). Una sola malla y material (1 draw call): el mapa emisivo
## sólo tiene las ventanas. `set_lights(f)` las enciende (0..1).

const VARIANTS := 4

var variant := 0
var model: Node3D
var _windows: StandardMaterial3D


func _init(building_variant: int = 0) -> void:
	variant = posmod(building_variant, VARIANTS)
	name = "building_%d" % variant
	model = ModelLibrary.instantiate(StringName("building_%d" % variant))
	add_child(model)
	var body := model.find_child("body", true, false) as MeshInstance3D
	_windows = ModelLibrary.own_material(body) as StandardMaterial3D
	if _windows != null:
		_windows.emission_enabled = true
		_windows.emission = Color("#ffd9a0")
		if _windows.emission_texture == null:
			_windows.emission_texture = ModelLibrary.texture("facade_emissive.png")
	set_lights(0.0)


## Intensidad de las luces de las ventanas (usar EnvironmentRig.night_factor()).
func set_lights(f: float) -> void:
	if _windows != null:
		_windows.emission_energy_multiplier = maxf(0.0, f) * 1.6
