class_name SettingsScreen
extends UiScreen
## Ajustes: calidad gráfica, sonido, reinicio de progreso con confirmación escrita, versión y
## créditos. Equivale a `SettingsScreen.ts`.

const CONFIRM_WORD: String = "BORRAR"

var _deps: SettingsDeps
var _quality: StringName
var _q_buttons: Dictionary[StringName, Button] = {}
var _sound_knob: ColorRect
var _sound_btn: Button
var _reset_box: VBoxContainer


func _init(deps: SettingsDeps) -> void:
	_deps = deps
	_quality = deps.quality

	var seg: HBoxContainer = HBoxContainer.new()
	seg.add_theme_constant_override("separation", 6)
	for pair: Array in [[SettingsDeps.QUALITY_LOW, "Baja"], [SettingsDeps.QUALITY_MEDIUM, "Media"], [SettingsDeps.QUALITY_HIGH, "Alta"]]:
		var q: StringName = pair[0]
		var b: Button = Button.new()
		b.text = pair[1]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(70, 36)
		b.pressed.connect(_set_quality.bind(q))
		_q_buttons[q] = b
		seg.add_child(b)

	_sound_btn = Button.new()
	_sound_btn.custom_minimum_size = Vector2(56, 30)
	_sound_knob = ColorRect.new()
	_sound_knob.custom_minimum_size = Vector2(22, 22)
	var knob_center: CenterContainer = CenterContainer.new()
	knob_center.add_child(_sound_knob)
	_sound_btn.add_child(knob_center)
	_sound_btn.pressed.connect(_toggle_sound)

	_reset_box = VBoxContainer.new()
	_reset_box.add_theme_constant_override("separation", 10)

	var about: VBoxContainer = VBoxContainer.new()
	var about1: Label = Label.new()
	about1.text = "Misión Energía · versión %s" % deps.version
	about1.add_theme_font_size_override("font_size", 12)
	about1.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	about.add_child(about1)
	var about2: Label = Label.new()
	about2.text = "Hecho por Inkfusion · San Juan"
	about2.add_theme_font_size_override("font_size", 12)
	about2.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	about.add_child(about2)

	var list: Array[Control] = [_row(&"gear", "Calidad gráfica", "Si el juego va lento, probá con Baja.", seg)]
	if deps.audio != null:
		list.append(_row(&"sound", "Sonido", "Efectos y viento.", _sound_btn))
	list.append(_reset_box)
	list.append(about)

	var frame: PageFrame = UiCommon.page_frame({"title": "Ajustes", "on_back": deps.on_back, "body": list})
	root = frame.root
	_paint_quality()
	_paint_sound()
	_render_reset(false)


func _row(icon_name: StringName, title: String, sub: String, control: Control) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(HudIcon.new(icon_name, 24.0))
	var txt: VBoxContainer = VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t: Label = Label.new()
	t.text = title
	txt.add_child(t)
	var s: Label = Label.new()
	s.text = sub
	s.add_theme_font_size_override("font_size", 12)
	s.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	txt.add_child(s)
	row.add_child(txt)
	row.add_child(control)
	return row


func on_back() -> bool:
	if _deps.on_back.is_valid():
		_deps.on_back.call()
	return true


func _set_quality(q: StringName) -> void:
	_quality = q
	_paint_quality()
	if _deps.on_quality_change.is_valid():
		_deps.on_quality_change.call(q)


func _paint_quality() -> void:
	for q: StringName in _q_buttons.keys():
		var b: Button = _q_buttons[q]
		b.button_pressed = (q == _quality)
		var bg: StyleBoxFlat = StyleBoxFlat.new()
		bg.corner_radius_top_left = 8
		bg.corner_radius_top_right = 8
		bg.corner_radius_bottom_left = 8
		bg.corner_radius_bottom_right = 8
		bg.bg_color = VisualMaterials.C_SUN if q == _quality else Color(1, 1, 1, 0.08)
		b.add_theme_stylebox_override("normal", bg)
		b.add_theme_color_override("font_color", Color("#0e2420") if q == _quality else Color.WHITE)


func _toggle_sound() -> void:
	var a: AudioSynth = _deps.audio
	if a == null:
		return
	a.set_muted(not a.is_muted())
	_paint_sound()


func _paint_sound() -> void:
	var on: bool = _deps.audio == null or not _deps.audio.is_muted()
	_sound_knob.color = VisualMaterials.C_OK if on else Color(1, 1, 1, 0.3)


func _render_reset(open: bool) -> void:
	for c: Node in _reset_box.get_children():
		c.queue_free()
	var head: Control
	if open:
		head = _row(&"retry", "Reiniciar progreso", "Borra niveles, estrellas, Soles y compras guardadas.", Control.new())
	else:
		head = _row(&"retry", "Reiniciar progreso", "Borra niveles, estrellas, Soles y compras guardadas.",
			UiCommon.action_button("Reiniciar", func() -> void: _render_reset(true), &"ghost"))
	_reset_box.add_child(head)
	if not open:
		return

	var confirm_col: VBoxContainer = VBoxContainer.new()
	confirm_col.add_theme_constant_override("separation", 8)
	var label: Label = Label.new()
	label.text = "Para confirmar escribí %s" % CONFIRM_WORD
	confirm_col.add_child(label)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var input: LineEdit = LineEdit.new()
	input.placeholder_text = CONFIRM_WORD
	input.max_length = 12
	input.custom_minimum_size = Vector2(160, 0)
	row.add_child(input)
	row.add_child(UiCommon.action_button("Cancelar", func() -> void: _render_reset(false), &"ghost"))
	var go: Button = UiCommon.action_button("Borrar todo", Callable(), &"danger")
	go.disabled = true
	go.pressed.connect(func() -> void:
		if input.text.strip_edges().to_upper() != CONFIRM_WORD:
			return
		if _deps.on_reset_progress.is_valid():
			_deps.on_reset_progress.call()
		for c: Node in _reset_box.get_children():
			c.queue_free()
		_reset_box.add_child(_row(&"check", "Progreso reiniciado", "Empezás de cero.", Control.new())))
	input.text_changed.connect(func(_t: String) -> void:
		go.disabled = input.text.strip_edges().to_upper() != CONFIRM_WORD)
	row.add_child(go)
	confirm_col.add_child(row)
	_reset_box.add_child(confirm_col)
	input.grab_focus()
