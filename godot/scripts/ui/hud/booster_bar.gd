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
	root.add_theme_constant_override("separation", 10)
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


func _build_button(s: BoosterSlot) -> Button:
	var b: Button = Button.new()
	b.custom_minimum_size = Vector2(56, 56)
	b.tooltip_text = "%s (te quedan %d)" % [s.label, s.count]
	b.disabled = s.count <= 0
	var col: VBoxContainer = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic_center: CenterContainer = CenterContainer.new()
	ic_center.add_child(HudIcon.new(s.icon, 26.0))
	col.add_child(ic_center)
	var count: Label = Label.new()
	count.text = str(s.count)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(count)
	b.add_child(col)
	var id: StringName = s.id
	b.pressed.connect(func() -> void:
		if on_use.is_valid():
			on_use.call(id))
	return b
