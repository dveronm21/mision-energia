class_name RemoteServer
extends Node
## Servidor del tele dentro del juego: HTTP + WebSocket en un puerto TCP y descubrimiento UDP.
## Port sin hilos de android/remote-core (RemoteServer/HttpServer/WebSocketConnection): todo es no
## bloqueante y se procesa una vez por frame en _process (process_priority = -100, antes del juego).
##
##   var server := RemoteServer.new()
##   add_child(server)
##   server.start()                         # OK o error si no hay puerto TCP
##   var host := RemoteHost.new(server.bridge())
##   # cada frame: host.update(), después host.input(0).read()
##
## Eventos para el juego (en el orden en que ocurrieron) con poll_events(): {e:"open",id,addr},
## {e:"msg",id,data}, {e:"close",id}. Un único close por cada open.

signal started(port: int)
signal stopped

## Máximo de msg pendientes si el juego deja de leer (después se descartan los nuevos; open/close nunca).
const MAX_PENDING_MSGS: int = 4096

@export var http_port: int = RemoteProtocol.HTTP_PORT
@export var fallback_http_ports: Array[int] = RemoteProtocol.FALLBACK_HTTP_PORTS.duplicate()
@export var discovery_port: int = RemoteProtocol.DISCOVERY_PORT
@export var discovery_enabled: bool = true
## Dirección donde escuchar ("*" = todas). Para tests: "127.0.0.1".
@export var bind_address: String = "*"
@export var tv_name: String = "Misión Energía TV"
## Máximo de WebSockets simultáneos (2 jugadores + margen para reconexiones y respuestas "full").
@export var max_websockets: int = 8
## Máximo de sockets TCP simultáneos (HTTP + WS).
@export var max_sockets: int = 32
@export var max_message_bytes: int = RemoteProtocol.MAX_MESSAGE_BYTES
## Si es false, se rechazan WebSockets con Origin http(s) de otro host (403).
@export var allow_any_origin: bool = false
## Carpeta de la página de control.
@export var controller_root: String = "res://controller/"
## IP a mostrar en el QR en lugar de la detectada (vacío = NetUtils.lan_ip()).
@export var lan_ip_override: String = ""
## Detener el servidor cuando la app pasa a segundo plano (Android) y reanudarlo al volver.
@export var pause_in_background: bool = true

var files: StaticFileServer
var _tcp: TCPServer
var _discovery: DiscoveryResponder
var _http: Array[HttpConnection] = []
var _ws: Dictionary = {}   # id → WsConnection
var _events: Array[Dictionary] = []
var _pending_msgs: int = 0
var _dropped_msgs: int = 0
var _next_id: int = 1
var _bound_port: int = -1
var _running: bool = false
var _was_running_before_pause: bool = false
var _bridge: RemoteServerBridge


func _init() -> void:
	process_priority = -100


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Abre el puerto TCP (probando los alternativos) y el UDP.
func start() -> Error:
	if _running:
		return OK
	files = StaticFileServer.new(controller_root)
	if not files.has_index():
		push_warning("RemoteServer: falta %sindex.html (página de control)" % controller_root)
	var ports: Array[int] = [http_port]
	ports.append_array(fallback_http_ports)
	var last_err: Error = ERR_CANT_OPEN
	for p: int in ports:
		var s := TCPServer.new()
		var err: Error = s.listen(p, bind_address)
		if err == OK:
			_tcp = s
			_bound_port = p
			break
		last_err = err
	if _tcp == null:
		return last_err
	_running = true
	if discovery_enabled:
		_discovery = DiscoveryResponder.new(discovery_port, _discovery_reply)
		var udp_bind: String = "0.0.0.0" if bind_address == "*" else bind_address
		# Para recibir broadcast hay que escuchar en todas las direcciones IPv4.
		if udp_bind.begins_with("127."):
			udp_bind = "0.0.0.0"
		AndroidMulticastLock.acquire()
		if _discovery.start(udp_bind) != OK:
			# Sin UDP igual se puede conectar por QR o IP: no es fatal.
			push_warning("RemoteServer: no se pudo abrir UDP %d" % discovery_port)
			_discovery = null
	started.emit(_bound_port)
	return OK


