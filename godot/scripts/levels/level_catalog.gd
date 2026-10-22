class_name LevelCatalog
extends RefCounted
## Catálogo inmutable de niveles, ordenado por `order` (equivale a `LevelCatalog.ts`).
## Se le pueden inyectar definiciones (tests/balance).

var _levels: Array[LevelDefinition] = []


## `levels` vacío = los 5 niveles de la campaña.
func _init(levels: Array[LevelDefinition] = []) -> void:
	_levels = levels.duplicate() if not levels.is_empty() else Levels.all()
	_levels.sort_custom(func(a: LevelDefinition, b: LevelDefinition) -> bool: return a.order < b.order)


func all() -> Array[LevelDefinition]:
	return _levels.duplicate()


func has_level(id: String) -> bool:
	return find_level(id) != null


## Nivel por id, o null si no existe.
func find_level(id: String) -> LevelDefinition:
	for l: LevelDefinition in _levels:
		if l.id == id:
			return l
	return null


## Nivel por id. Si no existe, registra el error y devuelve null (en la web lanzaba excepción).
func get_level(id: String) -> LevelDefinition:
	var l: LevelDefinition = find_level(id)
	if l == null:
		push_error("Nivel desconocido: %s" % id)
	return l


## Nivel que se desbloquea al completar `id` (el que lo tiene en `requires`), o null.
func next_of(id: String) -> LevelDefinition:
	for l: LevelDefinition in _levels:
		if l.requires == id:
			return l
	return null


## Costo de una compra del taller con los precios del nivel.
func cost(level: LevelDefinition, p: Purchase) -> int:
	var pr: ShopPrices = level.prices
	return pr.base_package + p.panels * pr.panel + p.batteries * pr.battery + (pr.kit_zonda if p.kit_zonda else 0)
