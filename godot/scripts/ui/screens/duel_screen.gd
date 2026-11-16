class_name DuelScreen
extends UiScreen
## Sala del duelo entre dos teles: busca la otra pantalla, el árbitro elige el nivel, los dos
## confirman "¡Listo!" y corre la cuenta regresiva. La App llama `refresh()` cuando cambia la fase
## del duelo y `tick()` cada cuadro (para el número de la cuenta regresiva).

var _duel: DuelMatch
var _levels: Array[LevelDefinition]
var _frame: PageFrame
var _count_label: Label
var _shown_phase: int = -1
var _on_back: Callable


## `on_back`: Callable() -> void (salir del duelo).
func _init(duel: DuelMatch, levels: Array[LevelDefinition], on_back: Callable) -> void:
	_duel = duel
	_levels = levels
	_on_back = on_back
	_frame = UiCommon.page_frame({"title": "Duelo", "eyebrow": "Dos pantallas, una carrera", "on_back": on_back,
		"back_label": "Salir del duelo", "cls": "duel"})
	root = _frame.root
	refresh()


func on_enter() -> void:
	refresh()


func on_back() -> bool:
	_on_back.call()
	return true


## Rearma el contenido según la fase del duelo.
func refresh() -> void:
	_shown_phase = _duel.phase
	for c: Node in _frame.body.get_children():
		c.queue_free()
	_count_label = null
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var focus: Control = null
	match _duel.phase:
		DuelMatch.Phase.SEARCHING:
			col.add_child(_big("Buscando la otra pantalla…"))
			col.add_child(_text("Abrí Duelo también en el otro tele. Las dos pantallas tienen que estar en la misma Wi-Fi."))
			var ip: String = NetUtils.lan_ip()
			if ip != "":
				col.add_child(_text("Esta pantalla: %s" % ip, UiTheme.SUN, 18))
		DuelMatch.Phase.LOBBY:
			col.add_child(_big("¡Conectado con %s!" % _duel.peer_name()))
			if _duel.is_referee():
				col.add_child(_text("Elegí el nivel del duelo:"))
				var grid: GridContainer = GridContainer.new()
				grid.columns = 3
				grid.add_theme_constant_override("h_separation", 12)
				grid.add_theme_constant_override("v_separation", 12)
				for l: LevelDefinition in _levels:
					var id: String = l.id
					var b: Button = UiCommon.action_button("%d · %s" % [l.order, l.name], func() -> void: _duel.choose_level(id), &"secondary")
					b.custom_minimum_size.x = 260
					grid.add_child(b)
					if focus == null:
						focus = b
				col.add_child(UiCommon.max_width(grid, 840.0))
			else:
				col.add_child(_text("La otra pantalla está eligiendo el nivel…"))
		DuelMatch.Phase.SETUP:
			var lv: LevelDefinition = _level(_duel.level_id)
			var eb: Label = UiTheme.eyebrow("Nivel %d" % lv.order if lv != null else "Nivel", UiTheme.SUN, 16)
			eb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(eb)
			col.add_child(_big(lv.name if lv != null else _duel.level_id))
			var p: Purchase = _duel.purchase()
			col.add_child(_text("Los dos arrancan con %d paneles y %s, sin potenciadores. Gana el primero que deja la planta funcionando al 100 %%." % [
				p.panels, "1 batería" if p.batteries == 1 else "%d baterías" % p.batteries]))
			if _duel.my_ready:
				col.add_child(_text("¡Listo! Esperando a %s…" % _duel.peer_name(), UiTheme.SUN, 22))
			else:
				var ready: Button = UiCommon.action_button("¡Listo!", _duel.set_ready, &"primary", &"play", true)
				ready.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				ready.custom_minimum_size.x = 320
				col.add_child(ready)
				focus = ready
				if _duel.peer_ready:
					col.add_child(_text("%s ya está lista." % _upper_first(_duel.peer_name()), UiTheme.SUN, 18))
		DuelMatch.Phase.COUNTDOWN:
			col.add_child(_text("¡Preparados!"))
			_count_label = UiTheme.label("3", UiTheme.display(700), 160, UiTheme.SUN)
			_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			col.add_child(_count_label)
			tick()
		_:
			pass
	_frame.body.add_child(col)
	if focus != null:
		UiCommon.focus_later(focus)


## Lo que ve cada tablet de este tele mientras se arma el duelo.
static func tablet_text(duel: DuelMatch) -> String:
	match duel.phase:
		DuelMatch.Phase.SEARCHING:
			return "Duelo: buscando la otra pantalla…"
		DuelMatch.Phase.LOBBY:
			return "Duelo contra %s: elegí el nivel en el tele" % duel.peer_name() if duel.is_referee() 				else "Duelo contra %s: el otro tele elige el nivel" % duel.peer_name()
		DuelMatch.Phase.SETUP:
			return "Esperando a %s…" % duel.peer_name() if duel.my_ready else "Tocá el botón para decir ¡Listo!"
		DuelMatch.Phase.COUNTDOWN:
			return "¡Preparados! %d…" % ceili(duel.countdown) if duel.countdown > 0.0 else "¡Ya!"
		_:
			return "Tocá una opción o usá las flechas"


## Cada cuadro: número de la cuenta regresiva.
func tick() -> void:
	if _count_label != null:
		_count_label.text = str(ceili(_duel.countdown)) if _duel.countdown > 0.0 else "¡Ya!"


func _level(id: String) -> LevelDefinition:
	for l: LevelDefinition in _levels:
		if l.id == id:
			return l
	return null


static func _upper_first(t: String) -> String:
	return t.left(1).to_upper() + t.substr(1)


static func _big(t: String) -> Label:
	var l: Label = UiTheme.title(t, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func _text(t: String, color: Color = UiTheme.MUTED, font_size: int = 22) -> Label:
	var l: Label = UiTheme.label(t, UiTheme.body(700), font_size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
