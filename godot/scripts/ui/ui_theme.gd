class_name UiTheme
extends RefCounted
## Estilo visual de toda la UI (equivale a las variables y clases base de `styles.ts`):
## paleta, fuentes (Fredoka para títulos y botones, Nunito para el texto) y fábricas de
## `StyleBoxFlat`. `build()` arma el `Theme` que `UiRoot` aplica a su raíz, así cada
## `Label`/`Button` hereda Nunito 16 blanco sin tener que configurarlo uno por uno.

# Paleta del prototipo (`:root` de styles.ts).
const HUD: Color = Color("#0e2420")
const HUD_2: Color = Color("#1f3d37")
const HUD_LINE: Color = Color("#2f5a51")
const FG: Color = Color.WHITE
const MUTED: Color = Color("#b7ccc6")
const SUN: Color = Color("#ffb82e")
const SUN_DARK: Color = Color("#b9781a")
const SUN_INK: Color = Color("#7a4e0e")
const SUN_SOFT: Color = Color("#ffe2a1")
const SUN_WARM: Color = Color("#ffd27a")
const LEAF: Color = Color("#3fa34d")
const LEAF_DARK: Color = Color("#2e7d3a")
const INK: Color = Color("#10231f")
const INK_2: Color = Color("#2a4741")
const INK_3: Color = Color("#4a635d")
const WARN: Color = Color("#f28c28")
const DANGER: Color = Color("#b3261e")
const DUST: Color = Color("#3a2a12")
const PAPER: Color = Color.WHITE
const PAPER_2: Color = Color("#f1f5f3")
const LINE: Color = Color("#d5dcda")
const SHADOW_DARK: Color = Color("#0a1a17")
const LOCKED: Color = Color("#4e625d")
const LOCKED_LINE: Color = Color("#8fa7a1")
const LOCKED_SHADOW: Color = Color("#2c3b36")
const PANEL_BG: Color = Color(14.0 / 255.0, 36.0 / 255.0, 32.0 / 255.0, 0.92)

const FONT_DIR: String = "res://assets/fonts/"

static var _fonts: Dictionary[String, Font] = {}
static var _theme: Theme = null


## Fredoka (títulos, botones, números). `weight`: 500 | 600 | 700.
static func display(weight: int = 700) -> Font:
	return _font("fredoka-latin-%d-normal.woff2" % clampi(weight, 500, 700))


## Nunito (texto). `weight`: 600 | 700 | 800.
static func body(weight: int = 700) -> Font:
	return _font("nunito-latin-%d-normal.woff2" % clampi(weight, 600, 800))


## Share Tech Mono (pantalla del multímetro).
static func mono() -> Font:
	return _font("share-tech-mono-latin-400-normal.woff2")


static func _font(file: String) -> Font:
	if not _fonts.has(file):
		_fonts[file] = load(FONT_DIR + file) as Font
	return _fonts[file]


## Tema global: Nunito 700 16 px blanco, sin fondos de botón por defecto (cada botón trae
## el suyo) y scrollbars finitas.
static func build() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	t.default_font = body(700)
	t.default_font_size = 16
	t.set_color("font_color", "Label", FG)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(state, "Button", FG)
	t.set_font("font", "Button", display(600))
	t.set_font_size("font_size", "Button", 18)
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		t.set_stylebox(state, "Button", empty)
	t.set_stylebox("focus", "Button", focus_ring())
	var grabber: StyleBoxFlat = box(Color(1, 1, 1, 0.25), 999)
	grabber.content_margin_left = 3
	grabber.content_margin_right = 3
	t.set_stylebox("grabber", "VScrollBar", grabber)
	t.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	t.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	_theme = t
	return t


