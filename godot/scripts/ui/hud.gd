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
var _bottom_lane: VBoxContainer
var _fit_queued: bool = false

## Debajo de este alto (teléfono con la UI agrandada) la misión se muestra compacta.
const COMPACT_H: float = 560.0
const LANE_MAX_W: float = 460.0
const LANE_MIN_W: float = 300.0


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
		top_margin.add_theme_constant_override("margin_%s" % side, 12)

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
	# Carril superior central (`.hud-lane-top`): entre la misión y las estadísticas, 12 px abajo
	# del borde. Ancla al centro con márgenes simétricos para que quede centrado sea cual sea su
	# alto.
	_alert_real.root.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_alert_real.root.offset_left = -230
	_alert_real.root.offset_right = 230
	_alert_real.root.offset_top = 12
	_alert_real.root.offset_bottom = 12
	_alert_real.root.grow_vertical = Control.GROW_DIRECTION_END
	root.add_child(_alert_real.root)

	joystick = Joystick.new()
	joystick.mouse_filter = Control.MOUSE_FILTER_STOP
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.grow_vertical = Control.GROW_DIRECTION_BEGIN
	joystick.position = Vector2(20, -152)
	if cb.on_joystick.is_valid():
		joystick.on_change = cb.on_joystick
	root.add_child(joystick)

	_boosters_real = BoosterBar.new(cb.on_use_booster)
	boosters = _boosters_real
	_boosters_real.root.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_boosters_real.root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_boosters_real.root.position = Vector2(12, -222)
	root.add_child(_boosters_real.root)

	_actions_real = ActionButtons.new(cb.on_action, cb.on_inspect, cb.on_meter, cb.on_pause)
	actions = _actions_real
	_actions_real.root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_actions_real.root)
	_actions_real.pause_button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top_lane.add_child(_actions_real.pause_button)

	# Carril inferior central: multímetro, ficha y "Salvá la ciudad", apilados de abajo hacia
	# arriba para que no se tapen si llegan a coincidir.
	# Pegado abajo al centro (entre joystick y botonera) y creciendo hacia arriba; cada panel
	# centrado en el carril.
	var bottom_lane: VBoxContainer = VBoxContainer.new()
	bottom_lane.add_theme_constant_override("separation", 10)
	bottom_lane.alignment = BoxContainer.ALIGNMENT_END
	bottom_lane.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_lane.offset_left = -230
	bottom_lane.offset_right = 230
	bottom_lane.offset_top = -16
	bottom_lane.offset_bottom = -16
	bottom_lane.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom_lane.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	for panel: Control in [_shedding_real.root, _inspect_real.root, _meter_real.root]:
		panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	root.add_child(bottom_lane)
	_bottom_lane = bottom_lane

	# Los carriles centrales se recalculan con el tamaño de la pantalla y de los paneles de las
	# puntas, para que en un teléfono la alerta y las fichas no tapen la misión, las
	# estadísticas, el joystick ni la botonera.
	root.resized.connect(_queue_fit)
	_mission_real.root.resized.connect(_queue_fit)
	_stats_real.root.resized.connect(_queue_fit)
	_stats_real.root.visibility_changed.connect(_queue_fit)


func _queue_fit() -> void:
	if _fit_queued:
		return
	_fit_queued = true
	_fit_lanes.call_deferred()


func _fit_lanes() -> void:
	_fit_queued = false
	if not root.is_inside_tree():
		return
	_mission_real.set_compact(root.size.y < COMPACT_H)
	var w: float = root.size.x

	var left: float = 12.0
	if _mission_real.root.is_visible_in_tree():
		left = _local(_mission_real.root).end.x
	var right: float = w - 12.0
	for c: Control in [_stats_real.root, _actions_real.pause_button]:
		if c.is_visible_in_tree():
			right = minf(right, _local(c).position.x)
	_place_lane(_alert_real.root, left, right)

	left = 12.0
	if joystick.is_visible_in_tree():
		left = _local(joystick).end.x
	right = w - 12.0
	if _actions_real.root.is_visible_in_tree():
		right = _local(_actions_real.root).position.x
	var lane_w: float = _place_lane(_bottom_lane, left, right)
	for panel: Control in [_shedding_real.root, _inspect_real.root]:
		panel.custom_minimum_size.x = lane_w


## Ubica un carril (anclado a la izquierda) en el hueco [left, right]: centrado en la pantalla
## si entra, si no corrido dentro del hueco. Devuelve el ancho.
func _place_lane(lane: Control, left: float, right: float) -> float:
	var gap: float = 10.0
	var w: float = clampf(right - left - 2.0 * gap, LANE_MIN_W, LANE_MAX_W)
	var x: float = clampf((root.size.x - w) / 2.0, left + gap, maxf(left + gap, right - gap - w))
	lane.anchor_left = 0.0
	lane.anchor_right = 0.0
	lane.offset_left = x
	lane.offset_right = x + w
	return w


func _local(c: Control) -> Rect2:
	var r: Rect2 = c.get_global_rect()
	r.position -= root.get_global_rect().position
	return r


## Modo TV: se juega desde las tablets, así que el tele no muestra joystick, botonera ni
## boosters (quedan la misión, las estadísticas, las alertas y las fichas).
func set_tv_mode(on: bool) -> void:
	joystick.visible = not on
	_actions_real.root.visible = not on
	_actions_real.pause_button.visible = not on
	_boosters_real.suppressed = on
	if on:
		_boosters_real.root.visible = false
