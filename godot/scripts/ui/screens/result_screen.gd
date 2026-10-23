class_name ResultScreen
extends UiScreen
## Resultado del nivel: estrellas animadas, puntaje, Soles ganados, consejos y acciones.
## Equivale a `ResultScreen.ts`.

var _deps: ResultDeps


func _init(deps: ResultDeps) -> void:
	_deps = deps
	modal = true
	var r: LevelResult = deps.result

	root = Control.new()
	root.name = "result"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color("#13302a") if r.won else Color("#3a1d1d")
	bg.corner_radius_top_left = 20
	bg.corner_radius_top_right = 20
	bg.corner_radius_bottom_left = 20
	bg.corner_radius_bottom_right = 20
	bg.content_margin_left = 28
	bg.content_margin_right = 28
	bg.content_margin_top = 22
	bg.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", bg)
	card.custom_minimum_size = Vector2(560, 0)

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)

	var eyebrow: Label = Label.new()
	eyebrow.text = deps.level_name
	eyebrow.add_theme_font_size_override("font_size", 12)
	eyebrow.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	col.add_child(eyebrow)

	var title: Label = Label.new()
	title.text = _title(r)
	title.add_theme_font_size_override("font_size", 26)
	col.add_child(title)

	col.add_child(UiCommon.stars_row(r.stars, 44.0))

	var sub: Label = Label.new()
	sub.text = _subtitle(r)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)

	var kpis: HBoxContainer = HBoxContainer.new()
	kpis.add_theme_constant_override("separation", 18)
	var score_label: String = "puntos"
	if deps.best_score >= 0 and deps.best_score > r.score:
		score_label = "puntos · récord %s" % UiFormat.fmt_int(deps.best_score)
	kpis.add_child(_kpi(UiFormat.fmt_int(r.score), score_label))
	kpis.add_child(_kpi(UiFormat.fmt_pct(r.final_soc_pct), "batería al final", &"battery-plus"))
	kpis.add_child(_kpi("+%s" % UiFormat.fmt_int(deps.soles_earned), "Soles ganados", &"coins"))
	col.add_child(kpis)

	if deps.unlocked_name != "":
		var unlock: HBoxContainer = HBoxContainer.new()
		unlock.add_theme_constant_override("separation", 8)
		unlock.add_child(HudIcon.new(&"star", 20.0, VisualMaterials.C_SUN))
		var unlock_label: Label = Label.new()
		unlock_label.text = "¡Desbloqueaste %s!" % deps.unlocked_name
		unlock.add_child(unlock_label)
		col.add_child(unlock)

	var tips: Array = r.tips.slice(0, mini(3, r.tips.size()))
	if not tips.is_empty():
		var tips_box: VBoxContainer = VBoxContainer.new()
		var tips_head: HBoxContainer = HBoxContainer.new()
		tips_head.add_theme_constant_override("separation", 6)
		tips_head.add_child(HudIcon.new(&"hint", 18.0))
		var tips_title: Label = Label.new()
		tips_title.text = "Consejos"
		tips_head.add_child(tips_title)
		tips_box.add_child(tips_head)
		for t: String in tips:
			var li: Label = Label.new()
			li.text = "· %s" % t
			li.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			tips_box.add_child(li)
		col.add_child(tips_box)

	var btns: HBoxContainer = HBoxContainer.new()
	btns.add_theme_constant_override("separation", 10)
	btns.add_child(UiCommon.action_button("Mapa", deps.on_map, &"ghost", &"map"))
	var has_next_btn: bool = deps.has_next and r.won
	btns.add_child(UiCommon.action_button("Reintentar", deps.on_retry, &"secondary" if has_next_btn else &"primary", &"retry"))
	if has_next_btn:
		btns.add_child(UiCommon.action_button("Siguiente nivel", deps.on_next, &"primary", &"next"))
	col.add_child(btns)

	card.add_child(col)
	center.add_child(card)


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


static func _kpi(value: String, label: String, icon_name: StringName = &"") -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	if icon_name != &"":
		row.add_child(HudIcon.new(icon_name, 18.0))
	var v: Label = Label.new()
	v.text = value
	v.add_theme_font_size_override("font_size", 18)
	row.add_child(v)
	col.add_child(row)
	var l: Label = Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	col.add_child(l)
	return col


func on_back() -> bool:
	if _deps.on_map.is_valid():
		_deps.on_map.call()
	return true


func dispose() -> void:
	pass
