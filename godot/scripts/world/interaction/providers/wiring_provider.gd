class_name WiringProvider
extends ActionProvider
## Manos libres o con un cable: tomar un cable de su equipo y conectarlo a otro (equivale a
## `WiringProvider` de `interaction/Providers.ts`).

var _s: SessionPort


func _init(session: SessionPort) -> void:
	_s = session


func collect(hands: HandsState, out: Array[WorldAction]) -> void:
	var w: PlantWorld = _s.world()
	if hands.kind == HandsState.KIND_FREE:
		if _s.phase() != SessionPort.PHASE_BUILD:
			return
		var c: CableNetwork = w.cables
		if not c.cable_connected(CableNetwork.COLOR_ORANGE):
			out.append(WorldAction.new("cable:orange", "Tomar cable naranja", w.junction.approach,
				_s.take_cable.bind(CableNetwork.COLOR_ORANGE, &"junction", w.junction.terminal)))
		if not c.cable_connected(CableNetwork.COLOR_BLUE):
			for b: BatterySlot in w.batteries:
				if b.installed():
					out.append(WorldAction.new("cable:blue:%d" % b.index, "Tomar cable azul", b.approach,
						_s.take_cable.bind(CableNetwork.COLOR_BLUE, &"battery", b.terminal)))
		if not c.cable_connected(CableNetwork.COLOR_VIOLET):
			out.append(WorldAction.new("cable:violet", "Tomar cable violeta", w.switchboard.approach,
				_s.take_cable.bind(CableNetwork.COLOR_VIOLET, &"switchboard", w.switchboard.terminal)))
		return
	if hands.kind != HandsState.KIND_CABLE:
		return
	var targets: Array[Dictionary] = [
		{"id": &"junction", "key": "junction", "name": "a la caja de conexión", "pos": w.junction.approach},
		{"id": &"inverter", "key": "inverter", "name": "al inversor", "pos": w.inverter.approach},
		{"id": &"switchboard", "key": "switchboard", "name": "al tablero", "pos": w.switchboard.approach},
	]
	if w.protection.installed():
		targets.append({"id": &"protection", "key": "protection", "name": "a la protección", "pos": w.protection.approach})
	for b: BatterySlot in w.batteries:
		if b.installed():
			targets.append({"id": &"battery", "key": "battery:%d" % b.index, "name": "a la batería", "pos": b.approach})
	for t: Dictionary in targets:
		var id: StringName = t["id"]
		if id == hands.cable_from:
			continue
		out.append(WorldAction.new("connect:%s" % t["key"], "Conectar %s" % t["name"], t["pos"], _s.connect_cable.bind(id)))
