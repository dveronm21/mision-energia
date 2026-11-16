class_name DuelResultScreen
extends UiScreen
## Resultado del duelo, igual en los dos teles: quién dejó primero la planta al 100 % y en cuánto.

var _duel: DuelMatch


## `on_again`: otra ronda (los dos teles vuelven a la sala). `on_exit`: salir del duelo.
func _init(duel: DuelMatch, level_name: String, on_again: Callable, on_exit: Callable, audio: AudioSynth = null) -> void:
	_duel = duel
	modal = true
	root = Control.new()
	root.name = "duel-result"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var col: VBoxContainer = UiCommon.modal_card(root, 760.0, 26.0, 14)
	var won: bool = duel.winner == DuelMatch.WIN_ME
	col.add_child(UiTheme.eyebrow("Duelo · " + level_name, UiTheme.SUN_INK))
	var title: String = "¡Ganaste el duelo!" if won else "Ganó %s" % duel.peer_name()
	col.add_child(UiTheme.title(title, 40, UiTheme.INK))
	var sub: String = ("Dejaste la planta funcionando al 100 %% en %s." if won else "Dejó la planta funcionando al 100 %% en %s.") % fmt_time(duel.win_sec)
	if duel.peer_lost:
		sub += " Se cortó la conexión con la otra pantalla."
	var l: Label = UiTheme.label(sub, UiTheme.body(700), 20, UiTheme.INK_2)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(l)
	var btns: HBoxContainer = HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	btns.alignment = BoxContainer.ALIGNMENT_END
	btns.add_child(UiCommon.action_button("Salir del duelo", on_exit, &"ghost_ink", &"back"))
	var again: Button = UiCommon.action_button("Otra ronda", on_again, &"primary", &"retry")
	btns.add_child(again)
	col.add_child(btns)
	UiCommon.focus_later(again)
	if audio != null:
		audio.play("star_3" if won else "bad")


func on_back() -> bool:
	return true


## Lo que ve cada tablet de este tele cuando termina el duelo.
static func tablet_text(duel: DuelMatch) -> String:
	if duel.winner == DuelMatch.WIN_ME:
		return "¡Ganaste el duelo en %s!" % fmt_time(duel.win_sec)
	return "Ganó %s en %s. ¡Va la revancha!" % [duel.peer_name(), fmt_time(duel.win_sec)]


## 83.4 → "1:23".
static func fmt_time(sec: float) -> String:
	var s: int = maxi(0, floori(sec))
	return "%d:%02d" % [s / 60, s % 60]
