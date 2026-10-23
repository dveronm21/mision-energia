class_name ActionProvider
extends RefCounted
## Estrategia: aporta acciones según el estado de manos actual (equivale a `ActionProvider`
## de `interaction/types.ts`). Las subclases sobrescriben `collect()`.

func collect(_hands: HandsState, _out: Array[WorldAction]) -> void:
	pass
