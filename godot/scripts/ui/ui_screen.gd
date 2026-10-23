class_name UiScreen
extends RefCounted
## Una pantalla administrada por `ScreenManager` (equivale a `UiScreen` de `ui/types.ts`).
## Las pantallas concretas (`scripts/app/screens/`, por construir) extienden esto.

## Nodo de verdad de la pantalla.
var root: Control
## true = se superpone y deja ver la pantalla de abajo (modal, pausa).
var modal: bool = false


## Pasa a ser la pantalla de arriba de la pila.
func on_enter() -> void:
	pass


## Deja de ser la de arriba (porque se apiló otra o se quitó).
func on_leave() -> void:
	pass


## Botón "atrás" del sistema (o tecla Escape/B). true = lo manejó.
func on_back() -> bool:
	return false


## Se quitó de la pila definitivamente.
func dispose() -> void:
	pass
