class_name SplitVersus
extends RefCounted
## Versus en pantalla dividida: dos partidas del mismo nivel a la vez en el mismo tele, una por
## mitad (cada una con su mundo 3D, su cámara y su HUD). Mismas reglas que el duelo entre dos
## teles (`DuelMatch`): la misma compra fija, sin potenciadores, a velocidad ×1, y gana el
## primero que deja la planta activada y funcionando al 100 %.
##
## Cada lado lo maneja una tablet (asiento 0/1) o, si falta una, el teclado de la PC (asiento −1).
##
##   var v := SplitVersus.new(level, players, deps)
##   ui.hud_layer.add_child(v.root); v.start(quality)
##   # cada cuadro:
##   for e: StringName in v.update(dt, [mover_izq, mover_der]): ...   # &"go", &"finished"

enum Phase { COUNTDOWN, PLAYING, FINISHED }

const COUNTDOWN_SEC: float = 3.0
## Lado del ganador cuando nadie llegó al 100 % (los dos días terminaron con la planta fallando).
const NO_WINNER: int = -1
const DIVIDER_W: float = 6.0
## Escala del mundo y del HUD de cada mitad (más chico que en una partida a pantalla completa).
const HALF_SCALE: float = 0.72


var root: Control
var level: LevelDefinition
var purchase: Purchase
var phase: Phase = Phase.COUNTDOWN
## Segundos que faltan para la largada (en COUNTDOWN).
var countdown: float = COUNTDOWN_SEC
## Segundos desde la largada.
var elapsed: float = 0.0
## Índice del lado ganador (0 = izquierda, 1 = derecha) o `NO_WINNER`.
var winner: int = NO_WINNER
var win_sec: float = 0.0
var paused: bool = false

var _sides: Array[SplitSide] = []
var _count_label: Label
var _events: Array[StringName] = []
var _disposed: bool = false


## `players`: hasta 2 de {slot: int (−1 = teclado), name: String, color: Color}, de izquierda a
## derecha. `deps`: {audio, inventory, boosters, on_feedback: Callable(slot, kind, text)}.
func _init(p_level: LevelDefinition, players: Array[Dictionary], deps: Dictionary) -> void:
	level = p_level
	purchase = DuelMatch.fixed_purchase(level.id)
	root = Control.new()
	root.name = "split-versus"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)
	for i: int in players.size():
		if i > 0:
			var line: ColorRect = ColorRect.new()
			line.color = UiTheme.INK
			line.custom_minimum_size.x = DIVIDER_W
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(line)
		var side: SplitSide = _make_side(players[i], deps)
		row.add_child(side.area)
		_sides.append(side)

	_count_label = UiTheme.label("3", UiTheme.display(700), 180, UiTheme.SUN)
	_count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.add_theme_color_override("font_outline_color", UiTheme.INK)
	_count_label.add_theme_constant_override("outline_size", 18)
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_count_label)


