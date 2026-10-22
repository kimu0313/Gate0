shader_type spatial;
// Gate-lounge carpet: dark patterned fibres, fully rough.

uniform vec3 base_color : source_color = vec3(0.19, 0.2, 0.23);
uniform vec3 pattern_color : source_color = vec3(0.25, 0.23, 0.26);
uniform float pattern_scale = 0.8;

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743);
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
	vec2 p = wpos.xz * pattern_scale;
	vec2 c = fract(p) - 0.5;
	float diamond = step(abs(c.x) + abs(c.y), 0.18);
	float fibre = hash(floor(wpos.xz * 220.0));
	float blot = noise(wpos.xz * 0.25);
	vec3 col = mix(base_color, pattern_color, diamond);
	col *= 0.85 + 0.25 * fibre + 0.2 * (blot - 0.5);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
