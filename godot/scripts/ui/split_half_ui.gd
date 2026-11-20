class_name SplitHalfUi
extends UiRootPort
## Avisos de una mitad del versus en pantalla dividida: cada partida muestra sus toasts arriba al
## centro de su propia mitad (con `UiRoot` saldrían los de las dos en el medio de la pantalla).

var root: Control


func _init() -> void:
	root = Control.new()
	root.name = "half-ui"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t: Toast = Toast.new()
	# Abajo, encima de la franja del jugador: arriba están la misión y las estadísticas, y en
	# media pantalla no queda lugar entre las dos.
	t.root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	t.root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	t.root.offset_top = -220
	root.add_child(t.root)
	toast = t


func show_toast(text: String, kind: StringName = KIND_INFO, ms: int = -1) -> void:
	var t: Toast = toast
	if ms >= 0:
		t.show(text, kind, ms)
	else:
		t.show(text, kind)
