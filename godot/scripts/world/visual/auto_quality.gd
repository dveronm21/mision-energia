class_name AutoQuality
extends RefCounted
## Calidad automática durante la partida: si los FPS se quedan bajos varios segundos, baja un escalón
## (sombras/brillo/antialiasing con `EnvironmentRig.set_quality` y, al final, la resolución 3D, que deja
## la UI nítida). Nunca sube por encima de la calidad elegida en Ajustes (`cap`). Si sobra rendimiento
## por un buen rato, devuelve primero la resolución 3D (la calidad no vuelve a subir: evita el vaivén).
##
##   var aq := AutoQuality.new(env, viewport, 2)
##   aq.update(dt_real)   # cada cuadro de juego

const LOW_FPS: float = 26.0
const HIGH_FPS: float = 50.0
## Segundos con FPS bajos antes de bajar un escalón (y de espera después de cada cambio).
const LOW_SECS: float = 3.0
const HIGH_SECS: float = 15.0
## Al arrancar el nivel se compilan shaders y cargan texturas: esos cuadros no cuentan.
const WARMUP_SECS: float = 4.0
const SCALES: Array[float] = [1.0, 0.85, 0.7]

var quality: int
var scale_step: int = 0

var _env: EnvironmentRig
var _vp: Viewport
var _cap: int
var _low_t: float = 0.0
var _high_t: float = 0.0
var _warm_t: float = 0.0
var _fps: float = 60.0


func _init(env: EnvironmentRig, vp: Viewport, cap: int) -> void:
	_env = env
	_vp = vp
	set_cap(cap)


## Calidad elegida por el jugador: se aplica entera y se reinicia la medición.
func set_cap(cap: int) -> void:
	_cap = clampi(cap, 0, 2)
	quality = _cap
	scale_step = 0
	_low_t = 0.0
	_high_t = 0.0
	_warm_t = 0.0
	_apply()


## `dt_real`: segundos reales del cuadro. `fps`: para tests (por defecto, el del motor).
func update(dt_real: float, fps: float = -1.0) -> void:
	if dt_real <= 0.0:
		return
	_warm_t += dt_real
	if _warm_t < WARMUP_SECS:
		return
	var now: float = fps if fps > 0.0 else float(Engine.get_frames_per_second())
	# Promedio suave: un cuadro lento suelto (un toast, un sonido) no cambia nada.
	_fps = lerpf(_fps, now, clampf(dt_real * 2.0, 0.0, 1.0))
	if _fps < LOW_FPS:
		_low_t += dt_real
		_high_t = 0.0
		if _low_t >= LOW_SECS:
			_step_down()
	elif _fps > HIGH_FPS:
		_high_t += dt_real
		_low_t = 0.0
		if _high_t >= HIGH_SECS and scale_step > 0:
			scale_step -= 1
			_after_change()
	else:
		_low_t = 0.0
		_high_t = 0.0


func _step_down() -> void:
	if quality > 0:
		quality -= 1
	elif scale_step < SCALES.size() - 1:
		scale_step += 1
	else:
		_low_t = 0.0
		return
	_after_change()


func _after_change() -> void:
	_low_t = 0.0
	_high_t = 0.0
	# Después de un cambio hay que volver a medir desde cero (y dejar que se asiente).
	_warm_t = WARMUP_SECS - LOW_SECS
	_fps = (LOW_FPS + HIGH_FPS) / 2.0
	_apply()


func _apply() -> void:
	if _env != null:
		_env.set_quality(quality)
	if _vp != null:
		_vp.scaling_3d_scale = SCALES[scale_step]
