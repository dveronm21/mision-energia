extends TestCase
## Port de core.test.ts: SaveStore (memoria, archivo, corrupto), EventBus, AudioSynth.

const TEST_DIR: String = "user://tests_tmp"


func test_save_store_en_memoria() -> void:
	var s: SaveStore = SaveStore.in_memory()
	check_eq(s.load_value("x", {"a": 1}), {"a": 1}, "fallback")
	s.save_value("x", {"a": 2})
	var v: Dictionary = s.load_value("x", {})
	check_eq(int(v["a"]), 2, "valor guardado")
	v["a"] = 99
	check_eq(int((s.load_value("x", {}) as Dictionary)["a"]), 2, "load devuelve copia")
	s.clear_all()
	check_eq(s.load_value("x", null), null, "clear_all")
	check(s.is_in_memory(), "es en memoria")


func test_save_store_archivo_atomico() -> void:
	var path: String = "%s/save_ok.json" % TEST_DIR
	_cleanup()
	var s: SaveStore = SaveStore.new(path)
	s.save_value("wallet", {"balance": 5})
	s.save_value("lista", [1, 2.5, "tres"])
	check(FileAccess.file_exists(path), "existe el archivo")
	check(not FileAccess.file_exists(path + ".tmp"), "no queda el .tmp")
	check_eq(s.last_error(), OK, "sin error de disco")
	var again: SaveStore = SaveStore.new(path)
	check_eq(int((again.load_value("wallet", {}) as Dictionary)["balance"]), 5, "relee del disco")
	check_eq(again.load_value("lista", []), [1.0, 2.5, "tres"], "lista")
	var json: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(json is Dictionary and int((json as Dictionary)["version"]) == 1, "formato con versión")
	again.clear_all()
	check_eq(SaveStore.new(path).load_value("wallet", null), null, "clear_all persiste")
	_cleanup()


func test_save_store_corrupto_respalda_y_arranca_vacio() -> void:
	var path: String = "%s/save_bad.json" % TEST_DIR
	_cleanup()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIR))
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{no json")
	f.close()
	var s: SaveStore = SaveStore.new(path)
	check_eq(s.load_value("bad", 7), 7, "fallback con archivo corrupto")
	check(s.backup_path() != "", "creó respaldo")
	check(FileAccess.file_exists(s.backup_path()), "el respaldo existe")
	check_eq(FileAccess.get_file_as_string(s.backup_path()), "{no json", "el respaldo conserva el contenido")
	s.save_value("k", [1, 2])
	check_eq(SaveStore.new(path).load_value("k", []), [1.0, 2.0], "después sigue guardando")
	# JSON válido pero con forma inesperada también se trata como corrupto.
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("[1,2,3]")
	f.close()
	var s2: SaveStore = SaveStore.new(path)
	check(s2.backup_path() != "" and s2.backup_path() != s.backup_path(), "segundo respaldo distinto")
	check_eq(s2.load_value("k", "vacío"), "vacío", "arranca vacío")
	_cleanup()


func test_event_bus() -> void:
	var bus: EventBus = EventBus.new()
	var got: Array[int] = []
	var cb: Callable = func(b: int) -> void: got.append(b)
	bus.wallet_changed.connect(cb)
	bus.toast.connect(func(_t: String, _k: String) -> void: got.append(-1))
	bus.wallet_changed.emit(3)
	bus.wallet_changed.disconnect(cb)
	bus.wallet_changed.emit(4)
	check_eq(got, [3] as Array[int], "suscribe, filtra y desuscribe")
	var kinds: Array[String] = []
	bus.toast.connect(func(_t: String, k: String) -> void: kinds.append(k))
	bus.emit_toast("hola")
	check_eq(kinds, ["info"] as Array[String], "toast por defecto info")
	bus.free()


func test_audio_synth_headless_y_mute_persistente() -> void:
	var store: SaveStore = SaveStore.in_memory()
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var a: AudioSynth = AudioSynth.new()
	a.setup(store)
	a.play("coin") # antes de unlock: no-op
	check_eq(a.pending_samples(), 0, "sin unlock no suena")
	tree.root.add_child(a)
	a.unlock()
	for n: String in AudioSynth.SFX_NAMES:
		a.play(n)
	check(a.pending_samples() > 0, "encola muestras")
	a.set_wind(true)
	check(a.is_wind_on(), "viento encendido")
	await tree.process_frame
	await tree.process_frame
	a.set_wind(false)
	a.set_muted(true)
	check(a.is_muted(), "muteado")
	check_eq(a.pending_samples(), 0, "mute corta los efectos")
	a.play("win")
	check_eq(a.pending_samples(), 0, "muteado no suena")
	var b: AudioSynth = AudioSynth.new()
	b.setup(store)
	check(b.is_muted(), "recuerda el mute")
	b.free()
	a.queue_free()
	await tree.process_frame


func test_audio_recetas() -> void:
	check_eq(AudioSynth.SFX_RECIPES.size(), 11, "11 efectos")
	for n: String in AudioSynth.SFX_NAMES:
		check(AudioSynth.SFX_RECIPES.has(n), "receta " + n)
		var buf: PackedFloat32Array = AudioSynth.render_recipe(AudioSynth.SFX_RECIPES[n], AudioSynth.MIX_RATE)
		var peak: float = 0.0
		for x: float in buf:
			peak = maxf(peak, absf(x))
		check(buf.size() > 0 and peak > 0.01 and peak < 1.0, "%s audible (pico %f)" % [n, peak])
	var click: PackedFloat32Array = AudioSynth.render_recipe(AudioSynth.SFX_RECIPES["click"], 22050.0)
	check_eq(click.size(), int(ceil(0.08 * 22050.0)), "duración click = 30 ms + cola")


func _cleanup() -> void:
	var dir: DirAccess = DirAccess.open(TEST_DIR)
	if dir == null:
		return
	for f: String in dir.get_files():
		dir.remove(f)
