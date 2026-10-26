class_name ShopScreen
extends UiScreen
## Tienda con pestañas. Packs con dinero real pasan por control parental → procesando →
## resultado. Equivale a `ShopScreen.ts`.

const GRID_MAX_W: float = 1100.0
## Debajo de este ancho las pestañas que no están elegidas muestran solo el ícono.
const NARROW_W: float = 900.0

var _deps: ShopDeps
var _tab: StringName
var _chip: WalletChip
var _grid: GridContainer
## Tarjetas de la pestaña actual: la grilla no tiene más columnas que tarjetas.
var _card_count: int = 1
var _sheet: Control
var _tab_buttons: Dictionary[StringName, Button] = {}
## "" = no hay confirmación de compra abierta.
var _confirming: String = ""
var _busy: bool = false


func _init(deps: ShopDeps) -> void:
	_deps = deps
	_tab = deps.initial_tab
	if _tab == ShopDeps.TAB_SOLES and not deps.shop.sells_real_money():
		_tab = ShopDeps.TAB_MEJORAS
	_chip = WalletChip.new(deps.wallet, deps.bus)

	# `.tabs`: píldora oscura con borde; la pestaña elegida en sol.
	var tabs_panel: PanelContainer = PanelContainer.new()
	var tabs_bg: StyleBoxFlat = UiTheme.box(Color(0, 0, 0, 0.25), 999, 1, UiTheme.HUD_LINE)
	tabs_bg.set_content_margin_all(4)
	tabs_panel.add_theme_stylebox_override("panel", tabs_bg)
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	var tab_defs: Array[Array] = [[ShopDeps.TAB_SOLES, "Soles", &"sun"], [ShopDeps.TAB_MEJORAS, "Mejoras", &"bolt"], [ShopDeps.TAB_VESTUARIO, "Vestuario", &"helmet"]]
	for pair: Array in tab_defs:
		var id: StringName = pair[0]
		if id == ShopDeps.TAB_SOLES and not deps.shop.sells_real_money():
			continue
		var b: Button = _tab_button(pair[1], pair[2], id)
		_tab_buttons[id] = b
		tabs.add_child(b)
	tabs_panel.add_child(tabs)

	# `.shop-grid`: columnas de al menos 220 px que llenan una columna centrada de hasta 1100 px.
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.resized.connect(_fit_columns)

	var right: Array[Control] = [tabs_panel, _chip]
	var body: Array[Control] = []
	if _deps.shop.is_demo() and _deps.shop.sells_real_money():
		body.append(_demo_banner())
	body.append(UiCommon.max_width(_grid, GRID_MAX_W))
	var frame: PageFrame = UiCommon.page_frame({"title": "Tienda", "on_back": _back, "right": right, "body": body})
	root = frame.root
	# La ficha de pago tapa toda la página (`.sheet`), no ocupa lugar en la grilla.
	_sheet = Control.new()
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.visible = false
	root.add_child(_sheet)
	_set_tab(_tab)
	root.resized.connect(_fit_tabs)


func _fit_tabs() -> void:
	var narrow: bool = root.size.x < NARROW_W
	for id: StringName in _tab_buttons.keys():
		var b: Button = _tab_buttons[id]
		var show_text: bool = not narrow or id == _tab
		(b.get_meta(&"label") as Label).visible = show_text
		b.custom_minimum_size.x = float(b.get_meta(&"wide_w")) if show_text else 52.0


func _fit_columns() -> void:
	var cols: int = clampi(int((_grid.size.x + 12.0) / (220.0 + 12.0)), 1, maxi(1, _card_count))
	if cols != _grid.columns:
		_grid.columns = cols


## `.demo-banner`: franja crema con borde de sol a la izquierda.
func _demo_banner() -> Control:
	var p: PanelContainer = PanelContainer.new()
	var s: StyleBoxFlat = UiTheme.box(Color("#fff1dc"), 12)
	s.border_width_left = 6
	s.border_color = UiTheme.SUN
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", s)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var ic: HudIcon = HudIcon.new(&"lock", 18.0, UiTheme.SUN_INK)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	row.add_child(UiTheme.label("Modo demo: no se cobra dinero real", UiTheme.body(800), 15, UiTheme.INK))
	p.add_child(row)
	return p


