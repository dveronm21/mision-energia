extends SceneTree
func _quad(x: float, mat: Material, col: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(-0.4,-0.4,0), Vector3(0.4,-0.4,0), Vector3(0.4,0.4,0), Vector3(-0.4,-0.4,0), Vector3(0.4,0.4,0), Vector3(-0.4,0.4,0)]:
		st.set_color(col)
		st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position = Vector3(x, 0, 0)
	return mi
func _init() -> void:
	var root := Node3D.new()
	var cam := Camera3D.new(); cam.projection = Camera3D.PROJECTION_ORTHOGONAL; cam.size = 2.0; cam.position = Vector3(0,0,2)
	root.add_child(cam)
	var a := StandardMaterial3D.new(); a.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; a.albedo_color = Color(0.5,0.5,0.5); a.cull_mode = BaseMaterial3D.CULL_DISABLED
	var b := StandardMaterial3D.new(); b.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; b.vertex_color_use_as_albedo = true; b.vertex_color_is_srgb = true; b.cull_mode = BaseMaterial3D.CULL_DISABLED
	var c := StandardMaterial3D.new(); c.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; c.vertex_color_use_as_albedo = true; c.cull_mode = BaseMaterial3D.CULL_DISABLED
	root.add_child(_quad(-1.2, a, Color.WHITE))
	root.add_child(_quad(0.0, b, Color(0.5,0.5,0.5)))
	root.add_child(_quad(1.2, c, Color(0.5,0.5,0.5)))
	get_root().add_child(root)
	await process_frame
	await process_frame
	await process_frame
	var img := get_root().get_texture().get_image()
	var w := img.get_width(); var h := img.get_height()
	print("size ", w, "x", h)
	for x in [-1.2, 0.0, 1.2]:
		var px := int((x / (2.0 * w / h) + 0.5) * w)
		print(x, " -> ", img.get_pixel(px, h / 2))
	quit()
