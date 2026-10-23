extends SceneTree
## Prueba de punta a punta del modo TV cooperativo, con red de verdad: levanta la app en modo
## TV (servidor en 127.0.0.1) y conecta dos "tablets" (WebSocketPeer) que hablan el protocolo
## real (hello, input con contadores de toques). Verifica la sala, la navegación de menús desde
## la tablet, los 2 técnicos, que cada uno se mueva con su tablet, el contexto que recibe cada
## control y la pausa desde la tablet. Guarda capturas en res://tools/out/tv_*.png.
##   godot --path godot --rendering-driver opengl3 -s res://tools/shot_tv.gd -- --tv --tv-bind=127.0.0.1 --tv-port=18765

var _app: App
var _fails: int = 0


class FakeTablet:
	var ws: WebSocketPeer = WebSocketPeer.new()
	var name: String
	var seq: int = 0
	var taps: Dictionary = {"action": 0, "inspect": 0, "tool": 0, "pause": 0}
	var stick: Vector2 = Vector2.ZERO
	var welcome: Dictionary = {}
	var ctx: Dictionary = {}
	var toasts: int = 0
	var haptics: int = 0

	func _init(p_name: String) -> void:
		name = p_name

	func open(url: String) -> void:
		ws.connect_to_url(url)

	func pump() -> void:
		ws.poll()
		if ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
			return
		while ws.get_available_packet_count() > 0:
			var msg: Variant = JSON.parse_string(ws.get_packet().get_string_from_utf8())
			if not (msg is Dictionary):
				continue
			match String(msg.get("t", "")):
				"welcome":
					welcome = msg
				"ctx":
					ctx = msg.get("c", {})
				"toast":
					toasts += 1
				"haptic":
					haptics += 1

	func send(d: Dictionary) -> void:
		if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			ws.send_text(JSON.stringify(d))

	func hello() -> void:
		send({"t": "hello", "v": RemoteProtocol.PROTOCOL_VERSION, "name": name, "device": "browser"})

	func tap(button: String) -> void:
		taps[button] += 1
		send_input()

	func send_input() -> void:
		seq += 1
		send({"t": "input", "s": {"seq": seq, "x": stick.x, "y": stick.y, "held": 0, "taps": taps}})


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
	_app.show_lobby()
	await _frames(10)

	var port: int = _app.tv.server.get_http_port()
	var url: String = "ws://127.0.0.1:%d/ws" % port
	var ana: FakeTablet = FakeTablet.new("Ana")
	var beto: FakeTablet = FakeTablet.new("Beto")
	for t: FakeTablet in [ana, beto]:
		t.open(url)
	await _pump_until([ana, beto], func() -> bool: return ana.ws.get_ready_state() == WebSocketPeer.STATE_OPEN and beto.ws.get_ready_state() == WebSocketPeer.STATE_OPEN)
	ana.hello()
	await _pump_until([ana, beto], func() -> bool: return not ana.welcome.is_empty())
	beto.hello()
	await _pump_until([ana, beto], func() -> bool: return not beto.welcome.is_empty())
	check(int(ana.welcome.get("slot", -1)) == 0 and int(beto.welcome.get("slot", -1)) == 1, "Ana y Beto tienen asiento 0 y 1")
	await _pump([ana, beto], 20)
	await _shot("tv_01_sala")
	check(String(ana.ctx.get("screen", "")) == "lobby", "la tablet sabe que está en la sala")

	# "Empezar" tiene el foco: la acción de la tablet lo aprieta (navegación desde la tablet).
	ana.tap("action")
	await _pump_until([ana, beto], func() -> bool: return _app.ui.screens.top() is MainMenu)
	check(_app.ui.screens.top() is MainMenu, "la acción de la tablet tocó Empezar → menú")
	await _shot("tv_02_menu")

	_app.start_level(LevelRun.make("casa", Purchase.make(4, 1, false), [] as Array[StringName]))
	await _pump([ana, beto], 30)
	var s: GameSession = _app.session
	check(s.technicians().size() == 2, "hay 2 técnicos en la planta")
	var a0: Vector3 = s.technician_for_slot(0).player.position
	var b0: Vector3 = s.technician_for_slot(1).player.position
	ana.stick = Vector2(1, 0)
	beto.stick = Vector2(-1, 0)
	for i: int in 40:
		ana.send_input()
		beto.send_input()
		await _pump([ana, beto], 1)
	ana.stick = Vector2.ZERO
	beto.stick = Vector2.ZERO
	ana.send_input()
	beto.send_input()
	await _pump([ana, beto], 10)
	var a1: Vector3 = s.technician_for_slot(0).player.position
	var b1: Vector3 = s.technician_for_slot(1).player.position
	check(a1.distance_to(a0) > 0.5 and b1.distance_to(b0) > 0.5, "cada técnico se movió con su tablet")
	check(a1.distance_to(b1) > a0.distance_to(b0), "se movieron en direcciones distintas")
	check(String(ana.ctx.get("screen", "")) == "playing" and ana.ctx.has("action"), "la tablet recibe el contexto de juego")
	await _shot("tv_03_partida", 20)

	# Multímetro con las manos libres (Beto) → se enciende en su contexto.
	beto.tap("tool")
	await _pump([ana, beto], 15)
	check(bool(beto.ctx.get("toolOn", false)), "Beto sacó el multímetro (toolOn en su tablet)")
	check(not bool(ana.ctx.get("toolOn", true)), "Ana no")

	# Pausa desde la tablet.
	ana.tap("pause")
	await _pump_until([ana, beto], func() -> bool: return _app.ui.screens.top() is PauseMenu)
	check(_app.ui.screens.top() is PauseMenu, "pausa desde la tablet")
	await _pump([ana, beto], 15)
	check(String(ana.ctx.get("screen", "")) == "paused", "las tablets saben que está en pausa")
	await _shot("tv_04_pausa")
	ana.tap("pause")
	await _pump_until([ana, beto], func() -> bool: return not (_app.ui.screens.top() is PauseMenu))
	check(not s.paused, "'pausa' de nuevo en la tablet → sigue el juego")

	print("listo: %d fallas" % _fails)
	quit(1 if _fails > 0 else 0)


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _pump(tablets: Array, n: int) -> void:
	for i: int in n:
		for t: FakeTablet in tablets:
			t.pump()
		await process_frame


func _pump_until(tablets: Array, cond: Callable, max_frames: int = 600) -> void:
	for i: int in max_frames:
		for t: FakeTablet in tablets:
			t.pump()
		if cond.call():
			return
		await process_frame


func _shot(shot_name: String, frames: int = 30) -> void:
	await _frames(frames)
	var path: String = "res://tools/out/%s.png" % shot_name
	get_root().get_texture().get_image().save_png(path)
	print("guardado ", path)


func check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
	print(("ok    " if ok else "FALLA ") + what)
