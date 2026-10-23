class_name CameraRig
extends Node3D
## Cámara en tercera persona que sigue al jugador (equivale a `CameraRig.ts`). Arrastrar
## con el dedo/mouse la hace girar (yaw) e inclinar (pitch); pellizco o rueda acercan.
## Se sigue con suavizado y se sacude con el Zonda.
##
## Escucha `_unhandled_input`: solo gira con toques que la UI no consumió (el joystick y los
## botones del HUD los aceptan antes), igual que en la web, donde escuchaba solo el canvas.

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
## Movimiento automático en curso (barrido de entrada, festejo) y órbita de victoria.
var _move: Tween = null
var _orbit: bool = false


func _init() -> void:
	camera = Camera3D.new()
	# Mismo encuadre que la web: `PerspectiveCamera(50, …)` de three.js es FOV vertical, igual
	# que `KEEP_HEIGHT` de Godot (el default de Godot, 75°, deja todo muy lejos).
	camera.fov = 50.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.1
	camera.far = 1000.0
	add_child(camera)


func _ready() -> void:
	set_process_unhandled_input(true)
	camera.current = true


## Coloca la cámara de golpe la próxima vez que se llame a `update` (al empezar un nivel).
func snap() -> void:
	_snapped = false


## Barrido de entrada: arranca alta, lejos y girada, y baja hasta el encuadre de juego.
## Si el jugador arrastra la cámara, el barrido se corta (manda el dedo).
func intro(sec: float = 1.9) -> void:
	_kill_move()
	var to_yaw: float = yaw
	var to_pitch: float = pitch
	var to_dist: float = dist
	yaw += 0.95
	pitch = 1.12
	dist = MAX_DIST
	snap()
	if not is_inside_tree():
		yaw = to_yaw
		pitch = to_pitch
		dist = to_dist
		return
	_move = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_move.tween_property(self, "yaw", to_yaw, sec)
	_move.tween_property(self, "pitch", to_pitch, sec)
	_move.tween_property(self, "dist", to_dist, sec)


## Golpe de cámara (abre el FOV y vuelve): marca un momento fuerte, como activar la planta.
func punch(amount: float = 6.0) -> void:
	if not is_inside_tree():
		return
	var base: float = 50.0
	var t: Tween = create_tween()
	t.tween_property(camera, "fov", base + amount, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(camera, "fov", base, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Festejo al ganar: se acerca y baja para ver al técnico, y queda orbitando despacio.
func celebrate() -> void:
	_kill_move()
	_orbit = true
	if not is_inside_tree():
		return
	_move = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_move.tween_property(self, "dist", 7.0, 1.6)
	_move.tween_property(self, "pitch", 0.34, 1.6)


## true mientras corre un movimiento automático (barrido de entrada o festejo).
func is_moving() -> bool:
	return (_move != null and _move.is_valid() and _move.is_running()) or _orbit


func _kill_move() -> void:
	if _move != null and _move.is_valid():
		_move.kill()
	_move = null


func update(dt: float, follow: Vector3) -> void:
	_time += dt
	if _orbit:
		yaw += dt * 0.32
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


func _unhandled_input(event: InputEvent) -> void:
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
	if not _orbit:
		_kill_move()
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
	if not _orbit:
		_kill_move()
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
