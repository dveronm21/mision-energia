class_name UiCommon
extends RefCounted
## Constructores de UI compartidos entre pantallas (equivale a `screens/common.ts`).

const COLOR_PRIMARY: Color = UiTheme.SUN
const COLOR_SECONDARY: Color = UiTheme.HUD_2
const COLOR_DANGER: Color = UiTheme.DANGER
const COLOR_LIGHT: Color = UiTheme.PAPER_2

const DISABLED_BG: Color = Color("#d5dcda")
const DISABLED_FG: Color = Color("#4e625d")
const DISABLED_LIP: Color = Color("#a9b5b1")


## `opts`: {"title":String, "eyebrow":String="", "on_back":Callable=Callable(),
## "back_label":String="Volver", "right":Array[Control]=[], "body":Array[Control],
## "footer":Array[Control]=[], "cls":String=""}.
## Igual que `.pg` de la web: fondo con degradé, cabecera de 64 px (botón atrás redondo +
## título Fredoka 28), cuerpo con scroll y pie oscuro con línea arriba.
static func page_frame(opts: Dictionary) -> PageFrame:
	var root: Control = Control.new()
	root.name = "pg-%s" % String(opts.get("cls", "")) if opts.has("cls") else "pg"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(UiBackdrop.new(UiBackdrop.Kind.PAGE))

	var col: VBoxContainer = VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	root.add_child(col)

	var head_pad: MarginContainer = _margins(16, 10, 16, 6)
	head_pad.custom_minimum_size.y = 64
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	head_pad.add_child(head)
	var on_back: Callable = opts.get("on_back", Callable())
	if on_back.is_valid():
		var back: Button = icon_button(&"back", on_back)
		back.tooltip_text = opts.get("back_label", "Volver")
		back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(back)

	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", 0)
	var eyebrow: String = opts.get("eyebrow", "")
	if eyebrow != "":
		titles.add_child(UiTheme.eyebrow(eyebrow, UiTheme.SUN, 12))
	titles.add_child(UiTheme.title(opts.get("title", ""), 28))
	head.add_child(titles)

	var right: HBoxContainer = HBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.alignment = BoxContainer.ALIGNMENT_END
	for c: Control in (opts.get("right", []) as Array):
		c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		right.add_child(c)
	head.add_child(right)
	col.add_child(head_pad)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body_pad: MarginContainer = _margins(16, 6, 16, 14)
	body_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for c: Control in (opts.get("body", []) as Array):
		body.add_child(c)
	body_pad.add_child(body)
	scroll.add_child(body_pad)
	col.add_child(scroll)

	var frame: PageFrame = PageFrame.new()
	frame.root = root
	frame.body = body
	var footer_items: Array = opts.get("footer", [])
	if not footer_items.is_empty():
		var foot_panel: PanelContainer = PanelContainer.new()
		var foot_style: StyleBoxFlat = UiTheme.box(Color(9.0 / 255.0, 24.0 / 255.0, 21.0 / 255.0, 0.75), 0)
		foot_style.border_width_top = 1
		foot_style.border_color = UiTheme.HUD_LINE
		foot_style.content_margin_left = 16
		foot_style.content_margin_right = 16
		foot_style.content_margin_top = 10
		foot_style.content_margin_bottom = 12
		foot_panel.add_theme_stylebox_override("panel", foot_style)
		var footer: HBoxContainer = HBoxContainer.new()
		footer.add_theme_constant_override("separation", 16)
		for c: Control in footer_items:
			footer.add_child(c)
		foot_panel.add_child(footer)
		col.add_child(foot_panel)
		frame.footer = footer
	return frame


