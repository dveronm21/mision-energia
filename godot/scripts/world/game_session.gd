class_name GameSession
extends SessionPort
## Una partida de un nivel (equivale a `GameSession.ts`):
##   build    → el jugador arma la planta (reloj detenido a la hora de activación).
##   running  → corre el simulador y el clima (Zonda, nubes, noche); se puede medir, defender y limpiar.
##   finished → Scoring y aviso (on_finished) tras una breve pausa para ver el final.
##
## Implementa `SessionPort` (reglas que usan las estrategias de interacción) extendiéndolo
## directo; `MissionFacts` y `LiveSource` los implementa por composición con
## `SessionMissionFacts`/`SessionLiveSource` (GDScript no tiene herencia múltiple).
##
## A diferencia de la web no hace falta `factory`/`env`/`camera`/`dragSurface` inyectados:
## `PlantWorld` arma sus propios visuales y `CameraRig` crea su propia cámara. Este nodo
## expone `root` (un `Node3D` con el mundo, el ambiente, los resaltados y la cámara) para
## que quien integre lo agregue una sola vez a la escena.

const CLOCK_NORMAL: float = 0.45
const CLOCK_SLOW: float = 0.05

const FLOW_DC: Color = Color("#ffd27a")
const FLOW_BAT: Color = Color("#7fb3ff")
const FLOW_AC: Color = Color("#d6c2ff")
const FLOW_GRID: Color = Color("#fff3a0")

## Raíz para agregar a la escena: ambiente, mundo (con el jugador adentro), resaltados y cámara.
var root: Node3D
var player: Player
var cam_rig: CameraRig
var paused: bool = false
## Multiplicador del reloj de juego (depuración).
var time_scale: float = 1.0
var connector: ConnectorFacts = ConnectorFacts.new()

var _d: SessionDeps
var _level: LevelDefinition
var _purchase: Purchase
var _world: PlantWorld
var _hands: HandsController
var _phase: StringName = PHASE_BUILD
var _weather: String = WeatherSchedule.CALM

var _sim: EnergySimulator = EnergySimulator.new()
var _weather_schedule: WeatherSchedule
var _storm: StormImpact = StormImpact.new()
var _interaction: InteractionSystem
var _tracker: MissionTracker
var _highlights: Highlights
var _env: EnvironmentRig
var _snap: SimSnapshot = null
var _hour: float = 0.0
var _zonda_fx: float = 0.0
var _storm_applied: bool = false
var _over_handled: bool = false
var _panels_lost: int = 0
var _shed: Array[String] = []
## null hasta que se hace de noche la primera vez; después, la lista de cargas no esenciales
## activas en ese momento (puede ser vacía).
var _night_loads: Variant = null
var _elapsed: float = 0.0
var _finish_timer: float = -1.0
var _hud_timer: float = 0.0
var _current_action: WorldAction = null
var _current_inspect: InspectEntry = null
var _open_inspect_id: String = ""
var _last_prompt: String = ""
var _hint_on: bool = false
var _drone_on: bool = false
var _bonus_kwh: float = 0.0
var _row_flows: Array[Variant] = []
var _flow_orange: EnergyFlowVisual
var _flow_link: EnergyFlowVisual
var _flow_blue: EnergyFlowVisual
var _flow_violet: EnergyFlowVisual
var _flow_grid: EnergyFlowVisual
var _flow_pump: EnergyFlowVisual
var _disposed: bool = false


func _init(deps: SessionDeps) -> void:
	_d = deps
	_level = deps.level
	_purchase = deps.purchase
	_hour = _level.start_hour
	_weather_schedule = WeatherSchedule.new(_level.events)
	_hint_on = deps.active_boosters.has(Boosters.HINT)
	_drone_on = deps.active_boosters.has(Boosters.DRONE)
	_bonus_kwh = deps.boosters.bonus_kwh(deps.active_boosters.has(Boosters.BATTERY))

	root = Node3D.new()
	root.name = "game-session"
	_env = EnvironmentRig.new()
	root.add_child(_env)
	_world = PlantWorld.new(_level, _purchase, clean_row.bind(true))
	root.add_child(_world)
	for _r: RowLayout in _world.layout.rows:
		_row_flows.append(null)

	var helmet: Color = _d.cosmetics.get("helmet", VisualMaterials.C_SUN)
	var vest: Color = _d.cosmetics.get("vest", VisualMaterials.C_ORANGE)
	var rig: WorkerVisual = WorkerVisual.new(helmet, vest)
	player = Player.new(rig, _world.colliders, _world.floor_at, _world.layout.spawn)
	_world.add_child(player)
	_hands = HandsController.new(rig)

	cam_rig = CameraRig.new()
	root.add_child(cam_rig)
	cam_rig.snap()

	_highlights = Highlights.new()
	root.add_child(_highlights)

	_interaction = InteractionSystem.new(
		[
			PickupProvider.new(self) as ActionProvider, PlacementProvider.new(self) as ActionProvider,
			WiringProvider.new(self) as ActionProvider, MeterProvider.new(self) as ActionProvider,
			FieldCareProvider.new(self) as ActionProvider, ConsoleProvider.new(self) as ActionProvider,
		],
		[Inspectables.new(SessionLiveSource.new(self)) as InspectProvider],
	)
	_tracker = MissionTracker.new(SessionMissionFacts.new(self))

	for b: BatterySlot in _world.batteries:
		b.set_charge(_level.start_soc)

	var hud: HudPort = _d.hud
	hud.reset()
	hud.mission.set_title("Nivel %d · %s" % [_level.order, _level.name])
	hud.mission.set_timer_visible(true)
	_refresh_booster_bar()
	_sync_hud()
	_env.update(0.0, _hour, 0.0, _weather_schedule.cloudiness_at(_hour), player.position)
	toast("Empezá por el pallet de paneles. Ojo: uno puede venir con el conector flojo."
		if _level.events.loose_connector
		else "Empezá por el pallet de paneles: está cerca tuyo, a la izquierda.")


