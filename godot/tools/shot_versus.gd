extends SceneTree
## Prueba de punta a punta del versus en pantalla dividida, con red de verdad: dos "tablets"
## (las de `shot_tv.gd`) entran, abren Versus desde la tablet, eligen el nivel, corre la cuenta
## regresiva, cada una mueve solo a su técnico (cada uno en su mitad), Ana arma su planta y gana.
## Prueba también la pausa y la revancha. Capturas en res://tools/out/versus_*.png.
##   godot --path godot --rendering-driver opengl3 -s res://tools/shot_versus.gd -- --tv --tv-bind=127.0.0.1 --tv-port=18775

const ShotTv = preload("res://tools/shot_tv.gd")
const TestSession = preload("res://tests/unit/test_game_session.gd")

var _app: App
var _fails: int = 0
var _frame_n: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var root: Window = get_root()
	root.size = Vector2i(1920, 1080)
	var services: AppServices = root.get_node("Services")
	services._build(SaveStore.in_memory())
	DirAccess.make_dir_recursive_absolute("res://tools/out")
	_app = (load("res://scenes/Main.tscn") as PackedScene).instantiate() as App
	root.add_child(_app)
	# Las esperas de esta prueba cuentan cuadros: a 60 FPS fijos da igual si la pantalla es de 60 o 144 Hz.
	Engine.max_fps = 60
	await _frames(5)
	check(_app.tv != null, "arrancó en modo TV")
	_app.show_lobby()
	await _frames(10)

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
	_app.show_menu()
	await _pump_until(both, func() -> bool: return ana.menu_labels().has("Versus"))
	check(ana.menu_labels().has("Versus") and ana.menu_labels().has("Duelo en red"), "el menú tiene Versus y Duelo en red")
	await _shot("versus_00_menu")

	check(ana.pick("Versus"), "Ana toca Versus en la tablet")
	await _pump_until(both, func() -> bool: return _app.ui.screens.top() is SplitSetupScreen)
	check(_app.ui.screens.top() is SplitSetupScreen, "se abre la elección de nivel")
	await _pump_until(both, func() -> bool: return ana.menu_labels().has("1 · Casa familiar"))
	await _shot("versus_01_nivel")
	var t_build: int = Time.get_ticks_msec()
	check(ana.pick("1 · Casa familiar"), "Ana elige Casa")
	await _pump_until(both, func() -> bool: return _app.versus != null)
	print("armar las dos partidas: %d ms" % (Time.get_ticks_msec() - t_build))
	var v: SplitVersus = _app.versus
	check(v != null and v.sides().size() == 2, "arrancan dos partidas")
	if v == null:
		quit(1)
		return
	check(v.sides()[0].slot == 0 and v.sides()[1].slot == 1, "Ana a la izquierda, Beto a la derecha")
	await _pump(both, 40)
	check(v.phase == SplitVersus.Phase.COUNTDOWN, "cuenta regresiva")
	await _shot("versus_02_cuenta", 1)
	await _pump_until(both, func() -> bool: return v.phase == SplitVersus.Phase.PLAYING, 400)
	check(v.phase == SplitVersus.Phase.PLAYING, "¡Ya!")

	var sa: GameSession = v.sides()[0].session
	var sb: GameSession = v.sides()[1].session
	var a0: Vector3 = sa.technicians()[0].player.position
	var b0: Vector3 = sb.technicians()[0].player.position
	ana.stick = Vector2(1, 0)
	for i: int in 120:
		ana.send_input()
		beto.send_input()
		await _pump(both, 1)
	ana.stick = Vector2.ZERO
	ana.send_input()
	await _pump(both, 10)
	check(sa.technicians()[0].player.position.distance_to(a0) > 0.5, "Ana mueve a su técnico")
	check(sb.technicians()[0].player.position.distance_to(b0) < 0.05, "el de Beto no se mueve con la tablet de Ana")
	check(String(ana.ctx.get("screen", "")) == "playing" and ana.ctx.has("action"), "la tablet recibe el contexto de juego")
	check(sa.technicians().size() == 1 and sb.technicians().size() == 1, "un técnico por mitad")
	await _shot("versus_03_partida", 20)

	# Pausa desde la tablet: se frena todo; Seguir lo reanuda.
	beto.tap("pause")
	await _pump_until(both, func() -> bool: return _app.ui.screens.top() is SplitPauseScreen)
	check(_app.ui.screens.top() is SplitPauseScreen and v.paused and sa.paused, "pausa desde la tablet de Beto")
	var t_paused: float = v.elapsed
	await _pump(both, 20)
	check(is_equal_approx(v.elapsed, t_paused), "el reloj de la carrera se frena en pausa")
	await _shot("versus_04_pausa")
	await _pump_until(both, func() -> bool: return beto.menu_labels().has("Seguir"))
	beto.pick("Seguir")
	await _pump_until(both, func() -> bool: return not (_app.ui.screens.top() is SplitPauseScreen))
	check(not v.paused and not sa.paused, "Seguir reanuda las dos partidas")

	# Beto avanza un poco (un panel); Ana arma la planta entera y gana.
	sb.take_from_pallet()
	sb.install_panel(sb.world().mounts[0])
	TestSession._build_casa(sa)
	for m: Mount in sa.world().mounts:
		if m.faulty:
			sa.repair_panel(m)
	await _pump_until(both, func() -> bool: return v.phase == SplitVersus.Phase.FINISHED, 200)
	check(v.phase == SplitVersus.Phase.FINISHED and v.winner == 0, "Ana gana la carrera")
	await _pump(both, 30)
	await _shot("versus_05_festejo", 1)
	await _pump_until(both, func() -> bool: return _app.ui.screens.top() is SplitResultScreen, 300)
	check(_app.ui.screens.top() is SplitResultScreen, "aparece el resultado")
	await _shot("versus_06_resultado")

	# Revancha: dos partidas nuevas del mismo nivel.
	await _pump_until(both, func() -> bool: return ana.menu_labels().has("Revancha"))
	ana.pick("Revancha")
	await _pump_until(both, func() -> bool: return _app.versus != null and _app.versus != v)
	check(_app.versus != null and _app.versus != v and _app.versus.level.id == "casa", "revancha en Casa")
	_app.leave_versus()
	await _pump(both, 10)
	check(_app.versus == null and _app.ui.screens.top() is MainMenu and _app.hud.root.visible, "salir vuelve al menú con el HUD normal")

	print("listo: %d fallas" % _fails)
	quit(1 if _fails > 0 else 0)


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _pump(tablets: Array, n: int) -> void:
	for i: int in n:
		_tick(tablets)
		await process_frame


## Como una tablet de verdad: manda su estado seguido (si no, el tele la da por desconectada).
func _tick(tablets: Array) -> void:
	_frame_n += 1
	for t: Variant in tablets:
		t.pump()
		if _frame_n % 20 == 0:
			t.send_input()


func _pump_until(tablets: Array, cond: Callable, max_frames: int = 600) -> void:
	for i: int in max_frames:
		_tick(tablets)
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
