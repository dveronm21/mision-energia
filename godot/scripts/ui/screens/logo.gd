class_name Logo
extends RefCounted
## Logotipo: sol + "MISIÓN ENERGÍA" (equivale a `logo.ts`).

static func build() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(HudIcon.new(&"sun", 44.0, VisualMaterials.C_SUN))
	var words: VBoxContainer = VBoxContainer.new()
	var a: Label = Label.new()
	a.text = "MISIÓN"
	a.add_theme_font_size_override("font_size", 22)
	words.add_child(a)
	var b: Label = Label.new()
	b.text = "ENERGÍA"
	b.add_theme_font_size_override("font_size", 28)
	b.add_theme_color_override("font_color", VisualMaterials.C_SUN)
	words.add_child(b)
	row.add_child(words)
	return row
