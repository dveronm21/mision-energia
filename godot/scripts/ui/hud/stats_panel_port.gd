class_name StatsPanelPort
extends RefCounted
## Contrato del panel de estadísticas (equivale a `StatsPanel.ts`).

func set_visible(_on: bool) -> void:
	pass


func update(_snap: SimSnapshot) -> void:
	pass
