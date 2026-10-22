// Cielo de Misión Energía: gradiente día/atardecer/noche, sol, luna, estrellas, nubes y bruma del Zonda.
// Port del shader del cielo de app/src/world/assets/Environment.ts. Colores en espacio lineal.
// En la pasada de radiancia (luz ambiente) sólo dibuja el gradiente cielo/suelo: equivale a la
// HemisphereLight de la versión web y no cambia con estrellas ni nubes.
shader_type sky;

uniform vec3 top_color = vec3(0.045, 0.27, 0.75);
uniform vec3 horizon_color = vec3(0.6, 0.8, 0.86);
uniform vec3 ground_color = vec3(0.45, 0.35, 0.2);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color = vec3(1.0, 0.9, 0.7);
uniform vec3 moon_dir = vec3(0.0, 1.0, 0.0);
uniform float night = 0.0;
uniform float clouds = 0.0;
uniform float zonda = 0.0;
uniform float cloud_time = 0.0;
uniform float sun_vis = 1.0;
uniform float stars = 0.0;
uniform vec3 haze_color = vec3(0.57, 0.33, 0.12);
uniform vec3 cloud_lit = vec3(1.0);
uniform vec3 cloud_shade = vec3(0.4, 0.47, 0.6);
// Luz ambiente (pasada de radiancia): color de cielo y de suelo de la "hemisférica".
uniform vec3 amb_sky = vec3(0.5, 0.6, 0.7);
uniform vec3 amb_ground = vec3(0.3, 0.2, 0.12);
// GL Compatibility interpreta el COLOR del cielo como sRGB (fondo y radiancia). Medido en 4.7.2: sin esto
// el cielo y la luz ambiente salen ~4 veces más oscuros. EnvironmentRig lo activa según el renderer.
uniform bool encode_srgb = false;

vec3 encode(vec3 c) {
	if (!encode_srgb) {
		return c;
	}
	c = max(c, vec3(0.0));
	return mix(1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, c * 12.92, lessThan(c, vec3(0.0031308)));
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float hash13(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.zyx + 31.32);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), f.x), mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

float star_field(vec3 d) {
	// celdas 3D sobre la esfera: una estrella posible por celda
	vec3 p = d * 140.0;
	vec3 cell = floor(p);
	float h = hash13(cell);
	if (h > 0.03) {
		return 0.0;
	}
	vec3 sp = cell + vec3(hash13(cell + 11.1), hash13(cell + 23.7), hash13(cell + 37.3));
	float dist = length(p - sp);
	float tw = 0.75 + 0.25 * hash13(cell + 5.0);
	return smoothstep(0.16, 0.035, dist) * tw * (h < 0.006 ? 1.6 : 1.0);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float h = d.y;
	if (AT_CUBEMAP_PASS) {
		// Luz ambiente: gradiente suave cielo/suelo (HemisphereLight)
		COLOR = encode(mix(amb_ground, amb_sky, smoothstep(-0.6, 0.6, h)));
	} else {
		float t = pow(clamp(h, 0.0, 1.0), 0.5);
		vec3 col = mix(horizon_color, top_color, t);
		col = mix(col, ground_color, smoothstep(0.0, -0.1, h));
		float sd = max(dot(d, sun_dir), 0.0);
		col += sun_color * (pow(sd, 5.0) * 0.18 + pow(sd, 40.0) * 0.3) * (1.0 - zonda * 0.4);
		col += sun_color * smoothstep(0.99935, 0.99965, sd) * 5.0 * sun_vis * (1.0 - clouds * 0.75) * (1.0 - zonda * 0.85);
		float md = dot(d, moon_dir);
		float moon_disc = smoothstep(0.99945, 0.9997, md);
		// fase: sombra desplazada sobre el disco
		float moon_shadow = smoothstep(0.99955, 0.9998, dot(d, normalize(moon_dir + vec3(0.012, 0.004, 0.0))));
		col += vec3(0.9, 0.92, 1.0) * moon_disc * (1.0 - moon_shadow * 0.85) * 2.4 * night * (1.0 - clouds * 0.8) * (1.0 - zonda);
		col += vec3(0.25, 0.3, 0.45) * pow(max(md, 0.0), 30.0) * 0.35 * night;
		if (stars > 0.01 && h > 0.0) {
			col += vec3(0.95, 0.97, 1.0) * star_field(d) * stars * smoothstep(0.0, 0.12, h) * 1.6;
		}
		if (h > 0.0 && clouds > 0.01) {
			vec2 uv = d.xz / (h + 0.18) * 1.1 + vec2(cloud_time * 0.008, cloud_time * 0.003);
			float n = fbm(uv);
			float th = 0.72 - 0.34 * clouds;
			float cover = smoothstep(th, th + 0.18, n) * smoothstep(0.0, 0.1, h) * smoothstep(0.0, 0.15, clouds);
			vec3 cc = mix(cloud_shade, cloud_lit, clamp((n - th) * 3.0, 0.0, 1.0) * 0.5 + sd * 0.5);
			col = mix(col, cc, cover * 0.92);
		}
		col = mix(col, haze_color, zonda * (0.6 + 0.35 * (1.0 - t)));
		COLOR = encode(col);
	}
}
