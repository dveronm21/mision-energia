class_name CameraRig
extends Node3D
## Cámara en tercera persona que sigue al jugador (equivale a `CameraRig.ts`). Arrastrar
## con el dedo/mouse la hace girar (yaw) e inclinar (pitch); pellizco o rueda acercan.
## Se sigue con suavizado y se sacude con el Zonda.
##
## Para que reciba el input hay que agregarlo al árbol con `set_process_input(true)`
## (ya lo hace `_ready`) y que el `Control`/`Viewport` no le robe el evento antes.

const MIN_PITCH: float = 0.22
const MAX_PITCH: float = 1.25
const MIN_DIST: float = 6.0
const MAX_DIST: float = 20.0
const DRAG_YAW: float = 0.006
const DRAG_PITCH: float = 0.004
const WHEEL_STEP: float = 0.6

var yaw: float = 0.18
var pitch: float = 0.6
var dist: float = 11.5
## 0..1: cuánto sacudir (viento Zonda).
var shake: float = 0.0

var camera: Camera3D

var _pointers: Dictionary[int, Vector2] = {}
var _pinch: float = 0.0
var _time: float = 0.0
var _snapped: bool = false
var _target: Vector3 = Vector3.ZERO
var _desired: Vector3 = Vector3.ZERO


func _init() -> void:
	camera = Camera3D.new()
	camera.near = 0.1
	camera.far = 1000.0
	add_child(camera)


func _ready() -> void:
	set_process_input(true)
	camera.current = true


## Coloca la cámara de golpe la próxima vez que se llame a `update` (al empezar un nivel).
func snap() -> void:
	_snapped = false


func update(dt: float, follow: Vector3) -> void:
	_time += dt
	_target = Vector3(follow.x, follow.y + 1.2, follow.z)
	var cp: float = cos(pitch)
	_desired = Vector3(sin(yaw) * cp, sin(pitch), cos(yaw) * cp) * dist + _target
	if shake > 0.0:
		_desired.x += sin(_time * 27.0) * 0.09 * shake
		_desired.y += sin(_time * 31.0 + 1.0) * 0.05 * shake
	if not _snapped:
		camera.position = _desired
		_snapped = true
	else:
		camera.position = camera.position.lerp(_desired, minf(1.0, dt * 7.0))
	camera.look_at(_target)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		_on_mouse_motion(event)


func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		_pointers[e.index] = e.position
		if _pointers.size() == 2:
			_pinch = _pinch_dist()
	else:
		_pointers.erase(e.index)
		if _pointers.size() < 2:
			_pinch = 0.0


func _on_drag(e: InputEventScreenDrag) -> void:
	if not _pointers.has(e.index):
		return
	_pointers[e.index] = e.position
	if _pointers.size() >= 2:
		var d: float = _pinch_dist()
		if _pinch > 0.0:
			dist = clampf(dist * (_pinch / d), MIN_DIST, MAX_DIST)
		_pinch = d
		return
	yaw -= e.relative.x * DRAG_YAW
	pitch = clampf(pitch + e.relative.y * DRAG_PITCH, MIN_PITCH, MAX_PITCH)


func _on_mouse_button(e: InputEventMouseButton) -> void:
	if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
		dist = clampf(dist - WHEEL_STEP, MIN_DIST, MAX_DIST)
	elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
		dist = clampf(dist + WHEEL_STEP, MIN_DIST, MAX_DIST)
	elif e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_pointers[-1] = e.position
		else:
			_pointers.erase(-1)


func _on_mouse_motion(e: InputEventMouseMotion) -> void:
	if not _pointers.has(-1):
		return
	yaw -= e.relative.x * DRAG_YAW
	pitch = clampf(pitch + e.relative.y * DRAG_PITCH, MIN_PITCH, MAX_PITCH)
	_pointers[-1] = e.position


func _pinch_dist() -> float:
	var pts: Array = _pointers.values()
	if pts.size() < 2:
		return 1.0
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[1]
	return maxf(1.0, a.distance_to(b))
