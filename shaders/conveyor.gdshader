shader_type spatial;
// Moving walkway / handrail surface. `offset` is advanced by script (metres), so speed changes stay smooth.

uniform vec3 color : source_color = vec3(0.34, 0.35, 0.37);
uniform vec3 groove_color : source_color = vec3(0.05, 0.05, 0.055);
uniform float offset = 0.0;
uniform float groove_spacing = 0.012;
uniform float pallet_length = 0.4;
uniform float metallic = 0.7;
uniform float roughness = 0.35;
uniform int axis = 2; // 0 = x, 2 = z (direction of travel in world space)

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float along = axis == 0 ? wpos.x : wpos.z;
	float across = axis == 0 ? wpos.z : wpos.x;
	float grooves = step(0.5, fract(across / groove_spacing));
	float pallet = fract((along + offset) / pallet_length);
	float seam = step(pallet, 0.03);
	vec3 col = mix(color, groove_color, grooves * 0.6);
	col = mix(col, groove_color * 0.5, seam);
	ALBEDO = col;
	METALLIC = metallic;
	ROUGHNESS = roughness + grooves * 0.2;
}
