class_name LoadSheddingPanelPort
extends RefCounted
## Contrato del panel de "Salvá la ciudad" (equivale a `LoadSheddingPanel.ts`): apagar
## cargas no esenciales de noche.

var visible: bool = false


func set_loads(_loads: Array[LoadBlock], _shed: Array[String]) -> void:
	pass


func show() -> void:
	visible = true


func hide() -> void:
	visible = false
