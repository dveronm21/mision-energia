class_name UiCommon
extends RefCounted
## Constructores de UI compartidos entre pantallas (equivale a `screens/common.ts`).

const COLOR_PRIMARY: Color = Color("#ffb82e")
const COLOR_SECONDARY: Color = Color("#1d4d3f")
const COLOR_DANGER: Color = Color("#ff4d4d")
const COLOR_LIGHT: Color = Color(0.92, 0.92, 0.9)


## `opts`: {"title":String, "eyebrow":String="", "on_back":Callable=Callable(),
## "back_label":String="Volver", "right":Array[Control]=[], "body":Array[Control],
## "footer":Array[Control]=[], "cls":String=""}.
static func page_frame(opts: Dictionary) -> PageFrame:
	var root: Control = Control.new()
	root.name = "pg-%s" % String(opts.get("cls", "")) if opts.has("cls") else "pg"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 12)
	root.add_child(col)

	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var on_back: Callable = opts.get("on_back", Callable())
	if on_back.is_valid():
		var back: Button = Button.new()
		back.custom_minimum_size = Vector2(44, 44)
		back.tooltip_text = opts.get("back_label", "Volver")
		var back_center: CenterContainer = CenterContainer.new()
		back_center.add_child(HudIcon.new(&"back", 22.0))
		back.add_child(back_center)
		back.pressed.connect(on_back)
		head.add_child(back)

	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var eyebrow: String = opts.get("eyebrow", "")
	if eyebrow != "":
		var eb: Label = Label.new()
		eb.text = eyebrow
		eb.add_theme_font_size_override("font_size", 12)
		eb.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		titles.add_child(eb)
	var title: Label = Label.new()
	title.text = opts.get("title", "")
	title.add_theme_font_size_override("font_size", 24)
	titles.add_child(title)
	head.add_child(titles)

	var right: HBoxContainer = HBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	for c: Control in (opts.get("right", []) as Array):
		right.add_child(c)
	head.add_child(right)
	col.add_child(head)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for c: Control in (opts.get("body", []) as Array):
		body.add_child(c)
	scroll.add_child(body)
	col.add_child(scroll)

	var frame: PageFrame = PageFrame.new()
	frame.root = root
	frame.body = body
	var footer_items: Array = opts.get("footer", [])
	if not footer_items.is_empty():
		var footer: HBoxContainer = HBoxContainer.new()
		footer.add_theme_constant_override("separation", 10)
		for c: Control in footer_items:
			footer.add_child(c)
		col.add_child(footer)
		frame.footer = footer
	return frame


## Botón con ícono + texto. `kind`: "primary" (amarillo) | "secondary" (verde oscuro) |
## "ghost" (contorno) | "danger" | "light".
static func action_button(label: String, on_click: Callable, kind: StringName = &"primary", icon_name: StringName = &"", big: bool = false) -> Button:
	var b: Button = Button.new()
	# Ancho mínimo fijo: el `Control` interno con FULL_RECT no empuja el tamaño del `Button`
	# padre (Button no es un Container que calcule su mínimo a partir de hijos), así que si no
	# se fija acá el botón puede colapsar casi invisible.
	b.custom_minimum_size = Vector2(160.0 if big else 130.0, 56 if big else 44)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	if icon_name != &"":
		row.add_child(HudIcon.new(icon_name, 28.0 if big else 22.0, _text_color(kind)))
	var l: Label = Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 18 if big else 15)
	l.add_theme_color_override("font_color", _text_color(kind))
	row.add_child(l)
	b.add_child(row)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.corner_radius_top_left = 14
	bg.corner_radius_top_right = 14
	bg.corner_radius_bottom_left = 14
	bg.corner_radius_bottom_right = 14
	match kind:
		&"secondary":
			bg.bg_color = COLOR_SECONDARY
		&"ghost":
			bg.bg_color = Color(0, 0, 0, 0)
			bg.border_width_top = 2
			bg.border_width_bottom = 2
			bg.border_width_left = 2
			bg.border_width_right = 2
			bg.border_color = Color(1, 1, 1, 0.5)
		&"danger":
			bg.bg_color = COLOR_DANGER
		&"light":
			bg.bg_color = COLOR_LIGHT
		_:
			bg.bg_color = COLOR_PRIMARY
	b.add_theme_stylebox_override("normal", bg)
	b.add_theme_stylebox_override("hover", bg)
	b.add_theme_stylebox_override("pressed", bg)
	if on_click.is_valid():
		b.pressed.connect(on_click)
	return b


static func _text_color(kind: StringName) -> Color:
	match kind:
		&"ghost":
			return Color.WHITE
		&"secondary":
			return Color.WHITE
		_:
			return Color("#0e2420")


## Fila de 0..3 estrellas.
static func stars_row(n: int, star_size: float = 20.0) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	for i: int in 3:
		row.add_child(HudIcon.new(&"star", star_size, VisualMaterials.C_SUN if i < n else Color(1, 1, 1, 0.25)))
	return row


## Confirmación dentro de la página (nunca un diálogo del sistema): pregunta + Sí/No.
static func inline_confirm(question: String, yes_label: String, on_yes: Callable, on_no: Callable, yes_kind: StringName = &"primary", no_label: String = "No") -> Control:
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	var q: Label = Label.new()
	q.text = question
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(q)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(action_button(no_label, on_no, &"ghost"))
	row.add_child(action_button(yes_label, on_yes, yes_kind))
	col.add_child(row)
	return col
