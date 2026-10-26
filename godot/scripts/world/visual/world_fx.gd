class_name WorldFx
extends RefCounted
## Efectos de partículas 3D de un solo disparo: chispas al conectar un cable, polvo al apoyar
## un equipo y destellos al activar la planta o completar el campo solar. `CPUParticles3D`
## (anda igual en GL Compatibility que en los renderers modernos) con puntitos redondos sin luz
## que miran a la cámara; cada ráfaga se borra sola al terminar.
##
##   WorldFx.sparks(world, terminal)      # en coordenadas locales de `world`

const SPARK_COLOR: Color = Color("#ffe066")
const SPARK_HOT: Color = Color("#fff8d6")
const DUST_COLOR: Color = Color("#c9a978")
const GLINT_COLOR: Color = Color("#ffb82e")

## Estrellita blanca de 4 puntas (Kenney, CC0) para los destellos de festejo.
const SPARKLE_TEX: String = "res://assets/textures/fx_sparkle.png"

static var _mat: StandardMaterial3D = null
static var _star_mat: StandardMaterial3D = null


static func _material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.vertex_color_use_as_albedo = true
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat.albedo_texture = _dot_texture()
	return _mat


## Punto redondo de borde suave (blanco; el color lo pone cada partícula).
static func _dot_texture() -> GradientTexture2D:
	var g: Gradient = Gradient.new()
	g.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	var t: GradientTexture2D = GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t


## Igual que `_material()` pero con la textura de estrellita (si no se encuentra, puntito).
static func _star_material() -> StandardMaterial3D:
	if _star_mat == null:
		_star_mat = _material().duplicate() as StandardMaterial3D
		var tex: Texture2D = load(SPARKLE_TEX) as Texture2D if ResourceLoader.exists(SPARKLE_TEX) else null
		if tex != null:
			_star_mat.albedo_texture = tex
	return _star_mat


static func _mesh(size: float, star: bool = false) -> QuadMesh:
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _star_material() if star else _material()
	return q


static func _ramp(a: Color, b: Color) -> Gradient:
	var g: Gradient = Gradient.new()
	g.colors = PackedColorArray([a, b, Color(b, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	return g


static func _burst(parent: Node3D, pos: Vector3, amount: int, life: float) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.name = "fx"
	p.position = pos
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.92
	p.local_coords = false
	p.emitting = false
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	return p


## Chispas eléctricas: salen en todas direcciones, caen y se apagan de blanco a amarillo.
static func sparks(parent: Node3D, pos: Vector3, count: int = 34) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p: CPUParticles3D = _burst(parent, pos, count, 0.55)
	p.mesh = _mesh(0.07)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.8
	p.initial_velocity_max = 4.2
	p.gravity = Vector3(0, -9.0, 0)
	p.damping_min = 1.0
	p.damping_max = 3.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.3
	p.color_ramp = _ramp(SPARK_HOT, SPARK_COLOR)
	p.emitting = true


## Nube de polvo al apoyar algo en el suelo: anillo bajo que se expande y se disuelve.
static func dust(parent: Node3D, pos: Vector3, count: int = 18) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p: CPUParticles3D = _burst(parent, Vector3(pos.x, maxf(pos.y, 0.05), pos.z), count, 0.8)
	p.mesh = _mesh(0.28)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.35
	p.emission_ring_inner_radius = 0.2
	p.emission_ring_height = 0.05
	p.direction = Vector3(0, 0.25, 0)
	p.spread = 70.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, 0.25, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(1.0, 1.6))
	p.scale_amount_curve = curve
	p.color_ramp = _ramp(Color(DUST_COLOR, 0.55), Color(DUST_COLOR, 0.3))
	p.emitting = true


## Destellos de festejo: chispitas doradas que suben girando (planta activa, campo completo).
static func glints(parent: Node3D, pos: Vector3, count: int = 46) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p: CPUParticles3D = _burst(parent, pos, count, 1.2)
	p.explosiveness = 0.7
	p.mesh = _mesh(0.22, true)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	p.direction = Vector3.UP
	p.spread = 35.0
	p.initial_velocity_min = 1.6
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0, -1.2, 0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	p.color_ramp = _ramp(Color.WHITE, GLINT_COLOR)
	p.emitting = true
