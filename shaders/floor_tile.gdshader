shader_type spatial;
// Polished terminal floor: world-space tiles with terrazzo speckles and low roughness for SSR reflections.

uniform vec3 color_a : source_color = vec3(0.56, 0.55, 0.52);
uniform vec3 color_b : source_color = vec3(0.50, 0.49, 0.47);
uniform vec3 grout_color : source_color = vec3(0.38, 0.38, 0.37);
uniform vec3 accent_color : source_color = vec3(0.12, 0.17, 0.32);
uniform float tile_size = 1.2;
uniform float grout = 0.006;
uniform float roughness_base = 0.10;
uniform float roughness_var = 0.18;
uniform float accent_band = 0.0; // 1 = draw accent stripes every 7 tiles
uniform float dark_share = 0.0;  // share of tiles laid in the dark stone (lounge floor), scattered
uniform vec3 dark_color : source_color = vec3(0.13, 0.135, 0.14);

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
	// joints: anti-aliased thin lines (hard steps shimmer and read as a CG grid at a distance)
	vec2 e = min(f, 1.0 - f);
	vec2 fw = fwidth(uv);
	vec2 gl = 1.0 - smoothstep(vec2(grout / tile_size) - fw, vec2(grout / tile_size) + fw, e);
	float g = max(gl.x, gl.y) * clamp(1.5 - max(fw.x, fw.y) * 6.0, 0.25, 1.0);
	float h = hash(cell);
	float n = noise(wpos.xz * 0.35) * 0.6 + noise(wpos.xz * 2.3) * 0.4;
	vec3 col = mix(color_a, color_b, h * 0.8);
	if (accent_band > 0.5 && mod(cell.x, 7.0) < 1.0) {
		col = mix(col, accent_color, 0.85);
	}
	// dark stone: single tiles and the odd pair along x, picked per tile so the pattern never repeats
	float dk = max(step(1.0 - dark_share, hash(cell + 17.3)), step(1.0 - dark_share * 0.5, hash(floor(vec2(cell.x * 0.5, cell.y)) + 41.9)));
	col = mix(col, dark_color * (0.9 + 0.2 * h), dk * step(0.001, dark_share));
	col *= 0.93 + 0.14 * n;
	float sp = step(0.988, hash(floor(wpos.xz * 45.0)));
	col = mix(col, col * 1.35 + vec3(0.02), sp * 0.5);
	col = mix(col, grout_color, g);
	ALBEDO = col;
	float smudge = noise(wpos.xz * 0.6 + 13.0);
	ROUGHNESS = clamp(roughness_base + roughness_var * smudge * smudge + g * 0.5, 0.03, 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.55;
}
