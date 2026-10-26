class_name CableGuideVisual
extends Node3D
## Camino punteado en el piso que muestra por dónde va un cable que todavía no está conectado.
## Los puntos (redondos, del color del cable) "avanzan" hacia el equipo de destino.
##
##   var guide := CableGuideVisual.new(route, CableNetwork.color_for(&"orange"))

const STEP: float = 0.34
const DOT_R: float = 0.085
const SPEED: float = 0.5

var _mm: MultiMeshInstance3D
var _path: PackedVector3Array = PackedVector3Array()
var _cum: PackedFloat32Array = PackedFloat32Array()
var _length: float = 0.0
var _offset: float = 0.0


## `route`: puntos del recorrido (los mismos que usa el cable); se apoyan todos en el piso.
func _init(route: PackedVector3Array, color: Color, floor_at: Callable) -> void:
	name = "cable_guide"
	for p: Vector3 in route:
		var q: Vector3 = Vector3(p.x, float(floor_at.call(p.x, p.z)) + 0.03, p.z)
		if _path.is_empty() or _path[_path.size() - 1].distance_to(q) > 0.01:
			_path.append(q)
	_cum.append(0.0)
	for i: int in range(1, _path.size()):
		_length += _path[i - 1].distance_to(_path[i])
		_cum.append(_length)

	var dot: CylinderMesh = CylinderMesh.new()
	dot.top_radius = DOT_R
	dot.bottom_radius = DOT_R
	dot.height = 0.02
	dot.radial_segments = 16
	dot.rings = 1
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color.lightened(0.15)
	dot.material = m

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = dot
	mm.instance_count = maxi(1, int(_length / STEP) + 1)
	_mm = MultiMeshInstance3D.new()
	_mm.multimesh = mm
	_mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mm)
	_place()


func _process(dt: float) -> void:
	if not visible or _length <= 0.0:
		return
	_offset = fmod(_offset + dt * SPEED, STEP)
	_place()


func _place() -> void:
	var mm: MultiMesh = _mm.multimesh
	for i: int in mm.instance_count:
		var d: float = i * STEP + _offset
		if d > _length:
			mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
			continue
		mm.set_instance_transform(i, Transform3D(Basis(), _at(d)))


func _at(d: float) -> Vector3:
	for i: int in range(1, _path.size()):
		if d <= _cum[i]:
			var seg: float = _cum[i] - _cum[i - 1]
			var t: float = 0.0 if seg <= 0.0 else (d - _cum[i - 1]) / seg
			return _path[i - 1].lerp(_path[i], t)
	return _path[_path.size() - 1]
