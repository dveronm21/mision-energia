class_name LevelRecordOutcome
extends RefCounted
## Lo que devuelve `LevelManager.record_result`: Soles acreditados y nivel recién desbloqueado ("" si ninguno).

var soles_earned: int = 0
var newly_unlocked: String = ""


static func make(p_soles: int, p_unlocked: String) -> LevelRecordOutcome:
	var o: LevelRecordOutcome = LevelRecordOutcome.new()
	o.soles_earned = p_soles
	o.newly_unlocked = p_unlocked
	return o
