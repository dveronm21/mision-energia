class_name MainMenu
extends UiScreen
## Menú principal: Jugar, Tienda, Vestuario, Ajustes, saldo y bono diario.
## Equivale a `MainMenu.ts`.

var _deps: MainMenuDeps
var _chip: WalletChip
var _bonus_box: VBoxContainer


func _init(deps: MainMenuDeps) -> void:
	_deps = deps
	root = Control.new()
	root.name = "mm"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#0e2420")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 18)

	var top: HBoxContainer = HBoxContainer.new()
	var top_spacer: Control = Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(top_spacer)
	_chip = WalletChip.new(deps.wallet, deps.bus, deps.on_shop)
	top.add_child(_chip)
	col.add_child(top)

	var hero: CenterContainer = CenterContainer.new()
	var hero_col: VBoxContainer = VBoxContainer.new()
	hero_col.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_col.add_theme_constant_override("separation", 10)
	var logo_c: CenterContainer = CenterContainer.new()
	logo_c.add_child(Logo.build())
	hero_col.add_child(logo_c)
	var tag: Label = Label.new()
	tag.text = "Construí una planta solar híbrida y mantené la ciudad encendida cuando se oculta el sol."
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.custom_minimum_size = Vector2(420, 0)
	hero_col.add_child(tag)
	hero.add_child(hero_col)
	col.add_child(hero)

	var actions: VBoxContainer = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 14)
	actions.size_flags_vertical = Control.SIZE_EXPAND_FILL
	actions.alignment = BoxContainer.ALIGNMENT_END

	var play: Button = UiCommon.action_button("Jugar", deps.on_play, &"primary", &"play", true)
	actions.add_child(play)

	var tiles: HBoxContainer = HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 12)
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	tiles.add_child(_tile("Tienda", &"cart", deps.on_shop))
	tiles.add_child(_tile("Vestuario", &"helmet", deps.on_wardrobe))
	tiles.add_child(_tile("Ajustes", &"gear", deps.on_settings))
	actions.add_child(tiles)

	_bonus_box = VBoxContainer.new()
	actions.add_child(_bonus_box)
	col.add_child(actions)

	root.add_child(col)
	_render_bonus()


func _tile(label: String, icon_name: StringName, on_click: Callable) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(110, 90)
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ic: CenterContainer = CenterContainer.new()
	ic.add_child(HudIcon.new(icon_name, 30.0))
	col.add_child(ic)
	var l: Label = Label.new()
	l.text = label
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	b.add_child(col)
	if on_click.is_valid():
		b.pressed.connect(on_click)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.06)
	bg.corner_radius_top_left = 14
	bg.corner_radius_top_right = 14
	bg.corner_radius_bottom_left = 14
	bg.corner_radius_bottom_right = 14
	b.add_theme_stylebox_override("normal", bg)
	b.add_theme_stylebox_override("hover", bg)
	b.add_theme_stylebox_override("pressed", bg)
	return b


func on_enter() -> void:
	_chip.refresh()
	_render_bonus()


func dispose() -> void:
	_chip.dispose()


## Volver a pintar (ej. después de cambiar de día).
func refresh() -> void:
	on_enter()


func _render_bonus() -> void:
	for c: Node in _bonus_box.get_children():
		c.queue_free()
	var r: RewardService = _deps.rewards
	if r == null:
		_bonus_box.visible = false
		return
	_bonus_box.visible = true
	var row: HBoxContainer = _bonus_row()
	if r.can_claim_daily():
		row.add_child(HudIcon.new(&"gift", 26.0, VisualMaterials.C_SUN))
		row.add_child(_bonus_text("Bono diario", "+%s Soles" % UiFormat.fmt_int(RewardService.DAILY_SOLES)))
		row.add_child(UiCommon.action_button("Reclamar", _claim, &"secondary"))
	else:
		row.add_child(HudIcon.new(&"gift", 26.0, Color(1, 1, 1, 0.5)))
		row.add_child(_bonus_text("Bono diario", "Volvé mañana por más Soles"))
	_bonus_box.add_child(row)


func _bonus_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	return row


func _bonus_text(title: String, sub: String) -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	var t: Label = Label.new()
	t.text = title
	col.add_child(t)
	var s: Label = Label.new()
	s.text = sub
	s.add_theme_font_size_override("font_size", 12)
	s.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	col.add_child(s)
	return col


func _claim() -> void:
	var r: RewardService = _deps.rewards
	if r == null:
		return
	var got: int = r.claim_daily()
	for c: Node in _bonus_box.get_children():
		c.queue_free()
	var row: HBoxContainer = _bonus_row()
	row.add_child(HudIcon.new(&"check", 26.0, VisualMaterials.C_OK))
	row.add_child(_bonus_text("¡Sumaste %s Soles!" % UiFormat.fmt_int(got) if got > 0 else "Ya lo reclamaste hoy", "Volvé mañana por más"))
	_bonus_box.add_child(row)
	_chip.refresh()
