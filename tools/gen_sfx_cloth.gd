extends SceneTree
## Synthesizes changing clothes for Shift1's locker (GDScript like gen_sfx_lift.gd: no Python on every machine):
##   cloth_change   ~2.4 s: a jacket pulled off and another shrugged on — soft swishes of fabric (band-limited noise
##                  under slow swells), a zip run up, a last tug
## Dry and close; the engine adds the room. Written to assets/audio/sfx; import after:
##   godot --headless --path . --script res://tools/gen_sfx_cloth.gd
##   godot --headless --path . --import

const SR := 44100
const OUT := "res://assets/audio/sfx/"


func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7313
	_save("cloth_change", _cloth(rng))
	quit()


func _cloth(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var n := int(SR * 2.4)
	var buf := PackedFloat32Array()
	buf.resize(n)
	# swishes: [start s, length s, gain, brightness]
	for e: Array in [[0.04, 0.34, 0.9, 0.3], [0.36, 0.26, 0.6, 0.22], [0.66, 0.42, 1.0, 0.34], [1.55, 0.3, 0.55, 0.26],
			[1.86, 0.42, 0.85, 0.3], [2.18, 0.16, 0.4, 0.2]]:
		var start := int(float(e[0]) * SR)
		var dur := int(float(e[1]) * SR)
		var fc: float = e[3]
		var lp := 0.0
		var lp2 := 0.0
		var slow := 0.0
		var ph := rng.randf() * TAU
		for i in dur:
			if start + i >= n:
				break
			var t := float(i) / dur
			var env := pow(sin(PI * t), 1.6) * (0.75 + 0.25 * sin(t * 31.0 + ph))
			lp += (rng.randf_range(-1.0, 1.0) - lp) * fc
			lp2 += (lp - lp2) * fc
			slow += (lp2 - slow) * 0.015
			buf[start + i] += (lp2 - slow) * env * float(e[2])
	# a zip run up: teeth clicking faster as it goes
	var teeth := 34
	for k in teeth:
		var u := float(k) / teeth
		var at := int((1.12 + 0.36 * pow(u, 0.75)) * SR)
		var g := 0.35 + 0.25 * rng.randf()
		var prev := 0.0
		for i in int(0.004 * SR):
			if at + i >= n:
				break
			var x := rng.randf_range(-1.0, 1.0) * exp(-float(i) / (0.0009 * SR))
			buf[at + i] += (x - prev) * g
			prev = x
	return _normalize(buf, 0.7)


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
