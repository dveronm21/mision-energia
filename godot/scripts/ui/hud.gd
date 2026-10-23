class_name Hud
extends HudPort
## HUD completo de partida (equivale a `Hud.ts`). Compone los componentes reales y define las
## zonas para que no se pisen: arriba-izq misión, arriba-der estadísticas + pausa, carril
## superior central (alertas), abajo-izq joystick + boosters, abajo-der botonera, carril
## inferior central (multímetro, ficha, cargas).

## Nodo de verdad: agregalo a la escena (ocupa toda la pantalla).
var root: Control
var joystick: Joystick

var _mission_real: MissionPanel
var _stats_real: StatsPanel
var _alert_real: AlertBanner
var _prompt_real: WorldPrompt
var _meter_real: MeterView
var _inspect_real: InspectCard
var _shedding_real: LoadSheddingPanel
var _boosters_real: BoosterBar
var _actions_real: ActionButtons


func _init(cb: HudCallbacks = HudCallbacks.new()) -> void:
	root = Control.new()
	root.name = "hud"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_prompt_real = WorldPrompt.new()
	prompt = _prompt_real
	root.add_child(_prompt_real.root)

	# Carril superior: misión a la izquierda, estadísticas a la derecha (un espaciador que se
	# expande entre las dos las empuja a cada punta, sin anclar nada a mano).
	var top_margin: MarginContainer = MarginContainer.new()
	top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	for side: String in ["left", "top", "right"]:
		top_margin.add_theme_constant_override("margin_%s" % side, 18)

	var top_lane: HBoxContainer = HBoxContainer.new()
	top_lane.add_theme_constant_override("separation", 12)
	top_margin.add_child(top_lane)

	_mission_real = MissionPanel.new()
	mission = _mission_real
	top_lane.add_child(_mission_real.root)

	var top_spacer: Control = Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_lane.add_child(top_spacer)

	_stats_real = StatsPanel.new()
	stats = _stats_real
	top_lane.add_child(_stats_real.root)
	root.add_child(top_margin)

	_alert_real = AlertBanner.new()
	alert = _alert_real
	_alert_real.root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_alert_real.root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_alert_real.root.position = Vector2(-220, 18)
	_alert_real.root.custom_minimum_size = Vector2(440, 0)
	root.add_child(_alert_real.root)

	joystick = Joystick.new()
	joystick.mouse_filter = Control.MOUSE_FILTER_STOP
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.grow_vertical = Control.GROW_DIRECTION_BEGIN
	joystick.position = Vector2(36, -160)
	if cb.on_joystick.is_valid():
		joystick.on_change = cb.on_joystick
	root.add_child(joystick)

	_boosters_real = BoosterBar.new(cb.on_use_booster)
	boosters = _boosters_real
	_boosters_real.root.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_boosters_real.root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_boosters_real.root.position = Vector2(36, -190)
	root.add_child(_boosters_real.root)

	_actions_real = ActionButtons.new(cb.on_action, cb.on_inspect, cb.on_meter, cb.on_pause)
	actions = _actions_real
	_actions_real.root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_actions_real.root)
	_actions_real.pause_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top_lane.add_child(_actions_real.pause_button)

	# Carril inferior central: multímetro, ficha y "Salvá la ciudad", apilados de abajo hacia
	# arriba para que no se tapen si llegan a coincidir.
	var bottom_lane: VBoxContainer = VBoxContainer.new()
	bottom_lane.add_theme_constant_override("separation", 10)
	bottom_lane.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_lane.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom_lane.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_lane.position = Vector2(-160, -220)
	bottom_lane.mouse_filter = Control.MOUSE_FILTER_PASS

	_shedding_real = LoadSheddingPanel.new(cb.on_toggle_load)
	shedding = _shedding_real
	bottom_lane.add_child(_shedding_real.root)

	_inspect_real = InspectCard.new()
	inspect = _inspect_real
	if cb.on_inspect_close.is_valid():
		_inspect_real.on_close = cb.on_inspect_close
	bottom_lane.add_child(_inspect_real.root)

	_meter_real = MeterView.new()
	meter = _meter_real
	bottom_lane.add_child(_meter_real.root)

	root.add_child(bottom_lane)
