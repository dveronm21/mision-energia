class_name ResultScreen
extends UiScreen
## Resultado del nivel: estrellas animadas, puntaje, Soles ganados, consejos y acciones.
## Equivale a `ResultScreen.ts` y `.rs` de styles.ts: tarjeta blanca de 860 px en dos columnas
## (título, estrellas y números a la izquierda; desbloqueo y consejos a la derecha) y los
## botones abajo a la derecha. Las estrellas ganadas caen de a una con rebote (y sonido).

const STAR_PX: float = 54.0
const STAR_OFF: Color = Color("#c9d3d0")
const STAR_DELAY_SEC: float = 0.25
const STAR_STEP_SEC: float = 0.32

var _deps: ResultDeps
var _tweens: Array[Tween] = []


func _init(deps: ResultDeps) -> void:
	_deps = deps
	modal = true
	var r: LevelResult = deps.result

	root = Control.new()
	root.name = "result"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var col: VBoxContainer = UiCommon.modal_card(root, 860.0, 22.0, 14)

	var cols: HBoxContainer = HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	col.add_child(cols)

	# ---- izquierda
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	left.add_child(UiTheme.eyebrow(deps.level_name, UiTheme.SUN_INK))
	left.add_child(UiTheme.title(_title(r), 32, UiTheme.INK))
	left.add_child(_stars(r.stars))
	var sub: Label = UiTheme.label(_subtitle(r), UiTheme.body(700), 16, UiTheme.INK_2)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(sub)
	var kpis: HBoxContainer = HBoxContainer.new()
	kpis.add_theme_constant_override("separation", 8)
	var score_label: String = "puntos"
	if deps.best_score >= 0 and deps.best_score > r.score:
		score_label = "puntos · récord %s" % UiFormat.fmt_int(deps.best_score)
	kpis.add_child(_kpi(UiFormat.fmt_int(r.score), score_label))
	kpis.add_child(_kpi(UiFormat.fmt_pct(r.final_soc_pct), "batería al final", &"battery-plus"))
	kpis.add_child(_kpi("+%s" % UiFormat.fmt_int(deps.soles_earned), "Soles ganados", &"sun"))
	left.add_child(kpis)
	cols.add_child(left)

	# ---- derecha
	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	if deps.unlocked_name != "":
		right.add_child(_unlock_pill(deps.unlocked_name))
	var tips: Array = r.tips.slice(0, mini(3, r.tips.size()))
	if not tips.is_empty():
		right.add_child(_tips_box(tips))
	cols.add_child(right)

	# ---- botones
	var btns: HBoxContainer = HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	btns.alignment = BoxContainer.ALIGNMENT_END
	btns.add_child(UiCommon.action_button("Mapa", deps.on_map, &"ghost_ink", &"map"))
	var has_next_btn: bool = deps.has_next and r.won
	var retry: Button = UiCommon.action_button("Reintentar", deps.on_retry, &"secondary" if has_next_btn else &"primary", &"retry")
	btns.add_child(retry)
	var focus: Button = retry
	if has_next_btn:
		focus = UiCommon.action_button("Siguiente nivel", deps.on_next, &"primary", &"next")
		btns.add_child(focus)
	col.add_child(btns)
	UiCommon.focus_later(focus)


