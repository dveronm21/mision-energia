class_name LevelPath
extends Control
## Camino curvo entre los nodos del mapa de niveles (equivale al SVG de curvas de
## `LevelMapScreen.ts`). `points_pct`: posiciones 0..1 relativas al tamaño del control.

var points_pct: Array[Vector2] = []
const ROAD_COLOR: Color = Color(1, 1, 1, 0.14)
const DASH_COLOR: Color = VisualMaterials.C_SUN


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func set_points(pts: Array[Vector2]) -> void:
	points_pct = pts
	queue_redraw()


func _draw() -> void:
	if points_pct.size() < 2:
		return
	var pts: PackedVector2Array = _sample()
	draw_polyline(pts, ROAD_COLOR, 10.0, true)
	# Guiones: una de cada tres muestras, para sugerir un camino punteado sin texturas.
	for i: int in range(0, pts.size() - 1, 3):
		draw_line(pts[i], pts[mini(i + 1, pts.size() - 1)], DASH_COLOR, 3.0, true)


func _sample(steps_per_segment: int = 24) -> PackedVector2Array:
	var s: Vector2 = size
	var pts: PackedVector2Array = PackedVector2Array()
	var abs_pts: Array[Vector2] = []
	for p: Vector2 in points_pct:
		abs_pts.append(Vector2(p.x * s.x, p.y * s.y))
	pts.append(abs_pts[0])
	for i: int in range(1, abs_pts.size()):
		var a: Vector2 = abs_pts[i - 1]
		var b: Vector2 = abs_pts[i]
		var mx: float = (a.x + b.x) / 2.0
		var c1: Vector2 = Vector2(mx, a.y)
		var c2: Vector2 = Vector2(mx, b.y)
		for step: int in range(1, steps_per_segment + 1):
			var t: float = float(step) / float(steps_per_segment)
			pts.append(a.bezier_interpolate(c1, c2, b, t))
	return pts
