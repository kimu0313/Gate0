extends SceneTree
## Synthesizes the lift's sounds (Lift; no Python on every machine, so this one is GDScript like gen_sfx_ball.gd):
##   lift_ding         the arrival chime: one soft struck bell (a fundamental, an inharmonic partial, a little shimmer)
##   lift_door         the car and landing doors sliding: a motor whirr rising and falling over the run, the rollers'
##                     rumble along the track, a soft rubber thud as they meet (or part)
##   lift_motor_loop   riding: the hoist motor's low hum and its drive's whine, a rush of air past the car, seamless
##   lift_jolt         the car taking up (or settling): a low thump and a creak of the cables
##   lift_siren_loop   the breakdown's alarm: a hard wailing tone (Shift1)
##   lift_shake_loop   the car shaking in its guides: rumble, cable thrum, metal knocks and rattles
##   lift_bang         the bang the breakdown starts with
##   lift_brake        the emergency brake: a jittering squeal over grinding, then the slam to a stop
##   lift_latch        the escape box's stiff latch giving a quarter of a turn
##   lift_lever        the escape lever: a ratchet, then a heavy clunk
##   lift_fall         nobody pulled it: a cable snapping, the car falling
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
	# the breakdown (Shift1, 2026-11-08): the alarm, the car shaking, the bang it starts with, the emergency brake,
	# the escape box's stiff latch and its lever, the fall when nobody pulls it
	_save("lift_siren_loop", _siren())
	_save("lift_shake_loop", _shake(rng))
	_save("lift_bang", _bang(rng))
	_save("lift_brake", _brake(rng))
	_save("lift_latch", _latch(rng))
	_save("lift_lever", _lever(rng))
	_save("lift_fall", _fall(rng))
	quit()


## A wailing alarm: a hard, slightly clipped tone sweeping up and down every second and a half, seamless.
func _siren() -> PackedFloat32Array:
	var length := 3.0
	var n := int(SR * length)
	var raw := PackedFloat32Array()
	raw.resize(n)
	var ph := 0.0
	for i in n:
		var s := float(i) / SR
		var f := 980.0 + 420.0 * sin(TAU * s / 1.5 - PI / 2)
		ph += TAU * f / SR
		var v := sin(ph) + 0.33 * sin(ph * 3.0) + 0.18 * sin(ph * 5.0) + 0.1 * sin(ph * 7.0)
		raw[i] = clampf(v * 1.4, -1.0, 1.0)
	return _loop(raw, 0.06, 0.5)


