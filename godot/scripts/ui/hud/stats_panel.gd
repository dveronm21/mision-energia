class_name StatsPanel
extends StatsPanelPort
## Estado de la planta (arriba a la derecha): hora, generación, consumo y batería.
## Equivale a `StatsPanel.ts`.

var root: PanelContainer

var _clock: Label
var _phase: Label
var _gen: Label
var _load: Label
var _bat: Label
var _bar_bg: ColorRect
var _bar_fill: ColorRect


func _init() -> void:
	root = PanelContainer.new()
	root.name = "hud-stats"
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.055, 0.141, 0.125, 0.82)
	bg.corner_radius_top_left = 14
	bg.corner_radius_top_right = 14
	bg.corner_radius_bottom_left = 14
	bg.corner_radius_bottom_right = 14
	bg.content_margin_left = 14
	bg.content_margin_right = 14
	bg.content_margin_top = 10
	bg.content_margin_bottom = 10
	root.add_theme_stylebox_override("panel", bg)
	root.custom_minimum_size = Vector2(200, 0)
	root.visible = false

	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	root.add_child(col)

	var top: HBoxContainer = HBoxContainer.new()
	_clock = Label.new()
	_clock.text = "10:00"
	_clock.add_theme_font_size_override("font_size", 18)
	_clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_clock)
	_phase = Label.new()
	_phase.text = "Día"
	top.add_child(_phase)
	col.add_child(top)

	_gen = Label.new()
	col.add_child(_row(&"panel", "Generan", _gen))
	_load = Label.new()
	col.add_child(_row(&"search", "Consumo", _load))
	_bat = Label.new()
	col.add_child(_row(&"battery-plus", "Batería", _bat))

	var bar_wrap: Control = Control.new()
	bar_wrap.custom_minimum_size = Vector2(0, 10)
	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(1, 1, 1, 0.15)
	_bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_wrap.add_child(_bar_bg)
	_bar_fill = ColorRect.new()
	_bar_fill.color = VisualMaterials.C_OK
	_bar_fill.anchor_left = 0.0
	_bar_fill.anchor_right = 0.0
	_bar_fill.anchor_top = 0.0
	_bar_fill.anchor_bottom = 1.0
	bar_wrap.add_child(_bar_fill)
	col.add_child(bar_wrap)


func _row(ic: StringName, label_text: String, value: Label) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(HudIcon.new(ic, 16.0))
	var l: Label = Label.new()
	l.text = label_text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	value.text = "0,0 kW"
	row.add_child(value)
	return row


func set_visible(on: bool) -> void:
	root.visible = on


func update(s: SimSnapshot) -> void:
	_clock.text = JsMath.fmt_hour(s.hour)
	_phase.text = "Apagón" if s.blackout else ("Noche" if s.is_night else ("Nublado" if s.irradiance < 0.35 else "Día"))
	_gen.text = UiFormat.fmt_kw(s.gen_kw)
	_load.text = UiFormat.fmt_kw(s.load_kw)
	_bat.text = UiFormat.fmt_pct(s.soc_pct)
	var pct: float = clampf(s.soc_pct, 0.0, 1.0)
	_bar_fill.anchor_right = pct
	_bar_fill.color = VisualMaterials.C_BAD if s.soc_pct < 0.2 else (VisualMaterials.C_BLUE if s.net_kw > 0.05 else VisualMaterials.C_OK)
