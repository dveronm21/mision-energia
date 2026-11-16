class_name DuelBanner
extends RefCounted
## Franja abajo al centro durante el duelo: cómo va el rival en la otra pantalla
## ("Ana: 3/4 paneles · batería · 2/3 cables"), para el público y para el jugador.

var root: PanelContainer
var _label: Label


func _init() -> void:
	root = PanelContainer.new()
	root.name = "duel-banner"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = UiTheme.hud_panel(999)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	root.add_theme_stylebox_override("panel", style)
	root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.offset_bottom = -14.0
	_label = UiTheme.label("", UiTheme.body(800), 20, UiTheme.FG)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_label)


func set_text(t: String) -> void:
	_label.text = t


## Texto de la franja a partir del avance que mandó el otro tele.
static func describe(rival: String, p: Dictionary) -> String:
	if p.is_empty():
		return "%s: arrancando…" % rival
	if bool(p.get("ok", false)):
		return "¡%s dejó la planta al 100 %%!" % rival
	if bool(p.get("activated", false)):
		return "%s activó la planta, pero le falla una fila" % rival
	var parts: Array[String] = ["%d/%d paneles" % [int(p.get("panels", 0)), int(p.get("total", 0))]]
	if bool(p.get("protection", false)):
		parts.append("protección")
	var bt: int = int(p.get("batteries_total", 0))
	if bt > 0 and int(p.get("batteries", 0)) > 0:
		parts.append("batería" if bt == 1 else "%d/%d baterías" % [int(p.get("batteries", 0)), bt])
	if int(p.get("cables", 0)) > 0:
		parts.append("%d/3 cables" % int(p.get("cables", 0)))
	return "%s: %s" % [rival, " · ".join(parts)]
