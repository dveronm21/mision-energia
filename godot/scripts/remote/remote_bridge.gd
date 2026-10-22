class_name RemoteBridge
extends RefCounted
## Lo que RemoteHost necesita del transporte (equivalente a NativeRemoteBridge de protocol.ts).
## Implementaciones: RemoteServerBridge (servidor GDScript real) y RemoteFakeBridge (tests).
## Todos los métodos son baratos y no bloquean: el host llama poll() una vez por frame.


## URL para el QR, ej. "http://192.168.0.23:8765/". Vacía si no hay red o el servidor no arrancó.
func controller_url() -> String:
	return ""


func tv_name() -> String:
	return ""


## Eventos acumulados desde el último poll: {e:"open",id,addr}, {e:"msg",id,data}, {e:"close",id}.
## Garantías: "open" antes que los "msg" de esa conexión; un único "close" por cada "open".
func poll() -> Array:
	return []


## Envía un ServerMsg (JSON de texto) a una conexión. false si no existe o se rechazó.
func send(_conn_id: int, _json: String) -> bool:
	return false


## Cierra una conexión (close 1000 con ese motivo, ≤123 bytes).
func close(_conn_id: int, _reason: String) -> void:
	pass
