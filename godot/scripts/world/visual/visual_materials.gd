class_name VisualMaterials
extends RefCounted
## Materiales compartidos de las clases visuales (equivalente a Materials.ts de la versión web).
## Todos pensados para GL Compatibility: StandardMaterial3D simples, sin metal fuerte.

const C_LEAF := Color("#3fa34d")
const C_SUN := Color("#ffb82e")
const C_ORANGE := Color("#f28c28")
const C_BLUE := Color("#2f7be0")
const C_VIOLET := Color("#8b5cf6")
const C_DARK := Color("#0e2420")
const C_OK := Color("#46e06a")
const C_WARN := Color("#ffb82e")
const C_BAD := Color("#ff4d4d")

static var _glow: StandardMaterial3D
static var _blob: StandardMaterial3D
static var _lamp_shared: Array[BaseMaterial3D] = []
static var _night := 0.0


## Brillo sin iluminación con color por vértice (LEDs, segmentos de batería). Valor > 1 para el glow.
static func glow() -> StandardMaterial3D:
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.resource_name = "glow_vc"
		_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow.vertex_color_use_as_albedo = true
		_glow.vertex_color_is_srgb = true
		_glow.albedo_color = Color(1.6, 1.6, 1.6)
		_glow.disable_receive_shadows = true
	return _glow


## Sombra de contacto (mancha suave bajo personajes): textura de polvo en negro translúcido.
static func blob_shadow() -> StandardMaterial3D:
	if _blob == null:
		_blob = StandardMaterial3D.new()
		_blob.resource_name = "blob_shadow"
		_blob.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_blob.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_blob.albedo_color = Color(0, 0, 0, 0.34)
		_blob.albedo_texture = ModelLibrary.texture("dust.png")
		_blob.disable_receive_shadows = true
		_blob.render_priority = -1
	return _blob


## Material de superficie lisa de un color (cables, piezas sueltas).
static func surface(color: Color, roughness: float = 0.6, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	m.roughness = roughness
	m.metallic_specular = 0.4
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m


## Material emisivo plano (partículas de energía), mezcla aditiva.
static func additive(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, 1.0)
	m.disable_receive_shadows = true
	m.no_depth_test = false
	return m


## Registra el material de luminaria de un poste (compartido por todas las instancias del .glb).
static func register_lamp(m: BaseMaterial3D) -> void:
	if m == null or _lamp_shared.has(m):
		return
	_lamp_shared.append(m)
	_apply_lamp(m)


## Intensidad 0..1 de las luminarias públicas (la llama EnvironmentRig.update cada frame).
static func set_night(f: float) -> void:
	var k := clampf(f, 0.0, 1.0)
	if absf(k - _night) < 0.002:
		return
	_night = k
	for m: BaseMaterial3D in _lamp_shared:
		_apply_lamp(m)


static func night() -> float:
	return _night


static func _apply_lamp(m: BaseMaterial3D) -> void:
	var k := _night
	m.albedo_color = Color(0.33 + k * 2.6, 0.31 + k * 2.0, 0.28 + k * 1.1)