## `.tab`: píldora de 48 px, Fredoka 17, ícono de sol (oscuro si está elegida).
func _tab_button(label: String, icon_name: StringName, id: StringName) -> Button:
	var b: Button = Button.new()
	var w: float = UiTheme.display(600).get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	b.custom_minimum_size = Vector2(w + 18.0 + 6.0 + 32.0, 48)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ic: HudIcon = HudIcon.new(icon_name, 18.0, UiTheme.SUN)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var t: Label = UiTheme.label(label, UiTheme.display(600), 17)
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(t)
	b.add_child(row)
	b.set_meta(&"label", t)
	b.set_meta(&"wide_w", b.custom_minimum_size.x)
	b.tooltip_text = label
	b.pressed.connect(_set_tab.bind(id))
	return b


func on_enter() -> void:
	_chip.refresh()
	_render()


func on_back() -> bool:
	_back()
	return true


func dispose() -> void:
	_chip.dispose()


func _back() -> void:
	if _busy:
		return
	if _sheet.visible:
		_close_sheet()
		return
	if _deps.on_back.is_valid():
		_deps.on_back.call()


func _set_tab(t: StringName) -> void:
	_tab = t
	_confirming = ""
	if root != null:
		_fit_tabs()
	for id: StringName in _tab_buttons.keys():
		var b: Button = _tab_buttons[id]
		var on: bool = id == t
		UiTheme.style_button(b, UiTheme.box(UiTheme.SUN if on else Color.TRANSPARENT, 999))
		for c: Node in b.get_node("row").get_children():
			if c is Label:
				(c as Label).add_theme_color_override("font_color", UiTheme.INK if on else UiTheme.FG)
			elif c is HudIcon:
				(c as HudIcon).stroke_color = UiTheme.INK if on else UiTheme.SUN
				(c as HudIcon).queue_redraw()
	_render()


func _products() -> Array[Product]:
	var all: Array[Product] = _deps.shop.catalog()
	var out: Array[Product] = []
	var kind: String
	match _tab:
		ShopDeps.TAB_SOLES:
			kind = Product.KIND_TOKEN_PACK
		ShopDeps.TAB_MEJORAS:
			kind = Product.KIND_BOOSTER
		_:
			kind = Product.KIND_COSMETIC
	for p: Product in all:
		if p.kind == kind:
			out.append(p)
	return out


func _render() -> void:
	for c: Node in _grid.get_children():
		c.queue_free()
	var list: Array[Product] = _products()
	_card_count = list.size()
	_fit_columns()
	if list.is_empty():
		_grid.add_child(UiTheme.label("No hay productos en esta sección por ahora.", UiTheme.body(700), 16, UiTheme.MUTED))
		return
	# Las tarjetas aparecen en cascada, una detrás de otra (solo si la grilla ya está en pantalla).
	var t: Tween = _grid.create_tween().set_parallel(true) if _grid.is_inside_tree() else null
	var i: int = 0
	for p: Product in list:
		var card: Control = _card(p)
		_grid.add_child(card)
		if t != null:
			card.modulate.a = 0.0
			t.tween_property(card, "modulate:a", 1.0, 0.18).set_delay(0.04 * i)
		i += 1


## `.shop-card`: tarjeta blanca con ícono en círculo crema, título Fredoka, descripción y pie.
func _card(p: Product) -> Control:
	var inv: Inventory = _deps.inventory
	var owned: int = inv.count(p.id)
	var is_cos: bool = p.kind == Product.KIND_COSMETIC
	var slot: StringName = WardrobeScreen._cosmetic_slot(p) if is_cos else &""
	var equipped: bool = is_cos and slot != &"" and inv.equipped_cosmetic(slot) == p.id

	var card: PanelContainer = PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UiTheme.card(18, 14.0, 5))

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)

	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var ic: PanelContainer = PanelContainer.new()
	ic.custom_minimum_size = Vector2(52, 52)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.add_theme_stylebox_override("panel", UiTheme.box(Color("#fff1dc"), 999))
	var ic_c: CenterContainer = CenterContainer.new()
	ic_c.add_child(HudIcon.new(slot if is_cos and slot != &"" else _icon_for(p.icon), 26.0, UiTheme.SUN_INK))
	ic.add_child(ic_c)
	if is_cos and slot != &"":
		# `.sc-swatch`: punto con el color del cosmético en la esquina del ícono.
		var sw: Panel = Panel.new()
		sw.custom_minimum_size = Vector2(24, 24)
		sw.position = Vector2(32, 32)
		sw.add_theme_stylebox_override("panel", UiTheme.box(WardrobeScreen._color_for(p, slot), 999, 3, Color.WHITE))
		ic.add_child(sw)
		sw.set_anchors_preset(Control.PRESET_TOP_LEFT)
	head.add_child(ic)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", 2)
	var title: Label = UiTheme.label(p.title, UiTheme.display(600), 19, UiTheme.INK)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(title)
	if p.kind == Product.KIND_TOKEN_PACK and p.soles > 0:
		var amount: HBoxContainer = HBoxContainer.new()
		amount.add_theme_constant_override("separation", 4)
		var sun: HudIcon = HudIcon.new(&"sun", 16.0, UiTheme.SUN_INK)
		sun.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		amount.add_child(sun)
		amount.add_child(UiTheme.label("%s Soles" % UiFormat.fmt_int(p.soles), UiTheme.body(800), 15, UiTheme.SUN_INK))
		titles.add_child(amount)
	if owned > 0 and not is_cos:
		titles.add_child(UiTheme.label("Tenés %d" % owned, UiTheme.body(800), 13, UiTheme.LEAF_DARK))
	head.add_child(titles)
	col.add_child(head)

	var desc: Label = UiTheme.label(p.description, UiTheme.body(700), 14, UiTheme.INK_2)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(desc)

	col.add_child(_card_footer(p, owned, is_cos, slot, equipped))
	card.add_child(col)
	return card


