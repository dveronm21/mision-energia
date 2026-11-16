class_name DuelLink
extends RefCounted
## Enlace entre dos teles para el modo Duelo, aparte del de las tablets (no toca su protocolo).
## Cada tele anuncia por UDP broadcast que está en Duelo; al verse, el de `id` menor se conecta por
## TCP al otro, que queda como árbitro. Los mensajes son JSON, uno por línea. Sin hilos: `poll()`
## una vez por cuadro devuelve lo que llegó.
##
##   var link := DuelLink.new("Ana")
##   link.start()
##   # cada cuadro:
##   for m: Dictionary in link.poll():   # {"t": "_connected"}, {"t": "_lost"} o los del otro tele
##       ...
##   link.send({"t": "setup", "level": "casa"})

const PROTOCOL_VERSION: int = 1
const PORT: int = 8767
const BEACON_PORT: int = 8768
const BEACON_PREFIX: String = "MISION-ENERGIA-DUEL-1 "
const BEACON_SEC: float = 0.8
const KEEPALIVE_MS: int = 500
## Sin nada del otro tele en este tiempo → enlace perdido (vuelve a buscar).
const TIMEOUT_MS: int = 4000
## Para conectar o saludar: si el otro no responde, se descarta y se reintenta con el próximo anuncio.
const CONNECT_TIMEOUT_MS: int = 3000
const MAX_LINE_BYTES: int = 16384

enum State { OFF, SEARCHING, CONNECTING, CONNECTED }

var id: String
var display_name: String
var state: State = State.OFF
## true = este tele aceptó la conexión (id mayor): sortea, elige el nivel y decide el ganador.
var is_referee: bool = false
var peer_id: String = ""
var peer_name: String = ""
var peer_ip: String = ""

## Pruebas en la misma compu: escuchar y anunciar en puertos distintos, a 127.0.0.1.
var bind_address: String = "*"
var port: int = PORT
var beacon_port: int = BEACON_PORT
var beacon_targets: Array[int] = [BEACON_PORT]
var beacon_address: String = "255.255.255.255"

var _server: TCPServer
var _udp_in: PacketPeerUDP
var _udp_out: PacketPeerUDP
var _link: TcpLink
var _buf: PackedByteArray = PackedByteArray()
var _beacon_wait: float = 0.0
var _last_rx: int = 0
var _last_tx: int = 0
var _connect_started: int = 0
var _hello_received: bool = false
var _out: Array[Dictionary] = []


func _init(p_name: String = "", p_id: String = "") -> void:
	display_name = p_name
	id = p_id if p_id != "" else "%08x%08x" % [randi(), randi()]


func start() -> Error:
	stop()
	_server = TCPServer.new()
	var err: Error = _server.listen(port, bind_address)
	if err != OK:
		_server = null
		return err
	_udp_in = PacketPeerUDP.new()
	if _udp_in.bind(beacon_port, bind_address) != OK:
		_udp_in = null # sin anuncios entrantes igual se puede conectar a mano o ser encontrado
	_udp_out = PacketPeerUDP.new()
	_udp_out.set_broadcast_enabled(true)
	state = State.SEARCHING
	_beacon_wait = 0.0
	return OK


func stop() -> void:
	if _link != null:
		_raw_send({"t": "bye"})
		_link.flush()
		_link.close()
		_link = null
	if _server != null:
		_server.stop()
		_server = null
	if _udp_in != null:
		_udp_in.close()
		_udp_in = null
	if _udp_out != null:
		_udp_out.close()
		_udp_out = null
	state = State.OFF
	_reset_peer()


func is_connected_to_peer() -> bool:
	return state == State.CONNECTED


## Conecta a mano a otro tele (pruebas, o si el broadcast no pasa por la red del lugar).
func connect_to(ip: String, p_port: int = PORT) -> void:
	if state != State.SEARCHING:
		return
	var tcp: StreamPeerTCP = StreamPeerTCP.new()
	if tcp.connect_to_host(ip, p_port) != OK:
		return
	_link = TcpLink.new(tcp)
	_link.remote_ip = ip
	peer_ip = ip
	is_referee = false
	state = State.CONNECTING
	_connect_started = Time.get_ticks_msec()
	_hello_received = false


func send(msg: Dictionary) -> void:
	if state == State.CONNECTED:
		_raw_send(msg)


## Procesa la red. Devuelve los mensajes del otro tele y los eventos `_connected` / `_lost`.
func poll(dt: float = 0.0) -> Array[Dictionary]:
	_out = []
	if state == State.OFF:
		return _out
	var now: int = Time.get_ticks_msec()
	if state == State.SEARCHING:
		_beacon(dt)
		_read_beacons()
		_accept()
	elif state == State.CONNECTING:
		_poll_link(now)
		if state == State.CONNECTING and now - _connect_started > CONNECT_TIMEOUT_MS:
			_drop(false)
	else:
		_poll_link(now)
		_reject_extra()
		if state == State.CONNECTED:
			if now - _last_rx > TIMEOUT_MS:
				_drop(true)
			elif now - _last_tx > KEEPALIVE_MS:
				_raw_send({"t": "ping"})
	return _out


