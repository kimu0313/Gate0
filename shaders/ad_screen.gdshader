shader_type spatial;
render_mode unshaded, cull_back;
// Digital advertising screen on the lounge columns (the reference's blue column screens): a slow airline ad with
// no text — night-blue sky over a cloud sea, high cloud bands, a plane climbing across — that crossfades between
// two variants. Every screen runs on its own clock (instance seed), so they never change together.

uniform sampler2D plane_tex : source_color, filter_linear_mipmap;
uniform float energy = 1.25;
instance uniform float seed = 0.0;

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

float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) {
		s += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

// uv: x 0..1 left to right, y 0..1 bottom to top; k = variant (0 deep night blue, 1 paler high-altitude blue)
vec3 sky(vec2 uv, float t, float k) {
	vec3 top = mix(vec3(0.006, 0.02, 0.11), vec3(0.012, 0.05, 0.2), k);
	vec3 hor = mix(vec3(0.1, 0.27, 0.72), vec3(0.2, 0.42, 0.85), k);
	vec3 col = mix(hor, top, smoothstep(0.2, 0.95, uv.y));
	float c = fbm(vec2(uv.x * 3.0 + t * 0.02, uv.y * 7.0) + seed * 7.0 + k * 5.0);
	float sea = smoothstep(0.4, 0.1, uv.y) * smoothstep(0.38, 0.66, c);
	col = mix(col, vec3(0.42, 0.58, 0.92), sea * 0.8);
	float bands = smoothstep(0.55, 0.8, fbm(vec2(uv.x * 2.0 - t * 0.015, uv.y * 15.0) + seed * 3.0 + k));
	col += vec3(0.1, 0.16, 0.32) * bands * smoothstep(0.4, 0.95, uv.y) * 0.6;
	return col;
}

// the pictogram plane (nose up-right) flying along its nose, `phase` 0..1 across the screen
vec4 plane(vec2 uv, float phase, float scale) {
	vec2 at = vec2(-0.25, 0.08) + vec2(1.3, 0.75) * phase;
	vec2 q = (uv - at) / vec2(scale, scale * 0.5) + 0.5;   // the screen is twice as tall as it is wide
	if (q.x < 0.0 || q.x > 1.0 || q.y < 0.0 || q.y > 1.0) {
		return vec4(0.0);
	}
	return texture(plane_tex, vec2(q.x, 1.0 - q.y));
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float t = TIME + seed * 37.0;
	float cyc = mod(t, 18.0) / 18.0;
	float k = smoothstep(0.45, 0.55, cyc);                          // variant crossfade halfway
	vec3 col = mix(sky(uv, t, 0.0), sky(uv, t, 1.0), k);
	vec4 p = plane(uv, fract(t / 9.0), mix(0.55, 0.38, k));
	col = mix(col, vec3(0.82, 0.88, 1.0), p.a * 0.9);
	// bottom bar (the advertiser's strip), a brief dip to black at each change, the LED pixel grid
	col = mix(col, vec3(0.02, 0.06, 0.18), step(uv.y, 0.07) * 0.85);
	col *= 1.0 - 0.85 * (1.0 - smoothstep(0.0, 0.012, abs(cyc - 0.5))) - 0.85 * (1.0 - smoothstep(0.0, 0.012, min(cyc, 1.0 - cyc)));
	vec2 g = abs(fract(uv * vec2(96.0, 192.0)) - 0.5);
	col *= 0.93 + 0.07 * smoothstep(0.5, 0.35, max(g.x, g.y));
	ALBEDO = col * energy;
}
