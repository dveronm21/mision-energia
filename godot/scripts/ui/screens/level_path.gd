class_name LevelPath
extends Control
## Camino curvo entre los nodos del mapa de niveles (equivale al SVG de curvas de
## `LevelMapScreen.ts`). `points_pct`: posiciones 0..1 relativas al tamaño del control.

var points_pct: Array[Vector2] = []
## `.lm-road`: trazo de 26 px blanco al 10 %, puntas redondas.
const ROAD_COLOR: Color = Color(1, 1, 1, 0.10)
const ROAD_W: float = 26.0
## `.lm-dash`: puntos amarillos cada 14 px (dasharray 2 12, opacidad .8).
const DOT_COLOR: Color = Color(1.0, 184.0 / 255.0, 46.0 / 255.0, 0.8)
const DOT_STEP: float = 14.0
const DOT_R: float = 2.2
## Los puntos avanzan despacio hacia adelante (px/s): el camino "invita" a seguirlo.
const DOT_SPEED: float = 10.0

var _flow: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func set_points(pts: Array[Vector2]) -> void:
	points_pct = pts
	queue_redraw()


func _process(delta: float) -> void:
	_flow = fmod(_flow + delta * DOT_SPEED, DOT_STEP)
	queue_redraw()


func _draw() -> void:
	if points_pct.size() < 2:
		return
	var pts: PackedVector2Array = _sample()
	draw_polyline(pts, ROAD_COLOR, ROAD_W, true)
	draw_circle(pts[0], ROAD_W / 2.0, ROAD_COLOR, true, -1.0, true)
	draw_circle(pts[pts.size() - 1], ROAD_W / 2.0, ROAD_COLOR, true, -1.0, true)
	# Puntos equiespaciados a lo largo del camino (no por muestra: la curva no es uniforme).
	var next_at: float = _flow
	var walked: float = 0.0
	for i: int in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var seg: float = a.distance_to(b)
		while next_at <= walked + seg:
			draw_circle(a.lerp(b, (next_at - walked) / maxf(seg, 0.001)), DOT_R, DOT_COLOR, true, -1.0, true)
			next_at += DOT_STEP
		walked += seg


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
