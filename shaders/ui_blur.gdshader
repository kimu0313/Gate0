shader_type canvas_item;
// Modal backdrop: blurred, darkened copy of the screen behind tablets, binders and menus.
// `amount` animates the whole effect in and out (0 = untouched screen).

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float lod : hint_range(0.0, 6.0) = 2.6;
uniform vec4 tint : source_color = vec4(0.02, 0.025, 0.035, 0.55);
uniform float amount : hint_range(0.0, 1.0) = 1.0;
uniform float vignette = 0.45;

void fragment() {
	vec2 uv = SCREEN_UV;
	float l = lod * amount;
	vec2 px = SCREEN_PIXEL_SIZE * exp2(l) * 0.75;
	vec3 c = textureLod(screen_tex, uv, l).rgb * 0.4;
	c += textureLod(screen_tex, uv + vec2(px.x, px.y), l).rgb * 0.15;
	c += textureLod(screen_tex, uv + vec2(-px.x, px.y), l).rgb * 0.15;
	c += textureLod(screen_tex, uv + vec2(px.x, -px.y), l).rgb * 0.15;
	c += textureLod(screen_tex, uv + vec2(-px.x, -px.y), l).rgb * 0.15;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(lum), 0.35 * amount);
	c = mix(c, tint.rgb, tint.a * amount);
	vec2 d = uv - 0.5;
	c *= 1.0 - dot(d, d) * vignette * amount * 1.6;
	COLOR = vec4(c, 1.0);
}
