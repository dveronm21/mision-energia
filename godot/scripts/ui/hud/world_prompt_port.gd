class_name WorldPromptPort
extends RefCounted
## Contrato del globito que sigue a la acción en pantalla (equivale a `WorldPrompt.ts`).

func show(_label: String) -> void:
	pass


func hide() -> void:
	pass


func set_screen_position(_x: float, _y: float, _visible: bool) -> void:
	pass
