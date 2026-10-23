class_name App
extends Node
## Raíz de composición (equivale a `App.ts`). Usa los servicios del autoload `Services`, arma
## la UI y el HUD, y navega entre pantallas:
## Splash → Menú (regalo de bienvenida y bono diario) → Mapa → Taller → Partida → Resultado.
## Tienda (con control parental), Vestuario (cosméticos del técnico) y Ajustes (calidad y sonido).
##
## Es el script de `scenes/Main.tscn`. El mundo 3D de la partida va en `world_host`; la UI,
## en una `CanvasLayer` encima.

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
var _welcome_checked: bool = false
## Después de "Reiniciar progreso" el menú de abajo tiene los servicios viejos: al salir de
## Ajustes se arma de nuevo.
var _menu_stale: bool = false
var _pause_menu: PauseMenu = null


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

	_keyboard.on_action = cb.on_action
	_keyboard.on_inspect = cb.on_inspect
	_keyboard.on_meter = cb.on_meter
	_keyboard.on_back = func() -> void: handle_back()

	_services.bus.sfx.connect(_on_sfx)

	_quality = StringName(_services.store.load_value(QUALITY_KEY, "medium"))
	if not QUALITY_INDEX.has(_quality):
		_quality = &"medium"

	show_splash()


func _process(delta: float) -> void:
	var ss: GameSession = session
	if ss == null:
		return
	var input: Vector2 = (hud.joystick.vector() + _keyboard.vector()).clamp(-Vector2.ONE, Vector2.ONE)
	ss.update(minf(0.1, maxf(0.0, delta)), input)


func _unhandled_input(event: InputEvent) -> void:
	if _keyboard.handle(event):
		get_viewport().set_input_as_handled()


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
	ui.screens.reset(SplashScreen.new(show_menu, _audio(), _version()))


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


## Borra el progreso pero conserva la calidad y el sonido (igual que la web).
func _reset_progress() -> void:
	var muted: bool = _audio().is_muted()
	_services.reset_progress()
	_s().store.save_value(QUALITY_KEY, String(_quality))
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
	t.root.offset_top = 12.0 + ((a.root.size.y + 8.0) if a.visible_now else 0.0)


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
	if ui.handle_back():
		return true
	if session != null and session.phase() != SessionPort.PHASE_FINISHED:
		pause()
		return true
	return false
