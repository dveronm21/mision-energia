extends SceneTree
## Recorre el flujo completo de la app (Main.tscn) con render real y guarda una captura por paso
## en res://tools/out/app_*.png. No toca el guardado del jugador (usa un SaveStore en memoria):
##   godot --path godot --rendering-driver opengl3 -s res://tools/shot_app.gd
## Con `-- --size=2400x1080 --ui=1.7 --prefix=tel` simula un teléfono y guarda `tel_*.png`.

var _app: App
var _prefix: String = "app"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var root: Window = get_root()
	var win: Vector2i = Vector2i(1280, 720)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--size="):
			var wh: PackedStringArray = a.trim_prefix("--size=").split("x")
			win = Vector2i(int(wh[0]), int(wh[1]))
		elif a.begins_with("--prefix="):
			_prefix = a.trim_prefix("--prefix=")
		elif a.begins_with("--ui="):
			# Factor de `UiScale` (el teléfono real lo mide solo: ~1,7 en uno de 6").
			UiScale.forced_factor = float(a.trim_prefix("--ui="))
	root.size = win
	var services: AppServices = root.get_node("Services")
	services._build(SaveStore.in_memory())
	DirAccess.make_dir_recursive_absolute("res://tools/out")

	_app = (load("res://scenes/Main.tscn") as PackedScene).instantiate() as App
	root.add_child(_app)
	await _shot("01_splash", 40)

	if OS.get_cmdline_user_args().has("--settings-only"):
		# Ajustes armados con la pantalla en vertical y después girada (como al abrir en Android).
		_app.push_settings()
		root.size = Vector2i(win.y, win.x)
		await _shot("11a_ajustes_vertical", 20)
		root.size = win
		await _shot("11b_ajustes_girada", 20)
		_app.push_shop()
		await _shot("09_tienda", 20)
		_app.push_wardrobe()
		await _shot("10_vestuario", 20)
		quit()
		return

	_app.show_menu()
	await _shot("02_menu", 60)

	_app.show_map()
	await _shot("03_mapa", 40)

	_app.push_workshop("casa")
	await _shot("04_taller", 40)

	_app.start_level(LevelRun.make("casa", Purchase.make(4, 1, false), [] as Array[StringName]))
	await _shot("05_partida", 200)

	_app.pause()
	await _shot("06_pausa")
	_app.handle_back()
	check(not _app.session.paused, "atrás en pausa reanuda")

	var s: GameSession = _app.session
	for i: int in 4:
		s.take_from_pallet()
		s.install_panel(s.world().mounts[i])
	s.take_pickup(_find_pickup(s, &"protection"))
	s.install_protection()
	s.take_pickup(_find_pickup(s, &"battery"))
	s.install_battery(0)
	s.take_cable(CableNetwork.COLOR_ORANGE, &"junction", s.world().junction.terminal)
	s.connect_cable(&"protection")
	s.take_cable(CableNetwork.COLOR_BLUE, &"battery", s.world().batteries[0].terminal)
	s.connect_cable(&"inverter")
	s.take_cable(CableNetwork.COLOR_VIOLET, &"switchboard", s.world().switchboard.terminal)
	s.connect_cable(&"inverter")
	s.try_activate()
	check(s.phase() == SessionPort.PHASE_RUNNING, "la planta arrancó")
	await _shot("07_planta_activa", 30)
	# Toma limpia (sin HUD ni avisos) para el gráfico destacado de Play Store.
	_app.ui.set_hud_visible(false)
	(_app.ui.toast as Toast).hide()
	await _shot("07z_limpia", 20)
	_app.ui.set_hud_visible(true)

	# Paneles del HUD abiertos a mano (alerta, multímetro, ficha) para revisar su estilo.
	var hud: Hud = _app.hud
	hud.alert.show("¡Alerta de viento Zonda!", "Defendé los paneles: tocá los postes de cada fila.", 4.0)
	hud.meter.show()
	hud.meter.set_reading("F1 OK  F2 OK", "por fila", "Todas las filas generan bien.", &"ok")
	await _shot("07b_paneles_hud", 30)
	hud.meter.hide()
	hud.inspect.show({"title": "Inversor híbrido", "body": "Convierte la corriente continua de los paneles y baterías en alterna para la casa.", "live": "Entregando energía a la casa."})
	await _shot("07c_ficha", 30)
	hud.inspect.hide()
	hud.alert.hide()

	s.time_scale = 40.0
	var frames: int = 0
	while not (_app.ui.screens.top() is ResultScreen) and frames < 3000:
		await process_frame
		frames += 1
	check(_app.ui.screens.top() is ResultScreen, "aparece la pantalla de resultado")
	await _shot("08_resultado", 60)
	await _shot("08b_confeti", 160)

	_app.show_map()
	_app.push_shop()
	await _shot("09_tienda", 30)
	_app.ui.screens.push(ParentalGateModal.new(services.gate))
	await _shot("09b_control_parental", 30)
	_app.show_menu()
	_app.push_wardrobe()
	await _shot("10_vestuario", 30)
	_app.show_menu()
	_app.push_settings()
	await _shot("11_ajustes")

	check(not _app.handle_back() or _app.ui.screens.size() == 1, "atrás vuelve al menú")
	print("listo")
	quit()


func _shot(shot_name: String, frames: int = 12) -> void:
	for i: int in frames:
		await process_frame
	var path: String = "res://tools/out/%s_%s.png" % [_prefix, shot_name]
	get_root().get_texture().get_image().save_png(path)
	print("guardado ", path, " | pantalla: ", _top_name())


func _top_name() -> String:
	var t: UiScreen = _app.ui.screens.top()
	return "(ninguna)" if t == null else t.root.name


func check(ok: bool, what: String) -> void:
	print(("ok    " if ok else "FALLA ") + what)


static func _find_pickup(s: GameSession, kind: StringName) -> Pickup:
	for p: Pickup in s.world().pickups:
		if p.kind == kind:
			return p
	return null
