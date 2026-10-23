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
var _card_bg: StyleBoxFlat
var _card: PanelContainer


func _init(gate: ParentalGate) -> void:
	_gate = gate
	modal = true

	root = Control.new()
	root.name = "parental-gate"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	_card = PanelContainer.new()
	_card_bg = StyleBoxFlat.new()
	_card_bg.bg_color = Color("#13302a")
	_card_bg.corner_radius_top_left = 20
	_card_bg.corner_radius_top_right = 20
	_card_bg.corner_radius_bottom_left = 20
	_card_bg.corner_radius_bottom_right = 20
	_card_bg.content_margin_left = 26
	_card_bg.content_margin_right = 26
	_card_bg.content_margin_top = 22
	_card_bg.content_margin_bottom = 22
	_card.add_theme_stylebox_override("panel", _card_bg)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)

	var left: VBoxContainer = VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(260, 0)
	var eyebrow: Label = Label.new()
	eyebrow.text = "Sólo personas adultas"
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	left.add_child(eyebrow)
	var title: Label = Label.new()
	title.text = "Pedile ayuda a un adulto"
	title.add_theme_font_size_override("font_size", 20)
	left.add_child(title)
	_question_label = Label.new()
	_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_question_label)
	_display = Label.new()
	_display.text = "?"
	_display.add_theme_font_size_override("font_size", 34)
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var display_bg: PanelContainer = PanelContainer.new()
	var display_style: StyleBoxFlat = StyleBoxFlat.new()
	display_style.bg_color = Color(0, 0, 0, 0.3)
	display_style.corner_radius_top_left = 10
	display_style.corner_radius_top_right = 10
	display_style.corner_radius_bottom_left = 10
	display_style.corner_radius_bottom_right = 10
	display_style.content_margin_top = 8
	display_style.content_margin_bottom = 8
	display_bg.add_theme_stylebox_override("panel", display_style)
	display_bg.add_child(_display)
	left.add_child(display_bg)
	_msg = Label.new()
	_msg.add_theme_color_override("font_color", VisualMaterials.C_BAD)
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_msg)
	left.add_child(UiCommon.action_button("Cancelar", _on_cancel, &"ghost"))
	row.add_child(left)

	row.add_child(_build_keypad())
	_card.add_child(row)
	center.add_child(_card)

	root.gui_input.connect(_on_gui_input)
	_new_question()


func _build_keypad() -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var keys: Array[String] = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "del", "0", "ok"]
	for k: String in keys:
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(64, 56)
		match k:
			"del":
				var ic: CenterContainer = CenterContainer.new()
				ic.add_child(HudIcon.new(&"back", 22.0))
				b.add_child(ic)
				b.pressed.connect(_del)
			"ok":
				var ic2: CenterContainer = CenterContainer.new()
				ic2.add_child(HudIcon.new(&"check", 24.0, VisualMaterials.C_OK))
				b.add_child(ic2)
				b.pressed.connect(_submit)
			_:
				b.text = k
				b.add_theme_font_size_override("font_size", 20)
				b.pressed.connect(_type.bind(k))
		grid.add_child(b)
	return grid


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
	_display.add_theme_color_override("font_color", Color.WHITE if _typed != "" else Color(1, 1, 1, 0.4))
