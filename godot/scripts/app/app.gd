class_name App
extends Node
## Raíz de composición (equivale a `App.ts`). Usa los servicios del autoload `Services`, arma
## la UI y el HUD, y navega entre pantallas:
## Splash → Menú (regalo de bienvenida y bono diario) → Mapa → Taller → Partida → Resultado.
## Tienda (con control parental), Vestuario (cosméticos del técnico) y Ajustes (calidad, sonido,
## velocidad del juego y tamaño de la interfaz).
##
## Es el script de `scenes/Main.tscn`. El mundo 3D de la partida va en `world_host`; la UI,
## en una `CanvasLayer` encima.
##
## Modo TV (`TvMode.wanted()`): Splash → Sala (QR) → Menú…; cada tablet maneja un técnico,
## los menús se recorren con el D-pad del control remoto o con el stick de la tablet, y el
## tele no muestra joystick ni botonera.

const QUALITY_KEY: String = "settings.quality"
const BOOSTER_IDS: Array[String] = [Boosters.HINT, Boosters.DRONE, Boosters.BATTERY, Boosters.BUDGET]
const QUALITY_INDEX: Dictionary[StringName, int] = {&"low": 0, &"medium": 1, &"high": 2}
const BG_COLOR: Color = Color("#0e2420")

var world_host: Node3D
var ui: UiRoot
var hud: Hud
var session: GameSession = null

## El autoload `Services`, resuelto por su nodo (el identificador global no existe cuando se
## corre con `-s`, p. ej. en `tools/shot_app.gd`).
var _services: AppServices
var _ui_layer: CanvasLayer
var _keyboard: KeyboardInput = KeyboardInput.new()
var _run: LevelRun = null
## Sorteo del clima de cada partida (Zonda al azar en los niveles que lo permiten).
var _weather_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _quality: StringName = &"medium"
var _speed: int = 1
var _fps: StringName = FrameRate.AUTO
var _ui_size: StringName = UiScale.NORMAL
var _welcome_checked: bool = false
## Después de "Reiniciar progreso" el menú de abajo tiene los servicios viejos: al salir de
## Ajustes se arma de nuevo.
var _menu_stale: bool = false
var _pause_menu: PauseMenu = null
## null fuera del modo TV.
var tv: TvMode = null
## Duelo contra otra pantalla (solo modo TV). null = no hay duelo.
var duel: DuelMatch = null
var _duel_screen: DuelScreen = null
var _duel_banner: DuelBanner = null
var _duel_sent: Dictionary = {}
## Versus en pantalla dividida (solo modo TV). null = no hay versus.
var versus: SplitVersus = null
var _versus_level: String = ""
var _versus_pause: SplitPauseScreen = null
## Botones de la pantalla del tele replicados en las tablets.
var _mirror: MenuMirror = MenuMirror.new()


func _ready() -> void:
	_services = get_node("/root/Services") as AppServices
	RenderingServer.set_default_clear_color(BG_COLOR)
	get_tree().quit_on_go_back = false

	world_host = Node3D.new()
	world_host.name = "world"
	add_child(world_host)

	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "ui"
	add_child(_ui_layer)
	ui = UiRoot.new(_audio())
	_ui_layer.add_child(ui.root)

	var cb: HudCallbacks = HudCallbacks.new()
	cb.on_action = _on_action
	cb.on_inspect = _on_inspect
	cb.on_meter = _on_meter
	cb.on_pause = pause
	cb.on_use_booster = _on_use_booster
	cb.on_toggle_load = _on_toggle_load
	cb.on_inspect_close = _on_inspect_close
	hud = Hud.new(cb)
	ui.hud_layer.add_child(hud.root)
	(hud.alert as AlertBanner).on_resize = _on_alert_resize

	if TvMode.wanted():
		TvMode.apply_desktop_window()
		tv = TvMode.new()
		add_child(tv)
		tv.start()
		hud.set_tv_mode(true)
		_keyboard.enter_is_action = true
		tv.host.joined.connect(_on_tv_join)
		tv.host.resumed.connect(_on_tv_join)

	_keyboard.on_action = cb.on_action
	_keyboard.on_inspect = cb.on_inspect
	_keyboard.on_meter = cb.on_meter

	_services.bus.sfx.connect(_on_sfx)

	_quality = StringName(_services.store.load_value(QUALITY_KEY, "medium"))
	if not QUALITY_INDEX.has(_quality):
		_quality = &"medium"
	_speed = GameSpeed.load_from(_services.store)
	_fps = FrameRate.load_from(_services.store)
	FrameRate.apply(_fps)
	_ui_size = UiScale.load_size(_services.store)
	_apply_ui_scale()
	get_window().size_changed.connect(_apply_ui_scale)

	show_splash()


