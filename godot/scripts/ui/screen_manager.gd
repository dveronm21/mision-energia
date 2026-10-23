class_name ScreenManager
extends RefCounted
## Pila de pantallas (equivale a `ScreenManager.ts`). Las pantallas "página" ocultan a las de
## abajo; las modales se superponen. Transiciones cortas (fundido + desplazamiento leve).

const ANIM_SEC: float = 0.18

var reduced_motion: bool = false

## Callable(top: UiScreen | null) -> void, uno por suscriptor.
var _listeners: Array[Callable] = []
var _stack: Array[UiScreen] = []
## Dónde se agregan los `root` de las pantallas.
var _host: Control


func _init(host: Control) -> void:
	_host = host


func size() -> int:
	return _stack.size()


func top() -> UiScreen:
	return _stack[_stack.size() - 1] if not _stack.is_empty() else null


func has(s: UiScreen) -> bool:
	return _stack.has(s)


func push(s: UiScreen) -> void:
	var prev: UiScreen = top()
	if prev != null:
		prev.on_leave()
	_stack.append(s)
	s.root.visible = true
	_host.add_child(s.root)
	_animate_in(s.root)
	_sync_visibility()
	s.on_enter()
	_emit()


## Quita la pantalla de arriba.
func pop() -> UiScreen:
	if _stack.is_empty():
		return null
	var s: UiScreen = _stack.pop_back()
	s.on_leave()
	_detach(s)
	_sync_visibility()
	var new_top: UiScreen = top()
	if new_top != null:
		new_top.on_enter()
	_emit()
	return s


## Quita una pantalla concreta (esté donde esté).
func remove(s: UiScreen) -> void:
	if top() == s:
		pop()
		return
	var i: int = _stack.find(s)
	if i < 0:
		return
	_stack.remove_at(i)
	_detach(s)
	_sync_visibility()
	_emit()


## Reemplaza la pantalla de arriba.
func replace(s: UiScreen) -> void:
	if not _stack.is_empty():
		var old: UiScreen = _stack.pop_back()
		old.on_leave()
		_detach(old, true)
	push(s)


## Vacía la pila y opcionalmente apila una nueva.
func reset(s: UiScreen = null) -> void:
	while not _stack.is_empty():
		var old: UiScreen = _stack.pop_back()
		old.on_leave()
		_detach(old, true)
	if s != null:
		push(s)
	else:
		_sync_visibility()
		_emit()


## Botón atrás de Android (o Escape). Devuelve true si alguna pantalla lo consumió.
func handle_back() -> bool:
	var t: UiScreen = top()
	if t == null:
		return false
	return t.on_back()


## Devuelve una Callable para desuscribirse (llamarla una vez).
func on_change(cb: Callable) -> Callable:
	_listeners.append(cb)
	return _unsubscribe.bind(cb)


func _unsubscribe(cb: Callable) -> void:
	var i: int = _listeners.find(cb)
	if i >= 0:
		_listeners.remove_at(i)


func _emit() -> void:
	var t: UiScreen = top()
	for cb: Callable in _listeners:
		cb.call(t)


func _sync_visibility() -> void:
	# Visible: desde la última página hacia arriba (las modales dejan ver lo de abajo).
	var last_page: int = -1
	for i: int in range(_stack.size() - 1, -1, -1):
		if not _stack[i].modal:
			last_page = i
			break
	for i: int in _stack.size():
		_stack[i].root.visible = i >= last_page
		_stack[i].root.mouse_filter = Control.MOUSE_FILTER_STOP if i == _stack.size() - 1 else Control.MOUSE_FILTER_IGNORE


func _animate_in(node: Control) -> void:
	if reduced_motion or not node.is_inside_tree():
		return
	node.modulate.a = 0.0
	node.position.y += 12.0
	var t: Tween = node.create_tween()
	t.set_parallel(true)
	t.tween_property(node, "modulate:a", 1.0, ANIM_SEC)
	t.tween_property(node, "position:y", node.position.y - 12.0, ANIM_SEC)


func _detach(s: UiScreen, immediate: bool = false) -> void:
	var node: Control = s.root
	var finish: Callable = func() -> void:
		if node.get_parent() == _host:
			_host.remove_child(node)
		s.dispose()
	if immediate or reduced_motion or not node.is_inside_tree():
		finish.call()
		return
	var t: Tween = node.create_tween()
	t.set_parallel(true)
	t.tween_property(node, "modulate:a", 0.0, ANIM_SEC)
	t.tween_property(node, "position:y", node.position.y + 12.0, ANIM_SEC)
	t.chain().tween_callback(finish)

# Nota: la web enfoca `[data-autofocus]` al entrar una pantalla (accesibilidad de teclado).
# Acá cada pantalla llama `grab_focus()` ella misma en `on_enter()` sobre el control que
# corresponda; no hace falta un paso extra en el manager.
