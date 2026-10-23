class_name ConsoleProvider
extends ActionProvider
## Manos libres, en obra: activar la planta (equivale a `ConsoleProvider` de
## `interaction/Providers.ts`).

var _s: SessionPort


func _init(session: SessionPort) -> void:
	_s = session


func collect(hands: HandsState, out: Array[WorldAction]) -> void:
	if hands.kind != HandsState.KIND_FREE or _s.phase() != SessionPort.PHASE_BUILD:
		return
	out.append(WorldAction.new("activate", "Activar planta", _s.world().console.approach, _s.try_activate))
