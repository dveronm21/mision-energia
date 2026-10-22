class_name LobbyView
extends Control
## Sala de espera del tele: QR grande con la URL del control, los 2 lugares y "Empezar".
## Port de app/src/remote/LobbyView.ts. Pensada para leerse a 3 m: textos grandes, alto contraste,
## área segura de TV (5% por borde) y navegación con D-pad / control remoto (foco bien visible,
## ui_accept activa, ui_cancel o Atrás → back_requested).
##
##   var lobby := LobbyView.new()
##   add_child(lobby)
##   lobby.setup(host)                   # RemoteHost
##   lobby.start_requested.connect(_empezar)
##   lobby.back_requested.connect(_volver)
##   lobby.show_lobby()

## "Empezar" (habilitado con ≥1 jugador conectado).
signal start_requested
## Botón "Volver", ui_cancel o la tecla Atrás del control remoto.
signal back_requested

const REFRESH_SEC: float = 0.25
const SAFE_AREA: float = 0.05

@export var title: String = "¡Sumate con tu tablet!"
## Muestra "Volver".
@export var show_back: bool = true
## Muestra "Quitar" en cada lugar ocupado (libera el asiento).
@export var allow_kick: bool = true

var host: RemoteHost
var start_button: Button
var back_button: Button
var slots: Array[LobbySlotCard] = []
var _margin: MarginContainer
var _qr_rect: TextureRect
var _qr_card: PanelContainer
var _no_net: VBoxContainer
var _url_label: Label
var _url_pill: PanelContainer
var _hint: Label
var _shown_url: String = "<sin dibujar>"
var _timer: Timer
var _was_ready: bool = false
var _glow_tex: GradientTexture2D
var _sun_tex: GradientTexture2D


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	_build()
	resized.connect(_apply_safe_area)
	_apply_safe_area()
	_timer = Timer.new()
	_timer.wait_time = REFRESH_SEC
	_timer.timeout.connect(_on_tick)
	add_child(_timer)
	if visible:
		_timer.start()
		refresh()
		focus_default()


## Conecta la vista a un host (se puede llamar antes o después de agregarla al árbol).
func setup(p_host: RemoteHost) -> void:
	if host != null:
		for sig: Signal in [host.joined, host.resumed]:
			if sig.is_connected(_on_player):
				sig.disconnect(_on_player)
		for sig: Signal in [host.left, host.dropped]:
			if sig.is_connected(_on_slot_event):
				sig.disconnect(_on_slot_event)
	host = p_host
	host.joined.connect(_on_player)
	host.resumed.connect(_on_player)
	host.left.connect(_on_slot_event)
	host.dropped.connect(_on_slot_event)
	if is_inside_tree():
		refresh()


func show_lobby() -> void:
	visible = true
	if _timer != null:
		_timer.start()
	refresh()
	focus_default()


func hide_lobby() -> void:
	visible = false
	if _timer != null:
		_timer.stop()


## Vuelve a leer jugadores y URL del host (solo toca nodos si algo cambió).
func refresh() -> void:
	if start_button == null:
		return
	var url: String = host.controller_url() if host != null else ""
	if url != _shown_url:
		_render_url(url)
	var ps: Array[RemotePlayer] = host.players() if host != null else ([null, null] as Array[RemotePlayer])
	var now: int = Time.get_ticks_msec()
	var n: int = 0
	for i: int in slots.size():
		slots[i].render(ps[i], now)
		if ps[i] != null and ps[i].connected:
			n += 1
	var ready_now: bool = n > 0
	start_button.disabled = not ready_now
	start_button.focus_mode = Control.FOCUS_ALL if ready_now else Control.FOCUS_NONE
	if ready_now:
		_hint.text = "Podés empezar ya o esperar a otro jugador" if n < RemoteProtocol.MAX_PLAYERS else "¡Equipo completo!"
	else:
		_hint.text = "Necesitás al menos 1 tablet conectada"
	# Al habilitarse "Empezar", el foco salta ahí (un OK y arranca).
	if ready_now and not _was_ready and is_visible_in_tree():
		start_button.grab_focus()
	_was_ready = ready_now
	_wire_focus()
	if is_visible_in_tree():
		var f: Control = get_viewport().gui_get_focus_owner()
		if f == null or not is_ancestor_of(f) or not f.is_visible_in_tree():
			focus_default()


## Foco inicial: "Empezar" si está habilitado; si no, el primer botón visible.
func focus_default() -> void:
	if start_button == null or not is_visible_in_tree():
		return
	if not start_button.disabled:
		start_button.grab_focus()
		return
	for b: Button in _focusables():
		b.grab_focus()
		return


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_visible_in_tree():
		back_requested.emit()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and _timer != null:
		if is_visible_in_tree():
			_timer.start()
		else:
			_timer.stop()


