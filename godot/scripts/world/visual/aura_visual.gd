class_name AuraVisual
extends Node3D
## Aura de color que marca, para los más chicos, qué cajón llevar y dónde va: un círculo de luz
## en el piso y una columna translúcida que se desvanece hacia arriba, las dos latiendo suave.
## El origen es el piso; `radius` es el radio del círculo en metros.
##
##   var aura := AuraVisual.new(AuraVisual.COLOR_PROTECTION)

const COLOR_PROTECTION: Color = Color("#ff7a00")
const COLOR_BATTERY: Color = Color("#1f6fff")
const COLOR_KIT: Color = Color("#ffd23a")

var _disc: MeshInstance3D
var _column: MeshInstance3D
var _time: float = 0.0


func _init(color: Color, radius: float = 0.85, column_h: float = 2.2) -> void:
	name = "aura"
	_disc = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(radius * 2.0, radius * 2.0)
	q.orientation = PlaneMesh.FACE_Y
	_disc.mesh = q
	_disc.material_override = _glow(color, _disc_texture())
	_disc.position.y = 0.035
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_disc)

	_column = MeshInstance3D.new()
	var c: CylinderMesh = CylinderMesh.new()
	c.top_radius = radius * 0.8
	c.bottom_radius = radius * 0.8
	c.height = column_h
	c.radial_segments = 32
	c.cap_top = false
	c.cap_bottom = false
	_column.mesh = c
	_column.material_override = _glow(color, _column_texture())
	_column.position.y = column_h / 2.0
	_column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_column)
	_time = randf() * TAU


func _process(dt: float) -> void:
	if not visible:
		return
	_time += dt
	var k: float = 0.5 + 0.5 * sin(_time * 3.0)
	_disc.scale = Vector3.ONE * (0.92 + 0.12 * k)
	_column.transparency = 0.15 + 0.35 * (1.0 - k)


static func _glow(color: Color, tex: Texture2D) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = color
	m.albedo_texture = tex
	return m


## Círculo con borde marcado y centro suave.
static func _disc_texture() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.62, 0.8, 0.9, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.35), Color(1, 1, 1, 0.5), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)])
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


## Columna: fuerte abajo y transparente arriba (v = 0 es la parte de arriba del cilindro).
static func _column_texture() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.55)])
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0.0, 0.0)
	t.fill_to = Vector2(0.0, 1.0)
	t.width = 4
	t.height = 64
	return t
