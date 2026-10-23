class_name Logo
extends RefCounted
## Logotipo: sol + "MISIÓN ENERGÍA" (equivale a `logo.ts` y `.logo` de styles.ts): disco de
## sol con halo y labio, al lado las dos palabras en Fredoka 700.

## `scale`: 1.0 = tamaño de tablet/TV de la web (sol 116 px, letras 60/72).
static func build(scale: float = 1.0) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(16 * scale))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var disc_px: float = 116.0 * scale
	var halo: int = int(8 * scale)
	var disc: PanelContainer = PanelContainer.new()
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.custom_minimum_size = Vector2(disc_px, disc_px)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var s: StyleBoxFlat = UiTheme.box(UiTheme.SUN, 999)
	s.border_color = UiTheme.SUN_DARK
	s.border_width_bottom = int(6 * scale)
	s.shadow_color = Color(UiTheme.SUN, 0.22)
	s.shadow_size = halo
	disc.add_theme_stylebox_override("panel", s)
	var c: CenterContainer = CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sun: HudIcon = HudIcon.new(&"sun", 76.0 * scale, UiTheme.INK)
	sun.stroke_width = 4.0 * scale
	# Sobre el disco amarillo va el trazo fino de la web: el ícono con volumen queda pesado.
	sun.use_art = false
	c.add_child(sun)
	disc.add_child(c)
	row.add_child(disc)

	var words: VBoxContainer = VBoxContainer.new()
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", int(-14 * scale))
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(_word("MISIÓN", int(60 * scale), UiTheme.FG))
	words.add_child(_word("ENERGÍA", int(72 * scale), UiTheme.SUN))
	row.add_child(words)
	return row


static func _word(text: String, font_size: int, color: Color) -> Label:
	var fv: FontVariation = FontVariation.new()
	fv.base_font = UiTheme.display(700)
	fv.spacing_glyph = int(font_size * 0.04)
	var l: Label = UiTheme.label(text, fv, font_size, color)
	return l
