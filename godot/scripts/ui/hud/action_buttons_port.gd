class_name ActionButtonsPort
extends RefCounted
## Contrato de la botonera de acción (equivale a `ActionButtons.ts`): el botón grande de
## acción contextual, el multímetro y "Revisar".

func set_meter_on(_on: bool) -> void:
	pass


## `state`: "normal" | "idle" | "drop".
func set_action(_label: String, _state: StringName) -> void:
	pass


func set_inspect_enabled(_on: bool) -> void:
	pass
