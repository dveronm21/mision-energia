class_name MeterProvider
extends ActionProvider
## Con el multímetro en la mano: medir filas, medir panel, reconectar conector (equivale a
## `MeterProvider` de `interaction/Providers.ts`).

var _s: SessionPort


func _init(session: SessionPort) -> void:
	_s = session


func collect(hands: HandsState, out: Array[WorldAction]) -> void:
	if hands.kind != HandsState.KIND_METER:
		return
	var w: PlantWorld = _s.world()
	out.append(WorldAction.new("measure:rows", "Medir filas", w.junction.approach, _s.measure_rows))
	for m: Mount in w.mounts:
		if not m.filled():
			continue
		if m.faulty and m.fault_found:
			out.append(WorldAction.new("repair:%d:%d" % [m.row, m.index], "Reconectar conector", m.approach, _s.repair_panel.bind(m)))
		else:
			out.append(WorldAction.new("measure:%d:%d" % [m.row, m.index], "Medir panel", m.approach, _s.measure_panel.bind(m)))
