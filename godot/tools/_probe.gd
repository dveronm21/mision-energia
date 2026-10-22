extends SceneTree
func _dump(n: Node, d: int) -> void:
	var s := "  ".repeat(d) + n.name + " (" + n.get_class() + ")"
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m is BaseMaterial3D:
				var bm := m as BaseMaterial3D
				s += " [mat %s vc=%s srgb=%s alb=%s rough=%.2f metal=%.2f unshaded=%s tr=%d]" % [bm.resource_name, bm.vertex_color_use_as_albedo, bm.vertex_color_is_srgb, bm.albedo_color, bm.roughness, bm.metallic, bm.shading_mode == 0, bm.transparency]
	print(s)
	for c in n.get_children(): _dump(c, d + 1)
func _init() -> void:
	for f in []:
		var sc: PackedScene = load("res://assets/models/%s.glb" % f)
		var n := sc.instantiate()
		_dump(n, 0)
	var sc2: PackedScene = load("res://assets/models/battery.glb")
	var b := sc2.instantiate()
	var mi := b.get_child(0).get_node("body") as MeshInstance3D
	var arr := mi.mesh.surface_get_arrays(0)
	var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	print("battery colors sample: ", cols[0], " ", cols[100], " count ", cols.size())
	quit()