func _card_footer(p: Product, owned: int, is_cos: bool, slot: StringName, equipped: bool) -> Control:
	if p.kind == Product.KIND_TOKEN_PACK:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var price: String = UiFormat.fmt_money(p.price_cents, p.currency) if p.price_cents > 0 else ""
		var buy: Button = UiCommon.action_button("Comprar %s" % price if price != "" else "Comprar", _buy_pack.bind(p), &"primary")
		buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(buy)
		if _deps.shop.is_demo():
			var note: Label = UiTheme.label("Precio de prueba", UiTheme.body(800), 12, UiTheme.INK_3)
			note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(note)
		return row

	if is_cos and owned > 0 and slot != &"":
		if equipped:
			var done: HBoxContainer = HBoxContainer.new()
			done.add_theme_constant_override("separation", 6)
			done.custom_minimum_size.y = 48
			var ok: HudIcon = HudIcon.new(&"check", 18.0, UiTheme.LEAF_DARK)
			ok.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			done.add_child(ok)
			var done_label: Label = UiTheme.label("Puesto", UiTheme.body(800), 16, UiTheme.LEAF_DARK)
			done_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			done.add_child(done_label)
			return done
		return UiCommon.action_button("Ponérmelo", _equip.bind(slot, p.id), &"secondary", slot)

	var cost: int = maxi(0, p.cost_soles)
	if _confirming == p.id:
		return UiCommon.inline_confirm("¿Comprar por %s Soles?" % UiFormat.fmt_int(cost), "Comprar", _buy_soles.bind(p), _cancel_confirm)

	var bal: int = _deps.wallet.balance()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if bal < cost:
		var sells: bool = _deps.shop.sells_real_money()
		row.add_child(UiCommon.action_button(UiFormat.fmt_int(cost), _set_tab.bind(ShopDeps.TAB_SOLES) if sells else Callable(), &"ghost_ink", &"sun"))
		var missing: String = "Te faltan %s" % UiFormat.fmt_int(cost - bal)
		var short: Label = UiTheme.label(missing if sells else missing + ": ganalos jugando", UiTheme.body(800), 12, UiTheme.INK_3)
		short.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		short.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		short.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(short)
	else:
		var buy: Button = UiCommon.action_button(UiFormat.fmt_int(cost), _start_confirm.bind(p.id), &"primary", &"sun")
		buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(buy)
	return row


static func _icon_for(icon_hint: String) -> StringName:
	match icon_hint:
		"hint":
			return &"hint"
		"drone":
			return &"drone"
		"battery-plus":
			return &"battery-plus"
		"coins", "sun-small", "sun-medium", "sun-large":
			return &"sun"
		_:
			return &"star"


func _start_confirm(id: String) -> void:
	_confirming = id
	_render()


func _cancel_confirm() -> void:
	_confirming = ""
	_render()


func _equip(slot: StringName, id: String) -> void:
	_deps.inventory.equip(slot, id)
	_render()


func _buy_soles(p: Product) -> void:
	_confirming = ""
	var ok: bool = _deps.shop.buy_with_soles(p.id)
	if ok:
		if _deps.on_purchased.is_valid():
			_deps.on_purchased.call(p)
		var slot: StringName = WardrobeScreen._cosmetic_slot(p) if p.kind == Product.KIND_COSMETIC else &""
		var msg: String = ("%s ya es tuyo." % p.title) if p.kind == Product.KIND_COSMETIC else ("Sumaste 1 × %s." % p.title)
		if slot != &"":
			_show_result(true, "¡Listo!", msg, "Ponérmelo", _equip.bind(slot, p.id))
		else:
			_show_result(true, "¡Listo!", msg, "", Callable())
	else:
		_show_result(false, "No se pudo comprar", "No te alcanzan los Soles.", "", Callable())
	_render()


