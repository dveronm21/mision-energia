class_name PickupProvider
extends ActionProvider
## Manos libres: tomar panel del pallet, cajones y paneles sueltos (equivale a
## `PickupProvider` de `interaction/Providers.ts`).

const ITEM_NAME: Dictionary[StringName, String] = {
	&"panel": "panel", &"battery": "batería", &"protection": "protección", &"kit": "kit anti-Zonda",
}

var _s: SessionPort


func _init(session: SessionPort) -> void:
	_s = session


func collect(hands: HandsState, out: Array[WorldAction]) -> void:
	if hands.kind != HandsState.KIND_FREE:
		return
	var w: PlantWorld = _s.world()
	if w.pallet.remaining() > 0:
		out.append(WorldAction.new("pallet", "Tomar panel", w.pallet.approach, _s.take_from_pallet))
	for i: int in w.pickups.size():
		var p: Pickup = w.pickups[i]
		var label: String = "Tomar %s" % ITEM_NAME.get(p.kind, String(p.kind))
		out.append(WorldAction.new("pickup:%d:%s" % [i, p.kind], label, p.approach, _s.take_pickup.bind(p)))
