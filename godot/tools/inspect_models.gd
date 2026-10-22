extends SceneTree
## Inspecciona los .glb importados: jerarquía, AABB, materiales y colores de vértice.
## Uso: godot --headless --path godot -s res://tools/inspect_models.gd [-- nombre1 nombre2 ...]

const DIR := "res://assets/models/"


func _init() -> void:
	var names: Array[String] = []
	for a: String in OS.get_cmdline_user_args():
		names.append(a)
	if names.is_empty():
		for f: String in DirAccess.get_files_at(DIR):
			if f.ends_with(".glb"):
				names.append(f.get_basename())
	for n: String in names:
		var sc: PackedScene = load(DIR + n + ".glb")
		if sc == null:
			print("!! no carga ", n)
			continue
		var root: Node = sc.instantiate()
		var box := _aabb(root, Transform3D.IDENTITY)
		print("== %s  aabb pos=%s size=%s" % [n, box.position, box.size])
		_dump(root, 1)
		root.free()
	quit()


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var b: AABB = t * (n as MeshInstance3D).mesh.get_aabb()
		out = b
		first = false
	for c: Node in n.get_children():
		var cb := _aabb(c, t)
		if cb.size == Vector3.ZERO:
			continue
		out = cb if first else out.merge(cb)
		first = false
	return out


func _dump(n: Node, d: int) -> void:
	var s := "  ".repeat(d) + String(n.name) + " (" + n.get_class() + ")"
	if n is Node3D:
		var n3 := n as Node3D
		if n3.position != Vector3.ZERO:
			s += " pos=%s" % n3.position
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for i: int in mi.mesh.get_surface_count():
				var m: Material = mi.mesh.surface_get_material(i)
				var fmt: int = mi.mesh.surface_get_format(i)
				var arr: Array = mi.mesh.surface_get_arrays(i)
				var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				s += "\n" + "  ".repeat(d + 1) + "surf%d v=%d col=%s uv=%s" % [i, verts.size(), (fmt & Mesh.ARRAY_FORMAT_COLOR) != 0, (fmt & Mesh.ARRAY_FORMAT_TEX_UV) != 0]
				if (fmt & Mesh.ARRAY_FORMAT_COLOR) != 0:
					var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
					s += " c0=%s" % cols[0]
				if m is BaseMaterial3D:
					var bm := m as BaseMaterial3D
					s += " [%s vc=%s srgb=%s alb=%s tex=%s rough=%.2f metal=%.2f emis=%s tr=%d cull=%d]" % [bm.resource_name, bm.vertex_color_use_as_albedo, bm.vertex_color_is_srgb, bm.albedo_color, bm.albedo_texture != null, bm.roughness, bm.metallic, bm.emission_enabled, bm.transparency, bm.cull_mode]
	print(s)
	for c: Node in n.get_children():
		_dump(c, d + 1)