## The car shaking in its guides: a low rumble swelling and easing, the cables' thrum, metal knocking and rattling.
func _shake(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var length := 4.0
	var n := int(SR * length)
	var raw := PackedFloat32Array()
	raw.resize(n)
	var lp1 := 0.0
	var lp2 := 0.0
	var a := 1.0 - exp(-TAU * 140.0 / SR)
	for i in n:
		var s := float(i) / SR
		lp1 += a * (rng.randf_range(-1.0, 1.0) - lp1)
		lp2 += a * (lp1 - lp2)
		var swell := 0.6 + 0.4 * sin(TAU * s / length * 2.0) * sin(TAU * s / length * 5.0)
		var thrum := sin(TAU * 38.0 * s + 0.8 * sin(TAU * 0.5 * s)) * 0.35
		raw[i] = lp2 * 6.0 * swell + thrum * swell
	# knocks: short metallic rings at random, some in quick rattling runs
	var t := 0.05
	while t < length - 0.3:
		var run := 1 if rng.randf() < 0.6 else rng.randi_range(3, 6)
		var f0 := rng.randf_range(380.0, 1300.0)
		var amp := rng.randf_range(0.25, 0.7)
		for r in run:
			var at := int(SR * (t + r * 0.045))
			for j in int(SR * 0.18):
				if at + j >= n:
					break
				var u := float(j) / SR
				var ring := (sin(TAU * f0 * u) + 0.5 * sin(TAU * f0 * 2.76 * u)) * exp(-u / 0.035)
				raw[at + j] += ring * amp * (0.9 if r == 0 else 0.6) + rng.randf_range(-1.0, 1.0) * exp(-u / 0.004) * 0.3
		t += rng.randf_range(0.12, 0.55) + run * 0.045
	return _loop(raw, 0.1, 0.6)


## A big metal bang: a deep thump, a burst, the car's steel ringing on.
func _bang(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(SR * 1.6)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var partials := [[231.0, 0.5, 0.5], [409.0, 0.4, 0.35], [763.0, 0.3, 0.25], [1229.0, 0.2, 0.18], [1871.0, 0.12, 0.12]]
	var lp := 0.0
	for i in n:
		var s := float(i) / SR
		ph += TAU * (36.0 + 50.0 * exp(-s / 0.04)) / SR
		var v := sin(ph) * exp(-s / 0.22) * 1.2
		lp += 0.25 * (rng.randf_range(-1.0, 1.0) - lp)
		v += lp * 2.0 * exp(-s / 0.05)
		for p: Array in partials:
			v += sin(TAU * p[0] * s) * p[1] * exp(-s / p[2])
		out[i] = v * minf(1.0, s / 0.001)
	return _normalize(out, 0.9)


## The emergency brake biting: a harsh, jittering metal squeal over grinding, rising, then the car slamming to a stop.
func _brake(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var length := 2.8
	var n := int(SR * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	var jit := 0.0
	var low := 0.0
	var band := 0.0
	var stop := 2.25
	for i in n:
		var s := float(i) / SR
		var env := minf(1.0, s / 0.08) * (1.0 if s < stop else exp(-(s - stop) / 0.05))
		jit += 0.02 * (rng.randf_range(-1.0, 1.0) - jit)
		var f := 2300.0 + 500.0 * (s / stop) + 380.0 * jit * 20.0
		ph += TAU * f / SR
		var squeal := (sin(ph) + 0.4 * sin(ph * 2.01) + 0.2 * sin(ph * 3.03)) * 0.4
		# grinding: noise through a band round 900 Hz
		var fc := 2.0 * sin(PI * 900.0 / SR)
		var x := rng.randf_range(-1.0, 1.0)
		low += fc * band
		var high := x - low - 0.6 * band
		band += fc * high
		out[i] = (squeal + band * 1.2) * env
	# the slam
	var at := int(SR * stop)
	var p2 := 0.0
	for j in int(SR * 0.5):
		if at + j >= n:
			break
		var u := float(j) / SR
		p2 += TAU * (42.0 + 60.0 * exp(-u / 0.03)) / SR
		out[at + j] += sin(p2) * exp(-u / 0.12) * 1.6 + rng.randf_range(-1.0, 1.0) * exp(-u / 0.02) * 0.6
	return _normalize(out, 0.9)


## A stiff quarter-turn latch giving a little: a short metal grind and a click.
func _latch(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(SR * 0.4)
	var out := PackedFloat32Array()
	out.resize(n)
	var low := 0.0
	var band := 0.0
	var fc := 2.0 * sin(PI * 2400.0 / SR)
	for i in n:
		var s := float(i) / SR
		var x := rng.randf_range(-1.0, 1.0) * (0.6 + 0.4 * sin(TAU * 55.0 * s))
		low += fc * band
		var high := x - low - 0.5 * band
		band += fc * high
		var env := minf(1.0, s / 0.01) * (1.0 if s < 0.17 else exp(-(s - 0.17) / 0.015))
		out[i] = band * env * 0.8
	var at := int(SR * 0.2)
	for j in int(SR * 0.05):
		var u := float(j) / SR
		out[at + j] += (sin(TAU * 3100.0 * u) + 0.6 * sin(TAU * 5200.0 * u)) * exp(-u / 0.006) * 0.9
	return _normalize(out, 0.7)


## The escape lever pulled: a ratchet running over a few teeth, then a heavy clunk as it hits home.
func _lever(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(SR * 0.7)
	var out := PackedFloat32Array()
	out.resize(n)
	for k in 5:
		var at := int(SR * (0.02 + k * 0.035))
		for j in int(SR * 0.02):
			var u := float(j) / SR
			out[at + j] += sin(TAU * (2600.0 + k * 90.0) * u) * exp(-u / 0.003) * 0.6
	var at2 := int(SR * 0.22)
	var ph := 0.0
	for j in int(SR * 0.45):
		if at2 + j >= n:
			break
		var u := float(j) / SR
		ph += TAU * (90.0 + 80.0 * exp(-u / 0.02)) / SR
		out[at2 + j] += sin(ph) * exp(-u / 0.08) + (sin(TAU * 820.0 * u) * 0.3 + rng.randf_range(-1.0, 1.0) * 0.4) * exp(-u / 0.02)
	return _normalize(out, 0.85)


## Nobody pulled it: a cable snapping like a whip, then the car falling — air roaring up past it, steel screaming.
func _fall(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var length := 3.2
	var n := int(SR * length)
	var out := PackedFloat32Array()
	out.resize(n)
	var lp1 := 0.0
	var a := 1.0 - exp(-TAU * 900.0 / SR)
	var ph := 0.0
	for i in n:
		var s := float(i) / SR
		# the snap
		var snap := 0.0
		if s < 0.15:
			snap = rng.randf_range(-1.0, 1.0) * exp(-s / 0.02) * 1.5 + sin(TAU * 1700.0 * s) * exp(-s / 0.03)
		# the rush, growing
		var g := clampf((s - 0.1) / 2.6, 0.0, 1.0)
		lp1 += a * (rng.randf_range(-1.0, 1.0) - lp1)
		var rush := lp1 * 3.0 * g * g
		ph += TAU * (600.0 + 1400.0 * g) / SR
		var scream := sin(ph + 0.3 * sin(TAU * 7.0 * s)) * 0.25 * g
		out[i] = snap + rush + scream
	for i in int(SR * 0.05):
		out[n - 1 - i] *= float(i) / (SR * 0.05)
	return _normalize(out, 0.85)


## A seamless loop from `raw`: its last `xfade` s cross-faded into its start.
func _loop(raw: PackedFloat32Array, xfade: float, peak: float) -> PackedFloat32Array:
	var n := raw.size()
	var x := int(SR * xfade)
	var out := raw.slice(0, n - x)
	for j in x:
		var w := float(j) / x
		out[j] = raw[j] * w + raw[n - x + j] * (1.0 - w)
	return _normalize(out, peak)


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