func _process(delta: float) -> void:
	var dt: float = minf(0.1, maxf(0.0, delta))
	if tv != null:
		tv.poll()
	if duel != null:
		_update_duel(dt)
	var ss: GameSession = session
	var menu_open: bool = ui.screens.top() != null
	if tv != null and ((ss == null and versus == null) or menu_open):
		tv.navigate_menus(dt)
		_push_menu_context()
		for slot: int in RemoteHost.SLOTS:
			for p: Dictionary in tv.host.take_picks(slot):
				_mirror.pick(int(p["v"]), int(p["i"]))
		if ui.screens.top() is SplitSetupScreen:
			(ui.screens.top() as SplitSetupScreen).set_players_text(SplitSetupScreen.players_text(_versus_players()))
	if versus != null:
		_update_versus(dt, menu_open)
		return
	if ss == null:
		return
	var local: Vector2 = (hud.joystick.vector() + _keyboard.vector()).clamp(-Vector2.ONE, Vector2.ONE)
	if tv == null:
		ss.update(dt, local)
		return
	# Modo TV: cada técnico se mueve con su tablet (el que no tiene tablet, con el control remoto).
	var moves: Array[Vector2] = []
	for t: Technician in ss.technicians():
		if t.slot < 0:
			moves.append(local)
		else:
			var it: PlayerIntent = tv.intent(t.slot)
			moves.append(Vector2(it.x, it.y))
	ss.update_multi(dt, moves)
	if menu_open or session != ss:
		return
	for t: Technician in ss.technicians():
		if t.slot < 0:
			continue
		var it: PlayerIntent = tv.intent(t.slot)
		if it.pause:
			pause()
			return
		if it.action or it.inspect or it.tool:
			ss.apply_intent(t, it)
		tv.host.set_context(t.slot, ss.controller_context(t))


func _unhandled_input(event: InputEvent) -> void:
	if _keyboard.handle(event):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_cancel"):
		# Escape, el "atrás" del control remoto o "pausa" de la tablet en un menú.
		get_viewport().set_input_as_handled()
		handle_back()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Botón atrás de Android: si no había nada que cerrar, la app sale.
			if not handle_back():
				get_tree().quit()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			pause()


# ================================================================== navegación


func _s() -> AppServices:
	return _services


func _audio() -> AudioSynth:
	return _services.audio


func _version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


func show_splash() -> void:
	ui.screens.reset(SplashScreen.new(show_lobby if tv != null else show_menu, _audio(), _version()))


## Modo TV: sala de espera con el QR. "Empezar" va al menú; "Atrás" cierra la app.
func show_lobby() -> void:
	_end_session()
	ui.screens.reset(LobbyScreen.new(tv.host, show_menu, func() -> void: get_tree().quit()))


func show_menu() -> void:
	_end_versus()
	_end_session()
	_menu_stale = false
	var s: AppServices = _s()
	var d: MainMenuDeps = MainMenuDeps.new()
	d.wallet = s.wallet
	d.rewards = s.rewards
	d.bus = s.bus
	d.on_play = _push_map
	d.on_shop = push_shop
	d.on_wardrobe = push_wardrobe
	d.on_settings = push_settings
	if tv != null:
		d.on_duel = start_duel
		d.on_versus = show_versus_setup
	ui.screens.reset(MainMenu.new(d))
	if not _welcome_checked:
		_welcome_checked = true
		if s.rewards.can_claim_welcome():
			var got: int = s.rewards.claim_welcome()
			if got > 0:
				get_tree().create_timer(0.35).timeout.connect(
					func() -> void: ui.show_toast("¡Regalo de bienvenida! Sumaste %d Soles." % got, UiRootPort.KIND_GOOD, 3600))
			_audio().play("coin")


