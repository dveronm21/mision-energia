class_name InspectEntry
extends RefCounted
## Ficha de "Revisar" (equivale a `InspectEntry` de `interaction/types.ts`).

var id: String
var pos: Vector3
var title: String
var body: String
## Callable() -> Variant (String o null): dato en vivo, o "" si no hay Callable asignado.
var live: Callable


func _init(p_id: String, p_pos: Vector3, p_title: String, p_body: String, p_live: Callable = Callable()) -> void:
	id = p_id
	pos = p_pos
	title = p_title
	body = p_body
	live = p_live


## Texto en vivo, o "" si no hay (equivale a `live?.()` de la web).
func live_text() -> String:
	var v: Variant = live_value()
	return v if v is String else ""


## Igual que `live_text()` pero sin forzar "": devuelve `null` cuando no hay dato en vivo
## (para UI que distingue "sin dato" de "cadena vacía").
func live_value() -> Variant:
	if not live.is_valid():
		return null
	return live.call()
