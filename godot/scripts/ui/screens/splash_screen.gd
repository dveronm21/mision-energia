class_name SplashScreen
extends UiScreen
## Pantalla inicial: logo + "Tocá para empezar". El primer toque desbloquea el audio.
## Equivale a `SplashScreen.ts`.

var _audio: AudioSynth
var _on_start: Callable
var _done: bool = false


## `on_start`: Callable() -> void. `audio` y `version` opcionales.
func _init(on_start: Callable, audio: AudioSynth = null, version: String = "") -> void:
	_on_start = on_start
	_audio = audio

	root = Control.new()
	root.name = "splash"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("#0e2420")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var col: VBoxContainer = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 22)

	var logo_center: CenterContainer = CenterContainer.new()
	logo_center.add_child(Logo.build())
	col.add_child(logo_center)

	var tag: Label = Label.new()
	tag.text = "Armá tu planta solar y mantené la ciudad encendida día y noche."
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.custom_minimum_size = Vector2(420, 0)
	col.add_child(tag)

	var tap: Button = UiCommon.action_button("Tocá para empezar", _go, &"primary", &"play", true)
	col.add_child(tap)

	center.add_child(col)

	var foot: Label = Label.new()
	foot.text = "Inkfusion · San Juan" + (" · v%s" % version if version != "" else "")
	foot.add_theme_font_size_override("font_size", 12)
	foot.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	foot.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	foot.grow_horizontal = Control.GROW_DIRECTION_BOTH
	foot.position.y = -28
	root.add_child(foot)

	root.gui_input.connect(_on_root_input)


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
