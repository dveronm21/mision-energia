class_name WorkerVisual
extends Node3D
## Técnico con casco y chaleco: jerarquía rígida (hips, torso, head, arm_l/forearm_l, arm_r/forearm_r,
## leg_l/shin_l, leg_r/shin_r) con animación procedural de caminar, respirar y poses de brazos.
## Port directo de ModelFactory.createWorker().animate() de la versión web (mismos ángulos y tiempos).
##
##   var w := WorkerVisual.new()
##   w.speed = 0.6; w.pose = WorkerVisual.Pose.CARRY      # se anima solo en _process
##   w.carry_anchor.add_child(CrateVisual.new(&"battery"))

enum Pose { IDLE, CARRY, CABLE, TOOL }

const BONES: Array[StringName] = [
	&"hips", &"torso", &"head", &"arm_l", &"forearm_l", &"arm_r", &"forearm_r",
	&"leg_l", &"shin_l", &"leg_r", &"shin_r",
]
const HIP_Y := 0.88

## Velocidad de marcha 0..1 (0 = quieto) y pose de brazos; los usa _process si `auto_animate`.
var speed := 0.0
var pose: Pose = Pose.IDLE
var auto_animate := true

var model: Node3D
## Anclaje sobre la cabeza para objetos cargados (cajones).
var carry_anchor: Node3D
## Anclaje en la mano derecha (multímetro, punta de cable).
var hand_anchor: Node3D

var _bones: Dictionary[StringName, Node3D] = {}
var _cur: Dictionary[StringName, Vector3] = {}
var _helmet_mat: StandardMaterial3D
var _vest_mat: StandardMaterial3D
var _shadow: MeshInstance3D
var _phase := 0.0
var _time := 0.0
var _walk := 0.0


func _init(helmet: Color = VisualMaterials.C_SUN, vest: Color = VisualMaterials.C_ORANGE) -> void:
	name = "worker"
	model = ModelLibrary.instantiate(&"worker")
	add_child(model)
	for b: StringName in BONES:
		var n := model.find_child(String(b), true, false) as Node3D
		if n == null:
			push_error("WorkerVisual: falta el nodo %s en worker.glb" % b)
			continue
		n.rotation_order = EULER_ORDER_XYZ # mismo orden que three.js
		_bones[b] = n
		_cur[b] = Vector3.ZERO
	# Sombras: sólo cuerpo, cabeza, casco y piernas (los brazos y el chaleco casi no se notan y suman draw calls)
	for part_name: String in ["arm_l_mesh", "arm_r_mesh", "forearm_l_mesh", "forearm_r_mesh", "vest"]:
		var gi := model.find_child(part_name, true, false) as GeometryInstance3D
		if gi != null:
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	carry_anchor = model.find_child("carry_anchor", true, false) as Node3D
	hand_anchor = model.find_child("hand_r", true, false) as Node3D
	_helmet_mat = ModelLibrary.own_material(model.find_child("helmet", true, false) as MeshInstance3D) as StandardMaterial3D
	_vest_mat = ModelLibrary.own_material(model.find_child("vest", true, false) as MeshInstance3D) as StandardMaterial3D
	# sombra de contacto (mancha suave): asienta al personaje aun sin sombras dinámicas
	_shadow = MeshInstance3D.new()
	_shadow.name = "contact_shadow"
	var q := QuadMesh.new()
	q.size = Vector2(0.95, 0.95)
	q.orientation = PlaneMesh.FACE_Y
	_shadow.mesh = q
	_shadow.material_override = VisualMaterials.blob_shadow()
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.position.y = 0.012
	add_child(_shadow)
	set_cosmetics(helmet, vest)
	animate(0.016, 0.0, Pose.IDLE)


## Colores de casco y chaleco (materiales propios de esta instancia).
func set_cosmetics(helmet: Color, vest: Color) -> void:
	if _helmet_mat != null:
		_helmet_mat.albedo_color = helmet
	if _vest_mat != null:
		_vest_mat.albedo_color = vest


func bone(bone_name: StringName) -> Node3D:
	return _bones.get(bone_name) as Node3D


func _process(dt: float) -> void:
	if auto_animate:
		animate(dt, speed, pose)


