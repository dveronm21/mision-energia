class_name MissionPanel
extends MissionPanelPort
## Panel de misión (arriba a la izquierda), colapsable. Equivale a `MissionPanel.ts` y
## `.hud-mission` de styles.ts: título Fredoka, cronómetro, flecha para plegar y la lista de
## objetivos con un punto por estado (hecho = verde lleno, actual = aro de sol con halo,
## alerta = naranja, pendiente = aro gris).
## Compacto (pantallas bajas, como un teléfono): solo "N de M hechos", el paso actual y el
## siguiente, para no tapar el joystick.

const WIDTH: float = 300.0
const ALERT_TEXT: Color = Color("#ffd27a")

## Nodo de verdad: agregalo a la escena.
var root: PanelContainer

var _title: Label
var _timer: Label
var _toggle: Button
var _chevron: HudIcon
var _list: VBoxContainer
var _collapsed: bool = false
var _last_key: String = ""
var _objectives: Array[MissionObjective] = []
var _compact: bool = false
## Callable(collapsed: bool) -> void, opcional.
var on_toggle: Callable


func _init() -> void:
	root = PanelContainer.new()
	root.name = "hud-mission"
	var bg: StyleBoxFlat = UiTheme.hud_panel(16)
	bg.content_margin_left = 14
	bg.content_margin_right = 6
	bg.content_margin_top = 4
	bg.content_margin_bottom = 10
	root.add_theme_stylebox_override("panel", bg)
	root.custom_minimum_size = Vector2(WIDTH, 0)
	root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	root.add_child(col)

	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.custom_minimum_size.y = 48
	_title = UiTheme.label("Misión", UiTheme.display(700), 18)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.size_flags_vertical = Control.SIZE_FILL
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(_title)
	_timer = UiTheme.label("0:00", UiTheme.display(500), 15, UiTheme.MUTED)
	_timer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_timer)
	_toggle = Button.new()
	_toggle.custom_minimum_size = Vector2(48, 48)
	_toggle.focus_mode = Control.FOCUS_NONE
	UiTheme.style_button(_toggle, StyleBoxEmpty.new())
	var tc: CenterContainer = CenterContainer.new()
	tc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_chevron = HudIcon.new(&"back", 20.0)
	_chevron.pivot_offset = Vector2(10, 10)
	_chevron.rotation = PI / 2.0
	tc.add_child(_chevron)
	_toggle.add_child(tc)
	_toggle.pressed.connect(_on_toggle_pressed)
	head.add_child(_toggle)
	col.add_child(head)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	var list_pad: MarginContainer = MarginContainer.new()
	list_pad.add_theme_constant_override("margin_right", 8)
	list_pad.add_child(_list)
	col.add_child(list_pad)


func _on_toggle_pressed() -> void:
	set_collapsed(not _collapsed)
	if on_toggle.is_valid():
		on_toggle.call(_collapsed)


func set_title(text: String) -> void:
	_title.text = text


func set_timer(elapsed_sec: float) -> void:
	_timer.text = UiFormat.fmt_clock(elapsed_sec)


func set_timer_visible(on: bool) -> void:
	_timer.visible = on


func set_compact(on: bool) -> void:
	if on == _compact:
		return
	_compact = on
	_last_key = ""
	set_objectives(_objectives)


func set_objectives(objectives: Array[MissionObjective]) -> void:
	_objectives = objectives
	var parts: PackedStringArray = PackedStringArray([str(_compact)])
	for it: MissionObjective in objectives:
		parts.append("%s|%s" % [it.state, it.text])
	var key: String = "\n".join(parts)
	if key == _last_key:
		return
	var had_items: bool = _last_key != ""
	var previously_ok: PackedStringArray = PackedStringArray()
	for line: String in _last_key.split("\n"):
		if line.begins_with(String(MissionObjective.STATE_OK) + "|"):
			previously_ok.append(line)
	_last_key = key
	for c: Node in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	var shown: Array[MissionObjective] = _visible_items(objectives)
	if shown.size() < objectives.size():
		var done: int = 0
		for it: MissionObjective in objectives:
			if it.state == MissionObjective.STATE_OK:
				done += 1
		if done > 0:
			_list.add_child(UiTheme.label("✓ %d de %d hechos" % [done, objectives.size()], UiTheme.body(800), 13, UiTheme.LEAF))
	for it: MissionObjective in shown:
		var row: Control = _build_item(it)
		_list.add_child(row)
		# Un objetivo recién cumplido destella (premio visual inmediato).
		if had_items and it.state == MissionObjective.STATE_OK and not previously_ok.has("%s|%s" % [it.state, it.text]):
			_flash(row)


## Compacto: los dos primeros pasos sin hacer (el actual y el siguiente), más las alertas que
## aparezcan antes; si no queda nada, el último hecho.
func _visible_items(objectives: Array[MissionObjective]) -> Array[MissionObjective]:
	if not _compact:
		return objectives
	var out: Array[MissionObjective] = []
	var pending: int = 0
	for it: MissionObjective in objectives:
		if it.state == MissionObjective.STATE_OK:
			continue
		out.append(it)
		if it.state != MissionObjective.STATE_ALERT:
			pending += 1
			if pending >= 2:
				break
	if out.is_empty() and not objectives.is_empty():
		out.append(objectives[objectives.size() - 1])
	return out


static func _flash(row: Control) -> void:
	row.modulate = Color(1.6, 1.5, 0.8)
	row.create_tween().tween_property(row, "modulate", Color.WHITE, 0.6).set_trans(Tween.TRANS_SINE)


func _build_item(it: MissionObjective) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var dot: Panel = Panel.new()
	dot.custom_minimum_size = Vector2(16, 16)
	dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	dot.add_theme_stylebox_override("panel", _dot_style(it.state))
	var dot_pad: MarginContainer = MarginContainer.new()
	dot_pad.add_theme_constant_override("margin_top", 2)
	dot_pad.add_child(dot)
	row.add_child(dot_pad)
	var now: bool = it.state == MissionObjective.STATE_NOW
	var label: Label = UiTheme.label(it.text, UiTheme.body(800 if now else 700), 14, _text_color(it.state))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row


static func _dot_style(state: StringName) -> StyleBoxFlat:
	match state:
		MissionObjective.STATE_OK:
			return UiTheme.box(UiTheme.LEAF, 999, 2, UiTheme.LEAF)
		MissionObjective.STATE_ALERT:
			return UiTheme.box(UiTheme.WARN, 999, 2, UiTheme.WARN)
		MissionObjective.STATE_NOW:
			var s: StyleBoxFlat = UiTheme.box(Color.TRANSPARENT, 999, 2, UiTheme.SUN)
			s.shadow_color = Color(UiTheme.SUN, 0.3)
			s.shadow_size = 3
			return s
		_:
			return UiTheme.box(Color.TRANSPARENT, 999, 2, UiTheme.MUTED)


static func _text_color(state: StringName) -> Color:
	match state:
		MissionObjective.STATE_OK, MissionObjective.STATE_NOW:
			return UiTheme.FG
		MissionObjective.STATE_ALERT:
			return ALERT_TEXT
		_:
			return UiTheme.MUTED


func set_collapsed(c: bool) -> void:
	_collapsed = c
	_list.get_parent().visible = not c
	_chevron.rotation = -PI / 2.0 if c else PI / 2.0
	_chevron.queue_redraw()
