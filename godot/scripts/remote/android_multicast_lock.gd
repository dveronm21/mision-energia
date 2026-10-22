class_name AndroidMulticastLock
extends RefCounted
## WifiManager.MulticastLock en Android (muchos equipos descartan el broadcast UDP del
## descubrimiento si la app no lo tiene). En otras plataformas no hace nada.
## Usa el singleton AndroidRuntime + JavaObject (Godot ≥ 4.4); requiere el permiso
## CHANGE_WIFI_MULTICAST_STATE en el preset de exportación. Sin él (o en un Godot sin
## AndroidRuntime) devuelve false y el descubrimiento sigue funcionando por unicast, QR o IP.

static var _lock: Variant = null


static func acquire(tag: String = "mision-energia-discovery") -> bool:
	if _lock != null:
		return true
	if OS.get_name() != "Android" or not Engine.has_singleton("AndroidRuntime"):
		return false
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var ctx: Variant = runtime.call("getApplicationContext")
	if ctx == null:
		return false
	var wifi: Variant = ctx.call("getSystemService", "wifi")
	if wifi == null:
		return false
	var lock: Variant = wifi.call("createMulticastLock", tag)
	if lock == null:
		return false
	lock.call("setReferenceCounted", false)
	lock.call("acquire")
	_lock = lock
	return true


static func release() -> void:
	if _lock != null:
		_lock.call("release")
		_lock = null


static func is_held() -> bool:
	return _lock != null
