shader_type spatial;
// An airliner's paint, drawn from the hull's own coordinates (Airliner: UV = (metres back from the nose, angle round
// the body, 0 = its right side), UV2 = (height over the section's centre, height over the ground)): a white body with
// a grey belly, a deep red cheatline with a gold pinstripe under the windows, dark cabin and upper-deck windows, door
// outlines, the cockpit glazing wrapping round the front of the hump, a grey radome and a dark tail exhaust.

uniform vec3 body : source_color = vec3(0.86, 0.87, 0.85);
uniform vec3 belly : source_color = vec3(0.6, 0.62, 0.62);
uniform vec3 band : source_color = vec3(0.44, 0.06, 0.07);
uniform vec3 gold : source_color = vec3(0.68, 0.52, 0.22);
uniform vec3 glass : source_color = vec3(0.045, 0.055, 0.06);
uniform vec3 outline : source_color = vec3(0.5, 0.51, 0.5);
uniform float win_h = -0.02;        // cabin window row centre over the section centre
uniform float win_pitch = 1.0;
uniform float win_z0 = 8.6;
uniform float win_z1 = 44.0;
uniform float up_h = 3.82;          // upper-deck windows (in the hump)
uniform float up_z0 = 8.2;
uniform float up_z1 = 17.0;
uniform vec4 doors = vec4(6.4, 14.0, 25.5, 34.0);
uniform float door_h0 = -1.2;
uniform float door_h1 = 0.73;
uniform float door_w = 1.07;
uniform float cockpit_y0 = 7.28;    // cockpit glazing band (height over the ground)
uniform float cockpit_y1 = 7.72;
uniform float cockpit_z0 = 2.2;
uniform float cockpit_z1 = 5.6;
uniform float length_z = 54.0;

varying vec2 zt;
varying vec2 hy;

void vertex() {
	zt = UV;
	hy = UV2;
}

float rrect(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - half_size + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float near_door(float z, float pad) {
	float d = 1e3;
	for (int i = 0; i < 4; i++) {
		d = min(d, abs(z - doors[i]));
	}
	return step(d, door_w * 0.5 + pad);
}

void fragment() {
	float z = zt.x;
	float th = zt.y;
	float c = cos(th);
	float s = sin(th);
	float h = hy.x;
	float y = hy.y;
	vec3 col = body;
	float rough = 0.3;
	// belly
	col = mix(col, belly, smoothstep(-0.6, -0.72, s));
	// radome and the tail exhaust
	col = mix(col, vec3(0.7, 0.71, 0.7), step(z, 1.5));
	// cheatline under the windows, from behind the radome to the tail cone
	if (z > 2.3 && z < 45.5) {
		float b = step(win_h - 0.84, h) * step(h, win_h - 0.36);
		float g = step(win_h - 0.99, h) * step(h, win_h - 0.92);
		col = mix(col, band, b);
		col = mix(col, gold, g);
		rough = mix(rough, 0.38, b);
	}
	// cabin windows down both sides (none at a door)
	if (abs(c) > 0.5 && z > win_z0 && z < win_z1 && near_door(z, 0.3) < 0.5) {
		float k = mod(z - win_z0, win_pitch) - win_pitch * 0.5;
		float d = rrect(vec2(k, h - win_h), vec2(0.13, 0.19), 0.1);
		float w = 1.0 - smoothstep(-0.006, 0.006, d);
		col = mix(col, glass, w);
		rough = mix(rough, 0.08, w);
	}
	// upper-deck windows in the hump
	if (abs(c) > 0.2 && s > 0.4 && z > up_z0 && z < up_z1) {
		float k = mod(z - up_z0, win_pitch) - win_pitch * 0.5;
		float d = rrect(vec2(k, h - up_h), vec2(0.12, 0.17), 0.09);
		float w = 1.0 - smoothstep(-0.006, 0.006, d);
		col = mix(col, glass, w);
		rough = mix(rough, 0.08, w);
	}
	// door outlines
	if (abs(c) > 0.45) {
		for (int i = 0; i < 4; i++) {
			float d = rrect(vec2(z - doors[i], h - (door_h0 + door_h1) * 0.5), vec2(door_w * 0.5, (door_h1 - door_h0) * 0.5), 0.14);
			col = mix(col, outline, (1.0 - smoothstep(0.012, 0.022, abs(d))));
		}
	}
	// cockpit glazing: a band at one height round the front of the hump, split by its frames
	if (z > cockpit_z0 && z < cockpit_z1 && s > 0.15 && y > cockpit_y0 && y < cockpit_y1) {
		float a = abs(th - 1.5708);
		float post = 0.0;
		for (int i = 0; i < 4; i++) {
			post = max(post, 1.0 - smoothstep(0.012, 0.03, abs(a - float(i) * 0.3)));
		}
		col = mix(glass, body * 0.8, post);
		rough = mix(0.06, 0.3, post);
	}
	col = mix(col, vec3(0.12, 0.12, 0.13), step(length_z - 0.35, z));
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = 0.05;
	SPECULAR = 0.55;
}
