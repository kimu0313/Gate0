shader_type spatial;
// Polished terminal floor: world-space tiles with terrazzo speckles and low roughness for SSR reflections.

uniform vec3 color_a : source_color = vec3(0.30, 0.31, 0.33);
uniform vec3 color_b : source_color = vec3(0.25, 0.26, 0.28);
uniform vec3 grout_color : source_color = vec3(0.13, 0.13, 0.14);
uniform vec3 accent_color : source_color = vec3(0.16, 0.20, 0.30);
uniform float tile_size = 1.2;
uniform float grout = 0.012;
uniform float roughness_base = 0.10;
uniform float roughness_var = 0.18;
uniform float accent_band = 0.0; // 1 = draw accent stripes every 7 tiles

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz / tile_size;
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	float gw = grout / tile_size;
	float g = max(max(step(f.x, gw), step(1.0 - gw, f.x)), max(step(f.y, gw), step(1.0 - gw, f.y)));
	float h = hash(cell);
	float n = noise(wpos.xz * 0.35) * 0.6 + noise(wpos.xz * 2.3) * 0.4;
	vec3 col = mix(color_a, color_b, h * 0.8);
	if (accent_band > 0.5 && mod(cell.x, 7.0) < 1.0) {
		col = mix(col, accent_color, 0.85);
	}
	col *= 0.88 + 0.24 * n;
	float sp = step(0.982, hash(floor(wpos.xz * 45.0)));
	col = mix(col, col * 1.7 + vec3(0.03), sp * 0.6);
	col = mix(col, grout_color, g);
	ALBEDO = col;
	float smudge = noise(wpos.xz * 0.6 + 13.0);
	ROUGHNESS = clamp(roughness_base + roughness_var * smudge * smudge + g * 0.5, 0.03, 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.55;
}
