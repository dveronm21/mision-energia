class_name EnvironmentRig
extends Node3D
## Ambiente del mundo (IEnvironment de la versión web): cielo con shader propio (día, atardecer, noche,
## sol, luna, estrellas, nubes), sol/luna direccional con sombras para móviles y TV, niebla, tonemapping,
## terreno sanjuanino, montañas de fondo, vegetación instanciada (MultiMesh desde env_instances.json)
## y viento Zonda (niebla ocre + polvo con CPUParticles3D).
##
## Orientación: norte = +Z (los paneles miran a +Z); el sol sale por el este (-X) y se pone por el oeste (+X).
##
##   var env := EnvironmentRig.new()
##   add_child(env)
##   env.set_quality(1)
##   # cada frame:
##   env.update(dt, hour, zonda, clouds, player_pos)
##   building.set_lights(env.night_factor())

const SKY_SHADER := preload("res://scripts/world/visual/shaders/sky.gdshader")
const INSTANCES_PATH := "res://assets/models/env_instances.json"
## Mallas de vegetación instanciada (nombre en env_instances.json → modelo env_<nombre>.glb).
const SCATTER: Array[StringName] = [&"rocks", &"jarillas", &"grass", &"algarrobos", &"alamos", &"vinedo"]
## Los que no proyectan sombra (pasto) o sólo en calidad alta.
const NO_SHADOW: Array[StringName] = [&"grass", &"rocks"]

const DAY_TOP := Color("#3d8fe0")
const DAY_HORIZON := Color("#cfe8f2")
const DUSK_TOP := Color("#3a4f8c")
const DUSK_HORIZON := Color("#ffbe7d")
const NIGHT_TOP := Color("#040a1c")
const NIGHT_HORIZON := Color("#1a2a4c")
const ZONDA := Color("#c79a62")
const ZONDA_DARK := Color("#6a4a30")

## Escala de energía three.js → Godot (three usa intensidades físicas sin 1/π; Godot ya lo incluye).
const SUN_ENERGY_K := 1.0 / PI
const AMBIENT_K := 1.0 / PI

var world_env: WorldEnvironment
var environment: Environment
var sun: DirectionalLight3D
var terrain: Node3D
var mountains: Node3D
var dust: CPUParticles3D
var sun_dir := Vector3.UP
var quality := 1
## Ajustes finos de calibración contra las capturas de la versión web (tools/shot.gd --rig=...).
var sun_scale := 1.0
var ambient_scale := 1.0
## GL Compatibility dibuja la luz con sombras en una pasada aditiva que se suma en espacio sRGB (8 bits
## codificados), no lineal: el sol "se suma de más" sobre la luz ambiente y todo sale lavado (medido en 4.7.2:
## ambiente 0,25 + sol 0,10 da 0,76 en vez de 0,35). Con esto se corrige la energía del sol para que, sobre el
## suelo, srgb(ambiente) + srgb(sol') = srgb(ambiente + sol). Se activa solo en Compatibility con sombras.
var gamma_additive_fix := RenderingServer.get_current_rendering_method() == "gl_compatibility"
## Luz ambiente de día relativa a la de noche: el ACES de Godot aclara más los medios-altos que el de three.js,
## así que de día bajamos la hemisférica para conservar el contraste de las sombras de la versión web.
var ambient_day_scale := 1.0

var _sky_mat: ShaderMaterial
var _scatter: Dictionary[StringName, MultiMeshInstance3D] = {}
var _scatter_full: Dictionary[StringName, int] = {}
var _dust_mat: StandardMaterial3D
var _night := 0.0
var _time := 0.0
var _sky_push_t := 1.0
var _last_sky_key := Vector4(-1, -1, -1, -1)


func _init() -> void:
	name = "environment"
	_build_world_env()
	_build_sun()
	terrain = ModelLibrary.instantiate(&"env_terrain")
	add_child(terrain)
	_set_shadow_cast(terrain, false) # la zona de juego es plana: sólo recibe
	mountains = ModelLibrary.instantiate(&"env_mountains")
	add_child(mountains)
	_set_shadow_cast(mountains, false)
	_build_scatter()
	_build_dust()
	set_quality(1)
	update(0.0, 11.0, 0.0, 0.0, Vector3(2, 0, -4))


func _ready() -> void:
	_apply_viewport_quality()


## Factor 0..1 de noche (para luces de la ciudad y luminarias).
func night_factor() -> float:
	return _night


