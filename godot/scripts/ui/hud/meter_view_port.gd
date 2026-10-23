class_name MeterViewPort
extends RefCounted
## Contrato del multímetro en pantalla (equivale a `MeterView.ts`).

## `state`: "idle" | "ok" | "bad".
func set_reading(_value: String, _unit: String, _body: String, _state: StringName) -> void:
	pass


func show() -> void:
	pass


func hide() -> void:
	pass
