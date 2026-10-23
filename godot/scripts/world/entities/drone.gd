class_name Drone
extends RefCounted
## Dron limpiador (booster). Despega del depósito, barre cada fila sucia volando sobre los
## paneles (al terminar la fila avisa `on_row_clean`) y vuelve (equivale a `Drone.ts`).

const ARRIVE_DIST: float = 0.08
const SPEED_TRAVEL: float = 6.0
const SPEED_SWEEP: float = 2.6

## Nodo visual: agregalo a la escena (arranca `visible = false`).
var visual: DroneVisual

## Callable(row: int) -> void: se llama al terminar de limpiar una fila.
var _on_row_clean: Callable
var _home: Vector3
var _legs: Array[DroneLeg] = []
var _busy: bool = false
var _time: float = 0.0


func _init(home: Vector3, on_row_clean: Callable) -> void:
	_home = home
	_on_row_clean = on_row_clean
	visual = DroneVisual.new()
	visual.position = home


func active() -> bool:
	return _busy


## `rows`: para cada fila sucia, extremos oeste/este (a la altura de los paneles), como
## pares [from, to] (`Array[Array[Vector3]]`, cada entrada con 2 elementos).
func start(rows: Array[Array]) -> void:
	if rows.is_empty():
		return
	_legs = []
	for pair: Array in rows:
		var row: int = pair[0]
		var from_pt: Vector3 = pair[1]
		var to_pt: Vector3 = pair[2]
		_legs.append(DroneLeg.new(Vector3(from_pt.x, 3.2, from_pt.z)))
		_legs.append(DroneLeg.new(Vector3(to_pt.x, 2.6, to_pt.z), row))
	_legs.append(DroneLeg.new(Vector3(_home.x, 4.0, _home.z)))
	_legs.append(DroneLeg.new(_home))
	visual.position = _home
	visual.visible = true
	_busy = true


func update(dt: float) -> void:
	_time += dt
	visual.animate(dt)
	if not _busy:
		return
	var leg: DroneLeg = _legs[0]
	var p: Vector3 = visual.position
	var d: float = p.distance_to(leg.to)
	var speed: float = SPEED_SWEEP if leg.row >= 0 else SPEED_TRAVEL
	visual.set_spraying(leg.row >= 0)
	if d < ARRIVE_DIST:
		if leg.row >= 0:
			_on_row_clean.call(leg.row)
		_legs.remove_at(0)
		if _legs.is_empty():
			_busy = false
			visual.visible = false
			visual.set_spraying(false)
		return
	var dir: Vector3 = (leg.to - p).normalized()
	p += dir * minf(d, speed * dt)
	p.y += sin(_time * 5.0) * 0.004
	visual.position = p
