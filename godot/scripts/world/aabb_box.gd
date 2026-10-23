class_name AabbBox
extends RefCounted
## Caja de colisión alineada a los ejes, en el plano XZ (equivale al `Aabb` de `Colliders.ts`).
## Centro (x, z) + medio ancho/fondo (hw, hd).

var x: float
var z: float
var hw: float
var hd: float


func _init(p_x: float, p_z: float, p_hw: float, p_hd: float) -> void:
	x = p_x
	z = p_z
	hw = p_hw
	hd = p_hd
