class_name ShopScreen
extends UiScreen
## Tienda con pestañas. Packs con dinero real pasan por control parental → procesando →
## resultado. Equivale a `ShopScreen.ts`.

var _deps: ShopDeps
var _tab: StringName
var _chip: WalletChip
var _grid: VBoxContainer
var _sheet: Control
var _tab_buttons: Dictionary[StringName, Button] = {}
## "" = no hay confirmación de compra abierta.
var _confirming: String = ""
var _busy: bool = false


func _init(deps: ShopDeps) -> void:
	_deps = deps
	_tab = deps.initial_tab
	_chip = WalletChip.new(deps.wallet, deps.bus)

	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	var tab_defs: Array[Array] = [[ShopDeps.TAB_SOLES, "Soles", &"coins"], [ShopDeps.TAB_MEJORAS, "Mejoras", &"bolt"], [ShopDeps.TAB_VESTUARIO, "Vestuario", &"helmet"]]
	for pair: Array in tab_defs:
		var id: StringName = pair[0]
		var b: Button = _tab_button(pair[1], pair[2], id)
		_tab_buttons[id] = b
		tabs.add_child(b)

	_grid = VBoxContainer.new()
	_grid.add_theme_constant_override("separation", 10)
	_sheet = Control.new()
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.visible = false

	var right: Array[Control] = [tabs, _chip]
	var body: Array[Control] = []
	if _deps.shop.is_demo():
		body.append(_demo_banner())
	body.append(_grid)
	body.append(_sheet)
	var frame: PageFrame = UiCommon.page_frame({"title": "Tienda", "on_back": _back, "right": right, "body": body})
	root = frame.root
	_set_tab(_tab)


func _demo_banner() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(HudIcon.new(&"lock", 18.0))
	var l: Label = Label.new()
	l.text = "Modo demo: no se cobra dinero real"
	l.add_theme_font_size_override("font_size", 12)
	row.add_child(l)
	return row


func _tab_button(label: String, icon_name: StringName, id: StringName) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(110, 40)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_child(HudIcon.new(icon_name, 18.0))
	var t: Label = Label.new()
	t.text = label
	row.add_child(t)
	b.add_child(row)
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
	for id: StringName in _tab_buttons.keys():
		var b: Button = _tab_buttons[id]
		var bg: StyleBoxFlat = StyleBoxFlat.new()
		bg.corner_radius_top_left = 10
		bg.corner_radius_top_right = 10
		bg.corner_radius_bottom_left = 10
		bg.corner_radius_bottom_right = 10
		bg.bg_color = VisualMaterials.C_SUN if id == t else Color(1, 1, 1, 0.08)
		b.add_theme_stylebox_override("normal", bg)
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
	if list.is_empty():
		var empty: Label = Label.new()
		empty.text = "No hay productos en esta sección por ahora."
		_grid.add_child(empty)
		return
	for p: Product in list:
		_grid.add_child(_card(p))


func _card(p: Product) -> Control:
	var inv: Inventory = _deps.inventory
	var owned: int = inv.count(p.id)
	var is_cos: bool = p.kind == Product.KIND_COSMETIC
	var slot: StringName = WardrobeScreen._cosmetic_slot(p) if is_cos else &""
	var equipped: bool = is_cos and slot != &"" and inv.equipped_cosmetic(slot) == p.id

	var card: PanelContainer = PanelContainer.new()
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.05)
	bg.corner_radius_top_left = 14
	bg.corner_radius_top_right = 14
	bg.corner_radius_bottom_left = 14
	bg.corner_radius_bottom_right = 14
	bg.content_margin_left = 16
	bg.content_margin_right = 16
	bg.content_margin_top = 12
	bg.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", bg)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)

	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	if is_cos and slot != &"":
		var swatch: ColorRect = ColorRect.new()
		swatch.custom_minimum_size = Vector2(30, 30)
		swatch.color = WardrobeScreen._color_for(p, slot)
		head.add_child(swatch)
	else:
		head.add_child(HudIcon.new(_icon_for(p.icon), 28.0))
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title: Label = Label.new()
	title.text = p.title
	title.add_theme_font_size_override("font_size", 16)
	titles.add_child(title)
	if p.kind == Product.KIND_TOKEN_PACK and p.soles > 0:
		var amount: HBoxContainer = HBoxContainer.new()
		amount.add_theme_constant_override("separation", 4)
		amount.add_child(HudIcon.new(&"coins", 14.0, VisualMaterials.C_SUN))
		var amount_label: Label = Label.new()
		amount_label.text = "%s Soles" % UiFormat.fmt_int(p.soles)
		amount_label.add_theme_font_size_override("font_size", 12)
		amount.add_child(amount_label)
		titles.add_child(amount)
	if owned > 0 and not is_cos:
		var owned_label: Label = Label.new()
		owned_label.text = "Tenés %d" % owned
		owned_label.add_theme_font_size_override("font_size", 11)
		owned_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		titles.add_child(owned_label)
	head.add_child(titles)
	col.add_child(head)

	var desc: Label = Label.new()
	desc.text = p.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(desc)

	col.add_child(_card_footer(p, owned, is_cos, slot, equipped))
	card.add_child(col)
	return card


