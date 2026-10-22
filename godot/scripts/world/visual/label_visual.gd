class_name LabelVisual
extends Node3D
## Etiqueta flotante legible: Label3D en Fredoka con contorno, sobre una "píldora" redondeada, siempre de
## frente a la cámara (billboard) y visible a través de los objetos. El ancla es el borde inferior: ubicala
## justo arriba del objeto. `height` = alto de la píldora en metros (0,6 por defecto, como la versión web).
##
##   var lb := LabelVisual.new("SALA DE EQUIPOS", 0.7)
##   lb.position = Vector3(7, 3.75, -6.4)

const FONT_PATH := "res://assets/fonts/fredoka-latin-700-normal.woff2"
const BG_DEFAULT := Color(0.055, 0.141, 0.125, 0.9)
const BG_ACCENT := Color(0.725, 0.47, 0.102, 0.94)
const FONT_SIZE := 64
const PILL_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 bg : source_color = vec4(0.055, 0.141, 0.125, 0.9);
uniform vec2 size = vec2(3.0, 1.0);
uniform float border = 0.035;
void vertex() {
	// billboard que conserva la escala del nodo
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 p = (UV - 0.5) * size;
	float r = size.y * 0.5;
	vec2 q = abs(p) - (size * 0.5 - vec2(r));
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
	float aa = fwidth(d) * 1.2;
	float inside = 1.0 - smoothstep(-aa, aa, d);
	float rim = smoothstep(-border - aa, -border, d) * inside;
	vec3 col = mix(bg.rgb, vec3(1.0), rim * 0.35);
	ALBEDO = col;
	ALPHA = inside * bg.a;
}
"""

static var _shader: Shader
static var _font: Font

var text := ""
var height := 0.6
var bg_color := BG_DEFAULT
var label: Label3D
var pill: MeshInstance3D
var _pill_mat: ShaderMaterial


func _init(label_text: String = "", label_height: float = 0.6, bg: Color = BG_DEFAULT) -> void:
	name = "label"
	if _shader == null:
		_shader = Shader.new()
		_shader.code = PILL_SHADER
	if _font == null:
		_font = load(FONT_PATH) as Font
	pill = MeshInstance3D.new()
	pill.name = "pill"
	pill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pill.mesh = QuadMesh.new()
	_pill_mat = ShaderMaterial.new()
	_pill_mat.shader = _shader
	_pill_mat.render_priority = 10
	pill.material_override = _pill_mat
	add_child(pill)
	label = Label3D.new()
	label.name = "text"
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.font = _font
	label.font_size = FONT_SIZE
	label.outline_size = 14
	label.outline_modulate = Color(0.03, 0.08, 0.07, 0.85)
	label.modulate = Color.WHITE
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.shaded = false
	label.fixed_size = false
	label.render_priority = 12
	label.outline_render_priority = 11
	label.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(label)
	setup(label_text, label_height, bg)


## Cambia texto, alto (m) y color de fondo.
func setup(label_text: String, label_height: float = 0.6, bg: Color = BG_DEFAULT) -> void:
	text = label_text
	height = maxf(0.05, label_height)
	bg_color = bg
	label.text = text
	# El texto ocupa ~52 % del alto de la píldora (igual que la textura de la versión web).
	var text_h := height * 0.5
	label.pixel_size = text_h / float(FONT_SIZE)
	var w_px := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var w := w_px * label.pixel_size + height * 0.75
	(pill.mesh as QuadMesh).size = Vector2(w, height * 0.8)
	pill.position = Vector3(0, height * 0.4, 0)
	label.position = Vector3(0, height * 0.42, 0)
	_pill_mat.set_shader_parameter("bg", bg)
	_pill_mat.set_shader_parameter("size", Vector2(w, height * 0.8))


func set_text(label_text: String) -> void:
	setup(label_text, height, bg_color)
