class_name Inspectables
extends InspectProvider
## Fichas educativas de "Revisar" con datos en vivo de la planta (equivale a
## `Inspectables.ts`).

const PANEL_VOC: int = 41

var _s: LiveSource


func _init(source: LiveSource) -> void:
	_s = source


func inspectables(out: Array[InspectEntry]) -> void:
	var w: PlantWorld = _s.world()
	var lv: LevelDefinition = _s.level()
	var snap: Callable = func() -> SimSnapshot: return _s.snapshot() if _s.is_running() else null

	for m: Mount in w.mounts:
		var title: String = "Panel solar · fila %d" % (m.row + 1) if m.filled() else "Estructura vacía"
		var body: String = "Convierte la luz del sol en corriente continua. Los paneles de una fila van en serie, así que un conector flojo apaga toda la fila." if m.filled() \
			else "Acá va un panel solar. La estructura está inclinada para aprovechar mejor el sol de la mañana a la tarde."
		var mount: Mount = m
		out.append(InspectEntry.new("mount:%d:%d" % [m.row, m.index], m.approach, title, body,
			func() -> Variant: return ("Con polvo: rinde 35% menos" if mount.is_dirty() else null) if mount.filled() else null))

	out.append(InspectEntry.new("pallet", w.pallet.approach, "Pallet de paneles",
		"Los paneles que compraste en el taller. Llevalos de a uno hasta las estructuras del campo solar.",
		func() -> String: return "Quedan %d" % w.pallet.remaining()))

	for i: int in w.pickups.size():
		var p: Pickup = w.pickups[i]
		var t: Array[String] = _pickup_text(p.kind, lv)
		out.append(InspectEntry.new("pickup:%d" % i, p.approach, t[0], t[1]))

	out.append(InspectEntry.new("junction", w.junction.approach, "Caja de conexión del campo",
		"Junta la energía de todas las filas en un circuito de corriente continua. Con el multímetro podés revisar cada fila.",
		func() -> String:
			var s: SimSnapshot = snap.call()
			return ("Llega energía del campo solar" if s.gen_kw > 0.05 else "Sin energía del campo solar") if s != null else "%d paneles conectados" % w.panels_installed()))

	for p: RowPost in w.posts:
		var post: RowPost = p
		out.append(InspectEntry.new("post:%d" % p.row, p.approach, "Poste de la fila %d" % (p.row + 1),
			"Desde acá se baja la fila a posición horizontal cuando sopla el Zonda y se limpian los paneles cuando pasa el viento.",
			func() -> Variant:
				if w.kit_installed:
					return "Trabas anti-Zonda instaladas"
				if post.in_defense():
					return "En posición de defensa"
				if w.row_dirty(post.row):
					return "Paneles con polvo"
				return null))

	out.append(InspectEntry.new("protection", w.protection.approach,
		"Protección de CC" if w.protection.installed() else "Lugar de la protección",
		"Fusible y seccionador: si hay un cortocircuito abren el circuito y protegen al inversor. En una instalación real la hace un electricista matriculado."))

	out.append(InspectEntry.new("inverter", w.inverter.approach, "Inversor híbrido",
		"Convierte la corriente continua de paneles y baterías en corriente alterna para la ciudad, y decide cuándo cargar o descargar las baterías.",
		func() -> String:
			var s: SimSnapshot = snap.call()
			if s == null:
				return "En espera"
			if s.net_kw > 0.05:
				return "Cargando baterías con lo que sobra"
			if s.net_kw < -0.05:
				return "Usando energía de las baterías"
			return "En equilibrio"))

	for b: BatterySlot in w.batteries:
		var battery: BatterySlot = b
		out.append(InspectEntry.new("battery:%d" % b.index, b.approach,
			"Batería de litio" if b.installed() else "Base para batería",
			"Guarda la energía que sobra de día para usarla de noche." if b.installed() else "Lugar marcado para una batería.",
			func() -> Variant:
				var s: SimSnapshot = snap.call()
				return "Carga del banco: %d%%" % roundi(s.soc_pct * 100.0) if (battery.installed() and s != null) else null))

	out.append(InspectEntry.new("switchboard", w.switchboard.approach, "Tablero eléctrico",
		"Recibe la corriente alterna del inversor y la reparte hacia la ciudad, con térmicas y disyuntor para cada circuito.",
		func() -> Variant:
			var s: SimSnapshot = snap.call()
			return ("Repartiendo energía a la ciudad" if not s.blackout else "Sin energía: la ciudad está a oscuras") if s != null else null))

	out.append(InspectEntry.new("console", w.console.approach, "Consola de control",
		"Cuando todo esté instalado y conectado, activá la planta acá. Necesitás al menos %d paneles, la protección, las baterías y los tres cables." % lv.min_panels))

	if w.pump != null:
		out.append(InspectEntry.new("pump", w.pump.approach, "Bomba de riego solar",
			"Saca agua del pozo para regar las vides. Consume mucho al mediodía, justo cuando los paneles generan más.",
			func() -> Variant:
				var s: SimSnapshot = snap.call()
				if s == null:
					return null
				var h: float = fmod(s.hour, 24.0)
				return "Regando" if (h >= 11.0 and h < 16.0) else "Detenida"))


static func _pickup_text(kind: StringName, lv: LevelDefinition) -> Array[String]:
	match kind:
		&"battery":
			return ["Batería embalada", "Batería de litio. Va en una de las bases de la sala de equipos."]
		&"protection":
			return ["Protección embalada", "Fusible y seccionador de corriente continua. Va en la pared, a la izquierda del inversor."]
		&"kit":
			return ["Kit anti-Zonda", "Trabas para las estructuras. Instalalo en el poste amarillo de cualquier fila del campo solar."]
		_:
			return ["Panel solar suelto", "Llevalo a una estructura vacía del campo solar."]
