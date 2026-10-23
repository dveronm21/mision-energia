class_name InteractionSystem
extends RefCounted
## Junta las acciones de todas las estrategias para el estado de manos actual y elige la más
## cercana al jugador (y la ficha de "Revisar" más cercana). Equivale a `InteractionSystem.ts`.

const ACTION_RADIUS: float = 2.1
const INSPECT_RADIUS: float = 3.0

var _providers: Array[ActionProvider]
var _inspectors: Array[InspectProvider]
var _action_radius: float
var _inspect_radius: float


func _init(providers: Array[ActionProvider], inspectors: Array[InspectProvider],
		action_radius: float = ACTION_RADIUS, inspect_radius: float = INSPECT_RADIUS) -> void:
	_providers = providers
	_inspectors = inspectors
	_action_radius = action_radius
	_inspect_radius = inspect_radius


## Todas las acciones disponibles ahora (para depuración y pruebas).
func available(hands: HandsState) -> Array[WorldAction]:
	var out: Array[WorldAction] = []
	for p: ActionProvider in _providers:
		p.collect(hands, out)
	return out


func update(hands: HandsState, at: Vector3) -> InteractionPick:
	var actions: Array[WorldAction] = available(hands)
	var action: WorldAction = _nearest_action(actions, at, _action_radius)
	var ins: Array[InspectEntry] = []
	for p: InspectProvider in _inspectors:
		p.inspectables(ins)
	var inspect: InspectEntry = _nearest_inspect(ins, at, _inspect_radius)
	return InteractionPick.new(action, inspect)


static func _nearest_action(list: Array[WorldAction], at: Vector3, r: float) -> WorldAction:
	var best: WorldAction = null
	var bd: float = r
	for a: WorldAction in list:
		var d: float = Vector2(a.pos.x - at.x, a.pos.z - at.z).length()
		if d < bd:
			bd = d
			best = a
	return best


static func _nearest_inspect(list: Array[InspectEntry], at: Vector3, r: float) -> InspectEntry:
	var best: InspectEntry = null
	var bd: float = r
	for a: InspectEntry in list:
		var d: float = Vector2(a.pos.x - at.x, a.pos.z - at.z).length()
		if d < bd:
			bd = d
			best = a
	return best
