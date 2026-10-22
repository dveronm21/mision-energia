class_name RemoteHost
extends RefCounted
## Lado tele del control remoto. Port fiel de app/src/remote/RemoteHost.ts.
##
## Lee bridge.poll() una vez por frame (update()), valida los mensajes, asigna asientos 0/1,
## reserva el asiento por token durante RESUME_WINDOW_MS, responde ping, detecta timeouts y
## expone un RemoteInputSource por asiento. Sin puente (bridge == null) queda inactivo y todo es no-op.
##
## Uso:
##   var server := RemoteServer.new(); add_child(server); server.start()
##   var host := RemoteHost.new(server.bridge())
##   func _process(_d): host.update(); var i := host.input(0).read()

## Un jugador nuevo ocupó un asiento.
signal joined(player: RemotePlayer)
## Se liberó un asiento. reason: "bye" | "kick" | "expired" | "released".
signal left(slot: int, reason: String)
## Un jugador recuperó su asiento con el mismo token.
signal resumed(player: RemotePlayer)
## Se cayó la conexión pero el asiento queda reservado. reason: "closed" | "timeout".
signal dropped(slot: int, reason: String)

## Intervalo mínimo entre dos ctx a la misma tablet (a lo sumo 10 por segundo).
const CTX_MIN_INTERVAL_MS: float = 100.0
## Una conexión que no manda hello en este tiempo se cierra.
const HELLO_TIMEOUT_MS: float = 5000.0
## Conexiones abiertas sin asiento a la vez (protección ante abusos).
const MAX_PENDING_CONNS: int = 8
## Límite de mensajes por conexión: ráfaga y recarga por segundo (token bucket).
const RATE_BURST: float = 120.0
const RATE_PER_SEC: float = 60.0
const DEFAULT_TV_NAME: String = "Misión Energía TV"
const SLOTS: Array[int] = [0, 1]


## Conexión WebSocket conocida por el host.
class Conn:
	var id: int
	var opened_at: float
	var slot: int = -1
	var bucket: float
	var bucket_at: float

	func _init(p_id: int, now: float) -> void:
		id = p_id
		opened_at = now
		bucket = RATE_BURST
		bucket_at = now


## Asiento ocupado (conectado o reservado).
class Seat:
	var token: String
	var name: String
	var device: String
	var conn_id: int = -1
	var last_seen_at: float
	var dropped_at: float = -1.0
	var latency_ms: int = -1


## Contexto deseado/enviado de un asiento.
class SlotCtx:
	var wanted: Dictionary
	var wanted_json: String
	var sent_json: String = ""
	var sent_at: float = -INF

	func _init() -> void:
		wanted = RemoteProtocol.default_context()
		wanted_json = RemoteProtocol.to_json(wanted)


var active: bool:
	get:
		return _bridge != null

var _bridge: RemoteBridge
var _now: Callable
var _make_token: Callable
var _conns: Dictionary = {}          # int → Conn
var _seats: Array[Seat] = [null, null]
var _inputs: Array[RemoteInputSource] = []
var _ctx: Array[SlotCtx] = []


## bridge: transporte (null = inactivo). now: () -> float ms (por defecto el reloj del motor).
## make_token: () -> String (por defecto 12 bytes aleatorios en hex).
func _init(bridge: RemoteBridge, now: Callable = Callable(), make_token: Callable = Callable(),
		dead_zone: float = RemoteInputSource.DEFAULT_DEAD_ZONE, curve: float = RemoteInputSource.DEFAULT_CURVE,
		max_pending_taps: int = RemoteInputSource.DEFAULT_MAX_PENDING_TAPS) -> void:
	_bridge = bridge
	_now = now if now.is_valid() else func() -> float: return Time.get_ticks_usec() / 1000.0
	_make_token = make_token if make_token.is_valid() else RemoteHost.random_token
	for s: int in SLOTS:
		_inputs.append(RemoteInputSource.new(s, dead_zone, curve, max_pending_taps))
		_ctx.append(SlotCtx.new())


