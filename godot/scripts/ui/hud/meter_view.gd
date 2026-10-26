class_name MeterView
extends MeterViewPort
## Multímetro con display LCD. Equivale a `MeterView.ts` y `.hud-meter` de styles.ts: carcasa
## amarilla con borde ocre y sombra dura, pantalla verdosa con marco negro y lectura en
## Share Tech Mono (verde si está bien, salmón si hay problema).

const LCD_IDLE: Color = Color("#c9d8b6")
const LCD_OK: Color = Color("#bfe3b4")
const LCD_BAD: Color = Color("#f3c6a5")
const LCD_INK: Color = Color("#1a1a1a")

var root: PanelContainer
var visible_now: bool = false

var _value: Label
var _unit: Label
var _note: Label
var _screen_bg: StyleBoxFlat


func _init() -> void:
	root = PanelContainer.new()
	root.name = "hud-meter"
	var outer: StyleBoxFlat = UiTheme.box(UiTheme.SUN, 26, 5, UiTheme.SUN_DARK)
	outer.set_content_margin_all(14)
	outer.shadow_color = Color(0, 0, 0, 0.25)
	outer.shadow_size = 0
	outer.shadow_offset = Vector2(0, 8)
	root.add_theme_stylebox_override("panel", outer)
	root.visible = false
	root.custom_minimum_size = Vector2(250, 0)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	root.add_child(col)

	var screen: PanelContainer = PanelContainer.new()
	_screen_bg = UiTheme.box(LCD_IDLE, 12, 4, Color("#2a2a2a"))
	_screen_bg.content_margin_left = 12
	_screen_bg.content_margin_right = 12
	_screen_bg.content_margin_top = 8
	_screen_bg.content_margin_bottom = 8
	screen.add_theme_stylebox_override("panel", _screen_bg)
	var screen_col: VBoxContainer = VBoxContainer.new()
	screen_col.add_theme_constant_override("separation", 4)
	_value = UiTheme.label("---", UiTheme.mono(), 38, LCD_INK)
	_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	screen_col.add_child(_value)
	_unit = UiTheme.label("multímetro", UiTheme.mono(), 14, LCD_INK)
	_unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	screen_col.add_child(_unit)
	screen.add_child(screen_col)
	col.add_child(screen)

	_note = UiTheme.label("Acercate a la caja de conexión o a un panel y tocá Medir.", UiTheme.body(800), 14, UiTheme.INK)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(222, 0)
	col.add_child(_note)


func show() -> void:
	if not root.visible:
		UiCommon.pop_in(root, 0.85, 0.3)
	root.visible = true
	visible_now = true


func hide() -> void:
	root.visible = false
	visible_now = false


## `value`: "OK", "FALLA" o "---"; `unit`: "por fila"; `note`: explicación breve. `state`: "idle"|"ok"|"bad".
func set_reading(value: String, unit: String, note: String, state: StringName = &"idle") -> void:
	var changed: bool = _value.text != value
	_value.text = value
	# Con 3 o 4 filas ("F1 OK  F2 FALLA  F3 OK…") la lectura se achica para entrar en el display.
	_value.add_theme_font_size_override("font_size", 38 if value.length() <= 14 else (28 if value.length() <= 22 else 22))
	_unit.text = unit
	_note.text = note
	match state:
		&"ok":
			_screen_bg.bg_color = LCD_OK
		&"bad":
			_screen_bg.bg_color = LCD_BAD
		_:
			_screen_bg.bg_color = LCD_IDLE
	# La lectura nueva "parpadea" como un display real al estabilizarse.
	if changed and value != "---" and _value.is_inside_tree():
		_value.modulate.a = 0.25
		_value.create_tween().tween_property(_value, "modulate:a", 1.0, 0.18)
