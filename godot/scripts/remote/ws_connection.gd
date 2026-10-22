class_name WsConnection
extends RefCounted
## Conexión WebSocket (RFC 6455) del lado servidor, solo mensajes de texto, sobre un TcpLink.
## Port de WebSocketConnection.java sin hilos: RemoteServer llama process() una vez por frame.
##
## Se implementa a mano (y no con WebSocketPeer.accept_stream) porque el servidor ya leyó la cabecera
## HTTP para enrutar y verificar Origin; accept_stream exige un StreamPeerTCP "virgen" y no acepta
## un StreamPeer que devuelva primero esos bytes (en 4.7 rechaza StreamPeerExtension con
## ERR_INVALID_PARAMETER), ni expone las cabeceras para el control de Origin.

## Mensaje de texto completo recibido.
signal message(conn: WsConnection, text: String)
## La conexión terminó (una sola vez).
signal closed(conn: WsConnection)

const CLOSE_NORMAL: int = 1000
const CLOSE_GOING_AWAY: int = 1001
const CLOSE_PROTOCOL_ERROR: int = 1002
const CLOSE_UNSUPPORTED: int = 1003
const CLOSE_INVALID_DATA: int = 1007
const CLOSE_POLICY: int = 1008
const CLOSE_TOO_BIG: int = 1009

const PING_INTERVAL_MS: int = 5000
const READ_TIMEOUT_MS: int = 15000
const CLOSE_WAIT_MS: int = 1000
## Mensajes salientes pendientes como máximo (cliente colgado → close 1008 "cliente lento").
const SEND_QUEUE_MAX: int = 512
const GUID: String = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

enum State { OPEN, CLOSING, CLOSED }

var id: int
var remote_ip: String
var state: State = State.OPEN
var _link: TcpLink
var _max_message: int
var _in := PackedByteArray()
var _frag := PackedByteArray()
var _frag_active: bool = false
var _last_rx: int
var _last_tx: int
var _closing_since: int = 0
## Ya se recibió el close del cliente: cerrar TCP en cuanto salga el eco.
var _peer_closed: bool = false


## handshake_response: el "101 Switching Protocols" a enviar. leftover: bytes que llegaron pegados
## a la cabecera HTTP (frames del cliente) y no hay que perder.
func _init(p_id: int, link: TcpLink, handshake_response: PackedByteArray, leftover: PackedByteArray,
		max_message: int = RemoteProtocol.MAX_MESSAGE_BYTES) -> void:
	id = p_id
	_link = link
	remote_ip = link.remote_ip
	_max_message = max_message
	_last_rx = Time.get_ticks_msec()
	_last_tx = _last_rx
	_link.write(handshake_response)
	_in = leftover


func is_open() -> bool:
	return state == State.OPEN


## Encola un mensaje de texto. No bloquea. false si está cerrando, si supera el máximo o si la cola
## está llena (en ese caso el cliente es demasiado lento y se lo desconecta).
func send_text(text: String) -> bool:
	if state != State.OPEN:
		return false
	var payload: PackedByteArray = text.to_utf8_buffer()
	if payload.size() > _max_message:
		push_warning("ws#%d: mensaje saliente demasiado grande (%d B), descartado" % [id, payload.size()])
		return false
	if _link.pending_chunks() >= SEND_QUEUE_MAX:
		close(CLOSE_POLICY, "cliente lento")
		return false
	_write(make_frame(0x1, payload))
	return true


## Cierre ordenado: manda el frame close y espera el del cliente hasta CLOSE_WAIT_MS.
func close(code: int, reason: String) -> void:
	if state != State.OPEN:
		return
	state = State.CLOSING
	_closing_since = Time.get_ticks_msec()
	_write(make_frame(0x8, close_payload(code, reason)))


## Corta el socket sin handshake de cierre.
func abort() -> void:
	if state == State.CLOSED:
		return
	state = State.CLOSED
	_link.close()
	closed.emit(self)


