class_name ActionButtons
extends ActionButtonsPort
## Botonera derecha: acción contextual grande, Revisar, Multímetro; y botón de pausa arriba a
## la derecha. Equivale a `ActionButtons.ts`. Extiende `ActionButtonsPort` así `GameSession` ya
## lo puede usar sin cambios.

## Nodo de verdad: agregalo a la escena (`host.add_child(action_buttons.root)`).
var root: Control
var pause_button: Button

var _act: Button
var _act_label: Label
var _inspect: Button
var _meter: Button
var _meter_icon: HudIcon


func _init(on_action: Callable, on_inspect: Callable, on_meter: Callable, on_pause: Callable) -> void:
	root = Control.new()
	root.name = "hud-btns"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.position = Vector2(-18, -18)
	root.add_child(row)

	_meter_icon = HudIcon.new(&"meter", 26.0)
	_meter = _round_button(_meter_icon, "Multímetro", on_meter)
	_meter.tooltip_text = "Sacar o guardar el multímetro"
	row.add_child(_meter)

	_inspect = _round_button(HudIcon.new(&"search", 26.0), "Revisar", on_inspect)
	_inspect.tooltip_text = "Revisar lo que tenés cerca"
	row.add_child(_inspect)

	_act_label = Label.new()
	_act_label.text = "Acercate a algo"
	_act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_act_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_act = Button.new()
	_act.custom_minimum_size = Vector2(150, 72)
	_act.add_child(_act_label)
	_act_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	if on_action.is_valid():
		_act.pressed.connect(on_action)
	_style_action_button(&"normal")
	row.add_child(_act)

	# El botón de pausa NO se ancla acá: va arriba a la derecha junto a `StatsPanel`, y ese
	# carril lo arma `Hud` con un `HBoxContainer` (ver la nota en `stats_panel.gd` sobre anclar
	# a mano con posiciones negativas en vez de contenedores).
	pause_button = Button.new()
	pause_button.custom_minimum_size = Vector2(52, 52)
	pause_button.tooltip_text = "Pausa"
	var pause_bg: StyleBoxFlat = StyleBoxFlat.new()
	pause_bg.bg_color = Color(0.2, 0.22, 0.2, 0.7)
	pause_bg.corner_radius_top_left = 26
	pause_bg.corner_radius_top_right = 26
	pause_bg.corner_radius_bottom_left = 26
	pause_bg.corner_radius_bottom_right = 26
	pause_button.add_theme_stylebox_override("normal", pause_bg)
	pause_button.add_theme_stylebox_override("hover", pause_bg)
	pause_button.add_theme_stylebox_override("pressed", pause_bg)
	var pause_center: CenterContainer = CenterContainer.new()
	pause_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_center.add_child(HudIcon.new(&"pause", 22.0))
	pause_button.add_child(pause_center)
	if on_pause.is_valid():
		pause_button.pressed.connect(on_pause)


func _round_button(ic: HudIcon, caption: String, on_pressed: Callable) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(72, 72)
	var col: VBoxContainer = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ic_center: CenterContainer = CenterContainer.new()
	ic_center.add_child(ic)
	col.add_child(ic_center)
	var cap: Label = Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", 11)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(cap)
	b.add_child(col)
	if on_pressed.is_valid():
		b.pressed.connect(on_pressed)
	return b


## Texto y estado del botón grande. "idle" = gris (nada cerca), "drop" = blanco (soltar lo que cargás).
func set_action(label: String, state: StringName = &"normal") -> void:
	_act_label.text = label
	_style_action_button(state)


func _style_action_button(state: StringName) -> void:
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.corner_radius_top_left = 16
	bg.corner_radius_top_right = 16
	bg.corner_radius_bottom_left = 16
	bg.corner_radius_bottom_right = 16
	match state:
		&"idle":
			bg.bg_color = Color(0.3, 0.32, 0.3, 0.55)
		&"drop":
			bg.bg_color = Color(0.9, 0.9, 0.88, 0.92)
			_act_label.add_theme_color_override("font_color", Color.BLACK)
		_:
			bg.bg_color = VisualMaterials.C_SUN
			_act_label.add_theme_color_override("font_color", Color.BLACK)
	_act.add_theme_stylebox_override("normal", bg)
	_act.add_theme_stylebox_override("hover", bg)
	_act.add_theme_stylebox_override("pressed", bg)
	if state != &"idle" and state != &"drop":
		_act_label.add_theme_color_override("font_color", Color.BLACK)
	elif state == &"idle":
		_act_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))


func set_meter_on(on: bool) -> void:
	_meter.button_pressed = on
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.corner_radius_top_left = 36
	bg.corner_radius_top_right = 36
	bg.corner_radius_bottom_left = 36
	bg.corner_radius_bottom_right = 36
	bg.bg_color = VisualMaterials.C_SUN if on else Color(0.2, 0.22, 0.2, 0.7)
	_meter.add_theme_stylebox_override("normal", bg)


func set_inspect_enabled(on: bool) -> void:
	_inspect.disabled = not on


func set_meter_enabled(on: bool) -> void:
	_meter.disabled = not on
