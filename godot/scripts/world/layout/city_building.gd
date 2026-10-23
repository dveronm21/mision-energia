class_name CityBuilding
extends RefCounted
## Un edificio de la ciudad, relativo al origen de `CityLayout` (equivale a cada tupla
## `[x, z, w, h, d]` de `CITY` en `LevelLayout.ts`).

var x: float
var z: float
var w: float
var h: float
var d: float


func _init(p_x: float, p_z: float, p_w: float, p_h: float, p_d: float) -> void:
	x = p_x
	z = p_z
	w = p_w
	h = p_h
	d = p_d
