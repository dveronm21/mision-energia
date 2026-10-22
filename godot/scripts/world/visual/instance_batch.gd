class_name InstanceBatch
extends MultiMeshInstance3D
## Lote de instancias de una misma malla (MultiMesh): 1 llamada de dibujo (y 1 de sombra) para N objetos.
## Lo usan MountVisual y PanelVisual en modo lote (`use_batch`) para que el campo solar no cueste una
## llamada por pieza. Ubicalo en el origen del mundo (o con la transformación que quieras: las instancias
## se guardan relativas al lote).
##
##   var batch := InstanceBatch.new(mesh, material, true)
##   add_child(batch)
##   var h := batch.add(xf)            # handle estable
##   batch.set_instance(h, new_xf)
##   batch.remove(h)

var _slot_of: Dictionary[int, int] = {}
var _handle_at: PackedInt32Array = PackedInt32Array()
var _next_handle := 1


func _init(batch_mesh: Mesh = null, material: Material = null, custom_data: bool = false, capacity: int = 32) -> void:
	name = "instance_batch"
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = custom_data
	# GL Compatibility: con datos custom y sin colores por instancia, COLOR llega multiplicado por los datos
	# custom (verificado en 4.7.2). Con colores por instancia en blanco queda bien en todos los renderers.
	multimesh.use_colors = custom_data
	multimesh.mesh = batch_mesh
	multimesh.instance_count = maxi(1, capacity)
	multimesh.visible_instance_count = 0
	if material != null:
		material_override = material


## Cantidad de instancias activas.
func size() -> int:
	return _handle_at.size()


## Agrega una instancia con transformación global `xf`; devuelve un handle estable.
func add(xf: Transform3D, custom: Color = Color(0, 0, 0, 0)) -> int:
	var n := _handle_at.size()
	if n >= multimesh.instance_count:
		_grow(maxi(multimesh.instance_count * 2, n + 1))
	var h := _next_handle
	_next_handle += 1
	_handle_at.append(h)
	_slot_of[h] = n
	multimesh.visible_instance_count = n + 1
	_write(n, xf)
	if multimesh.use_custom_data:
		multimesh.set_instance_custom_data(n, custom)
	if multimesh.use_colors:
		multimesh.set_instance_color(n, Color.WHITE)
	return h


func set_instance(handle: int, xf: Transform3D) -> void:
	if _slot_of.has(handle):
		_write(_slot_of[handle], xf)


func set_custom(handle: int, custom: Color) -> void:
	if _slot_of.has(handle) and multimesh.use_custom_data:
		multimesh.set_instance_custom_data(_slot_of[handle], custom)


## Saca la instancia (la última ocupa su lugar).
func remove(handle: int) -> void:
	if not _slot_of.has(handle):
		return
	var slot: int = _slot_of[handle]
	var last := _handle_at.size() - 1
	if slot != last:
		var moved := _handle_at[last]
		multimesh.set_instance_transform(slot, multimesh.get_instance_transform(last))
		if multimesh.use_custom_data:
			multimesh.set_instance_custom_data(slot, multimesh.get_instance_custom_data(last))
		if multimesh.use_colors:
			multimesh.set_instance_color(slot, Color.WHITE)
		_handle_at[slot] = moved
		_slot_of[moved] = slot
	_handle_at.resize(last)
	_slot_of.erase(handle)
	multimesh.visible_instance_count = last


func _write(slot: int, xf: Transform3D) -> void:
	var local := xf
	if is_inside_tree():
		local = global_transform.affine_inverse() * xf
	multimesh.set_instance_transform(slot, local)


func _grow(count: int) -> void:
	var n := _handle_at.size()
	var xfs: Array[Transform3D] = []
	var cds: Array[Color] = []
	for i: int in n:
		xfs.append(multimesh.get_instance_transform(i))
		if multimesh.use_custom_data:
			cds.append(multimesh.get_instance_custom_data(i))
	multimesh.visible_instance_count = -1
	multimesh.instance_count = count
	for i: int in n:
		multimesh.set_instance_transform(i, xfs[i])
		if multimesh.use_custom_data:
			multimesh.set_instance_custom_data(i, cds[i])
		if multimesh.use_colors:
			multimesh.set_instance_color(i, Color.WHITE)
	multimesh.visible_instance_count = n
