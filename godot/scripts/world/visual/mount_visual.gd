class_name MountVisual
extends Node3D
## Estructura de montaje (dos patas con dado de hormigón). `tilt` es el nodo inclinable donde va el panel
## (rotation.x = inclinación, 0,45 rad normal; 0 = posición de defensa contra el Zonda). `ghost` es la silueta
## translúcida que marca dónde falta un panel.

const PIVOT_HEIGHT := 1.1
const DEFAULT_TILT := 0.45

var model: Node3D
var tilt: Node3D
var ghost: MeshInstance3D
var panel: PanelVisual
var _tilt_target := DEFAULT_TILT
var _base: MeshInstance3D
var _frame: MeshInstance3D
var _base_mesh: Mesh

var _batch_normal: InstanceBatch
var _batch_defense: InstanceBatch
var _batch_in: InstanceBatch
var _batch_handle := 0

## Mallas base + bastidor fusionadas por ángulo de reposo (1 draw call por montaje quieto).
static var _baked: Dictionary[int, ArrayMesh] = {}


## Lote para montajes quietos con inclinación `angle` (base + bastidor fusionados). Agregalo a la escena
## y pasalo a `use_batch()` de cada montaje: todo el campo en 1 llamada de dibujo.
static func create_batch(angle: float = DEFAULT_TILT) -> InstanceBatch:
	var probe := MountVisual.new()
	probe.tilt.rotation.x = angle
	var m := probe._baked_mesh()
	probe.free()
	var b := InstanceBatch.new(m, null, false, 32)
	b.name = "mount_batch_%d" % roundi(angle * 100.0)
	return b


func _init() -> void:
	name = "mount"
	model = ModelLibrary.instantiate(&"mount")
	add_child(model)
	tilt = model.find_child("tilt", true, false) as Node3D
	ghost = model.find_child("ghost", true, false) as MeshInstance3D
	_base = model.find_child("base", true, false) as MeshInstance3D
	_frame = model.find_child("frame", true, false) as MeshInstance3D
	_base_mesh = _base.mesh
	_frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF # la sombra la da el panel
	tilt.rotation.x = DEFAULT_TILT
	_bake()
	set_process(false)


## Coloca un panel en el montaje (oculta la silueta).
func attach_panel(p: PanelVisual) -> void:
	if panel != null and panel != p:
		panel.queue_free()
	panel = p
	if p.get_parent() != null:
		p.get_parent().remove_child(p)
	tilt.add_child(p)
	p.transform = Transform3D.IDENTITY
	set_ghost(false)


## Saca el panel (lo devuelve sin liberar) y muestra la silueta.
func detach_panel() -> PanelVisual:
	var p := panel
	panel = null
	if p != null:
		tilt.remove_child(p)
	set_ghost(true)
	return p


func set_ghost(on: bool) -> void:
	if ghost != null:
		ghost.visible = on


## Inclinación objetivo en radianes. `instant` la aplica ya; si no, se anima.
func set_tilt(angle: float, instant: bool = false) -> void:
	_tilt_target = angle
	if instant:
		tilt.rotation.x = angle
		set_process(false)
		_bake()
	else:
		_unbake()
		set_process(true)


## Atajo: posición de defensa (paneles horizontales) o normal.
func set_defense(on: bool, instant: bool = false) -> void:
	set_tilt(0.0 if on else DEFAULT_TILT, instant)


func _process(dt: float) -> void:
	tilt.rotation.x = EquipmentVisual.damp(tilt.rotation.x, _tilt_target, 5.0, dt)
	if absf(tilt.rotation.x - _tilt_target) < 0.001:
		tilt.rotation.x = _tilt_target
		set_process(false)
		_bake()


## En reposo: base y bastidor en una sola malla (cacheada por ángulo); el bastidor suelto se oculta.
func _bake() -> void:
	_base.mesh = _baked_mesh()
	_frame.visible = false
	_sync_batch()


func _baked_mesh() -> ArrayMesh:
	var key := roundi(tilt.rotation.x * 1000.0)
	var m: ArrayMesh = _baked.get(key)
	if m == null:
		var st := SurfaceTool.new()
		st.append_from(_base_mesh, 0, Transform3D.IDENTITY)
		st.append_from(_frame.mesh, 0, tilt.transform * _frame.transform)
		m = st.commit()
		m.surface_set_material(0, _base_mesh.surface_get_material(0))
		_baked[key] = m
	return m


## Animando la inclinación: vuelve a mallas separadas.
func _unbake() -> void:
	_base.mesh = _base_mesh
	_frame.visible = true
	_sync_batch()


## Modo lote: quieto en la inclinación normal (o de defensa) se dibuja dentro del lote compartido.
## Si el montaje se mueve, el lote se actualiza solo.
func use_batch(normal: InstanceBatch, defense: InstanceBatch = null) -> void:
	_batch_normal = normal
	_batch_defense = defense
	set_notify_transform(true)
	_sync_batch()


func _wanted_batch() -> InstanceBatch:
	if not is_inside_tree() or not is_visible_in_tree() or _frame.visible:
		return null
	if _batch_normal != null and is_equal_approx(tilt.rotation.x, DEFAULT_TILT):
		return _batch_normal
	if _batch_defense != null and is_zero_approx(tilt.rotation.x):
		return _batch_defense
	return null


func _sync_batch() -> void:
	var want := _wanted_batch()
	if want != _batch_in:
		if _batch_in != null:
			_batch_in.remove(_batch_handle)
		_batch_in = want
		if want != null:
			_batch_handle = want.add(global_transform)
	elif want != null:
		want.set_instance(_batch_handle, global_transform)
	_base.visible = _batch_in == null


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE, NOTIFICATION_TRANSFORM_CHANGED, NOTIFICATION_VISIBILITY_CHANGED:
			if _batch_normal != null or _batch_defense != null:
				_sync_batch()
		NOTIFICATION_EXIT_TREE:
			if _batch_in != null:
				_batch_in.remove(_batch_handle)
				_batch_in = null
