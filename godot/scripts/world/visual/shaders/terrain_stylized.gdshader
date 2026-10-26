// Terreno estilizado: el color sigue saliendo de los colores por vértice (desierto, caminos, cerros) y
// las texturas pintadas a mano agregan los médanos y, en manchas grandes, la tierra agrietada del barreal.
// Coordenadas de mundo (x, z): las texturas no dependen de las UV del modelo.
shader_type spatial;
render_mode diffuse_lambert, specular_schlick_ggx;

uniform sampler2D sand_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cracks_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float sand_scale = 7.0;
uniform float cracks_scale = 4.5;
uniform float patch_scale = 26.0;
uniform float patch_amount = 0.8;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = wpos.xz;
	vec3 sand = texture(sand_tex, p / sand_scale).rgb;
	vec3 cracks = texture(cracks_tex, p / cracks_scale).rgb;
	float n = vnoise(p / patch_scale) * 0.7 + vnoise(p / (patch_scale * 0.4)) * 0.3;
	float m = smoothstep(0.58, 0.68, n) * patch_amount;
	vec3 detail = mix(sand, cracks, m);
	// Color por vértice tal cual (medido: da el mismo tono de suelo que el material original).
	ALBEDO = COLOR.rgb * detail;
	ROUGHNESS = 1.0;
	SPECULAR = 0.3;
}
