class_name ModelLibrary
extends RefCounted
## Biblioteca de modelos .glb (assets/models) con caché de PackedScene.
## Todos los modelos: origen en el piso (y = 0), mirando a +Z, escala en metros.
##
##   var mount := ModelLibrary.instantiate(&"mount")
##
## La caché es estática: cada .glb se carga una sola vez por ejecución.

const MODELS_DIR := "res://assets/models/"
const TEXTURES_DIR := "res://assets/textures/"

## Nombres válidos (los .glb exportados por tools/export_models).
const NAMES: Array[StringName] = [
	&"panel", &"mount", &"inverter", &"battery", &"protection", &"switchboard", &"junction_box",
	&"console", &"pump", &"crate_battery", &"crate_protection", &"crate_kit", &"crate_panel", &"pallet",
	&"row_post", &"tree_alamo", &"tree_algarrobo", &"tree_jarilla", &"building_0", &"building_1",
	&"building_2", &"building_3", &"power_pole", &"slab", &"wall", &"canopy", &"worker",
	&"env_terrain", &"env_mountains", &"env_rocks", &"env_jarillas", &"env_grass", &"env_algarrobos",
	&"env_alamos", &"env_vinedo",
]

static var _scenes: Dictionary[StringName, PackedScene] = {}
static var _meshes: Dictionary[StringName, Mesh] = {}
static var _textures: Dictionary[String, Texture2D] = {}


## PackedScene cacheada del modelo `model_name` (null si no existe).
static func scene(model_name: StringName) -> PackedScene:
	if _scenes.has(model_name):
		return _scenes[model_name]
	var path := MODELS_DIR + String(model_name) + ".glb"
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		push_error("ModelLibrary: no existe el modelo %s" % path)
	_scenes[model_name] = ps
	return ps


## Instancia nueva del modelo. Devuelve un Node3D vacío (y avisa) si el modelo no existe.
static func instantiate(model_name: StringName) -> Node3D:
	var ps := scene(model_name)
	if ps == null:
		var empty := Node3D.new()
		empty.name = String(model_name)
		return empty
	var n: Node3D = ps.instantiate() as Node3D
	n.name = String(model_name)
	return n


## Primera malla del modelo (para MultiMesh: vegetación, pila de paneles).
static func first_mesh(model_name: StringName) -> Mesh:
	if _meshes.has(model_name):
		return _meshes[model_name]
	var n := instantiate(model_name)
	var mi := find_mesh(n)
	var m: Mesh = mi.mesh if mi != null else null
	n.free()
	_meshes[model_name] = m
	return m


## Primer MeshInstance3D (en profundidad) de un árbol de nodos.
static func find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n as MeshInstance3D
	for c: Node in n.get_children():
		var r := find_mesh(c)
		if r != null:
			return r
	return null


## Textura suelta de assets/textures (cacheada).
static func texture(file_name: String) -> Texture2D:
	if _textures.has(file_name):
		return _textures[file_name]
	var t: Texture2D = load(TEXTURES_DIR + file_name) as Texture2D
	_textures[file_name] = t
	return t


## Material de superficie 0 de un MeshInstance3D (override > superficie de la malla).
static func surface_material(mi: MeshInstance3D) -> BaseMaterial3D:
	if mi == null:
		return null
	var m: Material = mi.get_surface_override_material(0)
	if m == null and mi.mesh != null:
		m = mi.mesh.surface_get_material(0)
	return m as BaseMaterial3D


## Duplica el material de la superficie 0 y lo asigna como override (material propio de la instancia).
static func own_material(mi: MeshInstance3D) -> BaseMaterial3D:
	var src := surface_material(mi)
	if src == null:
		return null
	var dup: BaseMaterial3D = src.duplicate() as BaseMaterial3D
	mi.set_surface_override_material(0, dup)
	return dup
