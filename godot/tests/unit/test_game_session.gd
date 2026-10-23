extends TestCase
## Test de humo de GameSession: arma una partida completa de "casa" con dependencias reales
## (salvo el HUD, que es el puerto por defecto) y la lleva de punta a punta: construir,
## activar, simular hasta ganar o perder. No reproduce GameSession.ts línea por línea (ya lo
## hacen los tests de sus piezas); esto confirma que el ensamblado entero no explota.


static func _deps(level: LevelDefinition, purchase: Purchase) -> SessionDeps:
	var d: SessionDeps = SessionDeps.new()
	d.level = level
	d.purchase = purchase
	d.spent = 0
	d.active_boosters = [] as Array[StringName]
	d.cosmetics = {}
	d.audio = AudioSynth.new()
	d.audio.setup(SaveStore.in_memory())
	d.inventory = Inventory.new(SaveStore.in_memory())
	d.boosters = Boosters.new(d.inventory)
	d.hud = HudPort.new()
	d.ui = UiRootPort.new()
	d.on_finished = Callable()
	return d


func test_game_session_arma_una_partida_de_casa() -> void:
	var level: LevelDefinition = Levels.casa()
	var purchase: Purchase = Purchase.make(4, 1, false)
	var s: GameSession = GameSession.new(_deps(level, purchase))

	check_eq(s.phase(), SessionPort.PHASE_BUILD, "arranca en fase de obra")
	check(s.root.get_child_count() > 0, "la raíz tiene hijos (mundo, ambiente, cámara, resaltados)")
	check(s.player != null, "el jugador existe")
	check_eq(s.world().panels_installed(), 0, "sin paneles instalados al arrancar")

	# Un cuadro de juego no debería explotar.
	s.update(0.016, Vector2.ZERO)
	check_eq(s.phase(), SessionPort.PHASE_BUILD, "sigue en obra tras un cuadro sin construir nada")

	s.dispose()


func test_game_session_arma_la_planta_completa_y_activa() -> void:
	var level: LevelDefinition = Levels.casa()
	var purchase: Purchase = Purchase.make(4, 1, false)
	var s: GameSession = GameSession.new(_deps(level, purchase))

	# Agarrar y colocar los 4 paneles.
	for i: int in 4:
		s.take_from_pallet()
		var h: HandsState = s.hands().hands()
		check_eq(h.kind, HandsState.KIND_CARRY, "manos cargando un panel (%d)" % i)
		s.install_panel(s.world().mounts[i])
	check_eq(s.world().panels_installed(), 4, "los 4 paneles quedaron instalados")

	# Protección.
	s.take_pickup(_find_pickup(s, &"protection"))
	s.install_protection()
	check(s.world().protection.installed(), "protección instalada")

	# Batería.
	s.take_pickup(_find_pickup(s, &"battery"))
	s.install_battery(0)
	check(s.world().batteries[0].installed(), "batería instalada")

	# Cables: naranja (junction → protección), azul (batería → inversor), violeta (tablero → inversor).
	s.take_cable(CableNetwork.COLOR_ORANGE, &"junction", s.world().junction.terminal)
	s.connect_cable(&"protection")
	check(s.world().cables.cable_connected(CableNetwork.COLOR_ORANGE), "cable naranja conectado")

	s.take_cable(CableNetwork.COLOR_BLUE, &"battery", s.world().batteries[0].terminal)
	s.connect_cable(&"inverter")
	check(s.world().cables.cable_connected(CableNetwork.COLOR_BLUE), "cable azul conectado")

	s.take_cable(CableNetwork.COLOR_VIOLET, &"switchboard", s.world().switchboard.terminal)
	s.connect_cable(&"inverter")
	check(s.world().cables.cable_connected(CableNetwork.COLOR_VIOLET), "cable violeta conectado")

	s.try_activate()
	check_eq(s.phase(), SessionPort.PHASE_RUNNING, "la planta queda corriendo tras activar con todo instalado")
	check(s.snapshot() != null, "hay una foto del simulador")

	# Avanzar varios cuadros no debería explotar.
	for _i: int in 30:
		s.update(0.05, Vector2(0.0, -1.0))
	check(s.game_hour() > level.start_hour, "el reloj de juego avanzó")

	s.dispose()


func test_game_session_no_activa_si_falta_algo() -> void:
	var level: LevelDefinition = Levels.casa()
	var purchase: Purchase = Purchase.make(4, 1, false)
	var s: GameSession = GameSession.new(_deps(level, purchase))
	s.try_activate()
	check_eq(s.phase(), SessionPort.PHASE_BUILD, "no activa si no se instaló nada")
	s.dispose()


func test_game_session_mission_tracker_y_pista_no_explotan() -> void:
	var level: LevelDefinition = Levels.casa()
	var purchase: Purchase = Purchase.make(4, 1, false)
	var deps: SessionDeps = _deps(level, purchase)
	deps.active_boosters = [Boosters.HINT] as Array[StringName]
	var s: GameSession = GameSession.new(deps)
	s.force_interaction_update()
	check(s.available_actions().size() > 0, "hay acciones disponibles con manos libres (pallet)")
	s.dispose()


static func _find_pickup(s: GameSession, kind: StringName) -> Pickup:
	for p: Pickup in s.world().pickups:
		if p.kind == kind:
			return p
	return null
