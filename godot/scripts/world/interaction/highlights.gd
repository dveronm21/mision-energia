class_name Highlights
extends Node3D
## Marcadores en el mundo: anillo amarillo bajo la acción más cercana y, con el booster
## "Pista", anillo celeste + flecha flotante sobre el próximo paso de la obra. Equivale a
## `Highlights.ts`.

var _ring: MeshInstance3D
var _hint_ring: MeshInstance3D
var _arrow: MeshInstance3D
var _time: float = 0.0
var _hint_y: float = 3.0


func _init() -> void:
	name = "highlights"
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.62
	ring_mesh.outer_radius = 0.82
	ring_mesh.rings = 4
	ring_mesh.ring_segments = 40

	_ring = MeshInstance3D.new()
	_ring.mesh = ring_mesh
	_ring.material_override = _unshaded(Color("#ffb82e"), 0.95)
	_ring.visible = false
	add_child(_ring)

	_hint_ring = MeshInstance3D.new()
	_hint_ring.mesh = ring_mesh
	_hint_ring.material_override = _unshaded(Color("#5fe3f5"), 0.85)
	_hint_ring.visible = false
	add_child(_hint_ring)

	var arrow_mesh: CylinderMesh = CylinderMesh.new()
	arrow_mesh.top_radius = 0.0
	arrow_mesh.bottom_radius = 0.32
	arrow_mesh.height = 0.7
	arrow_mesh.radial_segments = 4
	_arrow = MeshInstance3D.new()
	_arrow.mesh = arrow_mesh
	_arrow.rotation.x = PI
	var arrow_mat: StandardMaterial3D = StandardMaterial3D.new()
	arrow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arrow_mat.albedo_color = Color("#5fe3f5")
	_arrow.material_override = arrow_mat
	_arrow.visible = false
	add_child(_arrow)


static func _unshaded(color: Color, alpha: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Anillo de la acción actual (null = ocultar). `y` = altura del piso.
func set_action(pos: Variant, y: float = 0.0) -> void:
	_ring.visible = pos != null
	if pos != null:
		var p: Vector3 = pos
		_ring.position = Vector3(p.x, y + 0.04, p.z)


## Pista: anillo celeste + flecha sobre `pos` (null = ocultar).
func set_hint(pos: Variant, y: float = 0.0) -> void:
	var on: bool = pos != null
	_hint_ring.visible = on
	_arrow.visible = on
	if not on:
		return
	var p: Vector3 = pos
	_hint_ring.position = Vector3(p.x, y + 0.03, p.z)
	_hint_y = y + 3.0
	_arrow.position = Vector3(p.x, _hint_y, p.z)


func update(dt: float) -> void:
	_time += dt
	var s: float = 1.0 + sin(_time * 5.5) * 0.08
	_ring.scale = Vector3(s, 1.0, s)
	var h: float = 1.0 + sin(_time * 3.2 + 1.0) * 0.12
	_hint_ring.scale = Vector3(h, 1.0, h)
	_arrow.position.y = _hint_y + sin(_time * 3.2) * 0.25
	_arrow.rotation.y += dt * 2.0
