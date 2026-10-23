class_name MissionPanelPort
extends RefCounted
## Contrato del panel de misión (equivale a la superficie pública de `MissionPanel.ts`
## que usa `GameSession`). La UI real (`scripts/ui/hud/mission_panel.gd`) extiende esto.

func set_title(_text: String) -> void:
	pass


func set_timer_visible(_on: bool) -> void:
	pass


func set_objectives(_objectives: Array[MissionObjective]) -> void:
	pass


func set_timer(_elapsed_sec: float) -> void:
	pass


func set_collapsed(_on: bool) -> void:
	pass
