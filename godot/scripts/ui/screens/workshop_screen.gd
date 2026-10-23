class_name WorkshopScreen
extends UiScreen
## Briefing del nivel + taller de compras (paneles, baterías, kit) con presupuesto, y
## elección de boosters. Equivale a `WorkshopScreen.ts` y `.ws-*` de styles.ts: a la izquierda
## la historia del nivel, a la derecha la tarjeta blanca de compras; abajo, el presupuesto y
## "Construir".

const WARN_TEXT: Color = Color("#ffd27a")

var _deps: WorkshopDeps
var _lv: LevelDefinition
var _p: Purchase
var _picked: Array[String] = []
var _chip: WalletChip

var _row_panels: StepperRow
var _row_batteries: StepperRow
var _row_kit: StepperRow
var _spent_label: Label
var _bar_fill: Panel
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
	var shop: PanelContainer = _build_shop()

	# `.ws-grid`: columnas .85fr / 1.15fr, alineadas arriba.
	var grid: HBoxContainer = HBoxContainer.new()
	grid.add_theme_constant_override("separation", 16)
	story.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story.size_flags_stretch_ratio = 0.85
	story.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop.size_flags_stretch_ratio = 1.15
	shop.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	grid.add_child(story)
	grid.add_child(shop)

	var frame: PageFrame = UiCommon.page_frame({
		"title": "Taller", "on_back": deps.on_back, "right": [_chip] if _chip != null else [],
		"body": [grid], "footer": _build_footer(), "cls": "workshop",
	})
	root = frame.root
	_render_boosters()
	_update()


# ================================================================== historia


func _build_story(max_panels: int) -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.add_child(UiTheme.eyebrow("Nivel %d · %s" % [_lv.order, _lv.name]))
	var sub: Label = UiTheme.title(_lv.subtitle, 26)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	var story_text: Label = UiTheme.label(_lv.story, UiTheme.body(700), 16, Color("#dce7e3"))
	story_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(story_text)

	var facts: VBoxContainer = VBoxContainer.new()
	facts.add_theme_constant_override("separation", 6)
	facts.add_child(_fact(&"panel", "Hasta %d paneles de %s kW" % [max_panels, JsMath.fmt_decimal(_lv.panel_kw)]))
	facts.add_child(_fact(&"battery-plus", "Hasta %d baterías de %s kWh" % [_lv.battery_slots, JsMath.fmt_decimal(_lv.battery_kwh)]))
	facts.add_child(_fact(&"sun", "Activás a las %s; aguantá hasta las %s" % [JsMath.fmt_hour(_lv.start_hour), JsMath.fmt_hour(_lv.end_hour)]))
	if _lv.events.zonda_at_hour != LevelEvents.NO_ZONDA:
		facts.add_child(_fact(&"wind", "Pronóstico: viento Zonda a las %s" % JsMath.fmt_hour(_lv.events.zonda_at_hour), true))
	if not _lv.events.clouds.is_empty():
		facts.add_child(_fact(&"cloud", "Se esperan nubes durante el día", true))
	if _lv.events.loose_connector:
		facts.add_child(_fact(&"loose", "Un panel puede venir con un conector flojo", true))
	if _lv.has_pump:
		facts.add_child(_fact(&"pump", "Hay una bomba de agua que consume de día"))
	col.add_child(facts)
	return col


## `.ws-facts li`: ícono amarillo (naranja si es advertencia) + texto 14 px.
func _fact(icon_name: StringName, text: String, warn: bool = false) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var ic: HudIcon = HudIcon.new(icon_name, 18.0, UiTheme.WARN if warn else UiTheme.SUN)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(ic)
	var l: Label = UiTheme.label(text, UiTheme.body(700), 14, WARN_TEXT if warn else UiTheme.MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Sin esto, un Label con autowrap dentro de un HBoxContainer colapsa a su ancho mínimo
	# (casi 0) y el texto se parte letra por letra.
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


# ================================================================== compras


## `.ws-shop`: tarjeta blanca con las filas de compra y las ayudas.
func _build_shop() -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.card(20, 12.0, 0))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var eb: MarginContainer = UiCommon._margins(4, 2, 4, 2)
	eb.add_child(UiTheme.eyebrow("Taller de compras", UiTheme.SUN_INK))
	col.add_child(eb)

	_row_panels = _stepper(&"panel", "Paneles solares", "%s kW c/u · %s créditos" % [JsMath.fmt_decimal(_lv.panel_kw), UiFormat.fmt_int(_lv.prices.panel)], 1)
	col.add_child(_row_panels.root)
	_row_batteries = _stepper(&"battery-plus", "Baterías de litio", "%s kWh c/u · %s créditos" % [JsMath.fmt_decimal(_lv.battery_kwh), UiFormat.fmt_int(_lv.prices.battery)], 2)
	col.add_child(_row_batteries.root)
	_row_kit = _stepper(&"wind", "Kit anti-Zonda", "Trabas para los paneles · %s créditos" % UiFormat.fmt_int(_lv.prices.kit_zonda), 3)
	_row_kit.root.visible = _lv.events.zonda_at_hour != LevelEvents.NO_ZONDA
	col.add_child(_row_kit.root)

	var fixed: HBoxContainer = HBoxContainer.new()
	fixed.add_theme_constant_override("separation", 10)
	fixed.add_child(_item_icon(&"bolt", UiTheme.LEAF_DARK))
	fixed.add_child(_item_text("Inversor híbrido + protección", "Obligatorios · %s créditos" % UiFormat.fmt_int(_lv.prices.base_package)))
	var incl: Label = UiTheme.label("Incluidos", UiTheme.body(800), 16, UiTheme.LEAF_DARK)
	incl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var incl_pad: MarginContainer = UiCommon._margins(0, 0, 8, 0)
	incl_pad.add_child(incl)
	fixed.add_child(incl_pad)
	col.add_child(_item_panel(fixed))

	_booster_box = VBoxContainer.new()
	_booster_box.add_theme_constant_override("separation", 6)
	col.add_child(_booster_box)
	card.add_child(col)
	return card


