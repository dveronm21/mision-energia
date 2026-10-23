class_name LoadSheddingPanel
extends LoadSheddingPanelPort
## "Salvá la ciudad": de noche el jugador apaga cargas NO esenciales para que la batería
## alcance. Recibe los `LoadBlock` del nivel (filtra las esenciales) y avisa cada cambio con
## `on_toggle(label, encendida)`. Equivale a `LoadSheddingPanel.ts`.

var root: PanelContainer
## Callable(label: String, on: bool) -> void.
var on_toggle: Callable

var _grid: VBoxContainer
var _saving: Label
var _items: Array[LoadShedItem] = []


func _init(toggle_cb: Callable = Callable()) -> void:
	on_toggle = toggle_cb
	root = PanelContainer.new()
	root.name = "hud-shed"
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.055, 0.141, 0.125, 0.88)
	bg.corner_radius_top_left = 14
	bg.corner_radius_top_right = 14
	bg.corner_radius_bottom_left = 14
	bg.corner_radius_bottom_right = 14
	bg.content_margin_left = 16
	bg.content_margin_right = 16
	bg.content_margin_top = 10
	bg.content_margin_bottom = 10
	root.add_theme_stylebox_override("panel", bg)
	root.visible = false
	root.custom_minimum_size = Vector2(300, 0)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	root.add_child(col)

	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var title: Label = Label.new()
	title.text = "Salvá la ciudad"
	title.add_theme_color_override("font_color", VisualMaterials.C_SUN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_saving = Label.new()
	head.add_child(_saving)
	col.add_child(head)

	var hint: Label = Label.new()
	hint.text = "Apagá lo que no hace falta para que la batería llegue a la mañana."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	col.add_child(hint)

	_grid = VBoxContainer.new()
	_grid.add_theme_constant_override("separation", 4)
	col.add_child(_grid)


## `shed`: labels que ya están apagadas.
func set_loads(loads: Array[LoadBlock], shed: Array[String]) -> void:
	var by_label: Dictionary[String, float] = {}
	for l: LoadBlock in loads:
		if not l.essential:
			by_label[l.label] = maxf(by_label.get(l.label, 0.0), l.kw)
	for c: Node in _grid.get_children():
		c.queue_free()
	_items = []
	for label: String in by_label.keys():
		var item: LoadShedItem = LoadShedItem.new(label, by_label[label], not shed.has(label))
		item.button = _build_switch(item)
		_items.append(item)
		_grid.add_child(item.button)
	_update_saving()


func _build_switch(item: LoadShedItem) -> Button:
	var b: Button = Button.new()
	# Ancho mínimo fijo (Button no calcula tamaño a partir de hijos Control agregados a mano).
	b.custom_minimum_size = Vector2(260, 40)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	var knob: ColorRect = ColorRect.new()
	knob.custom_minimum_size = Vector2(14, 14)
	row.add_child(knob)
	var txt: VBoxContainer = VBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = item.label
	txt.add_child(name_label)
	var kw_label: Label = Label.new()
	kw_label.text = "%s kW" % JsMath.fmt_decimal(item.kw)
	kw_label.add_theme_font_size_override("font_size", 11)
	txt.add_child(kw_label)
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(txt)
	item.state_label = Label.new()
	row.add_child(item.state_label)
	b.add_child(row)
	b.pressed.connect(func() -> void:
		item.on = not item.on
		_paint(item, knob)
		_update_saving()
		if on_toggle.is_valid():
			on_toggle.call(item.label, item.on))
	_paint(item, knob)
	return b


func _paint(item: LoadShedItem, knob: ColorRect) -> void:
	knob.color = VisualMaterials.C_OK if item.on else Color(1, 1, 1, 0.3)
	item.state_label.text = "Prendido" if item.on else "Apagado"


func _update_saving() -> void:
	var kw: float = 0.0
	for it: LoadShedItem in _items:
		if not it.on:
			kw += it.kw
	_saving.text = ("Ahorrás %s kW" % JsMath.fmt_decimal(kw)) if kw > 0.0 else ""


func show() -> void:
	root.visible = true
	visible = true


func hide() -> void:
	root.visible = false
	visible = false
