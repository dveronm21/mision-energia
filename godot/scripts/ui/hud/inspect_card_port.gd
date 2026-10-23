class_name InspectCardPort
extends RefCounted
## Contrato de la ficha de "Revisar" (equivale a `InspectCard.ts`).

var visible: bool = false


## `data`: {"title": String, "body": String, "live": String | null}.
func show(_data: Dictionary) -> void:
	visible = true


func hide() -> void:
	visible = false


func update_live(_text: Variant) -> void:
	pass
