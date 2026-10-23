class_name PauseMenu
extends UiScreen
## Menú de pausa. Reiniciar y Salir piden un segundo toque para confirmar (sin diálogos del
## sistema). Equivale a `PauseMenu.ts`.

const ARM_SECONDS: float = 3.5

var _deps: PauseDeps
var _armed: StringName = &""
var _arm_timer: SceneTreeTimer

var _restart_btn: Button
var _restart_label: Label
var _exit_btn: Button
var _exit_label: Label
var _sound_btn: Button
var _sound_icon: HudIcon
var _sound_label: Label


func _init(deps: PauseDeps) -> void:
	_deps = deps
	modal = true

	root = Control.new()
	root.name = "pause"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color("#13302a")
	bg.corner_radius_top_left = 20
	bg.corner_radius_top_right = 20
	bg.corner_radius_bottom_left = 20
	bg.corner_radius_bottom_right = 20
	bg.content_margin_left = 24
	bg.content_margin_right = 24
	bg.content_margin_top = 20
	bg.content_margin_bottom = 20
	card.add_theme_stylebox_override("panel", bg)
	card.custom_minimum_size = Vector2(340, 0)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)

	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(HudIcon.new(&"pause", 26.0, VisualMaterials.C_SUN))
	var head_titles: VBoxContainer = VBoxContainer.new()
	if deps.level_name != "":
		var eb: Label = Label.new()
		eb.text = deps.level_name
		eb.add_theme_font_size_override("font_size", 12)
		eb.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		head_titles.add_child(eb)
	var title: Label = Label.new()
	title.text = "Pausa"
	title.add_theme_font_size_override("font_size", 22)
	head_titles.add_child(title)
	head.add_child(head_titles)
	col.add_child(head)

	col.add_child(UiCommon.action_button("Seguir jugando", deps.on_resume, &"primary", &"play", true))

	var grid: HBoxContainer = HBoxContainer.new()
	grid.add_theme_constant_override("separation", 10)
	_restart_btn = UiCommon.action_button("Reiniciar nivel", _arm_restart, &"secondary", &"retry")
	_restart_label = _find_label(_restart_btn)
	grid.add_child(_restart_btn)
	_exit_btn = UiCommon.action_button("Salir al mapa", _arm_exit, &"secondary", &"map")
	_exit_label = _find_label(_exit_btn)
	grid.add_child(_exit_btn)
	col.add_child(grid)

	if deps.audio != null:
		_sound_btn = Button.new()
		# Ancho mínimo fijo (Button no calcula tamaño a partir de hijos Control agregados a mano).
		_sound_btn.custom_minimum_size = Vector2(220, 44)
		var row: HBoxContainer = HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		_sound_icon = HudIcon.new(&"sound", 22.0)
		row.add_child(_sound_icon)
		_sound_label = Label.new()
		row.add_child(_sound_label)
		_sound_btn.add_child(row)
		_sound_btn.pressed.connect(_toggle_sound)
		col.add_child(_sound_btn)
		_paint_sound()

	card.add_child(col)
	center.add_child(card)


func on_back() -> bool:
	if _deps.on_resume.is_valid():
		_deps.on_resume.call()
	return true


func dispose() -> void:
	pass


func _arm_restart() -> void:
	_arm(&"restart")


func _arm_exit() -> void:
	_arm(&"exit")


func _arm(what: StringName) -> void:
	if _armed == what:
		_disarm()
		if what == &"restart" and _deps.on_restart.is_valid():
			_deps.on_restart.call()
		elif what == &"exit" and _deps.on_exit_to_map.is_valid():
			_deps.on_exit_to_map.call()
		return
	_disarm()
	_armed = what
	var label: Label = _restart_label if what == &"restart" else _exit_label
	label.text = "Tocá otra vez"
	if root.is_inside_tree():
		_arm_timer = root.get_tree().create_timer(ARM_SECONDS)
		_arm_timer.timeout.connect(_disarm)


func _disarm() -> void:
	_armed = &""
	_restart_label.text = "Reiniciar nivel"
	_exit_label.text = "Salir al mapa"


func _toggle_sound() -> void:
	var a: AudioSynth = _deps.audio
	if a == null:
		return
	a.set_muted(not a.is_muted())
	_paint_sound()


func _paint_sound() -> void:
	var muted: bool = _deps.audio != null and _deps.audio.is_muted()
	_sound_icon.icon_name = &"mute" if muted else &"sound"
	_sound_icon.queue_redraw()
	_sound_label.text = "Sonido: apagado" if muted else "Sonido: prendido"


static func _find_label(button: Button) -> Label:
	for c: Node in button.get_children():
		for g: Node in c.get_children():
			if g is Label:
				return g
	return null
