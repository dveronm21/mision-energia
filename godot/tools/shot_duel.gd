extends SceneTree
## Prueba de punta a punta del Duelo entre dos teles, con red de verdad en 127.0.0.1: la app en modo
## TV contra un "tele rival" simulado (DuelLink + DuelMatch en este mismo proceso). La app queda de
## árbitro: elige el nivel con el foco (como el control remoto), larga, ve el avance del rival y
## el resultado. Guarda capturas en res://tools/out/duel_*.png.
##   godot --path godot --rendering-driver opengl3 -s res://tools/shot_duel.gd -- --tv --tv-bind=127.0.0.1 --tv-port=18765 --duel-bind=127.0.0.1 --duel-port=18767 --duel-beacon=18768 --duel-targets=18769

var _app: App
var _rival: DuelMatch
var _fails: int = 0
var _tablet: Tablet


## Tablet mínima por WebSocket: saluda y guarda el último contexto que le manda el tele.
class Tablet:
	var ws: WebSocketPeer = WebSocketPeer.new()
	var ctx: Dictionary = {}
	var said_hello: bool = false
	var seq: int = 0

	func pump() -> void:
		ws.poll()
		if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
			return
		if not said_hello:
			said_hello = true
			ws.send_text(JSON.stringify({"t": "hello", "v": RemoteProtocol.PROTOCOL_VERSION, "name": "Ana", "device": "browser"}))
		# Como una tablet real: un input por cuadro hace de "sigo acá" (si no, el tele la da por caída).
		seq += 1
		ws.send_text(JSON.stringify({"t": "input", "s": {"seq": seq, "x": 0, "y": 0, "held": 0,
			"taps": {"action": 0, "inspect": 0, "tool": 0, "pause": 0}}}))
		while ws.get_available_packet_count() > 0:
			var msg: Variant = JSON.parse_string(ws.get_packet().get_string_from_utf8())
			if msg is Dictionary and msg.get("t", "") == "ctx":
				ctx = msg.get("c", {})

	func objective() -> String:
		return String(ctx.get("objective", ""))


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var root: Window = get_root()
	root.size = Vector2i(1280, 720)
	var services: AppServices = root.get_node("Services")
	services._build(SaveStore.in_memory())
	DirAccess.make_dir_recursive_absolute("res://tools/out")
	_app = (load("res://scenes/Main.tscn") as PackedScene).instantiate() as App
	root.add_child(_app)
	await _frames(5)
	check(_app.tv != null, "arrancó en modo TV")
	_app.show_menu()
	_tablet = Tablet.new()
	_tablet.ws.connect_to_url("ws://127.0.0.1:%d/ws" % _app.tv.server.get_http_port())
	await _until(func() -> bool: return _app.tv.players().size() == 1)
	check(_app.tv.players().size() == 1, "Ana conectó su tablet al tele")
	await _shot("duel_00_menu")

	# Rival con el id más chico: llama él, la app arbitra.
	var link: DuelLink = DuelLink.new("Beto", "0000000000000000")
	link.bind_address = "127.0.0.1"
	link.beacon_address = "127.0.0.1"
	link.port = 18777
	link.beacon_port = 18769
	link.beacon_targets = [18768] as Array[int]
	check(link.start() == OK, "el tele rival escucha")
	_rival = DuelMatch.new(link)

	_app.start_duel()
	check(_app.duel != null and _app.ui.screens.top() is DuelScreen, "Duelo abre la sala")
	await _frames(3)
	await _shot("duel_01_buscando", 5)
	await _until(func() -> bool: return _app.duel.phase == DuelMatch.Phase.LOBBY and _rival.phase == DuelMatch.Phase.LOBBY)
	check(_app.duel.is_referee(), "la app arbitra")
	check(_app.duel.peer_name() == "Beto", "conoce al rival")
	check(_rival.peer_name() == "Ana", "el rival ve el nombre de la tablet")
	await _until(func() -> bool: return _tablet.objective().contains("elegí el nivel"))
	check(_tablet.objective().contains("Beto"), "la tablet sabe contra quién es el duelo")
	await _shot("duel_02_elegir", 10)

	# El primer nivel tiene el foco: "aceptar" (el OK del remoto) lo elige.
	TvMode._press(&"ui_accept")
	await _until(func() -> bool: return _rival.phase == DuelMatch.Phase.SETUP)
	check(_rival.level_id == "casa", "el rival recibe el nivel elegido")
	await _shot("duel_03_listo", 10)
	TvMode._press(&"ui_accept") # ¡Listo!
	await _frames(5)
	check(_app.duel.my_ready, "¡Listo! con el remoto")
	_rival.set_ready()
	await _until(func() -> bool: return _app.duel.phase == DuelMatch.Phase.COUNTDOWN)
	await _shot("duel_04_cuenta", 8)
	await _until(func() -> bool: return _app.session != null and _rival.phase == DuelMatch.Phase.PLAYING, 2000)
	check(_app.session != null, "arranca la partida")
	check(_app.session.speed == 1, "velocidad ×1")
	_app.pause()
	check(not _app.session.paused, "en el duelo no se pausa")

	_rival.report_progress({"panels": 3, "total": 4, "batteries": 0, "batteries_total": 1, "protection": true, "cables": 1, "activated": false, "ok": false})
	await _until(func() -> bool: return not _app.duel.peer_progress.is_empty())
	check(int(_app.duel.peer_progress.get("panels", 0)) == 3, "la app ve el avance del rival")
	await _until(func() -> bool: return not _rival.peer_progress.is_empty())
	check(int(_rival.peer_progress.get("total", 0)) == 4, "el rival ve el avance de la app")
	await _shot("duel_05_partida", 30)

	_rival.report_done()
	await _until(func() -> bool: return _app.ui.screens.top() is DuelResultScreen and _rival.phase == DuelMatch.Phase.FINISHED)
	check(_app.duel.winner == DuelMatch.WIN_PEER, "la app sabe que ganó el rival")
	check(_rival.winner == DuelMatch.WIN_ME, "el rival sabe que ganó")
	check(_app.session == null, "la partida se cerró")
	await _until(func() -> bool: return _tablet.objective().begins_with("Ganó"))
	check(_tablet.objective().begins_with("Ganó Beto"), "la tablet muestra el resultado del duelo")
	await _shot("duel_06_resultado", 20)

	# "Otra ronda" (foco) → los dos vuelven a la sala.
	TvMode._press(&"ui_accept")
	await _until(func() -> bool: return _rival.phase == DuelMatch.Phase.LOBBY and _app.ui.screens.top() is DuelScreen)
	check(_app.duel.phase == DuelMatch.Phase.LOBBY, "otra ronda: la app en la sala")
	check(_rival.phase == DuelMatch.Phase.LOBBY, "otra ronda: el rival en la sala")

	_app.leave_duel()
	await _until(func() -> bool: return _rival.phase == DuelMatch.Phase.SEARCHING)
	check(_app.duel == null and _app.ui.screens.top() is MainMenu, "salir del duelo vuelve al menú")
	check(_rival.phase == DuelMatch.Phase.SEARCHING, "el rival se entera y vuelve a buscar")
	link.stop()

	print("listo: %d fallas" % _fails)
	quit(1 if _fails > 0 else 0)


func _frames(n: int) -> void:
	for i: int in n:
		_rival_tick()
		await process_frame


func _rival_tick() -> void:
	if _rival != null:
		_rival.update(1.0 / 60.0)
	if _tablet != null:
		_tablet.pump()


func _until(cond: Callable, max_frames: int = 300) -> void:
	for i: int in max_frames:
		if cond.call():
			return
		_rival_tick()
		await process_frame
		OS.delay_msec(5)


func _shot(shot_name: String, frames: int = 30) -> void:
	await _frames(frames)
	await RenderingServer.frame_post_draw
	var path: String = "res://tools/out/%s.png" % shot_name
	get_root().get_texture().get_image().save_png(path)
	print("guardado ", path)


func check(ok: bool, what: String) -> void:
	if ok:
		print("ok    ", what)
	else:
		_fails += 1
		print("FALLA ", what)
