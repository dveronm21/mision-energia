class_name LayoutRect
extends RefCounted
## Rectángulo en el plano XZ, centrado en (x, z) con ancho `w` y fondo `d`
## (equivale a `Rect` de `LevelLayout.ts`).

var x: float
var z: float
var w: float
var d: float


func _init(p_x: float, p_z: float, p_w: float, p_d: float) -> void:
	x = p_x
	z = p_z
	w = p_w
	d = p_d


## ¿El punto (px, pz) cae adentro, con un margen opcional `pad`?
func contains(px: float, pz: float, pad: float = 0.0) -> bool:
	return absf(px - x) <= w / 2.0 + pad and absf(pz - z) <= d / 2.0 + pad