## `.ws-item`: fila gris clara redondeada.
static func _item_panel(content: Control) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var s: StyleBoxFlat = UiTheme.box(UiTheme.PAPER_2, 16)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", s)
	p.add_child(content)
	return p


## `.ws-ic`: cuadrado blanco de 42 px con el ícono en color.
static func _item_icon(icon_name: StringName, color: Color = UiTheme.SUN_DARK) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.custom_minimum_size = Vector2(42, 42)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PAPER, 12))
	var c: CenterContainer = CenterContainer.new()
	c.add_child(HudIcon.new(icon_name, 24.0, color))
	p.add_child(c)
	return p


static func _item_text(title: String, sub: String) -> VBoxContainer:
	var txt: VBoxContainer = VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.alignment = BoxContainer.ALIGNMENT_CENTER
	txt.add_theme_constant_override("separation", 0)
	txt.add_child(UiTheme.label(title, UiTheme.display(600), 18, UiTheme.INK))
	var s: Label = UiTheme.label(sub, UiTheme.body(700), 13, UiTheme.INK_3)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.add_child(s)
	return txt


func _stepper(icon_name: StringName, title: String, sub: String, kind: int) -> StepperRow:
	var row: StepperRow = StepperRow.new()
	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(_item_icon(icon_name))
	box.add_child(_item_text(title, sub))

	var stepper: HBoxContainer = HBoxContainer.new()
	stepper.add_theme_constant_override("separation", 6)
	stepper.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.minus = _step_button(&"minus", _change.bind(kind, -1))
	stepper.add_child(row.minus)
	row.out = UiTheme.label("0", UiTheme.display(600), 26, UiTheme.INK)
	row.out.custom_minimum_size = Vector2(34, 0)
	row.out.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.out.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stepper.add_child(row.out)
	row.plus = _step_button(&"plus", _change.bind(kind, 1))
	stepper.add_child(row.plus)
	box.add_child(stepper)
	row.root = _item_panel(box)
	return row


## `.ws-step`: cuadrado oscuro de 48 px; deshabilitado queda al 30 %.
static func _step_button(icon_name: StringName, on_pressed: Callable) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(48, 48)
	UiTheme.style_button(b, UiTheme.box(UiTheme.HUD, 14))
	var c: CenterContainer = CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(HudIcon.new(icon_name, 20.0))
	b.add_child(c)
	b.draw.connect(func() -> void: b.modulate.a = 0.3 if b.disabled else 1.0)
	b.pressed.connect(on_pressed)
	return b


# ================================================================== pie


func _build_footer() -> Array[Control]:
	# `.ws-budget`: "Gastás" + cifra a la derecha, barra amarilla y resumen.
	var budget_col: VBoxContainer = VBoxContainer.new()
	budget_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	budget_col.add_theme_constant_override("separation", 5)
	var budget_row: HBoxContainer = HBoxContainer.new()
	var gastas: Label = UiTheme.label("Gastás", UiTheme.body(800), 14, UiTheme.MUTED)
	gastas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gastas.size_flags_vertical = Control.SIZE_SHRINK_END
	budget_row.add_child(gastas)
	_spent_label = UiTheme.label("", UiTheme.display(700), 22)
	budget_row.add_child(_spent_label)
	budget_col.add_child(budget_row)

	var bar: Panel = Panel.new()
	bar.custom_minimum_size = Vector2(0, 12)
	bar.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 1, 1, 0.14), 999))
	bar.clip_contents = true
	_bar_fill = Panel.new()
	_bar_fill.anchor_left = 0.0
	_bar_fill.anchor_right = 0.0
	_bar_fill.anchor_top = 0.0
	_bar_fill.anchor_bottom = 1.0
	bar.add_child(_bar_fill)
	budget_col.add_child(bar)
	_summary_label = UiTheme.label("", UiTheme.body(700), 13, UiTheme.MUTED)
	budget_col.add_child(_summary_label)

	var right: HBoxContainer = HBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	_warn_label = UiTheme.label("", UiTheme.body(800), 14, WARN_TEXT)
	_warn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_warn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_warn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warn_label.custom_minimum_size = Vector2(220, 0)
	right.add_child(_warn_label)
	_build_btn = UiCommon.action_button("Construir", _on_build, &"primary", &"bolt", true)
	_build_btn.custom_minimum_size.y = 56
	_build_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_child(_build_btn)
	return [budget_col, right]


