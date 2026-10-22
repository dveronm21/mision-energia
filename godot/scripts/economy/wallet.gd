class_name Wallet
extends RefCounted
## Billetera de Soles persistente con historial (últimos 100 movimientos). Montos enteros positivos.
## Igual a `Wallet.ts`; `onChange` de la web es la señal `balance_changed`.

signal balance_changed(balance: int)

const KEY: String = "wallet"
const HISTORY_MAX: int = 100

var _store: SaveStore
var _bus: EventBus
var _now: Callable
var _balance: int = 0
## Cada entrada: {"at": int ms, "delta": int, "reason": String}.
var _history: Array[Dictionary] = []


## `now` devuelve milisegundos (por defecto, reloj del sistema).
func _init(store: SaveStore, bus: EventBus = null, now: Callable = Callable()) -> void:
	_store = store
	_bus = bus
	_now = now if now.is_valid() else func() -> int: return int(Time.get_unix_time_from_system() * 1000.0)
	var d: Variant = store.load_value(KEY, {})
	if d is Dictionary:
		var dict: Dictionary = d
		var raw_balance: Variant = dict.get("balance", 0)
		var b: float = float(raw_balance) if (raw_balance is float or raw_balance is int) else 0.0
		_balance = maxi(0, floori(b))
		var h: Variant = dict.get("history", [])
		if h is Array:
			for e: Variant in h:
				if e is Dictionary:
					var entry: Dictionary = e
					_history.append({"at": int(entry.get("at", 0)), "delta": int(entry.get("delta", 0)), "reason": str(entry.get("reason", ""))})


func balance() -> int:
	return _balance


func add(amount: float, reason: String) -> void:
	if is_nan(amount):
		return
	var a: int = floori(amount)
	if not (a > 0):
		return
	_apply(a, reason)


## Gasta si alcanza; devuelve false si no.
func spend(amount: float, reason: String) -> bool:
	if is_nan(amount):
		return false
	var a: int = ceili(amount)
	if not (a >= 0) or a > _balance:
		return false
	if a > 0:
		_apply(-a, reason)
	return true


## Copia del historial.
func history() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for h: Dictionary in _history:
		out.append(h.duplicate())
	return out


func _apply(delta: int, reason: String) -> void:
	_balance += delta
	_history.append({"at": int(_now.call()), "delta": delta, "reason": reason})
	if _history.size() > HISTORY_MAX:
		_history = _history.slice(_history.size() - HISTORY_MAX)
	_store.save_value(KEY, {"balance": _balance, "history": _history})
	balance_changed.emit(_balance)
	if _bus != null:
		_bus.emit_wallet_changed(_balance)
