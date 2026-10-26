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


func test_game_session_cooperativo_dos_tecnicos() -> void:
	var level: LevelDefinition = Levels.casa()
	var s: GameSession = GameSession.new(_deps(level, Purchase.make(4, 1, false)))
	var feedback: Array = []
	s.on_feedback = func(slot: int, kind: StringName, _text: String) -> void: feedback.append([slot, kind])

	var a: Technician = s.add_technician(0, "Ana", Color.RED)
	check_eq(s.technicians().size(), 1, "el primer asiento usa el técnico que ya estaba")
	var b: Technician = s.add_technician(1, "Beto", Color.BLUE)
	check_eq(s.technicians().size(), 2, "el segundo asiento suma otro técnico")
	check(a.player != b.player and a.hands != b.hands, "cada uno con su cuerpo y sus manos")
	check_eq(s.technician_for_slot(1), b, "se encuentra por asiento")
	check(a.name_tag != null and b.name_tag.text == "Beto", "carteles con el nombre")

	# Beto agarra un panel del pallet: sus manos cargan, las de Ana siguen libres.
	s.take_from_pallet() # con Ana activa (técnico 0)
	check_eq(a.hands.kind(), HandsState.KIND_CARRY, "Ana carga el panel")
	var intent: PlayerIntent = PlayerIntent.new()
	s._bind(b)
	s.take_from_pallet()
	s._save_actor()
	s._bind(a)
	check_eq(b.hands.kind(), HandsState.KIND_CARRY, "Beto carga otro panel")
	s.install_panel(s.world().mounts[0])
	check(a.hands.is_free(), "Ana instaló y quedó con las manos libres")
	check_eq(b.hands.kind(), HandsState.KIND_CARRY, "Beto sigue cargando el suyo")

	# Un cuadro con los dos moviéndose no explota; el contexto de cada tablet es propio.
	for _i: int in 5:
		s.update_multi(0.05, [Vector2(0.5, 0.0), Vector2(-0.5, 0.0)] as Array[Vector2])
	var ctx_b: Dictionary = s.controller_context(b)
	check_eq(String(ctx_b["action"]["label"]), "Soltar", "la tablet de Beto ofrece soltar lo que carga")
	check_eq(String(ctx_b["screen"]), "playing", "pantalla de juego")
	check(String(ctx_b["objective"]) != "", "lleva el paso actual de la misión")

	# Error de Beto: el aviso va a su asiento (1); intento sin efectos no manda nada raro.
	intent.tool = true
	s.apply_intent(b, intent) # multímetro con las manos ocupadas → toast "bad"
	check(feedback.size() > 0 and feedback[feedback.size() - 1][0] == 1, "el aviso va a la tablet de Beto")
	check_eq(s.player, a.player, "después de una pulsación vuelve a quedar activo el técnico 0")
	s.dispose()


static func _find_pickup(s: GameSession, kind: StringName) -> Pickup:
	for p: Pickup in s.world().pickups:
		if p.kind == kind:
			return p
	return null


## Arma y activa la planta de "casa" (4 paneles, protección, batería y los 3 cables).
static func _build_casa(s: GameSession) -> void:
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


func test_game_session_velocidad_salvo_clima() -> void:
	var level: LevelDefinition = Levels.casa()
	# Nubes de 11 a 12 y Zonda a las 15 (con su alerta antes).
	level.events = LevelEvents.make(false, 15.0, [CloudBand.make(11, 12, 0.5)] as Array[CloudBand])
	var s: GameSession = GameSession.new(_deps(level, Purchase.make(4, 1, false)))
	s.speed = 4
	check_eq(s.effective_speed(), 1, "en obra el reloj no corre: velocidad ×1")
	_build_casa(s)
	check_eq(s.phase(), SessionPort.PHASE_RUNNING, "la planta corre")

	s._hour = 10.5
	check_eq(s.effective_speed(), 4, "con tiempo tranquilo corre a ×4")
	var h0: float = s.game_hour()
	s.update(0.05, Vector2.ZERO)
	var fast: float = s.game_hour() - h0
	s.speed = 1
	s._hour = 10.5
	s.update(0.05, Vector2.ZERO)
	var slow: float = s.game_hour() - 10.5
	check(fast > slow * 3.5, "×4 avanza unas 4 veces más rápido que ×1 (%.4f contra %.4f)" % [fast, slow])

	s.speed = 4
	s._hour = 11.5
	check_eq(s.effective_speed(), 1, "con nubes vuelve a ×1")
	var zw: ZondaWindow = WeatherSchedule.new(level.events).zonda_window()
	s._hour = (zw.warn_from + zw.storm_from) / 2.0
	check_eq(s.effective_speed(), 1, "con alerta de Zonda vuelve a ×1")
	s._hour = (zw.storm_from + zw.storm_to) / 2.0
	check_eq(s.effective_speed(), 1, "con tormenta de Zonda vuelve a ×1")
	s._hour = zw.storm_to + 0.5
	check_eq(s.effective_speed(), 4, "pasado el Zonda vuelve a ×4")
	s.dispose()
