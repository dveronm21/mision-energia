class_name PowerPoleVisual
extends Node3D
## Poste de media tensión con luminaria. La luminaria comparte material entre todos los postes y la
## enciende EnvironmentRig.update (VisualMaterials.set_night).

## Puntos de amarre de los conductores (locales).
const WIRE_ANCHORS: Array[Vector3] = [Vector3(-0.72, 6.84, 0), Vector3(0, 7.24, 0), Vector3(0.72, 6.84, 0)]

var model: Node3D


func _init() -> void:
	name = "power_pole"
	model = ModelLibrary.instantiate(&"power_pole")
	add_child(model)
	var lamp := model.find_child("lamp", true, false) as MeshInstance3D
	VisualMaterials.register_lamp(ModelLibrary.surface_material(lamp))


## Punto de amarre `i` (0..2) en coordenadas globales.
func wire_anchor_global(i: int) -> Vector3:
	var p := WIRE_ANCHORS[clampi(i, 0, WIRE_ANCHORS.size() - 1)]
	return global_transform * p if is_inside_tree() else transform * p