# ================================================================== SessionPort


func level() -> LevelDefinition:
	return _level


func purchase() -> Purchase:
	return _purchase


func world() -> PlantWorld:
	return _world


func hands() -> HandsController:
	return _hands


func phase() -> StringName:
	return _phase


func weather() -> String:
	return _weather


func is_night() -> bool:
	return _snap != null and _snap.is_night


func won() -> bool:
	return _snap != null and _snap.won


func is_running() -> bool:
	return _phase != PHASE_BUILD


func toast(text: String, kind: StringName = &"info") -> void:
	_d.ui.show_toast(text, kind, 4600 if kind == &"bad" else 3200)
	if kind == &"bad":
		sfx("bad")


func sfx(sfx_name: String) -> void:
	_d.audio.play(sfx_name)


func take_from_pallet() -> void:
	var faulty: bool = _world.pallet.take()
	_hands.carry(&"panel", faulty)
	sfx("pick")
	_changed()


func take_pickup(p: Pickup) -> void:
	_hands.carry(p.kind, p.faulty)
	_world.remove_pickup(p)
	sfx("pick")
	_changed()


func install_panel(m: Mount) -> void:
	var h: HandsState = _hands.hands()
	if h.kind != HandsState.KIND_CARRY or h.item_kind != &"panel":
		return
	_hands.clear()
	m.install(h.item_faulty)
	_ensure_row_wire(m.row)
	sfx("place")
	var n: int = _world.panels_installed()
	var total: int = _purchase.panels
	toast("¡Campo solar completo!" if n >= total else "Panel %d de %d instalado." % [n, total], &"good")
	_changed()


func install_protection() -> void:
	_hands.clear()
	_world.protection.install()
	_world.link_protection()
	sfx("place")
	toast("Protección instalada: corta el circuito si hay una falla.", &"good")
	_changed()


func install_battery(i: int) -> void:
	if i < 0 or i >= _world.batteries.size():
		return
	var slot: BatterySlot = _world.batteries[i]
	if slot.installed():
		return
	_hands.clear()
	slot.install()
	slot.set_charge(_level.start_soc)
	_world.colliders.add(slot.position.x, slot.position.z, 0.5, 0.32)
	sfx("place")
	toast("Batería %d instalada: %s kWh para guardar energía." % [_world.batteries_installed(), JsMath.fmt_decimal(_level.battery_kwh)], &"good")
	_changed()


func install_kit(_row: int) -> void:
	_hands.clear()
	_world.kit_installed = true
	sfx("place")
	toast("Trabas instaladas: el Zonda no podrá arrancar paneles.", &"good")
	_changed()


func take_cable(color: StringName, from: StringName, point: Vector3) -> void:
	_hands.take_cable(color, from, point)
	sfx("pick")
	toast("Llevá el %s hasta su equipo." % CableNetwork.NAMES.get(color, "cable"))
	_changed()


func connect_cable(to: StringName) -> void:
	var h: HandsState = _hands.hands()
	if h.kind != HandsState.KIND_CABLE:
		return
	var expected: StringName
	match h.cable_color:
		CableNetwork.COLOR_ORANGE:
			expected = &"protection"
		CableNetwork.COLOR_BLUE, CableNetwork.COLOR_VIOLET:
			expected = &"inverter"
		_:
			expected = &""
	if expected != to:
		toast(_cable_hint(h.cable_color, to), &"bad")
		return
	var w: PlantWorld = _world
	var c: CableNetwork = w.cables
	var room: RoomLayout = w.layout.room
	var pts: PackedVector3Array
	if h.cable_color == CableNetwork.COLOR_ORANGE:
		pts = CableNetwork.ground_route(w.junction.terminal, w.protection.terminal, w.floor_at, w.layout.junction.z + 0.45, NAN)
	elif h.cable_color == CableNetwork.COLOR_BLUE:
		pts = CableNetwork.ground_route(h.cable_from_point, w.inverter.terminal_for(&"bat"), w.floor_at, room.wall_z + 1.45, NAN)
	else:
		pts = CableNetwork.ground_route(w.switchboard.terminal, w.inverter.terminal_for(&"ac"), w.floor_at, room.wall_z + 1.15, NAN)
	c.connect_cable(h.cable_color, pts)
	_hands.clear()
	sfx("ok")
	toast("¡Bien! Conectaste el %s." % CableNetwork.NAMES.get(h.cable_color, "cable"), &"good")
	_changed()