static func random_token() -> String:
	return Crypto.new().generate_random_bytes(12).hex_encode()


# ======================= API para el juego =======================

## URL para el QR (vacía si no hay red o no hay puente).
func controller_url() -> String:
	return _bridge.controller_url() if _bridge != null else ""


func tv_name() -> String:
	var n: String = _bridge.tv_name() if _bridge != null else ""
	return n if n != "" else DEFAULT_TV_NAME


## Entrada del asiento (estable: siempre la misma instancia).
func input(slot: int) -> RemoteInputSource:
	return _inputs[slot]


## Llamar una vez por frame, antes de leer las entradas.
func update() -> void:
	if _bridge == null:
		return
	var now: float = _now.call()
	for ev: Dictionary in RemoteValidate.parse_bridge_events(_bridge.poll()):
		match String(ev["e"]):
			"open":
				_on_open(ev["id"], now)
			"close":
				_on_close(ev["id"])
			"msg":
				_on_message(ev["id"], ev["data"], now)
	_check_timeouts(now)
	for s: int in SLOTS:
		_flush_ctx(s, now)


## Contexto del control (texto del botón, objetivo, pantalla…). Se manda solo si cambió, ≤10/s.
func set_context(slot: int, ctx: Dictionary) -> void:
	var c: SlotCtx = _ctx[slot]
	var json: String = RemoteProtocol.to_json(ctx)
	if json == c.wanted_json:
		return
	c.wanted = ctx.duplicate(true)
	c.wanted_json = json
	if _bridge != null:
		_flush_ctx(slot, _now.call())


## Igual que set_context para los dos asientos.
func set_context_all(ctx: Dictionary) -> void:
	for s: int in SLOTS:
		set_context(s, ctx)


func get_context(slot: int) -> Dictionary:
	return _ctx[slot].wanted.duplicate(true)


## Vibración en la tablet (ms, formato navigator.vibrate).
func haptic(slot: int, pattern: Array) -> void:
	var p: Array[int] = RemoteValidate.sanitize_haptic(pattern)
	if not p.is_empty():
		_send_to(slot, {"t": "haptic", "pattern": p})


## Mensaje corto en la tablet. kind: "good" | "bad" | "info" | "" (sin tipo).
func toast(slot: int, text: String, kind: String = "") -> void:
	var m: Dictionary = {"t": "toast", "text": text.substr(0, RemoteValidate.MAX_TOAST_CHARS)}
	if kind == "good" or kind == "bad" or kind == "info":
		m["kind"] = kind
	_send_to(slot, m)


## Echa al jugador y libera el asiento.
func kick(slot: int, reason: String = "El tele cerró tu lugar") -> void:
	var seat: Seat = _seats[slot]
	if seat == null:
		return
	if seat.conn_id >= 0:
		var id: int = seat.conn_id
		_send_raw(id, {"t": "kick", "reason": reason})
		_close_conn(id, "kick")
	_free_seat(slot, "kick")


## Libera un asiento reservado (jugador desconectado) sin esperar RESUME_WINDOW_MS.
func release(slot: int) -> void:
	var seat: Seat = _seats[slot]
	if seat != null and seat.conn_id < 0:
		_free_seat(slot, "released")


## Jugadores por asiento (índice = slot); null = lugar libre.
func players() -> Array[RemotePlayer]:
	var out: Array[RemotePlayer] = []
	for s: int in SLOTS:
		out.append(_info(s))
	return out


## Asientos ocupados (conectados o reservados).
func player_count() -> int:
	var n: int = 0
	for s: Seat in _seats:
		if s != null:
			n += 1
	return n


func connected_count() -> int:
	var n: int = 0
	for s: Seat in _seats:
		if s != null and s.conn_id >= 0:
			n += 1
	return n


## Cierra todas las conexiones y olvida los asientos.
func dispose() -> void:
	for id: int in _conns.keys():
		_close_conn(id, "bye")
	for s: int in SLOTS:
		if _seats[s] != null:
			_free_seat(s, "released")


