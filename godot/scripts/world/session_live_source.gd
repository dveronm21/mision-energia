class_name SessionLiveSource
extends LiveSource
## Adaptador `GameSession → LiveSource` (ver `SessionMissionFacts`: mismo motivo).

var _s: GameSession


func _init(session: GameSession) -> void:
	_s = session


func level() -> LevelDefinition:
	return _s.level()


func world() -> PlantWorld:
	return _s.world()


func is_running() -> bool:
	return _s.is_running()


func snapshot() -> SimSnapshot:
	return _s.snapshot()
