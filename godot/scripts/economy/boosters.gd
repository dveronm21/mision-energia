class_name Boosters
extends RefCounted
## Uso de boosters (igual a `Boosters.ts`): consume del inventario y devuelve si se pudo.
## Los efectos los aplica el juego con estos números (fuente única para juego, UI y balance).

const HINT: String = "boost_hint"
const DRONE: String = "boost_drone"
const BATTERY: String = "boost_battery"
const BUDGET: String = "boost_budget"

## kWh ya cargados que suma la batería de emergencia (PlantState.bonus_kwh).
const BATTERY_BONUS_KWH: float = 4.0
## Multiplicador de presupuesto de obra del nivel.
const BUDGET_MULTIPLIER: float = 1.15

var _inventory: Inventory


func _init(inventory: Inventory) -> void:
	_inventory = inventory


func available(id: String) -> int:
	return _inventory.count(id)


func use(id: String) -> bool:
	return _inventory.consume(id)


## Presupuesto de obra con o sin boost_budget. Las estrellas se siguen midiendo contra level.budget.
func budget_for(level: LevelDefinition, boosted: bool) -> int:
	return JsMath.js_round(float(level.budget) * BUDGET_MULTIPLIER) if boosted else level.budget


## Valor para PlantState.bonus_kwh.
func bonus_kwh(boosted: bool) -> float:
	return BATTERY_BONUS_KWH if boosted else 0.0
