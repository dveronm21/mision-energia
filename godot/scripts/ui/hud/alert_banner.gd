class_name AlertBanner
extends AlertBannerPort
## Alerta grande (viento Zonda) con cuenta regresiva opcional. Equivale a `AlertBanner.ts`.

var root: PanelContainer
var visible_now: bool = false

var _title: Label
var _text: Label
var _count: Label
var _bg: StyleBoxFlat
var _pulse: Tween = null

const WARM: Color = Color("#ffd27a")
const URGENT_BG: Color = Color("#4a2a0e")
## Callable(height_px: float) -> void, opcional: para que quien integre corra otros carteles.
var on_resize: Callable


func _init() -> void:
	root = PanelContainer.new()
	root.name = "hud-alert"
	# `.hud-alert`: fondo tierra con borde de sol de 3 px.
	_bg = UiTheme.box(UiTheme.DUST, 18, 3, UiTheme.SUN)
	_bg.content_margin_left = 16
	_bg.content_margin_right = 16
	_bg.content_margin_top = 10
	_bg.content_margin_bottom = 10
	root.add_theme_stylebox_override("panel", _bg)
	root.visible = false

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var ic: HudIcon = HudIcon.new(&"wind", 34.0, UiTheme.SUN)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)

	var body: VBoxContainer = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	_title = UiTheme.label("¡Alerta de viento Zonda!", UiTheme.display(700), 20, WARM)
	body.add_child(_title)
	_text = UiTheme.label("", UiTheme.body(700), 14)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_text)
	row.add_child(body)

	_count = UiTheme.label("", UiTheme.display(700), 26, UiTheme.SUN)
	_count.custom_minimum_size.x = 54
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_count.visible = false
	row.add_child(_count)
	root.add_child(row)


## `seconds_left_or_null`: null oculta la cuenta regresiva.
func show(title: String, text: String, seconds_left_or_null: Variant) -> void:
	_title.text = title
	_text.text = text
	set_countdown(seconds_left_or_null)
	root.visible = true
	visible_now = true
	if on_resize.is_valid():
		on_resize.call(root.size.y)


func set_countdown(seconds_left_or_null: Variant) -> void:
	if seconds_left_or_null == null:
		_count.visible = false
		_set_urgent(false)
		return
	var seconds_left: float = seconds_left_or_null
	_count.visible = true
	_count.text = UiFormat.fmt_clock(seconds_left)
	_set_urgent(seconds_left <= 5.0)


## `.is-urgent` (`@keyframes alertPulse`): borde y fondo laten hacia naranja cada 0,8 s.
func _set_urgent(on: bool) -> void:
	if on == (_pulse != null):
		return
	if _pulse != null:
		_pulse.kill()
		_pulse = null
		_bg.border_color = UiTheme.SUN
		_bg.bg_color = UiTheme.DUST
	if on and root.is_inside_tree():
		_pulse = root.create_tween().set_loops()
		_pulse.tween_method(_pulse_step, 0.0, 1.0, 0.8).set_trans(Tween.TRANS_SINE)
		_pulse.tween_method(_pulse_step, 1.0, 0.0, 0.8).set_trans(Tween.TRANS_SINE)


func _pulse_step(k: float) -> void:
	_bg.border_color = UiTheme.SUN.lerp(UiTheme.WARN, k)
	_bg.bg_color = UiTheme.DUST.lerp(URGENT_BG, k)


func hide() -> void:
	_set_urgent(false)
	root.visible = false
	visible_now = false
	if on_resize.is_valid():
		on_resize.call(0.0)
