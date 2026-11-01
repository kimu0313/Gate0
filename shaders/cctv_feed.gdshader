shader_type spatial;
render_mode unshaded, cull_back;
// CCTV monitor in the security office: `split` x `split` grey-green camera feeds, each a ceiling camera's view down
// a hall — floor tiles running to a vanishing point, side walls with doors, light panels across the ceiling, the far
// end lost in the dark — some cameras panning slowly, under grain, scanlines, a slow rolling bar, a vignette, an OSD
// line of camera text top left and a blinking REC dot. Tile `dead` is down: dark with faint snow, or full static
// with `snow`. Every screen runs on its own seed.

uniform float energy = 0.85;
uniform vec3 tint = vec3(0.74, 0.88, 0.84);
instance uniform float seed = 0.0;
instance uniform float split = 1.0;
instance uniform float dead = -1.0;
instance uniform float snow = 0.0;           // 1 = the dead tile shows static instead of going dark

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// fade a line pattern out where it gets finer than a pixel
float lines(float v, float w) {
	float f = abs(fract(v) - 0.5);
	float aa = fwidth(v) * 1.5;
	return smoothstep(0.5 - w - aa, 0.5 - w + aa, f) * (1.0 - smoothstep(0.15, 0.45, aa));
}

// one camera's view; q 0..1 (y up), s = the camera's own seed
float view(vec2 q, float s) {
	float hz = 0.56 + (hash(vec2(s, 1.3)) - 0.5) * 0.22;
	float pan = hash(vec2(s, 5.9)) < 0.35 ? sin(TIME * 0.06 + s * 9.0) * 0.08 : 0.0;
	float vx = 0.5 + (hash(vec2(s, 2.7)) - 0.5) * 0.55 + pan;
	float hw = 1.1 + hash(vec2(s, 4.1)) * 1.6;           // the hall's half-width, camera heights
	float ch = 0.7 + hash(vec2(s, 6.3)) * 0.5;           // the ceiling above the camera
	vec2 d = q - vec2(vx, hz);
	float lum;
	float depth;
	if (d.y < 0.0 && abs(d.x) < -d.y * hw) {
		// floor
		depth = 1.0 / max(-d.y, 0.002);
		float xw = d.x * depth;
		lum = 0.34 + 0.06 * hash(floor(vec2(xw * 1.6, depth * 1.6)) + s);
		lum -= 0.12 * max(lines(xw * 1.6, 0.47), lines(depth * 1.6, 0.47));
		lum += 0.12 * exp(-abs(xw) * 1.2) * (0.5 + 0.5 * cos(depth * 1.57));     // sheen under the lights
	} else if (d.y > 0.0 && abs(d.x) < d.y * hw / ch) {
		// ceiling, a light panel every four metres
		depth = ch / max(d.y, 0.002);
		float xw = d.x * depth;
		float panel = step(fract(depth * 0.25 + s), 0.12) * step(abs(xw), 0.35);
		lum = mix(0.24, 1.0, panel);
	} else {
		// walls, doors along them
		depth = hw / max(abs(d.x), 0.002);
		float h = d.y * depth;
		float door = step(fract(depth * 0.14 + s * 3.0), 0.1) * step(h, 0.35);
		lum = mix(0.42, 0.2, door) - 0.05 * lines(h * 2.0, 0.48);
		lum *= d.x > 0.0 ? 0.92 : 1.05;
	}
	lum = mix(lum, 0.07, smoothstep(3.0, 22.0, depth));
	return lum;
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float n = max(split, 1.0);
	vec2 cell = floor(uv * n);
	vec2 q = fract(uv * n);
	float idx = cell.x + (n - 1.0 - cell.y) * n;          // reading order, top left first
	float s = seed * 13.1 + idx * 7.3;
	bool down = abs(idx - dead) < 0.5;
	float lum;
	float rec = 0.0;
	if (down && snow > 0.5) {
		lum = 0.12 + 0.8 * hash(floor(q * vec2(200.0, 150.0)) + fract(floor(TIME * 30.0) * 0.137) * 91.0);
		lum *= 0.85 + 0.15 * sin(uv.y * 40.0 + TIME * 9.0);
	} else if (down) {
		lum = 0.03 + 0.05 * hash(floor(q * vec2(160.0, 90.0)) + floor(TIME * 24.0));
	} else {
		lum = view(q, s);
		lum *= 0.9 + 0.1 * sin(TIME * (0.7 + hash(vec2(s, 8.0))) + s);    // the auto gain breathing
		// OSD: a line of camera text top left
		vec2 c = floor(q * vec2(n > 1.5 ? 48.0 : 64.0, 40.0));
		float osd = step(36.0, c.y) * step(c.y, 36.0) * step(2.0, c.x) * step(c.x, 21.0);
		osd *= step(0.35, hash(vec2(c.x, s)));
		lum = mix(lum, 0.95, osd);
		lum += (hash(q * vec2(331.0, 247.0) + fract(TIME * 7.0)) - 0.5) * 0.09;      // grain
		rec = step(length((q - vec2(0.94, 0.9)) * vec2(1.6, 1.0)), 0.025) * step(0.5, fract(TIME * 0.5 + s));
	}
	vec3 col = mix(vec3(lum) * tint, vec3(0.9, 0.12, 0.08), rec);
	// scanlines, a slow rolling bar, the vignette of each tile, the seams between tiles
	col *= 0.9 + 0.1 * sin(UV.y * 900.0);
	col *= 1.0 - 0.1 * smoothstep(0.0, 0.06, 0.06 - abs(fract(uv.y * 0.5 - TIME * 0.035) - 0.5));
	vec2 v = q - 0.5;
	col *= 1.0 - dot(v, v) * 0.9;
	vec2 e = min(q, 1.0 - q) * n;
	col *= n > 1.5 ? smoothstep(0.004, 0.012, min(e.x, e.y)) : 1.0;
	ALBEDO = col * energy;
}
