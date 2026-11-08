shader_type canvas_item;
// A black-and-white print (GuideView's photographs, made from in-game shots): desaturated with a little more
// contrast, a faintly warm paper tone, film grain, a vignette, a few scratches and a faded patch.

uniform float seed = 0.0;
uniform vec2 px = vec2(640.0, 452.0);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	l = pow(l, 0.8);
	l = clamp((l - 0.45) * 1.3 + 0.47, 0.0, 1.0);
	vec2 q = UV * px;
	l += (hash(floor(q) + seed) - 0.5) * 0.12;
	float v = length((UV - 0.5) * vec2(1.0, 0.85));
	l *= 1.0 - smoothstep(0.3, 0.78, v) * 0.55;
	float sx = hash(vec2(floor(q.x / 2.0), seed));
	l += step(0.996, sx) * 0.18 * vnoise(vec2(q.x, q.y * 0.03));
	l = mix(l, 0.72, 0.16 * smoothstep(0.55, 0.85, vnoise(UV * 3.0 + seed)));
	COLOR = vec4(vec3(l) * vec3(1.0, 0.975, 0.93), COLOR.a);
}
