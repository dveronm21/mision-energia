extends SceneTree
## Rendimiento del modo TV en esta PC: mide los cuadros por segundo (sin tope ni VSync, para ver
## el margen) de una partida cooperativa y del versus en pantalla dividida, con dos tablets
## simuladas caminando todo el tiempo, en Casa (nivel chico) y en el Parque solar (el más grande).
## Calidad fija (sin `AutoQuality`) para comparar. Imprime una tabla y la guarda en
## res://tools/out/bench.txt.
##   godot --path godot --rendering-driver opengl3 -s res://tools/bench_versus.gd -- --tv --tv-bind=127.0.0.1 --tv-port=18785 [--secs=12] [--windowed] [--screen=1] [--only=parque]

const ShotTv = preload("res://tools/shot_tv.gd")
const TestSession = preload("res://tests/unit/test_game_session.gd")

var _app: App
var _frame_n: int = 0
var _secs: float = 12.0
var _lines: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--secs="):
			_secs = float(a.trim_prefix("--secs="))
	var root: Window = get_root()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--screen="):
			DisplayServer.window_set_current_screen(int(a.trim_prefix("--screen=")))
	if OS.get_cmdline_user_args().has("--windowed"):
		root.size = Vector2i(1920, 1080)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	var services: AppServices = root.get_node("Services")
	services._build(SaveStore.in_memory())
	DirAccess.make_dir_recursive_absolute("res://tools/out")
	_app = (load("res://scenes/Main.tscn") as PackedScene).instantiate() as App
	root.add_child(_app)
	await _frames(5)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0

	_log("GPU: %s (%s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()])
	_log("API: %s" % RenderingServer.get_video_adapter_api_version())
	_log("Ventana: %s, pantalla %d de %d (%s Hz)" % [str(root.size), DisplayServer.window_get_current_screen(),
		DisplayServer.get_screen_count(), str(DisplayServer.screen_get_refresh_rate(DisplayServer.window_get_current_screen()))])
	_log("Escala de la UI: %.2f" % root.content_scale_factor)

	var url: String = "ws://127.0.0.1:%d/ws" % _app.tv.server.get_http_port()
	var ana: Variant = ShotTv.FakeTablet.new("Ana")
	var beto: Variant = ShotTv.FakeTablet.new("Beto")
	var both: Array = [ana, beto]
	ana.open(url)
	beto.open(url)
	await _pump_until(both, func() -> bool: return ana.ws.get_ready_state() == WebSocketPeer.STATE_OPEN and beto.ws.get_ready_state() == WebSocketPeer.STATE_OPEN)
	ana.hello()
	await _pump_until(both, func() -> bool: return not ana.welcome.is_empty())
	beto.hello()
	await _pump_until(both, func() -> bool: return not beto.welcome.is_empty())

	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--soak="):
			await _soak(both, float(a.trim_prefix("--soak=")))
			quit(0)
			return

	_log("")
	_log("%-34s %8s %8s %8s %9s %7s" % ["escena", "FPS prom", "1% bajo", "peor ms", "llamadas", "VRAM MB"])
	var levels: Array[String] = ["casa", "parque"]
	var qs: Array[int] = [1, 2]
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			levels = [a.trim_prefix("--only=")] as Array[String]
			qs = [2] as Array[int]
	for level_id: String in levels:
		for q: int in qs:
			# Partida normal del tele (cooperativo, los dos en la misma planta).
			_app.start_level(LevelRun.make(level_id, DuelMatch.fixed_purchase(level_id), [] as Array[StringName]))
			await _pump(both, 30)
			_app.session.set_quality(q)
			_app.session._auto_q = null
			await _measure(both, "TV coop · %s · %s" % [level_id, _qname(q)], [_app.session])
			_app.show_menu()
			await _pump(both, 10)

			# Versus en pantalla dividida, con una planta ya activada (flujos de energía y clima).
			_app.start_versus(level_id)
			await _pump(both, 10)
			var v: SplitVersus = _app.versus
			v.countdown = 0.0
			await _pump(both, 5)
			var ss: Array[GameSession] = []
			for side: SplitSide in v.sides():
				side.session.set_quality(q)
				side.session._auto_q = null
				ss.append(side.session)
			if level_id == "casa":
				TestSession._build_casa(ss[1])
			await _measure(both, "Versus · %s · %s" % [level_id, _qname(q)], ss)
			_app.leave_versus()
			await _pump(both, 10)

	_log("")
	_log("Memoria del proceso: %.0f MB (pico %.0f MB)" % [OS.get_static_memory_usage() / 1048576.0, OS.get_static_memory_peak_usage() / 1048576.0])
	var f: FileAccess = FileAccess.open("res://tools/out/bench.txt", FileAccess.WRITE)
	f.store_string("\n".join(_lines) + "\n")
	f.close()
	quit(0)


## Resistencia en condiciones reales: versus en el Parque con VSync, el tope de FPS y la calidad
## automática como en el juego (calidad alta). Cada 30 s: FPS y lo que hizo `AutoQuality`.
func _soak(tablets: Array, secs: float) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	FrameRate.apply(FrameRate.AUTO)
	_app.start_versus("parque")
	await _pump(tablets, 10)
	var v: SplitVersus = _app.versus
	v.countdown = 0.0
	for side: SplitSide in v.sides():
		side.session.set_quality(2)
	_log("Resistencia: versus · parque · alta · VSync · %d s" % int(secs))
	_log("%6s %8s %8s %s" % ["seg", "FPS prom", "FPS min", "calidad/escala por mitad"])
	var t0: int = Time.get_ticks_usec()
	while (Time.get_ticks_usec() - t0) / 1e6 < secs:
		var times: Array[float] = []
		await _walk(tablets, 30.0, times)
		var total: float = 0.0
		for t: float in times:
			total += t
		times.sort()
		var aq: Array[String] = []
		for side: SplitSide in v.sides():
			var q: AutoQuality = side.session._auto_q
			aq.append("%d/%.2f" % [q.quality, AutoQuality.SCALES[q.scale_step]] if q != null else "-")
		_log("%6d %8.1f %8.1f %s" % [int((Time.get_ticks_usec() - t0) / 1e6), times.size() / total, 1.0 / times.back(), "  ".join(aq)])
	var f: FileAccess = FileAccess.open("res://tools/out/bench_soak.txt", FileAccess.WRITE)
	f.store_string("
".join(_lines) + "
")
	f.close()


func _measure(tablets: Array, label: String, sessions: Array[GameSession]) -> void:
	# Calentamiento: shaders y primera carga.
	await _walk(tablets, 2.0, null)
	var times: Array[float] = []
	await _walk(tablets, _secs, times)
	times.sort()
	var total: float = 0.0
	for t: float in times:
		total += t
	var avg_fps: float = times.size() / total if total > 0.0 else 0.0
	# 1 % bajo: FPS promedio del 1 % de cuadros más lentos.
	var n: int = maxi(1, times.size() / 100)
	var slow: float = 0.0
	for i: int in n:
		slow += times[times.size() - 1 - i]
	var low_fps: float = n / slow if slow > 0.0 else 0.0
	var calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var vram: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0
	_log("%-34s %8.0f %8.0f %8.1f %9d %7.0f" % [label, avg_fps, low_fps, times.back() * 1000.0, calls, vram])
	await _shot(label)


## Las dos tablets caminan en círculos (la cámara se mueve) durante `secs`; anota cada cuadro.
func _walk(tablets: Array, secs: float, times: Variant) -> void:
	var t0: int = Time.get_ticks_usec()
	var last: int = t0
	var k: int = 0
	while (Time.get_ticks_usec() - t0) / 1e6 < secs:
		var ang: float = (Time.get_ticks_usec() - t0) / 1e6 * 1.3
		for i: int in tablets.size():
			tablets[i].stick = Vector2(cos(ang + i * PI), sin(ang + i * PI)) * 0.9
		k += 1
		_tick(tablets, k % 3 == 0)
		await process_frame
		var now: int = Time.get_ticks_usec()
		if times != null:
			(times as Array).append((now - last) / 1e6)
		last = now
	for t: Variant in tablets:
		t.stick = Vector2.ZERO
		t.send_input()


func _shot(label: String) -> void:
	var file: String = label.to_lower().replace(" · ", "_").replace(" ", "_")
	get_root().get_texture().get_image().save_png("res://tools/out/bench_%s.png" % file)


static func _qname(q: int) -> String:
	return ["baja", "media", "alta"][q]


func _log(s: String) -> void:
	_lines.append(s)
	print(s)


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _pump(tablets: Array, n: int) -> void:
	for i: int in n:
		_tick(tablets, false)
		await process_frame


func _tick(tablets: Array, send: bool) -> void:
	_frame_n += 1
	for t: Variant in tablets:
		t.pump()
		if send or _frame_n % 20 == 0:
			t.send_input()


func _pump_until(tablets: Array, cond: Callable, max_frames: int = 600) -> void:
	for i: int in max_frames:
		_tick(tablets, false)
		if cond.call():
			return
		await process_frame
