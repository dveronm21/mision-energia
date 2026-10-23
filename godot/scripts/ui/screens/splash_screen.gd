class_name SplashScreen
extends UiScreen
## Pantalla inicial: logo + "Tocá para empezar". El primer toque desbloquea el audio.
## Equivale a `SplashScreen.ts`.

var _audio: AudioSynth
var _on_start: Callable
var _done: bool = false
var _tap: Button
var _breathe: Tween = null


## `on_start`: Callable() -> void. `audio` y `version` opcionales.
func _init(on_start: Callable, audio: AudioSynth = null, version: String = "") -> void:
	_on_start = on_start
	_audio = audio

	root = Control.new()
	root.name = "splash"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(UiBackdrop.new(UiBackdrop.Kind.SPLASH))

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	var col: VBoxContainer = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var logo_center: CenterContainer = CenterContainer.new()
	logo_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_center.add_child(Logo.build())
	col.add_child(logo_center)

	var tag: Label = UiTheme.label("Armá tu planta solar y mantené la ciudad encendida día y noche.", UiTheme.body(700), 18, UiTheme.MUTED)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.custom_minimum_size = Vector2(300, 0)
	col.add_child(tag)

	_tap = UiCommon.action_button("Tocá para empezar", _go, &"primary", &"play", true)
	_tap.custom_minimum_size.y = 60
	_tap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_tap)

	center.add_child(col)

	var foot: Label = UiTheme.label("Inkfusion · San Juan" + (" · v%s" % version if version != "" else ""), UiTheme.body(700), 13, UiTheme.MUTED)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_top = -32
	foot.offset_bottom = -10
	root.add_child(foot)

	root.gui_input.connect(_on_root_input)


func on_enter() -> void:
	UiCommon.focus_later(_tap)
	_start_breathe.call_deferred()


## Respira (`@keyframes breathe`: escala 1.05 a mitad de 1,6 s), sobre su centro. Diferido: recién
## después del primer acomodo el botón tiene su tamaño real.
func _start_breathe() -> void:
	if _breathe == null and _tap.is_inside_tree():
		_tap.pivot_offset = _tap.size / 2.0
		_breathe = _tap.create_tween().set_loops()
		_breathe.tween_property(_tap, "scale", Vector2(1.05, 1.05), 0.8).set_trans(Tween.TRANS_SINE)
		_breathe.tween_property(_tap, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_SINE)


func dispose() -> void:
	if _breathe != null:
		_breathe.kill()
		_breathe = null


func _on_root_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_go()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_go()


func _go() -> void:
	if _done:
		return
	_done = true
	if _audio != null:
		_audio.unlock()
	if _on_start.is_valid():
		_on_start.call()
