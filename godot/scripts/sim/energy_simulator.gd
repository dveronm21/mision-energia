class_name EnergySimulator
extends RefCounted
## Simulador energético puro y determinista (acople en CC simplificado), igual a `EnergySimulator.ts`:
## generación → consumo directo; el excedente carga baterías (η = 0,95); el déficit lo cubren las baterías.
## Batería vacía con déficit = apagón (pierde). Llegar a `end_hour` = gana.
## La capacidad del banco se fija en `start()` (batteries × battery_kwh + bonus_kwh).

var _opts: SimulatorOptions
var _level: LevelDefinition = null
var _snap: SimSnapshot = SimSnapshot.new()


func _init(opts: SimulatorOptions = null) -> void:
	_opts = opts if opts != null else SimulatorOptions.new()


func options() -> SimulatorOptions:
	return _opts


## Inicializa con nivel y planta al activar.
func start(level: LevelDefinition, plant: PlantState) -> void:
	_level = level
	var bonus: float = maxf(0.0, plant.bonus_kwh)
	var bats: float = float(maxi(0, plant.batteries))
	var cap: float = bats * level.battery_kwh + bonus
	var soc: float = minf(cap, bats * level.battery_kwh * level.start_soc + bonus)
	_snap = _compute(level.start_hour, plant, WeatherSchedule.CALM, soc, cap)


## Avanza `dt_hours` de reloj de juego con el estado actual de la planta.
func step(dt_hours: float, plant: PlantState, weather: String) -> SimSnapshot:
	var level: LevelDefinition = _level
	if level == null:
		push_error("EnergySimulator: llamá a start() antes de step()")
		return snapshot()
	if _snap.finished or not (dt_hours > 0.0):
		return snapshot()
	var remaining: float = minf(dt_hours, level.end_hour - _snap.hour)
	var hour: float = _snap.hour
	var soc_kwh: float = _snap.soc_kwh
	var cap: float = _snap.cap_kwh
	var s: SimSnapshot = _snap.clone()
	while remaining > 1e-9:
		var h: float = minf(_opts.max_substep_hours, remaining)
		remaining -= h
		hour += h
		s = _compute(hour, plant, weather, soc_kwh, cap)
		var delta: float = s.net_kw * h * (_opts.charge_efficiency if s.net_kw > 0.0 else 1.0)
		soc_kwh = minf(cap, soc_kwh + delta)
		if soc_kwh <= 1e-9 and s.net_kw < 0.0:
			s.soc_kwh = 0.0
			s.soc_pct = 0.0
			s.blackout = true
			s.finished = true
			s.won = false
			_snap = s
			return snapshot()
		s.soc_kwh = soc_kwh
		s.soc_pct = soc_kwh / cap if cap > 0.0 else 0.0
	if hour >= level.end_hour - 1e-9:
		s.hour = level.end_hour
		s.finished = true
		s.won = true
	_snap = s
	return snapshot()


func snapshot() -> SimSnapshot:
	return _snap.clone()


## Generación efectiva de la planta en "paneles equivalentes" (pura, pública para tests y HUD).
func effective_panels(plant: PlantState) -> float:
	if not plant.cables_ok or not plant.protection_installed:
		return 0.0
	var n: float = 0.0
	for r: int in plant.panels_per_row.size():
		if r < plant.row_open.size() and plant.row_open[r]:
			continue
		var k: float = float(plant.panels_per_row[r])
		if r < plant.row_dirty.size() and plant.row_dirty[r]:
			k *= 1.0 - _opts.dust_loss
		if r < plant.row_defense.size() and plant.row_defense[r]:
			k *= _opts.defense_factor
		n += k
	return n


func _compute(hour: float, plant: PlantState, weather: String, soc_kwh: float, cap_kwh: float) -> SimSnapshot:
	var level: LevelDefinition = _level
	var sun: float = Solar.sun_factor(hour)
	var irradiance: float = sun * Solar.cloud_factor(level.events.clouds, hour) \
		* (_opts.storm_factor if weather == WeatherSchedule.ZONDA_STORM else 1.0)
	var s: SimSnapshot = SimSnapshot.new()
	s.hour = hour
	s.irradiance = irradiance
	s.gen_kw = minf(level.inverter_kw, effective_panels(plant) * level.panel_kw * irradiance)
	s.load_kw = Solar.load_kw(level.loads, hour, plant.shed_loads)
	s.net_kw = s.gen_kw - s.load_kw
	s.soc_kwh = soc_kwh
	s.cap_kwh = cap_kwh
	s.soc_pct = soc_kwh / cap_kwh if cap_kwh > 0.0 else 0.0
	s.is_night = sun <= 0.0
	s.blackout = false
	s.finished = false
	s.won = false
	return s
