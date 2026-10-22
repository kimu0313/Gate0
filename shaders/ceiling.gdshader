shader_type spatial;
// Acoustic ceiling tiles grid.

uniform vec3 color : source_color = vec3(0.72, 0.72, 0.71);
uniform vec3 grid_color : source_color = vec3(0.58, 0.58, 0.58);
uniform float tile = 0.6;
uniform float line = 0.012;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(269.5, 183.3))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz / tile;
	vec2 f = fract(p);
	float lw = line / tile;
	float g = max(max(step(f.x, lw), step(1.0 - lw, f.x)), max(step(f.y, lw), step(1.0 - lw, f.y)));
	float speck = hash(floor(wpos.xz * 60.0));
	vec3 col = color * (0.9 + 0.12 * hash(floor(p))) * (0.96 + 0.06 * speck);
	ALBEDO = mix(col, grid_color, g);
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
}
