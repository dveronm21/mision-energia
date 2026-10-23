class_name Toast
extends ToastPort
## Aviso breve arriba al centro. Uno a la vez; el nuevo reemplaza al anterior.
## Equivale a `Toast.ts` y `.ui-toast`: tarjeta blanca (verde clara si es bueno, naranja clara si
## es malo), texto oscuro Nunito 800 y labio inferior. Entra bajando con un pequeño rebote.

const BG_INFO: Color = Color.WHITE
const BG_GOOD: Color = Color("#dff3e3")
const BG_BAD: Color = Color("#ffe7cf")

var root: PanelContainer

var _label: Label
var _timer: Timer
var _tween: Tween = null


func _init() -> void:
	root = PanelContainer.new()
	root.name = "ui-toast"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_stylebox_override("panel", _style(BG_INFO))
	root.visible = false
	_label = UiTheme.label("", UiTheme.body(800), 16, UiTheme.INK)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_label)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(hide)
	root.add_child(_timer)


static func _style(bg: Color) -> StyleBoxFlat:
	var s: StyleBoxFlat = UiTheme.box(bg, 14)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(UiTheme.INK, 0.25)
	s.shadow_size = 0
	s.shadow_offset = Vector2(0, 6)
	return s


func show(text: String, kind: StringName = &"info", ms: int = 2600) -> void:
	_timer.stop()
	_label.text = text
	# Ancho natural del texto, con tope de 460 px (después parte en renglones).
	# Sin ajuste de línea si entra en uno (un Label con autowrap calcula mal su alto mínimo).
	var w: float = UiTheme.body(800).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var wraps: bool = w > 460.0
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wraps else TextServer.AUTOWRAP_OFF
	_label.custom_minimum_size.x = 460.0 if wraps else 0.0
	root.reset_size()
	root.offset_left = -root.get_combined_minimum_size().x / 2.0
	root.offset_right = -root.offset_left
	var bg: Color = BG_INFO
	match kind:
		&"good":
			bg = BG_GOOD
		&"bad":
			bg = BG_BAD
	root.add_theme_stylebox_override("panel", _style(bg))
	root.visible = true
	if root.is_inside_tree():
		_timer.start(ms / 1000.0)
		_pop_in()


## `@keyframes toastIn`: entra desde 8 px más arriba y transparente, con un rebote corto.
func _pop_in() -> void:
	if _tween != null:
		_tween.kill()
	root.modulate.a = 0.0
	root.pivot_offset = Vector2(root.size.x / 2.0, 0.0)
	root.scale = Vector2(0.92, 0.92)
	_tween = root.create_tween().set_parallel(true)
	_tween.tween_property(root, "modulate:a", 1.0, 0.16)
	_tween.tween_property(root, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide() -> void:
	_timer.stop()
	root.visible = false
