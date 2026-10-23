class_name DroneVisual
extends Node3D
## Dron limpiador: modelo procedural simple (equivale al armado de malla de `Drone.ts`).
## Solo apariencia; el vuelo y la lógica de "qué fila limpiar" viven en `Drone` (entities/).

var _rotors: Array[MeshInstance3D] = []
var _spray: MeshInstance3D
var _time: float = 0.0


func _init() -> void:
	name = "drone"
	var body_mat: StandardMaterial3D = VisualMaterials.surface(Color("#f1f4f2"), 0.4)
	var dark_mat: StandardMaterial3D = VisualMaterials.surface(Color("#24423c"), 0.5)

	var core: MeshInstance3D = MeshInstance3D.new()
	var core_mesh: BoxMesh = BoxMesh.new()
	core_mesh.size = Vector3(0.5, 0.18, 0.5)
	core.mesh = core_mesh
	core.material_override = body_mat
	add_child(core)

	var stripe: MeshInstance3D = MeshInstance3D.new()
	var stripe_mesh: BoxMesh = BoxMesh.new()
	stripe_mesh.size = Vector3(0.52, 0.05, 0.52)
	stripe.mesh = stripe_mesh
	stripe.material_override = VisualMaterials.surface(VisualMaterials.C_SUN, 0.6, 0.4)
	stripe.position.y = 0.03
	add_child(stripe)

	var arm_spots: Array[Vector2] = [Vector2(0.42, 0.42), Vector2(-0.42, 0.42), Vector2(0.42, -0.42), Vector2(-0.42, -0.42)]
	for spot: Vector2 in arm_spots:
		var x: float = spot.x
		var z: float = spot.y
		var arm: MeshInstance3D = MeshInstance3D.new()
		var arm_mesh: BoxMesh = BoxMesh.new()
		arm_mesh.size = Vector3(0.06, 0.05, 0.62)
		arm.mesh = arm_mesh
		arm.material_override = dark_mat
		arm.position = Vector3(x / 2.0, 0.0, z / 2.0)
		arm.rotation.y = atan2(x, z)
		add_child(arm)
		var rotor: MeshInstance3D = MeshInstance3D.new()
		var rotor_mesh: BoxMesh = BoxMesh.new()
		rotor_mesh.size = Vector3(0.46, 0.015, 0.06)
		rotor.mesh = rotor_mesh
		rotor.material_override = dark_mat
		rotor.position = Vector3(x, 0.1, z)
		add_child(rotor)
		_rotors.append(rotor)

	_spray = MeshInstance3D.new()
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.9
	cone.height = 1.6
	cone.radial_segments = 12
	var spray_mat: StandardMaterial3D = StandardMaterial3D.new()
	spray_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spray_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spray_mat.albedo_color = Color(0.75, 0.92, 1.0, 0.28)
	spray_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	spray_mat.no_depth_test = false
	_spray.mesh = cone
	_spray.material_override = spray_mat
	_spray.position.y = -0.85
	_spray.visible = false
	add_child(_spray)

	visible = false


func set_spraying(on: bool) -> void:
	_spray.visible = on


## Giro de las hélices + leve balanceo del cuerpo (llamalo todos los cuadros mientras `visible`).
func animate(dt: float) -> void:
	_time += dt
	for r: MeshInstance3D in _rotors:
		r.rotation.y += dt * 40.0
	rotation.z = sin(_time * 3.0) * 0.05
