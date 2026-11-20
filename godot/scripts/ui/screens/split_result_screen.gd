class_name SplitResultScreen
extends UiScreen
## Resultado del versus en pantalla dividida: quién dejó primero la planta al 100 % y en cuánto.


## `on_again`: revancha en el mismo nivel. `on_levels`: elegir otro nivel. `on_exit`: al menú.
func _init(versus: SplitVersus, on_again: Callable, on_levels: Callable, on_exit: Callable, audio: AudioSynth = null) -> void:
	modal = true
	root = Control.new()
	root.name = "split-result"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var col: VBoxContainer = UiCommon.modal_card(root, 760.0, 26.0, 14)
	col.add_child(UiTheme.eyebrow("Versus · " + versus.level.name, UiTheme.SUN_INK))
	col.add_child(UiTheme.title(title_text(versus), 40, UiTheme.INK))
	var w: SplitSide = versus.winner_side()
	var sub: String = ("Dejó la planta funcionando al 100 %% en %s." % DuelResultScreen.fmt_time(versus.win_sec)) if w != null \
		else "Las dos plantas terminaron el día con una fila fallando. ¡Va la revancha!"
	var l: Label = UiTheme.label(sub, UiTheme.body(700), 20, UiTheme.INK_2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(l)
	var btns: HBoxContainer = HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	btns.alignment = BoxContainer.ALIGNMENT_END
	btns.add_child(UiCommon.action_button("Salir", on_exit, &"ghost_ink", &"back"))
	btns.add_child(UiCommon.action_button("Otro nivel", on_levels, &"secondary"))
	var again: Button = UiCommon.action_button("Revancha", on_again, &"primary", &"retry")
	btns.add_child(again)
	col.add_child(btns)
	UiCommon.focus_later(again)
	if audio != null:
		audio.play("star_3" if w != null else "bad")


func on_back() -> bool:
	return true


static func title_text(versus: SplitVersus) -> String:
	var w: SplitSide = versus.winner_side()
	return "¡Ganó %s!" % w.name if w != null else "Nadie llegó al 100 %"

