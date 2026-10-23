class_name UiRootPort
extends RefCounted
## Raíz de la UI de toda la app (equivale a `UiRoot.ts`): acá `GameSession` solo usa el
## toast global (las pantallas/menús son responsabilidad de `scripts/app`, por construir).

var toast: ToastPort = ToastPort.new()

const KIND_INFO: StringName = &"info"
const KIND_GOOD: StringName = &"good"
const KIND_BAD: StringName = &"bad"


## `ms`: duración en milisegundos, o -1 para la que decida la UI.
func show_toast(_text: String, _kind: StringName = KIND_INFO, _ms: int = -1) -> void:
	pass
