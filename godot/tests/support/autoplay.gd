class_name Autoplay
extends RefCounted
## Jugador automático para tests y balance (port de `app/tests/support/autoplay.ts`): reproduce lo que
## haría el mundo 3D (fallas, Zonda, defensa, limpieza) contra el simulador real, con paso fijo.


## Estrategia del jugador automático.
class Strategy:
	extends RefCounted
	var repair_connector: bool = true
	var clean_after_zonda: bool = true
	## "defense": pone filas en horizontal durante aviso+tormenta. "none": no hace nada. (El kit va en Purchase.)
	var zonda: String = "defense"
	var shed_non_essential_at_night: bool = false
	var bonus_kwh: float = 0.0

	func clone() -> Strategy:
		var s: Strategy = Strategy.new()
		s.repair_connector = repair_connector
		s.clean_after_zonda = clean_after_zonda
		s.zonda = zonda
		s.shed_non_essential_at_night = shed_non_essential_at_night
		s.bonus_kwh = bonus_kwh
		return s


class PlayOutcome:
	extends RefCounted
	var result: LevelResult
	var blackout_hour: float = LevelResult.NO_BLACKOUT
	var min_soc_pct: float = 1.0
	var steps: Array[SimSnapshot] = []


class BestPurchase:
	extends RefCounted
	var buy: Purchase
	var outcome: PlayOutcome


static func perfect() -> Strategy:
	return Strategy.new()


static func distribute(level: LevelDefinition, panels: int) -> Array[int]:
	var rows: Array[int] = []
	var left: int = panels
	for r: int in level.rows:
		var n: int = mini(level.panels_per_row, left)
		rows.append(n)
		left -= n
	return rows


## Juega un nivel completo. Con `record_steps` guarda cada snapshot en `outcome.steps`.
static func play(level: LevelDefinition, buy: Purchase, s: Strategy = null, dt: float = 0.05, record_steps: bool = false) -> PlayOutcome:
	if s == null:
		s = perfect()
	var catalog: LevelCatalog = LevelCatalog.new([level] as Array[LevelDefinition])
	var sim: EnergySimulator = EnergySimulator.new()
	var weather: WeatherSchedule = WeatherSchedule.new(level.events)
	var storm: StormImpact = StormImpact.new()
	var spent: int = catalog.cost(level, buy)
	var plant: PlantState = PlantState.new()
	plant.panels_per_row = distribute(level, buy.panels)
	for r: int in level.rows:
		plant.row_open.append(level.events.loose_connector and r == 0 and not s.repair_connector)
		plant.row_dirty.append(false)
		plant.row_defense.append(false)
	plant.batteries = buy.batteries
	plant.bonus_kwh = s.bonus_kwh
	sim.start(level, plant)
	var out: PlayOutcome = PlayOutcome.new()
	var panels_lost: int = 0
	var storm_applied: bool = false
	var snap: SimSnapshot = sim.snapshot()
	var non_essential: Array[String] = level.non_essential_labels()
	while not snap.finished:
		var phase: String = weather.phase_at(snap.hour)
		var defend: bool = s.zonda == "defense" and not buy.kit_zonda \
			and (phase == WeatherSchedule.ZONDA_WARNING or phase == WeatherSchedule.ZONDA_STORM)
		plant = plant.clone()
		for r: int in plant.row_defense.size():
			plant.row_defense[r] = defend
		if phase == WeatherSchedule.ZONDA_STORM and not storm_applied:
			var hit: StormHit = storm.apply(plant, buy.kit_zonda)
			plant = hit.plant
			panels_lost += hit.panels_lost
			storm_applied = true
		if phase == WeatherSchedule.ZONDA_OVER and s.clean_after_zonda:
			for r: int in plant.row_dirty.size():
				plant.row_dirty[r] = false
		plant.shed_loads = non_essential.duplicate() if (s.shed_non_essential_at_night and snap.is_night) else Array([], TYPE_STRING, &"", null)
		snap = sim.step(dt, plant, phase)
		if record_steps:
			out.steps.append(snap)
		if snap.hour > 20.0:
			out.min_soc_pct = minf(out.min_soc_pct, snap.soc_pct)
	out.blackout_hour = snap.hour if snap.blackout else LevelResult.NO_BLACKOUT
	var input: ScoringInput = ScoringInput.new()
	input.won = snap.won
	input.final_soc_pct = snap.soc_pct
	input.spent = spent
	input.panels_lost = panels_lost
	input.blackout_hour = out.blackout_hour
	input.duration_sec = 90.0
	input.had_open_row_at_end = plant.any_open()
	input.had_dirty_row_at_end = plant.any_dirty()
	input.batteries = buy.batteries
	input.panels = buy.panels
	input.non_essential_on = not s.shed_non_essential_at_night and non_essential.size() > 0
	out.result = Scoring.new().evaluate(level, input)
	return out


## Todas las compras posibles dentro del presupuesto (con al menos min_panels y 1 batería).
static func affordable_purchases(level: LevelDefinition, budget: int = -1) -> Array[Purchase]:
	if budget < 0:
		budget = level.budget
	var catalog: LevelCatalog = LevelCatalog.new([level] as Array[LevelDefinition])
	var out: Array[Purchase] = []
	var kits: Array[bool] = [false]
	if level.events.has_zonda():
		kits.append(true)
	for p: int in range(level.min_panels, level.max_panels() + 1):
		for b: int in range(1, level.battery_slots + 1):
			for k: bool in kits:
				var buy: Purchase = Purchase.make(p, b, k)
				if catalog.cost(level, buy) <= budget:
					out.append(buy)
	return out


## Mejor compra con juego perfecto (más estrellas, después más puntaje).
static func best_purchase(level: LevelDefinition) -> BestPurchase:
	var best: BestPurchase = null
	for buy: Purchase in affordable_purchases(level):
		var o: PlayOutcome = play(level, buy)
		if best == null or o.result.stars > best.outcome.result.stars \
				or (o.result.stars == best.outcome.result.stars and o.result.score > best.outcome.result.score):
			best = BestPurchase.new()
			best.buy = buy
			best.outcome = o
	return best
