class_name LoadSheddingPanel
extends LoadSheddingPanelPort
## "Salvá la ciudad": de noche el jugador apaga cargas NO esenciales para que la batería
## alcance. Recibe los `LoadBlock` del nivel (filtra las esenciales) y avisa cada cambio con
## `on_toggle(label, encendida)`. Equivale a `LoadSheddingPanel.ts` y `.hud-shed` de
## styles.ts: panel oscuro, grilla de 2 columnas de interruptores verdes (grises y tachados
## cuando están apagados) y el ahorro en verde claro.

const SAVING: Color = Color("#9ee6a8")
const ON_BG: Color = Color("#173a2c")
const OFF_LINE: Color = Color("#5d736e")

var root: PanelContainer
## Callable(label: String, on: bool) -> void.
var on_toggle: Callable

var _grid: GridContainer
var _saving: Label
var _items: Array[LoadShedItem] = []


func _init(toggle_cb: Callable = Callable()) -> void:
	on_toggle = toggle_cb
	root = PanelContainer.new()
	root.name = "hud-shed"
	var bg: StyleBoxFlat = UiTheme.hud_panel(16)
	bg.content_margin_left = 12
	bg.content_margin_right = 12
	bg.content_margin_top = 10
	bg.content_margin_bottom = 12
	root.add_theme_stylebox_override("panel", bg)
	root.visible = false
	root.custom_minimum_size = Vector2(440, 0)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	root.add_child(col)

	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var ic: HudIcon = HudIcon.new(&"bolt", 22.0, UiTheme.SUN)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(ic)
	var title: Label = UiTheme.label("Salvá la ciudad", UiTheme.display(700), 19)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_saving = UiTheme.label("", UiTheme.body(800), 13, SAVING)
	_saving.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_saving)
	col.add_child(head)

	var hint: Label = UiTheme.label("Apagá lo que no hace falta para que la batería llegue a la mañana.", UiTheme.body(700), 13, UiTheme.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(hint)

	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	col.add_child(_grid)


## `shed`: labels que ya están apagadas.
func set_loads(loads: Array[LoadBlock], shed: Array[String]) -> void:
	var by_label: Dictionary[String, float] = {}
	for l: LoadBlock in loads:
		if not l.essential:
			by_label[l.label] = maxf(by_label.get(l.label, 0.0), l.kw)
	for c: Node in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_items = []
	for label: String in by_label.keys():
		var item: LoadShedItem = LoadShedItem.new(label, by_label[label], not shed.has(label))
		item.button = _build_switch(item)
		_items.append(item)
		_grid.add_child(item.button)
	_update_saving()


## `.ls-switch`: botón de 52 px con perilla (riel verde + bolita) y el nombre de la carga.
func _build_switch(item: LoadShedItem) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(202, 52)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	var knob: Control = Control.new()
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.custom_minimum_size = Vector2(36, 22)
	knob.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	knob.draw.connect(func() -> void:
		var c: Color = UiTheme.LEAF if item.on else OFF_LINE
		knob.draw_circle(Vector2(11, 11), 11.0, c, true, -1.0, true)
		knob.draw_circle(Vector2(25, 11), 11.0, c, true, -1.0, true)
		knob.draw_rect(Rect2(11, 0, 14, 22), c)
		knob.draw_circle(Vector2(25.0 if item.on else 11.0, 11.0), 8.0, Color.WHITE, true, -1.0, true))
	row.add_child(knob)
	var txt: VBoxContainer = VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.alignment = BoxContainer.ALIGNMENT_CENTER
	txt.add_theme_constant_override("separation", 0)
	var name_label: Label = UiTheme.label(item.label, UiTheme.body(800), 14)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	txt.add_child(name_label)
	item.state_label = UiTheme.label("", UiTheme.body(700), 12, UiTheme.MUTED)
	txt.add_child(item.state_label)
	row.add_child(txt)
	b.add_child(row)
	b.pressed.connect(func() -> void:
		item.on = not item.on
		_paint(item, b, knob, name_label)
		_update_saving()
		if on_toggle.is_valid():
			on_toggle.call(item.label, item.on))
	_paint(item, b, knob, name_label)
	return b


func _paint(item: LoadShedItem, b: Button, knob: Control, name_label: Label) -> void:
	UiTheme.style_button(b, UiTheme.box(ON_BG if item.on else UiTheme.HUD_2, 14, 2, UiTheme.LEAF if item.on else OFF_LINE))
	item.state_label.text = "Consumo %s · %s" % [_level_word(item.kw), "prendido" if item.on else "apagado"]
	name_label.add_theme_color_override("font_color", UiTheme.FG if item.on else UiTheme.MUTED)
	knob.queue_redraw()


func _update_saving() -> void:
	var kw: float = 0.0
	for it: LoadShedItem in _items:
		if not it.on:
			kw += it.kw
	_saving.text = "Ahorrás batería" if kw > 0.0 else ""


## Consumo relativo a la carga más grande del panel (sin valores eléctricos en pantalla).
func _level_word(kw: float) -> String:
	var top: float = 0.0
	for it: LoadShedItem in _items:
		top = maxf(top, it.kw)
	if top <= 0.0 or kw >= top * 0.66:
		return "alto"
	return "medio" if kw >= top * 0.33 else "bajo"


func show() -> void:
	if not root.visible:
		UiCommon.pop_in(root, 0.92, 0.28)
	root.visible = true
	visible = true


func hide() -> void:
	root.visible = false
	visible = false
