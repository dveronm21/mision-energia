class_name LoadShedItem
extends RefCounted
## Una carga del panel "Salvá la ciudad" (equivale a `LoadItem` de `LoadSheddingPanel.ts`).

var label: String
var kw: float
var on: bool
var button: Button
var state_label: Label


func _init(p_label: String, p_kw: float, p_on: bool) -> void:
	label = p_label
	kw = p_kw
	on = p_on
