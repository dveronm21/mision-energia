extends TestCase
## Port de sim.test.ts y scoring.test.ts.

var casa: LevelDefinition = Levels.casa()
var escuela: LevelDefinition = Levels.escuela()
var finca: LevelDefinition = Levels.finca()


func _calm_level() -> LevelDefinition:
	var l: LevelDefinition = escuela.clone()
	l.events = LevelEvents.calm()
	return l


func _run(level: LevelDefinition, dt: float, plant: PlantState = null) -> Array[SimSnapshot]:
	if plant == null:
		plant = PlantState.full_for(level)
	var sim: EnergySimulator = EnergySimulator.new()
	sim.start(level, plant)
	var out: Array[SimSnapshot] = []
	var s: SimSnapshot = sim.snapshot()
	while not s.finished:
		s = sim.step(dt, plant, WeatherSchedule.CALM)
		out.append(s)
	return out


func test_determinista() -> void:
	var a: Array[SimSnapshot] = _run(casa, 0.1)
	var b: Array[SimSnapshot] = _run(casa, 0.1)
	check_eq(a.size(), b.size(), "misma cantidad de pasos")
	var same: bool = true
	for i: int in a.size():
		same = same and a[i].to_dict() == b[i].to_dict()
	check(same, "misma entrada → misma salida")


func test_independiente_del_frame_rate() -> void:
	var a: SimSnapshot = _run(casa, 0.05).back()
	var b: SimSnapshot = _run(casa, 0.5).back()
	check_eq(a.won, b.won, "mismo resultado")
	check(absf(a.soc_kwh - b.soc_kwh) < 0.05, "%f vs %f" % [a.soc_kwh, b.soc_kwh])


func test_sin_generacion_de_noche() -> void:
	var night: int = 0
	var ok: bool = true
	for s: SimSnapshot in _run(casa, 0.1):
		if s.is_night:
			night += 1
			ok = ok and s.gen_kw == 0.0 and s.irradiance == 0.0
	check(night > 50, "hay noche")
	check(ok, "sin generación de noche")
	check_eq(Solar.sun_factor(2.0), 0.0, "sol 2 h")
	check_eq(Solar.sun_factor(26.0), 0.0, "sol 26 h")
	check(Solar.sun_factor(13.0) > 0.99, "pico")


func test_fila_abierta_polvo_defensa() -> void:
	var lvl: LevelDefinition = _calm_level()
	var sim: EnergySimulator = EnergySimulator.new()
	var base: PlantState = PlantState.full_for(lvl)
	sim.start(lvl, base)
	check_eq(sim.effective_panels(base), 6.0, "6 paneles")
	var p: PlantState = base.clone()
	p.row_open = [true, false]
	check_eq(sim.effective_panels(p), 3.0, "fila abierta")
	p = base.clone()
	p.row_dirty = [true, true]
	check_near(sim.effective_panels(p), 6.0 * 0.65, 1e-9, "polvo")
	p = base.clone()
	p.row_defense = [true, false]
	check_near(sim.effective_panels(p), 3.0 * 0.55 + 3.0, 1e-9, "defensa")
	p = base.clone()
	p.cables_ok = false
	check_eq(sim.effective_panels(p), 0.0, "cables mal")
	var g1: float = sim.step(0.05, base, WeatherSchedule.CALM).gen_kw
	var sim2: EnergySimulator = EnergySimulator.new()
	sim2.start(lvl, base)
	p = base.clone()
	p.row_open = [true, false]
	check_near(sim2.step(0.05, p, WeatherSchedule.CALM).gen_kw, g1 / 2.0, 1e-9, "mitad de generación")


func test_tormenta_25_por_ciento() -> void:
	var lvl: LevelDefinition = _calm_level()
	var p: PlantState = PlantState.full_for(lvl)
	var a: EnergySimulator = EnergySimulator.new()
	a.start(lvl, p)
	var b: EnergySimulator = EnergySimulator.new()
	b.start(lvl, p)
	var ca: SimSnapshot = a.step(0.05, p, WeatherSchedule.CALM)
	var sb: SimSnapshot = b.step(0.05, p, WeatherSchedule.ZONDA_STORM)
	check_near(sb.irradiance, ca.irradiance * 0.25, 1e-9, "irradiancia en tormenta")


func test_apagon() -> void:
	var p: PlantState = PlantState.full_for(casa)
	p.panels_per_row = [1]
	var s: SimSnapshot = _run(casa, 0.1, p).back()
	check(s.blackout and not s.won and s.finished, "apagón")
	check_eq(s.soc_kwh, 0.0, "batería vacía")
	check(s.hour > 19.0 and s.hour < 31.0, "hora del apagón")


func test_gana_y_no_pasa_capacidad() -> void:
	var all: Array[SimSnapshot] = _run(casa, 0.1)
	var last: SimSnapshot = all.back()
	check(last.won, "gana")
	check_eq(last.hour, casa.end_hour, "termina en end_hour")
	var ok: bool = true
	for s: SimSnapshot in all:
		ok = ok and s.soc_kwh <= s.cap_kwh + 1e-9
	check(ok, "nunca supera la capacidad")


func test_bonus_kwh() -> void:
	var p: PlantState = PlantState.full_for(casa)
	p.bonus_kwh = 4.0
	var sim: EnergySimulator = EnergySimulator.new()
	sim.start(casa, p)
	var s: SimSnapshot = sim.snapshot()
	check_eq(s.cap_kwh, casa.battery_kwh + 4.0, "capacidad")
	check_near(s.soc_kwh, casa.battery_kwh * casa.start_soc + 4.0, 1e-9, "carga")