func _buy_pack(p: Product) -> void:
	if _busy:
		return
	var ok: bool = true
	if _deps.gate != null and _deps.screens != null:
		ok = await ParentalGateModal.ask(_deps.screens, _deps.gate)
	if not ok:
		return
	_busy = true
	_show_processing()
	var res: PaymentResult = await _deps.shop.buy_token_pack(p.id)
	_busy = false
	var demo_note: String = " Fue una compra de prueba: no se cobró dinero." if _deps.shop.is_demo() else ""
	match res.status:
		PaymentResult.APPROVED:
			if _deps.on_purchased.is_valid():
				_deps.on_purchased.call(p)
			_show_result(true, "¡Compra lista!", "Sumaste %s Soles.%s" % [UiFormat.fmt_int(p.soles), demo_note], "", Callable())
		PaymentResult.PENDING:
			_show_result(false, "Pago pendiente", "Cuando se confirme el pago, los Soles aparecen en tu saldo.", "", Callable())
		PaymentResult.CANCELLED:
			_show_result(false, "Compra cancelada", "No se cobró nada.", "", Callable())
		_:
			var msg: String = res.message if res.message != "" else "Probá de nuevo más tarde. No se cobró nada."
			_show_result(false, "No se pudo completar", msg, "", Callable())
	_render()


## `.sheet-card` con `.spinner`: aro gris con un tramo de sol que gira.
func _show_processing() -> void:
	_clear_sheet()
	var col: VBoxContainer = UiCommon.modal_card(_sheet, 420.0, 22.0, 10)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var spin: Control = Control.new()
	spin.custom_minimum_size = Vector2(52, 52)
	spin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	spin.pivot_offset = Vector2(26, 26)
	spin.draw.connect(func() -> void:
		spin.draw_arc(Vector2(26, 26), 23.0, 0.0, TAU, 40, Color("#eef2f1"), 6.0, true)
		spin.draw_arc(Vector2(26, 26), 23.0, -PI / 2.0, 0.0, 16, UiTheme.SUN, 6.0, true))
	spin.tree_entered.connect(func() -> void:
		spin.create_tween().set_loops().tween_property(spin, "rotation", TAU, 0.8).from(0.0), CONNECT_ONE_SHOT)
	col.add_child(spin)
	col.add_child(_centered(UiTheme.title("Procesando compra…", 26, UiTheme.INK)))
	col.add_child(_centered(UiTheme.label("Esperá un momento, no cierres el juego.", UiTheme.body(700), 16, UiTheme.INK_2)))
	_sheet.visible = true


## `.sheet-card`: ícono en círculo (verde si salió bien, crema si no), título, texto y botones.
func _show_result(good: bool, title: String, text: String, extra_label: String, extra_run: Callable) -> void:
	_clear_sheet()
	var col: VBoxContainer = UiCommon.modal_card(_sheet, 420.0, 22.0, 10)
	var ic: PanelContainer = PanelContainer.new()
	ic.custom_minimum_size = Vector2(60, 60)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.add_theme_stylebox_override("panel", UiTheme.box(Color("#e6f4ea") if good else Color("#ffe7cf"), 999))
	var ic_c: CenterContainer = CenterContainer.new()
	ic_c.add_child(HudIcon.new(&"check" if good else &"close", 30.0, UiTheme.LEAF_DARK if good else Color("#9a4a06")))
	ic.add_child(ic_c)
	col.add_child(ic)
	col.add_child(_centered(UiTheme.title(title, 26, UiTheme.INK)))
	col.add_child(_centered(UiTheme.label(text, UiTheme.body(700), 16, UiTheme.INK_2)))
	var btns: HBoxContainer = HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 10)
	if extra_label != "":
		btns.add_child(UiCommon.action_button(extra_label, func() -> void:
			extra_run.call()
			_close_sheet()
			_render(), &"secondary"))
	var done: Button = UiCommon.action_button("Listo", _close_sheet, &"primary")
	btns.add_child(done)
	col.add_child(btns)
	UiCommon.focus_later(done)
	_sheet.visible = true


static func _centered(l: Label) -> Label:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _clear_sheet() -> void:
	for c: Node in _sheet.get_children():
		_sheet.remove_child(c)
		c.queue_free()


func _close_sheet() -> void:
	_sheet.visible = false
	for c: Node in _sheet.get_children():
		c.queue_free()
