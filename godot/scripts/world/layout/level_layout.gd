class_name LevelLayout
extends RefCounted
## Posiciones de todo el mundo de un nivel a partir de `LevelDefinition` + `Purchase`
## (equivale a `LevelLayout.ts`). Área compacta (≈ 36 × 22 m):
##   oeste: campo solar (filas en +Z → −Z) con postes de fila y caja de conexión;
##   centro-norte: sala de equipos (platea + pared + alero) con consola al frente;
##   sur: pallet de paneles y punto de partida; este: depósito de cajones; noreste: ciudad.
## La cámara arranca al sur (+Z) mirando hacia −Z.
##
## Lógica pura (sin nodos): se arma con `LevelLayout.build(level, purchase)` y se puede
## testear en headless.

const MOUNT_DX: float = 2.25
const ROW_DZ: float = 3.3
const ROW0_Z: float = -3.4
const FIELD_RIGHT_X: float = -4.6

var rows: Array[RowLayout] = []
var field_label: Vector3
var junction: Vector3
var room: RoomLayout
## null si el nivel no tiene bomba.
var pump: Variant = null
var pallet: Vector3
var crates: Array[CrateSpot] = []
var depot_label: Vector3
var city: CityLayout
var spawn: Vector3
var bounds: LevelBounds


static func build(level: LevelDefinition, purchase: Purchase) -> LevelLayout:
	var ppr: int = level.panels_per_row
	var left_x: float = FIELD_RIGHT_X - (ppr - 1) * MOUNT_DX
	var rows: Array[RowLayout] = []
	for r: int in level.rows:
		var z: float = ROW0_Z - r * ROW_DZ
		var mounts: Array[Vector3] = []
		for i: int in ppr:
			mounts.append(Vector3(left_x + i * MOUNT_DX, 0.0, z))
		rows.append(RowLayout.new(r, z, mounts, Vector3(left_x - 2.8, 0.0, z), Vector3(FIELD_RIGHT_X + 1.05, 0.85, z + 0.2)))
	var last_z: float = rows[rows.size() - 1].z

	var floor_y: float = 0.16
	var batteries: Array[Vector3] = []
	for i: int in level.battery_slots:
		batteries.append(Vector3(6.5 + i * 1.15, floor_y, -6.3))

	var crates: Array[CrateSpot] = []
	var kinds: Array[StringName] = [&"protection"]
	for _i: int in purchase.batteries:
		kinds.append(&"battery")
	if purchase.kit_zonda:
		kinds.append(&"kit")
	for i: int in kinds.size():
		crates.append(CrateSpot.new(kinds[i], Vector3(13.2 + i * 1.3, 0.0, 1.4)))

	var layout: LevelLayout = LevelLayout.new()
	layout.rows = rows
	layout.field_label = Vector3((left_x + FIELD_RIGHT_X) / 2.0, 2.6, ROW0_Z - 1.6)
	layout.junction = Vector3(-2.3, 0.0, -4.4)

	var room: RoomLayout = RoomLayout.new()
	room.slab = LayoutRect.new(7.0, -4.2, 11.0, 6.0)
	room.floor_y = floor_y
	room.wall_z = -6.9
	room.inverter = Vector3(5.2, floor_y, -6.9)
	room.protection = Vector3(3.3, floor_y, -6.9)
	room.switchboard = Vector3(11.2, floor_y, -6.9)
	room.batteries = batteries
	room.console = Vector3(7.0, floor_y, -2.2)
	room.label = Vector3(7.0, 3.75, -6.4)
	layout.room = room

	layout.pump = Vector3(15.2, 0.0, -5.2) if level.has_pump else null
	layout.pallet = Vector3(-4.0, 0.0, 3.2)
	layout.crates = crates
	layout.depot_label = Vector3(13.2 + (kinds.size() - 1) * 0.65, 1.55, 1.4)
	layout.city = _city_layout(level.id)
	layout.spawn = Vector3(0.0, 0.0, 2.6)
	layout.bounds = LevelBounds.new(left_x - 4.6, 21.0, minf(-8.6, last_z - 2.6), 7.5)
	return layout


## ¿El punto (x, z) está sobre la platea de la sala? (para la altura del piso).
func on_slab(x: float, z: float, pad: float = 0.0) -> bool:
	return room.slab.contains(x, z, pad)


## Edificios [x, z, ancho, alto, fondo] de cada nivel, relativos al origen de la ciudad
## ("near": si la ciudad queda cerca del campo solar, con menos postes de línea).
static func _city_layout(id: String) -> CityLayout:
	var city_name: String = ""
	var near: bool = true
	var buildings: Array[CityBuilding] = []
	match id:
		LevelDefinition.CASA:
			city_name = "CASA QUIROGA"
			buildings = [CityBuilding.new(0, 0, 6, 3.4, 5)]
		LevelDefinition.ESCUELA:
			city_name = "ESCUELA"
			buildings = [
				CityBuilding.new(0, 0, 10, 3.6, 5), CityBuilding.new(7.5, -6, 4.5, 3.4, 4),
			]
		LevelDefinition.FINCA:
			city_name = "FINCA"
			buildings = [
				CityBuilding.new(0, 0, 6, 3.4, 5), CityBuilding.new(8, -1, 6, 4.6, 7),
			]
		LevelDefinition.PUEBLO:
			city_name = "PUEBLO"
			near = false
			buildings = [
				CityBuilding.new(0, 0, 4, 6, 4), CityBuilding.new(5, 1, 3.6, 4.5, 3.4),
				CityBuilding.new(9.5, -1, 4.2, 7, 4), CityBuilding.new(2, -6, 4.4, 5, 3.6),
				CityBuilding.new(7, -6.5, 3.6, 8, 3.6), CityBuilding.new(-4, -3, 3.4, 4.5, 3.4),
			]
		LevelDefinition.PARQUE:
			city_name = "BARRIO"
			near = false
			buildings = [
				CityBuilding.new(0, 0, 4, 9, 4), CityBuilding.new(5, 1, 3.6, 6, 3.4),
				CityBuilding.new(9.5, -1, 4.2, 12, 4), CityBuilding.new(14, 0.5, 3.4, 6.5, 3.6),
				CityBuilding.new(2, -6, 4.4, 7.5, 3.6), CityBuilding.new(7, -6.5, 3.6, 15, 3.6),
				CityBuilding.new(12, -6, 4, 7, 4), CityBuilding.new(-4, -3, 3.4, 5.5, 3.4),
				CityBuilding.new(17, -4, 3.4, 9, 3.4), CityBuilding.new(-3, -9, 3.6, 6, 3.6),
			]
		_:
			push_error("LevelLayout: ciudad desconocida para el nivel '%s'" % id)
	var origin: Vector3 = Vector3(19.5, 0.0, -17.0) if near else Vector3(22.0, 0.0, -22.0)
	var top: float = 0.0
	for b: CityBuilding in buildings:
		top = maxf(top, b.h)
	var city: CityLayout = CityLayout.new()
	city.city_name = city_name
	city.origin = origin
	city.buildings = buildings
	var poles: Array[Vector3] = []
	if near:
		poles = [Vector3(13.0, 0.0, -8.5), Vector3(16.0, 0.0, -12.8)]
	else:
		poles = [Vector3(13.0, 0.0, -8.5), Vector3(15.5, 0.0, -13.5), Vector3(18.2, 0.0, -18.5)]
	city.poles = poles
	city.label = origin + Vector3(0.0 if near else 3.0, top + 1.6, 0.0)
	return city
