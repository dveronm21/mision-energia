class_name Joystick
extends Control
## Joystick virtual táctil (equivale a `Joystick.ts`). Al ser un `Control`, Godot ya le manda
## solo los toques que caen dentro de su círculo (`_gui_input`); otro dedo arrastrando la
## cámara en el resto de la pantalla no interfiere (no hace falta el manejo de pointer
## capture de la web). `x`: −1 izquierda … 1 derecha; `y`: −1 arriba (avanzar) … 1 abajo.

const RADIUS: float = 64.0
const KNOB_RADIUS: float = 26.0
const DEAD_ZONE: float = 0.12
const COLOR_RING: Color = Color(1.0, 1.0, 1.0, 0.18)
const COLOR_RING_ACTIVE: Color = Color(1.0, 1.0, 1.0, 0.3)
const COLOR_KNOB: Color = Color("#ffb82e")

## Callable(v: Vector2) -> void: se llama cuando cambia el vector (ya con zona muerta aplicada).
var on_change: Callable

var _pointer_id: int = -1
var _knob_offset: Vector2 = Vector2.ZERO
var _vector: Vector2 = Vector2.ZERO


func _init() -> void:
	custom_minimum_size = Vector2(RADIUS, RADIUS) * 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP


func vector() -> Vector2:
	return _vector


func is_active() -> bool:
	return _pointer_id >= 0


func reset() -> void:
	_pointer_id = -1
	_set_vector(Vector2.ZERO)
	_knob_offset = Vector2.ZERO
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_on_touch(event)
	elif event is InputEventScreenDrag:
		_on_drag(event)
	elif event is InputEventMouseButton:
		_on_mouse_button(event)
	elif event is InputEventMouseMotion and _pointer_id == -2:
		_track(event.position)


func _on_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		if _pointer_id != -1:
			return
		_pointer_id = e.index
		_track(e.position)
	elif e.index == _pointer_id:
		reset()


func _on_drag(e: InputEventScreenDrag) -> void:
	if e.index == _pointer_id:
		_track(e.position)


func _on_mouse_button(e: InputEventMouseButton) -> void:
	if e.button_index != MOUSE_BUTTON_LEFT:
		return
	if e.pressed:
		if _pointer_id != -1:
			return
		_pointer_id = -2
		_track(e.position)
	elif _pointer_id == -2:
		reset()


func _track(local_pos: Vector2) -> void:
	var center: Vector2 = size / 2.0
	var d: Vector2 = local_pos - center
	var max_d: float = RADIUS - KNOB_RADIUS / 2.0
	var len: float = d.length()
	if len > max_d and len > 0.0:
		d *= max_d / len
	_knob_offset = d
	var n: Vector2 = d / max_d
	_set_vector(Vector2.ZERO if n.length() < DEAD_ZONE else n)
	queue_redraw()


func _set_vector(v: Vector2) -> void:
	var clamped: Vector2 = Vector2(clampf(v.x, -1.0, 1.0), clampf(v.y, -1.0, 1.0))
	if clamped == _vector:
		return
	_vector = clamped
	if on_change.is_valid():
		on_change.call(_vector)


func _draw() -> void:
	var center: Vector2 = size / 2.0
	draw_circle(center, RADIUS, COLOR_RING_ACTIVE if is_active() else COLOR_RING)
	draw_circle(center + _knob_offset, KNOB_RADIUS, COLOR_KNOB)