func _draw() -> void:
	# Fondo: verde profundo con un resplandor de sol arriba a la derecha.
	draw_rect(Rect2(Vector2.ZERO, size), LobbyStyle.HUD)
	if _glow_tex == null:
		_glow_tex = GradientTexture2D.new()
		var g := Gradient.new()
		g.set_color(0, Color(LobbyStyle.HUD2, 1.0))
		g.set_color(1, Color(LobbyStyle.HUD2, 0.0))
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 256
		_glow_tex.height = 256
	var big: float = size.y * 2.2
	draw_texture_rect(_glow_tex, Rect2(Vector2(size.x * 0.8 - big / 2.0, -big / 2.0), Vector2(big, big)), false)
	if _sun_tex == null:
		_sun_tex = GradientTexture2D.new()
		var sg := Gradient.new()
		sg.set_color(0, Color(LobbyStyle.SUN, 0.32))
		sg.set_color(1, Color(LobbyStyle.SUN, 0.0))
		_sun_tex.gradient = sg
		_sun_tex.fill = GradientTexture2D.FILL_RADIAL
		_sun_tex.fill_from = Vector2(0.5, 0.5)
		_sun_tex.fill_to = Vector2(1.0, 0.5)
	var r: float = size.y * 0.5
	draw_texture_rect(_sun_tex, Rect2(Vector2(size.x - r * 0.75, -r * 1.25), Vector2(r * 2.0, r * 2.0)), false)


# ---------- construcción ----------

func _build() -> void:
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", LobbyStyle.px(6.0))
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_margin.add_child(row)

	# Columna del QR.
	var qr_col := VBoxContainer.new()
	qr_col.alignment = BoxContainer.ALIGNMENT_CENTER
	qr_col.add_theme_constant_override("separation", LobbyStyle.px(2.2))
	qr_col.custom_minimum_size.x = LobbyStyle.px(60.0)
	row.add_child(qr_col)
	_qr_card = PanelContainer.new()
	var card: StyleBoxFlat = LobbyStyle.box(Color.WHITE, LobbyStyle.px(3.2), LobbyStyle.SUN, LobbyStyle.px(0.8),
		Color(0, 0, 0, 0.35), LobbyStyle.px(1.2))
	card.set_content_margin_all(LobbyStyle.px(2.0))
	_qr_card.add_theme_stylebox_override("panel", card)
	_qr_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	qr_col.add_child(_qr_card)
	var qr_holder := Control.new()
	qr_holder.custom_minimum_size = Vector2.ONE * LobbyStyle.px(52.0)
	_qr_card.add_child(qr_holder)
	_qr_rect = TextureRect.new()
	_qr_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_qr_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_qr_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_qr_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	qr_holder.add_child(_qr_rect)
	_no_net = VBoxContainer.new()
	_no_net.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_no_net.alignment = BoxContainer.ALIGNMENT_CENTER
	var nn_title := Label.new()
	nn_title.text = "Sin red"
	nn_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	LobbyStyle.style_label(nn_title, "fredoka-700", 6.0, LobbyStyle.INK)
	var nn_text := Label.new()
	nn_text.text = "Conectá el tele a la red Wi-Fi para jugar con tablets"
	nn_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nn_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	LobbyStyle.style_label(nn_text, "nunito-800", 3.2, LobbyStyle.INK)
	_no_net.add_child(nn_title)
	_no_net.add_child(nn_text)
	qr_holder.add_child(_no_net)

	var scan := Label.new()
	scan.text = "Escaneá con la tablet o abrí Misión Energía Control"
	scan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scan.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scan.custom_minimum_size.x = LobbyStyle.px(56.0)
	LobbyStyle.style_label(scan, "nunito-800", 3.6)
	qr_col.add_child(scan)
	_url_pill = PanelContainer.new()
	var pill: StyleBoxFlat = LobbyStyle.box(Color(0, 0, 0, 0.28), LobbyStyle.px(4.0), LobbyStyle.LINE, LobbyStyle.px(0.3))
	pill.content_margin_left = LobbyStyle.px(3.0)
	pill.content_margin_right = LobbyStyle.px(3.0)
	pill.content_margin_top = LobbyStyle.px(0.4)
	pill.content_margin_bottom = LobbyStyle.px(0.4)
	_url_pill.add_theme_stylebox_override("panel", pill)
	_url_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_url_label = Label.new()
	LobbyStyle.style_label(_url_label, "mono", 4.2, LobbyStyle.SUN)
	_url_pill.add_child(_url_label)
	qr_col.add_child(_url_pill)

	# Columna principal.
	var main := VBoxContainer.new()
	main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.alignment = BoxContainer.ALIGNMENT_CENTER
	main.add_theme_constant_override("separation", LobbyStyle.px(4.0))
	row.add_child(main)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", LobbyStyle.px(0.6))
	var eyebrow := Label.new()
	eyebrow.text = "MODO TV · HASTA 2 JUGADORES"
	LobbyStyle.style_label(eyebrow, "nunito-800", 2.8, LobbyStyle.SUN)
	var tracked := FontVariation.new()
	tracked.base_font = LobbyStyle.font("nunito-800")
	tracked.spacing_glyph = LobbyStyle.px(0.4)
	eyebrow.add_theme_font_override("font", tracked)
	var title_l := Label.new()
	title_l.text = title
	LobbyStyle.style_label(title_l, "fredoka-700", 8.0)
	var sub := Label.new()
	sub.text = "Cada tablet es un joystick. Misma red Wi-Fi que el tele."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	LobbyStyle.style_label(sub, "nunito-700", 3.2, LobbyStyle.MUTED)
	head.add_child(eyebrow)
	head.add_child(title_l)
	head.add_child(sub)
	main.add_child(head)

	var slot_box := VBoxContainer.new()
	slot_box.add_theme_constant_override("separation", LobbyStyle.px(2.4))
	main.add_child(slot_box)
	for s: int in RemoteHost.SLOTS:
		var c := LobbySlotCard.new(s, allow_kick)
		c.kick_requested.connect(_on_kick)
		slot_box.add_child(c)
		slots.append(c)

	var foot := VBoxContainer.new()
	foot.add_theme_constant_override("separation", LobbyStyle.px(1.6))
	main.add_child(foot)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", LobbyStyle.px(2.4))
	foot.add_child(actions)
	start_button = Button.new()
	start_button.text = "Empezar"
	LobbyStyle.style_button(start_button, "primary", 4.8, 11.0, 5.5)
	start_button.icon = LobbyStyle.icon("play", LobbyStyle.px(4.2), LobbyStyle.INK)
	start_button.pressed.connect(func() -> void:
		if not start_button.disabled:
			start_requested.emit())
	actions.add_child(start_button)
	back_button = Button.new()
	back_button.text = "Volver"
	LobbyStyle.style_button(back_button, "secondary", 3.6, 9.0, 3.6)
	back_button.icon = LobbyStyle.icon("back", LobbyStyle.px(3.4), Color.WHITE)
	back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(func() -> void: back_requested.emit())
	back_button.visible = show_back
	actions.add_child(back_button)
	_hint = Label.new()
	LobbyStyle.style_label(_hint, "nunito-800", 2.9, LobbyStyle.MUTED)
	foot.add_child(_hint)


