class_name AndroidWifiLock
extends RefCounted
## WifiManager.WifiLock de baja latencia en Android mientras el tele atiende tablets. Sin él, el
## ahorro de energía del Wi-Fi junta los paquetes y los entrega cada ~100 ms: en la misma red la
## tablet ve 150 ms o más de latencia. Android 10+ usa WIFI_MODE_FULL_LOW_LATENCY (solo actúa con
## la app en primer plano y la pantalla prendida); antes, WIFI_MODE_FULL_HIGH_PERF.
## Requiere el permiso WAKE_LOCK en el preset. En otras plataformas no hace nada.

const MODE_FULL_HIGH_PERF: int = 3
const MODE_FULL_LOW_LATENCY: int = 4

static var _lock: Variant = null


static func acquire(tag: String = "mision-energia-tv") -> bool:
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
	var mode: int = MODE_FULL_LOW_LATENCY if android_major() >= 10 else MODE_FULL_HIGH_PERF
	var lock: Variant = wifi.call("createWifiLock", mode, tag)
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


## Versión mayor de Android ("13" → 13, "8.1.0" → 8); 0 si no se sabe.
static func android_major() -> int:
	var v: String = OS.get_version().strip_edges()
	var head: String = v.split(".")[0] if v != "" else ""
	return int(head) if head.is_valid_int() else 0
