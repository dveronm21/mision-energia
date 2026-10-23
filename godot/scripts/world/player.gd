class_name Player
extends Node3D
## El técnico que controla el jugador (equivale a `Player.ts`). Movimiento relativo a la
## cámara, giro suave, colisiones (`Colliders`), altura del piso y animación del rig visual
## (`WorkerVisual`). Nodo porque necesita posición/rotación en el árbol; el resto de la
## lógica es la misma que la web.

const RADIUS: float = 0.38
const SPEED: float = 5.0

## Rig visual (hijo): ya trae mallas, animación de piernas/brazos y las poses.
var rig: WorkerVisual
## Multiplicador de velocidad (carga pesada, viento Zonda).
var speed_factor: float = 1.0
var pose: WorkerVisual.Pose = WorkerVisual.Pose.IDLE

var _colliders: Colliders
## Callable(x: float, z: float) -> float: altura del piso en ese punto.
var _floor_at: Callable
var _heading: float = PI
var _speed01: float = 0.0


func _init(p_rig: WorkerVisual, colliders: Colliders, floor_at: Callable, spawn: Vector3 = Vector3.ZERO) -> void:
	rig = p_rig
	_colliders = colliders
	_floor_at = floor_at
	add_child(rig)
	position = spawn
	rotation.y = _heading


## Vector "adelante" del personaje en XZ.
func forward() -> Vector3:
	return Vector3(sin(_heading), 0.0, cos(_heading))


## `mx`, `my` en −1..1 (my −1 = avanzar), `cam_yaw` = ángulo de la cámara alrededor del jugador.
func update(dt: float, mx: float, my: float, cam_yaw: float) -> void:
	var mag: float = minf(1.0, sqrt(mx * mx + my * my))
	if mag > 0.08:
		var fx: float = -sin(cam_yaw)
		var fz: float = -cos(cam_yaw)
		var rx: float = cos(cam_yaw)
		var rz: float = -sin(cam_yaw)
		var dx: float = rx * mx - fx * my
		var dz: float = rz * mx - fz * my
		var l: float = sqrt(dx * dx + dz * dz)
		if l == 0.0:
			l = 1.0
		dx /= l
		dz /= l
		var v: float = SPEED * mag * speed_factor
		position.x += dx * v * dt
		position.z += dz * v * dt
		var target: float = atan2(dx, dz)
		var d: float = wrapf(target - _heading, -PI, PI)
		_heading += d * minf(1.0, dt * 12.0)
		rotation.y = _heading
	var resolved: Vector2 = _colliders.resolve(Vector2(position.x, position.z), RADIUS)
	position.x = resolved.x
	position.z = resolved.y
	var floor_y: float = _floor_at.call(position.x, position.z)
	position.y += (floor_y - position.y) * minf(1.0, dt * 14.0)
	_speed01 += ((mag if mag > 0.08 else 0.0) - _speed01) * minf(1.0, dt * 10.0)
	rig.animate(dt, _speed01, pose)


## Teletransporte (debug y reinicio de nivel).
func teleport(x: float, z: float, face_to: Variant = null) -> void:
	position.x = x
	position.z = z
	var resolved: Vector2 = _colliders.resolve(Vector2(position.x, position.z), RADIUS)
	position.x = resolved.x
	position.z = resolved.y
	position.y = _floor_at.call(position.x, position.z)
	if face_to != null:
		var f: Vector3 = face_to
		_heading = atan2(f.x - position.x, f.z - position.z)
		rotation.y = _heading