## Menú → Mapa (con "atrás" al menú).
func _push_map() -> void:
	var s: AppServices = _s()
	var d: LevelMapDeps = LevelMapDeps.new()
	d.levels = s.levels.all()
	d.manager = s.progress
	d.wallet = s.wallet
	d.bus = s.bus
	d.on_play = func(id: String) -> void: push_workshop(id)
	d.on_back = _pop
	d.on_shop = push_shop
	ui.screens.push(LevelMapScreen.new(d))


## Pila Menú → Mapa (al volver de una partida).
func show_map() -> void:
	show_menu()
	_push_map()


func push_workshop(id: String, initial: Purchase = null) -> void:
	var s: AppServices = _s()
	var level: LevelDefinition = s.levels.get_level(id).roll_weather(_weather_rng)
	var d: WorkshopDeps = WorkshopDeps.new()
	d.level = level
	d.boosters_catalog = s.catalog.by_kind(Product.KIND_BOOSTER)
	d.inventory = s.inventory
	d.boosters = s.boosters
	d.wallet = s.wallet
	d.bus = s.bus
	d.initial = initial
	d.on_build = func(purchase: Purchase, ids: Array[String]) -> void:
		var used: Array[StringName] = []
		for b: String in ids:
			if BOOSTER_IDS.has(b) and _s().boosters.use(b):
				used.append(StringName(b))
		start_level(LevelRun.make(id, purchase, used, level))
	d.on_back = _pop
	d.on_shop = func() -> void: push_shop(ShopDeps.TAB_MEJORAS)
	ui.screens.push(WorkshopScreen.new(d))


func push_shop(tab: StringName = ShopDeps.TAB_SOLES) -> void:
	var s: AppServices = _s()
	var d: ShopDeps = ShopDeps.new()
	d.shop = s.shop
	d.wallet = s.wallet
	d.inventory = s.inventory
	d.bus = s.bus
	d.screens = ui.screens
	d.gate = s.gate
	d.on_back = _pop
	d.initial_tab = tab
	ui.screens.push(ShopScreen.new(d))


func push_wardrobe() -> void:
	var s: AppServices = _s()
	var d: WardrobeDeps = WardrobeDeps.new()
	d.catalog = s.catalog
	d.inventory = s.inventory
	d.wallet = s.wallet
	d.bus = s.bus
	d.on_back = _pop
	d.on_shop = func() -> void: push_shop(ShopDeps.TAB_VESTUARIO)
	ui.screens.push(WardrobeScreen.new(d))


func push_settings() -> void:
	var d: SettingsDeps = SettingsDeps.new()
	d.quality = _quality
	d.audio = _audio()
	d.version = _version()
	d.on_quality_change = _set_quality
	d.speed = _speed
	d.on_speed_change = _set_speed
	d.fps = _fps
	d.on_fps_change = _set_fps
	d.ui_size = _ui_size
	d.on_ui_size_change = _set_ui_size
	d.on_reset_progress = _reset_progress
	d.on_back = func() -> void:
		if _menu_stale:
			show_menu()
		else:
			_pop()
	ui.screens.push(SettingsScreen.new(d))


func _pop() -> void:
	ui.screens.pop()


func _set_quality(q: StringName) -> void:
	if not QUALITY_INDEX.has(q):
		return
	_quality = q
	_s().store.save_value(QUALITY_KEY, String(q))
	if session != null:
		session.set_quality(QUALITY_INDEX[q])


func _set_speed(v: int) -> void:
	_speed = v
	GameSpeed.save_to(_s().store, v)
	if session != null:
		session.speed = v


func _set_fps(v: StringName) -> void:
	_fps = v
	FrameRate.save_to(_s().store, v)
	FrameRate.apply(v)


func _set_ui_size(v: StringName) -> void:
	_ui_size = v
	UiScale.save_size(_s().store, v)
	_apply_ui_scale()


func _apply_ui_scale() -> void:
	UiScale.apply(get_window(), tv != null, _ui_size)


## Borra el progreso pero conserva los ajustes (calidad, sonido, velocidad, cuadros y tamaño), igual que la web.
func _reset_progress() -> void:
	var muted: bool = _audio().is_muted()
	_services.reset_progress()
	_s().store.save_value(QUALITY_KEY, String(_quality))
	GameSpeed.save_to(_s().store, _speed)
	FrameRate.save_to(_s().store, _fps)
	UiScale.save_size(_s().store, _ui_size)
	_audio().set_muted(muted)
	_welcome_checked = false
	_menu_stale = true


