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
## Gesto en curso (&"" = ninguno), su tiempo transcurrido, duración y si se repite.
var _gesture: StringName = &""
var _g_time := 0.0
var _g_len := 0.0
var _g_loop := false

## Gestos: festejo (brazos arriba con saltito), "uy" (mano a la cabeza y sacudida de cabeza),
## "dale" (pulgar arriba con el brazo derecho) y baile de victoria (en bucle).
const GESTURE_LEN: Dictionary[StringName, float] = {
	&"cheer": 1.3, &"oops": 1.1, &"thumbs": 0.9, &"victory": 1.6,
}


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


## Dispara un gesto (ver `GESTURE_LEN`). `loop` lo repite hasta `stop_gesture()`. Un gesto nuevo
## reemplaza al anterior; mientras carga algo, solo se mueve la cabeza (no suelta el cajón).
func play_gesture(gesture: StringName, loop: bool = false) -> void:
	if not GESTURE_LEN.has(gesture):
		return
	_gesture = gesture
	_g_time = 0.0
	_g_len = GESTURE_LEN[gesture]
	_g_loop = loop


func stop_gesture() -> void:
	_gesture = &""


func gesture() -> StringName:
	return _gesture


## Peso de mezcla del gesto: entra en 0,15 s y sale en los últimos 0,25 s.
func _gesture_weight() -> float:
	if _g_loop:
		return clampf(_g_time / 0.15, 0.0, 1.0)
	return clampf(_g_time / 0.15, 0.0, 1.0) * clampf((_g_len - _g_time) / 0.25, 0.0, 1.0)


## Ángulos del gesto en curso (solo los huesos que mueve) y alto extra de cadera.
func _gesture_pose(carrying: bool) -> Dictionary:
	var t := _g_time
	var out: Dictionary = {}
	match _gesture:
		&"cheer":
			var wave := sin(t * 14.0) * 0.18
			if not carrying:
				out[&"arm_l"] = Vector3(-2.75 + wave, 0, 0.35)
				out[&"arm_r"] = Vector3(-2.75 - wave, 0, -0.35)
				out[&"forearm_l"] = Vector3(-0.25, 0, 0)
				out[&"forearm_r"] = Vector3(-0.25, 0, 0)
			out[&"head"] = Vector3(-0.25, 0, 0)
			out[&"torso"] = Vector3(-0.12, 0, 0)
			# Saltito: dos rebotes rápidos.
			out[&"hop"] = maxf(0.0, sin(t * TAU * 1.6)) * 0.16
		&"oops":
			if not carrying:
				out[&"arm_r"] = Vector3(-2.4, 0, -0.5)
				out[&"forearm_r"] = Vector3(-1.9, 0, 0)
				out[&"arm_l"] = Vector3(0.1, 0, 0.42)
			out[&"head"] = Vector3(0.18, sin(t * 16.0) * 0.38, sin(t * 8.0) * 0.12)
			out[&"torso"] = Vector3(0.14, 0, 0)
		&"thumbs":
			if not carrying:
				out[&"arm_r"] = Vector3(-1.45, 0, -0.35)
				out[&"forearm_r"] = Vector3(-1.2, 0.4, 0)
			out[&"head"] = Vector3(-0.1, -0.2, 0.12)
		&"victory":
			var beat := sin(t * TAU / 0.8)
			if not carrying:
				out[&"arm_l"] = Vector3(-2.9, 0, 0.5 + beat * 0.25)
				out[&"arm_r"] = Vector3(-2.9, 0, -0.5 + beat * 0.25)
				out[&"forearm_l"] = Vector3(-0.4, 0, 0)
				out[&"forearm_r"] = Vector3(-0.4, 0, 0)
			out[&"hips"] = Vector3(0, beat * 0.35, 0)
			out[&"torso"] = Vector3(-0.1, -beat * 0.2, beat * 0.08)
			out[&"head"] = Vector3(-0.2, beat * 0.25, 0)
			out[&"hop"] = absf(sin(t * TAU / 0.8)) * 0.12
	return out


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
	# Gesto encima de la marcha: se mezcla por hueso con su peso (entrada y salida suaves).
	var hop := 0.0
	if _gesture != &"":
		_g_time += dt
		if _g_time >= _g_len:
			if _g_loop:
				_g_time = fmod(_g_time, _g_len)
			else:
				_gesture = &""
		if _gesture != &"":
			var w := _gesture_weight()
			var g := _gesture_pose(p == Pose.CARRY)
			for b: StringName in g.keys():
				if b == &"hop":
					hop = float(g[b]) * w
				elif t.has(b):
					t[b] = t[b].lerp(g[b], w)
	var k := 1.0 - exp(-(18.0 if _gesture != &"" else 12.0) * dt)
	for b: StringName in BONES:
		var cur: Vector3 = _cur[b].lerp(t[b], k)
		_cur[b] = cur
		var n: Node3D = _bones.get(b)
		if n != null:
			n.rotation = cur
	var hips_node: Node3D = _bones.get(&"hips")
	if hips_node != null:
		hips_node.position.y = HIP_Y + (absf(c) * 0.045 - 0.03) * amp + breath * 0.003 * still + hop
	# La sombra de contacto se achica cuando salta (se siente el despegue).
	_shadow.scale = Vector3.ONE * (1.0 - 0.08 * amp * absf(c)) * (1.0 - hop * 1.8)
