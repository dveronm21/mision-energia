// Panel solar en lote (MultiMesh): polvo y brillo por instancia en INSTANCE_CUSTOM (r = sucio 0..1,
// g = brillo 0..1). Mismo aspecto que el StandardMaterial3D de PanelVisual.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_schlick_ggx;

uniform sampler2D tex_clean : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D tex_dirty : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 glow_color : source_color = vec3(0.133, 0.827, 0.933);
uniform float roughness_value = 0.3;
uniform float specular_value = 0.6;

varying vec2 v_custom;

vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) * (1.0 / 1.055), vec3(2.4)), c * (1.0 / 12.92), lessThan(c, vec3(0.04045)));
}

void vertex() {
	v_custom = INSTANCE_CUSTOM.rg;
	// colores por vértice en sRGB (igual que vertex_color_is_srgb del StandardMaterial3D)
	if (!OUTPUT_IS_SRGB) {
		COLOR.rgb = to_linear(COLOR.rgb);
	}
}

void fragment() {
	vec4 clean = texture(tex_clean, UV);
	vec4 dirty = texture(tex_dirty, UV);
	vec3 t = mix(clean.rgb, dirty.rgb, v_custom.x);
	ALBEDO = t * COLOR.rgb;
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
	METALLIC = 0.1;
	EMISSION = glow_color * t * v_custom.y * 1.4;
}
