class_name LevelMapScreen
extends UiScreen
## Mapa con los 5 niveles en un camino, estrellas, candados y desbloqueo con Soles.
## Equivale a `LevelMapScreen.ts` y `.lm-*` de styles.ts.

## Posiciones (0..1) de los nodos sobre el camino.
const POS: Array[Vector2] = [
	Vector2(0.10, 0.62), Vector2(0.30, 0.38), Vector2(0.50, 0.62), Vector2(0.70, 0.38), Vector2(0.90, 0.62),
]
const BUBBLE_PX: float = 96.0
const NODE_W: float = 180.0
const RING_SEC: float = 1.6

var _deps: LevelMapDeps
var _levels: Array[LevelDefinition] = []
var _chip: WalletChip
var _map: Control
var _sheet: Control
var _nodes: Array[Control] = []
var _tweens: Array[Tween] = []


func _init(deps: LevelMapDeps) -> void:
	_deps = deps
	_levels = deps.levels.duplicate()
	_levels.sort_custom(func(a: LevelDefinition, b: LevelDefinition) -> bool: return a.order < b.order)

	_chip = WalletChip.new(deps.wallet, deps.bus, deps.on_shop)
	_map = Control.new()
	_map.name = "lm-map"
	_map.custom_minimum_size = Vector2(0, 230)
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var frame: PageFrame = UiCommon.page_frame({
		"title": "Elegí tu misión", "on_back": deps.on_back, "right": [_chip], "body": [_map], "cls": "map",
	})
	root = frame.root
	# La ficha de nivel bloqueado tapa toda la página (`.lm-sheet`), no ocupa lugar en el cuerpo.
	_sheet = Control.new()
	_sheet.name = "lm-sheet"
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.visible = false
	root.add_child(_sheet)
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
	_kill_tweens()


func refresh() -> void:
	_render()


func _kill_tweens() -> void:
	for t: Tween in _tweens:
		if t.is_valid():
			t.kill()
	_tweens.clear()


func _render() -> void:
	_kill_tweens()
	for c: Node in _map.get_children():
		_map.remove_child(c)
		c.queue_free()
	_nodes = []

	var path: LevelPath = LevelPath.new()
	var pts: Array[Vector2] = []
	for i: int in _levels.size():
		pts.append(POS[i % POS.size()])
	path.set_points(pts)
	_map.add_child(path)

	var next_found: bool = false
	var focus_target: Button = null
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
		# El centro de la burbuja cae justo sobre el punto del camino.
		node.offset_left = -NODE_W / 2.0
		node.offset_right = NODE_W / 2.0
		node.offset_top = -BUBBLE_PX / 2.0
		node.offset_bottom = 120.0
		_map.add_child(node)
		_nodes.append(node)
		if is_next or (focus_target == null and unlocked):
			focus_target = node.get_meta(&"bubble") as Button
	if focus_target != null:
		UiCommon.focus_later(focus_target)


func _build_node(lv: LevelDefinition, p: LevelProgress, unlocked: bool, is_next: bool) -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bubble: Button = Button.new()
	bubble.custom_minimum_size = Vector2(BUBBLE_PX, BUBBLE_PX)
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bg: Color = UiTheme.SUN
	var line: Color = UiTheme.SUN_SOFT
	var lip: Color = UiTheme.SUN_DARK
	if not unlocked:
		bg = UiTheme.LOCKED
		line = UiTheme.LOCKED_LINE
		lip = UiTheme.LOCKED_SHADOW
	elif p.completed:
		bg = UiTheme.SUN_WARM
	UiTheme.style_button(bubble, UiTheme.lipped(bg, lip, 6, 999, 4, line, 0.0))
	var bubble_center: CenterContainer = CenterContainer.new()
	bubble_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	if unlocked:
		var num: Label = UiTheme.label(str(lv.order), UiTheme.display(700), 42, UiTheme.INK)
		bubble_center.add_child(num)
	else:
		bubble_center.add_child(HudIcon.new(&"lock", 30.0, UiTheme.PAPER_2))
	bubble.add_child(bubble_center)
	if unlocked:
		if _deps.on_play.is_valid():
			bubble.pressed.connect(_deps.on_play.bind(lv.id))
	else:
		bubble.pressed.connect(_open_locked.bind(lv))

	if is_next:
		bubble.add_child(_ring())
	col.add_child(bubble)
	col.set_meta(&"bubble", bubble)

	var name_label: Label = UiTheme.label(lv.name, UiTheme.display(600), 20, UiTheme.FG if unlocked else UiTheme.MUTED)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	name_label.add_theme_constant_override("shadow_offset_y", 2)
	name_label.add_theme_constant_override("shadow_outline_size", 4)
	col.add_child(name_label)

	var extra: CenterContainer = CenterContainer.new()
	extra.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if unlocked:
		extra.add_child(UiCommon.stars_row(p.best_stars, 18.0))
	else:
		extra.add_child(_cost_pill(lv.unlock_cost_soles))
	col.add_child(extra)
	return col