func _card_footer(p: Product, owned: int, is_cos: bool, slot: StringName, equipped: bool) -> Control:
	if p.kind == Product.KIND_TOKEN_PACK:
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var price: String = UiFormat.fmt_money(p.price_cents, p.currency) if p.price_cents > 0 else ""
		row.add_child(UiCommon.action_button("Comprar %s" % price if price != "" else "Comprar", _buy_pack.bind(p), &"primary"))
		if _deps.shop.is_demo():
			var note: Label = Label.new()
			note.text = "Precio de prueba"
			note.add_theme_font_size_override("font_size", 11)
			note.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
			row.add_child(note)
		return row

	if is_cos and owned > 0 and slot != &"":
		if equipped:
			var done: HBoxContainer = HBoxContainer.new()
			done.add_theme_constant_override("separation", 6)
			done.add_child(HudIcon.new(&"check", 18.0, VisualMaterials.C_OK))
			var done_label: Label = Label.new()
			done_label.text = "Puesto"
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
		row.add_child(UiCommon.action_button(UiFormat.fmt_int(cost), _set_tab.bind(ShopDeps.TAB_SOLES), &"ghost", &"coins"))
		var short: Label = Label.new()
		short.text = "Te faltan %s" % UiFormat.fmt_int(cost - bal)
		short.add_theme_font_size_override("font_size", 11)
		row.add_child(short)
	else:
		row.add_child(UiCommon.action_button(UiFormat.fmt_int(cost), _start_confirm.bind(p.id), &"primary", &"coins"))
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
			return &"coins"
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


func _show_processing() -> void:
	for c: Node in _sheet.get_children():
		c.queue_free()
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var col: VBoxContainer = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var title: Label = Label.new()
	title.text = "Procesando compra…"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub: Label = Label.new()
	sub.text = "Esperá un momento, no cierres el juego."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	center.add_child(col)
	_sheet.add_child(center)
	_sheet.visible = true


func _show_result(good: bool, title: String, text: String, extra_label: String, extra_run: Callable) -> void:
	for c: Node in _sheet.get_children():
		c.queue_free()
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var card: PanelContainer = PanelContainer.new()
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color("#13302a") if good else Color("#3a1d1d")
	bg.corner_radius_top_left = 18
	bg.corner_radius_top_right = 18
	bg.corner_radius_bottom_left = 18
	bg.corner_radius_bottom_right = 18
	bg.content_margin_left = 24
	bg.content_margin_right = 24
	bg.content_margin_top = 20
	bg.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", bg)
	card.custom_minimum_size = Vector2(340, 0)
	var col: VBoxContainer = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	var ic: CenterContainer = CenterContainer.new()
	ic.add_child(HudIcon.new(&"check" if good else &"close", 34.0))
	col.add_child(ic)
	var title_label: Label = Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 20)
	col.add_child(title_label)
	var text_label: Label = Label.new()
	text_label.text = text
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text_label)
	var btns: HBoxContainer = HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 10)
	if extra_label != "":
		btns.add_child(UiCommon.action_button(extra_label, func() -> void:
			extra_run.call()
			_close_sheet()
			_render(), &"secondary"))
	btns.add_child(UiCommon.action_button("Listo", _close_sheet, &"primary"))
	col.add_child(btns)
	card.add_child(col)
	center.add_child(card)
	_sheet.add_child(center)
	_sheet.visible = true


func _close_sheet() -> void:
	_sheet.visible = false
	for c: Node in _sheet.get_children():
		c.queue_free()