func _apply_safe_area() -> void:
	if _margin == null:
		return
	var mx: int = int(size.x * SAFE_AREA)
	var my: int = int(size.y * SAFE_AREA)
	_margin.add_theme_constant_override("margin_left", mx)
	_margin.add_theme_constant_override("margin_right", mx)
	_margin.add_theme_constant_override("margin_top", my)
	_margin.add_theme_constant_override("margin_bottom", my)
	queue_redraw()


func _render_url(url: String) -> void:
	_shown_url = url
	if url != "":
		var qr := QrEncoder.new()
		if qr.encode(url):
			_qr_rect.texture = qr.to_texture(8, 2, LobbyStyle.HUD, Color.WHITE)
		_qr_rect.visible = true
		_no_net.visible = false
		_url_label.text = url.trim_prefix("http://").trim_prefix("https://").trim_suffix("/")
		_url_label.add_theme_color_override("font_color", LobbyStyle.SUN)
	else:
		_qr_rect.visible = false
		_no_net.visible = true
		_url_label.text = "Esperando red…"
		_url_label.add_theme_color_override("font_color", LobbyStyle.MUTED)


## Vecinos de foco explícitos para el D-pad (la búsqueda geométrica de Godot iría de "Quitar" a "Volver").
func _wire_focus() -> void:
	var bottom_target: Button = start_button if not start_button.disabled else (back_button if back_button.visible else null)
	var kicks: Array[Button] = []
	for c: LobbySlotCard in slots:
		if c.kick_button != null and c.kick_button.visible:
			kicks.append(c.kick_button)
	for i: int in kicks.size():
		var k: Button = kicks[i]
		k.focus_neighbor_top = k.get_path_to(kicks[i - 1]) if i > 0 else NodePath("")
		var below: Button = kicks[i + 1] if i + 1 < kicks.size() else bottom_target
		k.focus_neighbor_bottom = k.get_path_to(below) if below != null else NodePath("")
	var above: Button = kicks[kicks.size() - 1] if not kicks.is_empty() else null
	for b: Button in [start_button, back_button]:
		b.focus_neighbor_top = b.get_path_to(above) if above != null else b.get_path_to(b)
		b.focus_neighbor_bottom = b.get_path_to(b)


func _focusables() -> Array[Button]:
	var out: Array[Button] = []
	if not start_button.disabled:
		out.append(start_button)
	if back_button.visible:
		out.append(back_button)
	for c: LobbySlotCard in slots:
		if c.kick_button != null and c.kick_button.visible:
			out.append(c.kick_button)
	return out


func _on_tick() -> void:
	refresh()


func _on_player(_p: RemotePlayer) -> void:
	refresh()


func _on_slot_event(_slot: int, _reason: String) -> void:
	refresh()


func _on_kick(slot: int) -> void:
	if host != null:
		host.kick(slot, "El tele liberó tu lugar")
	refresh()
	focus_default()
