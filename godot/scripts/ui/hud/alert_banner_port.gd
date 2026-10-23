class_name AlertBannerPort
extends RefCounted
## Contrato del cartel de alertas (equivale a `AlertBanner.ts`): aviso y tormenta de Zonda.

## `seconds_or_null`: cuenta regresiva, o null si no hay (p. ej. durante la tormenta misma).
func show(_title: String, _body: String, _seconds_or_null: Variant) -> void:
	pass


func hide() -> void:
	pass


func set_countdown(_seconds: float) -> void:
	pass
