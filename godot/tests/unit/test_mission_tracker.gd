extends TestCase
## Test de humo de MissionTracker: una PlantWorld real + un MissionFacts falso, para
## confirmar que la lista de objetivos y la pista avanzan como se espera a medida que
## se arma la planta.

class FakeFacts:
	extends MissionFacts
	var lv: LevelDefinition
	var buy: Purchase
	var w: PlantWorld
	var h: HandsController
	var _phase: StringName = SessionPort.PHASE_BUILD
	var _weather: String = WeatherSchedule.CALM
	var _connector: ConnectorFacts = ConnectorFacts.new()
	var _won: bool = false

	func _init(level: LevelDefinition, purchase: Purchase, world: PlantWorld, hands: HandsController) -> void:
		lv = level
		buy = purchase
		w = world
		h = hands

	func level() -> LevelDefinition:
		return lv

	func purchase() -> Purchase:
		return buy

	func world() -> PlantWorld:
		return w

	func hands() -> HandsController:
		return h

	func phase() -> StringName:
		return _phase

	func weather() -> String:
		return _weather

	func connector() -> ConnectorFacts:
		return _connector

	func won() -> bool:
		return _won


func test_mission_tracker_objetivos_avanzan_al_construir() -> void:
	var level: LevelDefinition = Levels.casa()
	var purchase: Purchase = Purchase.make(4, 1, false)
	var w: PlantWorld = PlantWorld.new(level, purchase, Callable())
	var hands: HandsController = HandsController.new(WorkerVisual.new())
	var facts: FakeFacts = FakeFacts.new(level, purchase, w, hands)
	var tracker: MissionTracker = MissionTracker.new(facts)

	var obj: Array[MissionObjective] = tracker.objectives()
	check(obj.size() >= 7, "al menos 7 objetivos para casa (sin conector flojo ni kit)")
	check_eq(obj[0].id, &"panels", "el primer objetivo es instalar paneles")
	check_eq(obj[0].state, MissionObjective.STATE_NOW, "instalar paneles es 'ahora' al arrancar")

	# El hint debería apuntar a algún cajón o al pallet mientras faltan paneles.
	var hint: Variant = tracker.hint_target()
	check(hint != null, "hay una pista mientras faltan paneles")

	for m: Mount in w.mounts:
		m.install(false)
	w.protection.install()
	w.batteries[0].install()
	w.cables.connect_cable(CableNetwork.COLOR_ORANGE, PackedVector3Array([Vector3.ZERO, Vector3.ONE]))
	w.cables.connect_cable(CableNetwork.COLOR_BLUE, PackedVector3Array([Vector3.ZERO, Vector3.ONE]))
	w.cables.connect_cable(CableNetwork.COLOR_VIOLET, PackedVector3Array([Vector3.ZERO, Vector3.ONE]))

	obj = tracker.objectives()
	var panels_item: MissionObjective
	for o: MissionObjective in obj:
		if o.id == &"panels":
			panels_item = o
	check_eq(panels_item.state, MissionObjective.STATE_OK, "con los 4 paneles instalados, el objetivo queda OK")

	var activate_item: MissionObjective
	for o: MissionObjective in obj:
		if o.id == &"activate":
			activate_item = o
	check_eq(activate_item.state, MissionObjective.STATE_NOW, "todo listo salvo activar: ahora toca activar")
	check_eq(tracker.hint_target(), w.console.approach, "con todo instalado, la pista apunta a la consola")

	facts._phase = SessionPort.PHASE_RUNNING
	obj = tracker.objectives()
	for o: MissionObjective in obj:
		if o.id == &"activate":
			check_eq(o.state, MissionObjective.STATE_OK, "ya corriendo, activar queda OK")
	w.free()


func test_mission_tracker_pista_sigue_lo_que_el_jugador_lleva() -> void:
	var level: LevelDefinition = Levels.casa()
	var purchase: Purchase = Purchase.make(4, 1, false)
	var w: PlantWorld = PlantWorld.new(level, purchase, Callable())
	var hands: HandsController = HandsController.new(WorkerVisual.new())
	var facts: FakeFacts = FakeFacts.new(level, purchase, w, hands)
	var tracker: MissionTracker = MissionTracker.new(facts)

	hands.carry(&"protection")
	check_eq(tracker.hint_target(), w.protection.approach, "cargando protección, la pista apunta a su lugar")

	hands.take_cable(CableNetwork.COLOR_ORANGE, &"junction", w.junction.terminal)
	check_eq(tracker.hint_target(), w.protection.approach, "cable naranja en mano: la pista apunta a la protección")
	w.free()