## `.rs-stars`: tres estrellas; las ganadas en sol con sombra dura, las otras en gris claro.
func _stars(won: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for i: int in 3:
		var on: bool = i < won
		var slot: Control = Control.new()
		slot.custom_minimum_size = Vector2(STAR_PX, STAR_PX + 3.0)
		if on:
			var shadow: HudIcon = HudIcon.new(&"star_fill", STAR_PX, UiTheme.SUN_DARK)
			shadow.position = Vector2(0, 3)
			slot.add_child(shadow)
			var star: HudIcon = HudIcon.new(&"star_fill", STAR_PX, UiTheme.SUN)
			slot.add_child(star)
			_schedule_pop(slot, i)
		else:
			var off: HudIcon = HudIcon.new(&"star", STAR_PX, STAR_OFF)
			off.stroke_width = 3.0
			slot.add_child(off)
		row.add_child(slot)
	return row


## `@keyframes starPop`: crece desde 0 girando −30° con sobrepaso, una detrás de otra.
func _schedule_pop(slot: Control, i: int) -> void:
	slot.scale = Vector2.ZERO
	slot.pivot_offset = Vector2(STAR_PX, STAR_PX) / 2.0
	slot.rotation = deg_to_rad(-30.0)
	slot.tree_entered.connect(func() -> void:
		var t: Tween = slot.create_tween()
		t.tween_interval(STAR_DELAY_SEC + i * STAR_STEP_SEC)
		t.tween_callback(func() -> void:
			if _deps.audio != null:
				_deps.audio.play("star_%d" % (i + 1))
			FxBurst.sparkle(slot, slot.get_global_rect().get_center(), 12 + i * 4))
		t.tween_property(slot, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(slot, "rotation", 0.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tweens.append(t), CONNECT_ONE_SHOT)


static func _title(r: LevelResult) -> String:
	if not r.won:
		return "Se apagó la ciudad"
	match r.stars:
		3:
			return "¡Planta perfecta!"
		2:
			return "¡Muy bien!"
		_:
			return "¡Lo lograste!"


static func _subtitle(r: LevelResult) -> String:
	if not r.won:
		if r.blackout_hour != LevelResult.NO_BLACKOUT:
			return "La batería se agotó a las %s." % JsMath.fmt_hour(r.blackout_hour)
		return "La planta no alcanzó para toda la noche."
	return "La ciudad tuvo luz toda la noche."


## `.rs-kpi`: recuadro gris claro con el número en Fredoka 24 y la etiqueta abajo.
static func _kpi(value: String, label: String, icon_name: StringName = &"") -> PanelContainer:
	var box: PanelContainer = PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s: StyleBoxFlat = UiTheme.box(UiTheme.PAPER_2, 14)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	box.add_theme_stylebox_override("panel", s)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	if icon_name != &"":
		var ic: HudIcon = HudIcon.new(icon_name, 20.0, UiTheme.SUN_DARK)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
	row.add_child(UiTheme.label(value, UiTheme.display(600), 24, UiTheme.INK))
	col.add_child(row)
	var l: Label = UiTheme.label(label, UiTheme.body(700), 13, UiTheme.INK_3)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(l)
	box.add_child(col)
	return box


## `.rs-unlock`: franja crema con la estrella y el nivel desbloqueado.
static func _unlock_pill(level_name: String) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var s: StyleBoxFlat = UiTheme.box(Color("#fff1dc"), 14)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", s)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var ic: HudIcon = HudIcon.new(&"star_fill", 20.0, UiTheme.SUN)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	row.add_child(UiTheme.label("¡Desbloqueaste %s!" % level_name, UiTheme.body(800), 16, UiTheme.INK))
	p.add_child(row)
	return p


## `.rs-tips`: caja verde clara con "Consejos" y la lista.
static func _tips_box(tips: Array) -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	var s: StyleBoxFlat = UiTheme.box(Color("#e6f4ea"), 16)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", s)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var ic: HudIcon = HudIcon.new(&"hint", 20.0, UiTheme.LEAF_DARK)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(ic)
	head.add_child(UiTheme.label("Consejos", UiTheme.display(600), 18, UiTheme.LEAF_DARK))
	col.add_child(head)
	for t: Variant in tips:
		var li: Label = UiTheme.label("•  %s" % String(t), UiTheme.body(700), 15, UiTheme.INK_2)
		li.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(li)
	p.add_child(col)
	return p


## Al ganar, confeti cuando terminó de caer la última estrella (con 3 estrellas, el doble).
func on_enter() -> void:
	var r: LevelResult = _deps.result
	if not r.won or not root.is_inside_tree():
		return
	var t: Tween = root.create_tween()
	t.tween_interval(STAR_DELAY_SEC + maxi(r.stars, 1) * STAR_STEP_SEC + 0.15)
	t.tween_callback(func() -> void:
		FxBurst.confetti(root, 150 if r.stars >= 3 else 70)
		if _deps.audio != null and r.stars >= 3:
			_deps.audio.play("confetti"))
	_tweens.append(t)


func on_back() -> bool:
	if _deps.on_map.is_valid():
		_deps.on_map.call()
	return true


func dispose() -> void:
	for t: Tween in _tweens:
		if t.is_valid():
			t.kill()
	_tweens.clear()
