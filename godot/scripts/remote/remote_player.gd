class_name RemotePlayer
extends RefCounted
## Foto de un asiento ocupado (lo que necesita la UI). Port de RemotePlayer en RemoteHost.ts.

var slot: int = 0
var name: String = ""
var color: String = ""
var color_name: String = ""
## Hay una conexión viva. false = se cayó, el asiento sigue reservado hasta reserved_until.
var connected: bool = false
## Última latencia ida y vuelta informada por la tablet (ms), o -1 si aún no hay dato.
var latency_ms: int = -1
## "browser" o "app".
var device: String = "browser"
## Momento (reloj del host, ms) hasta el que se guarda el asiento si está desconectado; -1 = no aplica.
var reserved_until: int = -1


func has_latency() -> bool:
	return latency_ms >= 0


func to_dict() -> Dictionary:
	return {"slot": slot, "name": name, "color": color, "colorName": color_name, "connected": connected,
		"latencyMs": latency_ms if latency_ms >= 0 else null, "device": device,
		"reservedUntil": reserved_until if reserved_until >= 0 else null}
