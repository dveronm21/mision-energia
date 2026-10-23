class_name LiveSource
extends RefCounted
## Lo que `Inspectables` necesita de la partida en marcha (equivale a `LiveSource` de
## `interaction/Inspectables.ts`). `GameSession` lo implementa.

func level() -> LevelDefinition:
	return null


func world() -> PlantWorld:
	return null


func is_running() -> bool:
	return false


func snapshot() -> SimSnapshot:
	return null
