class_name SessionMissionFacts
extends MissionFacts
## Adaptador `GameSession → MissionFacts`. GDScript no tiene herencia múltiple (la web hace
## `class GameSession implements SessionPort, MissionFacts, LiveSource`); como `GameSession`
## ya extiende `SessionPort`, este adaptador chico delega todo por composición.
##
## Ojo: todo acá son llamadas a método (no campos) porque `GameSession` expone `level`,
## `world`, `hands`, `phase`, `weather` como métodos (los exige `SessionPort`, que ya
## extiende) — no puede tener a la vez un campo y un método con el mismo nombre.

var _s: GameSession


func _init(session: GameSession) -> void:
	_s = session


func level() -> LevelDefinition:
	return _s.level()


func purchase() -> Purchase:
	return _s.purchase()


func world() -> PlantWorld:
	return _s.world()


func hands() -> HandsController:
	return _s.hands()


func phase() -> StringName:
	return _s.phase()


func weather() -> String:
	return _s.weather()


func connector() -> ConnectorFacts:
	return _s.connector


func won() -> bool:
	return _s.won()
