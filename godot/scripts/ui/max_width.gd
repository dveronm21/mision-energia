class_name MaxWidth
extends Container
## Columna centrada de hasta `max_w` px (el `max-width` + `margin: 0 auto` de la web): con
## pantalla ancha el contenido queda en el medio, y con pantalla angosta usa todo el ancho.

var max_w: float


func _init(width: float) -> void:
	max_w = width
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	for c: Node in get_children():
		var ctl: Control = c as Control
		if ctl == null or not ctl.visible:
			continue
		var w: float = maxf(minf(max_w, size.x), ctl.get_combined_minimum_size().x)
		fit_child_in_rect(ctl, Rect2(Vector2(maxf(0.0, (size.x - w) / 2.0), 0.0), Vector2(w, size.y)))


func _get_minimum_size() -> Vector2:
	var m: Vector2 = Vector2.ZERO
	for c: Node in get_children():
		var ctl: Control = c as Control
		if ctl != null and ctl.visible:
			m = m.max(ctl.get_combined_minimum_size())
	return m
