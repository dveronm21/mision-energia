class_name MainMenu
extends UiScreen
## Menú principal: Jugar, Tienda, Vestuario, Ajustes, saldo y bono diario.
## Equivale a `MainMenu.ts`.

var _deps: MainMenuDeps
var _chip: WalletChip
var _bonus_box: VBoxContainer
var _bonus_panel: PanelContainer
var _play: Button


func _init(deps: MainMenuDeps) -> void:
	_deps = deps
	root = Control.new()
	root.name = "mm"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(UiBackdrop.new(UiBackdrop.Kind.PAGE))

	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)

	# `.mm-top`: saldo arriba a la derecha.
	var top_pad: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right"]:
		top_pad.add_theme_constant_override("margin_" + side, 16)
	top_pad.add_theme_constant_override("margin_top", 10)
	var top: HBoxContainer = HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	_chip = WalletChip.new(deps.wallet, deps.bus, deps.on_shop)
	top.add_child(_chip)
	top_pad.add_child(top)
	col.add_child(top_pad)

	# `.mm-main`: héroe (logo + lema) y acciones, lado a lado y centrados.
	var main: HBoxContainer = HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_theme_constant_override("separation", 64)

	var hero: VBoxContainer = VBoxContainer.new()
	hero.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_theme_constant_override("separation", 16)
	hero.custom_minimum_size.x = 440
	hero.add_child(Logo.build(0.82))
	var tag: Label = UiTheme.label("Construí una planta solar híbrida y mantené la ciudad encendida cuando se oculta el sol.",
		UiTheme.body(700), 20, UiTheme.MUTED)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero.add_child(tag)
	main.add_child(hero)

	var actions: VBoxContainer = VBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	actions.custom_minimum_size.x = 480

	_play = UiCommon.action_button("Jugar", deps.on_play, &"primary", &"play", true)
	_play.custom_minimum_size.y = 80
	# En tablet/TV la web agranda el "Jugar" del menú (80 px, Fredoka 30).
	for c: Node in _play.get_node("row").get_children():
		if c is Label:
			(c as Label).add_theme_font_size_override("font_size", 30)
	actions.add_child(_play)

	var tiles: HBoxContainer = HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 10)
	tiles.add_child(_tile("Tienda", &"cart", deps.on_shop))
	tiles.add_child(_tile("Vestuario", &"helmet", deps.on_wardrobe))
	tiles.add_child(_tile("Ajustes", &"gear", deps.on_settings))
	actions.add_child(tiles)

	_bonus_panel = PanelContainer.new()
	_bonus_panel.custom_minimum_size.y = 60
	_bonus_box = VBoxContainer.new()
	_bonus_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_bonus_panel.add_child(_bonus_box)
	actions.add_child(_bonus_panel)
	main.add_child(actions)
	col.add_child(main)

	root.add_child(col)
	_render_bonus()


## `.mm-tile`: tarjeta verde oscura con ícono amarillo y nombre en Fredoka.
func _tile(label: String, icon_name: StringName, on_click: Callable) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(0, 104)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTheme.style_button(b, UiTheme.lipped(UiTheme.HUD_2, UiTheme.SHADOW_DARK, 4, 18, 2, UiTheme.HUD_LINE, 6.0))
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ic: CenterContainer = CenterContainer.new()
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.add_child(HudIcon.new(icon_name, 36.0, UiTheme.SUN))
	col.add_child(ic)
	var l: Label = UiTheme.label(label, UiTheme.display(600), 19)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(l)
	b.add_child(col)
	if on_click.is_valid():
		b.pressed.connect(on_click)
	return b


func on_enter() -> void:
	_chip.refresh()
	_render_bonus()
	UiCommon.focus_later(_play)


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
		_bonus_panel.visible = false
		return
	_bonus_panel.visible = true
	var row: HBoxContainer = _bonus_row()
	row.add_child(HudIcon.new(&"gift", 26.0, UiTheme.SUN))
	if r.can_claim_daily():
		_set_bonus_style(&"ready")
		row.add_child(_bonus_text("Bono diario", "+%s Soles" % UiFormat.fmt_int(RewardService.DAILY_SOLES)))
		row.add_child(UiCommon.action_button("Reclamar", _claim, &"secondary"))
	else:
		_set_bonus_style(&"wait")
		row.add_child(_bonus_text("Bono diario", "Volvé mañana por más Soles"))
	_bonus_box.add_child(row)


## `.mm-bonus` (borde tenue), `.is-ready` (borde y fondo de sol), `.is-claimed` (borde verde).
func _set_bonus_style(state: StringName) -> void:
	var s: StyleBoxFlat
	match state:
		&"ready":
			s = UiTheme.box(Color(UiTheme.SUN, 0.12), 16, 2, UiTheme.SUN)
		&"claimed":
			s = UiTheme.box(Color(1, 1, 1, 0.06), 16, 2, UiTheme.LEAF)
		_:
			s = UiTheme.box(Color(1, 1, 1, 0.06), 16, 2, Color(UiTheme.HUD_LINE, 0.9))
	s.content_margin_left = 12
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	_bonus_panel.add_theme_stylebox_override("panel", s)


func _bonus_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	return row


func _bonus_text(title: String, sub: String) -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 0)
	col.add_child(UiTheme.label(title, UiTheme.display(600), 17))
	col.add_child(UiTheme.label(sub, UiTheme.body(700), 14, UiTheme.MUTED))
	return col


func _claim() -> void:
	var r: RewardService = _deps.rewards
	if r == null:
		return
	# Las monedas del bono salen volando desde el propio recuadro hacia el saldo.
	_chip.coins_from(_bonus_panel.get_global_rect().get_center())
	var got: int = r.claim_daily()
	for c: Node in _bonus_box.get_children():
		c.queue_free()
	_set_bonus_style(&"claimed")
	var row: HBoxContainer = _bonus_row()
	row.add_child(HudIcon.new(&"check", 26.0, UiTheme.SUN))
	row.add_child(_bonus_text("¡Sumaste %s Soles!" % UiFormat.fmt_int(got) if got > 0 else "Ya lo reclamaste hoy", "Volvé mañana por más"))
	_bonus_box.add_child(row)
	_chip.refresh()
