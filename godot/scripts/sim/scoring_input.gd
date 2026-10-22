class_name ScoringInput
extends RefCounted
## Datos de fin de partida que `Scoring.evaluate` necesita.

const NO_BLACKOUT: float = -1.0
const PANELS_UNKNOWN: int = -1

var won: bool = false
## Batería final 0..1.
var final_soc_pct: float = 0.0
## Créditos de obra gastados.
var spent: int = 0
var panels_lost: int = 0
## Hora del apagón, o `NO_BLACKOUT`.
var blackout_hour: float = NO_BLACKOUT
var duration_sec: float = 0.0
var had_open_row_at_end: bool = false
var had_dirty_row_at_end: bool = false
var batteries: int = 0
## Paneles instalados (para el consejo "pocos paneles"), o `PANELS_UNKNOWN`.
var panels: int = PANELS_UNKNOWN
## true si quedaron cargas no esenciales encendidas de noche.
var non_essential_on: bool = false


func has_blackout() -> bool:
	return blackout_hour >= 0.0


func clone() -> ScoringInput:
	var i: ScoringInput = ScoringInput.new()
	i.won = won
	i.final_soc_pct = final_soc_pct
	i.spent = spent
	i.panels_lost = panels_lost
	i.blackout_hour = blackout_hour
	i.duration_sec = duration_sec
	i.had_open_row_at_end = had_open_row_at_end
	i.had_dirty_row_at_end = had_dirty_row_at_end
	i.batteries = batteries
	i.panels = panels
	i.non_essential_on = non_essential_on
	return i