# ================================================================== partida


func _cosmetics() -> Dictionary:
	var inv: Inventory = _s().inventory
	var out: Dictionary = {}
	var helmet: String = inv.equipped_cosmetic(Catalog.SLOT_HELMET)
	var vest: String = inv.equipped_cosmetic(Catalog.SLOT_VEST)
	if helmet != "":
		out["helmet"] = Catalog.cosmetic_color(helmet)
	if vest != "":
		out["vest"] = Catalog.cosmetic_color(vest)
	return out


func start_level(run: LevelRun) -> void:
	_end_session()
	_run = run
	var s: AppServices = _s()
	var level: LevelDefinition = run.level if run.level != null else s.levels.get_level(run.level_id)
	var d: SessionDeps = SessionDeps.new()
	d.level = level
	d.purchase = run.purchase
	d.spent = s.levels.cost(level, run.purchase)
	d.active_boosters = run.boosters
	d.cosmetics = _cosmetics()
	d.audio = _audio()
	d.inventory = s.inventory
	d.boosters = s.boosters
	d.hud = hud
	d.ui = ui
	d.on_finished = _on_finished
	session = GameSession.new(d)
	world_host.add_child(session.root)
	session.set_quality(QUALITY_INDEX[_quality])
	session.speed = _speed
	if tv != null:
		session.on_feedback = _on_session_feedback
		for p: RemotePlayer in tv.players():
			session.add_technician(p.slot, p.name, Color.from_string(p.color, UiTheme.SUN))
	session.start_intro()
	_audio().play("whoosh")
	ui.screens.reset()
	ui.set_hud_visible(true)
	s.bus.emit_level_started(run.level_id)


func _on_finished(result: LevelResult) -> void:
	if duel != null:
		return # en el duelo el resultado lo da la carrera, no el día simulado
	var s: AppServices = _s()
	var outcome: LevelRecordOutcome = s.progress.record_result(result)
	s.bus.emit_level_finished(result)
	var next: LevelDefinition = s.levels.next_of(result.level_id)
	var level: LevelDefinition = s.levels.get_level(result.level_id)
	ui.set_hud_visible(false)
	var d: ResultDeps = ResultDeps.new()
	d.result = result
	d.level_name = "Nivel %d · %s" % [level.order, level.name]
	d.soles_earned = outcome.soles_earned
	d.unlocked_name = s.levels.get_level(outcome.newly_unlocked).name if outcome.newly_unlocked != "" else ""
	d.has_next = next != null and s.progress.is_unlocked(next.id)
	d.best_score = s.progress.progress(result.level_id).best_score
	d.audio = _audio()
	d.on_retry = func() -> void:
		var r: LevelRun = _run
		show_map()
		if r != null:
			push_workshop(r.level_id, r.purchase)
	d.on_next = func() -> void:
		show_map()
		if next != null:
			push_workshop(next.id)
	d.on_map = show_map
	ui.screens.push(ResultScreen.new(d))


func pause() -> void:
	if versus != null:
		_pause_versus()
		return
	var ss: GameSession = session
	if ss == null or ss.paused or ss.phase() == SessionPort.PHASE_FINISHED:
		return
	if duel != null:
		return # en el duelo no se pausa: el reloj del rival sigue corriendo
	ss.paused = true
	hud.joystick.reset()
	var d: PauseDeps = PauseDeps.new()
	d.audio = _audio()
	d.level_name = ss.level().name
	d.speed = _speed
	d.on_speed_change = _set_speed
	d.on_resume = _resume
	d.on_restart = func() -> void:
		if _run != null:
			start_level(_run)
	d.on_exit_to_map = show_map
	_pause_menu = PauseMenu.new(d)
	ui.screens.push(_pause_menu)


func _resume() -> void:
	if _pause_menu != null:
		ui.screens.remove(_pause_menu)
		_pause_menu = null
	if session != null:
		session.paused = false


func _end_session() -> void:
	_pause_menu = null
	if session == null:
		return
	session.dispose()
	session = null
	ui.set_hud_visible(false)
	_audio().set_wind(false)


## Con la alerta del Zonda arriba, el toast baja para no taparla (el `--alert-h` de la web).
## Diferido: el alto real de la alerta se conoce recién después del acomodo.
func _on_alert_resize(_height: float) -> void:
	_place_toast.call_deferred()


