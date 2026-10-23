class_name MeterView
extends MeterViewPort
## Multímetro con display LCD. Equivale a `MeterView.ts`.

var root: PanelContainer
var visible_now: bool = false

var _value: Label
var _unit: Label
var _note: Label
var _screen_bg: StyleBoxFlat


func _init() -> void:
	root = PanelContainer.new()
	root.name = "hud-meter"
	var outer: StyleBoxFlat = StyleBoxFlat.new()
	outer.bg_color = Color(0.1, 0.1, 0.1, 0.92)
	outer.corner_radius_top_left = 14
	outer.corner_radius_top_right = 14
	outer.corner_radius_bottom_left = 14
	outer.corner_radius_bottom_right = 14
	outer.content_margin_left = 14
	outer.content_margin_right = 14
	outer.content_margin_top = 10
	outer.content_margin_bottom = 10
	root.add_theme_stylebox_override("panel", outer)
	root.visible = false
	root.custom_minimum_size = Vector2(220, 0)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	root.add_child(col)

	var screen: PanelContainer = PanelContainer.new()
	_screen_bg = StyleBoxFlat.new()
	_screen_bg.bg_color = Color("#9fe8b0").darkened(0.3)
	_screen_bg.corner_radius_top_left = 8
	_screen_bg.corner_radius_top_right = 8
	_screen_bg.corner_radius_bottom_left = 8
	_screen_bg.corner_radius_bottom_right = 8
	_screen_bg.content_margin_left = 10
	_screen_bg.content_margin_right = 10
	_screen_bg.content_margin_top = 6
	_screen_bg.content_margin_bottom = 6
	screen.add_theme_stylebox_override("panel", _screen_bg)
	var screen_col: VBoxContainer = VBoxContainer.new()
	_value = Label.new()
	_value.text = "--- V"
	_value.add_theme_font_size_override("font_size", 26)
	_value.add_theme_color_override("font_color", Color("#0e2420"))
	screen_col.add_child(_value)
	_unit = Label.new()
	_unit.text = "V⎓ CC"
	_unit.add_theme_color_override("font_color", Color("#0e2420"))
	screen_col.add_child(_unit)
	screen.add_child(screen_col)
	col.add_child(screen)

	_note = Label.new()
	_note.text = "Acercate a la caja de conexión o a un panel y tocá Medir."
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(220, 0)
	col.add_child(_note)


func show() -> void:
	root.visible = true
	visible_now = true


func hide() -> void:
	root.visible = false
	visible_now = false


## `value`: "38,4 V" o "--- V"; `unit`: "V⎓ CC"; `note`: explicación breve. `state`: "idle"|"ok"|"bad".
func set_reading(value: String, unit: String, note: String, state: StringName = &"idle") -> void:
	_value.text = value
	_unit.text = unit
	_note.text = note
	match state:
		&"ok":
			_screen_bg.bg_color = Color("#9fe8b0")
		&"bad":
			_screen_bg.bg_color = Color("#ff9f8f")
		_:
			_screen_bg.bg_color = Color("#9fe8b0").darkened(0.3)
