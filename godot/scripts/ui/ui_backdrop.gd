class_name UiBackdrop
extends Control
## Fondo de las pantallas (equivale a los `background` de `.pg` y `.splash` en styles.ts):
##   PAGE   → degradé vertical #183A34 → #0E2420 con un resplandor de sol arriba a la derecha y
##            uno verde abajo a la izquierda.
##   SPLASH → degradé #0B1E1B → #163631 → #2A4A2E, resplandor de sol desde abajo y rayos que
##            giran despacio (`.splash-rays`, 60 s por vuelta).

enum Kind { PAGE, SPLASH }

const RAY_STEP_DEG: float = 15.0
const RAY_WIDTH_DEG: float = 4.0
const RAY_COLOR: Color = Color(1.0, 184.0 / 255.0, 46.0 / 255.0, 0.06)
const RAY_TURN_SEC: float = 60.0

var kind: Kind = Kind.PAGE
var _angle: float = 0.0
## Capa de los rayos, encima de los degradés (lo que dibuja este nodo quedaría debajo de sus hijos).
var _rays: Control = null


func _init(p_kind: Kind = Kind.PAGE) -> void:
	kind = p_kind
	name = "backdrop"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	if kind == Kind.PAGE:
		_add_linear([Color("#183a34"), Color("#0e2420"), Color("#0e2420")], [0.0, 0.7, 1.0])
		_add_glow(Vector2(0.85, -0.2), Vector2(0.55 * 1.6, 0.55 * 1.6), Color(1.0, 184.0 / 255.0, 46.0 / 255.0, 0.28))
		_add_glow(Vector2(-0.1, 1.2), Vector2(0.5 * 1.6, 0.5 * 1.6), Color(63.0 / 255.0, 163.0 / 255.0, 77.0 / 255.0, 0.22))
	else:
		_add_linear([Color("#0b1e1b"), Color("#163631"), Color("#2a4a2e")], [0.0, 0.6, 1.0])
		_add_glow(Vector2(0.5, 1.2), Vector2(1.2, 1.2), Color(1.0, 184.0 / 255.0, 46.0 / 255.0, 0.55), Color(242.0 / 255.0, 140.0 / 255.0, 40.0 / 255.0, 0.15))
		_rays = Control.new()
		_rays.name = "rays"
		_rays.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rays.set_anchors_preset(Control.PRESET_FULL_RECT)
		_rays.draw.connect(_draw_rays)
		add_child(_rays)
		set_process(true)


func _process(delta: float) -> void:
	if _rays == null:
		return
	_angle = fmod(_angle + delta * TAU / RAY_TURN_SEC, TAU)
	_rays.queue_redraw()


func _draw_rays() -> void:
	# Centro de los rayos en el borde de abajo (un círculo de 120vmax con bottom:-60vmax en la web).
	var sz: Vector2 = _rays.size
	var vmax: float = maxf(sz.x, sz.y)
	var center: Vector2 = Vector2(sz.x * 0.5, sz.y)
	var reach: float = vmax * 0.6
	var deg: float = 0.0
	while deg < 360.0:
		var a0: float = deg_to_rad(deg) + _angle
		var a1: float = a0 + deg_to_rad(RAY_WIDTH_DEG)
		var pts: PackedVector2Array = PackedVector2Array([
			center, center + Vector2(cos(a0), sin(a0)) * reach, center + Vector2(cos(a1), sin(a1)) * reach])
		_rays.draw_colored_polygon(pts, RAY_COLOR)
		deg += RAY_STEP_DEG


func _add_linear(colors: Array[Color], offsets: Array[float]) -> void:
	var g: Gradient = Gradient.new()
	g.colors = PackedColorArray(colors)
	g.offsets = PackedFloat32Array(offsets)
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 256
	add_child(_rect(tex))


## Resplandor radial: `center` y `radius` en fracciones del tamaño de la pantalla.
func _add_glow(center: Vector2, radius: Vector2, inner: Color, mid: Color = Color.TRANSPARENT) -> void:
	var g: Gradient = Gradient.new()
	var clear: Color = Color(inner.r, inner.g, inner.b, 0.0)
	if mid.a > 0.0:
		g.colors = PackedColorArray([inner, mid, Color(mid.r, mid.g, mid.b, 0.0)])
		g.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	else:
		g.colors = PackedColorArray([inner, clear])
		g.offsets = PackedFloat32Array([0.0, 1.0])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.width = 256
	tex.height = 256
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var r: TextureRect = _rect(tex)
	r.set_anchors_preset(Control.PRESET_TOP_LEFT)
	r.anchor_left = center.x - radius.x
	r.anchor_right = center.x + radius.x
	r.anchor_top = center.y - radius.y
	r.anchor_bottom = center.y + radius.y
	r.offset_left = 0
	r.offset_right = 0
	r.offset_top = 0
	r.offset_bottom = 0
	add_child(r)


static func _rect(tex: Texture2D) -> TextureRect:
	var r: TextureRect = TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	return r
