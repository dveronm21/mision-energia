class_name MissionFacts
extends RefCounted
## Lo que `MissionTracker` necesita ver de la partida (equivale a `MissionFacts` de
## `MissionTracker.ts`). `GameSession` lo implementa; mismo patrón que `SessionPort`.

func level() -> LevelDefinition:
	return null


func purchase() -> Purchase:
	return null


func world() -> PlantWorld:
	return null


func hands() -> HandsController:
	return null


func phase() -> StringName:
	return SessionPort.PHASE_BUILD


func weather() -> String:
	return WeatherSchedule.CALM


func connector() -> ConnectorFacts:
	return ConnectorFacts.new()


func won() -> bool:
	return false
