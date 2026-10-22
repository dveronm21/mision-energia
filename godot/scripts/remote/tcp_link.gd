class_name TcpLink
extends RefCounted
## Envoltorio no bloqueante de un StreamPeerTCP: lectura de lo disponible y cola de escritura por
## trozos (cada trozo = un frame o una respuesta), que se vacía con put_partial_data sin bloquear nunca.

var tcp: StreamPeerTCP
var remote_ip: String = ""
var _chunks: Array[PackedByteArray] = []
var _offset: int = 0       # bytes ya enviados del primer trozo
var _pending_bytes: int = 0


func _init(p_tcp: StreamPeerTCP) -> void:
	tcp = p_tcp
	tcp.set_no_delay(true)   # sin Nagle: cada input/pong sale en el momento
	remote_ip = tcp.get_connected_host()


## Actualiza el estado del socket. false si ya no está conectado (cerrado por el otro lado o error).
func poll() -> bool:
	tcp.poll()
	return tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED


func is_open() -> bool:
	return tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED


## Lee todo lo disponible (hasta max_bytes). Vacío si no hay nada.
func read_available(max_bytes: int = 1 << 20) -> PackedByteArray:
	var n: int = available()
	if n <= 0:
		return PackedByteArray()
	var r: Array = tcp.get_partial_data(mini(n, max_bytes))
	if int(r[0]) != OK:
		return PackedByteArray()
	return r[1]


## Bytes listos para leer (0 si el socket ya está cerrado).
func available() -> int:
	if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return 0
	return tcp.get_available_bytes()


## Encola bytes y trata de enviarlos ya.
func write(data: PackedByteArray) -> void:
	if data.is_empty():
		return
	_chunks.append(data)
	_pending_bytes += data.size()
	flush()


## Envía lo que el socket acepte sin bloquear. true si la cola quedó vacía.
func flush() -> bool:
	while not _chunks.is_empty():
		if tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return false
		var chunk: PackedByteArray = _chunks[0]
		var part: PackedByteArray = chunk if _offset == 0 else chunk.slice(_offset)
		var r: Array = tcp.put_partial_data(part)
		if int(r[0]) != OK:
			return false
		var sent: int = r[1]
		_pending_bytes -= sent
		if sent < part.size():
			_offset += sent
			return false
		_chunks.pop_front()
		_offset = 0
	return true


## Trozos (mensajes) que todavía no salieron del todo.
func pending_chunks() -> int:
	return _chunks.size()


func pending_bytes() -> int:
	return _pending_bytes


func close() -> void:
	_chunks.clear()
	_offset = 0
	_pending_bytes = 0
	tcp.disconnect_from_host()
