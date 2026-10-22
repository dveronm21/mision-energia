class_name LobbyStyle
extends RefCounted
## Paleta, fuentes, cajas e íconos de la sala de espera del tele (misma estética que lobbyStyles.ts).
## Medidas en unidades de la base 1280×720 (stretch canvas_items): U = 1% del alto.

const U: float = 7.2
const SUN := Color("#FFB82E")
const SUN_DARK := Color("#B9781A")
const INK := Color("#10231F")
const HUD := Color("#0E2420")
const HUD2 := Color("#1F3D37")
const LINE := Color("#2F5A51")
const MUTED := Color("#C3D6D0")
const LEAF := Color("#3FA34D")
const WARN := Color("#FFD27A")
const ORANGE := Color("#F28C28")
const DISABLED_BG := Color("#3B5751")
const DISABLED_FG := Color("#9DB3AD")
const DISABLED_SHADOW := Color("#24403A")

const FONT_DIR: String = "res://assets/fonts/"

static var _fonts: Dictionary = {}
static var _icons: Dictionary = {}


## Fuente del juego: "fredoka-600", "fredoka-700", "nunito-700", "nunito-800", "mono".
static func font(key: String) -> Font:
	if _fonts.has(key):
		return _fonts[key]
	var files: Dictionary = {
		"fredoka-600": "fredoka-latin-600-normal.woff2", "fredoka-700": "fredoka-latin-700-normal.woff2",
		"nunito-700": "nunito-latin-700-normal.woff2", "nunito-800": "nunito-latin-800-normal.woff2",
		"mono": "share-tech-mono-latin-400-normal.woff2",
	}
	var f: Font = null
	var path: String = FONT_DIR + String(files.get(key, ""))
	if ResourceLoader.exists(path):
		f = load(path) as Font
	if f == null:
		f = ThemeDB.fallback_font
	_fonts[key] = f
	return f


static func px(units: float) -> int:
	return int(roundf(units * U))


static func box(bg: Color, radius: float, border: Color = Color.TRANSPARENT, border_w: int = 0,
		shadow: Color = Color.TRANSPARENT, shadow_y: float = 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.draw_center = bg.a > 0.0
	s.set_corner_radius_all(int(radius))
	s.corner_detail = 12
	s.anti_aliasing = true
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	if shadow.a > 0.0:
		s.shadow_color = shadow
		s.shadow_offset = Vector2(0, shadow_y)
		s.shadow_size = 1
	return s


## Anillo blanco bien visible alrededor del elemento con foco (D-pad), opcionalmente con brillo.
static func focus_ring(radius: float, glow: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.border_color = Color.WHITE
	s.set_border_width_all(px(0.7))
	s.set_corner_radius_all(int(radius + px(0.8)))
	s.set_expand_margin_all(px(0.9))
	s.corner_detail = 12
	s.anti_aliasing = true
	if glow.a > 0.0:
		s.shadow_color = glow
		s.shadow_size = px(3.0)
	return s


## Ícono vectorial (SVG) rasterizado: "play", "back", "close".
static func icon(icon_name: String, size_px: int, color: Color) -> Texture2D:
	var key: String = "%s|%d|%s" % [icon_name, size_px, color.to_html(false)]
	if _icons.has(key):
		return _icons[key]
	var c: String = "#" + color.to_html(false)
	var body: String
	match icon_name:
		"play":
			body = "<path d='M7 4.5v15a1 1 0 0 0 1.5.86l12.5-7.5a1 1 0 0 0 0-1.72L8.5 3.64A1 1 0 0 0 7 4.5z' fill='%s'/>" % c
		"back":
			body = "<path d='M15 4 7 12l8 8' fill='none' stroke='%s' stroke-width='3' stroke-linecap='round' stroke-linejoin='round'/>" % c
		_:
			body = "<path d='M6 6l12 12M18 6 6 18' fill='none' stroke='%s' stroke-width='3' stroke-linecap='round'/>" % c
	var svg: String = "<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24'>%s</svg>" % body
	var img := Image.new()
	img.load_svg_from_string(svg, float(size_px) / 24.0)
	var tex := ImageTexture.create_from_image(img)
	_icons[key] = tex
	return tex


static func style_label(l: Label, font_key: String, size_units: float, color: Color = Color.WHITE) -> void:
	l.add_theme_font_override("font", font(font_key))
	l.add_theme_font_size_override("font_size", px(size_units))
	l.add_theme_color_override("font_color", color)


## Botón grande redondeado. kind: "primary" (sol), "secondary" (verde oscuro) o "ghost" (contorno).
static func style_button(b: Button, kind: String, font_size_units: float, height_units: float, pad_units: float) -> void:
	var r: float = px(height_units) / 2.0
	var normal: StyleBoxFlat
	var disabled: StyleBoxFlat
	var fg := Color.WHITE
	var glow := Color.TRANSPARENT
	match kind:
		"primary":
			normal = box(SUN, r, Color.TRANSPARENT, 0, SUN_DARK, px(0.9))
			disabled = box(DISABLED_BG, r, Color.TRANSPARENT, 0, DISABLED_SHADOW, px(0.9))
			fg = INK
			glow = Color(SUN, 0.55)
		"secondary":
			normal = box(HUD2, r, LINE, px(0.35))
			disabled = normal
		_:
			normal = box(Color.TRANSPARENT, r, Color(1, 1, 1, 0.45), px(0.35))
			disabled = normal
	for st: StyleBoxFlat in [normal, disabled]:
		st.content_margin_left = px(pad_units)
		st.content_margin_right = px(pad_units)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.08) if normal.draw_center else Color(1, 1, 1, 0.08)
	hover.draw_center = true
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = normal.bg_color.darkened(0.08) if normal.draw_center else Color(1, 1, 1, 0.14)
	pressed.draw_center = true
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("disabled", disabled)
	b.add_theme_stylebox_override("focus", focus_ring(r, glow))
	b.add_theme_font_override("font", font("fredoka-700" if kind != "ghost" else "nunito-800"))
	b.add_theme_font_size_override("font_size", px(font_size_units))
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, fg)
	b.add_theme_color_override("font_disabled_color", DISABLED_FG)
	b.add_theme_constant_override("h_separation", px(1.4))
	b.custom_minimum_size.y = px(height_units)
	b.focus_mode = Control.FOCUS_ALL
