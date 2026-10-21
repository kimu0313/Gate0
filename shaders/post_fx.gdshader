shader_type canvas_item;
// Screen-space horror post effects: erosion (chromatic aberration, grain, glitch bands, desaturation,
// pulsing vignette), eyelids for the close-eyes mechanic, and full-screen flashes.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear;
uniform float erosion : hint_range(0.0, 1.0) = 0.0;
uniform float eyes : hint_range(0.0, 1.0) = 0.0;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color : source_color = vec3(1.0);
uniform float vignette = 0.32;
uniform float grain = 0.035;
uniform float desat = 0.0;
uniform float darken = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;
	// glitch bands
	float band = floor(uv.y * 36.0);
	float frame = floor(t * 14.0);
	float band_on = step(0.97 - erosion * 0.05, hash(vec2(band, frame)));
	float g = clamp(glitch + erosion * erosion * 0.25 * band_on, 0.0, 1.0);
	uv.x += (hash(vec2(band, frame + 7.0)) - 0.5) * 0.08 * g * band_on;
	uv.x += (hash(vec2(band * 3.1, frame)) - 0.5) * 0.03 * glitch;

	vec2 dir = uv - 0.5;
	float ca = 0.0012 + erosion * 0.006 + glitch * 0.012;
	vec3 col;
	col.r = texture(screen_tex, uv + dir * ca).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - dir * ca).b;

	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(l), clamp(desat + erosion * 0.4, 0.0, 1.0));

	float n = hash(uv * vec2(1931.0, 1087.0) + fract(t * 7.13) * 97.0);
	col += (n - 0.5) * (grain + erosion * 0.07 + glitch * 0.1);

	float r = length(dir * vec2(1.0, 0.85));
	float v = smoothstep(0.88, 0.28, r);
	float pulse = 1.0 - erosion * 0.18 * (0.5 + 0.5 * sin(t * 1.6));
	col *= mix(1.0 - vignette - erosion * 0.35, 1.0, v) * pulse;
	col *= 1.0 - darken;

	// eyelids
	float open_h = mix(0.75, -0.08, eyes);
	float curve = pow(abs(SCREEN_UV.x - 0.5) * 2.0, 2.0) * 0.12;
	float d = abs(SCREEN_UV.y - 0.5) + curve;
	float lid = 1.0 - smoothstep(open_h - 0.07, open_h + 0.02, d);
	col *= lid;
	col += vec3(0.025, 0.004, 0.004) * (1.0 - lid) * (1.0 - eyes * 0.6);

	col = mix(col, flash_color, flash);
	COLOR = vec4(col, 1.0);
}
