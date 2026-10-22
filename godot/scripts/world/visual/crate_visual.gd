class_name CrateVisual
extends Node3D
## Cajón de madera con ícono. kind: battery | protection | kit | panel.

const KINDS: Array[StringName] = [&"battery", &"protection", &"kit", &"panel"]

var kind: StringName
var model: Node3D


func _init(crate_kind: StringName = &"kit") -> void:
	kind = crate_kind if KINDS.has(crate_kind) else &"kit"
	name = "crate_" + String(kind)
	model = ModelLibrary.instantiate(StringName("crate_" + String(kind)))
	add_child(model)
