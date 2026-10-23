class_name LevelMapScreen
extends UiScreen
## Mapa con los 5 niveles en un camino, estrellas, candados y desbloqueo con Soles.
## Equivale a `LevelMapScreen.ts`.

## Posiciones (0..1) de los nodos sobre el camino.
const POS: Array[Vector2] = [
	Vector2(0.10, 0.62), Vector2(0.30, 0.38), Vector2(0.50, 0.62), Vector2(0.70, 0.38), Vector2(0.90, 0.62),
]

var _deps: LevelMapDeps
var _levels: Array[LevelDefinition] = []
var _chip: WalletChip
var _map: Control
var _sheet: Control
var _nodes: Array[Control] = []


func _init(deps: LevelMapDeps) -> void:
	_deps = deps
	_levels = deps.levels.duplicate()
	_levels.sort_custom(func(a: LevelDefinition, b: LevelDefinition) -> bool: return a.order < b.order)

	_chip = WalletChip.new(deps.wallet, deps.bus, deps.on_shop)
	_map = Control.new()
	_map.custom_minimum_size = Vector2(0, 420)
	_sheet = Control.new()
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.visible = false

	var frame: PageFrame = UiCommon.page_frame({
		"title": "Elegí tu misión", "on_back": deps.on_back, "right": [_chip], "body": [_map, _sheet],
	})
	root = frame.root
	_render()


func on_enter() -> void:
	_chip.refresh()
	_render()


func on_back() -> bool:
	if _sheet.visible:
		_close_sheet()
		return true
	if _deps.on_back.is_valid():
		_deps.on_back.call()
	return true


func dispose() -> void:
	_chip.dispose()


func refresh() -> void:
	_render()


func _render() -> void:
	for c: Node in _map.get_children():
		c.queue_free()
	_nodes = []

	var path: LevelPath = LevelPath.new()
	var pts: Array[Vector2] = []
	for i: int in _levels.size():
		pts.append(POS[i % POS.size()])
	path.set_points(pts)
	_map.add_child(path)

	var next_found: bool = false
	for i: int in _levels.size():
		var lv: LevelDefinition = _levels[i]
		var p: LevelProgress = _deps.manager.progress(lv.id)
		var unlocked: bool = _deps.manager.is_unlocked(lv.id)
		var is_next: bool = unlocked and not p.completed and not next_found
		if is_next:
			next_found = true
		var node: Control = _build_node(lv, p, unlocked, is_next)
		var pos: Vector2 = POS[i % POS.size()]
		node.set_anchors_preset(Control.PRESET_TOP_LEFT)
		node.anchor_left = pos.x
		node.anchor_right = pos.x
		node.anchor_top = pos.y
		node.anchor_bottom = pos.y
		node.position = Vector2(-55, -55)
		_map.add_child(node)
		_nodes.append(node)


func _build_node(lv: LevelDefinition, p: LevelProgress, unlocked: bool, is_next: bool) -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.custom_minimum_size = Vector2(110, 110)
	col.alignment = BoxContainer.ALIGNMENT_CENTER

	var bubble: Button = Button.new()
	bubble.custom_minimum_size = Vector2(64, 64)
	var bubble_bg: StyleBoxFlat = StyleBoxFlat.new()
	bubble_bg.corner_radius_top_left = 32
	bubble_bg.corner_radius_top_right = 32
	bubble_bg.corner_radius_bottom_left = 32
	bubble_bg.corner_radius_bottom_right = 32
	if not unlocked:
		bubble_bg.bg_color = Color(1, 1, 1, 0.08)
	elif p.completed:
		bubble_bg.bg_color = VisualMaterials.C_OK
	elif is_next:
		bubble_bg.bg_color = VisualMaterials.C_SUN
	else:
		bubble_bg.bg_color = Color(1, 1, 1, 0.18)
	bubble.add_theme_stylebox_override("normal", bubble_bg)
	bubble.add_theme_stylebox_override("hover", bubble_bg)
	bubble.add_theme_stylebox_override("pressed", bubble_bg)
	var bubble_center: CenterContainer = CenterContainer.new()
	bubble_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	if unlocked:
		var num: Label = Label.new()
		num.text = str(lv.order)
		num.add_theme_font_size_override("font_size", 22)
		num.add_theme_color_override("font_color", Color("#0e2420") if (p.completed or is_next) else Color.WHITE)
		bubble_center.add_child(num)
	else:
		bubble_center.add_child(HudIcon.new(&"lock", 26.0))
	bubble.add_child(bubble_center)
	if unlocked:
		if _deps.on_play.is_valid():
			bubble.pressed.connect(_deps.on_play.bind(lv.id))
	else:
		bubble.pressed.connect(_open_locked.bind(lv))
	var bubble_wrap: CenterContainer = CenterContainer.new()
	bubble_wrap.add_child(bubble)
	col.add_child(bubble_wrap)

	var name_label: Label = Label.new()
	name_label.text = lv.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 12)
	col.add_child(name_label)

	if unlocked:
		var stars_wrap: CenterContainer = CenterContainer.new()
		stars_wrap.add_child(UiCommon.stars_row(p.best_stars, 14.0))
		col.add_child(stars_wrap)
	else:
		var cost: HBoxContainer = HBoxContainer.new()
		cost.alignment = BoxContainer.ALIGNMENT_CENTER
		cost.add_theme_constant_override("separation", 4)
		cost.add_child(HudIcon.new(&"coins", 14.0))
		var cost_label: Label = Label.new()
		cost_label.text = UiFormat.fmt_int(lv.unlock_cost_soles)
		cost_label.add_theme_font_size_override("font_size", 12)
		cost.add_child(cost_label)
		col.add_child(cost)
	return col


