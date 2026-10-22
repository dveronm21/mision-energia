class_name LobbySlotCard
extends PanelContainer
## Tarjeta de un lugar de la sala de espera: color del jugador, número, nombre, estado, latencia y
## "Quitar". Estados: vacío ("Esperando…"), conectado y reconectando (lugar guardado con cuenta regresiva).

signal kick_requested(slot: int)

var slot: int
var kick_button: Button
var _avatar: PanelContainer
var _num: Label
var _name: Label
var _status: Label
var _ping: PanelContainer
var _ping_text: Label
var _bars: Array[ColorRect] = []
var _key: String = ""


func _init(p_slot: int, allow_kick: bool) -> void:
	slot = p_slot
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", LobbyStyle.px(3.0))
	hb.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(hb)
	custom_minimum_size.y = LobbyStyle.px(16.0)

	_avatar = PanelContainer.new()
	_avatar.custom_minimum_size = Vector2.ONE * LobbyStyle.px(11.0)
	_avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_num = Label.new()
	_num.text = str(slot + 1)
	_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	LobbyStyle.style_label(_num, "fredoka-700", 6.2, LobbyStyle.INK)
	_avatar.add_child(_num)
	hb.add_child(_avatar)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", LobbyStyle.px(0.3))
	_name = Label.new()
	LobbyStyle.style_label(_name, "fredoka-600", 5.2)
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.clip_text = true
	_status = Label.new()
	LobbyStyle.style_label(_status, "nunito-800", 2.9, LobbyStyle.MUTED)
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status.clip_text = true
	info.add_child(_name)
	info.add_child(_status)
	hb.add_child(info)

	_ping = PanelContainer.new()
	var pbox: StyleBoxFlat = LobbyStyle.box(Color(0, 0, 0, 0.3), LobbyStyle.px(3.0))
	pbox.content_margin_left = LobbyStyle.px(1.8)
	pbox.content_margin_right = LobbyStyle.px(1.8)
	pbox.content_margin_top = LobbyStyle.px(0.8)
	pbox.content_margin_bottom = LobbyStyle.px(0.8)
	_ping.add_theme_stylebox_override("panel", pbox)
	_ping.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var phb := HBoxContainer.new()
	phb.add_theme_constant_override("separation", LobbyStyle.px(1.0))
	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", LobbyStyle.px(0.4))
	bars.alignment = BoxContainer.ALIGNMENT_END
	for h: float in [0.4, 0.7, 1.0]:
		var r := ColorRect.new()
		r.custom_minimum_size = Vector2(LobbyStyle.px(0.8), LobbyStyle.px(2.8) * h)
		r.size_flags_vertical = Control.SIZE_SHRINK_END
		bars.add_child(r)
		_bars.append(r)
	bars.custom_minimum_size.y = LobbyStyle.px(2.8)
	bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	phb.add_child(bars)
	_ping_text = Label.new()
	LobbyStyle.style_label(_ping_text, "mono", 3.2)
	phb.add_child(_ping_text)
	_ping.add_child(phb)
	hb.add_child(_ping)

	if allow_kick:
		kick_button = Button.new()
		kick_button.text = "Quitar"
		LobbyStyle.style_button(kick_button, "ghost", 2.8, 7.4, 2.2)
		kick_button.icon = LobbyStyle.icon("close", LobbyStyle.px(3.0), Color.WHITE)
		kick_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		kick_button.pressed.connect(func() -> void: kick_requested.emit(slot))
		hb.add_child(kick_button)
	render(null, 0)


## Actualiza la tarjeta (barato: solo toca nodos si algo cambió). now_ms: reloj del host.
func render(p: RemotePlayer, now_ms: int) -> void:
	var col: Color = RemoteProtocol.slot_color(slot)
	var col_name: String = RemoteProtocol.SLOT_COLOR_NAME[slot]
	var state: String
	var nm: String
	var status: String
	var ping: String = ""
	var q: String = ""
	if p == null:
		state = "empty"
		nm = "Esperando…"
		status = "Lugar %d · %s" % [slot + 1, col_name]
	elif p.connected:
		state = "on"
		nm = p.name
		status = "%s · %s" % [col_name, "App Control" if p.device == "app" else "Navegador"]
		if p.has_latency():
			ping = "%d ms" % p.latency_ms
			q = "good" if p.latency_ms < 60 else ("ok" if p.latency_ms < 150 else "bad")
		else:
			ping = "…"
			q = "ok"
	else:
		state = "off"
		nm = p.name
		var left: int = maxi(0, ceili((p.reserved_until - now_ms) / 1000.0)) if p.reserved_until >= 0 else 0
		status = "Reconectando… lugar guardado %d:%02d" % [left / 60, left % 60]
	var key: String = "%s|%s|%s|%s|%s" % [state, nm, status, ping, q]
	if key == _key:
		return
	_key = key
	var card: StyleBoxFlat
	var av: StyleBoxFlat
	var r: float = LobbyStyle.px(3.0)
	match state:
		"empty":
			card = LobbyStyle.box(Color(LobbyStyle.HUD, 0.55), r, LobbyStyle.LINE, LobbyStyle.px(0.5))
			av = LobbyStyle.box(Color.TRANSPARENT, LobbyStyle.px(5.5), Color(col, 0.8), LobbyStyle.px(0.5))
			_num.add_theme_color_override("font_color", col)
			_name.add_theme_color_override("font_color", LobbyStyle.MUTED)
		"off":
			card = LobbyStyle.box(Color(LobbyStyle.HUD2, 0.92), r, Color(col, 0.6), LobbyStyle.px(0.5))
			av = LobbyStyle.box(Color(col, 0.55), LobbyStyle.px(5.5))
			_num.add_theme_color_override("font_color", LobbyStyle.INK)
			_name.add_theme_color_override("font_color", Color.WHITE)
		_:
			card = LobbyStyle.box(Color(LobbyStyle.HUD2, 0.92), r, col, LobbyStyle.px(0.5), Color(0, 0, 0, 0.3), LobbyStyle.px(0.8))
			av = LobbyStyle.box(col, LobbyStyle.px(5.5), Color.TRANSPARENT, 0, col.darkened(0.25), LobbyStyle.px(0.5))
			_num.add_theme_color_override("font_color", LobbyStyle.INK)
			_name.add_theme_color_override("font_color", Color.WHITE)
	card.content_margin_left = LobbyStyle.px(3.0)
	card.content_margin_right = LobbyStyle.px(3.0)
	card.content_margin_top = LobbyStyle.px(2.0)
	card.content_margin_bottom = LobbyStyle.px(2.0)
	add_theme_stylebox_override("panel", card)
	_avatar.add_theme_stylebox_override("panel", av)
	_name.text = nm
	_status.text = status
	_status.add_theme_color_override("font_color", LobbyStyle.WARN if state == "off" else LobbyStyle.MUTED)
	_ping.visible = state == "on"
	_ping_text.text = ping
	var lit: int = 3 if q == "good" else (2 if q == "ok" else 1)
	var lit_col: Color = LobbyStyle.LEAF if q == "good" else (LobbyStyle.SUN if q == "ok" else LobbyStyle.ORANGE)
	for i: int in _bars.size():
		_bars[i].color = lit_col if i < lit else Color(1, 1, 1, 0.25)
	if kick_button != null:
		var had_focus: bool = kick_button.has_focus()
		kick_button.visible = p != null
		kick_button.tooltip_text = "Quitar a %s" % p.name if p != null else "Quitar"
		if had_focus and p == null:
			kick_button.release_focus()

