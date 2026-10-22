class_name EnergyFlowVisual
extends MultiMeshInstance3D
## Partículas de energía que recorren una curva (MultiMesh: 1 llamada de dibujo por flujo).
## `direction` = 1 recorre la curva del inicio al final; -1 al revés.
##
##   var flow := EnergyFlowVisual.new()
##   cable.add_child(flow)          # comparte el espacio local del cable
##   flow.setup(cable.curve, Color("#ffd166"))
##   flow.set_on(true)

var curve: Curve3D
var direction := 1
## Metros por segundo.
var speed := 2.2
## Separación entre partículas en metros.
var spacing := 0.45
var _on := false
var _offset := 0.0
var _fade := 0.0
var _count := 0
var _mat: StandardMaterial3D


func _init() -> void:
	name = "energy_flow"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var s := SphereMesh.new()
	s.radius = 0.055
	s.height = 0.11
	s.radial_segments = 8
	s.rings = 4
	multimesh.mesh = s
	visible = false


func setup(path_curve: Curve3D, flow_color: Color = Color("#ffd166"), bead_spacing: float = 0.45) -> void:
	curve = path_curve
	spacing = maxf(0.1, bead_spacing)
	_mat = VisualMaterials.additive(flow_color, 2.2)
	material_override = _mat
	var len := curve.get_baked_length() if curve != null else 0.0
	_count = clampi(int(len / spacing), 1, 200)
	multimesh.instance_count = _count
	_update(0.0)


func set_on(on: bool) -> void:
	_on = on
	if on:
		visible = true


func set_direction(dir: int) -> void:
	direction = 1 if dir >= 0 else -1


func is_on() -> bool:
	return _on


func _process(dt: float) -> void:
	_fade = EquipmentVisual.damp(_fade, 1.0 if _on else 0.0, 6.0, dt)
	if _fade < 0.01 and not _on:
		visible = false
		return
	_offset += dt * speed * float(direction)
	_update(dt)


func _update(_dt: float) -> void:
	if curve == null or _count == 0:
		return
	var len := curve.get_baked_length()
	if len <= 0.0:
		return
	var scale_k := 0.35 + 0.65 * _fade
	for i: int in _count:
		var d := fposmod(_offset + float(i) * spacing, len)
		var p := curve.sample_baked(d, true)
		# las partículas nacen y mueren chiquitas en los extremos
		var edge := clampf(minf(d, len - d) / 0.4, 0.0, 1.0)
		var sc := scale_k * (0.4 + 0.6 * edge)
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * sc), p))
