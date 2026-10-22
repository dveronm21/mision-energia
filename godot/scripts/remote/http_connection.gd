class_name HttpConnection
extends RefCounted
## Una conexión TCP en fase HTTP: parsea peticiones, sirve estáticos y /api/info, y si llega
## GET /ws con Upgrade se la pasa a RemoteServer para convertirla en WsConnection (con los bytes que
## ya llegaron). HTTP/1.1 con keep-alive acotado (32 peticiones, 5 s de inactividad). Solo GET y HEAD.

const HEAD_TIMEOUT_MS: int = 5000
const MAX_REQUESTS_PER_CONNECTION: int = 32
## Tras la última respuesta se sigue leyendo (y descartando) un rato antes de cerrar, para que el
## cierre no sea un RST que le haga perder la respuesta al cliente.
const LINGER_MS: int = 500

enum State { READING, CLOSING_AFTER_FLUSH, LINGER, DONE, UPGRADED }

var link: TcpLink
var state: State = State.READING
var _server: RemoteServer
var _parser := HttpRequestParser.new()
var _served: int = 0
var _last_activity: int
var _linger_since: int = 0


func _init(p_link: TcpLink, server: RemoteServer) -> void:
	link = p_link
	_server = server
	_last_activity = Time.get_ticks_msec()


func is_finished() -> bool:
	return state == State.DONE or state == State.UPGRADED


func process(now: int) -> void:
	if is_finished():
		return
	var alive: bool = link.poll()
	var data: PackedByteArray = link.read_available(HttpRequestParser.MAX_HEAD_BYTES + 1)
	if not data.is_empty():
		_last_activity = now
	match state:
		State.READING:
			if not data.is_empty():
				_handle_bytes(data)
			if state == State.READING:
				if not alive and link.available() == 0:
					_finish()
				elif now - _last_activity > HEAD_TIMEOUT_MS:
					_finish()   # timeout de cabecera o de keep-alive
		State.CLOSING_AFTER_FLUSH:
			if not alive or link.flush():
				state = State.LINGER
				_linger_since = now
		State.LINGER:
			if not alive or now - _linger_since > LINGER_MS:
				_finish()
	if state == State.READING:
		link.flush()


func close_now() -> void:
	_finish()


func _handle_bytes(data: PackedByteArray) -> void:
	var r: HttpRequestParser.Result = _parser.feed(data)
	while true:
		if r == HttpRequestParser.Result.NEED_MORE:
			return
		if r == HttpRequestParser.Result.ERROR:
			_reply_and_close(StaticFileServer.error_response(_parser.error_status, _parser.error_message, false, false))
			return
		var req: HttpRequestHead = _parser.request
		_served += 1
		var keep_alive: bool = not req.header_has_token("Connection", "close") and req.version == "HTTP/1.1" \
			and _served < MAX_REQUESTS_PER_CONNECTION
		if req.path == RemoteProtocol.WS_PATH and req.header_has_token("Upgrade", "websocket"):
			var refusal: PackedByteArray = _server._try_upgrade(self, req, _parser.take_leftover())
			if refusal.is_empty():
				state = State.UPGRADED
			else:
				_reply_and_close(refusal)
			return
		var head_only: bool = req.method == "HEAD"
		if not head_only and req.method != "GET":
			_reply_and_close(StaticFileServer.error_response(405, "Método no permitido", false, false))
			return
		var resp: PackedByteArray = _server._http_response(self, req, head_only, keep_alive)
		if not keep_alive:
			_reply_and_close(resp)
			return
		link.write(resp)
		_parser.reset_keep_leftover()
		r = _parser.feed(PackedByteArray())


func _reply_and_close(resp: PackedByteArray) -> void:
	link.write(resp)
	state = State.CLOSING_AFTER_FLUSH


func _finish() -> void:
	if state == State.DONE or state == State.UPGRADED:
		return
	state = State.DONE
	link.close()
