class_name InspectProvider
extends RefCounted
## Aporta fichas para "Revisar" (equivale a `InspectProvider` de `interaction/types.ts`).
## Las subclases sobrescriben `inspectables()`.

func inspectables(_out: Array[InspectEntry]) -> void:
	pass
