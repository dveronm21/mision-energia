class_name InspectCard
extends InspectCardPort
## Ficha de "Revisar": qué es el equipo y cómo está funcionando (dato en vivo opcional).
## Equivale a `InspectCard.ts`.

var root: PanelContainer

var _title: Label
var _body: Label
var _live: Label
## Callable() -> void, opcional.
var on_close: Callable


func _init() -> void:
	root = PanelContainer.new()
	root.name = "hud-inspect"
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.055, 0.141, 0.125, 0.94)
	bg.corner_radius_top_left = 16
	bg.corner_radius_top_right = 16
	bg.corner_radius_bottom_left = 16
	bg.corner_radius_bottom_right = 16
	bg.content_margin_left = 18
	bg.content_margin_right = 18
	bg.content_margin_top = 12
	bg.content_margin_bottom = 14
	root.add_theme_stylebox_override("panel", bg)
	root.visible = false
	root.custom_minimum_size = Vector2(320, 0)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	root.add_child(col)

	var head: HBoxContainer = HBoxContainer.new()
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 17)
	_title.add_theme_color_override("font_color", VisualMaterials.C_SUN)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var close: Button = Button.new()
	close.custom_minimum_size = Vector2(28, 28)
	close.add_child(HudIcon.new(&"close", 16.0))
	close.pressed.connect(_on_close_pressed)
	head.add_child(close)
	col.add_child(head)

	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_body)

	_live = Label.new()
	_live.add_theme_color_override("font_color", VisualMaterials.C_SUN)
	_live.visible = false
	col.add_child(_live)


func _on_close_pressed() -> void:
	hide()
	if on_close.is_valid():
		on_close.call()


## `info`: {"title": String, "body": String, "live": String | null}.
func show(info: Dictionary) -> void:
	_title.text = info.get("title", "")
	_body.text = info.get("body", "")
	update_live(info.get("live", null))
	root.visible = true
	visible = true


func update_live(text: Variant) -> void:
	_live.visible = text != null
	if text != null:
		_live.text = text


func hide() -> void:
	root.visible = false
	visible = false
