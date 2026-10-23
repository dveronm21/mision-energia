class_name CrateSpot
extends RefCounted
## Un cajón del depósito y dónde va (equivale a las entradas de `LevelLayout['crates']`).

## "battery" | "protection" | "kit" (ver `CrateVisual.KINDS`).
var kind: StringName
var pos: Vector3


func _init(p_kind: StringName, p_pos: Vector3) -> void:
	kind = p_kind
	pos = p_pos