# ================================================================== ciclo de vida


func on_enter() -> void:
	if _chip != null:
		_chip.refresh()
	_render_boosters()
	UiCommon.focus_later(_build_btn)


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
	var out: Label = (_row_panels if kind == 1 else _row_batteries if kind == 2 else _row_kit).out
	_pop_number(out)


## El número salta un poco al cambiar (realimentación inmediata del toque).
static func _pop_number(l: Label) -> void:
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(1.3, 1.3)
	l.create_tween().tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
	var fill_tween: Tween = _bar_fill.create_tween() if _bar_fill.is_inside_tree() else null
	if fill_tween != null:
		fill_tween.tween_property(_bar_fill, "anchor_right", pct, 0.2)
	else:
		_bar_fill.anchor_right = pct
	_bar_fill.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.WARN if sp > bud else UiTheme.SUN, 999))
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


# ================================================================== ayudas


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

	var head: MarginContainer = UiCommon._margins(4, 4, 4, 0)
	head.add_child(UiTheme.label("Ayudas para llevar", UiTheme.display(600), 17, UiTheme.INK))
	_booster_box.add_child(head)

	if owned.is_empty():
		var empty_row: HBoxContainer = HBoxContainer.new()
		empty_row.add_theme_constant_override("separation", 6)
		var pad: Control = Control.new()
		pad.custom_minimum_size.x = 0
		empty_row.add_child(pad)
		var empty_label: Label = UiTheme.label("No tenés ayudas todavía.", UiTheme.body(700), 14, UiTheme.INK_3)
		empty_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		empty_row.add_child(empty_label)
		if _deps.on_shop.is_valid():
			empty_row.add_child(_link_button("Ver en la tienda", _deps.on_shop))
		_booster_box.add_child(empty_row)
		return

	var list: HFlowContainer = HFlowContainer.new()
	list.add_theme_constant_override("h_separation", 8)
	list.add_theme_constant_override("v_separation", 8)
	for b: Product in owned:
		list.add_child(_booster_chip(b))
	_booster_box.add_child(list)


## `.link-btn`: texto subrayado, Nunito 800 15 oscuro.
static func _link_button(text: String, on_click: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.flat = true
	b.custom_minimum_size.y = 48
	b.add_theme_font_override("font", UiTheme.body(800))
	b.add_theme_font_size_override("font_size", 15)
	for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(state, UiTheme.INK)
	b.draw.connect(func() -> void:
		var f: Font = UiTheme.body(800)
		var w: float = f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var y: float = b.size.y / 2.0 + 11.0
		var x0: float = (b.size.x - w) / 2.0
		b.draw_line(Vector2(x0, y), Vector2(x0 + w, y), UiTheme.INK, 1.5))
	b.pressed.connect(on_click)
	UiTheme.add_press_bounce(b)
	return b


## `.ws-bst`: ficha blanca con borde; elegida, verde clara con el tilde lleno.
func _booster_chip(b: Product) -> Button:
	var on: bool = _picked.has(b.id)
	var btn: Button = Button.new()
	var title_w: float = UiTheme.body(800).get_string_size(b.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	btn.custom_minimum_size = Vector2(maxf(title_w, 60.0) + 22.0 + 28.0 + 8.0 * 3.0 + 18.0, 52)
	var normal: StyleBoxFlat = UiTheme.box(Color("#e6f4ea") if on else UiTheme.PAPER, 14, 2, UiTheme.LEAF_DARK if on else UiTheme.LINE)
	UiTheme.style_button(btn, normal)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -8
	var ic: HudIcon = HudIcon.new(_booster_icon(b.icon), 22.0, UiTheme.SUN_DARK)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var txt: VBoxContainer = VBoxContainer.new()
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	txt.alignment = BoxContainer.ALIGNMENT_CENTER
	txt.add_theme_constant_override("separation", 0)
	txt.add_child(UiTheme.label(b.title, UiTheme.body(800), 14, UiTheme.INK))
	txt.add_child(UiTheme.label("Tenés %d" % _deps.inventory.count(b.id), UiTheme.body(700), 12, UiTheme.INK_3))
	row.add_child(txt)
	var check: PanelContainer = PanelContainer.new()
	check.custom_minimum_size = Vector2(28, 28)
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	check.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.LEAF_DARK if on else UiTheme.PAPER_2, 999))
	var cc: CenterContainer = CenterContainer.new()
	cc.add_child(HudIcon.new(&"check" if on else &"plus", 16.0, UiTheme.FG if on else UiTheme.INK_3))
	check.add_child(cc)
	row.add_child(check)
	btn.add_child(row)
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
