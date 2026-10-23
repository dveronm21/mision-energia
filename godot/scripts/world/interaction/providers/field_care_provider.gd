class_name FieldCareProvider
extends ActionProvider
## Manos libres: defensa ante el Zonda y limpieza en el poste de cada fila (equivale a
## `FieldCareProvider` de `interaction/Providers.ts`).

var _s: SessionPort


func _init(session: SessionPort) -> void:
	_s = session


func collect(hands: HandsState, out: Array[WorldAction]) -> void:
	if hands.kind != HandsState.KIND_FREE:
		return
	var w: PlantWorld = _s.world()
	var ph: String = _s.weather()
	var zonda_now: bool = ph == WeatherSchedule.ZONDA_WARNING or ph == WeatherSchedule.ZONDA_STORM
	for p: RowPost in w.posts:
		if w.panels_in_row(p.row) == 0:
			continue
		if zonda_now and not p.in_defense() and not w.kit_installed:
			out.append(WorldAction.new("defense:%d" % p.row, "Fila %d: defensa" % (p.row + 1), p.approach, _s.set_defense.bind(p.row)))
		if ph != WeatherSchedule.ZONDA_STORM and w.row_dirty(p.row):
			out.append(WorldAction.new("clean:%d" % p.row, "Limpiar fila %d" % (p.row + 1), p.approach, _s.clean_row.bind(p.row)))