func _open_locked(lv: LevelDefinition) -> void:
	var req: LevelDefinition = null
	if lv.requires != "":
		for l: LevelDefinition in _levels:
			if l.id == lv.requires:
				req = l
				break
	var bal: int = _deps.wallet.balance()
	var enough: bool = bal >= lv.unlock_cost_soles

	for c: Node in _sheet.get_children():
		c.queue_free()
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color("#13302a")
	bg.corner_radius_top_left = 18
	bg.corner_radius_top_right = 18
	bg.corner_radius_bottom_left = 18
	bg.corner_radius_bottom_right = 18
	bg.content_margin_left = 22
	bg.content_margin_right = 22
	bg.content_margin_top = 18
	bg.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", bg)
	card.custom_minimum_size = Vector2(380, 0)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)

	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(HudIcon.new(&"gear", 26.0))
	var head_titles: VBoxContainer = VBoxContainer.new()
	var eb: Label = Label.new()
	eb.text = "Nivel %d" % lv.order
	eb.add_theme_font_size_override("font_size", 12)
	head_titles.add_child(eb)
	var title: Label = Label.new()
	title.text = lv.name
	title.add_theme_font_size_override("font_size", 20)
	head_titles.add_child(title)
	head.add_child(head_titles)
	col.add_child(head)

	var body: Label = Label.new()
	body.text = ("Se abre cuando completes %s. También podés desbloquearlo ahora." % req.name) if req != null else "Podés desbloquearlo ahora con Soles."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	if not enough:
		var short: Label = Label.new()
		short.text = "Te faltan %s Soles." % UiFormat.fmt_int(lv.unlock_cost_soles - bal)
		short.add_theme_color_override("font_color", VisualMaterials.C_BAD)
		col.add_child(short)

	var actions: VBoxContainer = VBoxContainer.new()
	col.add_child(actions)
	_show_locked_main(actions, lv, enough)

	card.add_child(col)
	center.add_child(card)
	_sheet.visible = true


func _show_locked_main(actions: VBoxContainer, lv: LevelDefinition, enough: bool) -> void:
	for c: Node in actions.get_children():
		c.queue_free()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiCommon.action_button("Cerrar", _close_sheet, &"ghost"))
	if enough:
		row.add_child(UiCommon.action_button("Desbloquear por %s Soles" % UiFormat.fmt_int(lv.unlock_cost_soles),
			func() -> void: _show_locked_confirm(actions, lv), &"primary"))
	elif _deps.on_shop.is_valid():
		row.add_child(UiCommon.action_button("Conseguir Soles", _deps.on_shop, &"secondary", &"cart"))
	actions.add_child(row)


func _show_locked_confirm(actions: VBoxContainer, lv: LevelDefinition) -> void:
	for c: Node in actions.get_children():
		c.queue_free()
	actions.add_child(UiCommon.inline_confirm(
		"¿Gastar %s Soles en desbloquear %s?" % [UiFormat.fmt_int(lv.unlock_cost_soles), lv.name],
		"Sí, desbloquear",
		func() -> void:
			if _deps.manager.unlock_with_soles(lv.id):
				_close_sheet()
				_render()
			else:
				_show_locked_main(actions, lv, _deps.wallet.balance() >= lv.unlock_cost_soles),
		func() -> void: _show_locked_main(actions, lv, _deps.wallet.balance() >= lv.unlock_cost_soles),
		&"primary"))


func _close_sheet() -> void:
	_sheet.visible = false
	for c: Node in _sheet.get_children():
		c.queue_free()
