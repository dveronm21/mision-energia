class_name Toast
extends ToastPort
## Aviso breve arriba al centro. Uno a la vez; el nuevo reemplaza al anterior.
## Equivale a `Toast.ts`.

var root: PanelContainer

var _label: Label
var _timer: Timer


func _init() -> void:
	root = PanelContainer.new()
	root.name = "ui-toast"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.corner_radius_top_left = 20
	bg.corner_radius_top_right = 20
	bg.corner_radius_bottom_left = 20
	bg.corner_radius_bottom_right = 20
	bg.content_margin_left = 20
	bg.content_margin_right = 20
	bg.content_margin_top = 10
	bg.content_margin_bottom = 10
	bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	root.add_theme_stylebox_override("panel", bg)
	root.visible = false
	_label = Label.new()
	root.add_child(_label)
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(hide)
	root.add_child(_timer)


func show(text: String, kind: StringName = &"info", ms: int = 2600) -> void:
	_timer.stop()
	_label.text = text
	var bg: StyleBoxFlat = root.get_theme_stylebox("panel").duplicate()
	match kind:
		&"good":
			bg.bg_color = VisualMaterials.C_OK.darkened(0.55)
		&"bad":
			bg.bg_color = VisualMaterials.C_BAD.darkened(0.45)
		_:
			bg.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	root.add_theme_stylebox_override("panel", bg)
	root.visible = true
	if root.is_inside_tree():
		_timer.start(ms / 1000.0)


func hide() -> void:
	_timer.stop()
	root.visible = false