func test_step_sin_start_no_explota() -> void:
	var sim: EnergySimulator = EnergySimulator.new()
	check(not sim.snapshot().finished, "snapshot vacío")


func test_cargas_apagadas() -> void:
	check_eq(Solar.load_kw(casa.loads, 20.0, []), 0.2 + 0.9, "20 h")
	check_eq(Solar.load_kw(casa.loads, 20.0, ["Luces y TV"] as Array[String]), 0.2, "apagadas")
	check_eq(Solar.load_kw(escuela.loads, 26.0, []), 0.2 + 0.3, "cruza medianoche")


func test_weather_schedule() -> void:
	var w: WeatherSchedule = WeatherSchedule.new(LevelEvents.make(false, 13.0, [CloudBand.make(10, 12, 0.4)] as Array[CloudBand]))
	check_eq(w.phase_at(12.9), WeatherSchedule.CALM, "12.9")
	check_eq(w.phase_at(13.0), WeatherSchedule.ZONDA_WARNING, "13.0")
	check_eq(w.phase_at(13.69), WeatherSchedule.ZONDA_WARNING, "13.69")
	check_eq(w.phase_at(13.75), WeatherSchedule.ZONDA_STORM, "13.75")
	check_eq(w.phase_at(14.01), WeatherSchedule.ZONDA_OVER, "14.01")
	check_near(w.warning_remaining(13.2), 0.5, 1e-9, "aviso restante")
	check_near(w.cloudiness_at(11.0), 0.6, 1e-9, "nubosidad")
	check_eq(WeatherSchedule.new(casa.events).phase_at(15.0), WeatherSchedule.CALM, "sin zonda")
	check(WeatherSchedule.new(casa.events).zonda_window() == null, "sin ventana")


func test_storm_impact() -> void:
	var p: PlantState = PlantState.full_for(_calm_level())
	p.row_defense = [true, false]
	var r: StormHit = StormImpact.new().apply(p, false)
	check_eq(r.panels_lost, 1, "un panel")
	check_eq(r.plant.panels_per_row, [3, 2] as Array[int], "pierde en la fila sin defensa")
	check_eq(r.plant.row_dirty, [true, true] as Array[bool], "ensucia todo")
	check_eq(p.panels_per_row, [3, 3] as Array[int], "no muta la original")
	check_eq(StormImpact.new().apply(PlantState.full_for(_calm_level()), true).panels_lost, 0, "kit")


func test_autoplay_booster_no_reemplaza_aprender() -> void:
	var s: Autoplay.Strategy = Autoplay.perfect()
	s.repair_connector = false
	s.bonus_kwh = 4.0
	check(not Autoplay.play(escuela, Purchase.make(4, 2, false), s).result.won, "sigue perdiendo")


func _base_input() -> ScoringInput:
	var i: ScoringInput = ScoringInput.new()
	i.won = true
	i.final_soc_pct = 0.5
	i.spent = 11000
	i.duration_sec = 80.0
	i.batteries = 2
	i.panels = 5
	return i


func test_scoring_estrellas() -> void:
	var sc: Scoring = Scoring.new()
	check_eq(sc.evaluate(finca, _base_input()).stars, 3, "3★")
	var i: ScoringInput = _base_input()
	i.panels_lost = 1
	check_eq(sc.evaluate(finca, i).stars, 2, "panel perdido")
	i = _base_input()
	i.spent = finca.budget
	check_eq(sc.evaluate(finca, i).stars, 2, "gasto total")
	i = _base_input()
	i.final_soc_pct = finca.two_star_soc - 0.01
	check_eq(sc.evaluate(finca, i).stars, 1, "soc bajo")
	i = _lost(26.0)
	var lost: LevelResult = sc.evaluate(finca, i)
	check_eq(lost.stars, 0, "perdió")
	check_eq(lost.score, int((26.0 - finca.start_hour) * 25.0), "puntaje perdiendo")
	check(sc.evaluate(finca, _base_input()).score > 1000, "puntaje ganando")


func _lost(hour: float) -> ScoringInput:
	var i: ScoringInput = _base_input()
	i.won = false
	i.final_soc_pct = 0.0
	i.blackout_hour = hour
	return i


func test_scoring_tips() -> void:
	var sc: Scoring = Scoring.new()
	var i: ScoringInput = _lost(27.0)
	i.had_open_row_at_end = true
	i.had_dirty_row_at_end = true
	var r: LevelResult = sc.evaluate(finca, i)
	check(r.tips[0].contains("conector flojo"), "tip conector")
	check(r.tips[1].contains("polvo"), "tip polvo")
	check(r.tips.size() <= 3, "máximo 3")
	i = _lost(27.0)
	i.batteries = 1
	check(_any(sc.evaluate(finca, i).tips, "batería"), "tip baterías")
	i = _lost(27.0)
	i.panels = 4
	check(_any(sc.evaluate(finca, i).tips, "pocos paneles"), "tip paneles")
	i = _lost(27.0)
	i.non_essential_on = true
	check(_any(sc.evaluate(finca, i).tips, "no son esenciales"), "tip cargas")
	i = _base_input()
	i.panels_lost = 2
	check(_any(sc.evaluate(finca, i).tips, "defensa"), "tip defensa")
	check(sc.evaluate(finca, _base_input()).tips.size() >= 1, "siempre hay tip")


func _any(tips: Array[String], needle: String) -> bool:
	for t: String in tips:
		if t.contains(needle):
			return true
	return false
