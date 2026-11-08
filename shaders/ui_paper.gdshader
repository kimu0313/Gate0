shader_type canvas_item;
// An aged sheet of paper (GuideView): off-white, mottled, yellower toward its edges, grain, specks and foxing, a
// faint fold across it, its very edge a hair darker.

uniform vec2 px = vec2(650.0, 830.0);         // the sheet's size in pixels
uniform vec4 base : source_color = vec4(0.87, 0.85, 0.79, 1.0);
uniform float seed = 0.0;
uniform float crease = 0.0;                    // a fold across the sheet at this share of its height (0: none)

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.7);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 q = UV * px;
	vec2 p = q + vec2(seed * 137.0, seed * 59.0);
	vec3 col = base.rgb * (0.92 + 0.11 * fbm(p * 0.01));
	// yellowing toward the edges, unevenly
	vec2 e = min(q, px - q);
	float edge = 1.0 - smoothstep(0.0, 80.0, min(e.x, e.y) + (fbm(p * 0.025) - 0.5) * 50.0);
	col = mix(col, col * vec3(0.93, 0.85, 0.7), edge * 0.55);
	// grain, specks, foxing
	col *= 0.975 + 0.05 * hash(floor(p));
	col *= 1.0 - 0.14 * step(0.9993, hash(floor(p * 0.6) + 7.0));
	col *= mix(vec3(1.0), vec3(0.95, 0.91, 0.84), smoothstep(0.66, 0.75, fbm(p * 0.02 + 11.0)));
	// the fold
	if (crease > 0.0) {
		float cy = q.y - crease * px.y;
		col *= 1.0 - 0.07 * exp(-abs(cy) / 1.6) - 0.025 * exp(-abs(cy) / 14.0);
		col += vec3(0.02) * exp(-abs(cy + 3.0) / 2.5);
	}
	// the cut edge
	col *= 1.0 - 0.14 * (1.0 - smoothstep(0.0, 2.0, min(e.x, e.y)));
	COLOR = vec4(col, COLOR.a);
}