## Actualiza hora, Zonda (0..1), nubes (0..1) y el punto a seguir (polvo y estrellas centrados ahí).
func update(dt: float, hour: float, zonda: float, clouds: float, follow: Vector3) -> void:
	_time += dt
	zonda = clampf(zonda, 0.0, 1.0)
	clouds = clampf(clouds, 0.0, 1.0)

	# Sol: día de 6:30 a 20:00, noche de 20:00 a 6:30 (continuo)
	var h := fposmod(hour, 24.0)
	var a: float
	if h >= 6.5 and h <= 20.0:
		a = PI * (h - 6.5) / 13.5
	else:
		var hn := h - 20.0 if h > 20.0 else h + 4.0
		a = PI + PI * hn / 10.5
	sun_dir = Vector3(-cos(a), sin(a) * 0.86, sin(a) * 0.5 + 0.18).normalized()
	var elev := sun_dir.y
	var moon := Vector3(-sun_dir.x * 0.8, maxf(0.35, -sun_dir.y), -0.45).normalized()

	var day := _smooth(-0.04, 0.38, elev)
	var dusk := (1.0 - _smooth(0.0, 0.32, absf(elev - 0.04))) * (1.0 - zonda * 0.6)
	var night := _smooth(0.06, -0.16, elev)
	_night = _smooth(0.14, -0.06, elev)

	# Colores del cielo (lineales)
	var top := _lin(NIGHT_TOP).lerp(_lin(DAY_TOP), day).lerp(_lin(DUSK_TOP), dusk * 0.55)
	var hor := _lin(NIGHT_HORIZON).lerp(_lin(DAY_HORIZON), day).lerp(_lin(DUSK_HORIZON), dusk * 0.85)
	var haze := _lin(ZONDA).lerp(_lin(ZONDA_DARK), night * 0.85)
	var sun_col := Color(1, 0.93, 0.78).lerp(Color(1, 0.55, 0.25), dusk)

	# Hemisférica (luz ambiente): mismo cálculo que la versión web
	var hemi_sky := hor.lerp(top, 0.35 * day).lerp(Color(1, 0.92, 0.8), 0.25 * dusk).lerp(Color(0.35, 0.42, 0.65), night * 0.6).lerp(_lin(ZONDA), zonda * 0.6)
	var hemi_ground := Color(0.6, 0.48, 0.34).lerp(Color(0.08, 0.08, 0.12), night)
	var hemi_i := (lerpf(0.6, 1.25, day) + dusk * 0.6 + zonda * 0.2) * lerpf(1.0, ambient_day_scale, day)

	_sky_push_t += dt
	var key := Vector4(snappedf(h, 0.02), snappedf(zonda, 0.01), snappedf(clouds, 0.01), 0.0)
	if dt == 0.0 or key != _last_sky_key or _sky_push_t > 0.25:
		_last_sky_key = key
		_sky_push_t = 0.0
		var m := _sky_mat
		m.set_shader_parameter("top_color", _v3(top))
		m.set_shader_parameter("horizon_color", _v3(hor))
		m.set_shader_parameter("ground_color", _v3(hor * 0.75))
		m.set_shader_parameter("sun_dir", sun_dir)
		m.set_shader_parameter("moon_dir", moon)
		m.set_shader_parameter("sun_color", _v3(sun_col))
		m.set_shader_parameter("sun_vis", _smooth(-0.03, 0.02, elev))
		m.set_shader_parameter("night", night)
		m.set_shader_parameter("clouds", clouds)
		m.set_shader_parameter("zonda", zonda)
		m.set_shader_parameter("cloud_time", _time)
		m.set_shader_parameter("haze_color", _v3(haze))
		m.set_shader_parameter("stars", night * (1.0 - clouds * 0.85) * (1.0 - zonda))
		m.set_shader_parameter("cloud_lit", _v3(Color(1, 1, 1).lerp(Color(1, 0.72, 0.5), dusk).lerp(Color(0.18, 0.22, 0.32), night)))
		m.set_shader_parameter("cloud_shade", _v3(Color(0.66, 0.72, 0.8).lerp(Color(0.55, 0.42, 0.45), dusk).lerp(Color(0.06, 0.08, 0.14), night)))
		m.set_shader_parameter("amb_sky", _v3(hemi_sky * hemi_i * AMBIENT_K * ambient_scale))
		m.set_shader_parameter("amb_ground", _v3(hemi_ground * hemi_i * AMBIENT_K * ambient_scale))

	# Luz principal: sol o luna
	var sun_i := 2.9 * _smooth(-0.05, 0.16, elev) * (1.0 - 0.55 * clouds) * (1.0 - 0.55 * zonda)
	var moon_i := 0.42 * night * (1.0 - 0.6 * clouds) * (1.0 - 0.7 * zonda)
	var use_sun := sun_i >= moon_i
	var dir := sun_dir if use_sun else moon
	var energy := maxf(sun_i, moon_i) * SUN_ENERGY_K * sun_scale
	var light_lin: Color # color lineal (como setRGB de three.js)
	if use_sun:
		light_lin = Color(1, 0.95, 0.86).lerp(Color(1, 0.72, 0.48), dusk * 0.85).lerp(Color(1, 0.78, 0.55), zonda * 0.6)
	else:
		light_lin = Color(0.62, 0.72, 1.0)
	if gamma_additive_fix and sun.shadow_enabled:
		var amb_up := hemi_ground.lerp(hemi_sky, 0.88) * (hemi_i * AMBIENT_K * ambient_scale)
		# Con la luna (todo en el pie de la curva) la suma en sRGB se parece más a la versión web: sólo con sol.
		var fixed := (light_lin * energy).lerp(_compensate_additive(light_lin * energy, amb_up, maxf(dir.y, 0.08)), _smooth(-0.05, 0.05, elev))
		energy = maxf(fixed.r, maxf(fixed.g, fixed.b))
		light_lin = fixed / maxf(energy, 1e-6) if energy > 0.0 else light_lin
	sun.light_energy = energy
	sun.light_color = Color(light_lin.r, light_lin.g, light_lin.b).linear_to_srgb()
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.BACK
	sun.basis = Basis.looking_at(-dir, up) # el rig va en el origen del mundo
	sun.visible = sun.light_energy > 0.002

	# Niebla (lineal en profundidad como la versión web)
	var fog_col := hor.lerp(haze, zonda)
	environment.fog_light_color = fog_col.linear_to_srgb()
	environment.fog_depth_begin = lerpf(70.0, 3.0, pow(zonda, 0.7))
	environment.fog_depth_end = lerpf(700.0 - clouds * 150.0, 55.0, pow(zonda, 0.6))
	environment.fog_density = lerpf(0.55, 1.0, zonda)

	# Polvo del Zonda
	dust.position = Vector3(follow.x, 4.5, follow.z)
	var dust_a := minf(1.0, zonda * 1.3)
	dust.emitting = zonda > 0.02
	dust.visible = zonda > 0.02
	var dc := Color(0.95, 0.85, 0.68).lerp(Color(0.35, 0.28, 0.22), night * 0.8)
	_dust_mat.albedo_color = Color(dc.r, dc.g, dc.b, dust_a)
	var wind := Vector3(-16, 0, -5).normalized()
	dust.direction = wind
	dust.initial_velocity_min = 5.0 + zonda * 6.0
	dust.initial_velocity_max = 9.0 + zonda * 9.0

	VisualMaterials.set_night(_night)


