class_name PlantState
extends RefCounted
## Estado físico de la planta que el mundo 3D le informa al simulador en cada paso.

## Paneles instalados por fila.
var panels_per_row: Array[int] = []
## Fila abierta por conector flojo (no genera).
var row_open: Array[bool] = []
## Fila con polvo (rinde `dust_loss` menos).
var row_dirty: Array[bool] = []
## Fila en posición de defensa (horizontal, rinde 0,55).
var row_defense: Array[bool] = []
var batteries: int = 0
var protection_installed: bool = true
## Los 3 cables conectados correctamente.
var cables_ok: bool = true
## Cargas que el jugador apagó en "Salvá la ciudad" (por label).
var shed_loads: Array[String] = []
## kWh extra de la batería de emergencia (booster boost_battery). Se lee solo en `start()`.
var bonus_kwh: float = 0.0


## Planta llena para un nivel (todas las filas completas y todas las baterías), como `plantFor` de los tests web.
static func full_for(level: LevelDefinition) -> PlantState:
	var p: PlantState = PlantState.new()
	for r: int in level.rows:
		p.panels_per_row.append(level.panels_per_row)
		p.row_open.append(false)
		p.row_dirty.append(false)
		p.row_defense.append(false)
	p.batteries = level.battery_slots
	return p


func total_panels() -> int:
	var n: int = 0
	for c: int in panels_per_row:
		n += c
	return n


func any_open() -> bool:
	return row_open.has(true)


func any_dirty() -> bool:
	return row_dirty.has(true)


func clone() -> PlantState:
	var p: PlantState = PlantState.new()
	p.panels_per_row = panels_per_row.duplicate()
	p.row_open = row_open.duplicate()
	p.row_dirty = row_dirty.duplicate()
	p.row_defense = row_defense.duplicate()
	p.batteries = batteries
	p.protection_installed = protection_installed
	p.cables_ok = cables_ok
	p.shed_loads = shed_loads.duplicate()
	p.bonus_kwh = bonus_kwh
	return p
