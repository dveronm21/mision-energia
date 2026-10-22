class_name LevelManager
extends RefCounted
## Progreso de la campaña (igual a `LevelManager.ts`). Persiste en el `SaveStore`.
## El nivel de order 1 está siempre desbloqueado; los demás se desbloquean al completar el requerido
## o pagando `unlock_cost_soles`. Soles: rewards[k] se acredita la PRIMERA vez que se alcanza la
## estrella k+1 (no se repiten al rejugar).

const KEY: String = "levels.progress"

var _catalog: LevelCatalog
var _store: SaveStore
var _wallet: Wallet
## id → LevelProgress
var _data: Dictionary[String, LevelProgress] = {}


func _init(catalog: LevelCatalog, store: SaveStore, wallet: Wallet) -> void:
	_catalog = catalog
	_store = store
	_wallet = wallet
	var d: Variant = store.load_value(KEY, {})
	if d is Dictionary:
		var dict: Dictionary = d
		for k: Variant in dict.keys():
			if dict[k] is Dictionary:
				_data[str(k)] = LevelProgress.from_dict(dict[k])


func progress(id: String) -> LevelProgress:
	var p: LevelProgress = _data[id].clone() if _data.has(id) else LevelProgress.new()
	p.unlocked = is_unlocked(id)
	return p


func is_unlocked(id: String) -> bool:
	var level: LevelDefinition = _catalog.get_level(id)
	if level == null:
		return false
	if level.order == 1 or level.requires == "":
		return true
	if _data.has(id) and _data[id].unlocked:
		return true
	return _data.has(level.requires) and _data[level.requires].completed


## Desbloqueo anticipado pagando Soles. Devuelve false si no alcanza.
func unlock_with_soles(id: String) -> bool:
	if is_unlocked(id):
		return true
	var level: LevelDefinition = _catalog.get_level(id)
	if level == null:
		return false
	if not _wallet.spend(level.unlock_cost_soles, "Desbloqueo: %s" % level.name):
		return false
	var p: LevelProgress = progress(id)
	p.unlocked = true
	_data[id] = p
	_persist()
	return true


## Registra un resultado: actualiza mejores marcas, desbloquea el siguiente y acredita Soles por estrellas NUEVAS.
func record_result(result: LevelResult) -> LevelRecordOutcome:
	var level: LevelDefinition = _catalog.get_level(result.level_id)
	if level == null:
		return LevelRecordOutcome.make(0, "")
	var prev: LevelProgress = progress(result.level_id)
	var soles_earned: int = 0
	for s: int in range(prev.best_stars, result.stars):
		if s < level.rewards.size():
			soles_earned += level.rewards[s]
	var next: LevelDefinition = _catalog.next_of(level.id) if result.won else null
	var was_next_unlocked: bool = is_unlocked(next.id) if next != null else true
	_data[level.id] = LevelProgress.make(true, maxi(prev.best_stars, result.stars),
		maxi(prev.best_score, result.score), prev.completed or result.won)
	_persist()
	if soles_earned > 0:
		_wallet.add(soles_earned, "Estrellas nuevas: %s" % level.name)
	var newly: String = next.id if (next != null and not was_next_unlocked) else ""
	return LevelRecordOutcome.make(soles_earned, newly)


## Total de estrellas de la campaña (para la pantalla de mapa).
func total_stars() -> int:
	var acc: int = 0
	for l: LevelDefinition in _catalog.all():
		if _data.has(l.id):
			acc += _data[l.id].best_stars
	return acc


func _persist() -> void:
	var out: Dictionary = {}
	for k: String in _data.keys():
		out[k] = _data[k].to_dict()
	_store.save_value(KEY, out)
