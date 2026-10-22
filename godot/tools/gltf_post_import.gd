@tool
extends EditorScenePostImport
## Post-import de los .glb exportados desde la versión web (tools/export_models).
## - Colores por vértice: activa vertex_color_use_as_albedo + vertex_color_is_srgb (el exportador los guarda en sRGB).
## - Saca la raíz auxiliar: la escena importada queda con el nombre del modelo.
## - Ajusta materiales para GL Compatibility (sin metal fuerte: sin sondas de reflexión se ve negro).


func _post_import(scene: Node) -> Object:
	_fix(scene)
	return scene


func _fix(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var mesh := mi.mesh
		if mesh != null:
			for i in mesh.get_surface_count():
				var mat := mesh.surface_get_material(i)
				if mat is BaseMaterial3D:
					var bm := mat as BaseMaterial3D
					var has_color: bool = (mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR) != 0
					if has_color:
						bm.vertex_color_use_as_albedo = true
						bm.vertex_color_is_srgb = true
					if bm.metallic > 0.0:
						bm.metallic = minf(bm.metallic, 0.1)
					bm.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	for c in n.get_children():
		_fix(c)