## Pista didáctica cuando el cable va al equipo equivocado.
func _cable_hint(color: StringName, to: StringName) -> String:
	if color == CableNetwork.COLOR_ORANGE and to == &"inverter":
		return "El cable de los paneles no va directo al inversor: primero pasa por la protección, en la pared a la izquierda del inversor."
	if color == CableNetwork.COLOR_ORANGE:
		return "El cable naranja lleva la corriente continua de los paneles. Llevalo hasta la protección."
	if color == CableNetwork.COLOR_BLUE:
		return "Este es el cable de las baterías: tiene que llegar al inversor, que decide cuándo cargarlas y descargarlas."
	return "El tablero recibe la corriente alterna que sale del inversor. Llevá el cable violeta al inversor."


func measure_rows() -> void:
	var w: PlantWorld = _world
	var m: MeterViewPort = _d.hud.meter
	connector.measured = true
	sfx("beep")
	m.show()
	if _phase == PHASE_RUNNING and is_night():
		m.set_reading("0 V", "V⎓ por fila", "De noche los paneles no generan tensión. Medí de día para buscar fallas.", &"idle")
		return
	var vals: Array[Variant] = []
	for r: int in w.rows.size():
		if w.panels_in_row(r) == 0:
			vals.append(null)
		elif w.row_open(r):
			vals.append(0)
		else:
			vals.append(w.panels_in_row(r) * Inspectables.PANEL_VOC)
	var parts: PackedStringArray = PackedStringArray()
	for r: int in vals.size():
		var v: Variant = vals[r]
		parts.append("F%d %s" % [r + 1, "–" if v == null else str(v)])
	var text: String = "  ".join(parts)
	var bad: int = -1
	for r: int in vals.size():
		if vals[r] == 0:
			bad = r
			break
	if bad >= 0:
		connector.row_found = true
		m.set_reading(text, "V⎓ por fila", "La fila %d marca 0 V: hay un circuito abierto. Medí panel por panel en esa fila." % (bad + 1), &"bad")
	else:
		var all_null: bool = true
		for v: Variant in vals:
			if v != null:
				all_null = false
				break
		if all_null:
			m.set_reading(text, "V⎓ por fila", "Todavía no hay paneles conectados a la caja.", &"idle")
		else:
			m.set_reading(text, "V⎓ por fila", "Tensiones normales: cada panel suma unos %d V en serie." % Inspectables.PANEL_VOC, &"ok")
	_changed()


func measure_panel(mt: Mount) -> void:
	var m: MeterViewPort = _d.hud.meter
	sfx("beep")
	m.show()
	if mt.faulty:
		mt.fault_found = true
		connector.row_found = true
		m.set_reading("OL", "Ω conector", "Panel bien (%d V), pero el conector está abierto: tocá Reconectar." % Inspectables.PANEL_VOC, &"bad")
	else:
		m.set_reading("41,2 V", "V⎓ panel", "Panel y conector en buen estado.", &"ok")
	_changed()


func repair_panel(mt: Mount) -> void:
	mt.repair()
	connector.fixed = true
	sfx("ok")
	_d.hud.meter.set_reading("41,2 V", "V⎓ panel", "Conector reparado: la fila vuelve a sumar tensión.", &"ok")
	toast("Conector reconectado. La fila vuelve a generar.", &"good")
	_changed()


func set_defense(row: int) -> void:
	_world.posts[row].set_defense(true)
	for m: Mount in (_world.rows[row] as Array[Mount]):
		m.set_defense(true)
	sfx("place")
	toast("Fila %d en horizontal: el viento ya no la empuja." % (row + 1), &"good")
	_changed()


func clean_row(row: int, by_drone: bool = false) -> void:
	if not _world.row_dirty(row):
		return
	for m: Mount in (_world.rows[row] as Array[Mount]):
		m.set_dirty(false)
	sfx("ok")
	toast(("El dron limpió la fila %d." % (row + 1)) if by_drone else ("Fila %d limpia: recupera toda su generación." % (row + 1)), &"good")
	_changed()


