shader_type spatial;
// The shaft over the lounge's glass side (LoungeShaft): painted concrete (or its steel glazing frames) in world
// space, mottled, and darker the higher it is so the structure goes on up into black whatever the lighting.

uniform vec3 color : source_color = vec3(0.62, 0.62, 0.6);
uniform float roughness = 0.88;
uniform float metallic = 0.0;
uniform float stain = 0.2;       // mottling of the paint
uniform float y0 = 13.0;         // full colour up to here
uniform float fade = 30.0;       // then it falls off by e every `fade` metres

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = abs(wnrm.x) > 0.5 ? wpos.zy : (abs(wnrm.z) > 0.5 ? wpos.xy : wpos.xz);
	float n = vnoise(uv * vec2(0.45, 0.3)) * 0.6 + vnoise(uv * 2.1) * 0.4;
	float k = exp(-max(wpos.y - y0, 0.0) / fade);
	ALBEDO = color * mix(1.0 - stain, 1.0 + stain * 0.3, n) * k;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = 0.4 * k;
}
