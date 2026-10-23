class_name LevelRun
extends RefCounted
## Lo que hace falta para (re)empezar una partida: nivel, compra del taller y boosters ya
## consumidos (equivale a `LevelRun` de `App.ts`).

var level_id: String = ""
var purchase: Purchase
var boosters: Array[StringName] = []


static func make(p_level_id: String, p_purchase: Purchase, p_boosters: Array[StringName]) -> LevelRun:
	var r: LevelRun = LevelRun.new()
	r.level_id = p_level_id
	r.purchase = p_purchase
	r.boosters = p_boosters
	return r
