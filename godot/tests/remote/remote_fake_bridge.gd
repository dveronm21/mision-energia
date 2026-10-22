class_name RemoteFakeBridge
extends RemoteBridge
## Puente en memoria que imita al servidor real. Port de app/src/remote/FakeBridge.ts (tests).
##
##   var bridge := RemoteFakeBridge.new()
##   var host := RemoteHost.new(bridge)
##   var ana := bridge.connect_client()   # abre un "WebSocket"
##   ana.hello("Ana"); host.update()
##   ana.last("welcome")["slot"]          # → 0

var clients: Dictionary = {}   # int → RemoteFakeClient
var _queue: Array = []
var _next_id: int = 1
var _url: String
var _tv_name: String


func _init(url: String = "http://192.168.0.23:8765/", p_tv_name: String = "Tele del living") -> void:
	_url = url
	_tv_name = p_tv_name


func controller_url() -> String:
	return _url


func tv_name() -> String:
	return _tv_name


func poll() -> Array:
	var out: Array = _queue
	_queue = []
	return out


func send(conn_id: int, json: String) -> bool:
	var c: RemoteFakeClient = clients.get(conn_id)
	if c == null or c.closed:
		return false
	var m: Variant = JSON.parse_string(json)
	c.receive(m as Dictionary)
	return true


func close(conn_id: int, reason: String) -> void:
	var c: RemoteFakeClient = clients.get(conn_id)
	if c == null or c.closed:
		return
	c.closed = true
	c.close_reason = reason
	# Igual que el servidor real: el cierre también se informa como evento.
	_queue.append({"e": "close", "id": conn_id})


## Abre una conexión nueva (como si una tablet abriera el WebSocket).
func connect_client(addr: String = "192.168.0.50") -> RemoteFakeClient:
	var id: int = _next_id
	_next_id += 1
	var c := RemoteFakeClient.new(self, id)
	clients[id] = c
	_queue.append({"e": "open", "id": id, "addr": addr})
	return c


## Inyecta un evento crudo (para probar entradas inválidas).
func push_event(ev: Variant) -> void:
	_queue.append(ev)


func enqueue_msg(id: int, data: String) -> void:
	_queue.append({"e": "msg", "id": id, "data": data})


func enqueue_close(id: int) -> void:
	_queue.append({"e": "close", "id": id})
