extends TestCase
## Test de humo del sistema de interacción: un `SessionPort` falso + un `PlantWorld` real,
## para confirmar que los proveedores de acciones no explotan y devuelven lo esperable.

class FakeLive:
	extends LiveSource
	var w: PlantWorld
	var lv: LevelDefinition

	func _init(world: PlantWorld, level: LevelDefinition) -> void:
		w = world
		lv = level

	func level() -> LevelDefinition:
		return lv

	func world() -> PlantWorld:
		return w

	func is_running() -> bool:
		return false

	func snapshot() -> SimSnapshot:
		return null


class FakeSession:
	extends SessionPort

	var w: PlantWorld
	var _phase: StringName = PHASE_BUILD
	var taken_from_pallet: int = 0
	var activated: int = 0

	func _init(world: PlantWorld) -> void:
		w = world

	func world() -> PlantWorld:
		return w

	func phase() -> StringName:
		return _phase

	func weather() -> String:
		return WeatherSchedule.CALM

	func take_from_pallet() -> void:
		taken_from_pallet += 1

	func try_activate() -> void:
		activated += 1


func test_pickup_provider_ofrece_tomar_del_pallet_con_manos_libres() -> void:
	var w: PlantWorld = PlantWorld.new(Levels.casa(), Purchase.make(4, 1, false), Callable())
	var s: FakeSession = FakeSession.new(w)
	var provider: PickupProvider = PickupProvider.new(s)
	var out: Array[WorldAction] = []
	provider.collect(HandsState.free_hands(), out)

	var has_pallet: bool = false
	for a: WorldAction in out:
		if a.id == "pallet":
			has_pallet = true
			a.run.call()
	check(has_pallet, "ofrece tomar del pallet")
	check_eq(s.taken_from_pallet, 1, "ejecutar la acción llama a take_from_pallet()")

	var carrying: Array[WorldAction] = []
	provider.collect(HandsState.carry(&"panel"), carrying)
	check(carrying.is_empty(), "con las manos ocupadas no ofrece nada")
	w.free()


func test_placement_provider_ofrece_colocar_panel_en_montaje_vacio() -> void:
	var w: PlantWorld = PlantWorld.new(Levels.casa(), Purchase.make(4, 1, false), Callable())
	var s: FakeSession = FakeSession.new(w)
	var provider: PlacementProvider = PlacementProvider.new(s)
	var out: Array[WorldAction] = []
	provider.collect(HandsState.carry(&"panel"), out)
	check_eq(out.size(), 4, "4 montajes vacíos ofrecen 'colocar panel'")

	w.mounts[0].install(false)
	out = []
	provider.collect(HandsState.carry(&"panel"), out)
	check_eq(out.size(), 3, "con uno instalado, quedan 3 ofertas")
	w.free()


func test_console_provider_solo_en_obra_con_manos_libres() -> void:
	var w: PlantWorld = PlantWorld.new(Levels.casa(), Purchase.make(4, 1, false), Callable())
	var s: FakeSession = FakeSession.new(w)
	var provider: ConsoleProvider = ConsoleProvider.new(s)

	var out: Array[WorldAction] = []
	provider.collect(HandsState.free_hands(), out)
	check_eq(out.size(), 1, "ofrece activar en fase de obra")
	out[0].run.call()
	check_eq(s.activated, 1, "ejecutar la acción llama a try_activate()")

	s._phase = SessionPort.PHASE_RUNNING
	out = []
	provider.collect(HandsState.free_hands(), out)
	check(out.is_empty(), "ya corriendo, no ofrece activar de nuevo")
	w.free()


func test_interaction_system_elige_la_accion_mas_cercana() -> void:
	var w: PlantWorld = PlantWorld.new(Levels.casa(), Purchase.make(4, 1, false), Callable())
	var s: FakeSession = FakeSession.new(w)
	var sys: InteractionSystem = InteractionSystem.new(
		[PickupProvider.new(s) as ActionProvider],
		[] as Array[InspectProvider],
	)
	var pick: InteractionPick = sys.update(HandsState.free_hands(), w.pallet.approach)
	check(pick.action != null, "hay una acción cerca del pallet")
	check_eq(pick.action.id, "pallet", "la acción más cercana es tomar del pallet")

	var far: InteractionPick = sys.update(HandsState.free_hands(), Vector3(500.0, 0.0, 500.0))
	check(far.action == null, "lejos de todo, ninguna acción entra en el radio")
	w.free()


func test_inspectables_no_explota_sin_simulacion_corriendo() -> void:
	var level: LevelDefinition = Levels.casa()
	var w: PlantWorld = PlantWorld.new(level, Purchase.make(4, 1, false), Callable())
	var insp: Inspectables = Inspectables.new(FakeLive.new(w, level))

	var out: Array[InspectEntry] = []
	insp.inspectables(out)
	# 4 montajes + pallet + 2 cajones + junction + 1 poste + protección + inversor + 1 batería
	# + tablero + consola = 14 (casa no tiene bomba).
	check_eq(out.size(), 14, "cantidad de fichas de 'Revisar' para casa")
	for e: InspectEntry in out:
		check(e.title != "", "%s: tiene título" % e.id)
		e.live_text()  # no debe explotar aunque no haya simulación corriendo.
	w.free()