func _make_side(p: Dictionary, deps: Dictionary) -> SplitSide:
	var side: SplitSide = SplitSide.new()
	side.slot = int(p.get("slot", -1))
	side.name = String(p.get("name", "Jugador"))
	side.color = p.get("color", UiTheme.SUN)

	side.area = Control.new()
	side.area.name = "half-%d" % side.slot
	side.area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.area.size_flags_stretch_ratio = 1.0
	side.area.clip_contents = true
	side.area.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Mundo y HUD van juntos en un lienzo más grande que la mitad, achicado con `HALF_SCALE`: así
	# el HUD entra en media pantalla y el 3D se dibuja casi a la resolución real de la pantalla.
	var holder: Control = Control.new()
	holder.name = "scaled"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.scale = Vector2(HALF_SCALE, HALF_SCALE)
	side.area.add_child(holder)
	side.area.resized.connect(func() -> void: holder.size = side.area.size / HALF_SCALE)

	var box: SubViewportContainer = SubViewportContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.stretch = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.viewport = SubViewport.new()
	# Cada mitad con su propio mundo: si no, las dos partidas se dibujarían una encima de la otra.
	side.viewport.own_world_3d = true
	side.viewport.handle_input_locally = false
	side.viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	box.add_child(side.viewport)
	holder.add_child(box)

	side.hud = Hud.new(HudCallbacks.new())
	side.hud.set_tv_mode(true)
	side.hud.force_compact = true
	holder.add_child(side.hud.root)
	side.ui = SplitHalfUi.new()
	holder.add_child(side.ui.root)
	side.banner = DuelBanner.new()
	# La franja de cada lado con el color de su tablet, para saber de un vistazo de quién es cada mitad.
	var st: StyleBoxFlat = (side.banner.root.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	st.border_color = side.color
	st.set_border_width_all(3)
	side.banner.root.add_theme_stylebox_override("panel", st)
	side.area.add_child(side.banner.root)

	var d: SessionDeps = SessionDeps.new()
	d.level = level
	d.purchase = purchase
	d.spent = 0
	d.active_boosters = [] as Array[StringName]
	d.cosmetics = {}
	d.audio = deps.get("audio")
	d.inventory = deps.get("inventory")
	d.boosters = deps.get("boosters")
	d.hud = side.hud
	d.ui = side.ui
	d.on_finished = func(_r: LevelResult) -> void: _on_day_over()
	side.session = GameSession.new(d)
	side.session.add_technician(side.slot, side.name, side.color)
	var fb: Callable = deps.get("on_feedback", Callable())
	if fb.is_valid() and side.slot >= 0:
		var my_slot: int = side.slot
		# Lo de cada partida va solo a la tablet de ese lado (el clima de una no le importa al otro).
		side.session.on_feedback = func(_slot: int, kind: StringName, text: String) -> void: fb.call(my_slot, kind, text)
	side.session.paused = true
	return side


## Con `root` ya en la escena: mete cada mundo en su mitad, fija la calidad y arranca la intro.
func start(quality: int) -> void:
	for side: SplitSide in _sides:
		side.viewport.add_child(side.session.root)
		side.session.set_quality(quality)
		side.session.start_intro()
		_refresh_banner(side)


func sides() -> Array[SplitSide]:
	return _sides


func side_for_slot(slot: int) -> SplitSide:
	for side: SplitSide in _sides:
		if side.slot == slot:
			return side
	return null


## Partida del lado que se juega con el teclado (sin tablet), o null.
func keyboard_session() -> GameSession:
	var side: SplitSide = side_for_slot(-1)
	return side.session if side != null else null


## Un cuadro. `moves[i]` mueve al técnico del lado `i`. Devuelve lo que pasó (&"go", &"finished").
func update(dt: float, moves: Array[Vector2]) -> Array[StringName]:
	if _disposed:
		return [] as Array[StringName]
	match phase:
		Phase.COUNTDOWN:
			if not paused:
				countdown -= dt
			if countdown <= 0.0:
				countdown = 0.0
				phase = Phase.PLAYING
				elapsed = 0.0
				for side: SplitSide in _sides:
					side.session.paused = false
				_events.append(&"go")
		Phase.PLAYING:
			if not paused:
				elapsed += dt
	_tick_count_label(dt)
	for i: int in _sides.size():
		var side: SplitSide = _sides[i]
		var mv: Vector2 = moves[i] if i < moves.size() and phase == Phase.PLAYING and not paused else Vector2.ZERO
		side.session.update_multi(dt, [mv] as Array[Vector2])
		_refresh_banner(side)
	if phase == Phase.PLAYING:
		_check_winner()
	var out: Array[StringName] = _events
	_events = []
	return out


func set_paused(on: bool) -> void:
	paused = on
	if phase == Phase.PLAYING:
		for side: SplitSide in _sides:
			side.session.paused = on


func winner_side() -> SplitSide:
	return _sides[winner] if winner >= 0 and winner < _sides.size() else null


func _check_winner() -> void:
	for i: int in _sides.size():
		if _sides[i].session.plant_ok():
			_finish(i)
			return


## El día de una partida terminó sin ganador todavía: si ya no queda ninguna corriendo, nadie
## llegó al 100 % (las dos activaron con una fila fallando y no la repararon).
func _on_day_over() -> void:
	if phase != Phase.PLAYING:
		return
	for side: SplitSide in _sides:
		if side.session.phase() != SessionPort.PHASE_FINISHED:
			return
	_finish(NO_WINNER)


func _finish(who: int) -> void:
	winner = who
	win_sec = elapsed
	phase = Phase.FINISHED
	for side: SplitSide in _sides:
		side.session.paused = true
	var w: SplitSide = winner_side()
	if w != null:
		w.session.cam_rig.celebrate()
	_events.append(&"finished")


func _tick_count_label(dt: float) -> void:
	if phase == Phase.COUNTDOWN:
		_count_label.visible = true
		_count_label.text = str(ceili(countdown))
		_count_label.modulate.a = 1.0
	elif phase == Phase.PLAYING and elapsed < 0.9:
		_count_label.visible = true
		_count_label.text = "¡Ya!"
		_count_label.modulate.a = clampf(1.0 - (elapsed - 0.4) / 0.5, 0.0, 1.0)
	else:
		_count_label.visible = false


func _refresh_banner(side: SplitSide) -> void:
	var t: String = DuelBanner.describe(side.name, side.session.duel_progress())
	if phase == Phase.COUNTDOWN:
		t = "%s · %s" % [side.name, "teclado" if side.slot < 0 else "tablet"]
	if t != side.last_banner:
		side.last_banner = t
		side.banner.set_text(t)


## Lo que ve la tablet de un lado mientras corre la cuenta regresiva.
func countdown_text() -> String:
	return "¡Preparados! %d…" % ceili(countdown) if countdown > 0.0 else "¡Ya!"


func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	for side: SplitSide in _sides:
		side.session.dispose()
	root.queue_free()
