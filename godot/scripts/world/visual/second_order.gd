class_name SecondOrder
extends RefCounted
## Resorte de segundo orden para movimiento secundario (técnica de t3ssel8r, "Giving Personality
## to Procedural Animations using Math"): `value` sigue a la entrada con inercia.
##   f: frecuencia (Hz, qué tan rápido responde). z: amortiguación (< 1 rebota, 1 justo, > 1 lento).
##   r: respuesta inicial (0 arranca suave, 1 inmediato, > 1 se adelanta, < 0 arranca al revés).
##
##   var s := SecondOrder.new(3.0, 0.45, 0.0, pos)
##   pos_con_inercia = s.update(dt, pos)

var value: Vector3
var velocity: Vector3 = Vector3.ZERO

var _k1: float
var _k2: float
var _k3: float
var _prev_input: Vector3


func _init(f: float, z: float, r: float, start: Vector3 = Vector3.ZERO) -> void:
	_k1 = z / (PI * f)
	_k2 = 1.0 / ((TAU * f) * (TAU * f))
	_k3 = r * z / (TAU * f)
	reset(start)


## Salta a `v` sin movimiento (al aparecer o al teletransportar).
func reset(v: Vector3) -> void:
	value = v
	velocity = Vector3.ZERO
	_prev_input = v


func update(dt: float, input: Vector3) -> Vector3:
	if dt <= 0.0:
		return value
	var input_vel: Vector3 = (input - _prev_input) / dt
	_prev_input = input
	# k2 mínimo para que la integración no se vuelva inestable con cuadros largos.
	var k2: float = maxf(_k2, maxf(dt * dt / 2.0 + dt * _k1 / 2.0, dt * _k1))
	value += velocity * dt
	velocity += dt * (input + _k3 * input_vel - value - _k1 * velocity) / k2
	return value
