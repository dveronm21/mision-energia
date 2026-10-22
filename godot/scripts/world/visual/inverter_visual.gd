class_name InverterVisual
extends EquipmentVisual
## Inversor híbrido de pared con pantalla LCD (texto con color) y 3 LEDs (RED / BAT / FALLA).
## La pantalla es un Label3D sobre el frente; los LEDs una malla de brillo con colores por vértice.

const FONT_PATH := "res://assets/fonts/fredoka-latin-700-normal.woff2"
## Centro del LCD y de los LEDs en coordenadas del modelo (derivados del atlas del frente, 256 × 320 px
## sobre una placa de 0,84 × 1,05 m centrada en (0, 1,58, 0,311)).
const LCD_POS := Vector3(0, 1.81, 0.316)
const LED_Y := 1.4816
const LED_X: Array[float] = [-0.1903, 0.0, 0.1903]
const LED_ON: Array[Color] = [Color("#46e06a"), Color("#ffb82e"), Color("#ff4d4d")]
const LED_OFF := Color("#2a302f")

var _screen: Label3D
var _leds: MeshInstance3D
var _text := ""
var _color := Color("#8fa7a1")


func _init() -> void:
	super(&"inverter")
	name = "inverter"
	_screen = Label3D.new()
	_screen.name = "screen"
	_screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_screen.font = load(FONT_PATH) as Font
	_screen.font_size = 96
	_screen.pixel_size = 0.0011
	_screen.outline_size = 0
	_screen.shaded = false
	_screen.double_sided = false
	_screen.position = LCD_POS
	_screen.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_screen.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_screen)
	var face := part("face") as GeometryInstance3D
	if face != null:
		face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_leds = MeshInstance3D.new()
	_leds.name = "leds"
	_leds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_leds.material_override = VisualMaterials.glow()
	add_child(_leds)
	set_screen("STANDBY", Color("#8fa7a1"))


## Texto y color de la pantalla. Los LEDs se deducen del color (igual que la versión web):
## rojo → FALLA, ámbar → BAT, cualquier otro (salvo STANDBY) → RED.
func set_screen(text: String, color: Color = Color("#5fe3f5")) -> void:
	_text = text
	_color = color
	_screen.text = text
	_screen.font_size = 70 if text.length() > 9 else 96
	# HDR leve para que el texto "brille" con el glow sin quemarse
	_screen.modulate = Color(color.r * 1.25, color.g * 1.25, color.b * 1.25, 1.0)
	var red := color.r > 0.75 and color.g < 0.45
	var amber := color.r > 0.75 and color.g >= 0.45 and color.g < 0.85 and color.b < 0.45
	var on: Array[bool] = [not red and text != "STANDBY", amber, red]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in 3:
		MeshKit.disc(st, Vector3(LED_X[i], LED_Y, 0.3125), 0.026, LED_ON[i] if on[i] else LED_OFF, 12)
	_leds.mesh = st.commit()


func screen_text() -> String:
	return _text
