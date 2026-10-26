class_name PauseMenu
extends UiScreen
## Menú de pausa. Reiniciar y Salir piden un segundo toque para confirmar (sin diálogos del
## sistema). Equivale a `PauseMenu.ts`.

const ARM_SECONDS: float = 3.5

var _deps: PauseDeps
var _armed: StringName = &""
var _arm_timer: SceneTreeTimer

var _resume_btn: Button
var _restart_btn: Button
var _restart_label: Label
var _exit_btn: Button
var _exit_label: Label
var _sound_btn: Button
var _sound_icon: HudIcon
var _sound_label: Label
var _speed: int = 1
var _speed_btn: Button
var _speed_label: Label


func _init(deps: PauseDeps) -> void:
	_deps = deps
	modal = true

	root = Control.new()
	root.name = "pause"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# `.mdl-card.pm`: tarjeta blanca de 480 px.
	var col: VBoxContainer = UiCommon.modal_card(root, 480.0, 22.0, 12)

	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	var ic: PanelContainer = PanelContainer.new()
	ic.custom_minimum_size = Vector2(48, 48)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PAPER_2, 999))
	var ic_c: CenterContainer = CenterContainer.new()
	ic_c.add_child(HudIcon.new(&"pause", 24.0, UiTheme.INK))
	ic.add_child(ic_c)
	head.add_child(ic)
	var head_titles: VBoxContainer = VBoxContainer.new()
	head_titles.add_theme_constant_override("separation", 0)
	if deps.level_name != "":
		head_titles.add_child(UiTheme.eyebrow(deps.level_name, UiTheme.SUN_INK))
	head_titles.add_child(UiTheme.title("Pausa", 30, UiTheme.INK))
	head.add_child(head_titles)
	col.add_child(head)

	_resume_btn = UiCommon.action_button("Seguir jugando", deps.on_resume, &"primary", &"play", true)
	col.add_child(_resume_btn)

	var grid: HBoxContainer = HBoxContainer.new()
	grid.add_theme_constant_override("separation", 10)
	_restart_btn = UiCommon.action_button("Reiniciar nivel", _arm_restart, &"secondary", &"retry")
	_restart_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_restart_label = _find_label(_restart_btn)
	grid.add_child(_restart_btn)
	_exit_btn = UiCommon.action_button("Salir al mapa", _arm_exit, &"secondary", &"map")
	_exit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exit_label = _find_label(_exit_btn)
	grid.add_child(_exit_btn)
	col.add_child(grid)

	# `.pm-sound`: botones de contorno oscuro (sonido y velocidad) a todo el ancho.
	var opts: HBoxContainer = HBoxContainer.new()
	opts.add_theme_constant_override("separation", 10)
	if deps.audio != null:
		_sound_btn = UiCommon.action_button("Sonido: prendido", _toggle_sound, &"ghost_ink", &"sound")
		_sound_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_sound_icon = _find_icon(_sound_btn)
		_sound_label = _find_label(_sound_btn)
		opts.add_child(_sound_btn)
		_paint_sound()
	if deps.on_speed_change.is_valid():
		_speed = deps.speed
		_speed_btn = UiCommon.action_button("Velocidad: ×4", _cycle_speed, &"ghost_ink", &"bolt")
		_speed_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_speed_label = _find_label(_speed_btn)
		_speed_label.text = "Velocidad: %s" % GameSpeed.label(_speed)
		opts.add_child(_speed_btn)
	if opts.get_child_count() > 0:
		col.add_child(opts)


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


func _cycle_speed() -> void:
	_speed = GameSpeed.next(_speed)
	_speed_label.text = "Velocidad: %s" % GameSpeed.label(_speed)
	_deps.on_speed_change.call(_speed)


static func _find_label(button: Button) -> Label:
	for c: Node in button.get_children():
		for g: Node in c.get_children():
			if g is Label:
				return g
	return null


static func _find_icon(button: Button) -> HudIcon:
	for c: Node in button.get_children():
		for g: Node in c.get_children():
			if g is HudIcon:
				return g
	return null


func on_enter() -> void:
	UiCommon.focus_later(_resume_btn)
