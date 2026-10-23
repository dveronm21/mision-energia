class_name HudIcon
extends Control
## Ícono del HUD, dibujado con primitivas (no es un port de `icons.ts`: esa es una librería de
## 24 SVG de trazo propio; acá van glifos vectoriales simples con la misma idea — trazo fino,
## color heredado — para no bloquear el HUD en texturas que todavía no existen).

## "meter" | "search" | "pause" | "hint" | "drone" | "battery-plus" | "coins" | "close" | "star".
@export var icon_name: StringName = &"star"
@export var stroke_color: Color = Color.WHITE
@export var stroke_width: float = 2.2


func _init(name_: StringName = &"star", size_px: float = 24.0, color: Color = Color.WHITE) -> void:
	icon_name = name_
	stroke_color = color
	custom_minimum_size = Vector2(size_px, size_px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s: Vector2 = size
	var c: Vector2 = s / 2.0
	var r: float = minf(s.x, s.y) / 2.0 - stroke_width
	match icon_name:
		&"meter":
			draw_arc(c, r, 2.6, PI + 0.55, 20, stroke_color, stroke_width, true)
			draw_line(c, c + Vector2(r * 0.7, -r * 0.1).rotated(-0.5), stroke_color, stroke_width, true)
		&"search":
			var lens_c: Vector2 = c + Vector2(-r * 0.18, -r * 0.18)
			draw_arc(lens_c, r * 0.55, 0.0, TAU, 24, stroke_color, stroke_width, true)
			var dir: Vector2 = Vector2(1, 1).normalized()
			draw_line(lens_c + dir * r * 0.55, lens_c + dir * r * 1.15, stroke_color, stroke_width, true)
		&"pause":
			var w: float = r * 0.5
			draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.75), Vector2(w, r * 1.5)), stroke_color)
			draw_rect(Rect2(c + Vector2(r * 0.05, -r * 0.75), Vector2(w, r * 1.5)), stroke_color)
		&"minus":
			draw_line(c + Vector2(-r * 0.6, 0.0), c + Vector2(r * 0.6, 0.0), stroke_color, stroke_width * 1.3, true)
		&"plus":
			draw_line(c + Vector2(-r * 0.6, 0.0), c + Vector2(r * 0.6, 0.0), stroke_color, stroke_width * 1.3, true)
			draw_line(c + Vector2(0.0, -r * 0.6), c + Vector2(0.0, r * 0.6), stroke_color, stroke_width * 1.3, true)
		&"wind":
			for i: int in 3:
				var yy: float = -r * 0.4 + i * r * 0.4
				draw_line(c + Vector2(-r * 0.8, yy), c + Vector2(r * 0.4, yy), stroke_color, stroke_width, true)
				draw_arc(c + Vector2(r * 0.4, yy - r * 0.15), r * 0.15, -PI / 2.0, PI / 2.0, 8, stroke_color, stroke_width, true)
		&"cloud":
			draw_arc(c + Vector2(-r * 0.25, 0.0), r * 0.4, PI * 0.5, PI * 1.8, 12, stroke_color, stroke_width, true)
			draw_arc(c + Vector2(r * 0.25, -r * 0.1), r * 0.35, PI * 1.2, PI * 2.4, 12, stroke_color, stroke_width, true)
			draw_line(c + Vector2(-r * 0.55, r * 0.3), c + Vector2(r * 0.5, r * 0.3), stroke_color, stroke_width, true)
		&"loose":
			draw_line(c + Vector2(-r * 0.7, -r * 0.5), c + Vector2(-r * 0.1, 0.0), stroke_color, stroke_width, true)
			draw_line(c + Vector2(r * 0.1, r * 0.1), c + Vector2(r * 0.7, r * 0.6), stroke_color, stroke_width, true)
			draw_arc(c + Vector2(-r * 0.1, 0.05), r * 0.1, 0.0, TAU, 8, stroke_color, stroke_width, true)
		&"pump":
			draw_arc(c, r * 0.55, 0.0, TAU, 16, stroke_color, stroke_width, true)
			draw_line(c + Vector2(r * 0.55, 0.0), c + Vector2(r, 0.0), stroke_color, stroke_width, true)
		&"bolt":
			var pts_b: PackedVector2Array = PackedVector2Array([
				c + Vector2(r * 0.15, -r), c + Vector2(-r * 0.55, r * 0.15), c + Vector2(-r * 0.05, r * 0.15),
				c + Vector2(-r * 0.15, r), c + Vector2(r * 0.55, -r * 0.15), c + Vector2(r * 0.05, -r * 0.15),
			])
			draw_colored_polygon(pts_b, stroke_color)
		&"lock":
			draw_rect(Rect2(c + Vector2(-r * 0.55, -r * 0.1), Vector2(r * 1.1, r * 0.85)), stroke_color, false, stroke_width)
			draw_arc(c + Vector2(0.0, -r * 0.1), r * 0.4, PI, TAU, 14, stroke_color, stroke_width, true)
		&"next":
			draw_line(c + Vector2(-r * 0.5, -r * 0.8), c + Vector2(r * 0.3, 0.0), stroke_color, stroke_width, true)
			draw_line(c + Vector2(r * 0.3, 0.0), c + Vector2(-r * 0.5, r * 0.8), stroke_color, stroke_width, true)
		&"retry":
			draw_arc(c, r * 0.6, -2.3, 2.3, 16, stroke_color, stroke_width, true)
			var tip: Vector2 = c + Vector2(cos(2.3), sin(2.3)) * r * 0.6
			draw_line(tip, tip + Vector2(-r * 0.3, -r * 0.1), stroke_color, stroke_width, true)
			draw_line(tip, tip + Vector2(-r * 0.05, r * 0.3), stroke_color, stroke_width, true)
		&"map":
			draw_line(c + Vector2(-r, -r * 0.5), c + Vector2(-r * 0.3, -r * 0.8), stroke_color, stroke_width, true)
			draw_line(c + Vector2(-r * 0.3, -r * 0.8), c + Vector2(r * 0.3, -r * 0.5), stroke_color, stroke_width, true)
			draw_line(c + Vector2(r * 0.3, -r * 0.5), c + Vector2(r, -r * 0.8), stroke_color, stroke_width, true)
			draw_line(c + Vector2(-r, -r * 0.5), c + Vector2(-r, r * 0.8), stroke_color, stroke_width, true)
			draw_line(c + Vector2(-r, r * 0.8), c + Vector2(-r * 0.3, r * 0.5), stroke_color, stroke_width, true)
			draw_line(c + Vector2(-r * 0.3, -r * 0.8), c + Vector2(-r * 0.3, r * 0.5), stroke_color, stroke_width, true)
			draw_line(c + Vector2(-r * 0.3, r * 0.5), c + Vector2(r * 0.3, r * 0.8), stroke_color, stroke_width, true)
			draw_line(c + Vector2(r * 0.3, -r * 0.5), c + Vector2(r * 0.3, r * 0.8), stroke_color, stroke_width, true)
			draw_line(c + Vector2(r * 0.3, r * 0.8), c + Vector2(r, r * 0.5), stroke_color, stroke_width, true)
			draw_line(c + Vector2(r, -r * 0.8), c + Vector2(r, r * 0.5), stroke_color, stroke_width, true)
		&"sound":
			draw_rect(Rect2(c + Vector2(-r * 0.9, -r * 0.3), Vector2(r * 0.4, r * 0.6)), stroke_color)
			var pts_s: PackedVector2Array = PackedVector2Array([c + Vector2(-r * 0.5, -r * 0.3), c + Vector2(r * 0.1, -r * 0.7), c + Vector2(r * 0.1, r * 0.7), c + Vector2(-r * 0.5, r * 0.3)])
			draw_colored_polygon(pts_s, stroke_color)
			draw_arc(c + Vector2(r * 0.2, 0.0), r * 0.55, -0.7, 0.7, 10, stroke_color, stroke_width, true)
		&"mute":
			draw_rect(Rect2(c + Vector2(-r * 0.9, -r * 0.3), Vector2(r * 0.4, r * 0.6)), stroke_color)
			var pts_m: PackedVector2Array = PackedVector2Array([c + Vector2(-r * 0.5, -r * 0.3), c + Vector2(r * 0.1, -r * 0.7), c + Vector2(r * 0.1, r * 0.7), c + Vector2(-r * 0.5, r * 0.3)])
			draw_colored_polygon(pts_m, stroke_color)
			draw_line(c + Vector2(r * 0.3, -r * 0.4), c + Vector2(r * 0.9, r * 0.4), stroke_color, stroke_width, true)
			draw_line(c + Vector2(r * 0.3, r * 0.4), c + Vector2(r * 0.9, -r * 0.4), stroke_color, stroke_width, true)
		&"cart":
			draw_rect(Rect2(c + Vector2(-r * 0.75, -r * 0.3), Vector2(r * 1.3, r * 0.65)), stroke_color, false, stroke_width)
			draw_line(c + Vector2(-r, -r * 0.8), c + Vector2(-r * 0.75, -r * 0.3), stroke_color, stroke_width, true)
			draw_arc(c + Vector2(-r * 0.4, r * 0.65), r * 0.18, 0.0, TAU, 10, stroke_color, stroke_width, true)
			draw_arc(c + Vector2(r * 0.35, r * 0.65), r * 0.18, 0.0, TAU, 10, stroke_color, stroke_width, true)
		&"helmet":
			draw_arc(c, r * 0.7, PI, TAU, 16, stroke_color, stroke_width, true)
			draw_line(c + Vector2(-r * 0.7, 0.0), c + Vector2(r * 0.7, 0.0), stroke_color, stroke_width, true)
		&"gear":
			draw_arc(c, r * 0.45, 0.0, TAU, 20, stroke_color, stroke_width, true)
			for i: int in 8:
				var a: float = (float(i) / 8.0) * TAU
				var dir: Vector2 = Vector2(cos(a), sin(a))
				draw_line(c + dir * r * 0.6, c + dir * r * 0.9, stroke_color, stroke_width, true)
		&"gift":
			draw_rect(Rect2(c + Vector2(-r * 0.7, -r * 0.3), Vector2(r * 1.4, r)), stroke_color, false, stroke_width)
			draw_line(c + Vector2(0.0, -r * 0.3), c + Vector2(0.0, r * 0.7), stroke_color, stroke_width, true)
			draw_line(c + Vector2(-r * 0.7, -r * 0.3), c + Vector2(r * 0.7, -r * 0.3), stroke_color, stroke_width, true)
		&"check":
			draw_line(c + Vector2(-r * 0.6, 0.0), c + Vector2(-r * 0.15, r * 0.5), stroke_color, stroke_width, true)
			draw_line(c + Vector2(-r * 0.15, r * 0.5), c + Vector2(r * 0.7, -r * 0.5), stroke_color, stroke_width, true)
		&"play":
			var pts: PackedVector2Array = PackedVector2Array([
				c + Vector2(-r * 0.6, -r * 0.8), c + Vector2(-r * 0.6, r * 0.8), c + Vector2(r * 0.8, 0.0),
			])
			draw_colored_polygon(pts, stroke_color)
		&"sun":
			draw_arc(c, r * 0.5, 0.0, TAU, 20, stroke_color, stroke_width, true)
			for i: int in 8:
				var a: float = (float(i) / 8.0) * TAU
				var dir: Vector2 = Vector2(cos(a), sin(a))
				draw_line(c + dir * r * 0.68, c + dir * r, stroke_color, stroke_width, true)
		&"back":
			draw_line(c + Vector2(r * 0.4, -r * 0.8), c + Vector2(-r * 0.4, 0.0), stroke_color, stroke_width, true)
			draw_line(c + Vector2(-r * 0.4, 0.0), c + Vector2(r * 0.4, r * 0.8), stroke_color, stroke_width, true)
		&"close":
			draw_line(c + Vector2(-r, -r), c + Vector2(r, r), stroke_color, stroke_width, true)
			draw_line(c + Vector2(-r, r), c + Vector2(r, -r), stroke_color, stroke_width, true)
		&"hint":
			draw_arc(c + Vector2(0, -r * 0.1), r * 0.55, 0.3, TAU - 0.3, 20, stroke_color, stroke_width, true)
			draw_line(c + Vector2(-r * 0.18, r * 0.45), c + Vector2(r * 0.18, r * 0.45), stroke_color, stroke_width, true)
			draw_line(c + Vector2(0, r * 0.45), c + Vector2(0, r * 0.75), stroke_color, stroke_width, true)
		&"drone":
			draw_rect(Rect2(c - Vector2(r * 0.3, r * 0.2), Vector2(r * 0.6, r * 0.4)), stroke_color)
			for dx: float in [-1.0, 1.0]:
				for dz: float in [-1.0, 1.0]:
					var arm: Vector2 = c + Vector2(dx, dz) * r * 0.6
					draw_line(c, arm, stroke_color, stroke_width * 0.6, true)
					draw_arc(arm, r * 0.22, 0.0, TAU, 10, stroke_color, stroke_width * 0.6, true)
		&"battery-plus":
			draw_rect(Rect2(c + Vector2(-r * 0.8, -r * 0.5), Vector2(r * 1.4, r)), stroke_color, false, stroke_width)
			draw_rect(Rect2(c + Vector2(r * 0.6, -r * 0.25), Vector2(r * 0.2, r * 0.5)), stroke_color)
			draw_line(c + Vector2(-r * 0.1, -r * 0.3), c + Vector2(-r * 0.1, r * 0.3), stroke_color, stroke_width, true)
			draw_line(c + Vector2(-r * 0.4, 0.0), c + Vector2(r * 0.2, 0.0), stroke_color, stroke_width, true)
		&"coins":
			draw_arc(c + Vector2(-r * 0.25, r * 0.2), r * 0.5, 0.0, TAU, 20, stroke_color, stroke_width, true)
			draw_arc(c + Vector2(r * 0.25, -r * 0.2), r * 0.5, 0.0, TAU, 20, stroke_color, stroke_width, true)
		_:
			_draw_star(c, r)


func _draw_star(c: Vector2, r: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 10:
		var a: float = (float(i) / 10.0) * TAU - PI / 2.0
		var rr: float = r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	pts.append(pts[0])
	draw_polyline(pts, stroke_color, stroke_width, true)
