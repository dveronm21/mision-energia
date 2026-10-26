class_name WiringProvider
extends ActionProvider
## Manos libres: conectar un cable entero de su equipo a su destino. Con un cable en la mano
## (flujo anterior, se mantiene por compatibilidad): conectarlo a otro equipo (equivale a
## `WiringProvider` de `interaction/Providers.ts`).

var _s: SessionPort


func _init(session: SessionPort) -> void:
	_s = session


func collect(hands: HandsState, out: Array[WorldAction]) -> void:
	var w: PlantWorld = _s.world()
	if hands.kind == HandsState.KIND_FREE:
		if _s.phase() != SessionPort.PHASE_BUILD:
			return
		# El cable se tiende entero de una vez hasta su destino (también se conecta solo al
		# acercarse: ver `GameSession._auto_wire`).
		if _s.can_auto_connect(CableNetwork.COLOR_ORANGE):
			out.append(WorldAction.new("cable:orange", "Conectar cable naranja", w.junction.approach,
				_s.auto_connect.bind(CableNetwork.COLOR_ORANGE)))
		if _s.can_auto_connect(CableNetwork.COLOR_BLUE):
			out.append(WorldAction.new("cable:blue", "Conectar cable azul", w.blue_source().approach,
				_s.auto_connect.bind(CableNetwork.COLOR_BLUE)))
		if _s.can_auto_connect(CableNetwork.COLOR_VIOLET):
			out.append(WorldAction.new("cable:violet", "Conectar cable violeta", w.switchboard.approach,
				_s.auto_connect.bind(CableNetwork.COLOR_VIOLET)))
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