func try_activate() -> void:
	var w: PlantWorld = _world
	var lv: LevelDefinition = _level
	var miss: Array[String] = []
	if w.panels_installed() < lv.min_panels:
		miss.append("instalá al menos %d paneles" % lv.min_panels)
	if not w.protection.installed():
		miss.append("instalá la protección")
	var nb: int = w.batteries_installed()
	if nb < _purchase.batteries:
		miss.append("instalá la batería" if _purchase.batteries == 1 else "instalá las %d baterías" % _purchase.batteries)
	var colors: Array[StringName] = [CableNetwork.COLOR_ORANGE, CableNetwork.COLOR_BLUE, CableNetwork.COLOR_VIOLET]
	for c: StringName in colors:
		if not w.cables.cable_connected(c):
			var cname: String = "naranja" if c == CableNetwork.COLOR_ORANGE else ("azul" if c == CableNetwork.COLOR_BLUE else "violeta")
			miss.append("conectá el cable %s" % cname)
	if not miss.is_empty():
		var shown: Array[String] = miss.slice(0, 2)
		toast("Todavía no: " + " y ".join(shown) + ".", &"bad")
		return
	_activate()


# ====================================================================== ciclo de vida


func _activate() -> void:
	var w: PlantWorld = _world
	_sim.start(_level, plant_state())
	_snap = _sim.snapshot()
	_phase = PHASE_RUNNING
	_flow_orange = _add_flow(w.cables.connected.get(CableNetwork.COLOR_ORANGE), FLOW_DC)
	_flow_link = _add_flow(w.protection_link, FLOW_DC)
	_flow_blue = _add_flow(w.cables.connected.get(CableNetwork.COLOR_BLUE), FLOW_BAT)
	_flow_violet = _add_flow(w.cables.connected.get(CableNetwork.COLOR_VIOLET), FLOW_AC)
	_flow_grid = _add_flow(w.city.line, FLOW_GRID)
	_flow_pump = _add_flow(w.pump_wire, FLOW_AC)
	if _flow_violet != null:
		_flow_violet.set_direction(-1)
	w.console.set_active(true)
	_d.hud.stats.set_visible(true)
	_d.hud.stats.update(_snap)
	sfx("power")
	if w.any_faulty():
		toast("¡Planta activada! Pero una fila marca 0 V en el inversor. Usá el multímetro.", &"bad")
	else:
		toast("¡Planta activada! Mirá cómo viaja la energía.", &"good")
	_changed()


static func _add_flow(cable: Variant, color: Color) -> EnergyFlowVisual:
	if cable == null:
		return null
	var cv: CableVisual = cable
	var f: EnergyFlowVisual = EnergyFlowVisual.new()
	cv.add_child(f)
	f.setup(cv.curve, color)
	return f


func _ensure_row_wire(r: int) -> void:
	_world.ensure_row_wire(r)
	var run: Variant = _world.row_wires[r]
	if run != null and _row_flows[r] == null:
		_row_flows[r] = _add_flow(run, FLOW_DC)


func plant_state() -> PlantState:
	var w: PlantWorld = _world
	var ps: PlantState = PlantState.new()
	var ppr: Array[int] = []
	var ro: Array[bool] = []
	var rd: Array[bool] = []
	for r: int in w.rows.size():
		ppr.append(w.panels_in_row(r))
		ro.append(w.row_open(r))
		rd.append(w.row_dirty(r))
	ps.panels_per_row = ppr
	ps.row_open = ro
	ps.row_dirty = rd
	var rdef: Array[bool] = []
	for p: RowPost in w.posts:
		rdef.append(p.in_defense())
	ps.row_defense = rdef
	ps.batteries = w.batteries_installed()
	ps.protection_installed = w.protection.installed()
	ps.cables_ok = w.cables.cable_connected(CableNetwork.COLOR_ORANGE) and w.cables.cable_connected(CableNetwork.COLOR_BLUE) and w.cables.cable_connected(CableNetwork.COLOR_VIOLET)
	ps.shed_loads = _shed.duplicate()
	ps.bonus_kwh = _bonus_kwh
	return ps


func snapshot() -> SimSnapshot:
	return _snap


