class_name EpseLogoVisual
extends Node3D
## Logo de EPSE en letras corpóreas, parado sobre el techo de la sala de equipos. Es el logo
## oficial sin redibujar: el frente es la imagen (`epse_logo.png`) y los cantos salen de su
## silueta exacta (`epse_logo_outline.json`), extruida `DEPTH` metros. Ambos se generan con
## `tools/epse_logo/build_logo.py` a partir del PNG de la empresa. Mira hacia +z (la cámara).
## El origen es el centro de la base; `height` es el alto del logo en metros.
##
##   var logo := EpseLogoVisual.new(1.6)

const TEXTURE: String = "res://assets/textures/epse_logo.png"
const OUTLINE: String = "res://assets/models/epse_logo_outline.json"
const DEPTH: float = 0.16
const LIFT: float = 0.12


func _init(height: float = 1.6) -> void:
	name = "epse_logo"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTLINE))
	var aspect: float = float(data.get("aspect", 3.0))
	var orange: Color = Color.from_string(String(data.get("color", "#f37435")), Color("#f37435"))
	var width: float = height * aspect
	var board: Node3D = Node3D.new()
	board.position = Vector3(-width / 2.0, LIFT, 0.0)
	add_child(board)

	# Frente y dorso: la imagen del logo, recortada por su transparencia.
	var face_mat: StandardMaterial3D = StandardMaterial3D.new()
	face_mat.albedo_texture = load(TEXTURE) as Texture2D
	face_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	face_mat.alpha_scissor_threshold = 0.5
	face_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	face_mat.roughness = 0.5
	# Un poco de brillo propio: el cartel se lee aunque el techo quede a la sombra.
	face_mat.emission_enabled = true
	face_mat.emission_texture = face_mat.albedo_texture
	face_mat.emission_energy_multiplier = 0.15
	for front: bool in [true, false]:
		var face: MeshInstance3D = MeshInstance3D.new()
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(width, height)
		face.mesh = q
		face.material_override = face_mat
		face.position = Vector3(width / 2.0, height / 2.0, DEPTH / 2.0 if front else -DEPTH / 2.0)
		if not front:
			face.rotation.y = PI
		board.add_child(face)

	# Cantos: la silueta extruida, del mismo naranja.
	var edge_mat: StandardMaterial3D = StandardMaterial3D.new()
	edge_mat.albedo_color = orange.darkened(0.12)
	edge_mat.roughness = 0.6
	edge_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var edges: MeshInstance3D = MeshInstance3D.new()
	edges.mesh = _edges_mesh(data.get("loops", []) as Array, height)
	edges.material_override = edge_mat
	board.add_child(edges)

	# Riel y dos patas (el cartel va atornillado sobre el techo).
	var steel: StandardMaterial3D = StandardMaterial3D.new()
	steel.albedo_color = Color("#2b3532")
	steel.roughness = 0.7
	var rail: MeshInstance3D = MeshInstance3D.new()
	var rail_mesh: BoxMesh = BoxMesh.new()
	rail_mesh.size = Vector3(width * 0.9, 0.07, 0.07)
	rail.mesh = rail_mesh
	rail.material_override = steel
	rail.position = Vector3(0.0, LIFT - 0.035, -DEPTH / 2.0 - 0.04)
	add_child(rail)
	for x: float in [-width * 0.33, width * 0.33]:
		var leg: MeshInstance3D = MeshInstance3D.new()
		var leg_mesh: BoxMesh = BoxMesh.new()
		leg_mesh.size = Vector3(0.06, LIFT + height * 0.5, 0.06)
		leg.mesh = leg_mesh
		leg.material_override = steel
		leg.position = Vector3(x, (LIFT + height * 0.5) / 2.0 - 0.07, -DEPTH / 2.0 - 0.04)
		add_child(leg)


## Paredes de la extrusión: cada contorno (x, y en unidades de alto) se levanta entre el dorso y
## el frente. Los contornos vienen orientados para que la normal sea (dy, -dx).
static func _edges_mesh(loops: Array, height: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var zf: float = DEPTH / 2.0
	for loop: Variant in loops:
		var flat: Array = (loop as Dictionary).get("points", [])
		var n: int = flat.size() / 2
		for i: int in n:
			var j: int = (i + 1) % n
			var a: Vector2 = Vector2(float(flat[2 * i]), float(flat[2 * i + 1])) * height
			var b: Vector2 = Vector2(float(flat[2 * j]), float(flat[2 * j + 1])) * height
			var d: Vector2 = b - a
			if d.length_squared() < 1e-10:
				continue
			st.set_normal(Vector3(d.y, -d.x, 0.0).normalized())
			var af: Vector3 = Vector3(a.x, a.y, zf)
			var ab: Vector3 = Vector3(a.x, a.y, -zf)
			var bf: Vector3 = Vector3(b.x, b.y, zf)
			var bb: Vector3 = Vector3(b.x, b.y, -zf)
			for v: Vector3 in [af, bf, ab, ab, bf, bb]:
				st.add_vertex(v)
	return st.commit()
