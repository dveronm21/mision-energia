class_name LevelResult
extends RefCounted
## Resultado evaluado de una partida.

const NO_BLACKOUT: float = -1.0

var level_id: String = ""
var won: bool = false
## 0..3
var stars: int = 0
var score: int = 0
var final_soc_pct: float = 0.0
var spent: int = 0
var budget: int = 0
var panels_lost: int = 0
## Hora del apagón, o `NO_BLACKOUT` (siempre `NO_BLACKOUT` si ganó).
var blackout_hour: float = NO_BLACKOUT
var duration_sec: float = 0.0
## Consejos didácticos según qué falló (máximo 3, primero lo que más pesó).
var tips: Array[String] = []


func has_blackout() -> bool:
	return blackout_hour >= 0.0


static func make(p_level_id: String, p_won: bool, p_stars: int, p_score: int) -> LevelResult:
	var r: LevelResult = LevelResult.new()
	r.level_id = p_level_id
	r.won = p_won
	r.stars = p_stars
	r.score = p_score
	return r
