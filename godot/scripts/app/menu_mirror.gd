class_name MenuMirror
extends RefCounted
## Espejo de los menús del tele en las tablets: junta los botones visibles de la pantalla de arriba
## (en orden de lectura), arma el `menu` del contexto ({v, items: [{l, f}]}) y, cuando una tablet
## toca uno (`pick`), le da el foco y lo aprieta como si fuera el OK del control remoto.
##
##   var mirror := MenuMirror.new()
##   var menu: Dictionary = mirror.scan(ui.screens.top().root)   # cada cuadro, con un menú abierto
##   mirror.pick(v, i)                                            # lo que mandó la tablet

const MAX_ITEMS: int = 16
## Metadato opcional de un botón con el texto que debe ver la tablet (gana sobre todo lo demás).
const LABEL_META: StringName = &"mirror_label"
const MAX_LABEL: int = 32
## Metadato para que un botón no aparezca en las tablets (p. ej. "Quitar" en la sala: una tablet no saca a otra).
const SKIP_META: StringName = &"mirror_skip"
## Nombre para los botones que solo tienen ícono.
const ICON_LABELS: Dictionary[StringName, String] = {
	&"back": "Volver", &"close": "Cerrar", &"plus": "+", &"minus": "−", &"pause": "Pausa",
	&"sound": "Sonido", &"mute": "Sonido", &"cart": "Tienda", &"gear": "Ajustes", &"map": "Mapa",
}

var _buttons: Array[Button] = []
var _version: int = 0


## Botones de `root` y el `menu` para el contexto de las tablets ({} si no hay ninguno).
func scan(root: Control) -> Dictionary:
	_buttons = []
	if root == null or not root.is_visible_in_tree():
		_version = 0
		return {}
	_collect(root)
	_buttons.sort_custom(func(a: Button, b: Button) -> bool:
		var ra: Rect2 = a.get_global_rect()
		var rb: Rect2 = b.get_global_rect()
		# Misma fila si se solapan en alto; si no, el de más arriba primero.
		if absf(ra.get_center().y - rb.get_center().y) > minf(ra.size.y, rb.size.y) * 0.5:
			return ra.position.y < rb.position.y
		return ra.position.x < rb.position.x)
	# "Volver" (la flecha de arriba a la izquierda) va al final: en la tablet primero las opciones.
	var backs: Array[Button] = _buttons.filter(func(b: Button) -> bool: return _is_back(b))
	_buttons = _buttons.filter(func(b: Button) -> bool: return not _is_back(b))
	_buttons.append_array(backs)
	if _buttons.size() > MAX_ITEMS:
		_buttons.resize(MAX_ITEMS)
	var items: Array = []
	var labels: PackedStringArray = PackedStringArray()
	for b: Button in _buttons:
		var l: String = label_of(b)
		labels.append(l)
		var item: Dictionary = {"l": l}
		if b.has_focus():
			item["f"] = true
		items.append(item)
	if items.is_empty():
		_version = 0
		return {}
	# La versión cambia si cambian los botones: un toque viejo (de otra pantalla) no aprieta nada.
	_version = absi(hash("|".join(labels))) % 1000000000 + 1
	return {"v": _version, "items": items}


## Aprieta el botón `i` si la tablet vio esta misma lista. true si lo apretó.
func pick(v: int, i: int) -> bool:
	if v != _version or i < 0 or i >= _buttons.size():
		return false
	var b: Button = _buttons[i]
	if not is_instance_valid(b) or not b.is_visible_in_tree() or b.disabled:
		return false
	b.grab_focus()
	b.pressed.emit()
	return true


func _collect(n: Node) -> void:
	for c: Node in n.get_children():
		var ctl: Control = c as Control
		if ctl == null or not ctl.visible:
			continue
		if c is Button:
			var b: Button = c
			if not b.disabled and not b.has_meta(SKIP_META) and b.focus_mode != Control.FOCUS_NONE and label_of(b) != "":
				_buttons.append(b)
			continue
		_collect(c)


## Texto que se ve en el botón; si es solo un ícono, un nombre para él (los +/− del taller llevan
## el título de su fila: "+ Paneles").
static func label_of(b: Button) -> String:
	if b.has_meta(LABEL_META):
		return String(b.get_meta(LABEL_META)).substr(0, MAX_LABEL)
	var t: String = b.text.strip_edges()
	if t == "":
		t = _labels_in(b)
	if t == "":
		var icon: HudIcon = _icon_in(b)
		if icon != null and ICON_LABELS.has(icon.icon_name):
			t = ICON_LABELS[icon.icon_name]
			if icon.icon_name == &"plus" or icon.icon_name == &"minus":
				var row: String = _row_title(b)
				if row != "":
					t += " " + row
	if t == "" and b.tooltip_text != "":
		t = b.tooltip_text
	return t.substr(0, MAX_LABEL)


static func _is_back(b: Button) -> bool:
	if b.text.strip_edges() != "" or _labels_in(b) != "":
		return false
	var icon: HudIcon = _icon_in(b)
	return icon != null and icon.icon_name == &"back"


static func _labels_in(n: Node) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for c: Node in n.get_children():
		if c is Label and (c as Label).visible and (c as Label).text.strip_edges() != "":
			parts.append((c as Label).text.strip_edges())
		elif not (c is Button):
			var sub: String = _labels_in(c)
			if sub != "":
				parts.append(sub)
	return " ".join(parts)


static func _icon_in(n: Node) -> HudIcon:
	for c: Node in n.get_children():
		if c is HudIcon:
			return c
		var sub: HudIcon = _icon_in(c)
		if sub != null:
			return sub
	return null


## Primer texto de la fila del botón (subiendo hasta 3 niveles, sin mirar adentro de otros botones).
static func _row_title(b: Button) -> String:
	var n: Node = b.get_parent()
	for _i: int in 3:
		if n == null:
			return ""
		var t: String = _first_label(n)
		if t != "":
			return t
		n = n.get_parent()
	return ""


static func _first_label(n: Node) -> String:
	for c: Node in n.get_children():
		if c is Button:
			continue
		if c is Label and (c as Label).text.strip_edges() != "" and not (c as Label).text.strip_edges().is_valid_int():
			return (c as Label).text.strip_edges()
		var sub: String = _first_label(c)
		if sub != "":
			return sub
	return ""
