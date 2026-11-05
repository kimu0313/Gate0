shader_type spatial;
// Black-and-white checkerboard vinyl tiles in world space (the security office; the Hitman Absolution police-station
// concept art): each tile a little off its neighbours, worn and dirty toward the edges of the room's traffic, scuffs,
// a soft sheen.

uniform vec3 white_tile : source_color = vec3(0.74, 0.73, 0.68);
uniform vec3 black_tile : source_color = vec3(0.07, 0.07, 0.075);
uniform vec3 dirt : source_color = vec3(0.3, 0.27, 0.2);
uniform float tile_size = 0.33;
uniform float grout = 0.0025;

varying vec3 wpos;

// no sine in the hash: see concrete.gdshader
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz / tile_size;
	vec2 cell = floor(uv);
	vec2 f = fract(uv);
	vec2 e = min(f, 1.0 - f);
	vec2 fw = fwidth(uv);
	vec2 gl = 1.0 - smoothstep(vec2(grout / tile_size) - fw, vec2(grout / tile_size) + fw, e);
	float g = max(gl.x, gl.y) * clamp(1.5 - max(fw.x, fw.y) * 6.0, 0.25, 1.0);
	float checker = mod(cell.x + cell.y, 2.0);
	float h = hash(cell);
	vec3 col = mix(white_tile, black_tile, checker) * (0.9 + 0.16 * h);
	// grime: broad patches, darker in the joints and near tile edges, scuffs
	float n = noise(wpos.xz * 0.45) * 0.6 + noise(wpos.xz * 2.7 + 5.0) * 0.4;
	float grime = smoothstep(0.35, 0.95, n);
	col = mix(col, col * 0.55 + dirt * 0.25, grime * (checker > 0.5 ? 0.25 : 0.6));
	float edge = 1.0 - smoothstep(0.0, 0.08, min(e.x, e.y));
	col = mix(col, col * 0.7 + dirt * 0.1, edge * 0.35);
	float scuff = step(0.993, hash(floor(wpos.xz * vec2(9.0, 60.0)) + 3.1));
	col = mix(col, vec3(0.05), scuff * 0.4 * (1.0 - checker));
	col = mix(col, dirt * 0.35, g);
	ALBEDO = col;
	float smudge = noise(wpos.xz * 0.9 + 13.0);
	ROUGHNESS = clamp(0.28 + 0.35 * smudge + grime * 0.25 + g * 0.5, 0.1, 1.0);
	SPECULAR = 0.5;
}
