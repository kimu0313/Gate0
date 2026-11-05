shader_type spatial;
// The service corridors' walls (user: "복도 벽 텍스처 이걸로 해줘", a 256 px tile: concrete panels over a pale blue
// painted band with a dark foot). World space, so walls of any length join without seams: along a wall the texture
// repeats every `tile_w` metres; up it, the band sits on the floor (`base_height`) and the concrete above it runs up
// to `wall_h`, repeating its concrete part (no band) on anything taller. `with_band` off: only the concrete, repeating
// all the way up (the stairwell, whose floors are many). Horizontal faces (wall tops, door heads) take the concrete.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_w = 3.25;
uniform float wall_h = 3.25;
uniform float base_height = 0.0;
uniform float band_from = 0.735;     // where the band starts in the texture, from its top (v)
uniform bool with_band = true;
uniform vec3 tint = vec3(1.0);
uniform float roughness = 0.82;
uniform float band_roughness = 0.55; // the painted band is gloss paint

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(wnrm);
	float along = n.x > n.z ? wpos.z : wpos.x;
	if (n.y > 0.7) {
		along = wpos.x + wpos.z * 0.37;
	}
	float h = wpos.y - base_height;
	float band_h = (1.0 - band_from) * wall_h;
	float conc_h = band_from * wall_h;
	float v;
	float in_band = 0.0;
	if (with_band && h < band_h && n.y < 0.7) {
		v = band_from + (1.0 - band_from) * (1.0 - clamp(h / band_h, 0.0, 1.0));
		in_band = 1.0;
	} else {
		float t = with_band ? (h - band_h) / conc_h : h / conc_h;
		v = band_from * (1.0 - fract(t)) ;
		v = clamp(v, 0.004, band_from - 0.004);
	}
	vec2 uv = vec2(along / tile_w, v);
	// gradients from the continuous coordinates: the jumps in v (band / repeat) must not pick a blurry mip
	vec2 cont = vec2(along / tile_w, -h / wall_h);
	vec2 gx = dFdx(cont);
	vec2 gy = dFdy(cont);
	vec3 c = textureGrad(albedo_tex, uv, gx, gy).rgb * tint;
	ALBEDO = c;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	ROUGHNESS = mix(roughness, band_roughness, in_band) + (0.5 - lum) * 0.12;
	SPECULAR = 0.35;
}