## Avanza la animación procedural: `spd` 0..1 de marcha y pose de brazos.
func animate(dt: float, spd: float, p: Pose) -> void:
	dt = minf(dt, 0.1)
	_time += dt
	spd = clampf(spd, 0.0, 1.0)
	_walk = EquipmentVisual.damp(_walk, 1.0 if spd > 0.03 else 0.0, 8.0, dt)
	var amp := _walk * (0.45 + 0.55 * spd)
	_phase += dt * (5.0 + 6.0 * spd) * (1.0 if spd > 0.03 else _walk)
	var s := sin(_phase)
	var c := cos(_phase)
	var breath := sin(_time * 1.9)
	var still := 1.0 - _walk
	# Ángulos objetivo por hueso (Euler XYZ, igual que la versión web)
	var leg_l := Vector3(-s * 0.62 * amp, 0, 0)
	var leg_r := Vector3(s * 0.62 * amp, 0, 0)
	var shin_l := Vector3(amp * (0.12 + 0.95 * maxf(0.0, c)), 0, 0)
	var shin_r := Vector3(amp * (0.12 + 0.95 * maxf(0.0, -c)), 0, 0)
	# Torso y cabeza (respiración y mirada en reposo)
	var torso := Vector3(0.07 * amp + breath * 0.018 * still, s * 0.13 * amp, 0)
	var hips := Vector3(0, -s * 0.07 * amp, 0)
	var head := Vector3(-0.04 * amp + still * sin(_time * 0.31) * 0.05, -s * 0.08 * amp + still * sin(_time * 0.45) * 0.28, 0)
	# Brazos: balanceo
	var arm_l := Vector3(s * 0.55 * amp, 0, 0.06 + breath * 0.015 * still)
	var arm_r := Vector3(-s * 0.55 * amp, 0, -0.06 - breath * 0.015 * still)
	var forearm_l := Vector3(-0.18 - 0.35 * amp * (0.5 + 0.5 * s), 0, 0)
	var forearm_r := Vector3(-0.18 - 0.35 * amp * (0.5 - 0.5 * s), 0, 0)

	match p:
		Pose.CARRY:
			var lift := -2.72 + sin(_phase * 2.0) * 0.03 * amp
			arm_l = Vector3(lift, 0, 0.32)
			arm_r = Vector3(lift, 0, -0.32)
			forearm_l = Vector3(-0.35, 0, -0.55)
			forearm_r = Vector3(-0.35, 0, 0.55)
			torso = Vector3(0.02, torso.y * 0.4, 0)
			head = Vector3(-0.05, head.y * 0.3, 0)
		Pose.CABLE:
			arm_r = Vector3(-0.85 + s * 0.06 * amp, 0, 0.12)
			forearm_r = Vector3(-0.55, 0, 0)
		Pose.TOOL:
			arm_r = Vector3(-0.95, 0, 0.32)
			forearm_r = Vector3(-1.25, 0.2, 0)
			arm_l = Vector3(-0.75, 0, -0.25)
			forearm_l = Vector3(-1.05, 0, 0)
			head = Vector3(0.32, 0.12 * still, 0)
			torso = Vector3(0.06, torso.y, 0)

	var t: Dictionary[StringName, Vector3] = {
		&"hips": hips, &"torso": torso, &"head": head, &"arm_l": arm_l, &"forearm_l": forearm_l,
		&"arm_r": arm_r, &"forearm_r": forearm_r, &"leg_l": leg_l, &"shin_l": shin_l, &"leg_r": leg_r, &"shin_r": shin_r,
	}
	var k := 1.0 - exp(-12.0 * dt)
	for b: StringName in BONES:
		var cur: Vector3 = _cur[b].lerp(t[b], k)
		_cur[b] = cur
		var n: Node3D = _bones.get(b)
		if n != null:
			n.rotation = cur
	var hips_node: Node3D = _bones.get(&"hips")
	if hips_node != null:
		hips_node.position.y = HIP_Y + (absf(c) * 0.045 - 0.03) * amp + breath * 0.003 * still
	_shadow.scale = Vector3.ONE * (1.0 - 0.08 * amp * absf(c))