## `.lm-cost`: píldora oscura con el sol y el precio en Soles.
static func _cost_pill(soles: int) -> PanelContainer:
	var pill: PanelContainer = PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s: StyleBoxFlat = UiTheme.box(Color(0, 0, 0, 0.35), 999)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", s)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sun: HudIcon = HudIcon.new(&"sun", 16.0, UiTheme.SUN)
	sun.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sun)
	row.add_child(UiTheme.label(UiFormat.fmt_int(soles), UiTheme.body(800), 13, UiTheme.SUN))
	pill.add_child(row)
	return pill


## `@keyframes ring`: aro de sol que se abre 18 px y se apaga, en bucle, alrededor de la
## burbuja del nivel que sigue.
func _ring() -> Control:
	var ring: Panel = Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.show_behind_parent = true
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	var s: StyleBoxFlat = UiTheme.box(Color(UiTheme.SUN, 0.6), 999)
	ring.add_theme_stylebox_override("panel", s)
	ring.pivot_offset = Vector2(BUBBLE_PX, BUBBLE_PX) / 2.0
	var t: Tween = ring.create_tween().set_loops()
	t.tween_property(ring, "scale", Vector2.ONE * (1.0 + 36.0 / BUBBLE_PX), RING_SEC).from(Vector2.ONE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.parallel().tween_property(ring, "modulate:a", 0.0, RING_SEC).from(1.0).set_ease(Tween.EASE_OUT)
	_tweens.append(t)
	return ring


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
	dim.color = Color(9.0 / 255.0, 24.0 / 255.0, 21.0 / 255.0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
			_close_sheet())
	_sheet.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.add_child(center)

	# `.lm-card`: tarjeta blanca de 520 px.
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.card(22, 20.0))
	card.custom_minimum_size = Vector2(520, 0)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)

	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var ic: PanelContainer = PanelContainer.new()
	ic.custom_minimum_size = Vector2(48, 48)
	ic.add_theme_stylebox_override("panel", UiTheme.box(Color("#eef2f1"), 999))
	var ic_c: CenterContainer = CenterContainer.new()
	ic_c.add_child(HudIcon.new(&"lock", 26.0, UiTheme.INK))
	ic.add_child(ic_c)
	head.add_child(ic)
	var head_titles: VBoxContainer = VBoxContainer.new()
	head_titles.add_theme_constant_override("separation", 0)
	head_titles.add_child(UiTheme.eyebrow("Nivel %d" % lv.order, UiTheme.SUN_INK))
	head_titles.add_child(UiTheme.title(lv.name, 26, UiTheme.INK))
	head.add_child(head_titles)
	col.add_child(head)

	var body: Label = UiTheme.label(
		("Se abre cuando completes %s. También podés desbloquearlo ahora." % req.name) if req != null else "Podés desbloquearlo ahora con Soles.",
		UiTheme.body(700), 15, UiTheme.INK_2)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(body)
	if not enough:
		col.add_child(UiTheme.label("Te faltan %s Soles." % UiFormat.fmt_int(lv.unlock_cost_soles - bal), UiTheme.body(800), 15, Color("#9a4a06")))

	var actions: VBoxContainer = VBoxContainer.new()
	col.add_child(actions)
	_show_locked_main(actions, lv, enough)

	card.add_child(col)
	center.add_child(card)
	_sheet.visible = true
	_pop(card)


## Entrada de tarjeta (`@keyframes popIn` con un rebote extra).
static func _pop(card: Control) -> void:
	card.modulate.a = 0.4
	card.scale = Vector2(0.94, 0.94)
	card.resized.connect(func() -> void: card.pivot_offset = card.size / 2.0, CONNECT_ONE_SHOT)
	var t: Tween = card.create_tween().set_parallel(true)
	t.tween_property(card, "modulate:a", 1.0, 0.2)
	t.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_locked_main(actions: VBoxContainer, lv: LevelDefinition, enough: bool) -> void:
	for c: Node in actions.get_children():
		c.queue_free()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(UiCommon.action_button("Cerrar", _close_sheet, &"ghost_ink"))
	var main_btn: Button = null
	if enough:
		main_btn = UiCommon.action_button("Desbloquear por %s Soles" % UiFormat.fmt_int(lv.unlock_cost_soles),
			func() -> void: _show_locked_confirm(actions, lv), &"primary", &"lock")
	elif _deps.on_shop.is_valid():
		main_btn = UiCommon.action_button("Conseguir Soles", _deps.on_shop, &"secondary", &"cart")
	if main_btn != null:
		row.add_child(main_btn)
		UiCommon.focus_later(main_btn)
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
				_flash.call_deferred(_levels.find(lv))
			else:
				_show_locked_main(actions, lv, _deps.wallet.balance() >= lv.unlock_cost_soles),
		func() -> void: _show_locked_main(actions, lv, _deps.wallet.balance() >= lv.unlock_cost_soles),
		&"primary"))


## `.is-new`: la burbuja recién desbloqueada aparece con rebote y un destello dorado.
func _flash(idx: int) -> void:
	if idx < 0 or idx >= _nodes.size():
		return
	var bubble: Button = _nodes[idx].get_meta(&"bubble") as Button
	if bubble == null or not bubble.is_inside_tree():
		return
	UiCommon.pop_in(bubble, 0.4, 0.45)
	FxBurst.sparkle(bubble, bubble.get_global_rect().get_center(), 20)


func _close_sheet() -> void:
	_sheet.visible = false
	for c: Node in _sheet.get_children():
		c.queue_free()
