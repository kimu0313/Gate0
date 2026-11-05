shader_type spatial;
// Cast-in-place concrete in world space (the security office's walls, columns, beams and slab; the Control concept
// art): soft mottling, formwork panel joints with their tie holes, faint streaks running down, fine pores; on the
// walls an optional painted dado band at the foot (`dado` m high, 0 = none) with a dark line along its top.

uniform vec3 color : source_color = vec3(0.6, 0.59, 0.565);
uniform vec3 dark : source_color = vec3(0.47, 0.465, 0.445);
uniform float panel_w = 2.4;
uniform float panel_h = 1.2;
uniform float joint = 0.007;
uniform float tie = 0.011;
uniform float roughness = 0.84;
uniform float dado = 0.0;
uniform vec3 dado_color : source_color = vec3(0.12, 0.19, 0.2);
uniform float base_height = 0.0;
// an optional photo of worn plaster (the security office's walls — user: "현재의 투톤 색상은 유지한 채 텍스처만 이렇게"):
// only its light and dark is used, so the walls keep their own colours and take on its cracks, patches and pitting;
// repeated mirror-wise every `detail_size` m so no seam shows
uniform bool use_detail = false;
uniform sampler2D detail_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 detail_size = vec2(2.4, 4.0);
uniform float detail_strength = 1.0;
uniform float detail_mean = 0.7;      // the photo's average lightness: what reads as the wall's own colour
uniform bool detail_horiz = false;    // on floors and ceilings too (the office ceiling's stone photo)

varying vec3 wpos;
varying vec3 wnrm;

// a hash with no sine in it: sin() of world-sized arguments times a big number gives each side of a cell edge a
// different value on the GPU, and the noise showed as hard-edged blocks
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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.1, 5.3);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	bool horiz = abs(wnrm.y) > 0.5;
	vec2 uv = horiz ? wpos.xz : vec2(abs(wnrm.x) > abs(wnrm.z) ? wpos.z : wpos.x, wpos.y - base_height);
	float m = fbm(uv * 0.32) * 0.72 + noise(uv * 1.9 + 7.0) * 0.28;
	float mottle = smoothstep(0.22, 0.82, m);
	if (use_detail) {
		mottle = mix(mottle, 0.85, 0.6);       // the photo carries the variation now
	}
	vec3 col = mix(dark, color, mottle);
	float rough = roughness;
	if (!horiz) {
		// water and dust streaks running down from the joints
		float s = noise(vec2(uv.x * 2.6, uv.y * 0.12 + 3.0));
		col *= 1.0 - 0.13 * smoothstep(0.58, 0.92, s);
	}
	// formwork panels: their joints, and four tie holes in each
	vec2 pp = uv / vec2(panel_w, panel_h);
	vec2 f = fract(pp) * vec2(panel_w, panel_h);
	float dj = min(min(f.x, panel_w - f.x), min(f.y, panel_h - f.y));
	if (joint > 0.0) {
		col *= mix(0.84, 1.0, smoothstep(joint * 0.4, joint, dj));
	}
	if (!horiz && tie > 0.0) {
		vec2 hq = vec2(panel_w, panel_h) * 0.25;
		float dh = length(abs(f - vec2(panel_w, panel_h) * 0.5) - hq);
		col *= mix(0.62, 1.0, smoothstep(tie * 0.6, tie, dh));
	}
	// pores
	col *= hash(floor(uv * 140.0)) > 0.992 ? 0.8 : 1.0;
	if (!horiz && dado > 0.0) {
		float y = wpos.y - base_height;
		if (y < dado) {
			col = dado_color * (0.9 + 0.12 * m);
			rough = 0.55;
		}
		col *= mix(0.55, 1.0, smoothstep(0.004, 0.012, abs(y - dado)));
	}
	if (use_detail && (!horiz || detail_horiz)) {
		vec2 q = abs(fract(uv / detail_size * 0.5) * 2.0 - 1.0);
		float l = dot(texture(detail_tex, vec2(q.x, 1.0 - q.y)).rgb, vec3(0.299, 0.587, 0.114));
		col *= mix(1.0, l / detail_mean, detail_strength);
		rough = clamp(rough + (detail_mean - l) * 0.5, 0.3, 1.0);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}
