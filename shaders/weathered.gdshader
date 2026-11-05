shader_type spatial;
// Weathered surfaces in the security office — its light fittings' metal and its old computers' yellowed plastic (user,
// with photos of an old industrial fitting and an old beige PC: "질감도 현실적으로", "컴퓨터 텍스처도 참고해줘"): a base
// colour broken by patches (`rust`: rust on metal, yellowing on plastic) and dark grime from world-space noise, and on
// brushed parts fine streaks along the part's own long axis (mesh-local x). The hash has no sin() (it banded at world
// sizes).

uniform vec3 base_color : source_color = vec3(0.1, 0.09, 0.08);
uniform vec3 rust_color : source_color = vec3(0.3, 0.15, 0.07);
uniform vec3 grime_color : source_color = vec3(0.04, 0.036, 0.032);
uniform float metallic = 0.6;
uniform float roughness = 0.55;
uniform float rust = 0.35;       // 0 none .. 1 most of it
uniform float grime = 0.4;
uniform float scale = 9.0;       // noise cells per metre
uniform float brushed = 0.0;     // streaks along mesh-local x
uniform float scratches = 0.0;   // thin bright scratches through the paint (0 none .. 1 many)
uniform float runs = 0.0;        // rust patches drawn out downward, like runs (0 round .. 1 long)
uniform vec3 scratch_color : source_color = vec3(0.72, 0.73, 0.72);
// The noise in the mesh's own space (plus a per-instance seed) instead of world space: the service corridors' doors
// (far from the origin, where this hash showed blocks; and the stair lobby's two copies must look the same).
uniform bool local_space = false;
instance uniform vec3 noise_seed = vec3(0.0);

varying vec3 wpos;
varying vec3 lpos;

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y);
	float b = mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y);
	return mix(a, b, f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int k = 0; k < 4; k++) {
		v += vnoise(p) * amp;
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		amp *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lpos = VERTEX;
}

void fragment() {
	vec3 P = local_space ? lpos + noise_seed : wpos;
	vec3 rp = P * scale * vec3(1.0, 1.0 - 0.8 * runs, 1.0);
	float n = fbm(rp);
	float n2 = fbm(P * scale * 3.1 + vec3(11.3, 4.7, 2.9));
	float r = smoothstep(1.0 - rust * 0.55, 1.0 - rust * 0.55 + 0.18, n + n2 * 0.25);
	float g = smoothstep(0.35, 0.85, n2) * grime;
	vec3 col = mix(base_color, rust_color, r);
	col = mix(col, grime_color, g);
	// the fine detail fades out once a pixel covers it, so it never shimmers in the distance
	float px = length(fwidth(wpos));
	float streak = (vnoise(vec3(lpos.x * 3.0, lpos.y * 600.0, lpos.z * 600.0)) - 0.5) * brushed
			* (1.0 - smoothstep(0.0008, 0.003, px));
	col *= 1.0 + streak * 0.25;
	float sc = 0.0;
	if (scratches > 0.0 && px < 0.006) {
		float cluster = smoothstep(0.45, 0.75, fbm(P * 2.3 + vec3(5.1, 1.3, 7.7)));
		float s1 = smoothstep(0.86, 0.95, vnoise(vec3(P.x * 140.0, P.y * 9.0, P.z * 140.0)));
		float s2 = smoothstep(0.88, 0.96, vnoise(vec3((P.x + P.z) * 11.0, P.y * 150.0, (P.x - P.z) * 11.0)));
		sc = max(s1, s2) * cluster * scratches * (1.0 - r) * (1.0 - smoothstep(0.002, 0.006, px));
		col = mix(col, scratch_color, sc * 0.7);
	}
	ALBEDO = col;
	METALLIC = mix(mix(metallic, 0.05, r), 0.9, sc);
	ROUGHNESS = clamp(mix(roughness, 0.92, r) + g * 0.18 + streak * 0.12 - sc * 0.3, 0.05, 1.0);
}
