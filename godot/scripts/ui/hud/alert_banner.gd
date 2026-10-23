class_name AlertBanner
extends AlertBannerPort
## Alerta grande (viento Zonda) con cuenta regresiva opcional. Equivale a `AlertBanner.ts`.

var root: PanelContainer
var visible_now: bool = false

var _title: Label
var _text: Label
var _count: Label
## Callable(height_px: float) -> void, opcional: para que quien integre corra otros carteles.
var on_resize: Callable


func _init() -> void:
	root = PanelContainer.new()
	root.name = "hud-alert"
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color("#b9781a").lerp(Color.BLACK, 0.35)
	bg.bg_color.a = 0.95
	bg.corner_radius_top_left = 16
	bg.corner_radius_top_right = 16
	bg.corner_radius_bottom_left = 16
	bg.corner_radius_bottom_right = 16
	bg.content_margin_left = 16
	bg.content_margin_right = 16
	bg.content_margin_top = 10
	bg.content_margin_bottom = 10
	root.add_theme_stylebox_override("panel", bg)
	root.visible = false

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(HudIcon.new(&"hint", 34.0))

	var body: VBoxContainer = VBoxContainer.new()
	_title = Label.new()
	_title.text = "¡Alerta de viento Zonda!"
	_title.add_theme_font_size_override("font_size", 16)
	body.add_child(_title)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(_text)
	row.add_child(body)

	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 20)
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
		return
	var seconds_left: float = seconds_left_or_null
	_count.visible = true
	_count.text = UiFormat.fmt_clock(seconds_left)
	_count.add_theme_color_override("font_color", VisualMaterials.C_BAD if seconds_left <= 5.0 else Color.WHITE)


func hide() -> void:
	root.visible = false
	visible_now = false
	if on_resize.is_valid():
		on_resize.call(0.0)
