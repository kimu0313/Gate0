shader_type spatial;
// Large wall cladding panels in world space (works on X- and Z-facing walls).

uniform vec3 color : source_color = vec3(0.62, 0.60, 0.56);
uniform vec3 seam_color : source_color = vec3(0.28, 0.27, 0.26);
uniform float panel_w = 1.5;
uniform float panel_h = 2.4;
uniform float seam = 0.008;
uniform float roughness = 0.55;
uniform float base_height = 0.0;
uniform vec3 skirting_color : source_color = vec3(0.12, 0.12, 0.13);
uniform float skirting = 0.12;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float u = abs(wnrm.x) > abs(wnrm.z) ? wpos.z : wpos.x;
	vec2 p = vec2(u / panel_w, (wpos.y - base_height) / panel_h);
	vec2 f = fract(p);
	vec2 cell = floor(p);
	float sw = seam / panel_w;
	float sh = seam / panel_h;
	float s = max(max(step(f.x, sw), step(1.0 - sw, f.x)), max(step(f.y, sh), step(1.0 - sh, f.y)));
	vec3 col = color * (0.94 + 0.08 * hash(cell));
	col = mix(col, seam_color, s * 0.8);
	float sk = step(wpos.y, skirting);
	if (abs(wnrm.y) > 0.5) {
		sk = 0.0;
		s = 0.0;
	}
	col = mix(col, skirting_color, sk);
	ALBEDO = col;
	ROUGHNESS = mix(roughness, 0.4, sk);
	SPECULAR = 0.4;
}
