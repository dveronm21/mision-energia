class_name WorkshopScreen
extends UiScreen
## Briefing del nivel + taller de compras (paneles, baterías, kit) con presupuesto, y
## elección de boosters. Equivale a `WorkshopScreen.ts`.

var _deps: WorkshopDeps
var _lv: LevelDefinition
var _p: Purchase
var _picked: Array[String] = []
var _chip: WalletChip

var _row_panels: StepperRow
var _row_batteries: StepperRow
var _row_kit: StepperRow
var _spent_label: Label
var _bar_fill: ColorRect
var _warn_label: Label
var _build_btn: Button
var _summary_label: Label
var _booster_box: VBoxContainer


func _init(deps: WorkshopDeps) -> void:
	_deps = deps
	_lv = deps.level
	var max_panels: int = _lv.rows * _lv.panels_per_row
	if deps.initial != null:
		_p = deps.initial.clone()
	else:
		_p = Purchase.make(mini(max_panels, _lv.min_panels), mini(1, _lv.battery_slots), false)
	_chip = WalletChip.new(deps.wallet, deps.bus, deps.on_shop) if deps.wallet != null else null

	var story: VBoxContainer = _build_story(max_panels)
	var shop: VBoxContainer = _build_shop()

	var grid: HBoxContainer = HBoxContainer.new()
	grid.add_theme_constant_override("separation", 24)
	grid.add_child(story)
	grid.add_child(shop)

	_build_btn = UiCommon.action_button("Construir", _on_build, &"primary", &"bolt")
	var footer_left: VBoxContainer = VBoxContainer.new()
	var budget_row: HBoxContainer = HBoxContainer.new()
	budget_row.add_theme_constant_override("separation", 6)
	var gastas: Label = Label.new()
	gastas.text = "Gastás"
	budget_row.add_child(gastas)
	_spent_label = Label.new()
	budget_row.add_child(_spent_label)
	footer_left.add_child(budget_row)
	var bar_wrap: Control = Control.new()
	bar_wrap.custom_minimum_size = Vector2(220, 8)
	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.color = Color(1, 1, 1, 0.15)
	bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_wrap.add_child(bar_bg)
	_bar_fill = ColorRect.new()
	_bar_fill.color = VisualMaterials.C_OK
	_bar_fill.anchor_left = 0.0
	_bar_fill.anchor_right = 0.0
	_bar_fill.anchor_top = 0.0
	_bar_fill.anchor_bottom = 1.0
	bar_wrap.add_child(_bar_fill)
	footer_left.add_child(bar_wrap)
	_summary_label = Label.new()
	_summary_label.add_theme_font_size_override("font_size", 12)
	_summary_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	footer_left.add_child(_summary_label)

	var footer_right: VBoxContainer = VBoxContainer.new()
	_warn_label = Label.new()
	_warn_label.add_theme_color_override("font_color", VisualMaterials.C_BAD)
	footer_right.add_child(_warn_label)
	footer_right.add_child(_build_btn)

	var footer: Array[Control] = [footer_left, footer_right]
	var right: Array[Control] = []
	if _chip != null:
		right.append(_chip)
	var frame: PageFrame = UiCommon.page_frame({
		"title": "Taller", "on_back": deps.on_back, "right": right, "body": [grid], "footer": footer,
	})
	root = frame.root
	_render_boosters()
	_update()


func _build_story(max_panels: int) -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.custom_minimum_size = Vector2(340, 0)
	var eyebrow: Label = Label.new()
	eyebrow.text = "Nivel %d · %s" % [_lv.order, _lv.name]
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	col.add_child(eyebrow)
	var sub: Label = Label.new()
	sub.text = _lv.subtitle
	sub.add_theme_font_size_override("font_size", 18)
	col.add_child(sub)
	var story_text: Label = Label.new()
	story_text.text = _lv.story
	story_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(story_text)

	col.add_child(_fact(&"panel", "Hasta %d paneles de %s kW" % [max_panels, JsMath.fmt_decimal(_lv.panel_kw)]))
	col.add_child(_fact(&"battery-plus", "Hasta %d baterías de %s kWh" % [_lv.battery_slots, JsMath.fmt_decimal(_lv.battery_kwh)]))
	col.add_child(_fact(&"sun", "Activás a las %s; aguantá hasta las %s" % [JsMath.fmt_hour(_lv.start_hour), JsMath.fmt_hour(_lv.end_hour)]))
	if _lv.events.zonda_at_hour != LevelEvents.NO_ZONDA:
		col.add_child(_fact(&"wind", "Pronóstico: viento Zonda a las %s" % JsMath.fmt_hour(_lv.events.zonda_at_hour), true))
	if not _lv.events.clouds.is_empty():
		col.add_child(_fact(&"cloud", "Se esperan nubes durante el día", true))
	if _lv.events.loose_connector:
		col.add_child(_fact(&"loose", "Un panel puede venir con un conector flojo", true))
	if _lv.has_pump:
		col.add_child(_fact(&"pump", "Hay una bomba de agua que consume de día"))
	return col


