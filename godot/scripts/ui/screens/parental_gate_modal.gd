class_name ParentalGateModal
extends UiScreen
## Control parental antes de pagar con dinero real: multiplicación con teclado numérico propio.
## Equivale a `ParentalGateModal.ts`. Uso típico:
##   var passed: bool = await ParentalGateModal.ask(ui.screens, gate)

## Se emite una sola vez, al salir (pasó o canceló).
signal resolved(passed: bool)

var _gate: ParentalGate
## Se asigna en `ask()`, para poder sacarse solo de la pila al resolver.
var _screens: ScreenManager
var _answer: int = 0
var _typed: String = ""
var _fails: int = 0

var _question_label: Label
var _display: Label
var _msg: Label
var _card: PanelContainer


func _init(gate: ParentalGate) -> void:
	_gate = gate
	modal = true

	root = Control.new()
	root.name = "parental-gate"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# `.pgm`: tarjeta blanca de 600 px; a la izquierda la cuenta y el visor, a la derecha el teclado.
	var content: VBoxContainer = UiCommon.modal_card(root, 600.0, 22.0, 0)
	_card = content.get_parent() as PanelContainer

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)

	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(UiTheme.eyebrow("Sólo personas adultas", UiTheme.SUN_INK))
	left.add_child(UiTheme.title("Pedile ayuda a un adulto", 24, UiTheme.INK))
	_question_label = UiTheme.label("", UiTheme.display(600), 28, UiTheme.INK)
	_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_question_label)
	# `.pgm-display`: visor con borde oscuro de 3 px.
	_display = UiTheme.label("?", UiTheme.display(700), 36, UiTheme.INK)
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var display_bg: PanelContainer = PanelContainer.new()
	display_bg.custom_minimum_size.x = 140
	display_bg.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var display_style: StyleBoxFlat = UiTheme.box(Color.WHITE, 14, 3, UiTheme.INK)
	display_style.content_margin_left = 14
	display_style.content_margin_right = 14
	display_style.content_margin_top = 4
	display_style.content_margin_bottom = 4
	display_bg.add_theme_stylebox_override("panel", display_style)
	display_bg.add_child(_display)
	left.add_child(display_bg)
	_msg = UiTheme.label("", UiTheme.body(800), 14, Color("#9a4a06"))
	_msg.custom_minimum_size.y = 20
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_msg)
	var cancel: Button = UiCommon.action_button("Cancelar", _on_cancel, &"ghost_ink")
	cancel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_child(cancel)
	row.add_child(left)

	row.add_child(_build_keypad())
	content.add_child(row)

	root.gui_input.connect(_on_gui_input)
	_new_question()


## `.pgm-keys`: teclas de 64×52 con labio; borrar en gris y aceptar en verde.
func _build_keypad() -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var keys: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "del", "0", "ok"]
	for k: String in keys:
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(64, 52)
		match k:
			"del":
				UiTheme.style_button(b, UiTheme.lipped(Color("#eef2f1"), UiTheme.LINE, 3, 14, 0, Color.TRANSPARENT, 0.0))
				b.add_child(_key_icon(&"back", UiTheme.INK))
				b.pressed.connect(_del)
			"ok":
				UiTheme.style_button(b, UiTheme.lipped(UiTheme.LEAF_DARK, Color("#1d5426"), 3, 14, 0, Color.TRANSPARENT, 0.0))
				b.add_child(_key_icon(&"check", Color.WHITE))
				b.pressed.connect(_submit)
			_:
				UiTheme.style_button(b, UiTheme.lipped(UiTheme.PAPER_2, UiTheme.LINE, 3, 14, 0, Color.TRANSPARENT, 0.0))
				b.text = k
				b.add_theme_font_override("font", UiTheme.display(700))
				b.add_theme_font_size_override("font_size", 26)
				for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
					b.add_theme_color_override(state, UiTheme.INK)
				b.pressed.connect(_type.bind(k))
		grid.add_child(b)
	return grid


static func _key_icon(icon_name: StringName, color: Color) -> CenterContainer:
	var c: CenterContainer = CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(HudIcon.new(icon_name, 22.0, color))
	return c


func _on_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed:
		return
	var e: InputEventKey = event
	if e.keycode >= KEY_0 and e.keycode <= KEY_9:
		_type(str(e.keycode - KEY_0))
	elif e.keycode == KEY_BACKSPACE:
		_del()
	elif e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
		_submit()
	elif e.keycode == KEY_ESCAPE:
		_on_cancel()


static func ask(screens: ScreenManager, gate: ParentalGate) -> bool:
	var m: ParentalGateModal = ParentalGateModal.new(gate)
	m._screens = screens
	screens.push(m)
	var passed: bool = await m.resolved
	return passed


func on_back() -> bool:
	_on_cancel()
	return true


func _on_pass() -> void:
	if _screens != null:
		_screens.remove(self)
	resolved.emit(true)


func _on_cancel() -> void:
	if _screens != null:
		_screens.remove(self)
	resolved.emit(false)


func _new_question() -> void:
	var c: ParentalChallenge = _gate.challenge()
	_answer = c.answer
	_question_label.text = c.question
	_typed = ""
	_paint()


func _type(k: String) -> void:
	if _typed.length() >= 3:
		return
	_typed += k
	_msg.text = ""
	_paint()


func _del() -> void:
	_typed = _typed.substr(0, _typed.length() - 1)
	_paint()


func _submit() -> void:
	if _typed == "":
		return
	if int(_typed) == _answer:
		_on_pass()
		return
	_fails += 1
	_shake()
	if _fails >= 3:
		_fails = 0
		_msg.text = "Probemos con otra cuenta."
		_new_question()
		_msg.text = "Probemos con otra cuenta."
	else:
		_msg.text = "No es correcto. Probá de nuevo."
		_typed = ""
		_paint()


func _shake() -> void:
	if not _card.is_inside_tree():
		return
	var base_x: float = _card.position.x
	var t: Tween = _card.create_tween()
	for i: int in 4:
		var dx: float = 8.0 if i % 2 == 0 else -8.0
		t.tween_property(_card, "position:x", base_x + dx, 0.04)
	t.tween_property(_card, "position:x", base_x, 0.04)


func _paint() -> void:
	_display.text = _typed if _typed != "" else "?"
	_display.add_theme_color_override("font_color", UiTheme.INK if _typed != "" else Color("#8fa7a1"))
