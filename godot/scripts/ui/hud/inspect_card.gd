class_name InspectCard
extends InspectCardPort
## Ficha de "Revisar": qué es el equipo y cómo está funcionando (dato en vivo opcional).
## Equivale a `InspectCard.ts` y `.hud-inspect` de styles.ts: tarjeta blanca de 440 px, título
## Fredoka, texto y el dato en vivo en una franja verde clara; cruz redonda para cerrar.

var root: PanelContainer

var _title: Label
var _body: Label
var _live: Label
var _live_box: PanelContainer
## Callable() -> void, opcional.
var on_close: Callable


func _init() -> void:
	root = PanelContainer.new()
	root.name = "hud-inspect"
	var bg: StyleBoxFlat = UiTheme.card(18, 0.0, 8)
	bg.shadow_color = Color(UiTheme.INK, 0.25)
	bg.content_margin_left = 18
	bg.content_margin_right = 4
	bg.content_margin_top = 4
	bg.content_margin_bottom = 16
	root.add_theme_stylebox_override("panel", bg)
	root.visible = false
	root.custom_minimum_size = Vector2(440, 0)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	root.add_child(col)

	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	_title = UiTheme.title("", 22, UiTheme.INK)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var title_pad: MarginContainer = UiCommon._margins(0, 10, 0, 0)
	title_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_pad.add_child(_title)
	head.add_child(title_pad)
	# `.ins-close`: 48 px de área táctil con un círculo gris claro adentro.
	var close: Button = Button.new()
	close.custom_minimum_size = Vector2(48, 48)
	close.focus_mode = Control.FOCUS_NONE
	var close_bg: StyleBoxFlat = UiTheme.box(Color("#eef2f1"), 999)
	close_bg.expand_margin_left = -6
	close_bg.expand_margin_right = -6
	close_bg.expand_margin_top = -6
	close_bg.expand_margin_bottom = -6
	UiTheme.style_button(close, close_bg)
	var cc: CenterContainer = CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.add_child(HudIcon.new(&"close", 16.0, UiTheme.INK))
	close.add_child(cc)
	close.pressed.connect(_on_close_pressed)
	head.add_child(close)
	col.add_child(head)

	var text_pad: MarginContainer = UiCommon._margins(0, 0, 14, 0)
	var text_col: VBoxContainer = VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 10)
	_body = UiTheme.label("", UiTheme.body(700), 15, UiTheme.INK_2)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_col.add_child(_body)

	_live_box = PanelContainer.new()
	var live_bg: StyleBoxFlat = UiTheme.box(Color("#e6f4ea"), 10)
	live_bg.content_margin_left = 10
	live_bg.content_margin_right = 10
	live_bg.content_margin_top = 8
	live_bg.content_margin_bottom = 8
	_live_box.add_theme_stylebox_override("panel", live_bg)
	_live = UiTheme.label("", UiTheme.body(800), 14, UiTheme.INK)
	_live.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_live_box.add_child(_live)
	_live_box.visible = false
	text_col.add_child(_live_box)
	text_pad.add_child(text_col)
	col.add_child(text_pad)


func _on_close_pressed() -> void:
	hide()
	if on_close.is_valid():
		on_close.call()


## `info`: {"title": String, "body": String, "live": String | null}.
func show(info: Dictionary) -> void:
	var was_hidden: bool = not root.visible
	_title.text = info.get("title", "")
	_body.text = info.get("body", "")
	update_live(info.get("live", null))
	root.visible = true
	visible = true
	if was_hidden:
		UiCommon.pop_in(root, 0.92, 0.28)


func update_live(text: Variant) -> void:
	_live_box.visible = text != null
	if text != null:
		_live.text = text


func hide() -> void:
	root.visible = false
	visible = false
