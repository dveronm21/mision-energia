class_name StatsPanel
extends StatsPanelPort
## Estado de la planta (arriba a la derecha): hora, generación, consumo y batería.
## Equivale a `StatsPanel.ts` y `.hud-stats` de styles.ts: reloj grande en Fredoka, fase en
## mayúsculas (celeste de noche, rosada en apagón), filas con el valor en Fredoka y barra de
## batería (naranja si está baja).

const PHASE_NIGHT: Color = Color("#a9c8ff")
const PHASE_BLACKOUT: Color = Color("#ffb4a8")

var root: PanelContainer

var _clock: Label
var _phase: Label
var _gen: Label
var _load: Label
var _bat: Label
var _bar_fill: Panel
var _fill_style: StyleBoxFlat


func _init() -> void:
	root = PanelContainer.new()
	root.name = "hud-stats"
	var bg: StyleBoxFlat = UiTheme.hud_panel(16)
	bg.content_margin_left = 14
	bg.content_margin_right = 14
	bg.content_margin_top = 10
	bg.content_margin_bottom = 12
	root.add_theme_stylebox_override("panel", bg)
	root.custom_minimum_size = Vector2(220, 0)
	root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.visible = false

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	root.add_child(col)

	var top: HBoxContainer = HBoxContainer.new()
	_clock = UiTheme.label("10:00", UiTheme.display(600), 32)
	_clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_clock)
	_phase = UiTheme.eyebrow("Día", UiTheme.MUTED, 13)
	_phase.size_flags_vertical = Control.SIZE_SHRINK_END
	top.add_child(_phase)
	col.add_child(top)

	_gen = _value()
	col.add_child(_row(&"panel", "Generan", _gen))
	_load = _value()
	col.add_child(_row(&"bolt", "Consumo", _load))
	_bat = _value()
	col.add_child(_row(&"battery-plus", "Batería", _bat))

	var bar: Panel = Panel.new()
	bar.custom_minimum_size = Vector2(0, 12)
	bar.clip_contents = true
	bar.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.HUD_2, 999))
	_bar_fill = Panel.new()
	_bar_fill.anchor_left = 0.0
	_bar_fill.anchor_right = 0.0
	_bar_fill.anchor_top = 0.0
	_bar_fill.anchor_bottom = 1.0
	_fill_style = UiTheme.box(UiTheme.LEAF, 999)
	_bar_fill.add_theme_stylebox_override("panel", _fill_style)
	bar.add_child(_bar_fill)
	col.add_child(bar)


static func _value() -> Label:
	return UiTheme.label("Nada", UiTheme.display(600), 17)


## Sin valores eléctricos en pantalla: la generación se muestra por nivel de sol.
static func gen_level(s: SimSnapshot) -> String:
	if s.gen_kw <= 0.01:
		return "Nada"
	if s.irradiance >= 0.6:
		return "Alta"
	return "Media" if s.irradiance >= 0.3 else "Baja"


## De dónde sale la energía que se consume ahora.
static func load_source(s: SimSnapshot) -> String:
	if s.blackout:
		return "Sin luz"
	return "Del sol" if s.net_kw >= 0.0 else "De batería"


func _row(ic: StringName, label_text: String, value: Label) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var icon: HudIcon = HudIcon.new(ic, 16.0, UiTheme.MUTED)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var l: Label = UiTheme.label(label_text, UiTheme.body(700), 14, UiTheme.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	row.add_child(value)
	return row


func set_visible(on: bool) -> void:
	if on and not root.visible and root.is_inside_tree():
		# Entra deslizándose desde la derecha la primera vez que arranca la planta.
		root.modulate.a = 0.0
		var t: Tween = root.create_tween().set_parallel(true)
		t.tween_property(root, "modulate:a", 1.0, 0.25)
	root.visible = on


func update(s: SimSnapshot) -> void:
	_clock.text = JsMath.fmt_hour(s.hour)
	_phase.text = ("Apagón" if s.blackout else ("Noche" if s.is_night else ("Nublado" if s.irradiance < 0.35 else "Día"))).to_upper()
	_phase.add_theme_color_override("font_color", PHASE_BLACKOUT if s.blackout else (PHASE_NIGHT if s.is_night else UiTheme.MUTED))
	_gen.text = gen_level(s)
	_load.text = load_source(s)
	_bat.text = UiFormat.fmt_pct(s.soc_pct)
	_bar_fill.anchor_right = clampf(s.soc_pct, 0.0, 1.0)
	_fill_style.bg_color = UiTheme.WARN if s.soc_pct < 0.2 else UiTheme.LEAF