## Cierra todo: UDP, puerto TCP, WebSockets (close 1001) y sockets HTTP. Espera hasta ~300 ms a
## que salgan los frames close. poll_events() entrega después los close de cada conexión.
func stop() -> void:
	if not _running:
		return
	_running = false
	if _discovery != null:
		_discovery.stop()
		_discovery = null
	AndroidMulticastLock.release()
	_tcp.stop()
	_tcp = null
	for ws: WsConnection in _ws.values():
		ws.close(WsConnection.CLOSE_GOING_AWAY, "el tele se apagó")
	var deadline: int = Time.get_ticks_msec() + 300
	while not _ws.is_empty() and Time.get_ticks_msec() < deadline:
		for ws: WsConnection in _ws.values():
			ws.process(Time.get_ticks_msec())
		OS.delay_usec(2000)
	for ws: WsConnection in _ws.values():
		ws.abort()
	for h: HttpConnection in _http:
		h.close_now()
	_http.clear()
	_bound_port = -1
	stopped.emit()


func is_running() -> bool:
	return _running


func is_discovery_running() -> bool:
	return _discovery != null and _discovery.is_running()


## Puerto TCP real (−1 si está parado).
func get_http_port() -> int:
	return _bound_port


func connection_count() -> int:
	return _ws.size()


func dropped_message_count() -> int:
	return _dropped_msgs


## Puente para RemoteHost (siempre la misma instancia).
func bridge() -> RemoteServerBridge:
	if _bridge == null:
		_bridge = RemoteServerBridge.new(self)
	return _bridge


## IP local preferida para el QR ("" si no hay red).
func lan_ip() -> String:
	if lan_ip_override != "":
		return lan_ip_override
	if bind_address != "*" and bind_address != "0.0.0.0" and NetUtils.is_ipv4(bind_address):
		return bind_address
	return NetUtils.lan_ip()


## "http://192.168.0.23:8765/" o "" si no hay red o el servidor está parado.
func controller_url() -> String:
	if not _running or _bound_port < 0:
		return ""
	var ip: String = lan_ip()
	return "" if ip == "" else "http://%s:%d/" % [ip, _bound_port]


## DiscoveryReply JSON para la IP local dada (o la preferida).
func info_json(local_ip: String = "") -> String:
	var ip: String = local_ip if local_ip != "" else lan_ip()
	var players: int = mini(_ws.size(), RemoteProtocol.MAX_PLAYERS)
	return RemoteProtocol.to_json({"app": RemoteProtocol.APP_ID, "v": RemoteProtocol.PROTOCOL_VERSION,
		"name": tv_name, "ip": ip, "port": _bound_port, "players": players, "max": RemoteProtocol.MAX_PLAYERS})


## Eventos acumulados desde la última llamada.
func poll_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = _events
	_events = []
	_pending_msgs = 0
	return out


## Envía un ServerMsg (JSON) a una conexión. false si no existe, está cerrando o es demasiado grande.
func send(conn_id: int, json: String) -> bool:
	var ws: WsConnection = _ws.get(conn_id)
	return ws != null and ws.send_text(json)


## Cierra una conexión (close 1000 con ese motivo).
func close_connection(conn_id: int, reason: String) -> void:
	var ws: WsConnection = _ws.get(conn_id)
	if ws != null:
		ws.close(WsConnection.CLOSE_NORMAL, reason)


## Corta una conexión sin handshake de cierre (como un corte de red). Para pruebas y para expulsar
## clientes que no responden.
func abort_connection(conn_id: int) -> void:
	var ws: WsConnection = _ws.get(conn_id)
	if ws != null:
		ws.abort()


func _process(_delta: float) -> void:
	poll_network()


## Atiende red (aceptar, leer, escribir, UDP). Lo llama _process; los tests pueden llamarlo a mano.
func poll_network() -> void:
	if not _running and _ws.is_empty() and _http.is_empty():
		return
	var now: int = Time.get_ticks_msec()
	if _tcp != null:
		while _tcp.is_connection_available():
			var peer: StreamPeerTCP = _tcp.take_connection()
			if peer == null:
				break
			if _http.size() + _ws.size() >= max_sockets:
				peer.disconnect_from_host()
				continue
			_http.append(HttpConnection.new(TcpLink.new(peer), self))
	var i: int = 0
	while i < _http.size():
		var h: HttpConnection = _http[i]
		h.process(now)
		if h.is_finished():
			_http.remove_at(i)
		else:
			i += 1
	for ws: WsConnection in _ws.values():
		ws.process(now)
	if _discovery != null:
		_discovery.poll()