## Un cuadro de juego. `input`: joystick/teclado (x, y en −1..1).
func update(dt_real: float, input: Vector2) -> void:
	if _disposed:
		return
	var dt: float = clampf(dt_real, 0.0, 0.05)
	if not paused:
		if _phase != PHASE_FINISHED:
			_elapsed += clampf(dt_real, 0.0, 0.25)
		player.speed_factor = (0.85 if _hands.kind() == HandsState.KIND_CARRY else 1.0) * (0.8 if _weather == WeatherSchedule.ZONDA_STORM else 1.0)
		player.pose = _hands.pose()
		var can_move: bool = _phase != PHASE_FINISHED
		player.update(dt, input.x if can_move else 0.0, input.y if can_move else 0.0, cam_rig.yaw)
		if _phase == PHASE_RUNNING:
			_step_sim(dt)
		if _phase == PHASE_FINISHED and _finish_timer >= 0.0:
			_finish_timer += dt
			if _finish_timer > 1.6:
				_finish_timer = -1.0
				_d.on_finished.call(_result())
	_world.update(dt, dt * maxf(1.0, time_scale))
	_highlights.update(dt)
	_update_visuals(dt)
	cam_rig.shake = 1.0 if _weather == WeatherSchedule.ZONDA_STORM else (0.15 if _weather == WeatherSchedule.ZONDA_WARNING else 0.0)
	cam_rig.update(dt, player.position)
	var live: HandsState = _hands.hands()
	var live_from: Variant = live.cable_from_point if live.kind == HandsState.KIND_CABLE else null
	var live_color: Variant = live.cable_color if live.kind == HandsState.KIND_CABLE else null
	_world.cables.update_live(live_from, _hands.hand_world(), live_color)
	if not paused and _phase != PHASE_FINISHED:
		_update_interaction()
	_hud_timer -= dt
	if _hud_timer <= 0.0:
		_hud_timer = 0.16
		_sync_hud()


func _step_sim(dt: float) -> void:
	var phase: String = _weather_schedule.phase_at(_hour)
	if phase != _weather:
		_on_weather(phase)
	var hps: float = (CLOCK_SLOW if (phase == WeatherSchedule.ZONDA_WARNING or phase == WeatherSchedule.ZONDA_STORM) else CLOCK_NORMAL) * time_scale
	var snap: SimSnapshot = _sim.step(dt * hps, plant_state(), phase)
	_snap = snap
	_hour = snap.hour
	_check_night_loads(snap)
	if snap.finished:
		_finish(snap)


func _on_weather(phase: String) -> void:
	_weather = phase
	var hud: HudPort = _d.hud
	var w: PlantWorld = _world
	if phase == WeatherSchedule.ZONDA_WARNING:
		sfx("alarm")
		hud.alert.show("¡Alerta de viento Zonda!",
			"Las trabas sostienen los paneles, pero se van a llenar de polvo." if w.kit_installed else "Corré a los postes y poné cada fila en defensa.",
			_warning_seconds())
	if phase == WeatherSchedule.ZONDA_STORM or (phase == WeatherSchedule.ZONDA_OVER and not _storm_applied):
		_apply_storm()
	if phase == WeatherSchedule.ZONDA_STORM:
		_d.audio.set_wind(true)
		hud.alert.show("Zonda soplando", "Ráfagas de 70 km/h · los paneles se llenan de polvo", null)
	if phase == WeatherSchedule.ZONDA_OVER and not _over_handled:
		_over_handled = true
		_d.audio.set_wind(false)
		hud.alert.hide()
		for p: RowPost in w.posts:
			p.set_defense(false)
		for m: Mount in w.mounts:
			m.set_defense(false)
		var dirty: Array[int] = []
		for r: int in w.rows.size():
			if w.row_dirty(r):
				dirty.append(r)
		if not dirty.is_empty() and _drone_on:
			_launch_drone()
		else:
			toast("Pasó el Zonda. Los paneles quedaron con polvo: limpialos en el poste de cada fila." if not dirty.is_empty() else "Pasó el Zonda.",
				&"bad" if not dirty.is_empty() else &"good")
	_changed()


func _apply_storm() -> void:
	if _storm_applied:
		return
	_storm_applied = true
	var w: PlantWorld = _world
	var hit: StormHit = _storm.apply(plant_state(), w.kit_installed)
	_panels_lost += hit.panels_lost
	for r: int in hit.lost_per_row.size():
		if hit.lost_per_row[r] == 0:
			continue
		var row_list: Array[Mount] = (w.rows[r] as Array[Mount])
		var victim: Mount = null
		for i: int in range(row_list.size() - 1, -1, -1):
			if row_list[i].filled():
				victim = row_list[i]
				break
		if victim == null:
			continue
		var faulty: bool = victim.remove()
		var p: Vector3 = victim.position()
		w.add_pickup(&"panel", Vector3(p.x + 0.6 + r * 0.5, 0.0, -0.9 - r * 0.25), faulty, 0.4 + r)
	for r: int in hit.plant.row_dirty.size():
		if hit.plant.row_dirty[r]:
			for m: Mount in (w.rows[r] as Array[Mount]):
				m.set_dirty(true)
	if hit.panels_lost > 0:
		toast("¡El viento arrancó un panel! Buscalo en el camino y volvé a colocarlo." if hit.panels_lost == 1
			else "¡El viento arrancó %d paneles! Buscalos en el camino y volvé a colocarlos." % hit.panels_lost, &"bad")