## Modal (`.mdl` + `.mdl-card`): oscurece la pantalla y centra una tarjeta blanca de `width`
## px que entra con un rebote. Agrega todo a `root` y devuelve la columna de contenido.
static func modal_card(root: Control, width: float, pad: float = 22.0, separation: int = 12) -> VBoxContainer:
	var dim: ColorRect = ColorRect.new()
	dim.name = "dim"
	dim.color = Color(9.0 / 255.0, 24.0 / 255.0, 21.0 / 255.0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var card: PanelContainer = PanelContainer.new()
	card.name = "mdl-card"
	card.add_theme_stylebox_override("panel", UiTheme.card(24, pad, 10))
	card.custom_minimum_size = Vector2(width, 0)
	# Pantalla angosta (teléfono con la UI agrandada): la tarjeta se achica y deja 16 px a cada lado.
	center.resized.connect(func() -> void:
		card.custom_minimum_size.x = minf(width, maxf(280.0, center.size.x - 32.0)))
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", separation)
	card.add_child(col)
	center.add_child(card)
	card.tree_entered.connect(func() -> void: pop_in(card), CONNECT_ONE_SHOT)
	return col


## Enfoca `c` al final del cuadro (para teclado, D-pad y control de TV), si para entonces sigue
## en pantalla: las pantallas se redibujan y el control pedido puede haber sido reemplazado.
static func focus_later(c: Control) -> void:
	var go: Callable = func() -> void:
		if is_instance_valid(c) and c.is_inside_tree() and c.is_visible_in_tree():
			c.grab_focus()
	go.call_deferred()


## Entrada con rebote (`@keyframes popIn`, un poco más elástico): escala desde 0.9 y aparece.
static func pop_in(c: Control, from_scale: float = 0.9, sec: float = 0.34) -> void:
	c.modulate.a = 0.0
	c.scale = Vector2(from_scale, from_scale)
	var start: Callable = func() -> void:
		if not is_instance_valid(c) or not c.is_inside_tree():
			return
		c.pivot_offset = c.size / 2.0
		var t: Tween = c.create_tween().set_parallel(true)
		t.tween_property(c, "modulate:a", 1.0, 0.16)
		t.tween_property(c, "scale", Vector2.ONE, sec).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Diferido: recién después del primer acomodo la tarjeta tiene su tamaño (y su centro).
	start.call_deferred()


## Envuelve `c` en una columna centrada de hasta `width` px (ver `MaxWidth`).
static func max_width(c: Control, width: float) -> MaxWidth:
	var m: MaxWidth = MaxWidth.new(width)
	m.add_child(c)
	return m


static func _margins(l: int, t: int, r: int, b: int) -> MarginContainer:
	var m: MarginContainer = MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	return m


## Botón redondo de 48 px con ícono (`.icon-btn`: atrás, cerrar).
static func icon_button(icon_name: StringName, on_click: Callable, icon_size: float = 22.0) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(48, 48)
	UiTheme.style_button(b, UiTheme.box(UiTheme.HUD_2, 999, 2, UiTheme.HUD_LINE))
	var c: CenterContainer = CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(HudIcon.new(icon_name, icon_size))
	b.add_child(c)
	if on_click.is_valid():
		b.pressed.connect(on_click)
	return b


## Botón con ícono + texto (`.btn`): píldora, Fredoka 600 18, labio inferior.
## `kind`: "primary" (amarillo) | "secondary" (verde oscuro) | "ghost" (contorno blanco) |
## "ghost_ink" (contorno oscuro, para tarjetas blancas) | "danger" | "light".
## `big`: `.btn-big` (64 px de alto, Fredoka 700 24).
static func action_button(label: String, on_click: Callable, kind: StringName = &"primary", icon_name: StringName = &"", big: bool = false) -> Button:
	var b: Button = Button.new()
	var font: Font = UiTheme.display(700 if big else 600)
	var font_size: int = 24 if big else 18
	var pad: float = 34.0 if big else 20.0
	var icon_px: float = 26.0 if big else 20.0
	var fg: Color = _text_color(kind)

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ic: HudIcon = null
	if icon_name != &"":
		ic = HudIcon.new(icon_name, icon_px, fg)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
	var l: Label = UiTheme.label(label, font, font_size, fg)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	b.add_child(row)

	# El `Control` interno no empuja el tamaño del `Button` (no es un Container): el mínimo se
	# calcula del texto, ícono y relleno.
	var text_w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var w: float = text_w + pad * 2.0 + ((icon_px + 8.0) if ic != null else 0.0)
	b.custom_minimum_size = Vector2(ceilf(w), 64.0 if big else 48.0)

	var normal: StyleBoxFlat
	match kind:
		&"secondary":
			normal = UiTheme.lipped(UiTheme.HUD_2, UiTheme.SHADOW_DARK, 4, 999, 2, UiTheme.HUD_LINE, pad)
		&"ghost":
			normal = UiTheme.box(Color.TRANSPARENT, 999, 2, Color(1, 1, 1, 0.85))
		&"ghost_ink":
			normal = UiTheme.box(Color.TRANSPARENT, 999, 2, UiTheme.INK)
		&"danger":
			normal = UiTheme.lipped(UiTheme.DANGER, Color("#6e1712"), 4, 999, 0, Color.TRANSPARENT, pad)
		&"light":
			normal = UiTheme.lipped(UiTheme.PAPER_2, UiTheme.LINE, 3, 999, 0, Color.TRANSPARENT, pad)
		_:
			normal = UiTheme.lipped(UiTheme.SUN, UiTheme.SUN_DARK, 5, 999, 0, Color.TRANSPARENT, pad)
	var disabled: StyleBoxFlat
	if kind == &"ghost" or kind == &"ghost_ink":
		disabled = normal
	else:
		disabled = UiTheme.lipped(DISABLED_BG, DISABLED_LIP, 4, 999, 0, Color.TRANSPARENT, pad)
	UiTheme.style_button(b, normal, disabled)

	# Texto e ícono cambian de color al deshabilitar (Button no avisa por señal: `draw` se
	# dispara cada vez que cambia de estado).
	var ghost: bool = kind == &"ghost" or kind == &"ghost_ink"
	b.draw.connect(func() -> void:
		var off: bool = b.disabled
		var c: Color = (Color(fg, 0.5) if ghost else DISABLED_FG) if off else fg
		l.add_theme_color_override("font_color", c)
		if ic != null and ic.stroke_color != c:
			ic.stroke_color = c
			ic.queue_redraw())
	if on_click.is_valid():
		b.pressed.connect(on_click)
	return b


static func _text_color(kind: StringName) -> Color:
	match kind:
		&"ghost", &"secondary", &"danger":
			return Color.WHITE
		_:
			return UiTheme.INK


## Fila de 0..3 estrellas.
static func stars_row(n: int, star_size: float = 20.0) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	for i: int in 3:
		row.add_child(HudIcon.new(&"star", star_size, VisualMaterials.C_SUN if i < n else Color(1, 1, 1, 0.25)))
	return row


## Confirmación dentro de la página (nunca un diálogo del sistema): pregunta + Sí/No.
static func inline_confirm(question: String, yes_label: String, on_yes: Callable, on_no: Callable, yes_kind: StringName = &"primary", no_label: String = "No") -> Control:
	# `.confirm`: va sobre tarjetas blancas (mapa, tienda), así que el texto y el "No" son oscuros.
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	var q: Label = UiTheme.label(question, UiTheme.body(800), 16, UiTheme.INK)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(q)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(action_button(no_label, on_no, &"ghost_ink"))
	var yes: Button = action_button(yes_label, on_yes, yes_kind)
	row.add_child(yes)
	UiCommon.focus_later(yes)
	col.add_child(row)
	return col