func _place_toast() -> void:
	var a: AlertBanner = hud.alert as AlertBanner
	var t: Toast = ui.toast as Toast
	var top: float = 12.0 + ((a.root.size.y + 8.0) if a.visible_now else 0.0)
	# Se corre entero (arriba y abajo) con su alto justo: mover solo el borde de arriba lo estiraba.
	t.root.offset_top = top
	t.root.offset_bottom = top + t.root.get_combined_minimum_size().y


# ================================================================== duelo


## Menú → Duelo: arranca a buscar la otra pantalla.
func start_duel() -> void:
	var link: DuelLink = DuelLink.new(_duel_name())
	# Pruebas con dos juegos en la misma compu: `-- --duel-port=18767 --duel-beacon=18768 --duel-targets=18769`.
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--duel-port="):
			link.port = int(a.trim_prefix("--duel-port="))
		elif a.begins_with("--duel-beacon="):
			link.beacon_port = int(a.trim_prefix("--duel-beacon="))
		elif a.begins_with("--duel-targets="):
			link.beacon_targets = [] as Array[int]
			for t: String in a.trim_prefix("--duel-targets=").split(",", false):
				link.beacon_targets.append(int(t))
		elif a.begins_with("--duel-bind="):
			link.bind_address = a.trim_prefix("--duel-bind=")
			link.beacon_address = link.bind_address
	if link.start() != OK:
		ui.show_toast("No se pudo abrir el duelo en esta red.", UiRootPort.KIND_BAD, 4000)
		return
	duel = DuelMatch.new(link)
	_show_duel_screen()


## Nombre que ve el otro tele: los jugadores con tablet ("Ana y Beto") o, sin tablets, uno genérico.
func _duel_name() -> String:
	var names: Array[String] = []
	if tv != null:
		for p: RemotePlayer in tv.players():
			names.append(p.name)
	return " y ".join(names) if not names.is_empty() else "la otra pantalla"


func _show_duel_screen() -> void:
	_end_duel_play()
	show_menu()
	_duel_screen = DuelScreen.new(duel, _s().levels.all(), leave_duel)
	ui.screens.push(_duel_screen)


func leave_duel() -> void:
	if duel != null:
		duel.link.stop()
	duel = null
	_duel_screen = null
	_end_duel_play()
	show_menu()


func _update_duel(dt: float) -> void:
	for e: StringName in duel.update(dt):
		if duel == null:
			return
		match e:
			&"go":
				_start_duel_level()
			&"finished":
				_show_duel_result()
			&"lobby":
				_show_duel_screen()
			&"progress", &"peer_lost":
				if _duel_banner != null:
					_duel_banner.set_text("Se cortó la conexión: terminá tu planta" if duel.peer_lost
						else DuelBanner.describe(duel.peer_name(), duel.peer_progress))
			&"lost":
				if session != null or _duel_screen == null or ui.screens.top() != _duel_screen:
					_show_duel_screen()
				ui.show_toast("Se perdió la conexión con la otra pantalla.", UiRootPort.KIND_BAD, 3600)
			_:
				if _duel_screen != null and ui.screens.top() == _duel_screen:
					_duel_screen.refresh()
	if _duel_screen != null and ui.screens.top() == _duel_screen:
		_duel_screen.tick()
	if duel.phase == DuelMatch.Phase.PLAYING and session != null:
		var p: Dictionary = session.duel_progress()
		if p != _duel_sent:
			_duel_sent = p
			duel.report_progress(p)
		if session.plant_ok():
			duel.report_done()


func _start_duel_level() -> void:
	var level: LevelDefinition = _s().levels.get_level(duel.level_id)
	start_level(LevelRun.make(duel.level_id, duel.purchase(), [] as Array[StringName], level))
	session.speed = 1
	_duel_sent = {}
	_duel_banner = DuelBanner.new()
	_duel_banner.set_text(DuelBanner.describe(duel.peer_name(), {}))
	ui.hud_layer.add_child(_duel_banner.root)


func _show_duel_result() -> void:
	var level: LevelDefinition = _s().levels.get_level(duel.level_id)
	_end_duel_play()
	ui.screens.reset(DuelResultScreen.new(duel, level.name, func() -> void:
		duel.back_to_lobby()
		_show_duel_screen(), leave_duel, _audio()))


