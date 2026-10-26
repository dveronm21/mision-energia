class_name WardrobeScreen
extends UiScreen
## Vestuario: colores de casco y chaleco, con vista previa (acá, un `WorkerVisual` 3D de
## verdad en vez del busto SVG de la web — ya existe el modelo, no hace falta reinventarlo).
## Equivale a `WardrobeScreen.ts`.

var _deps: WardrobeDeps
var _chip: WalletChip
var _helmet_list: VBoxContainer
var _vest_list: VBoxContainer
var _info: VBoxContainer
var _preview_name: Label
var _rig: WorkerVisual


func _init(deps: WardrobeDeps) -> void:
	_deps = deps
	_chip = WalletChip.new(deps.wallet, deps.bus, deps.on_shop) if deps.wallet != null else null

	var preview_col: VBoxContainer = VBoxContainer.new()
	preview_col.add_theme_constant_override("separation", 8)
	preview_col.add_child(_build_preview())
	_preview_name = UiTheme.label("Tu técnico", UiTheme.body(800), 14, UiTheme.MUTED)
	_preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_col.add_child(_preview_name)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 6)
	preview_col.add_child(_info)

	var options_col: VBoxContainer = VBoxContainer.new()
	options_col.add_theme_constant_override("separation", 16)
	options_col.add_child(_section("Casco", &"helmet"))
	options_col.add_child(_section("Chaleco", &"vest"))

	var grid: HBoxContainer = HBoxContainer.new()
	grid.add_theme_constant_override("separation", 24)
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_child(preview_col)
	grid.add_child(options_col)

	var right: Array[Control] = []
	if _chip != null:
		right.append(_chip)
	var frame: PageFrame = UiCommon.page_frame({"title": "Vestuario", "on_back": deps.on_back, "right": right, "body": [grid]})
	root = frame.root
	_render()


func _section(title: String, slot: StringName) -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(HudIcon.new(slot, 22.0, UiTheme.SUN))
	head.add_child(UiTheme.label(title, UiTheme.display(600), 20))
	col.add_child(head)
	var list: HBoxContainer = HBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	if slot == &"helmet":
		_helmet_list = col
	else:
		_vest_list = col
	col.add_child(list)
	return col


func _build_preview() -> Control:
	var wrap: SubViewportContainer = SubViewportContainer.new()
	wrap.custom_minimum_size = Vector2(240, 300)
	wrap.stretch = true
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(480, 600)
	vp.transparent_bg = true
	vp.own_world_3d = true

	var env_node: WorldEnvironment = WorldEnvironment.new()
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#1f3d37")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#aee0d8")
	env.ambient_light_energy = 0.9
	env_node.environment = env
	vp.add_child(env_node)

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_energy = 1.1
	vp.add_child(light)

	var cam: Camera3D = Camera3D.new()
	# Todavía fuera del árbol: `look_at()` no funciona, se arma el transform a mano.
	cam.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.5, 1.7)).looking_at(Vector3(0.0, 1.35, 0.0), Vector3.UP)
	cam.fov = 32.0
	vp.add_child(cam)

	_rig = WorkerVisual.new()
	_rig.pose = WorkerVisual.Pose.IDLE
	vp.add_child(_rig)

	wrap.add_child(vp)
	return wrap


func on_enter() -> void:
	if _chip != null:
		_chip.refresh()
	_render()


func on_back() -> bool:
	if _deps.on_back.is_valid():
		_deps.on_back.call()
	return true


func dispose() -> void:
	if _chip != null:
		_chip.dispose()


func _items(slot: StringName) -> Array[Product]:
	var out: Array[Product] = []
	for p: Product in _deps.catalog.all():
		if p.kind == Product.KIND_COSMETIC and _cosmetic_slot(p) == slot:
			out.append(p)
	return out


static func _cosmetic_slot(p: Product) -> StringName:
	var s: String = (p.id + " " + p.icon).to_lower()
	if s.contains("helmet") or s.contains("casco"):
		return &"helmet"
	if s.contains("vest") or s.contains("chaleco"):
		return &"vest"
	return &""


