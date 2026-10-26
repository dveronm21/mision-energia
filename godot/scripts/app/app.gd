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
var _quality: StringName = &"medium"
var _speed: int = 1
var _ui_size: StringName = UiScale.NORMAL
var _welcome_checked: bool = false
## Después de "Reiniciar progreso" el menú de abajo tiene los servicios viejos: al salir de
## Ajustes se arma de nuevo.
var _menu_stale: bool = false
var _pause_menu: PauseMenu = null
## null fuera del modo TV.
var tv: TvMode = null


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
	_ui_size = UiScale.load_size(_services.store)
	_apply_ui_scale()
	get_window().size_changed.connect(_apply_ui_scale)

	show_splash()


func _process(delta: float) -> void:
	var dt: float = minf(0.1, maxf(0.0, delta))
	if tv != null:
		tv.poll()
	var ss: GameSession = session
	var menu_open: bool = ui.screens.top() != null
	if tv != null and (ss == null or menu_open):
		tv.navigate_menus(dt)
		_push_menu_context()
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
	var level: LevelDefinition = s.levels.get_level(id)
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
		start_level(LevelRun.make(id, purchase, used))
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


func _set_ui_size(v: StringName) -> void:
	_ui_size = v
	UiScale.save_size(_s().store, v)
	_apply_ui_scale()


func _apply_ui_scale() -> void:
	UiScale.apply(get_window(), tv != null, _ui_size)


## Borra el progreso pero conserva los ajustes (calidad, sonido, velocidad y tamaño), igual que la web.
func _reset_progress() -> void:
	var muted: bool = _audio().is_muted()
	_services.reset_progress()
	_s().store.save_value(QUALITY_KEY, String(_quality))
	GameSpeed.save_to(_s().store, _speed)
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
	var level: LevelDefinition = s.levels.get_level(run.level_id)
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
	var ss: GameSession = session
	if ss == null or ss.paused or ss.phase() == SessionPort.PHASE_FINISHED:
		return
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


# ================================================================== modo TV


## Una tablet entró (o volvió) en plena partida: su técnico aparece al lado del otro.
func _on_tv_join(p: RemotePlayer) -> void:
	if session != null:
		session.add_technician(p.slot, p.name, Color.from_string(p.color, UiTheme.SUN))


## Aviso de la partida para las tablets: vibración siempre, y el texto solo a quien lo provocó.
func _on_session_feedback(slot: int, kind: StringName, text: String) -> void:
	var targets: Array[int] = [slot] if slot >= 0 else RemoteHost.SLOTS
	for s: int in targets:
		if kind == &"bad":
			tv.host.haptic(s, [90, 60, 90])
		elif kind == &"good":
			tv.host.haptic(s, [35])
		if slot >= 0 and kind != &"info":
			tv.host.toast(s, text, String(kind))


## Qué muestran las tablets fuera de la partida, según la pantalla de arriba del tele.
func _push_menu_context() -> void:
	var top: UiScreen = ui.screens.top()
	if top is LobbyScreen:
		tv.menu_context("lobby", "¡Listo! Cuando estén todos, tocá Empezar en el tele")
	elif top is PauseMenu:
		tv.menu_context("paused", "Pausa: elegí en el tele con el stick y el botón")
	elif top is ResultScreen:
		tv.menu_context("result", "¡Mirá el resultado en el tele!")
	else:
		tv.menu_context("menu", "Elegí en el tele: mové el stick y tocá el botón")


func _on_sfx(sfx_name: String) -> void:
	_audio().play(sfx_name)


func _on_action() -> void:
	if session != null:
		session.do_action()


func _on_inspect() -> void:
	if session != null:
		session.toggle_inspect()


func _on_meter() -> void:
	if session != null:
		session.toggle_meter()


func _on_use_booster(id: String) -> void:
	if session != null:
		session.use_booster(id)


func _on_toggle_load(label: String, on: bool) -> void:
	if session != null:
		session.toggle_load(label, on)


func _on_inspect_close() -> void:
	if session != null:
		session.close_inspect()


## Botón atrás de Android (o Escape). false = no había nada que cerrar (la app puede salir).
func handle_back() -> bool:
	if tv != null and ui.screens.top() is MainMenu:
		show_lobby()
		return true
	if ui.handle_back():
		return true
	if session != null and session.phase() != SessionPort.PHASE_FINISHED:
		pause()
		return true
	return false