## 0 = baja (sin sombras, menos vegetación y polvo), 1 = media, 2 = alta (sombras 4096 suaves y glow).
func set_quality(q: int) -> void:
	quality = clampi(q, 0, 2)
	sun.shadow_enabled = quality > 0
	sun.directional_shadow_max_distance = 32.0 if quality == 1 else 48.0
	# media: 1 sola cascada (más barata); alta: 2 cascadas (sombras nítidas cerca y alcance lejos)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if quality == 2 else DirectionalLight3D.SHADOW_ORTHOGONAL
	RenderingServer.directional_shadow_atlas_set_size(4096 if quality == 2 else 2048, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if quality == 2 else RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	environment.glow_enabled = quality == 2
	var k := 0.6 if quality == 0 else 1.0
	for n: StringName in _scatter:
		var mmi := _scatter[n]
		var full := _scatter_full[n]
		mmi.multimesh.visible_instance_count = full if n == &"vinedo" else int(full * k)
		var cast := quality > 0 and not NO_SHADOW.has(n)
		if n == &"vinedo" or n == &"jarillas":
			cast = quality == 2
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.amount = [300, 600, 1000][quality]
	if is_inside_tree():
		_apply_viewport_quality()


func _apply_viewport_quality() -> void:
	var vp := get_viewport()
	if vp == null:
		return
	vp.msaa_3d = Viewport.MSAA_DISABLED if quality == 0 else Viewport.MSAA_2X if quality == 1 else Viewport.MSAA_4X


# ----------------------------------------------------------------------------------------- construcción

func _build_world_env() -> void:
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = SKY_SHADER
	_sky_mat.set_shader_parameter("encode_srgb", RenderingServer.get_current_rendering_method() == "gl_compatibility")
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_AUTOMATIC
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 1.0
	# Sin reflejos del cielo (igual que la versión web: la hemisférica sólo aporta difuso). Con reflejos, el
	# Fresnel en ángulo rasante "lava" el suelo y los paneles.
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.9
	environment.tonemap_white = 6.0
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_depth_curve = 1.0
	environment.fog_sky_affect = 0.0
	environment.fog_sun_scatter = 0.0
	environment.glow_enabled = false
	environment.glow_intensity = 0.5
	environment.glow_strength = 0.9
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.1
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.08
	environment.adjustment_contrast = 1.04
	world_env = WorldEnvironment.new()
	world_env.name = "world_environment"
	world_env.environment = environment
	add_child(world_env)


func _build_sun() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "sun"
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 42.0
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 0.8
	sun.shadow_blur = 0.5
	sun.shadow_opacity = 0.92
	sun.light_angular_distance = 0.5
	sun.light_specular = 0.6
	add_child(sun)


func _build_scatter() -> void:
	var f := FileAccess.open(INSTANCES_PATH, FileAccess.READ)
	if f == null:
		push_error("EnvironmentRig: no se puede leer %s" % INSTANCES_PATH)
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	for n: StringName in SCATTER:
		var entry: Dictionary = data.get(String(n), {})
		if entry.is_empty():
			continue
		var count: int = entry["count"]
		var xf: Array = entry["xf"]
		var col: Array = entry.get("col", [])
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = not col.is_empty()
		mm.mesh = ModelLibrary.first_mesh(StringName("env_" + String(n)))
		mm.instance_count = count
		# Orden aleatorio estable: al recortar instancias por calidad se reparten parejo por el mapa.
		var order := range(count)
		var rng := RandomNumberGenerator.new()
		rng.seed = 91
		for i: int in range(count - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp: int = order[i]
			order[i] = order[j]
			order[j] = tmp
		for slot: int in count:
			var i: int = order[slot]
			var o := i * 12
			var basis := Basis(
				Vector3(xf[o], xf[o + 1], xf[o + 2]),
				Vector3(xf[o + 3], xf[o + 4], xf[o + 5]),
				Vector3(xf[o + 6], xf[o + 7], xf[o + 8]))
			mm.set_instance_transform(slot, Transform3D(basis, Vector3(xf[o + 9], xf[o + 10], xf[o + 11])))
			if mm.use_colors:
				mm.set_instance_color(slot, Color(col[i * 3], col[i * 3 + 1], col[i * 3 + 2]))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = String(n)
		mmi.multimesh = mm
		add_child(mmi)
		_scatter[n] = mmi
		_scatter_full[n] = count


func _build_dust() -> void:
	dust = CPUParticles3D.new()
	dust.name = "zonda_dust"
	dust.local_coords = false
	dust.amount = 600
	dust.lifetime = 4.0
	dust.preprocess = 4.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(32, 4.5, 32)
	dust.position = Vector3(0, 4.5, 0)
	dust.spread = 18.0
	dust.gravity = Vector3(0, -0.2, 0)
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.6
	dust.angular_velocity_min = -90.0
	dust.angular_velocity_max = 90.0
	var q := QuadMesh.new()
	q.size = Vector2(0.34, 0.34)
	dust.mesh = q
	_dust_mat = StandardMaterial3D.new()
	_dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_dust_mat.albedo_texture = ModelLibrary.texture("dust.png")
	_dust_mat.disable_receive_shadows = true
	_dust_mat.proximity_fade_enabled = false
	dust.material_override = _dust_mat
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# alfa por partícula: nace y muere suave
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 1))
	ramp.add_point(0.8, Color(1, 1, 1, 1))
	dust.color_ramp = ramp
	_dust_mat.vertex_color_use_as_albedo = true
	dust.emitting = false
	dust.visible = false
	add_child(dust)


func _set_shadow_cast(n: Node, on: bool) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c: Node in n.get_children():
		_set_shadow_cast(c, on)


## Energía por canal del sol tal que, sumada en espacio sRGB sobre la ambiente `amb` (superficie de referencia
## con N·L = `ndl`), dé lo mismo que la suma lineal. Devuelve el color lineal × energía corregido.
static func _compensate_additive(light: Color, amb: Color, ndl: float) -> Color:
	var out := Color(0, 0, 0)
	for c: int in 3:
		var a := maxf(amb[c], 0.0)
		var s := maxf(light[c], 0.0) * ndl
		var enc := _enc(a + s) - _enc(a)
		out[c] = _dec(enc) / ndl
	return out


static func _enc(x: float) -> float:
	return x * 12.92 if x < 0.0031308 else 1.055 * pow(x, 1.0 / 2.4) - 0.055


static func _dec(x: float) -> float:
	return x / 12.92 if x < 0.04045 else pow((x + 0.055) / 1.055, 2.4)


static func _smooth(e0: float, e1: float, x: float) -> float:
	var t := clampf((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


static func _lin(c: Color) -> Color:
	return c.srgb_to_linear()


static func _v3(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
