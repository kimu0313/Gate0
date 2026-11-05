extends SceneTree
## Synthesizes the lift's sounds (Lift; no Python on every machine, so this one is GDScript like gen_sfx_ball.gd):
##   lift_ding         the arrival chime: one soft struck bell (a fundamental, an inharmonic partial, a little shimmer)
##   lift_door         the car and landing doors sliding: a motor whirr rising and falling over the run, the rollers'
##                     rumble along the track, a soft rubber thud as they meet (or part)
##   lift_motor_loop   riding: the hoist motor's low hum and its drive's whine, a rush of air past the car, seamless
##   lift_jolt         the car taking up (or settling): a low thump and a creak of the cables
## Dry and close, like the other sources (the engine adds the room). Written to assets/audio/sfx; import them after:
##   godot --headless --path . --script res://tools/gen_sfx_lift.gd
##   godot --headless --path . --import

const SR := 44100
const OUT := "res://assets/audio/sfx/"


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4141
	_save("lift_ding", _ding())
	_save("lift_door", _door(rng))
	_save("lift_motor_loop", _motor(rng))
	_save("lift_jolt", _jolt(rng))
	quit()


func _ding() -> PackedFloat32Array:
	var n := int(SR * 2.2)
	var out := PackedFloat32Array()
	out.resize(n)
	# [frequency, amplitude, decay s]
	var partials := [[1046.5, 1.0, 0.9], [2093.0, 0.22, 0.45], [2730.0, 0.16, 0.3], [3920.0, 0.06, 0.18], [523.25, 0.12, 1.2]]
	for i in n:
		var s := float(i) / SR
		var v := 0.0
		for p: Array in partials:
			v += sin(TAU * p[0] * s) * p[1] * exp(-s / p[2])
		v *= 1.0 + 0.04 * sin(TAU * 5.0 * s)           # a slight beat in the bell
		out[i] = v * minf(1.0, s / 0.002)
	return _normalize(out, 0.6)


func _door(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var length := 1.6
	var n := int(SR * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var lp1 := 0.0
	var lp2 := 0.0
	var a := 1.0 - exp(-TAU * 180.0 / SR)
	for i in n:
		var s := float(i) / SR
		var run := clampf(s / 1.25, 0.0, 1.0)
		var env := sin(PI * run)                        # the doors speed up and slow down
		var f := 95.0 + 160.0 * env
		ph += TAU * f / SR
		var whirr := (sin(ph) + 0.35 * sin(ph * 2.0) + 0.15 * sin(ph * 3.01)) * env * 0.35
		lp1 += a * (rng.randf_range(-1.0, 1.0) - lp1)
		lp2 += a * (lp1 - lp2)
		var rumble := lp2 * 4.0 * (0.3 + env)
		out[i] = whirr + rumble
	# the leaves meeting: a soft thud at the end of the run
	var at := int(SR * 1.27)
	var ph2 := 0.0
	for j in int(SR * 0.25):
		if at + j >= n:
			break
		var s := float(j) / SR
		ph2 += TAU * (70.0 + 40.0 * exp(-s / 0.02)) / SR
		out[at + j] += sin(ph2) * exp(-s / 0.05) * 0.9
	for i in int(SR * 0.08):
		out[n - 1 - i] *= float(i) / (SR * 0.08)
	return _normalize(out, 0.7)


func _motor(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var length := 3.0
	var n := int(SR * length)
	var raw := PackedFloat32Array()
	raw.resize(n)
	var lp1 := 0.0
	var lp2 := 0.0
	var a := 1.0 - exp(-TAU * 420.0 / SR)
	for i in n:
		var s := float(i) / SR
		# hum and its harmonics, a drive whine — whole cycles in the loop so it joins
		var hum := sin(TAU * 60.0 * s) * 0.5 + sin(TAU * 120.0 * s) * 0.3 + sin(TAU * 180.0 * s) * 0.12
		var whine := sin(TAU * 1240.0 * s + 0.6 * sin(TAU * 2.0 * s)) * 0.035
		lp1 += a * (rng.randf_range(-1.0, 1.0) - lp1)
		lp2 += a * (lp1 - lp2)
		var air := lp2 * 2.2 * (0.85 + 0.15 * sin(TAU * s / length * 3.0))
		raw[i] = hum * 0.6 + whine + air
	var x := int(SR * 0.08)
	var out := raw.slice(0, n - x)
	for j in x:
		var w := float(j) / x
		out[j] = raw[j] * w + raw[n - x + j] * (1.0 - w)
	return _normalize(out, 0.5)


func _jolt(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(SR * 0.9)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var cr := 0.0
	var lp := 0.0
	for i in n:
		var s := float(i) / SR
		ph += TAU * (48.0 + 30.0 * exp(-s / 0.03)) / SR
		var thump := sin(ph) * exp(-s / 0.09)
		# a creak: a rough, slowly falling squeak after the thump
		var t2 := s - 0.12
		var creak := 0.0
		if t2 > 0.0:
			cr += TAU * (340.0 - 120.0 * t2) / SR
			lp += 0.3 * (rng.randf_range(-1.0, 1.0) - lp)
			creak = (sin(cr) + 0.6 * lp) * 0.12 * exp(-t2 / 0.22) * minf(1.0, t2 / 0.05)
		out[i] = thump + creak
	return _normalize(out, 0.8)


func _normalize(buf: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0
	for v in buf:
		m = maxf(m, absf(v))
	if m > 0.0:
		for i in buf.size():
			buf[i] = buf[i] / m * peak
	return buf


func _save(sound_name: String, buf: PackedFloat32Array) -> void:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = bytes
	var path := ProjectSettings.globalize_path(OUT + sound_name + ".wav")
	var err := w.save_to_wav(path)
	print("%s: %s (%.2f s)" % [sound_name, "ok" if err == OK else "error %d" % err, float(buf.size()) / SR])
