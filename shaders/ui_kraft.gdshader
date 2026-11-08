shader_type canvas_item;
// A worn kraft file folder lying open (GuideView): its outline — the two covers and the back cover's tab above them,
// the edges a little frayed —, mottled card with fibres and specks, lighter worn edges, a ring stain and a blot, and
// the crease down the fold.

uniform vec2 px = vec2(1490.0, 908.0);        // the rect's size in pixels
uniform float top = 26.0;                      // where the covers begin (the tab stands above it)
uniform vec2 tab = vec2(1040.0, 1320.0);       // the tab's x span
uniform float fold = 738.0;                    // the crease
uniform vec2 ring = vec2(1250.0, 790.0);       // a cup's ring stain
uniform vec4 base : source_color = vec4(0.6, 0.48, 0.34, 1.0);

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

float sd_box(vec2 p, vec2 a, vec2 b, float r) {
	vec2 c = (a + b) * 0.5;
	vec2 h = (b - a) * 0.5 - vec2(r);
	vec2 d = abs(p - c) - h;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * px;
	float d = sd_box(p, vec2(1.5, top), px - vec2(1.5), 9.0);
	d = min(d, sd_box(p, vec2(tab.x, 1.5), vec2(tab.y, top + 14.0), 10.0));
	d += (fbm(p * 0.09) - 0.5) * 2.6;                                   // frayed edges
	float alpha = clamp(0.5 - d, 0.0, 1.0);
	// the card: mottled, fibres along its grain, specks
	vec3 col = base.rgb * (0.84 + 0.28 * fbm(p * 0.006));
	col *= 0.95 + 0.07 * vnoise(vec2(p.x * 0.03, p.y * 0.8));
	col *= 1.0 - 0.28 * step(0.9965, hash(floor(p * 0.5)));
	col *= 1.0 + 0.12 * step(0.998, hash(floor(p * 0.5) + 3.0));
	// worn edges, lighter where the card has been handled
	float edge = smoothstep(-24.0, 0.0, d) * (0.4 + 0.9 * fbm(p * 0.04));
	col = mix(col, col * 1.16 + vec3(0.05, 0.045, 0.035), clamp(edge, 0.0, 1.0) * 0.7);
	// a cup's ring and a blot
	float r1 = length(p - ring);
	col *= 1.0 - 0.13 * smoothstep(7.0, 0.0, abs(r1 - 58.0)) * (0.4 + fbm(p * 0.05)) - 0.04 * smoothstep(60.0, 30.0, r1);
	col *= 1.0 - 0.1 * smoothstep(0.64, 0.74, fbm(p * 0.011 + 3.0));
	// the crease: a dark valley down the fold, the light falling off toward it from both covers, its lip catching it
	float fx = abs(p.x - fold);
	col *= 1.0 - 0.34 * exp(-fx / 3.0) - 0.16 * exp(-fx / 64.0);
	col += vec3(0.035) * exp(-abs(p.x - fold - 5.0) / 2.0);
	COLOR = vec4(col, alpha * COLOR.a);
}
