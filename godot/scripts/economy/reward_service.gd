class_name RewardService
extends RefCounted
## Regalos gratuitos (igual a `RewardService.ts`): bienvenida (una vez) y bono diario
## (una vez por día calendario local).

const KEY: String = "rewards"
const WELCOME_SOLES: int = 50
const DAILY_SOLES: int = 20

var _wallet: Wallet
var _store: SaveStore
var _clock: Callable
var _welcome_claimed: bool = false
## "AAAA-MM-DD" del último bono diario, o "".
var _last_daily: String = ""


## `clock` devuelve un Dictionary con year, month, day (como `Time.get_datetime_dict_from_system()`, hora local).
func _init(wallet: Wallet, store: SaveStore, clock: Callable = Callable()) -> void:
	_wallet = wallet
	_store = store
	_clock = clock if clock.is_valid() else func() -> Dictionary: return Time.get_datetime_dict_from_system()
	var d: Variant = store.load_value(KEY, {})
	if d is Dictionary:
		var dict: Dictionary = d
		_welcome_claimed = bool(dict.get("welcome_claimed", false))
		var last: Variant = dict.get("last_daily", null)
		_last_daily = str(last) if last is String else ""


func can_claim_welcome() -> bool:
	return not _welcome_claimed


## Devuelve los Soles acreditados (0 si ya se reclamó).
func claim_welcome() -> int:
	if _welcome_claimed:
		return 0
	_welcome_claimed = true
	_persist()
	_wallet.add(WELCOME_SOLES, "Regalo de bienvenida")
	return WELCOME_SOLES


func can_claim_daily() -> bool:
	return _last_daily != _today()


func claim_daily() -> int:
	if not can_claim_daily():
		return 0
	_last_daily = _today()
	_persist()
	_wallet.add(DAILY_SOLES, "Bono diario")
	return DAILY_SOLES


func _today() -> String:
	var d: Dictionary = _clock.call()
	return "%d-%02d-%02d" % [int(d.get("year", 0)), int(d.get("month", 0)), int(d.get("day", 0))]


func _persist() -> void:
	var last: Variant = null
	if _last_daily != "":
		last = _last_daily
	_store.save_value(KEY, {"welcome_claimed": _welcome_claimed, "last_daily": last})
