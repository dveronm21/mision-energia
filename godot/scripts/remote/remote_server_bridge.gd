class_name RemoteServerBridge
extends RemoteBridge
## Adaptador RemoteServer → RemoteBridge (lo que consume RemoteHost). Lo crea RemoteServer.bridge().

var _server_ref: WeakRef


func _init(server: RemoteServer) -> void:
	_server_ref = weakref(server)


func _server() -> RemoteServer:
	return _server_ref.get_ref() as RemoteServer


func controller_url() -> String:
	var s: RemoteServer = _server()
	return s.controller_url() if s != null else ""


func tv_name() -> String:
	var s: RemoteServer = _server()
	return s.tv_name if s != null else ""


func poll() -> Array:
	var s: RemoteServer = _server()
	return s.poll_events() if s != null else []


func send(conn_id: int, json: String) -> bool:
	var s: RemoteServer = _server()
	return s != null and s.send(conn_id, json)


func close(conn_id: int, reason: String) -> void:
	var s: RemoteServer = _server()
	if s != null:
		s.close_connection(conn_id, reason)
