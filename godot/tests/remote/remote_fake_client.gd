class_name RemoteFakeClient
extends RefCounted
## Una tablet simulada para tests. Lleva su propio seq y contadores de toques, como la página real.

var id: int
var received: Array[Dictionary] = []
var closed: bool = false
var close_reason: String = ""
var _bridge_ref: WeakRef
var _seq: int = 0
var _x: float = 0.0
var _y: float = 0.0
var _held: int = 0
var _taps: Dictionary = {"action": 0, "inspect": 0, "tool": 0, "pause": 0}


func _init(bridge: RemoteFakeBridge, p_id: int) -> void:
	_bridge_ref = weakref(bridge)
	id = p_id


func receive(m: Dictionary) -> void:
	received.append(m)


func send(msg: Dictionary) -> void:
	send_raw(JSON.stringify(msg, "", false, true))


func send_raw(data: String) -> void:
	if not closed:
		(_bridge_ref.get_ref() as RemoteFakeBridge).enqueue_msg(id, data)


func hello(p_name: String, token: String = "", device: String = "browser", v: int = RemoteProtocol.PROTOCOL_VERSION) -> void:
	var m: Dictionary = {"t": "hello", "v": v, "name": p_name, "device": device}
	if token != "":
		m["token"] = token
	send(m)


## Cambia el joystick/botones mantenidos y manda el estado (o no, si lost). Claves opcionales x, y, held.
func input(p: Dictionary = {}, lost: bool = false) -> void:
	if p.has("x"):
		_x = p["x"]
	if p.has("y"):
		_y = p["y"]
	if p.has("held"):
		_held = p["held"]
	_flush(lost)


## Toque de un botón. Con lost el mensaje "se pierde" pero el contador avanza igual.
func tap(tap_name: String, lost: bool = false) -> void:
	_taps[tap_name] = int(_taps[tap_name]) + 1
	_flush(lost)


## Reinicia los contadores (como si la página se recargara).
func reset_counters() -> void:
	_seq = 0
	_taps = {"action": 0, "inspect": 0, "tool": 0, "pause": 0}


## Misma página que reconecta: sigue con los contadores de otra conexión (seq vuelve a 0).
func continue_from(other: RemoteFakeClient) -> void:
	_taps = other._taps.duplicate()


func ping(at: float, rtt: float = -1.0) -> void:
	var m: Dictionary = {"t": "ping", "at": at}
	if rtt >= 0.0:
		m["rtt"] = rtt
	send(m)


func bye() -> void:
	send({"t": "bye"})


## Corte de red: el servidor detecta el cierre del socket.
func drop() -> void:
	if closed:
		return
	closed = true
	close_reason = "network"
	(_bridge_ref.get_ref() as RemoteFakeBridge).enqueue_close(id)


## Último mensaje recibido de ese tipo, o {} si no hay.
func last(t: String) -> Dictionary:
	for i: int in range(received.size() - 1, -1, -1):
		if received[i].get("t") == t:
			return received[i]
	return {}


func count(t: String) -> int:
	var n: int = 0
	for m: Dictionary in received:
		if m.get("t") == t:
			n += 1
	return n


func _flush(lost: bool) -> void:
	_seq += 1
	if not lost:
		send({"t": "input", "s": {"seq": _seq, "x": _x, "y": _y, "held": _held, "taps": _taps.duplicate()}})