## Lee, procesa frames, timeouts y keepalive. Llamar una vez por frame.
func process(now: int) -> void:
	if state == State.CLOSED:
		return
	var alive: bool = _link.poll()
	var data: PackedByteArray = _link.read_available(_max_message + 16)
	if not data.is_empty():
		_last_rx = now
		if state == State.OPEN:
			_in.append_array(data)
	if state == State.OPEN and not _in.is_empty():
		_parse_frames()
	if not alive and _link.available() == 0:
		abort()
		return
	match state:
		State.OPEN:
			if now - _last_rx > READ_TIMEOUT_MS:
				abort()   # sin datos: conexión muerta
				return
			if now - _last_tx > PING_INTERVAL_MS:
				_write(make_frame(0x9, PackedByteArray()))   # keepalive del servidor
		State.CLOSING:
			_link.flush()
			if _peer_closed and _link.pending_chunks() == 0:
				abort()
			elif now - _closing_since > CLOSE_WAIT_MS:
				abort()
	if state != State.CLOSED:
		_link.flush()


func _write(frame: PackedByteArray) -> void:
	_last_tx = Time.get_ticks_msec()
	_link.write(frame)


func _parse_frames() -> void:
	while state == State.OPEN:
		var n: int = _in.size()
		if n < 2:
			return
		var b0: int = _in[0]
		var b1: int = _in[1]
		var fin: bool = (b0 & 0x80) != 0
		var opcode: int = b0 & 0x0f
		if (b0 & 0x70) != 0:
			_protocol_error("bits RSV")
			return
		if (b1 & 0x80) == 0:
			_protocol_error("frame sin máscara")
			return
		var length: int = b1 & 0x7f
		var hdr: int = 2
		if length == 126:
			if n < 4:
				return
			length = (_in[2] << 8) | _in[3]
			hdr = 4
		elif length == 127:
			if n < 10:
				return
			if (_in[2] & 0x80) != 0:
				_protocol_error("largo inválido")
				return
			length = 0
			for i: int in 8:
				length = (length << 8) | _in[2 + i]
			hdr = 10
		var control: bool = opcode >= 0x8
		if control and (not fin or length > 125):
			_protocol_error("frame de control inválido")
			return
		if not control and length + _frag.size() > _max_message:
			close(CLOSE_TOO_BIG, "mensaje demasiado grande")
			return
		if n < hdr + 4 + length:
			return   # falta el resto: esperar
		var key: PackedByteArray = _in.slice(hdr, hdr + 4)
		var payload: PackedByteArray = unmask(_in.slice(hdr + 4, hdr + 4 + length), key)
		_in = _in.slice(hdr + 4 + length)
		match opcode:
			0x0:   # continuación
				if not _frag_active:
					_protocol_error("continuación inesperada")
					return
				_frag.append_array(payload)
				if fin:
					var whole: PackedByteArray = _frag
					_frag = PackedByteArray()
					_frag_active = false
					if not _deliver(whole):
						return
			0x1:   # texto
				if _frag_active:
					_protocol_error("mensaje nuevo dentro de un fragmentado")
					return
				if fin:
					if not _deliver(payload):
						return
				else:
					_frag = payload
					_frag_active = true
			0x2:   # binario
				close(CLOSE_UNSUPPORTED, "solo texto")
				return
			0x8:   # close
				var code: int = CLOSE_NORMAL
				if payload.size() == 1:
					code = CLOSE_PROTOCOL_ERROR
				elif payload.size() >= 2:
					code = (payload[0] << 8) | payload[1]
					if not _valid_close_code(code):
						code = CLOSE_PROTOCOL_ERROR
				_peer_closed = true
				close(code, "")
				return
			0x9:   # ping → pong con el mismo contenido
				_write(make_frame(0xA, payload))
			0xA:   # pong
				pass
			_:
				_protocol_error("opcode %d" % opcode)
				return


func _deliver(utf8: PackedByteArray) -> bool:
	if not is_valid_utf8(utf8):
		close(CLOSE_INVALID_DATA, "UTF-8 inválido")
		return false
	message.emit(self, utf8.get_string_from_utf8())
	return true


func _protocol_error(why: String) -> void:
	close(CLOSE_PROTOCOL_ERROR, why)


