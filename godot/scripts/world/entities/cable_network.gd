class_name CableNetwork
extends Node3D
## Todos los cables del mundo (equivale a `CableNetwork` de `entities/Cable.ts`). Los de potencia
## se tienden por el piso con recorrido "en L" (por pasillos); también dibuja el cable "en la
## mano" mientras el jugador lo lleva. El tubo con caída y la malla ya los resuelve `CableVisual`.

const COLOR_ORANGE: StringName = &"orange"
const COLOR_BLUE: StringName = &"blue"
const COLOR_VIOLET: StringName = &"violet"

const NAMES: Dictionary[StringName, String] = {
	&"orange": "cable de los paneles",
	&"blue": "cable de las baterías",
	&"violet": "cable del tablero",
}

## color → CableVisual ya conectado.
var connected: Dictionary[StringName, CableVisual] = {}

## Callable(x: float, z: float) -> float: altura del piso en ese punto (para apoyar el cable).
var _floor_at: Callable
var _live: CableVisual
var _live_key: String = ""


func _init(floor_at: Callable) -> void:
	name = "cables"
	_floor_at = floor_at


static func color_for(color: StringName) -> Color:
	match color:
		COLOR_ORANGE:
			return CableVisual.COLOR_PV
		COLOR_BLUE:
			return CableVisual.COLOR_BAT
		_:
			return CableVisual.COLOR_AC


## Cable con puntos explícitos (no se guarda como "conectado").
func run(points: PackedVector3Array, color: Color, radius: float = 0.035) -> CableVisual:
	var c: CableVisual = CableVisual.new()
	add_child(c)
	c.setup(points, color, radius)
	return c


## Recorrido por el piso: baja de `a`, va hasta el pasillo, lo recorre y sube a `b`.
## `corridor_z` o `corridor_x` (uno de los dos; el otro `NAN`) elige el eje del pasillo.
static func ground_route(a: Vector3, b: Vector3, floor_at: Callable, corridor_z: float, corridor_x: float) -> PackedVector3Array:
	var plan: Array[Vector2] = []
	if not is_nan(corridor_z):
		plan = [Vector2(a.x, corridor_z), Vector2(b.x, corridor_z), Vector2(b.x, b.z + 0.42)]
	else:
		plan = [Vector2(corridor_x, a.z + 0.25), Vector2(corridor_x, b.z + 0.45), Vector2(b.x, b.z + 0.45)]
	var pts: PackedVector3Array = PackedVector3Array([a])
	var prev: Vector2 = Vector2(a.x, a.z + 0.3)
	pts.append(Vector3(prev.x, float(floor_at.call(prev.x, prev.y)) + 0.05, prev.y))
	for p: Vector2 in plan:
		var length: float = prev.distance_to(p)
		var n: int = maxi(1, ceili(length / 0.6))
		for i: int in range(1, n + 1):
			var t: float = float(i) / float(n)
			var x: float = prev.x + (p.x - prev.x) * t
			var z: float = prev.y + (p.y - prev.y) * t
			pts.append(Vector3(x, float(floor_at.call(x, z)) + 0.05, z))
		prev = p
	pts.append(b)
	return pts


func connect_cable(color: StringName, points: PackedVector3Array) -> CableVisual:
	var r: CableVisual = run(points, color_for(color))
	connected[color] = r
	return r


## Ojo: no se llama `is_connected` porque ese nombre ya es un método de `Object` (señales).
func cable_connected(color: StringName) -> bool:
	return connected.has(color)


## Dibuja el cable que el jugador lleva en la mano. Se reconstruye solo cuando cambia de
## verdad (redondeando a 0,1 m), como mucho ~12 veces por segundo en la práctica.
func update_live(from: Variant, hand: Vector3, color: Variant) -> void:
	if from == null or color == null:
		if _live != null:
			_live.queue_free()
			_live = null
			_live_key = ""
		return
	var from_pt: Vector3 = from
	var color_name: StringName = color
	var key: String = "%s|%.1f|%.1f|%.1f" % [color_name, hand.x, hand.y, hand.z]
	if key == _live_key:
		return
	_live_key = key
	if _live == null:
		_live = CableVisual.new()
		add_child(_live)
	_live.setup(PackedVector3Array([from_pt, hand]), color_for(color_name), 0.04)
