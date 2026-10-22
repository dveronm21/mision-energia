class_name DiscoveryResponder
extends RefCounted
## Escucha UDP en DISCOVERY_PORT. A cada datagrama cuyo contenido sea exactamente DISCOVERY_QUERY
## le responde por unicast (al puerto de origen) con el DiscoveryReply JSON. La IP del reply es la de
## la red de quien preguntó (NetUtils.best_local_for). Cualquier otro contenido se ignora.
## Limitado a MAX_REPLIES_PER_SECOND. Sin hilos: RemoteServer llama poll() una vez por frame.
##
## En Android muchos equipos descartan broadcast si la app no tiene un WifiManager.MulticastLock
## (permiso CHANGE_WIFI_MULTICAST_STATE). Ver tools/remote_test/README.md.

const MAX_REPLIES_PER_SECOND: int = 50
const MAX_QUERY_BYTES: int = 64
const MAX_PACKETS_PER_POLL: int = 64

var port: int
var replies_sent: int = 0
## (ip_local: String) -> String JSON
var _reply_builder: Callable
var _udp: PacketPeerUDP
var _window_start: int = 0
var _window_count: int = 0


func _init(p_port: int, reply_builder: Callable) -> void:
	port = p_port
	_reply_builder = reply_builder


func start(bind_address: String = "0.0.0.0") -> Error:
	stop()
	_udp = PacketPeerUDP.new()
	var err: Error = _udp.bind(port, bind_address)
	if err != OK:
		_udp = null
		return err
	_udp.set_broadcast_enabled(true)
	return OK


func stop() -> void:
	if _udp != null:
		_udp.close()
		_udp = null


func is_running() -> bool:
	return _udp != null and _udp.is_bound()


func poll() -> void:
	if _udp == null:
		return
	var handled: int = 0
	while _udp.get_available_packet_count() > 0 and handled < MAX_PACKETS_PER_POLL:
		handled += 1
		var pkt: PackedByteArray = _udp.get_packet()
		var ip: String = _udp.get_packet_ip()
		var p: int = _udp.get_packet_port()
		if pkt.size() > MAX_QUERY_BYTES or ip.is_empty():
			continue
		if pkt.get_string_from_ascii().strip_edges() != RemoteProtocol.DISCOVERY_QUERY:
			continue
		var now: int = Time.get_ticks_msec()
		if now - _window_start >= 1000:
			_window_start = now
			_window_count = 0
		_window_count += 1
		if _window_count > MAX_REPLIES_PER_SECOND:
			continue
		var reply: String = _reply_builder.call(ip)
		_udp.set_dest_address(ip, p)
		if _udp.put_packet(reply.to_utf8_buffer()) == OK:
			replies_sent += 1
