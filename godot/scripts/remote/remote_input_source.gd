class_name RemoteInputSource
extends RefCounted
## Entrada de un jugador que controla desde una tablet. Una instancia por asiento, estable durante
## toda la vida de RemoteHost (el juego puede guardar la referencia). Port de RemoteInputSource.ts.
##
## - Joystick: zona muerta radial + curva de potencia, conservando la dirección.
## - Toques: los contadores acumulativos del protocolo se convierten en flancos. Si se perdieron
##   mensajes y el contador saltó de 3 a 5, se entregan 2 pulsaciones en 2 frames seguidos
##   (nunca se pierde una ni se duplica).
## - Desconectado: devuelve intención neutra con connected = false.

const DEFAULT_DEAD_ZONE: float = 0.15
const DEFAULT_CURVE: float = 1.5
const DEFAULT_MAX_PENDING_TAPS: int = 4

var slot: int
## Zona muerta radial (0..0.9). Debajo de este radio el personaje no se mueve.
var dead_zone: float = DEFAULT_DEAD_ZONE
## Exponente de la curva de respuesta (1 = lineal; >1 = más precisión cerca del centro).
var curve: float = DEFAULT_CURVE
## Pulsaciones pendientes máximas por botón (evita ráfagas si llega un contador gigante).
var max_pending_taps: int = DEFAULT_MAX_PENDING_TAPS

var _x: float = 0.0
var _y: float = 0.0
var _held: int = 0
var _last_seq: int = -1
var _connected: bool = false
var _seen: Dictionary = {"action": 0, "inspect": 0, "tool": 0, "pause": 0}
var _pending: Dictionary = {"action": 0, "inspect": 0, "tool": 0, "pause": 0}


func _init(p_slot: int, p_dead_zone: float = DEFAULT_DEAD_ZONE, p_curve: float = DEFAULT_CURVE,
		p_max_pending_taps: int = DEFAULT_MAX_PENDING_TAPS) -> void:
	slot = p_slot
	dead_zone = clampf(p_dead_zone, 0.0, 0.9)
	curve = maxf(0.1, p_curve)
	max_pending_taps = maxi(1, p_max_pending_taps)


func is_connected_now() -> bool:
	return _connected


## Vector crudo recibido (sin zona muerta ni curva), útil para depurar.
func raw() -> Vector2:
	return Vector2(_x, _y)


## Llamar una vez por frame; devuelve la intención del jugador para este frame.
func read() -> PlayerIntent:
	if not _connected:
		return PlayerIntent.neutral(false)
	var v: Vector2 = shape_stick(_x, _y, dead_zone, curve)
	return PlayerIntent.new(v.x, v.y, (_held & RemoteProtocol.BTN_RUN) != 0,
		_take("action"), _take("inspect"), _take("tool"), _take("pause"), true)


# ---------- Uso interno de RemoteHost ----------

## Nueva conexión en este asiento. new_player = asiento recién ocupado (contadores desde 0);
## si es una reconexión del mismo jugador se conservan los contadores vistos.
func begin_connection(new_player: bool) -> void:
	_last_seq = -1
	_connected = true
	_x = 0.0
	_y = 0.0
	_held = 0
	if new_player:
		for k: String in RemoteProtocol.TAP_KEYS:
			_seen[k] = 0
			_pending[k] = 0


## Aplica un estado completo (ya validado). Ignora estados viejos (seq no creciente en la conexión).
func apply_state(s: Dictionary) -> bool:
	var seq: int = s["seq"]
	if not _connected or seq <= _last_seq:
		return false
	_last_seq = seq
	_x = s["x"]
	_y = s["y"]
	_held = s["held"]
	var taps: Dictionary = s["taps"]
	for k: String in RemoteProtocol.TAP_KEYS:
		var cur: int = taps[k]
		var seen: int = _seen[k]
		# Si el contador bajó, la página se reinició: cuenta desde 0.
		var diff: int = cur - seen if cur >= seen else cur
		_seen[k] = cur
		if diff > 0:
			_pending[k] = mini(max_pending_taps, int(_pending[k]) + diff)
	return true


## Conexión perdida: queda quieto y sin pulsaciones pendientes.
func disconnect_source() -> void:
	_connected = false
	_x = 0.0
	_y = 0.0
	_held = 0
	for k: String in RemoteProtocol.TAP_KEYS:
		_pending[k] = 0


func _take(k: String) -> bool:
	var n: int = _pending[k]
	if n <= 0:
		return false
	_pending[k] = n - 1
	return true


## Zona muerta radial reescalada + curva de potencia. Mantiene la dirección y satura en 1.
static func shape_stick(x: float, y: float, p_dead_zone: float, p_curve: float) -> Vector2:
	var mag: float = sqrt(x * x + y * y)
	if not (mag > p_dead_zone):
		return Vector2.ZERO
	var m: float = minf(1.0, mag)
	var t: float = pow((m - p_dead_zone) / (1.0 - p_dead_zone), p_curve)
	var k: float = t / mag
	return Vector2(roundf(x * k * 1000.0) / 1000.0, roundf(y * k * 1000.0) / 1000.0)
