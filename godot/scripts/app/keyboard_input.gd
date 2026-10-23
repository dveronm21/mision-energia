class_name KeyboardInput
extends RefCounted
## Teclado (escritorio y pruebas), equivale a `KeyboardInput.ts`: WASD/flechas para caminar,
## E/Espacio acción, R revisar, M multímetro. "Atrás" (Esc) lo resuelve `App` con `ui_cancel`.
## En el tele, el OK del control remoto (Enter) también es acción si `enter_is_action`.

## Callable() -> void, cada uno.
var on_action: Callable = Callable()
var on_inspect: Callable = Callable()
var on_meter: Callable = Callable()
var enter_is_action: bool = false


## Dirección de caminata (x, y en −1..1; y negativa = adelante, igual que el joystick).
func vector() -> Vector2:
	var v: Vector2 = Vector2.ZERO
	if _down(KEY_A) or _down(KEY_LEFT):
		v.x -= 1.0
	if _down(KEY_D) or _down(KEY_RIGHT):
		v.x += 1.0
	if _down(KEY_W) or _down(KEY_UP):
		v.y -= 1.0
	if _down(KEY_S) or _down(KEY_DOWN):
		v.y += 1.0
	return v


## Procesa una tecla recién apretada. true = la consumió.
func handle(event: InputEvent) -> bool:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return false
	match k.physical_keycode:
		KEY_E, KEY_SPACE:
			return _fire(on_action)
		KEY_ENTER, KEY_KP_ENTER:
			return _fire(on_action) if enter_is_action else false
		KEY_R:
			return _fire(on_inspect)
		KEY_M:
			return _fire(on_meter)
	return false


static func _down(key: Key) -> bool:
	return Input.is_physical_key_pressed(key)


static func _fire(cb: Callable) -> bool:
	if not cb.is_valid():
		return false
	cb.call()
	return true