func _render() -> void:
	var list_helmet: HBoxContainer = _helmet_list.get_child(1)
	var list_vest: HBoxContainer = _vest_list.get_child(1)
	for container_slot: Array in [[list_helmet, &"helmet"], [list_vest, &"vest"]]:
		var list: HBoxContainer = container_slot[0]
		var slot: StringName = container_slot[1]
		for c: Node in list.get_children():
			c.queue_free()
		var equipped: String = _deps.inventory.equipped_cosmetic(slot)
		list.add_child(_swatch(slot, null, "Clásico", _default_color(slot), true, equipped == ""))
		for p: Product in _items(slot):
			list.add_child(_swatch(slot, p, p.title, _color_for(p, slot), _deps.inventory.count(p.id) > 0, equipped == p.id))
	_paint_preview(_color_for_id(_deps.inventory.equipped_cosmetic(&"helmet"), &"helmet"), _color_for_id(_deps.inventory.equipped_cosmetic(&"vest"), &"vest"))


static func _default_color(slot: StringName) -> Color:
	return VisualMaterials.C_SUN if slot == &"helmet" else VisualMaterials.C_ORANGE


static func _color_for(p: Product, slot: StringName) -> Color:
	return _color_for_id(p.id, slot)


static func _color_for_id(id: String, slot: StringName) -> Color:
	if id == "":
		return _default_color(slot)
	if Catalog.COSMETIC_COLORS.has(id):
		# COSMETIC_COLORS guarda RGB de 24 bits (0xRRGGBB); Color.hex() espera RGBA de 32,
		# así que hay que completar el byte de alfa (0xff) antes de convertir.
		var rgb: int = Catalog.COSMETIC_COLORS[id]
		return Color.hex((rgb << 8) | 0xff)
	return _default_color(slot)


## `.wr-sw`: círculo de color de 52 px con borde blanco y sombra; el equipado con aro de sol;
## los que no tenés, apagados y con candado; el equipado con tilde.
func _swatch(slot: StringName, p: Product, label: String, color: Color, owned: bool, on: bool) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(84, 90)
	UiTheme.style_button(b, StyleBoxEmpty.new())
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 4

	var dot: Panel = Panel.new()
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.custom_minimum_size = Vector2(52, 52)
	dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ds: StyleBoxFlat = UiTheme.box(color, 999, 3, Color(1, 1, 1, 0.85))
	ds.shadow_color = UiTheme.SUN if on else Color(0, 0, 0, 0.3)
	ds.shadow_size = 4 if on else 0
	ds.shadow_offset = Vector2.ZERO if on else Vector2(0, 4)
	dot.add_theme_stylebox_override("panel", ds)
	if not owned:
		dot.modulate.a = 0.55
	col.add_child(dot)

	var name_label: Label = UiTheme.label(label, UiTheme.body(800), 12, Color("#e4ecea"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name_label)
	b.add_child(col)

	if on or not owned:
		# `.wr-badge`: círculo de 24 px arriba a la derecha (sol con tilde, o gris con candado).
		var badge: PanelContainer = PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.custom_minimum_size = Vector2(24, 24)
		badge.position = Vector2(56, 0)
		badge.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.SUN if on else UiTheme.LOCKED, 999, 2, UiTheme.HUD))
		var bc: CenterContainer = CenterContainer.new()
		bc.add_child(HudIcon.new(&"check" if on else &"lock", 13.0, UiTheme.INK if on else Color.WHITE))
		badge.add_child(bc)
		b.add_child(badge)
	b.pressed.connect(_on_swatch.bind(slot, p, label, color, owned))
	return b


func _on_swatch(slot: StringName, p: Product, label: String, color: Color, owned: bool) -> void:
	if owned:
		var id: String = p.id if p != null else ""
		_deps.inventory.equip(slot, id)
		if _deps.on_equip.is_valid():
			_deps.on_equip.call(slot, id)
		for c: Node in _info.get_children():
			c.queue_free()
		_render()
	elif p != null:
		if slot == &"helmet":
			_paint_preview(color, _color_for_id(_deps.inventory.equipped_cosmetic(&"vest"), &"vest"))
		else:
			_paint_preview(_color_for_id(_deps.inventory.equipped_cosmetic(&"helmet"), &"helmet"), color)
		_preview_name.text = "Vista previa: %s" % label
		for c: Node in _info.get_children():
			c.queue_free()
		var cost_row: Label = UiTheme.label("Cuesta %s Soles en la tienda." % UiFormat.fmt_int(maxi(0, p.cost_soles)),
			UiTheme.body(800), 14, Color("#ffd27a"))
		cost_row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_info.add_child(cost_row)
		if _deps.on_shop.is_valid():
			_info.add_child(UiCommon.action_button("Ir a la tienda", _deps.on_shop, &"secondary", &"cart"))


func _paint_preview(helmet: Color, vest: Color) -> void:
	_rig.set_cosmetics(helmet, vest)
	_preview_name.text = "Tu técnico"
