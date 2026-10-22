@tool
extends EditorScenePostImport
## Post-import de los .glb exportados desde la versión web (tools/export_models).
## - Saca la raíz auxiliar "AuxScene" que agrega GLTFExporter: la escena queda con el nodo del modelo como raíz.
## - Colores por vértice: el exportador los guarda en sRGB → vertex_color_use_as_albedo + vertex_color_is_srgb
##   (verificado: en GL Compatibility y en Forward+ el gris 0.5 por vértice sale igual que albedo 0.5).
## - Materiales para GL Compatibility: sin metal fuerte (sin sondas de reflexión se ve negro), especular moderado
##   y difuso Lambert (igual que three.js; Burley aclara de más el terreno visto en ángulo rasante).
## - Materiales especiales por nombre: glow/lamp/water_stream sin iluminación, ghost translúcido sin sombra.


func _post_import(scene: Node) -> Object:
	var root := _strip_aux_root(scene)
	_fix(root)
	return root


## GLTFExporter de three envuelve todo en una escena "AuxScene" con un solo hijo: lo promovemos a raíz.
func _strip_aux_root(scene: Node) -> Node:
	if scene.get_child_count() != 1:
		return scene
	var child := scene.get_child(0)
	if not (child is Node3D) or not (scene is Node3D):
		return scene
	if not (scene as Node3D).transform.is_equal_approx(Transform3D.IDENTITY):
		return scene
	scene.remove_child(child)
	child.owner = null
	_reown(child, child)
	scene.free()
	return child


func _reown(n: Node, owner_node: Node) -> void:
	for c: Node in n.get_children():
		c.owner = owner_node
		_reown(c, owner_node)


func _fix(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var mesh := mi.mesh
		if mesh != null:
			for i: int in mesh.get_surface_count():
				var mat: Material = mesh.surface_get_material(i)
				if mat is BaseMaterial3D:
					_fix_material(mat as BaseMaterial3D, (mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR) != 0, mi)
	for c: Node in n.get_children():
		_fix(c)


func _fix_material(bm: BaseMaterial3D, has_color: bool, mi: MeshInstance3D) -> void:
	if has_color:
		bm.vertex_color_use_as_albedo = true
		bm.vertex_color_is_srgb = true
	if bm.metallic > 0.0:
		bm.metallic = minf(bm.metallic, 0.1)
	bm.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	# Lambert como la versión web: Burley (el default) aclara mucho el suelo rugoso visto en ángulo rasante.
	bm.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	bm.metallic_specular = 0.35
	match bm.resource_name:
		"glow", "lamp", "water_stream":
			bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bm.disable_receive_shadows = true
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"ghost":
			bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			bm.albedo_color = Color(0.85, 0.95, 1.0, 0.32)
			bm.disable_receive_shadows = true
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"water":
			bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			bm.metallic_specular = 0.6
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		"windows":
			bm.emission_energy_multiplier = 0.0