# ======================= Internos =======================

func _info(slot: int) -> RemotePlayer:
	var s: Seat = _seats[slot]
	if s == null:
		return null
	var p := RemotePlayer.new()
	p.slot = slot
	p.name = s.name
	p.color = RemoteProtocol.SLOT_COLOR_HEX[slot]
	p.color_name = RemoteProtocol.SLOT_COLOR_NAME[slot]
	p.connected = s.conn_id >= 0
	p.latency_ms = s.latency_ms
	p.device = s.device
	p.reserved_until = -1 if s.dropped_at < 0.0 else int(s.dropped_at + RemoteProtocol.RESUME_WINDOW_MS)
	return p


func _on_open(id: int, now: float) -> void:
	if _conns.has(id):
		return
	var pending: int = 0
	for c: Conn in _conns.values():
		if c.slot < 0:
			pending += 1
	if pending >= MAX_PENDING_CONNS:
		_bridge.close(id, "busy")
		return
	_conns[id] = Conn.new(id, now)


func _on_close(id: int) -> void:
	var c: Conn = _conns.get(id)
	if c == null:
		return
	_conns.erase(id)
	if c.slot >= 0:
		_drop_seat(c.slot, "closed")


func _on_message(id: int, data: String, now: float) -> void:
	var c: Conn = _conns.get(id)
	if c == null:
		# El puente puede entregar un mensaje sin "open" previo (o lo descartamos por lleno): lo registramos.
		_on_open(id, now)
		c = _conns.get(id)
		if c == null:
			return
	# Token bucket: descarta excesos sin cortar la conexión.
	c.bucket = minf(RATE_BURST, c.bucket + ((now - c.bucket_at) / 1000.0) * RATE_PER_SEC)
	c.bucket_at = now
	if c.bucket < 1.0:
		return
	c.bucket -= 1.0

	var msg: Dictionary = RemoteValidate.parse_client_msg(data)
	if msg.is_empty():
		return
	var t: String = msg["t"]
	if t == "hello":
		_on_hello(c, msg["v"], msg["name"], msg["token"], msg["device"], now)
		return
	if c.slot < 0:
		return
	var seat: Seat = _seats[c.slot]
	if seat == null or seat.conn_id != c.id:
		return
	seat.last_seen_at = now
	match t:
		"input":
			_inputs[c.slot].apply_state(msg["s"])
		"ping":
			if msg.has("rtt"):
				seat.latency_ms = msg["rtt"]
			_send_raw(c.id, {"t": "pong", "at": msg["at"]})
		"bye":
			var slot: int = c.slot
			_close_conn(c.id, "bye")
			_free_seat(slot, "bye")


func _on_hello(c: Conn, v: float, raw_name: String, token: String, device: String, now: float) -> void:
	if c.slot >= 0:
		return  # hello repetido
	if v != float(RemoteProtocol.PROTOCOL_VERSION):
		_send_raw(c.id, {"t": "kick", "reason": "Versión incompatible: actualizá la app de control"})
		_close_conn(c.id, "version")
		return
	# ¿Vuelve un jugador con su token?
	if token != "":
		for s: int in SLOTS:
			var seat: Seat = _seats[s]
			if seat != null and seat.token == token:
				if seat.conn_id >= 0 and seat.conn_id != c.id:
					_close_conn(seat.conn_id, "replaced")
				if raw_name != "":
					seat.name = raw_name
				seat.device = device
				_bind(c, s, seat, now, false)
				resumed.emit(_info(s))
				return
	var free: int = -1
	for s: int in SLOTS:
		if _seats[s] == null:
			free = s
			break
	if free < 0:
		_send_raw(c.id, {"t": "full", "reason": "Ya hay %d jugadores en este tele" % RemoteProtocol.MAX_PLAYERS})
		_close_conn(c.id, "full")
		return
	var ns := Seat.new()
	ns.token = _make_token.call()
	ns.name = raw_name if raw_name != "" else "Jugador %d" % (free + 1)
	ns.device = device
	ns.last_seen_at = now
	_seats[free] = ns
	_bind(c, free, ns, now, true)
	joined.emit(_info(free))


