extends TestCase
## Equivalencia con la versión web: reproduce `tests/fixtures/golden.json` (generado por
## `app/tests/export-golden.ts`). Estrellas, puntaje, tips y tabla de balance exactos;
## kWh, SOC y demás floats con tolerancia 1e-6.

const GOLDEN_PATH: String = "res://tests/fixtures/golden.json"
const TOL: float = 1e-6
const FLOAT_KEYS: Array[String] = ["hour", "irradiance", "genKw", "loadKw", "netKw", "socKwh", "capKwh", "socPct"]
const BOOL_KEYS: Array[String] = ["isNight", "blackout", "finished", "won"]

var _golden: Dictionary = {}
var _levels: Dictionary[String, LevelDefinition] = {}
## Contadores para el resumen.
var scenarios_ok: int = 0
var scenarios_total: int = 0
var snapshots_compared: int = 0


func _init() -> void:
	var raw: String = FileAccess.get_file_as_string(GOLDEN_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	if parsed is Dictionary:
		_golden = parsed
	for l: LevelDefinition in Levels.all():
		_levels[l.id] = l


func test_golden_cargado() -> void:
	check(not _golden.is_empty(), "no se pudo leer %s (corré npx tsx tests/export-golden.ts en app/)" % GOLDEN_PATH)


func test_mejor_compra() -> void:
	var best: Dictionary = _golden.get("best", {})
	for id: String in _levels.keys():
		var b: Autoplay.BestPurchase = Autoplay.best_purchase(_levels[id])
		var expected: Purchase = _purchase(best.get(id, {}))
		check_eq(b.buy.describe(), expected.describe(), "mejor compra " + id)


func test_escenarios_autoplay() -> void:
	var every: int = int(_golden.get("snapshotEvery", 10))
	for sc: Variant in _golden.get("scenarios", []):
		var g: Dictionary = sc
		var tag: String = "%s/%s" % [g["level"], g["name"]]
		var level: LevelDefinition = _levels[str(g["level"])]
		var buy: Purchase = _purchase(g["buy"])
		var before: int = failures().size()
		scenarios_total += 1
		check_eq(LevelCatalog.new().cost(level, buy), int(g["cost"]), tag + " costo")
		var o: Autoplay.PlayOutcome = Autoplay.play(level, buy, _strategy(g["strategy"]), float(g["dt"]), true)
		check_eq(o.steps.size(), int(g["stepCount"]), tag + " pasos")
		_compare_samples(o.steps, g["snapshots"], every, tag)
		if not o.steps.is_empty():
			_compare_snap(o.steps.back(), g["final"], tag + " final")
		_compare_result(o.result, g["result"], tag)
		_near_or_null(o.blackout_hour, g["blackoutHour"], tag + " blackoutHour")
		check_near(o.min_soc_pct, float(g["minSocPct"]), TOL, tag + " minSocPct")
		if failures().size() == before:
			scenarios_ok += 1


func test_corridas_simulador() -> void:
	var every: int = int(_golden.get("snapshotEvery", 10))
	for run: Variant in _golden.get("simRuns", []):
		var g: Dictionary = run
		var tag: String = "sim " + str(g["name"])
		var level: LevelDefinition = _levels[str(g["level"])]
		var plant: PlantState = _plant(g["plant"])
		var sim: EnergySimulator = EnergySimulator.new()
		sim.start(level, plant)
		_compare_snap(sim.snapshot(), g["start"], tag + " inicio")
		check_near(sim.effective_panels(plant), float(g["effectivePanels"]), TOL, tag + " effectivePanels")
		var steps: Array[SimSnapshot] = []
		var s: SimSnapshot = sim.snapshot()
		while not s.finished:
			s = sim.step(float(g["dt"]), plant, str(g["weather"]))
			steps.append(s)
		check_eq(steps.size(), int(g["stepCount"]), tag + " pasos")
		_compare_samples(steps, g["snapshots"], every, tag)
		_compare_snap(s, g["final"], tag + " final")


func test_casos_scoring() -> void:
	var sc: Scoring = Scoring.new()
	for c: Variant in _golden.get("scoring", []):
		var g: Dictionary = c
		var tag: String = "scoring %s/%s" % [g["level"], g["name"]]
		var inp: Dictionary = g["input"]
		var i: ScoringInput = ScoringInput.new()
		i.won = bool(inp["won"])
		i.final_soc_pct = float(inp["finalSocPct"])
		i.spent = int(inp["spent"])
		i.panels_lost = int(inp["panelsLost"])
		i.blackout_hour = float(inp["blackoutHour"]) if inp["blackoutHour"] != null else ScoringInput.NO_BLACKOUT
		i.duration_sec = float(inp["durationSec"])
		i.had_open_row_at_end = bool(inp["hadOpenRowAtEnd"])
		i.had_dirty_row_at_end = bool(inp["hadDirtyRowAtEnd"])
		i.batteries = int(inp["batteries"])
		i.panels = int(inp["panels"]) if inp["panels"] != null else ScoringInput.PANELS_UNKNOWN
		i.non_essential_on = bool(inp["nonEssentialOn"])
		_compare_result(sc.evaluate(_levels[str(g["level"])], i), g["result"], tag)


func test_compras_posibles() -> void:
	var aff: Dictionary = _golden.get("affordable", {})
	var catalog: LevelCatalog = LevelCatalog.new()
	for id: String in _levels.keys():
		var level: LevelDefinition = _levels[id]
		var expected: Array = aff.get(id, [])
		var got: Array[Purchase] = Autoplay.affordable_purchases(level)
		check_eq(got.size(), expected.size(), id + " cantidad de compras")
		for k: int in mini(got.size(), expected.size()):
			var e: Dictionary = expected[k]
			var tag: String = "%s compra %s" % [id, got[k].describe()]
			check_eq(got[k].describe(), _purchase(e["buy"]).describe(), tag + " misma compra")
			check_eq(catalog.cost(level, got[k]), int(e["cost"]), tag + " costo")
			var o: Autoplay.PlayOutcome = Autoplay.play(level, got[k])
			check_eq(o.result.won, bool(e["won"]), tag + " won")
			check_eq(o.result.stars, int(e["stars"]), tag + " estrellas")
			check_eq(o.result.score, int(e["score"]), tag + " puntaje")
			check_near(o.result.final_soc_pct, float(e["finalSocPct"]), TOL, tag + " soc")


func test_tabla_de_balance() -> void:
	var bc: BalanceCheck = BalanceCheck.new()
	check(bc.run(), "balance sin problemas: %s" % ", ".join(bc.problems))
	var expected: Array = _golden.get("balanceTable", [])
	check_eq(bc.lines.size(), expected.size(), "líneas de la tabla")
	for k: int in mini(bc.lines.size(), expected.size()):
		check_eq(bc.lines[k], str(expected[k]), "tabla línea %d" % k)


# ---------------------------------------------------------------- helpers

func _compare_samples(steps: Array[SimSnapshot], samples: Array, every: int, tag: String) -> void:
	for smp: Variant in samples:
		var d: Dictionary = smp
		var idx: int = int(d["step"]) - 1
		check_eq((idx + 1) % every, 0, tag + " muestreo")
		if idx >= steps.size():
			check(false, "%s paso %d inexistente" % [tag, idx + 1])
			continue
		_compare_snap(steps[idx], d["snap"], "%s paso %d" % [tag, idx + 1])


func _compare_snap(s: SimSnapshot, expected: Dictionary, tag: String) -> void:
	snapshots_compared += 1
	var got: Dictionary = s.to_dict()
	for k: String in FLOAT_KEYS:
		check_near(float(got[k]), float(expected[k]), TOL, "%s %s" % [tag, k])
	for k: String in BOOL_KEYS:
		check_eq(bool(got[k]), bool(expected[k]), "%s %s" % [tag, k])


func _compare_result(r: LevelResult, expected: Dictionary, tag: String) -> void:
	check_eq(r.level_id, str(expected["levelId"]), tag + " levelId")
	check_eq(r.won, bool(expected["won"]), tag + " won")
	check_eq(r.stars, int(expected["stars"]), tag + " estrellas")
	check_eq(r.score, int(expected["score"]), tag + " puntaje")
	check_near(r.final_soc_pct, float(expected["finalSocPct"]), TOL, tag + " finalSocPct")
	check_eq(r.spent, int(expected["spent"]), tag + " spent")
	check_eq(r.budget, int(expected["budget"]), tag + " budget")
	check_eq(r.panels_lost, int(expected["panelsLost"]), tag + " panelsLost")
	_near_or_null(r.blackout_hour, expected["blackoutHour"], tag + " blackoutHour")
	var tips: Array[String] = []
	for t: Variant in expected["tips"]:
		tips.append(str(t))
	check_eq(r.tips, tips, tag + " tips")


func _near_or_null(got: float, expected: Variant, tag: String) -> void:
	if expected == null:
		check(got < 0.0, tag + " (esperaba sin apagón)")
	else:
		check_near(got, float(expected), TOL, tag)


func _purchase(d: Dictionary) -> Purchase:
	return Purchase.make(int(d.get("panels", 0)), int(d.get("batteries", 0)), bool(d.get("kitZonda", false)))


func _strategy(d: Dictionary) -> Autoplay.Strategy:
	var s: Autoplay.Strategy = Autoplay.perfect()
	s.repair_connector = bool(d["repairConnector"])
	s.clean_after_zonda = bool(d["cleanAfterZonda"])
	s.zonda = str(d["zonda"])
	s.shed_non_essential_at_night = bool(d["shedNonEssentialAtNight"])
	s.bonus_kwh = float(d["bonusKwh"])
	return s


func _plant(d: Dictionary) -> PlantState:
	var p: PlantState = PlantState.new()
	for v: Variant in d["panelsPerRow"]:
		p.panels_per_row.append(int(v))
	for v: Variant in d["rowOpen"]:
		p.row_open.append(bool(v))
	for v: Variant in d["rowDirty"]:
		p.row_dirty.append(bool(v))
	for v: Variant in d["rowDefense"]:
		p.row_defense.append(bool(v))
	p.batteries = int(d["batteries"])
	p.protection_installed = bool(d["protectionInstalled"])
	p.cables_ok = bool(d["cablesOk"])
	for v: Variant in d["shedLoads"]:
		p.shed_loads.append(str(v))
	p.bonus_kwh = float(d.get("bonusKwh", 0.0))
	return p
