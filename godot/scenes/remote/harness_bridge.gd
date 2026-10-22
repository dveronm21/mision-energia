class_name RemoteHarnessBridge
extends RemoteBridge
## Puente del banco de pruebas: el banco decide qué eventos del servidor llegan al host (las
## conexiones de eco/administración de los tests no pasan) y el resto se delega en RemoteServer.

var queue: Array = []
var _server: RemoteServer


func _init(server: RemoteServer) -> void:
	_server = server


func controller_url() -> String:
	return _server.controller_url()


func tv_name() -> String:
	return _server.tv_name


func poll() -> Array:
	var out: Array = queue
	queue = []
	return out


func send(conn_id: int, json: String) -> bool:
	return _server.send(conn_id, json)


func close(conn_id: int, reason: String) -> void:
	_server.close_connection(conn_id, reason)