## Caja redondeada lisa. `radius` 999 = píldora.
static func box(bg: Color, radius: int = 16, border: int = 0, border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 12
	s.anti_aliasing = true
	if border > 0:
		s.set_border_width_all(border)
		s.border_color = border_color
	return s


## Caja con "labio" inferior duro (el `box-shadow: 0 Npx 0` de la web): el borde de abajo
## más grueso hace de sombra. `pad_x`/`pad_y`: márgenes de contenido.
static func lipped(bg: Color, lip: Color, lip_px: int, radius: int = 999, border: int = 0, border_color: Color = Color.TRANSPARENT, pad_x: float = 20.0, pad_y: float = 0.0) -> StyleBoxFlat:
	var s: StyleBoxFlat = box(bg, radius, border, border_color)
	if border == 0:
		s.border_color = lip
	s.border_width_bottom = border + lip_px
	if border > 0:
		# Borde de color + labio: el labio se dibuja como sombra sin difuminar.
		s.border_width_bottom = border
		s.shadow_color = lip
		s.shadow_size = 0
		s.shadow_offset = Vector2(0, lip_px)
	s.content_margin_left = pad_x
	s.content_margin_right = pad_x
	s.content_margin_top = pad_y
	s.content_margin_bottom = pad_y
	return s


## Anillo de foco (`:focus-visible` amarillo de 3 px separado 3 px): teclado, D-pad o control.
static func focus_ring(radius: int = 999) -> StyleBoxFlat:
	var s: StyleBoxFlat = box(Color.TRANSPARENT, radius + 6 if radius < 999 else 999, 3, SUN)
	s.draw_center = false
	s.expand_margin_left = 6
	s.expand_margin_right = 6
	s.expand_margin_top = 6
	s.expand_margin_bottom = 6
	return s


## Rebote al tocar: se achica al apretar y vuelve con un pequeño sobrepaso al soltar (el
## "squash" de los juegos de Supercell). Escala sobre el centro, sin mover el layout.
static func add_press_bounce(b: BaseButton, squash: float = 0.94) -> void:
	if b.has_meta(&"bounce"):
		return
	b.set_meta(&"bounce", true)
	b.button_down.connect(func() -> void: _bounce(b, Vector2(squash, squash), 0.07, Tween.TRANS_QUAD))
	b.button_up.connect(func() -> void: _bounce(b, Vector2.ONE, 0.28, Tween.TRANS_BACK))


static func _bounce(b: BaseButton, to: Vector2, sec: float, trans: Tween.TransitionType) -> void:
	if not b.is_inside_tree():
		return
	b.pivot_offset = b.size / 2.0
	# Ojo: `get_meta(clave, null)` igual da error si falta la clave (null cuenta como "sin valor
	# por defecto"), por eso se pregunta antes.
	if b.has_meta(&"bounce_tween"):
		var old: Tween = b.get_meta(&"bounce_tween") as Tween
		if old != null and old.is_valid():
			old.kill()
	var t: Tween = b.create_tween()
	t.tween_property(b, "scale", to, sec).set_trans(trans).set_ease(Tween.EASE_OUT)
	b.set_meta(&"bounce_tween", t)


## Panel oscuro translúcido del HUD (`.hud-panel`).
static func hud_panel(radius: int = 16) -> StyleBoxFlat:
	return box(PANEL_BG, radius, 1, HUD_LINE)


## Tarjeta blanca (`.mdl-card`, `.ws-shop`, `.lm-card`), con sombra dura opcional.
static func card(radius: int = 22, pad: float = 18.0, shadow_px: int = 10) -> StyleBoxFlat:
	var s: StyleBoxFlat = box(PAPER, radius)
	s.set_content_margin_all(pad)
	if shadow_px > 0:
		s.shadow_color = Color(0, 0, 0, 0.22)
		s.shadow_size = 0
		s.shadow_offset = Vector2(0, shadow_px)
	return s


## Aplica la misma caja a todos los estados de un botón; `pressed` baja el contenido y achica
## el labio (como el `:active { transform: translateY(3px) }` de la web).
static func style_button(b: Button, normal: StyleBox, disabled: StyleBox = null) -> void:
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", normal)
	b.add_theme_stylebox_override("focus", focus_ring(_radius_of(normal)))
	var pressed: StyleBox = normal
	if normal is StyleBoxFlat:
		var p: StyleBoxFlat = (normal as StyleBoxFlat).duplicate() as StyleBoxFlat
		var lip_border: int = p.border_width_bottom - p.border_width_top
		if lip_border > 2:
			p.border_width_bottom -= 3
			p.content_margin_top += 3
		elif p.shadow_offset.y > 2.0:
			p.shadow_offset.y -= 3.0
			p.content_margin_top += 3
		pressed = p
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled if disabled != null else normal)
	add_press_bounce(b)


static func _radius_of(s: StyleBox) -> int:
	return (s as StyleBoxFlat).corner_radius_top_left if s is StyleBoxFlat else 16


## Label con fuente propia. `font`: una de `display()`/`body()`/`mono()`.
static func label(text: String, font: Font, font_size: int, color: Color = FG) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


## Título en Fredoka 700 (`.pg-title`, `h2`).
static func title(text: String, font_size: int = 28, color: Color = FG) -> Label:
	return label(text, display(700), font_size, color)


## Texto chico en mayúsculas espaciadas (`.eyebrow`).
static func eyebrow(text: String, color: Color = SUN, font_size: int = 13) -> Label:
	var l: Label = label(text.to_upper(), body(800), font_size, color)
	l.add_theme_constant_override("outline_size", 0)
	var fv: FontVariation = FontVariation.new()
	fv.base_font = body(800)
	fv.spacing_glyph = 2
	l.add_theme_font_override("font", fv)
	return l
