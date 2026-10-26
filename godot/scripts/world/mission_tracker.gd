class_name MissionTracker
extends RefCounted
## Arma la lista de objetivos del panel de misión según el estado de la partida y calcula el
## "próximo paso" para la Pista (booster "Pista"). Equivale a `MissionTracker.ts`.

var _f: MissionFacts


func _init(facts: MissionFacts) -> void:
	_f = facts


func _items() -> Array[MissionItem]:
	var lv: LevelDefinition = _f.level()
	var buy: Purchase = _f.purchase()
	var w: PlantWorld = _f.world()
	var phase: StringName = _f.phase()
	var weather: String = _f.weather()
	var running: bool = phase != SessionPort.PHASE_BUILD
	var n: int = w.panels_installed()
	var nb: int = w.batteries_installed()
	var c: ConnectorFacts = _f.connector()

	var items: Array[MissionItem] = [
		MissionItem.new(&"panels", "Instalá los paneles (%d/%d)" % [n, buy.panels], n >= buy.panels or (running and n >= lv.min_panels)),
		MissionItem.new(&"protection", "Instalá la protección junto al inversor", w.protection.installed()),
		MissionItem.new(&"batteries", "Instalá %s (%d/%d)" % ["la batería" if buy.batteries == 1 else "las baterías", nb, buy.batteries], nb >= buy.batteries),
	]
	if buy.kit_zonda:
		items.append(MissionItem.new(&"kit", "Poné las trabas anti-Zonda en un poste de fila", w.kit_installed))
	items.append(MissionItem.new(&"orange", "Conectá paneles → protección (naranja)", w.cables.cable_connected(CableNetwork.COLOR_ORANGE)))
	items.append(MissionItem.new(&"blue", "Conectá baterías → inversor (azul)", w.cables.cable_connected(CableNetwork.COLOR_BLUE)))
	items.append(MissionItem.new(&"violet", "Conectá tablero → inversor (violeta)", w.cables.cable_connected(CableNetwork.COLOR_VIOLET)))

	if lv.events.loose_connector:
		var text: String
		if c.fixed:
			text = "Reparaste el conector flojo"
		elif c.row_found:
			text = "Medí panel por panel la fila que falla y reconectá"
		else:
			text = "Medí las filas con el multímetro en la caja de conexión"
		items.append(MissionItem.new(&"connector", text, c.fixed, c.row_found and not c.fixed))

	items.append(MissionItem.new(&"activate", "Activá la planta en la consola", running))

	if running:
		for p: Pickup in w.pickups:
			if p.kind == &"panel":
				items.append(MissionItem.new(&"lost", "Volvé a colocar el panel que voló", false, true))
				break

	if running and weather != WeatherSchedule.CALM:
		var dirty: bool = false
		for r: int in w.rows.size():
			if w.row_dirty(r):
				dirty = true
				break
		if weather == WeatherSchedule.ZONDA_OVER:
			items.append(MissionItem.new(&"zonda", "Limpiá el polvo en el poste de cada fila" if dirty else "Pasó el Zonda: paneles limpios", not dirty, dirty))
		else:
			var all_defended: bool = true
			for p: RowPost in w.posts:
				if not (p.in_defense() or w.panels_in_row(p.row) == 0):
					all_defended = false
					break
			items.append(MissionItem.new(&"zonda",
				"Zonda: las trabas sostienen los paneles" if w.kit_installed else "Zonda: poné cada fila en defensa (poste de la fila)",
				w.kit_installed or all_defended, not w.kit_installed))

	items.append(MissionItem.new(&"night", "Mantené la ciudad con luz toda la noche", phase == SessionPort.PHASE_FINISHED and _f.won()))
	return items


func objectives() -> Array[MissionObjective]:
	var now_set: bool = false
	var out: Array[MissionObjective] = []
	for it: MissionItem in _items():
		var state: StringName
		if it.ok:
			state = MissionObjective.STATE_OK
		elif it.alert:
			state = MissionObjective.STATE_ALERT
		elif not now_set:
			state = MissionObjective.STATE_NOW
			now_set = true
		else:
			state = MissionObjective.STATE_TODO
		out.append(MissionObjective.new(it.step, it.text, state))
	return out


## Dónde está el próximo paso (o null).
func hint_target() -> Variant:
	var w: PlantWorld = _f.world()
	var hands: HandsController = _f.hands()
	var h: HandsState = hands.hands()

	if h.kind == HandsState.KIND_CARRY:
		match h.item_kind:
			&"panel":
				return _first_unfilled_mount_approach(w)
			&"protection":
				return w.protection.approach
			&"battery":
				return _first_uninstalled_battery_approach(w)
			&"kit":
				return w.posts[0].approach if not w.posts.is_empty() else null
	if h.kind == HandsState.KIND_CABLE:
		return w.protection.approach if h.cable_color == CableNetwork.COLOR_ORANGE else w.inverter.approach

	var next: MissionItem = null
	for it: MissionItem in _items():
		if not it.ok and (it.alert or it.step != &"night"):
			next = it
			break
	if next == null:
		return null

	match next.step:
		&"panels":
			var crate: Variant = _crate_approach(w, &"panel")
			return crate if crate != null else (w.pallet.approach if w.pallet.remaining() > 0 else null)
		&"lost":
			return _crate_approach(w, &"panel")
		&"protection":
			return _crate_approach(w, &"protection")
		&"batteries":
			return _crate_approach(w, &"battery")
		&"kit":
			return _crate_approach(w, &"kit")
		&"orange":
			return w.junction.approach
		&"blue":
			return _first_installed_battery_approach(w)
		&"violet":
			return w.switchboard.approach
		&"connector":
			if not _f.connector().row_found:
				return w.junction.approach
			for m: Mount in w.mounts:
				if m.filled() and m.faulty:
					return m.approach
			return null
		&"activate":
			return w.console.approach
		&"zonda":
			var zonda_over: bool = _f.weather() == WeatherSchedule.ZONDA_OVER
			for p: RowPost in w.posts:
				var wants: bool = w.row_dirty(p.row) if zonda_over else (not p.in_defense() and w.panels_in_row(p.row) > 0)
				if wants:
					return p.approach
			return null
		_:
			return null


static func _first_unfilled_mount_approach(w: PlantWorld) -> Variant:
	for m: Mount in w.mounts:
		if not m.filled():
			return m.approach
	return null


static func _first_uninstalled_battery_approach(w: PlantWorld) -> Variant:
	for b: BatterySlot in w.batteries:
		if not b.installed():
			return b.approach
	return null


static func _first_installed_battery_approach(w: PlantWorld) -> Variant:
	for b: BatterySlot in w.batteries:
		if b.installed():
			return b.approach
	return null


static func _crate_approach(w: PlantWorld, kind: StringName) -> Variant:
	for p: Pickup in w.pickups:
		if p.kind == kind:
			return p.approach
	return null