func _launch_drone() -> void:
	var w: PlantWorld = _world
	var rows: Array[Array] = []
	for r: int in w.rows.size():
		if w.row_dirty(r):
			var ms: Array[Vector3] = w.layout.rows[r].mounts
			var from_pt: Vector3 = ms[0] + Vector3(-1.2, 0.0, 0.0)
			var to_pt: Vector3 = ms[ms.size() - 1] + Vector3(1.2, 0.0, 0.0)
			rows.append([r, from_pt, to_pt])
	if rows.is_empty():
		return
	w.drone.start(rows)
	toast("Pasó el Zonda. ¡El dron limpiador ya salió a limpiar los paneles!", &"good")


func _warning_seconds() -> float:
	return _weather_schedule.warning_remaining(_hour) / (CLOCK_SLOW * time_scale)


## "Salvá la ciudad": al llegar la noche, ofrecer apagar cargas no esenciales que consumen de noche.
func _check_night_loads(s: SimSnapshot) -> void:
	var hud: HudPort = _d.hud
	if s.is_night and _night_loads == null:
		var lv: LevelDefinition = _level
		var labels: Array[String] = []
		for l: LoadBlock in lv.loads:
			if not l.essential and _active_until_end(l, s.hour) and not labels.has(l.label):
				labels.append(l.label)
		_night_loads = labels
		if not labels.is_empty():
			var filtered: Array[LoadBlock] = []
			for l: LoadBlock in lv.loads:
				if labels.has(l.label):
					filtered.append(l)
			hud.shedding.set_loads(filtered, _shed)
			hud.shedding.show()
			toast("Se hizo de noche: apagá lo que no haga falta para que la batería llegue a la mañana.")
	if not s.is_night and _night_loads != null and hud.shedding.visible:
		hud.shedding.hide()


func _active_until_end(l: LoadBlock, from: float) -> bool:
	var h: float = from
	while h < _level.end_hour:
		if Solar.block_active(l, h):
			return true
		h += 0.25
	return false


func toggle_load(label: String, on: bool) -> void:
	if on:
		var idx: int = _shed.find(label)
		if idx >= 0:
			_shed.remove_at(idx)
	elif not _shed.has(label):
		_shed.append(label)


func _finish(s: SimSnapshot) -> void:
	if _phase == PHASE_FINISHED:
		return
	_phase = PHASE_FINISHED
	_finish_timer = 0.0
	_d.audio.set_wind(false)
	_d.hud.alert.hide()
	_d.hud.shedding.hide()
	_hands.clear()
	_d.hud.meter.hide()
	_d.hud.actions.set_meter_on(false)
	sfx("win" if s.won else "lose")
	if not s.won:
		toast("¡Apagón! La batería se agotó a las %s." % JsMath.fmt_hour(s.hour), &"bad")
	_changed()


func _result() -> LevelResult:
	var s: SimSnapshot = _snap if _snap != null else _sim.snapshot()
	var plant: PlantState = plant_state()
	var night_loads: Array[String] = _night_loads if _night_loads != null else []
	var input: ScoringInput = ScoringInput.new()
	input.won = s.won
	input.final_soc_pct = s.soc_pct
	input.spent = _d.spent
	input.panels_lost = _panels_lost
	input.blackout_hour = s.hour if s.blackout else ScoringInput.NO_BLACKOUT
	input.duration_sec = roundf(_elapsed)
	var had_open: bool = false
	for v: bool in plant.row_open:
		if v:
			had_open = true
			break
	input.had_open_row_at_end = had_open
	var had_dirty: bool = false
	for v: bool in plant.row_dirty:
		if v:
			had_dirty = true
			break
	input.had_dirty_row_at_end = had_dirty
	input.batteries = plant.batteries
	input.panels = _world.panels_installed()
	var non_ess_on: bool = false
	for l: String in night_loads:
		if not _shed.has(l):
			non_ess_on = true
			break
	input.non_essential_on = non_ess_on
	return Scoring.new().evaluate(_level, input)


# =========================================================== interacción y HUD


func _update_interaction() -> void:
	var pick: InteractionPick = _interaction.update(_hands.hands(), player.position)
	_current_action = pick.action
	_current_inspect = pick.inspect
	var hud: HudPort = _d.hud
	var h: HandsState = _hands.hands()
	var a: WorldAction = pick.action
	if a != null:
		hud.actions.set_action(a.label, &"normal")
	elif h.kind == HandsState.KIND_METER:
		hud.actions.set_action("Medir", &"idle")
	elif h.kind == HandsState.KIND_CABLE:
		hud.actions.set_action("Soltar cable", &"drop")
	elif h.kind == HandsState.KIND_CARRY:
		hud.actions.set_action("Soltar", &"drop")
	else:
		hud.actions.set_action("Planta en marcha" if _phase == PHASE_RUNNING else "Acercate a algo", &"idle")
	hud.actions.set_inspect_enabled(pick.inspect != null or hud.inspect.visible)
	var floor_y: float = _world.floor_at(a.pos.x, a.pos.z) if a != null else 0.0
	_highlights.set_action(a.pos if a != null else null, floor_y)
	if a != null:
		if _last_prompt != a.label:
			hud.prompt.show(a.label)
			_last_prompt = a.label
		var world_pos: Vector3 = Vector3(a.pos.x, floor_y + 2.3, a.pos.z)
		var screen: Vector2 = cam_rig.camera.unproject_position(world_pos)
		var behind: bool = cam_rig.camera.is_position_behind(world_pos)
		hud.prompt.set_screen_position(screen.x, screen.y, not behind)
	elif _last_prompt != "":
		hud.prompt.hide()
		_last_prompt = ""
	var hint: Variant = _tracker.hint_target() if _hint_on else null
	_highlights.set_hint(hint, _world.floor_at(hint.x, hint.z) if hint != null else 0.0)


