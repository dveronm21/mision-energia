class_name MissionPanel
extends MissionPanelPort
## Panel de misión (arriba a la izquierda), colapsable. Equivale a `MissionPanel.ts`.

## Nodo de verdad: agregalo a la escena.
var root: PanelContainer

var _title: Label
var _timer: Label
var _toggle: Button
var _list: VBoxContainer
var _collapsed: bool = false
var _last_key: String = ""
## Callable(collapsed: bool) -> void, opcional.
var on_toggle: Callable


func _init() -> void:
	root = PanelContainer.new()
	root.name = "hud-mission"
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.055, 0.141, 0.125, 0.82)
	bg.corner_radius_top_left = 14
	bg.corner_radius_top_right = 14
	bg.corner_radius_bottom_left = 14
	bg.corner_radius_bottom_right = 14
	bg.content_margin_left = 14
	bg.content_margin_right = 14
	bg.content_margin_top = 10
	bg.content_margin_bottom = 10
	root.add_theme_stylebox_override("panel", bg)
	root.custom_minimum_size = Vector2(260, 0)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	root.add_child(col)

	var head: HBoxContainer = HBoxContainer.new()
	_title = Label.new()
	_title.text = "Misión"
	_title.add_theme_font_size_override("font_size", 16)
	_title.add_theme_color_override("font_color", VisualMaterials.C_SUN)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_timer = Label.new()
	_timer.text = "0:00"
	head.add_child(_timer)
	_toggle = Button.new()
	_toggle.custom_minimum_size = Vector2(28, 28)
	_toggle.add_child(HudIcon.new(&"close", 14.0))
	_toggle.pressed.connect(_on_toggle_pressed)
	head.add_child(_toggle)
	col.add_child(head)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	col.add_child(_list)


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


func set_objectives(objectives: Array[MissionObjective]) -> void:
	var parts: PackedStringArray = PackedStringArray()
	for it: MissionObjective in objectives:
		parts.append("%s|%s" % [it.state, it.text])
	var key: String = "\n".join(parts)
	if key == _last_key:
		return
	_last_key = key
	for c: Node in _list.get_children():
		c.queue_free()
	for it: MissionObjective in objectives:
		_list.add_child(_build_item(it))


func _build_item(it: MissionObjective) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var dot: ColorRect = ColorRect.new()
	dot.custom_minimum_size = Vector2(8, 8)
	dot.color = _state_color(it.state)
	var dot_center: CenterContainer = CenterContainer.new()
	dot_center.add_child(dot)
	row.add_child(dot_center)
	var label: Label = Label.new()
	label.text = it.text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", _state_color(it.state) if it.state != MissionObjective.STATE_TODO else Color(1, 1, 1, 0.55))
	if it.state == MissionObjective.STATE_NOW:
		label.add_theme_font_size_override("font_size", 15)
	row.add_child(label)
	return row


static func _state_color(state: StringName) -> Color:
	match state:
		MissionObjective.STATE_OK:
			return VisualMaterials.C_OK
		MissionObjective.STATE_ALERT:
			return VisualMaterials.C_BAD
		MissionObjective.STATE_NOW:
			return VisualMaterials.C_SUN
		_:
			return Color(1, 1, 1, 0.55)


func set_collapsed(c: bool) -> void:
	_collapsed = c
	_list.visible = not c
