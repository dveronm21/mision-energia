class_name LevelBounds
extends RefCounted
## Límites del mapa jugable en el plano XZ (equivale a `LevelLayout['bounds']`).

var min_x: float
var max_x: float
var min_z: float
var max_z: float


func _init(p_min_x: float, p_max_x: float, p_min_z: float, p_max_z: float) -> void:
	min_x = p_min_x
	max_x = p_max_x
	min_z = p_min_z
	max_z = p_max_z