## Cierra la partida del duelo y saca la franja del rival.
func _end_duel_play() -> void:
	if _duel_banner != null:
		_duel_banner.root.queue_free()
		_duel_banner = null
	_end_session()


# ================================================================== versus


## Menú → Versus: elegir el nivel. Hace falta al menos una tablet (la otra mitad, con el teclado).
func show_versus_setup() -> void:
	_end_versus()
	if _versus_players().size() < 2:
		ui.show_toast("Para el versus conectá dos tablets (o una, y la otra mitad se juega con el teclado).", UiRootPort.KIND_BAD, 4200)
		return
	ui.screens.push(SplitSetupScreen.new(_s().levels.all(), start_versus, _pop))


## Quién juega en cada mitad: las tablets por asiento; si hay una sola, la derecha es del teclado.
func _versus_players() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if tv == null:
		return out
	for p: RemotePlayer in tv.players():
		if out.size() < 2:
			out.append({"slot": p.slot, "name": p.name, "color": Color.from_string(p.color, UiTheme.SUN)})
	if out.size() == 1:
		out.append({"slot": -1, "name": "Teclado", "color": UiTheme.SUN})
	return out


func start_versus(level_id: String) -> void:
	var players: Array[Dictionary] = _versus_players()
	if players.size() < 2:
		ui.show_toast("Se desconectó una tablet: conectala y elegí el nivel de nuevo.", UiRootPort.KIND_BAD, 4000)
		return
	_end_versus()
	_end_session()
	_versus_level = level_id
	var s: AppServices = _s()
	versus = SplitVersus.new(s.levels.get_level(level_id), players, {
		"audio": _audio(), "inventory": s.inventory, "boosters": s.boosters,
		"on_feedback": _on_session_feedback,
	})
	hud.root.visible = false
	ui.hud_layer.add_child(versus.root)
	ui.screens.reset()
	ui.set_hud_visible(true)
	versus.start(QUALITY_INDEX[_quality])
	_audio().play("whoosh")


func _update_versus(dt: float, menu_open: bool) -> void:
	var local: Vector2 = (hud.joystick.vector() + _keyboard.vector()).clamp(-Vector2.ONE, Vector2.ONE)
	var moves: Array[Vector2] = []
	for side: SplitSide in versus.sides():
		if side.slot < 0:
			moves.append(local if not menu_open else Vector2.ZERO)
		else:
			var it: PlayerIntent = tv.intent(side.slot)
			moves.append(Vector2(it.x, it.y) if not menu_open else Vector2.ZERO)
	var v: SplitVersus = versus
	for e: StringName in v.update(dt, moves):
		if e == &"go":
			_audio().play("whoosh")
		elif e == &"finished":
			# Un momento para ver el festejo antes del cartel.
			get_tree().create_timer(1.8).timeout.connect(func() -> void:
				if versus == v:
					_show_versus_result())
	if menu_open or versus != v:
		return
	for side: SplitSide in v.sides():
		if side.slot < 0:
			continue
		var it: PlayerIntent = tv.intent(side.slot)
		if it.pause:
			_pause_versus()
			return
		var t: Technician = side.session.technician_for_slot(side.slot)
		if t == null:
			continue
		if v.phase == SplitVersus.Phase.PLAYING and (it.action or it.inspect or it.tool):
			side.session.apply_intent(t, it)
		var ctx: Dictionary = side.session.controller_context(t)
		if v.phase == SplitVersus.Phase.COUNTDOWN:
			# En la cuenta regresiva la partida está quieta, pero la tablet ya muestra los controles.
			ctx["screen"] = "playing"
			ctx["objective"] = v.countdown_text()
		tv.host.set_context(side.slot, ctx)


func _pause_versus() -> void:
	if versus == null or versus.phase == SplitVersus.Phase.FINISHED or _versus_pause != null:
		return
	versus.set_paused(true)
	hud.joystick.reset()
	_versus_pause = SplitPauseScreen.new(_resume_versus, leave_versus)
	ui.screens.push(_versus_pause)


func _resume_versus() -> void:
	if _versus_pause != null:
		ui.screens.remove(_versus_pause)
		_versus_pause = null
	if versus != null:
		versus.set_paused(false)