## Botón de acción (o tecla E).
func do_action() -> void:
	if paused or _phase == PHASE_FINISHED:
		return
	if _current_action != null:
		_current_action.run.call()
		_update_interaction()
		return
	var h: HandsState = _hands.hands()
	if h.kind == HandsState.KIND_METER:
		toast("Con el multímetro podés medir la caja de conexión o un panel instalado.")
		return
	if h.kind == HandsState.KIND_CABLE:
		_hands.clear()
		toast("Soltaste el cable. Podés volver a tomarlo desde su equipo.")
		_changed()
		return
	if h.kind == HandsState.KIND_CARRY:
		_drop_carried()


func _drop_carried() -> void:
	var h: HandsState = _hands.hands()
	if h.kind != HandsState.KIND_CARRY:
		return
	var p: Vector3 = player.position + player.forward() * 1.3
	var b: LevelBounds = _world.layout.bounds
	p.x = clampf(p.x, b.min_x + 1.0, b.max_x - 1.0)
	p.y = 0.0
	p.z = clampf(p.z, b.min_z + 1.0, b.max_z - 1.2)
	var item_kind: StringName = h.item_kind
	var faulty: bool = h.item_faulty
	_hands.clear()
	_world.add_pickup(item_kind, p, faulty, player.rotation.y)
	sfx("place")
	_changed()


func toggle_meter() -> void:
	if paused or _phase == PHASE_FINISHED:
		return
	var hud: HudPort = _d.hud
	if _hands.kind() == HandsState.KIND_METER:
		_hands.set_meter(false)
		hud.meter.hide()
		hud.actions.set_meter_on(false)
		return
	if not _hands.is_free():
		toast("Primero soltá lo que tenés en la mano.")
		return
	_hands.set_meter(true)
	hud.actions.set_meter_on(true)
	hud.meter.set_reading("--- V", "V⎓ CC", "Acercate a la caja de conexión o a un panel instalado y tocá Medir.", &"idle")
	hud.meter.show()


func toggle_inspect() -> void:
	var ins: InspectCardPort = _d.hud.inspect
	if ins.visible:
		ins.hide()
		_open_inspect_id = ""
		return
	var c: InspectEntry = _current_inspect
	if c == null:
		return
	_open_inspect_id = c.id
	ins.show({"title": c.title, "body": c.body, "live": c.live_value()})
	sfx("beep")


func close_inspect() -> void:
	_open_inspect_id = ""


## Booster usado desde la barra durante la partida.
func use_booster(id: String) -> void:
	if id == Boosters.HINT and not _hint_on and _d.boosters.use(Boosters.HINT):
		_hint_on = true
		toast("Pista activada: seguí la flecha celeste.", &"good")
	elif id == Boosters.DRONE and not _drone_on and _d.boosters.use(Boosters.DRONE):
		_drone_on = true
		var any_dirty: bool = false
		for r: int in _world.rows.size():
			if _world.row_dirty(r):
				any_dirty = true
				break
		if _weather == WeatherSchedule.ZONDA_OVER and any_dirty:
			_launch_drone()
		else:
			toast("El dron va a limpiar los paneles cuando pase el Zonda.", &"good")
	_refresh_booster_bar()


func _refresh_booster_bar() -> void:
	var inv: Inventory = _d.inventory
	var slots: Array[BoosterSlot] = []
	if not _hint_on and inv.count(Boosters.HINT) > 0:
		slots.append(BoosterSlot.new(Boosters.HINT, "Pista", &"hint", inv.count(Boosters.HINT)))
	if _level.events.zonda_at_hour != LevelEvents.NO_ZONDA and not _drone_on and inv.count(Boosters.DRONE) > 0:
		slots.append(BoosterSlot.new(Boosters.DRONE, "Dron limpiador", &"drone", inv.count(Boosters.DRONE)))
	_d.hud.boosters.set_boosters(slots)


func _changed() -> void:
	_hud_timer = 0.0


