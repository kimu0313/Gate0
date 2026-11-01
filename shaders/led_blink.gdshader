shader_type spatial;
render_mode unshaded, cull_back;
// Status LED on a server or a recorder: on most of the time, off for a moment each cycle (`rate` cycles a second,
// `phase` offset); rate 0 = steady. Colour per instance.

instance uniform vec3 led_color = vec3(0.2, 1.0, 0.45);
instance uniform float rate = 0.0;
instance uniform float phase = 0.0;

void fragment() {
	float on = rate > 0.0 ? step(0.3, fract(TIME * rate + phase)) : 1.0;
	ALBEDO = led_color * mix(0.12, 2.2, on);
}