func _fact(icon_name: StringName, text: String, warn: bool = false) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(HudIcon.new(icon_name, 18.0, VisualMaterials.C_WARN if warn else Color.WHITE))
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Sin esto, un Label con autowrap dentro de un HBoxContainer colapsa a su ancho mínimo
	# (casi 0) y el texto se parte letra por letra.
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if warn:
		l.add_theme_color_override("font_color", VisualMaterials.C_WARN)
	row.add_child(l)
	return row


func _build_shop() -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(340, 0)
	var eyebrow: Label = Label.new()
	eyebrow.text = "Taller de compras"
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	col.add_child(eyebrow)

	_row_panels = _stepper(&"panel", "Paneles solares", "%s kW c/u · %s créditos" % [JsMath.fmt_decimal(_lv.panel_kw), UiFormat.fmt_int(_lv.prices.panel)], 1)
	col.add_child(_row_panels.root)
	_row_batteries = _stepper(&"battery-plus", "Baterías de litio", "%s kWh c/u · %s créditos" % [JsMath.fmt_decimal(_lv.battery_kwh), UiFormat.fmt_int(_lv.prices.battery)], 2)
	col.add_child(_row_batteries.root)
	_row_kit = _stepper(&"wind", "Kit anti-Zonda", "Trabas para los paneles · %s créditos" % UiFormat.fmt_int(_lv.prices.kit_zonda), 3)
	_row_kit.root.visible = _lv.events.zonda_at_hour != LevelEvents.NO_ZONDA
	col.add_child(_row_kit.root)

	var fixed: HBoxContainer = HBoxContainer.new()
	fixed.add_theme_constant_override("separation", 10)
	fixed.add_child(HudIcon.new(&"bolt", 26.0))
	var fixed_txt: VBoxContainer = VBoxContainer.new()
	fixed_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fixed_title: Label = Label.new()
	fixed_title.text = "Inversor híbrido + protección"
	fixed_txt.add_child(fixed_title)
	var fixed_sub: Label = Label.new()
	fixed_sub.text = "Obligatorios · %s créditos" % UiFormat.fmt_int(_lv.prices.base_package)
	fixed_sub.add_theme_font_size_override("font_size", 11)
	fixed_sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	fixed_txt.add_child(fixed_sub)
	fixed.add_child(fixed_txt)
	var incl: Label = Label.new()
	incl.text = "Incluidos"
	incl.add_theme_font_size_override("font_size", 11)
	fixed.add_child(incl)
	col.add_child(fixed)

	_booster_box = VBoxContainer.new()
	_booster_box.add_theme_constant_override("separation", 8)
	col.add_child(_booster_box)
	return col


func _stepper(icon_name: StringName, title: String, sub: String, kind: int) -> StepperRow:
	var row: StepperRow = StepperRow.new()
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(HudIcon.new(icon_name, 26.0))
	var txt: VBoxContainer = VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t: Label = Label.new()
	t.text = title
	txt.add_child(t)
	var s: Label = Label.new()
	s.text = sub
	s.add_theme_font_size_override("font_size", 11)
	s.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	txt.add_child(s)
	box.add_child(txt)

	var stepper: HBoxContainer = HBoxContainer.new()
	stepper.add_theme_constant_override("separation", 6)
	row.minus = _step_button(&"minus", _change.bind(kind, -1))
	stepper.add_child(row.minus)
	row.out = Label.new()
	row.out.text = "0"
	row.out.custom_minimum_size = Vector2(28, 0)
	row.out.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stepper.add_child(row.out)
	row.plus = _step_button(&"plus", _change.bind(kind, 1))
	stepper.add_child(row.plus)
	box.add_child(stepper)
	row.root = box
	return row


static func _step_button(icon_name: StringName, on_pressed: Callable) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(36, 36)
	var c: CenterContainer = CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(HudIcon.new(icon_name, 18.0))
	b.add_child(c)
	b.pressed.connect(on_pressed)
	return b


func on_enter() -> void:
	if _chip != null:
		_chip.refresh()
	_render_boosters()


func on_back() -> bool:
	if _deps.on_back.is_valid():
		_deps.on_back.call()
	return true


func dispose() -> void:
	if _chip != null:
		_chip.dispose()


func purchase() -> Purchase:
	return _p.clone()


func spent() -> int:
	var pr: ShopPrices = _lv.prices
	return pr.base_package + _p.panels * pr.panel + _p.batteries * pr.battery + (pr.kit_zonda if _p.kit_zonda else 0)


func _change(kind: int, d: int) -> void:
	match kind:
		1:
			_p.panels += d
		2:
			_p.batteries += d
		_:
			_p.kit_zonda = d > 0
	_update()


## Presupuesto vigente: con "Presupuesto extra" elegido, el ampliado.
func budget() -> int:
	if _picked.has("boost_budget"):
		return _deps.boosters.budget_for(_lv, true)
	return _lv.budget


