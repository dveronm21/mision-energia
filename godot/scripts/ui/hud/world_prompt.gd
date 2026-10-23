class_name WorldPrompt
extends WorldPromptPort
## Etiqueta que sigue un punto del mundo 3D proyectado a pantalla (equivale a `WorldPrompt.ts`).
## `GameSession` proyecta con `Camera3D.unproject_position()` y llama `set_screen_position()`
## cada cuadro.

const MARGIN: float = 8.0
## Base de diseño del proyecto (ver `project.godot`); se usa si todavía no está en el árbol.
const DEFAULT_VIEWPORT: Vector2 = Vector2(1280, 720)

var root: PanelContainer
var _label: Label
var _x: float = -9999.0
var _y: float = -9999.0


func _init() -> void:
	root = PanelContainer.new()
	root.name = "hud-prompt"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.72)
	bg.corner_radius_top_left = 10
	bg.corner_radius_top_right = 10
	bg.corner_radius_bottom_left = 10
	bg.corner_radius_bottom_right = 10
	bg.content_margin_left = 12
	bg.content_margin_right = 12
	bg.content_margin_top = 6
	bg.content_margin_bottom = 6
	root.add_theme_stylebox_override("panel", bg)
	root.visible = false
	_label = Label.new()
	root.add_child(_label)


func show(text: String) -> void:
	_label.text = text
	root.visible = true


func hide() -> void:
	root.visible = false


## Coordenadas en píxeles de la ventana; `visible`=false si el punto quedó detrás de la cámara.
func set_screen_position(px: float, py: float, is_visible: bool = true) -> void:
	if not is_visible:
		root.modulate.a = 0.0
		return
	root.modulate.a = 1.0
	var vp: Vector2 = root.get_viewport_rect().size if root.is_inside_tree() else DEFAULT_VIEWPORT
	var w: float = root.size.x
	var h: float = root.size.y
	var cx: float = clampf(px, MARGIN + w / 2.0, vp.x - MARGIN - w / 2.0)
	var cy: float = clampf(py, MARGIN + h, vp.y - MARGIN)
	if absf(cx - _x) < 0.5 and absf(cy - _y) < 0.5:
		return
	_x = cx
	_y = cy
	root.position = Vector2(cx - w / 2.0, cy - h)
