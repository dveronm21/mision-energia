class_name PlantWorld
extends Node3D
## Arma el mundo 3D de un nivel a partir del `LevelLayout` (entidades + colisionadores) y
## responde preguntas sobre el estado físico (paneles por fila, filas abiertas, etc.).
## Equivale a `PlantWorld.ts`. A diferencia de la web no hace falta un `update(dt)` manual
## para el brillo de los paneles ni el flujo de energía: `MountVisual`/`EnergyFlowVisual` ya
## se animan solos (cada uno con su propio `_process`); acá solo se actualiza el dron.

const WIRE_ROW: Color = Color("#30383b")
const WIRE_PROTECTION: Color = Color("#f28c28")
const WIRE_PUMP: Color = Color("#55605d")

var level: LevelDefinition
var layout: LevelLayout
var colliders: Colliders

var mounts: Array[Mount] = []
## mounts agrupados por fila (mismo orden que layout.rows).
var rows: Array[Array] = []
var posts: Array[RowPost] = []
var pallet: Pallet
var pickups: Array[Pickup] = []
var junction: JunctionBox
var inverter: Inverter
var protection: ProtectionSlot
var batteries: Array[BatterySlot] = []
var switchboard: Switchboard
var console: ControlConsole
## null si el nivel no tiene bomba.
var pump: Pump
var cables: CableNetwork
## Un cable por fila hacia la caja de conexión, o null hasta que `ensure_row_wire()` lo crea.
var row_wires: Array[Variant] = []
var protection_link: CableVisual
var pump_wire: CableVisual
var city: City
var drone: Drone
var kit_installed: bool = false

var _pallet_label: LabelVisual
var _room_light: OmniLight3D
var _lamp_mat: StandardMaterial3D


func _init(p_level: LevelDefinition, purchase: Purchase, on_row_clean_by_drone: Callable) -> void:
	name = "plant-world"
	level = p_level
	_on_row_clean_by_drone = on_row_clean_by_drone
	layout = LevelLayout.build(level, purchase)
	colliders = Colliders.new(layout.bounds.min_x, layout.bounds.max_x, layout.bounds.min_z, layout.bounds.max_z)

	_build_field()
	_build_junction()
	_build_room()
	_build_pump()
	_build_depot(purchase)
	_build_cables_and_city()


func _add(n: Node3D) -> Node3D:
	add_child(n)
	return n


func _label(text: String, pos: Vector3, scale: float = 0.6, bg: Color = LabelVisual.BG_DEFAULT) -> LabelVisual:
	var l: LabelVisual = LabelVisual.new(text, scale, bg)
	l.position = pos
	_add(l)
	return l


# ------------------------------------------------------------------------------------- campo solar

func _build_field() -> void:
	for row: RowLayout in layout.rows:
		var list: Array[Mount] = []
		for i: int in row.mounts.size():
			var p: Vector3 = row.mounts[i]
			var m: Mount = Mount.new(row.index, i, p)
			_add(m.visual)
			colliders.add(p.x, p.z, 1.0, 0.55)
			list.append(m)
			mounts.append(m)
		rows.append(list)
		var post: RowPost = RowPost.new(row.index, row.post)
		_add(post.visual)
		colliders.add(row.post.x, row.post.z, 0.22, 0.22)
		posts.append(post)
	_label("CAMPO SOLAR", layout.field_label, 0.75)
	for _row: RowLayout in layout.rows:
		row_wires.append(null)


func _build_junction() -> void:
	junction = JunctionBox.new(layout.junction)
	_add(junction.visual)
	colliders.add(layout.junction.x, layout.junction.z, 0.3, 0.25)


# --------------------------------------------------------------------------------- sala de equipos

func _build_room() -> void:
	var r: RoomLayout = layout.room
	var slab: Node3D = ModelLibrary.instantiate(&"slab")
	slab.position = Vector3(r.slab.x, 0.0, r.slab.z)
	_add(slab)
	var wall: Node3D = ModelLibrary.instantiate(&"wall")
	wall.position = Vector3(r.slab.x, r.floor_y, r.wall_z)
	_add(wall)
	var canopy: Node3D = ModelLibrary.instantiate(&"canopy")
	canopy.position = Vector3(r.slab.x, r.floor_y, r.wall_z + 0.8)
	_add(canopy)
	colliders.add(r.slab.x, r.wall_z - 0.15, r.slab.w / 2.0, 0.45)
	_label("SALA DE EQUIPOS", r.label, 0.7)

	# Luz de la sala: se enciende de noche con la energía de las baterías (siempre presente
	# para no recompilar shaders).
	_room_light = OmniLight3D.new()
	_room_light.light_color = Color("#ffd9a0")
	_room_light.light_energy = 0.0
	_room_light.omni_range = 13.0
	_room_light.omni_attenuation = 1.2
	_room_light.position = Vector3(r.slab.x, r.floor_y + 2.9, r.wall_z + 1.6)
	_add(_room_light)
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp_mat.albedo_color = Color("#4a4740")
	var lamp: MeshInstance3D = MeshInstance3D.new()
	var lamp_mesh: BoxMesh = BoxMesh.new()
	lamp_mesh.size = Vector3(5.0, 0.05, 0.12)
	lamp.mesh = lamp_mesh
	lamp.material_override = _lamp_mat
	lamp.position = Vector3(r.slab.x, r.floor_y + 3.28, r.wall_z + 1.0)
	_add(lamp)

	inverter = Inverter.new(r.inverter)
	_add(inverter.visual)
	protection = ProtectionSlot.new(r.protection)
	_add(protection)
	for i: int in r.batteries.size():
		var b: BatterySlot = BatterySlot.new(i, r.batteries[i])
		_add(b)
		batteries.append(b)
	switchboard = Switchboard.new(r.switchboard)
	_add(switchboard.visual)
	colliders.add(r.inverter.x, r.wall_z + 0.2, 0.6, 0.25)
	colliders.add(r.switchboard.x, r.wall_z + 0.15, 0.5, 0.2)
	console = ControlConsole.new(r.console)
	_add(console.visual)
	colliders.add(r.console.x, r.console.z, 0.45, 0.4)
	_label("ACTIVAR PLANTA", Vector3(r.console.x, 1.75, r.console.z), 0.55, LabelVisual.BG_ACCENT)


