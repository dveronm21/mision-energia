class_name BoosterBar
extends BoosterBarPort
## Boosters disponibles en la partida (pista, dron limpiador, batería de emergencia) con
## cantidad. Equivale a `BoosterBar.ts`.

var root: HBoxContainer
## Callable(booster_id: String) -> void.
var on_use: Callable
var _last_key: String = ""


func _init(use_cb: Callable = Callable()) -> void:
	on_use = use_cb
	root = HBoxContainer.new()
	root.name = "hud-boosters"
	root.add_theme_constant_override("separation", 8)
	root.visible = false


func set_boosters(slots: Array[BoosterSlot]) -> void:
	var parts: PackedStringArray = PackedStringArray()
	for s: BoosterSlot in slots:
		parts.append("%s:%d" % [s.id, s.count])
	var key: String = ",".join(parts)
	if key == _last_key:
		return
	_last_key = key
	for c: Node in root.get_children():
		c.queue_free()
	for s: BoosterSlot in slots:
		root.add_child(_build_button(s))
	root.visible = not slots.is_empty()


## `.bst-btn`: cuadrado oscuro de 56 px con borde blanco, ícono de sol y la cantidad en un
## globito amarillo arriba a la derecha (gris y al 50 % si no quedan).
func _build_button(s: BoosterSlot) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(56, 56)
	b.tooltip_text = "%s (te quedan %d)" % [s.label, s.count]
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = s.count <= 0
	UiTheme.style_button(b, UiTheme.box(Color(UiTheme.HUD, 0.88), 16, 2, Color(1, 1, 1, 0.6)))
	var ic_center: CenterContainer = CenterContainer.new()
	ic_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic_center.add_child(HudIcon.new(s.icon, 26.0, UiTheme.MUTED if b.disabled else UiTheme.SUN))
	b.add_child(ic_center)
	var badge: PanelContainer = PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(24, 24)
	badge.position = Vector2(39, -7)
	var bs: StyleBoxFlat = UiTheme.box(Color("#8fa7a1") if b.disabled else UiTheme.SUN, 999, 2, UiTheme.HUD)
	bs.content_margin_left = 5
	bs.content_margin_right = 5
	badge.add_theme_stylebox_override("panel", bs)
	var count: Label = UiTheme.label(str(s.count), UiTheme.display(700), 14, UiTheme.INK)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(count)
	b.add_child(badge)
	if b.disabled:
		b.modulate.a = 0.5
	var id: StringName = s.id
	b.pressed.connect(func() -> void:
		if on_use.is_valid():
			on_use.call(id))
	return b