func _beacon(dt: float) -> void:
	_beacon_wait -= dt
	if _beacon_wait > 0.0 or _udp_out == null:
		return
	_beacon_wait = BEACON_SEC
	var data: PackedByteArray = (BEACON_PREFIX + JSON.stringify({"id": id, "name": display_name, "port": port})).to_utf8_buffer()
	for p: int in beacon_targets:
		_udp_out.set_dest_address(beacon_address, p)
		_udp_out.put_packet(data)


func _read_beacons() -> void:
	if _udp_in == null:
		return
	var n: int = 0
	while _udp_in.get_available_packet_count() > 0 and n < 32 and state == State.SEARCHING:
		n += 1
		var text: String = _udp_in.get_packet().get_string_from_utf8()
		var ip: String = _udp_in.get_packet_ip()
		var b: Dictionary = parse_beacon(text)
		if b.is_empty() or b["id"] == id:
			continue
		# El de id menor llama; el otro espera (así no se cruzan dos conexiones).
		if id < String(b["id"]):
			connect_to(ip, int(b["port"]))


## {id, name, port} de un anuncio válido, o {} si no lo es.
static func parse_beacon(text: String) -> Dictionary:
	if not text.begins_with(BEACON_PREFIX) or text.length() > 512:
		return {}
	var v: Variant = _parse(text.trim_prefix(BEACON_PREFIX))
	if not (v is Dictionary) or not (v.get("id") is String) or not (v.get("port") is float):
		return {}
	var p: int = int(v["port"])
	if p <= 0 or p > 65535 or String(v["id"]).is_empty():
		return {}
	return {"id": String(v["id"]), "name": String(v.get("name", "")).substr(0, 40), "port": p}


## JSON sin errores en el log (lo que llega por la red puede venir roto).
static func _parse(text: String) -> Variant:
	var j: JSON = JSON.new()
	return j.data if j.parse(text) == OK else null


func _accept() -> void:
	if _server == null or not _server.is_connection_available():
		return
	_link = TcpLink.new(_server.take_connection())
	peer_ip = _link.remote_ip
	is_referee = true
	state = State.CONNECTING
	_connect_started = Time.get_ticks_msec()
	_hello_received = false


## Ya hay un rival: cualquier otra conexión entrante se cierra.
func _reject_extra() -> void:
	while _server != null and _server.is_connection_available():
		_server.take_connection().disconnect_from_host()


func _poll_link(now: int) -> void:
	if _link == null:
		return
	var st: int = _link.tcp.get_status()
	_link.tcp.poll()
	st = _link.tcp.get_status()
	if st == StreamPeerTCP.STATUS_CONNECTING:
		return
	if st != StreamPeerTCP.STATUS_CONNECTED:
		_drop(state == State.CONNECTED)
		return
	if state == State.CONNECTING and _last_tx < _connect_started:
		_raw_send({"t": "hello", "v": PROTOCOL_VERSION, "id": id, "name": display_name})
	_link.flush()
	var chunk: PackedByteArray = _link.read_available()
	if chunk.is_empty():
		return
	_buf.append_array(chunk)
	while true:
		var nl: int = _buf.find(10)
		if nl < 0:
			if _buf.size() > MAX_LINE_BYTES:
				_drop(state == State.CONNECTED)
			return
		var line: String = _buf.slice(0, nl).get_string_from_utf8()
		_buf = _buf.slice(nl + 1)
		var v: Variant = _parse(line)
		if not (v is Dictionary) or not (v.get("t") is String):
			continue
		_last_rx = now
		_handle(v)
		if _link == null:
			return


func _handle(m: Dictionary) -> void:
	match String(m["t"]):
		"hello":
			if int(m.get("v", 0)) != PROTOCOL_VERSION or String(m.get("id", "")) == id:
				_drop(false)
				return
			peer_id = String(m.get("id", ""))
			peer_name = String(m.get("name", "")).substr(0, 40)
			_hello_received = true
			if state == State.CONNECTING:
				state = State.CONNECTED
				_out.append({"t": "_connected"})
		"ping":
			pass
		"bye":
			_drop(true)
		_:
			if state == State.CONNECTED:
				_out.append(m)


func _raw_send(msg: Dictionary) -> void:
	if _link == null:
		return
	_link.write((JSON.stringify(msg) + "\n").to_utf8_buffer())
	_last_tx = Time.get_ticks_msec()


## Corta con el otro tele y vuelve a buscar. `notify`: avisar `_lost` (estaba conectado).
func _drop(notify: bool) -> void:
	if _link != null:
		_link.close()
		_link = null
	_reset_peer()
	if state != State.OFF:
		state = State.SEARCHING
		_beacon_wait = 0.0
	if notify:
		_out.append({"t": "_lost"})


func _reset_peer() -> void:
	_buf = PackedByteArray()
	_hello_received = false
	is_referee = false
	peer_id = ""
	peer_name = ""
	peer_ip = ""
	_last_tx = 0