func _build_pump() -> void:
	if layout.pump == null:
		return
	var pos: Vector3 = layout.pump
	pump = Pump.new(pos)
	_add(pump.visual)
	colliders.add(pos.x - 0.35, pos.z + 0.75, 0.8, 1.3)
	_label("BOMBA DE RIEGO", Vector3(pos.x, 1.9, pos.z), 0.45)


# ------------------------------------------------------------------------------- depósito y pallet

func _build_depot(purchase: Purchase) -> void:
	pallet = Pallet.new(layout.pallet, purchase.panels, level.events.loose_connector)
	_add(pallet.visual)
	colliders.add(layout.pallet.x, layout.pallet.z, 1.1, 0.66)
	_pallet_label = _label("PANELES", Vector3(layout.pallet.x, 1.3, layout.pallet.z), 0.5)
	for c: CrateSpot in layout.crates:
		add_pickup(c.kind, c.pos, false, fmod(c.pos.x * 0.37, 0.3) - 0.15)
	_label("DEPÓSITO", layout.depot_label, 0.6)


func add_pickup(kind: StringName, pos: Vector3, faulty: bool, yaw: float = 0.0) -> Pickup:
	var p: Pickup = Pickup.new(kind, pos, faulty, colliders, yaw)
	add_child(p)
	pickups.append(p)
	return p


func remove_pickup(p: Pickup) -> void:
	var i: int = pickups.find(p)
	if i >= 0:
		pickups.remove_at(i)
	p.dispose()


# --------------------------------------------------------------------------- cables, ciudad, dron

func _build_cables_and_city() -> void:
	cables = CableNetwork.new(floor_at)
	_add(cables)
	city = City.new(layout.city, switchboard.line_out, cables)
	_add(city)
	if pump != null:
		var pts: PackedVector3Array = CableNetwork.ground_route(switchboard.terminal, pump.terminal, floor_at, -4.6, NAN)
		pump_wire = cables.run(pts, WIRE_PUMP, 0.03)
	var first_crate: Vector3 = layout.crates[0].pos
	drone = Drone.new(Vector3(first_crate.x - 1.2, 0.3, first_crate.z + 2.4), _on_row_clean_relay)
	_add(drone.visual)


var _on_row_clean_by_drone: Callable


func _on_row_clean_relay(row: int) -> void:
	_on_row_clean_by_drone.call(row)


## Altura del piso (la platea de la sala está 16 cm arriba).
func floor_at(x: float, z: float) -> float:
	return layout.room.floor_y if layout.on_slab(x, z, -0.05) else 0.0


# -------------------------------------------------------------------------- consultas de estado físico

func panels_in_row(r: int) -> int:
	var count: int = 0
	for m: Mount in (rows[r] as Array[Mount]):
		if m.filled():
			count += 1
	return count


func panels_installed() -> int:
	var count: int = 0
	for m: Mount in mounts:
		if m.filled():
			count += 1
	return count


func row_open(r: int) -> bool:
	for m: Mount in (rows[r] as Array[Mount]):
		if m.filled() and m.faulty:
			return true
	return false


func any_faulty() -> bool:
	for m: Mount in mounts:
		if m.filled() and m.faulty:
			return true
	return false


func batteries_installed() -> int:
	var count: int = 0
	for b: BatterySlot in batteries:
		if b.installed():
			count += 1
	return count


func row_dirty(r: int) -> bool:
	for m: Mount in (rows[r] as Array[Mount]):
		if m.is_dirty():
			return true
	return false


## Crea (una vez) el cable de la fila hasta la caja de conexión.
func ensure_row_wire(r: int) -> void:
	if row_wires[r] != null:
		return
	var row: RowLayout = layout.rows[r]
	var to: Vector3 = junction.terminal + Vector3(-0.12 + r * 0.06, 0.0, 0.0)
	var pts: PackedVector3Array = CableNetwork.ground_route(row.wire_start, to, floor_at, NAN, -3.0 + r * 0.12)
	row_wires[r] = cables.run(pts, WIRE_ROW, 0.025)


## Cable fijo protección → inversor (al instalar la protección).
func link_protection() -> void:
	if protection_link != null:
		return
	var pts: PackedVector3Array = CableNetwork.ground_route(protection.terminal, inverter.terminal_for(&"pv"), floor_at, layout.room.wall_z + 0.42, NAN)
	protection_link = cables.run(pts, WIRE_PROTECTION, 0.03)


## Luz de la sala de equipos (0..1).
func set_room_light(v: float) -> void:
	_room_light.light_energy = v * 9.0
	_lamp_mat.albedo_color = Color(0.29 + v * 2.2, 0.28 + v * 1.9, 0.25 + v * 1.4)


## `drone_dt`: tiempo del dron (acompaña la velocidad del reloj simulado; por defecto, tiempo real).
func update(dt: float, drone_dt: float = -1.0) -> void:
	drone.update(dt if drone_dt < 0.0 else drone_dt)
	_pallet_label.visible = pallet.remaining() > 0


func dispose() -> void:
	if get_parent() != null:
		get_parent().remove_child(self)
	queue_free()
