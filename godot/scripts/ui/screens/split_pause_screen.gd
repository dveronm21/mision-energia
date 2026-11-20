class_name SplitPauseScreen
extends UiScreen
## Pausa del versus en pantalla dividida: se frenan las dos partidas y el reloj de la carrera.

var _resume: Callable


## `on_resume`: seguir. `on_exit`: abandonar el versus y volver al menú.
func _init(on_resume: Callable, on_exit: Callable) -> void:
	modal = true
	root = Control.new()
	root.name = "split-pause"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var col: VBoxContainer = UiCommon.modal_card(root, 560.0, 26.0, 14)
	col.add_child(UiTheme.eyebrow("Versus", UiTheme.SUN_INK))
	col.add_child(UiTheme.title("Pausa", 40, UiTheme.INK))
	var btns: HBoxContainer = HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	btns.alignment = BoxContainer.ALIGNMENT_END
	btns.add_child(UiCommon.action_button("Salir del versus", on_exit, &"ghost_ink", &"back"))
	var go: Button = UiCommon.action_button("Seguir", on_resume, &"primary", &"play")
	btns.add_child(go)
	col.add_child(btns)
	UiCommon.focus_later(go)
	_resume = on_resume


func on_back() -> bool:
	_resume.call()
	return true
