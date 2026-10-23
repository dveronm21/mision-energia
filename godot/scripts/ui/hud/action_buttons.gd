class_name ActionButtons
extends ActionButtonsPort
## Botonera derecha: acción contextual grande, Revisar, Multímetro; y botón de pausa arriba a
## la derecha. Equivale a `ActionButtons.ts` y a `.hud-btns`/`.hud-round`/`.hud-act` de
## styles.ts. Extiende `ActionButtonsPort` así `GameSession` ya lo puede usar sin cambios.

const ACT_PX: float = 128.0
const ROUND_PX: float = 76.0
const PAUSE_PX: float = 52.0
const ROUND_BG: Color = Color(14.0 / 255.0, 36.0 / 255.0, 32.0 / 255.0, 0.85)
const ROUND_LINE: Color = Color(1, 1, 1, 0.7)

## Nodo de verdad: agregalo a la escena (`host.add_child(action_buttons.root)`).
var root: Control
var pause_button: Button

var _act: Button
var _act_label: Label
var _act_state: StringName = &""
var _inspect: Button
var _meter: Button
var _meter_icon: HudIcon
var _meter_cap: Label
var _meter_circle: Panel


func _init(on_action: Callable, on_inspect: Callable, on_meter: Callable, on_pause: Callable) -> void:
	root = Control.new()
	root.name = "hud-btns"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_right = -12
	row.offset_bottom = -12
	row.offset_left = -12
	row.offset_top = -12
	root.add_child(row)

	_meter_icon = HudIcon.new(&"meter", 26.0)
	_meter = _round_button(_meter_icon, "Multímetro", on_meter)
	_meter.tooltip_text = "Sacar o guardar el multímetro"
	row.add_child(_meter)

	_inspect = _round_button(HudIcon.new(&"search", 26.0), "Revisar", on_inspect)
	_inspect.tooltip_text = "Revisar lo que tenés cerca"
	row.add_child(_inspect)

	# `.hud-act`: círculo grande con borde claro y labio; el texto se parte en 2 renglones.
	_act = Button.new()
	_act.name = "hud-act"
	_act.custom_minimum_size = Vector2(ACT_PX, ACT_PX)
	_act.size_flags_vertical = Control.SIZE_SHRINK_END
	_act_label = UiTheme.label("Acercate a algo", UiTheme.display(700), 19, UiTheme.INK)
	_act_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_act_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_act_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_act_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_act_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_act_label.offset_left = 16
	_act_label.offset_right = -16
	_act_label.offset_bottom = -6
	_act.add_child(_act_label)
	if on_action.is_valid():
		_act.pressed.connect(on_action)
	_style_action_button(&"idle")
	row.add_child(_act)

	# El botón de pausa NO se ancla acá: va arriba a la derecha junto a `StatsPanel`, y ese
	# carril lo arma `Hud` con un `HBoxContainer`.
	pause_button = Button.new()
	pause_button.name = "hud-pause"
	pause_button.custom_minimum_size = Vector2(PAUSE_PX, PAUSE_PX)
	pause_button.tooltip_text = "Pausa"
	pause_button.focus_mode = Control.FOCUS_NONE
	UiTheme.style_button(pause_button, UiTheme.box(ROUND_BG, 999, 3, ROUND_LINE))
	var pause_center: CenterContainer = CenterContainer.new()
	pause_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_center.add_child(HudIcon.new(&"pause", 22.0))
	pause_button.add_child(pause_center)
	if on_pause.is_valid():
		pause_button.pressed.connect(on_pause)


## `.hud-round`: círculo de 76 px con ícono y, debajo, una etiqueta en píldora.
func _round_button(ic: HudIcon, caption: String, on_pressed: Callable) -> Button:
	var b: Button = Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(ROUND_PX + 8.0, ROUND_PX + 22.0)
	b.size_flags_vertical = Control.SIZE_SHRINK_END
	UiTheme.style_button(b, StyleBoxEmpty.new())
	var col: VBoxContainer = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 3)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.set_anchors_preset(Control.PRESET_FULL_RECT)

	var circle: Panel = Panel.new()
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	circle.custom_minimum_size = Vector2(ROUND_PX, ROUND_PX)
	circle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	circle.add_theme_stylebox_override("panel", UiTheme.box(ROUND_BG, 999, 3, ROUND_LINE))
	var ic_center: CenterContainer = CenterContainer.new()
	ic_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic_center.add_child(ic)
	circle.add_child(ic_center)
	col.add_child(circle)

	var cap_wrap: PanelContainer = PanelContainer.new()
	cap_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap_wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var cap_bg: StyleBoxFlat = UiTheme.box(ROUND_BG, 999)
	cap_bg.content_margin_left = 7
	cap_bg.content_margin_right = 7
	cap_bg.content_margin_top = 1
	cap_bg.content_margin_bottom = 2
	cap_wrap.add_theme_stylebox_override("panel", cap_bg)
	var cap: Label = UiTheme.label(caption, UiTheme.body(800), 12)
	cap_wrap.add_child(cap)
	col.add_child(cap_wrap)
	b.add_child(col)
	b.draw.connect(func() -> void: col.modulate.a = 0.45 if b.disabled else 1.0)
	if ic == _meter_icon:
		_meter_cap = cap
		_meter_circle = circle
	if on_pressed.is_valid():
		b.pressed.connect(on_pressed)
	return b


## Texto y estado del botón grande. "idle" = gris (nada cerca), "drop" = blanco (soltar lo que cargás).
func set_action(label: String, state: StringName = &"normal") -> void:
	_act_label.text = label
	var was: StringName = _act_state
	_style_action_button(state)
	# Cuando aparece algo para hacer, el botón salta para llamar la atención del pulgar.
	if was == &"idle" and state != &"idle" and _act.is_inside_tree():
		_act.pivot_offset = _act.size / 2.0
		_act.scale = Vector2(0.82, 0.82)
		_act.create_tween().tween_property(_act, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _style_action_button(state: StringName) -> void:
	if state == _act_state:
		return
	_act_state = state
	var bg: Color = UiTheme.SUN
	var line: Color = UiTheme.SUN_SOFT
	var lip: Color = UiTheme.SUN_DARK
	var fg: Color = UiTheme.INK
	match state:
		&"idle":
			bg = UiTheme.LOCKED
			line = UiTheme.LOCKED_LINE
			lip = UiTheme.LOCKED_SHADOW
			fg = UiTheme.PAPER_2
		&"drop":
			bg = Color("#eef2f1")
			line = Color.WHITE
			lip = UiTheme.LOCKED_LINE
	UiTheme.style_button(_act, UiTheme.lipped(bg, lip, 7, 999, 5, line, 0.0))
	_act_label.add_theme_color_override("font_color", fg)


func set_meter_on(on: bool) -> void:
	_meter.button_pressed = on
	# `.hud-round.is-on`: círculo color tierra con borde de sol y texto cálido.
	var warm: Color = Color("#ffd27a")
	_meter_circle.add_theme_stylebox_override("panel",
		UiTheme.box(UiTheme.DUST, 999, 3, UiTheme.SUN) if on else UiTheme.box(ROUND_BG, 999, 3, ROUND_LINE))
	_meter_icon.stroke_color = warm if on else Color.WHITE
	_meter_icon.queue_redraw()
	_meter_cap.add_theme_color_override("font_color", warm if on else UiTheme.FG)


func set_inspect_enabled(on: bool) -> void:
	_inspect.disabled = not on


func set_meter_enabled(on: bool) -> void:
	_meter.disabled = not on