func _sync_hud() -> void:
	var hud: HudPort = _d.hud
	hud.mission.set_objectives(_tracker.objectives())
	hud.mission.set_timer(_elapsed)
	if _snap != null and _phase != PHASE_BUILD:
		hud.stats.update(_snap)
	if _weather == WeatherSchedule.ZONDA_WARNING:
		hud.alert.set_countdown(_warning_seconds())
	var ins: InspectCardPort = hud.inspect
	if ins.visible and _open_inspect_id != "":
		if _current_inspect == null or _current_inspect.id != _open_inspect_id:
			ins.hide()
			_open_inspect_id = ""
		else:
			ins.update_live(_current_inspect.live_value())


func _update_visuals(dt: float) -> void:
	var w: PlantWorld = _world
	var s: SimSnapshot = _snap
	var running: bool = _phase != PHASE_BUILD
	var z_target: float = 0.0
	var zw: ZondaWindow = _weather_schedule.zonda_window()
	if zw != null and running:
		if _weather == WeatherSchedule.ZONDA_WARNING:
			z_target = 0.35 * (_hour - zw.warn_from) / (zw.storm_from - zw.warn_from)
		elif _weather == WeatherSchedule.ZONDA_STORM:
			z_target = 1.0
		elif _weather == WeatherSchedule.ZONDA_OVER:
			z_target = maxf(0.0, 1.0 - (_hour - zw.storm_to) / 0.35)
	_zonda_fx += (z_target - _zonda_fx) * minf(1.0, dt * 2.5)
	_env.update(dt, _hour, _zonda_fx, _weather_schedule.cloudiness_at(_hour), player.position)
	var night: float = _env.night_factor()
	var lit: bool = running and s != null and not s.blackout
	w.city.set_lit(night if lit else 0.0)
	w.set_room_light(night if lit else 0.0)
	if not running or s == null:
		w.inverter.set_screen("STANDBY", Color("#8fa7a1"))
		return
	for r: int in w.rows.size():
		var open: bool = w.row_open(r)
		for m: Mount in (w.rows[r] as Array[Mount]):
			m.set_glow(0.0 if open else 0.28 * s.irradiance)
	for b: BatterySlot in w.batteries:
		b.set_charge(s.soc_pct)
	var pump_on: bool = w.pump != null and lit and _pump_load_active(s.hour)
	if w.pump != null:
		w.pump.set_running(pump_on)
	var open_row: int = -1
	for r: int in w.rows.size():
		if w.panels_in_row(r) > 0 and w.row_open(r):
			open_row = r
			break
	if s.blackout:
		w.inverter.set_screen("SIN CARGA", Color("#ff5a4d"))
	elif open_row >= 0 and s.irradiance > 0.05:
		w.inverter.set_screen("F%d: 0 V" % (open_row + 1), Color("#ffb547"))
	elif s.gen_kw > s.load_kw:
		w.inverter.set_screen("ON %s kW" % JsMath.fmt_decimal(s.gen_kw), Color("#5fe3f5"))
	else:
		w.inverter.set_screen("BAT %s kW" % JsMath.fmt_decimal(s.load_kw), Color("#ffd27a"))

	var gen: bool = s.gen_kw > 0.05 and _phase == PHASE_RUNNING
	for r: int in _row_flows.size():
		var f: Variant = _row_flows[r]
		if f != null:
			(f as EnergyFlowVisual).set_on(gen and w.panels_in_row(r) > 0 and not w.row_open(r))
	if _flow_orange != null:
		_flow_orange.set_on(gen)
	if _flow_link != null:
		_flow_link.set_on(gen)
	if _flow_blue != null:
		var full: bool = s.net_kw > 0.0 and s.soc_pct >= 0.999
		_flow_blue.set_on(_phase == PHASE_RUNNING and absf(s.net_kw) > 0.05 and not full)
		_flow_blue.set_direction(-1 if s.net_kw > 0.0 else 1)
	var delivering: bool = lit and _phase == PHASE_RUNNING
	if _flow_violet != null:
		_flow_violet.set_on(delivering)
	if _flow_grid != null:
		_flow_grid.set_on(delivering)
	if _flow_pump != null:
		_flow_pump.set_on(pump_on)


func _pump_load_active(hour: float) -> bool:
	for l: LoadBlock in _level.loads:
		if l.label.to_lower().contains("bomba") and Solar.block_active(l, hour):
			return true
	return false


# ======================================================================== depuración


func available_actions() -> Array[WorldAction]:
	return _interaction.available(_hands.hands())


func current_action_label() -> String:
	return _current_action.label if _current_action != null else ""


func game_hour() -> float:
	return _hour


func lost_panels() -> int:
	return _panels_lost


func cosmetics() -> Dictionary:
	return _d.cosmetics.duplicate()


func shed_loads() -> Array[String]:
	return _shed.duplicate()


func force_interaction_update() -> void:
	_update_interaction()


func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	_d.audio.set_wind(false)
	_hands.clear()
	_d.ui.toast.hide()
	_d.hud.reset()
	if root.get_parent() != null:
		root.get_parent().remove_child(root)
	root.queue_free()