func _show_versus_result() -> void:
	_versus_pause = null
	ui.screens.reset(SplitResultScreen.new(versus,
		func() -> void: start_versus(_versus_level),
		func() -> void:
			show_menu()
			show_versus_setup(),
		leave_versus, _audio()))


func leave_versus() -> void:
	show_menu()


## Cierra las dos partidas del versus y devuelve el HUD normal.
func _end_versus() -> void:
	_versus_pause = null
	if versus == null:
		return
	versus.dispose()
	versus = null
	hud.root.visible = true
	ui.set_hud_visible(false)


## Partida que manejan el teclado y la pantalla táctil: la normal, o en el versus la mitad sin tablet.
func _local_session() -> GameSession:
	if versus != null:
		return versus.keyboard_session() if versus.phase == SplitVersus.Phase.PLAYING and not versus.paused else null
	return session


# ================================================================== modo TV


## Una tablet entró (o volvió) en plena partida: su técnico aparece al lado del otro.
func _on_tv_join(p: RemotePlayer) -> void:
	if versus != null:
		var side: SplitSide = versus.side_for_slot(p.slot)
		if side != null:
			side.session.add_technician(p.slot, p.name, side.color)
		return
	if session != null:
		session.add_technician(p.slot, p.name, Color.from_string(p.color, UiTheme.SUN))


## Aviso de la partida para las tablets: el texto (también las pistas "info") y una vibración en
## los logros y errores. Lo que provocó un técnico va solo a su tablet; el clima y la noche, a todas.
func _on_session_feedback(slot: int, kind: StringName, text: String) -> void:
	for s: int in RemoteHost.targets(slot):
		if kind == &"bad":
			tv.host.haptic(s, [90, 60, 90])
		elif kind == &"good":
			tv.host.haptic(s, [35])
		tv.host.toast(s, text, String(kind))


## Qué muestran las tablets fuera de la partida, según la pantalla de arriba del tele.
func _push_menu_context() -> void:
	var top: UiScreen = ui.screens.top()
	var menu: Dictionary = _mirror.scan(top.root if top != null else null)
	if top is LobbyScreen:
		tv.menu_context("lobby", "¡Listo! Cuando estén todos, tocá Empezar", menu)
	elif top is PauseMenu:
		tv.menu_context("paused", "Pausa: elegí qué hacer", menu)
	elif top is DuelResultScreen and duel != null:
		tv.menu_context("result", DuelResultScreen.tablet_text(duel), menu)
	elif top is ResultScreen:
		tv.menu_context("result", "¡Mirá el resultado en el tele!", menu)
	elif top is SplitPauseScreen:
		tv.menu_context("paused", "Versus en pausa: elegí qué hacer", menu)
	elif top is SplitResultScreen and versus != null:
		tv.menu_context("result", SplitResultScreen.title_text(versus), menu)
	elif top is SplitSetupScreen:
		tv.menu_context("menu", "Versus: elegí el nivel en el tele", menu)
	elif top is DuelScreen and duel != null:
		tv.menu_context("menu", DuelScreen.tablet_text(duel), menu)
	else:
		tv.menu_context("menu", "Tocá una opción o usá las flechas", menu)


func _on_sfx(sfx_name: String) -> void:
	_audio().play(sfx_name)


func _on_action() -> void:
	var ss: GameSession = _local_session()
	if ss != null:
		ss.do_action()


func _on_inspect() -> void:
	var ss: GameSession = _local_session()
	if ss != null:
		ss.toggle_inspect()


func _on_meter() -> void:
	var ss: GameSession = _local_session()
	if ss != null:
		ss.toggle_meter()


func _on_use_booster(id: String) -> void:
	var ss: GameSession = _local_session()
	if ss != null:
		ss.use_booster(id)


func _on_toggle_load(label: String, on: bool) -> void:
	var ss: GameSession = _local_session()
	if ss != null:
		ss.toggle_load(label, on)


func _on_inspect_close() -> void:
	var ss: GameSession = _local_session()
	if ss != null:
		ss.close_inspect()


## Botón atrás de Android (o Escape). false = no había nada que cerrar (la app puede salir).
func handle_back() -> bool:
	if tv != null and ui.screens.top() is MainMenu:
		show_lobby()
		return true
	if ui.handle_back():
		return true
	if versus != null:
		_pause_versus()
		return true
	if session != null and session.phase() != SessionPort.PHASE_FINISHED:
		pause()
		return true
	return false
