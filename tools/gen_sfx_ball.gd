extends SceneTree
## Synthesizes the red ball's sounds for the service corridor (no Python on every machine, so this one is GDScript):
##   ball_bounce_1..3   a hollow rubber ball landing on hard tile: a short low thump that drops in pitch as it lands,
##                      the ball's air cavity ringing over it, a tiny click of the skin on the floor
##   ball_roll_loop     the same ball rolling on tile: a soft rumble that flutters as it turns, the grout joints ticking
## Dry and close, like the other sources (the engine adds the room). Written to assets/audio/sfx; import them after:
##   godot --headless --path . --script res://tools/gen_sfx_ball.gd
##   godot --headless --path . --import

const SR := 44100
const OUT := "res://assets/audio/sfx/"


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	# [body pitch, cavity pitch, body decay, brightness]
	var takes := [[182.0, 540.0, 0.05, 0.55], [204.0, 610.0, 0.042, 0.7], [168.0, 480.0, 0.056, 0.45]]
	for i in takes.size():
		_save("ball_bounce_%d" % (i + 1), _bounce(takes[i], rng))
	_save("ball_roll_loop", _roll(rng))
	quit()


func _bounce(t: Array, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(SR * 0.42)
	var out := PackedFloat32Array()
	out.resize(n)
	var f0: float = t[0]
	var fc: float = t[1]
	var decay: float = t[2]
	var bright: float = t[3]
	var phase := 0.0
	var cav := 0.0
	var hp := 0.0
	var last := 0.0
	for i in n:
		var s := float(i) / SR
		var f := f0 * (1.0 + 0.45 * exp(-s / 0.008))           # the thump sags as the ball squashes
		phase += TAU * f / SR
		cav += TAU * fc * (1.0 - 0.06 * exp(-s / 0.02)) / SR
		var body := sin(phase) * exp(-s / decay)
		var ring := sin(cav) * exp(-s / 0.022) * 0.35 * bright
		var noise := rng.randf_range(-1.0, 1.0)
		hp = noise - last                                             # a crude high-pass for the click
		last = noise
		var click := hp * exp(-s / 0.0012) * 0.5 * bright
		var attack := minf(1.0, s / 0.0006)
		out[i] = (body * 0.9 + ring + click) * attack
	return _normalize(out, 0.85)


func _roll(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var length := 1.2
	var n := int(SR * length)
	var raw := PackedFloat32Array()
	raw.resize(n)
	# rumble: low-passed noise, fluttering at the turn rate (a whole number of turns in the loop)
	var lp1 := 0.0
	var lp2 := 0.0
	var a := 1.0 - exp(-TAU * 260.0 / SR)
	for i in n:
		lp1 += a * (rng.randf_range(-1.0, 1.0) - lp1)
		lp2 += a * (lp1 - lp2)
		var s := float(i) / SR
		var flutter := 0.75 + 0.25 * sin(TAU * s * 5.0 / length * 4.0)
		raw[i] = lp2 * 3.2 * flutter
	# grout joints: soft ticks, eight in the loop
	for k in 8:
		var at := int((k + rng.randf_range(0.1, 0.35)) * n / 8.0)
		var amp := rng.randf_range(0.18, 0.32)
		var ph := 0.0
		for j in int(SR * 0.04):
			if at + j >= n:
				break
			var s := float(j) / SR
			ph += TAU * 230.0 / SR
			raw[at + j] += sin(ph) * exp(-s / 0.008) * amp
	# seamless: the last 60 ms fade into the first
	var x := int(SR * 0.06)
	var out := raw.slice(0, n - x)
	for j in x:
		var w := float(j) / x
		out[j] = raw[j] * w + raw[n - x + j] * (1.0 - w)
	return _normalize(out, 0.5)


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
