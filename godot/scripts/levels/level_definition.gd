class_name LevelDefinition
extends RefCounted
## Definición de un nivel de la campaña (equivale a `LevelDefinition` de `contracts.ts`).
## Unidades: kW, kWh; horas de juego decimales (10.5 = 10:30; 31 = 07:00 del día siguiente).
## Las 5 instancias están en `Levels.all()` (levels.gd).

const CASA: String = "casa"
const ESCUELA: String = "escuela"
const FINCA: String = "finca"
const PUEBLO: String = "pueblo"
const PARQUE: String = "parque"

var id: String = ""
## 1..5
var order: int = 0
var name: String = ""
var subtitle: String = ""
var story: String = ""
## Filas de paneles (cada fila en serie).
var rows: int = 1
var panels_per_row: int = 1
var battery_slots: int = 1
## kW pico por panel (didáctico).
var panel_kw: float = 0.0
## kWh útiles por batería.
var battery_kwh: float = 0.0
## Límite de potencia del inversor.
var inverter_kw: float = 0.0
## Créditos de obra disponibles en el taller.
var budget: int = 0
var prices: ShopPrices = ShopPrices.new()
## Mínimo de paneles para poder activar.
var min_panels: int = 1
## Consumo de la ciudad / finca.
var loads: Array[LoadBlock] = []
## Nivel con bomba solar (la carga diurna extra ya está en `loads`).
var has_pump: bool = false
var events: LevelEvents = LevelEvents.new()
## Hora al activar.
var start_hour: float = 10.0
## Hora de fin (31 = 07:00 del día siguiente).
var end_hour: float = 31.0
## Carga inicial de baterías (0..1).
var start_soc: float = 0.0
## Soles por 1, 2 y 3 estrellas.
var rewards: Array[int] = [0, 0, 0]
## ★★ si la batería final ≥ two_star_soc.
var two_star_soc: float = 0.0
## ★★★ si además el gasto ≤ three_star_spend × presupuesto y no se perdieron paneles.
var three_star_spend: float = 1.0
## Id del nivel requerido para desbloquear, o "" si ninguno.
var requires: String = ""
## Desbloqueo anticipado pagando Soles.
var unlock_cost_soles: int = 0


func max_panels() -> int:
	return rows * panels_per_row


func non_essential_labels() -> Array[String]:
	var out: Array[String] = []
	for b: LoadBlock in loads:
		if not b.essential:
			out.append(b.label)
	return out


## Copia profunda (para variantes en tests y balance).
func clone() -> LevelDefinition:
	var l: LevelDefinition = LevelDefinition.new()
	l.id = id
	l.order = order
	l.name = name
	l.subtitle = subtitle
	l.story = story
	l.rows = rows
	l.panels_per_row = panels_per_row
	l.battery_slots = battery_slots
	l.panel_kw = panel_kw
	l.battery_kwh = battery_kwh
	l.inverter_kw = inverter_kw
	l.budget = budget
	l.prices = prices.clone()
	l.min_panels = min_panels
	var ls: Array[LoadBlock] = []
	for b: LoadBlock in loads:
		ls.append(b.clone())
	l.loads = ls
	l.has_pump = has_pump
	l.events = events.clone()
	l.start_hour = start_hour
	l.end_hour = end_hour
	l.start_soc = start_soc
	l.rewards = rewards.duplicate()
	l.two_star_soc = two_star_soc
	l.three_star_spend = three_star_spend
	l.requires = requires
	l.unlock_cost_soles = unlock_cost_soles
	return l