static func _valid_close_code(c: int) -> bool:
	return (c >= 1000 and c <= 1003) or (c >= 1007 and c <= 1011) or (c >= 3000 and c <= 4999)


## Sec-WebSocket-Accept = base64(sha1(key + GUID)).
static func accept_key(key: String) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA1)
	h.update((key + GUID).to_utf8_buffer())
	return Marshalls.raw_to_base64(h.finish())


## Sin Origin (apps nativas, Node) → permitido. Con Origin http(s), el host tiene que coincidir con
## la cabecera Host (la página la sirve este mismo servidor). Igual que HttpServer.originAllowed (Java).
static func origin_allowed(origin: String, host_header: String) -> bool:
	if origin.is_empty() or origin == "null":
		return true
	var o: String = origin.to_lower()
	if o.begins_with("file:"):
		return true
	var sep: int = o.find("://")
	if sep < 0 or host_header.is_empty():
		return false
	var oh: String = o.substr(sep + 3)
	if oh.ends_with("/"):
		oh = oh.substr(0, oh.length() - 1)
	return oh == host_header.to_lower().strip_edges()


## Frame del servidor (sin máscara, FIN=1).
static func make_frame(opcode: int, payload: PackedByteArray) -> PackedByteArray:
	var n: int = payload.size()
	var f := PackedByteArray()
	f.append(0x80 | opcode)
	if n < 126:
		f.append(n)
	elif n <= 0xFFFF:
		f.append(126)
		f.append((n >> 8) & 0xFF)
		f.append(n & 0xFF)
	else:
		f.append(127)
		for i: int in 8:
			f.append((n >> (56 - 8 * i)) & 0xFF)
	f.append_array(payload)
	return f


## Código + motivo (≤123 bytes, sin cortar un carácter UTF-8 a la mitad).
static func close_payload(code: int, reason: String) -> PackedByteArray:
	var r: PackedByteArray = reason.to_utf8_buffer()
	if r.size() > 123:
		var cut: int = 123
		while cut > 0 and (r[cut] & 0xC0) == 0x80:
			cut -= 1
		r = r.slice(0, cut)
	var p := PackedByteArray([(code >> 8) & 0xFF, code & 0xFF])
	p.append_array(r)
	return p


## XOR con la clave de 4 bytes, de a 32 bits (4× menos iteraciones en GDScript).
static func unmask(payload: PackedByteArray, key: PackedByteArray) -> PackedByteArray:
	var n: int = payload.size()
	if n == 0:
		return payload
	var padded: PackedByteArray = payload.duplicate()
	padded.resize((n + 3) & ~3)
	var words: PackedInt32Array = padded.to_int32_array()
	var k: int = key.decode_s32(0)
	for i: int in words.size():
		words[i] = words[i] ^ k
	var out: PackedByteArray = words.to_byte_array()
	out.resize(n)
	return out


## Validación estricta de UTF-8 (sin sobrelargos, sin surrogates, ≤ U+10FFFF).
static func is_valid_utf8(b: PackedByteArray) -> bool:
	var i: int = 0
	var n: int = b.size()
	while i < n:
		var c: int = b[i]
		if c < 0x80:
			i += 1
			continue
		var need: int
		var min_cp: int
		var cp: int
		if c >= 0xC2 and c <= 0xDF:
			need = 1; min_cp = 0x80; cp = c & 0x1F
		elif c >= 0xE0 and c <= 0xEF:
			need = 2; min_cp = 0x800; cp = c & 0x0F
		elif c >= 0xF0 and c <= 0xF4:
			need = 3; min_cp = 0x10000; cp = c & 0x07
		else:
			return false
		if i + need >= n:
			return false
		for j: int in range(1, need + 1):
			var cc: int = b[i + j]
			if (cc & 0xC0) != 0x80:
				return false
			cp = (cp << 6) | (cc & 0x3F)
		if cp < min_cp or cp > 0x10FFFF or (cp >= 0xD800 and cp <= 0xDFFF):
			return false
		i += need + 1
	return true