func _update() -> void:
	var pr: ShopPrices = _lv.prices
	var bud: int = budget()
	var max_panels: int = _lv.rows * _lv.panels_per_row
	_p.panels = clampi(_p.panels, 0, max_panels)
	_p.batteries = clampi(_p.batteries, 0, _lv.battery_slots)
	var sp: int = spent()
	var left: int = bud - sp
	_row_panels.out.text = str(_p.panels)
	_row_batteries.out.text = str(_p.batteries)
	_row_kit.out.text = "1" if _p.kit_zonda else "0"
	_row_panels.minus.disabled = _p.panels <= 0
	_row_panels.plus.disabled = _p.panels >= max_panels or left < pr.panel
	_row_batteries.minus.disabled = _p.batteries <= 0
	_row_batteries.plus.disabled = _p.batteries >= _lv.battery_slots or left < pr.battery
	_row_kit.minus.disabled = not _p.kit_zonda
	_row_kit.plus.disabled = _p.kit_zonda or left < pr.kit_zonda

	_spent_label.text = "%s / %s" % [UiFormat.fmt_int(sp), UiFormat.fmt_int(bud)]
	var pct: float = minf(1.0, float(sp) / float(bud)) if bud > 0 else 0.0
	_bar_fill.anchor_right = pct
	_bar_fill.color = VisualMaterials.C_BAD if sp > bud else VisualMaterials.C_OK
	var gen: float = _p.panels * _lv.panel_kw
	var store: float = _p.batteries * _lv.battery_kwh
	_summary_label.text = "Generás hasta %s kW · Guardás %s kWh" % [JsMath.fmt_decimal(gen), JsMath.fmt_decimal(store)]

	var msg: String = ""
	if sp > bud:
		msg = "Te pasaste del presupuesto."
	elif _p.panels < _lv.min_panels:
		msg = "Necesitás al menos %d paneles." % _lv.min_panels
	elif _p.batteries == 0:
		msg = "Sin baterías, de noche se apaga todo."
	_warn_label.text = msg
	_warn_label.visible = msg != ""
	_build_btn.disabled = sp > bud or _p.panels < _lv.min_panels


func _on_build() -> void:
	if _deps.on_build.is_valid():
		var ids: Array[String] = _picked.duplicate()
		_deps.on_build.call(_p.clone(), ids)


func _render_boosters() -> void:
	for c: Node in _booster_box.get_children():
		c.queue_free()
	var owned: Array[Product] = []
	for b: Product in _deps.boosters_catalog:
		if _deps.inventory.count(b.id) > 0:
			owned.append(b)
	var owned_ids: Array[String] = []
	for b: Product in owned:
		owned_ids.append(b.id)
	for id: String in _picked.duplicate():
		if not owned_ids.has(id):
			_picked.erase(id)

	var title: Label = Label.new()
	title.text = "Ayudas para llevar"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_booster_box.add_child(title)

	if owned.is_empty():
		var empty_row: HBoxContainer = HBoxContainer.new()
		empty_row.add_theme_constant_override("separation", 8)
		var empty_label: Label = Label.new()
		empty_label.text = "No tenés ayudas todavía."
		empty_row.add_child(empty_label)
		if _deps.on_shop.is_valid():
			empty_row.add_child(UiCommon.action_button("Ver en la tienda", _deps.on_shop, &"ghost"))
		_booster_box.add_child(empty_row)
		return

	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	for b: Product in owned:
		list.add_child(_booster_chip(b))
	_booster_box.add_child(list)


func _booster_chip(b: Product) -> Button:
	var on: bool = _picked.has(b.id)
	var btn: Button = Button.new()
	btn.custom_minimum_size = Vector2(0, 48)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_child(HudIcon.new(_booster_icon(b.icon), 22.0))
	var txt: VBoxContainer = VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t: Label = Label.new()
	t.text = b.title
	txt.add_child(t)
	var s: Label = Label.new()
	s.text = "Tenés %d" % _deps.inventory.count(b.id)
	s.add_theme_font_size_override("font_size", 11)
	txt.add_child(s)
	row.add_child(txt)
	row.add_child(HudIcon.new(&"check" if on else &"plus", 18.0))
	btn.add_child(row)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.corner_radius_top_left = 10
	bg.corner_radius_top_right = 10
	bg.corner_radius_bottom_left = 10
	bg.corner_radius_bottom_right = 10
	bg.bg_color = Color(1, 1, 1, 0.14) if on else Color(1, 1, 1, 0.06)
	btn.add_theme_stylebox_override("normal", bg)
	btn.add_theme_stylebox_override("hover", bg)
	btn.pressed.connect(_toggle_booster.bind(b.id))
	return btn


static func _booster_icon(icon_hint: String) -> StringName:
	match icon_hint:
		"hint":
			return &"hint"
		"drone":
			return &"drone"
		"battery-plus":
			return &"battery-plus"
		"coins":
			return &"coins"
		_:
			return &"star"


func _toggle_booster(id: String) -> void:
	if _picked.has(id):
		_picked.erase(id)
	else:
		_picked.append(id)
	_render_boosters()
	_update()
