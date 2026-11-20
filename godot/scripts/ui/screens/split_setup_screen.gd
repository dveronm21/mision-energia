class_name SplitSetupScreen
extends UiScreen
## Versus en pantalla dividida: quién juega en cada mitad y qué nivel. Al elegir el nivel arranca
## la cuenta regresiva (la App arma las dos partidas).

var _players_label: Label
var _on_back: Callable


## `on_pick`: Callable(level_id: String) -> void. `on_back`: Callable() -> void.
func _init(levels: Array[LevelDefinition], on_pick: Callable, on_back: Callable) -> void:
	_on_back = on_back
	var frame: PageFrame = UiCommon.page_frame({"title": "Versus", "eyebrow": "Pantalla dividida, una carrera",
		"on_back": on_back, "back_label": "Volver", "cls": "duel"})
	root = frame.root
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_players_label = DuelScreen._text("", UiTheme.SUN, 24)
	col.add_child(_players_label)
	col.add_child(DuelScreen._text("Los dos arman la misma planta, cada uno en su mitad de la pantalla. Gana el primero que la deja funcionando al 100 %."))
	col.add_child(DuelScreen._text("Elegí el nivel:", UiTheme.FG, 22))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var focus: Control = null
	for l: LevelDefinition in levels:
		var id: String = l.id
		var b: Button = UiCommon.action_button("%d · %s" % [l.order, l.name], func() -> void: on_pick.call(id), &"secondary")
		b.custom_minimum_size.x = 260
		grid.add_child(b)
		if focus == null:
			focus = b
	col.add_child(UiCommon.max_width(grid, 840.0))
	frame.body.add_child(col)
	if focus != null:
		UiCommon.focus_later(focus)


func on_back() -> bool:
	_on_back.call()
	return true


## "Izquierda: Ana · Derecha: Beto". Se llama cada cuadro (una tablet puede entrar mientras tanto).
func set_players_text(t: String) -> void:
	if _players_label.text != t:
		_players_label.text = t


## `players`: los mismos diccionarios que recibe `SplitVersus` ({slot, name}).
static func players_text(players: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	var where: Array[String] = ["Izquierda", "Derecha"]
	for i: int in mini(players.size(), 2):
		var p: Dictionary = players[i]
		var who: String = String(p.get("name", "Jugador"))
		if int(p.get("slot", -1)) < 0:
			who += " (teclado)"
		parts.append("%s: %s" % [where[i], who])
	return " · ".join(parts)
