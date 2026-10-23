extends SceneTree
## Runner de tests headless del dominio:
##   godot --headless --path godot -s res://tests/run_tests.gd
## Corre cada método `test_*` de las suites de `tests/unit/`, imprime un resumen y sale con código ≠ 0
## si algo falla. Filtro opcional: `-- --solo=golden` (subcadena del archivo de suite).

const SUITES: Array[String] = [
	"res://tests/unit/test_core.gd",
	"res://tests/unit/test_sim.gd",
	"res://tests/unit/test_levels.gd",
	"res://tests/unit/test_economy.gd",
	"res://tests/unit/test_golden.gd",
	"res://tests/unit/test_world.gd",
	"res://tests/unit/test_layout.gd",
	"res://tests/unit/test_plant_world.gd",
	"res://tests/unit/test_interaction.gd",
	"res://tests/unit/test_mission_tracker.gd",
	"res://tests/unit/test_game_session.gd",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var only: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--solo="):
			only = a.trim_prefix("--solo=")
	var t0: int = Time.get_ticks_msec()
	var cases: int = 0
	var failed_cases: int = 0
	var checks: int = 0
	var report: Array[String] = []
	for path: String in SUITES:
		if only != "" and not path.contains(only):
			continue
		var script: GDScript = load(path)
		if script == null:
			report.append("ERROR: no se pudo cargar %s" % path)
			failed_cases += 1
			continue
		var suite: TestCase = script.new()
		var names: Array[String] = []
		for m: Dictionary in script.get_script_method_list():
			var n: String = m["name"]
			if n.begins_with("test_") and not names.has(n):
				names.append(n)
		var suite_fail: int = 0
		for n: String in names:
			suite.reset()
			var t: int = Time.get_ticks_msec()
			await Callable(suite, n).call()
			cases += 1
			var f: Array[String] = suite.failures()
			if f.is_empty():
				print("  ok   %s::%s (%d ms)" % [path.get_file(), n, Time.get_ticks_msec() - t])
			else:
				failed_cases += 1
				suite_fail += 1
				print("  FAIL %s::%s" % [path.get_file(), n])
				for k: int in mini(f.size(), 15):
					print("       - " + f[k])
				if f.size() > 15:
					print("       … y %d fallas más" % (f.size() - 15))
		checks += suite.checks()
		if path.ends_with("test_golden.gd"):
			report.append("Golden: %d/%d escenarios idénticos, %d snapshots comparados (tolerancia 1e-6)" % [
				suite.get("scenarios_ok"), suite.get("scenarios_total"), suite.get("snapshots_compared")])
		print("%s: %d casos, %d con fallas" % [path.get_file(), names.size(), suite_fail])
	print("")
	for r: String in report:
		print(r)
	print("RESUMEN: %d casos, %d chequeos, %d casos fallidos (%d ms)" % [cases, checks, failed_cases, Time.get_ticks_msec() - t0])
	print("RESULTADO: %s" % ("OK" if failed_cases == 0 else "FALLÓ"))
	quit(0 if failed_cases == 0 else 1)
