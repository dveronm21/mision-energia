class_name PanelVisual
extends Node3D
## Panel solar 2,0 × 1,15 m (marco, celdas, vidrio). Origen en su cara inferior: se cuelga del `tilt` del
## montaje. Material propio por panel: polvo (textura sucia) y brillo de producción independientes.

const GLOW_COLOR := Color("#22d3ee")

const BATCH_SHADER := preload("res://scripts/world/visual/shaders/panel_batch.gdshader")

var model: Node3D
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _dirty := false
var _glow := 0.0
var _batch: InstanceBatch
var _batch_in := false
var _batch_handle := 0


## Lote para paneles (polvo y brillo por instancia con un shader propio). Agregalo a la escena y pasalo
## a `use_batch()` de cada panel: todos los paneles en 1 llamada de dibujo.
static func create_batch() -> InstanceBatch:
	var mat := ShaderMaterial.new()
	mat.shader = BATCH_SHADER
	mat.set_shader_parameter("tex_clean", ModelLibrary.texture("panel_clean.png"))
	mat.set_shader_parameter("tex_dirty", ModelLibrary.texture("panel_dirty.png"))
	mat.set_shader_parameter("glow_color", GLOW_COLOR)
	var b := InstanceBatch.new(ModelLibrary.first_mesh(&"panel"), mat, true, 32)
	b.name = "panel_batch"
	return b


func _init() -> void:
	name = "panel"
	model = ModelLibrary.instantiate(&"panel")
	add_child(model)
	_mesh = ModelLibrary.find_mesh(model)
	_mat = ModelLibrary.own_material(_mesh) as StandardMaterial3D
	if _mat != null:
		_mat.albedo_texture = ModelLibrary.texture("panel_clean.png")
		_mat.emission_enabled = true
		_mat.emission = GLOW_COLOR
		_mat.emission_texture = _mat.albedo_texture
		_mat.emission_energy_multiplier = 0.0
		_mat.roughness = 0.3
		_mat.metallic_specular = 0.6


## Panel con polvo (rinde menos): cambia la textura.
func set_dirty(on: bool) -> void:
	_dirty = on
	if _mat == null:
		return
	_mat.albedo_texture = ModelLibrary.texture("panel_dirty.png" if on else "panel_clean.png")
	_mat.emission_texture = _mat.albedo_texture
	_push_custom()


func is_dirty() -> bool:
	return _dirty


## Brillo de producción 0..1 (celdas celestes).
func set_glow(v: float) -> void:
	_glow = maxf(0.0, v)
	if _mat != null:
		_mat.emission_energy_multiplier = _glow * 1.4
	_push_custom()


## Modo lote: el panel se dibuja dentro de `batch` (sigue a su nodo: inclinación, movimiento, visibilidad).
func use_batch(batch: InstanceBatch) -> void:
	_batch = batch
	set_notify_transform(true)
	_sync_batch()


func _custom() -> Color:
	return Color(1.0 if _dirty else 0.0, _glow, 0, 0)


func _push_custom() -> void:
	if _batch_in:
		_batch.set_custom(_batch_handle, _custom())


func _sync_batch() -> void:
	if _batch == null:
		return
	var want := is_inside_tree() and is_visible_in_tree()
	if want and not _batch_in:
		_batch_handle = _batch.add(global_transform, _custom())
		_batch_in = true
	elif not want and _batch_in:
		_batch.remove(_batch_handle)
		_batch_in = false
	elif want:
		_batch.set_instance(_batch_handle, global_transform)
	_mesh.visible = not _batch_in


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE, NOTIFICATION_TRANSFORM_CHANGED, NOTIFICATION_VISIBILITY_CHANGED:
			_sync_batch()
		NOTIFICATION_EXIT_TREE:
			if _batch_in:
				_batch.remove(_batch_handle)
				_batch_in = false
