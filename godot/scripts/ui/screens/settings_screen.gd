class_name SettingsScreen
extends UiScreen
## Ajustes: calidad gráfica, sonido, reinicio de progreso con confirmación escrita, versión y
## créditos. Equivale a `SettingsScreen.ts` y `.set-*` de styles.ts: filas en tarjetas verdes,
## selector de calidad en píldora, interruptor de sonido y confirmación en rojo.

const CONFIRM_WORD: String = "BORRAR"
const LIST_W: float = 760.0
const SWITCH_OFF: Color = Color("#5d736e")
const DANGER_ICON: Color = Color("#ff9c8f")

var _deps: SettingsDeps
var _quality: StringName
var _q_buttons: Dictionary[StringName, Button] = {}
var _sound_btn: Button
var _switch: Control
var _knob_x: float = 0.0
var _reset_box: VBoxContainer


func _init(deps: SettingsDeps) -> void:
	_deps = deps
	_quality = deps.quality

	# `.seg`: píldora oscura con las tres opciones.
	var seg_panel: PanelContainer = PanelContainer.new()
	var seg_bg: StyleBoxFlat = UiTheme.box(Color(0, 0, 0, 0.3), 999)
	seg_bg.set_content_margin_all(4)
	seg_panel.add_theme_stylebox_override("panel", seg_bg)
	seg_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var seg: HBoxContainer = HBoxContainer.new()
	seg.add_theme_constant_override("separation", 4)
	for pair: Array in [[SettingsDeps.QUALITY_LOW, "Baja"], [SettingsDeps.QUALITY_MEDIUM, "Media"], [SettingsDeps.QUALITY_HIGH, "Alta"]]:
		var q: StringName = pair[0]
		var b: Button = Button.new()
		b.text = pair[1]
		b.custom_minimum_size = Vector2(72, 48)
		b.add_theme_font_override("font", UiTheme.display(600))
		b.add_theme_font_size_override("font_size", 17)
		b.pressed.connect(_set_quality.bind(q))
		_q_buttons[q] = b
		seg.add_child(b)
	seg_panel.add_child(seg)

	# `.switch`: 72×48 con riel y perilla que se desliza.
	_sound_btn = Button.new()
	_sound_btn.custom_minimum_size = Vector2(72, 48)
	_sound_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiTheme.style_button(_sound_btn, StyleBoxEmpty.new())
	_switch = Control.new()
	_switch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_switch.set_anchors_preset(Control.PRESET_FULL_RECT)
	_switch.draw.connect(_draw_switch)
	_sound_btn.add_child(_switch)
	_sound_btn.pressed.connect(_toggle_sound)

	_reset_box = VBoxContainer.new()
	_reset_box.add_theme_constant_override("separation", 8)

	var about: VBoxContainer = VBoxContainer.new()
	about.add_theme_constant_override("separation", 2)
	var about_pad: MarginContainer = UiCommon._margins(0, 12, 0, 4)
	for line: String in ["Misión Energía · versión %s" % deps.version, "Hecho por Inkfusion · San Juan"]:
		var l: Label = UiTheme.label(line, UiTheme.body(700), 14, UiTheme.MUTED)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		about.add_child(l)
	about_pad.add_child(about)

	# `.set-list`: columna centrada de hasta 760 px.
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.custom_minimum_size.x = LIST_W
	list.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	list.add_child(_row(&"gear", "Calidad gráfica", "Si el juego va lento, probá con Baja.", seg_panel))
	if deps.audio != null:
		list.add_child(_row(&"sound", "Sonido", "Efectos y viento.", _sound_btn))
	list.add_child(_reset_box)
	list.add_child(about_pad)

	var frame: PageFrame = UiCommon.page_frame({"title": "Ajustes", "on_back": deps.on_back, "body": [list]})
	root = frame.root
	_paint_quality()
	_knob_x = 1.0 if _sound_on() else 0.0
	_render_reset(false)


## `.set-row`: tarjeta verde oscura con ícono en recuadro, título, ayuda y el control a la derecha.
func _row(icon_name: StringName, title: String, sub: String, control: Control, danger: bool = false) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var bg: StyleBoxFlat = UiTheme.box(UiTheme.HUD_2, 16, 1, UiTheme.HUD_LINE)
	bg.content_margin_left = 14
	bg.content_margin_right = 14
	bg.content_margin_top = 10
	bg.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", bg)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var ic: PanelContainer = PanelContainer.new()
	ic.custom_minimum_size = Vector2(44, 44)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 1, 1, 0.07), 12))
	var ic_c: CenterContainer = CenterContainer.new()
	ic_c.add_child(HudIcon.new(icon_name, 24.0, DANGER_ICON if danger else UiTheme.SUN))
	ic.add_child(ic_c)
	row.add_child(ic)
	var txt: VBoxContainer = VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.alignment = BoxContainer.ALIGNMENT_CENTER
	txt.add_theme_constant_override("separation", 0)
	txt.add_child(UiTheme.label(title, UiTheme.display(600), 18))
	var s: Label = UiTheme.label(sub, UiTheme.body(700), 14, UiTheme.MUTED)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.add_child(s)
	row.add_child(txt)
	if control != null:
		row.add_child(control)
	panel.add_child(row)
	return panel