func _notification(what: int) -> void:
	if not pause_in_background:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_was_running_before_pause = _running
		stop()
	elif what == NOTIFICATION_APPLICATION_RESUMED and _was_running_before_pause:
		_was_running_before_pause = false
		start()
	elif what == NOTIFICATION_PREDELETE or what == NOTIFICATION_WM_CLOSE_REQUEST:
		stop()


func _exit_tree() -> void:
	stop()


# ---------- usados por HttpConnection ----------

func _http_response(conn: HttpConnection, req: HttpRequestHead, head_only: bool, keep_alive: bool) -> PackedByteArray:
	if req.path == RemoteProtocol.INFO_PATH:
		var ip: String = NetUtils.best_local_for(conn.link.remote_ip, _candidate_ips())
		return StaticFileServer.response(200, "application/json; charset=utf-8", info_json(ip).to_utf8_buffer(),
			head_only, keep_alive, "Access-Control-Allow-Origin: *\r\n")
	return files.respond(req.path, head_only, keep_alive)


## Valida el handshake. Vacío = aceptado (la conexión pasa a WsConnection); si no, la respuesta de error.
func _try_upgrade(conn: HttpConnection, req: HttpRequestHead, leftover: PackedByteArray) -> PackedByteArray:
	if req.method != "GET":
		return StaticFileServer.error_response(405, "Método no permitido", false, false)
	if not req.header_has_token("Connection", "upgrade"):
		return StaticFileServer.error_response(400, "Falta Connection: Upgrade", false, false)
	if req.header("Sec-WebSocket-Version") != "13":
		return StaticFileServer.error_response(426, "Versión de WebSocket no soportada", false, false, "Sec-WebSocket-Version: 13\r\n")
	var key: String = req.header("Sec-WebSocket-Key").strip_edges()
	# 16 bytes en Base64 = 22 caracteres + "==" (se valida antes de decodificar para no ensuciar el log).
	if not _is_ws_key(key) or Marshalls.base64_to_raw(key).size() != 16:
		return StaticFileServer.error_response(400, "Sec-WebSocket-Key inválida", false, false)
	if not allow_any_origin and not WsConnection.origin_allowed(req.header("Origin"), req.header("Host")):
		return StaticFileServer.error_response(403, "Origen no permitido", false, false)
	if not _running or _ws.size() >= max_websockets:
		return StaticFileServer.error_response(503, "Demasiadas conexiones", false, false)
	var resp: String = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n" \
		+ "Sec-WebSocket-Accept: " + WsConnection.accept_key(key) + "\r\n\r\n"
	var id: int = _next_id
	_next_id += 1
	var ws := WsConnection.new(id, conn.link, resp.to_utf8_buffer(), leftover, max_message_bytes)
	ws.message.connect(_on_ws_message)
	ws.closed.connect(_on_ws_closed)
	_ws[id] = ws
	_events.append({"e": "open", "id": id, "addr": ws.remote_ip.trim_prefix("::ffff:")})
	return PackedByteArray()


static func _is_ws_key(key: String) -> bool:
	if key.length() != 24 or not key.ends_with("=="):
		return false
	for i: int in 22:
		var c: int = key.unicode_at(i)
		if not ((c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 43 or c == 47):
			return false
	return true


func _on_ws_message(ws: WsConnection, text: String) -> void:
	if _pending_msgs >= MAX_PENDING_MSGS:
		_dropped_msgs += 1
		return
	_pending_msgs += 1
	_events.append({"e": "msg", "id": ws.id, "data": text})


func _on_ws_closed(ws: WsConnection) -> void:
	if _ws.erase(ws.id):
		_events.append({"e": "close", "id": ws.id})


func _candidate_ips() -> Array[String]:
	var l: String = lan_ip()
	var out: Array[String] = NetUtils.lan_ips()
	if l != "" and not out.has(l):
		out.push_front(l)
	elif l != "":
		out.erase(l)
		out.push_front(l)
	return out


func _discovery_reply(from_ip: String) -> String:
	return info_json(NetUtils.best_local_for(from_ip, _candidate_ips()))