func _bind(c: Conn, slot: int, seat: Seat, now: float, new_player: bool) -> void:
	c.slot = slot
	seat.conn_id = c.id
	seat.last_seen_at = now
	seat.dropped_at = -1.0
	_inputs[slot].begin_connection(new_player)
	_send_raw(c.id, {
		"t": "welcome", "v": RemoteProtocol.PROTOCOL_VERSION, "slot": slot, "token": seat.token,
		"color": RemoteProtocol.SLOT_COLOR_HEX[slot], "colorName": RemoteProtocol.SLOT_COLOR_NAME[slot],
		"tvName": tv_name(), "resumed": not new_player,
	})
	# El contexto va siempre enseguida del welcome (conexión nueva = nada enviado aún).
	var sc: SlotCtx = _ctx[slot]
	sc.sent_json = ""
	sc.sent_at = -INF
	_flush_ctx(slot, now)


func _check_timeouts(now: float) -> void:
	for c: Conn in _conns.values():
		if c.slot < 0 and now - c.opened_at > HELLO_TIMEOUT_MS:
			_close_conn(c.id, "hello-timeout")
	for s: int in SLOTS:
		var seat: Seat = _seats[s]
		if seat == null:
			continue
		if seat.conn_id >= 0 and now - seat.last_seen_at > RemoteProtocol.PLAYER_TIMEOUT_MS:
			var id: int = seat.conn_id
			_drop_seat(s, "timeout")
			_conns.erase(id)
			_bridge.close(id, "timeout")
		elif seat.conn_id < 0 and seat.dropped_at >= 0.0 and now - seat.dropped_at > RemoteProtocol.RESUME_WINDOW_MS:
			_free_seat(s, "expired")


func _drop_seat(slot: int, reason: String) -> void:
	var seat: Seat = _seats[slot]
	if seat == null or seat.conn_id < 0:
		return
	seat.conn_id = -1
	seat.dropped_at = _now.call()
	_inputs[slot].disconnect_source()
	dropped.emit(slot, reason)


func _free_seat(slot: int, reason: String) -> void:
	if _seats[slot] == null:
		return
	_seats[slot] = null
	_inputs[slot].disconnect_source()
	left.emit(slot, reason)


func _flush_ctx(slot: int, now: float) -> void:
	var seat: Seat = _seats[slot]
	if seat == null or seat.conn_id < 0:
		return
	var c: SlotCtx = _ctx[slot]
	if c.wanted_json == c.sent_json or now - c.sent_at < CTX_MIN_INTERVAL_MS:
		return
	c.sent_json = c.wanted_json
	c.sent_at = now
	_bridge.send(seat.conn_id, "{\"t\":\"ctx\",\"c\":" + c.wanted_json + "}")


func _send_to(slot: int, msg: Dictionary) -> void:
	var seat: Seat = _seats[slot]
	if seat != null and seat.conn_id >= 0:
		_send_raw(seat.conn_id, msg)


func _send_raw(conn_id: int, msg: Dictionary) -> void:
	if _bridge == null:
		return
	_bridge.send(conn_id, RemoteProtocol.to_json(msg))


## Cierra la conexión del lado del tele; si tenía asiento, lo desvincula sin liberarlo.
func _close_conn(id: int, reason: String) -> void:
	var c: Conn = _conns.get(id)
	_conns.erase(id)
	if c != null and c.slot >= 0:
		var seat: Seat = _seats[c.slot]
		if seat != null and seat.conn_id == id:
			seat.conn_id = -1
			seat.dropped_at = _now.call()
			_inputs[c.slot].disconnect_source()
	if _bridge != null:
		_bridge.close(id, reason)