func on_enter() -> void:
	UiCommon.focus_later(_q_buttons[_quality] as Button)


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
		var on: bool = q == _quality
		UiTheme.style_button(b, UiTheme.box(UiTheme.SUN if on else Color.TRANSPARENT, 999))
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(state, UiTheme.INK if on else UiTheme.FG)


func _sound_on() -> bool:
	return _deps.audio == null or not _deps.audio.is_muted()


func _toggle_sound() -> void:
	var a: AudioSynth = _deps.audio
	if a == null:
		return
	a.set_muted(not a.is_muted())
	var t: Tween = _switch.create_tween()
	t.tween_method(func(v: float) -> void:
		_knob_x = v
		_switch.queue_redraw(), _knob_x, 1.0 if _sound_on() else 0.0, 0.15)


func _draw_switch() -> void:
	var sz: Vector2 = _switch.size
	var track: Rect2 = Rect2(Vector2(4, 8), Vector2(sz.x - 8, sz.y - 16))
	var col: Color = SWITCH_OFF.lerp(UiTheme.LEAF_DARK, _knob_x)
	var r: float = track.size.y / 2.0
	_switch.draw_circle(track.position + Vector2(r, r), r, col, true, -1.0, true)
	_switch.draw_circle(track.end - Vector2(r, r), r, col, true, -1.0, true)
	_switch.draw_rect(Rect2(track.position + Vector2(r, 0), Vector2(track.size.x - 2.0 * r, track.size.y)), col)
	var knob_r: float = 12.0
	var x: float = lerpf(10.0 + knob_r, 38.0 + knob_r, _knob_x)
	_switch.draw_circle(Vector2(x, sz.y / 2.0), knob_r, Color.WHITE, true, -1.0, true)


func _render_reset(open: bool) -> void:
	for c: Node in _reset_box.get_children():
		c.queue_free()
	var sub: String = "Borra niveles, estrellas, Soles y compras guardadas."
	var head: Control
	if open:
		head = _row(&"retry", "Reiniciar progreso", sub, null, true)
	else:
		head = _row(&"retry", "Reiniciar progreso", sub,
			UiCommon.action_button("Reiniciar", func() -> void: _render_reset(true), &"ghost"), true)
	_reset_box.add_child(head)
	if not open:
		return

	# `.set-confirm`: caja rojiza con la palabra a escribir.
	var box: PanelContainer = PanelContainer.new()
	var bg: StyleBoxFlat = UiTheme.box(Color(179.0 / 255.0, 38.0 / 255.0, 30.0 / 255.0, 0.16), 16, 1, Color("#6e1712"))
	bg.content_margin_left = 14
	bg.content_margin_right = 14
	bg.content_margin_top = 10
	bg.content_margin_bottom = 10
	box.add_theme_stylebox_override("panel", bg)
	var confirm_col: VBoxContainer = VBoxContainer.new()
	confirm_col.add_theme_constant_override("separation", 8)
	confirm_col.add_child(UiTheme.label("Para confirmar escribí %s" % CONFIRM_WORD, UiTheme.body(700), 15))

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var input: LineEdit = LineEdit.new()
	input.placeholder_text = CONFIRM_WORD
	input.max_length = 12
	input.custom_minimum_size = Vector2(170, 48)
	var in_bg: StyleBoxFlat = UiTheme.box(Color.WHITE, 12, 2, Color.WHITE)
	in_bg.content_margin_left = 12
	in_bg.content_margin_right = 12
	input.add_theme_stylebox_override("normal", in_bg)
	input.add_theme_stylebox_override("focus", UiTheme.box(Color.TRANSPARENT, 12, 3, UiTheme.SUN))
	input.add_theme_font_override("font", UiTheme.body(800))
	input.add_theme_font_size_override("font_size", 20)
	input.add_theme_color_override("font_color", UiTheme.INK)
	input.add_theme_color_override("font_placeholder_color", Color(UiTheme.INK, 0.35))
	input.add_theme_color_override("caret_color", UiTheme.INK)
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
		_reset_box.add_child(_row(&"check", "Progreso reiniciado", "Empezás de cero.", null)))
	input.text_changed.connect(func(_t: String) -> void:
		go.disabled = input.text.strip_edges().to_upper() != CONFIRM_WORD)
	row.add_child(go)
	confirm_col.add_child(row)
	box.add_child(confirm_col)
	_reset_box.add_child(box)
	UiCommon.focus_later(input)
