class_name LevelProgress
extends RefCounted
## Progreso guardado de un nivel.

var unlocked: bool = false
var best_stars: int = 0
var best_score: int = 0
var completed: bool = false


static func make(p_unlocked: bool, p_stars: int, p_score: int, p_completed: bool) -> LevelProgress:
	var p: LevelProgress = LevelProgress.new()
	p.unlocked = p_unlocked
	p.best_stars = p_stars
	p.best_score = p_score
	p.completed = p_completed
	return p


static func from_dict(d: Dictionary) -> LevelProgress:
	return LevelProgress.make(bool(d.get("unlocked", false)), int(d.get("best_stars", 0)),
		int(d.get("best_score", 0)), bool(d.get("completed", false)))


func to_dict() -> Dictionary:
	return {"unlocked": unlocked, "best_stars": best_stars, "best_score": best_score, "completed": completed}


func clone() -> LevelProgress:
	return LevelProgress.make(unlocked, best_stars, best_score, completed)
