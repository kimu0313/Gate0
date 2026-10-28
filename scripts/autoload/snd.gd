extends Node
## Audio director: buses, one-shots, 3D sounds, ambience layers and the terminal PA system.

signal pa_started(tag: String)
signal pa_finished(cancelled: bool)

const SFX_DIR := "res://assets/audio/sfx/"
## Makeup gain on the SFX bus: the ElevenLabs set (and its room-recorded footsteps) plays quieter than the procedural
## set it replaced; this brings the world back to the old loudness (~-23.5 LUFS in the audio walk). The radio and PA
## buses take the same off so the voices keep their level.
const WORLD_GAIN := 2.5
const VOICE_DIR := "res://assets/audio/voice/"

var _cache := {}
var _missing := {}
var _ui_pool: Array[AudioStreamPlayer] = []
var _ui_index := 0

var _amb_a: AudioStreamPlayer
var _amb_b: AudioStreamPlayer
var _amb_current: AudioStreamPlayer
var _music: AudioStreamPlayer
var _drone: AudioStreamPlayer
var _heart: AudioStreamPlayer
var _whisper: AudioStreamPlayer
var _pa: AudioStreamPlayer
var _radio_static: AudioStreamPlayer

var pa_busy := false
var pa_tag := ""
var _pa_cancel := false
var _muffle_amount := 0.0
var _tension := 0.0

var bus_master := 0
var _muffle_fx_index := -1

## Distant one-shots scattered around the listener during a shift (creaks, duct ticks, a far beep…), sparse and
## quiet, never during a PA announcement. More often as the dread rises.
const SCATTER := ["amb_creak_1", "amb_creak_2", "amb_tick_1", "amb_knock_1", "amb_far_beep_1", "amb_rattle_1", "amb_cart_1"]
var _scatter_on := false
var _scatter_t := 0.0
var _scatter_last := ""

## Zone ambience beds layered over the global room tone (Events.zone_entered): [bed, bed dB, how much the big-hall
## tone ducks there] (closed rooms hear less of the hall).
const BEDS := {
	"office": ["amb_office_loop", -8.0, -9.0], "secoffice": ["amb_office_loop", -8.0, -9.0], "storage": ["amb_service_loop", -9.0, -8.0], "maint": ["amb_service_loop", -6.0, -10.0],
	"baggage": ["amb_baggage_loop", -7.0, -4.0], "security": ["amb_baggage_loop", -12.0, -2.0],
	"corridor": ["amb_corridor_loop", -7.0, -4.0], "gates": ["amb_gates_loop", -6.0, -5.0], "bridge0": ["amb_gates_loop", -13.0, -8.0],
}
var _beds_on := false
var _bed_a: AudioStreamPlayer
var _bed_b: AudioStreamPlayer
var _bed_current: AudioStreamPlayer
var _bed_name := ""
var _amb_target_db := -6.0
var _amb_duck := 0.0

var _occluders: Array = []
var _occ_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "UI"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_ui_pool.append(p)
	_amb_a = _make_player("Ambience")
	_amb_b = _make_player("Ambience")
	_music = _make_player("Music")
	_drone = _make_player("SFX")
	_heart = _make_player("SFX")
	_whisper = _make_player("SFX")
	_pa = _make_player("PA")
	_radio_static = _make_player("Radio")
	_bed_a = _make_player("Ambience")
	_bed_b = _make_player("Ambience")
	Events.zone_entered.connect(_on_zone)
	Game.apply_settings()


func _make_player(bus_name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus_name
	p.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(p)
	return p


func _setup_buses() -> void:
	bus_master = AudioServer.get_bus_index("Master")
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(bus_master, lp)
	_muffle_fx_index = AudioServer.get_bus_effect_count(bus_master) - 1
	AudioServer.set_bus_effect_enabled(bus_master, _muffle_fx_index, false)
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.5
	AudioServer.add_bus_effect(bus_master, limiter)

	_add_bus("Music", "Master")
	_add_bus("SFX", "Master")
	_add_bus("UI", "Master")
	_add_bus("Ambience", "SFX")
	var makeup := AudioEffectAmplify.new()
	makeup.volume_db = WORLD_GAIN
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), makeup)

	var pa := _add_bus("PA", "SFX")
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 260.0
	AudioServer.add_bus_effect(pa, hp)
	var lpf := AudioEffectLowPassFilter.new()
	lpf.cutoff_hz = 5200.0
	AudioServer.add_bus_effect(pa, lpf)
	var delay := AudioEffectDelay.new()
	delay.dry = 1.0
	delay.tap1_active = true
	delay.tap1_delay_ms = 190.0
	delay.tap1_level_db = -11.0
	delay.tap1_pan = -0.3
	delay.tap2_active = true
	delay.tap2_delay_ms = 410.0
	delay.tap2_level_db = -17.0
	delay.tap2_pan = 0.35
	AudioServer.add_bus_effect(pa, delay)
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.9
	rev.damping = 0.35
	rev.spread = 1.0
	rev.dry = 0.85
	rev.wet = 0.38
	rev.predelay_msec = 70.0
	AudioServer.add_bus_effect(pa, rev)
	AudioServer.set_bus_volume_db(pa, -2.0 - WORLD_GAIN)

	var radio := _add_bus("Radio", "SFX")
	var rhp := AudioEffectHighPassFilter.new()
	rhp.cutoff_hz = 420.0
	AudioServer.add_bus_effect(radio, rhp)
	var rlp := AudioEffectLowPassFilter.new()
	rlp.cutoff_hz = 3200.0
	AudioServer.add_bus_effect(radio, rlp)
	var dist := AudioEffectDistortion.new()
	dist.mode = AudioEffectDistortion.MODE_OVERDRIVE
	dist.drive = 0.25
	AudioServer.add_bus_effect(radio, dist)
	AudioServer.set_bus_volume_db(radio, -WORLD_GAIN)

	# Reverb sends for the Terminal's reverb zones (Area3D), one per kind of space. Wet only: the dry sound
	# stays on SFX. hipass keeps the low end out of the tails so big rooms do not boom; no predelay feedback
	# (it repeats the early echo into a metallic flutter) and a low-pass so the tail is softer than the sound.
	for r in [
		["RevHall", 0.7, 0.6, 22.0, 0.5, 0.2],          # double-height check-in lobby: big stone room
		["RevLong", 0.78, 0.5, 30.0, 0.5, 0.22],        # long glass corridor and gate lounge: longer tail
		["RevMid", 0.5, 0.65, 12.0, 0.42, 0.22],        # security and baggage halls: wide but low ceilings
		["RevRoom", 0.25, 0.75, 4.0, 0.35, 0.28],       # office, storage, maintenance: small and dull
		["RevTight", 0.15, 0.6, 2.0, 0.4, 0.3],         # jet bridge: narrow tube
	]:
		var bus := _add_bus(r[0], "SFX")
		var zrev := AudioEffectReverb.new()
		zrev.room_size = r[1]
		zrev.damping = r[2]
		zrev.predelay_msec = r[3]
		zrev.predelay_feedback = 0.0
		zrev.dry = 0.0
		zrev.wet = r[4]
		zrev.hipass = r[5]
		zrev.spread = 0.9
		var soft := AudioEffectLowPassFilter.new()
		soft.cutoff_hz = 4500.0
		AudioServer.add_bus_effect(bus, soft)
		AudioServer.add_bus_effect(bus, zrev)


func _add_bus(bus_name: String, send: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		return idx
	AudioServer.add_bus()
	idx = AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send)
	return idx


# --- streams --------------------------------------------------------------------------
func stream(sound_name: String) -> AudioStream:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var path := SFX_DIR + sound_name + ".wav"
	if not ResourceLoader.exists(path):
		path = VOICE_DIR + sound_name + ".wav"
	if not ResourceLoader.exists(path):
		if not _missing.has(sound_name):
			_missing[sound_name] = true
			push_warning("Missing sound: " + sound_name)
		return null
	var s: AudioStream = load(path)
	if s is AudioStreamWAV and sound_name.ends_with("_loop"):
		var w := s as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = 0
			w.loop_end = int(w.get_length() * w.mix_rate)
	_cache[sound_name] = s
	return s


func voice(clip: String) -> AudioStream:
	return stream(clip)


func random_variant(base: String, count: int) -> String:
	return "%s_%d" % [base, randi_range(1, count)]


var _variants := {}

## A random existing take of `base` (base_1, base_2 … however many the sound set has), never the same twice in a row.
func variant(base: String) -> String:
	if not _variants.has(base):
		var n := 0
		while ResourceLoader.exists(SFX_DIR + "%s_%d.wav" % [base, n + 1]):
			n += 1
		_variants[base] = [maxi(1, n), 0]
	var v: Array = _variants[base]
	var k := randi_range(1, v[0])
	if v[0] > 1 and k == v[1]:
		k = k % v[0] + 1
	v[1] = k
	return "%s_%d" % [base, k]


# --- one-shots ---------------------------------------------------------------------------
func play(sound_name: String, volume_db := 0.0, pitch := 1.0, bus := "UI") -> AudioStreamPlayer:
	var s := stream(sound_name)
	if s == null:
		return null
	var p := _ui_pool[_ui_index]
	_ui_index = (_ui_index + 1) % _ui_pool.size()
	p.stop()
	p.bus = bus
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()
	return p


## Every world sound goes through here: reverb zones (area_mask), air absorption over distance, and occlusion
## (muffled and quieter when a wall stands between it and the listener, see _update_occlusion).
func setup_3d(p: AudioStreamPlayer3D, occlude := true) -> void:
	p.area_mask = Geo.LAYER_AUDIO
	p.attenuation_filter_cutoff_hz = 7000.0
	p.attenuation_filter_db = -14.0
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	if occlude:
		p.set_meta("occ_unit", p.unit_size)
		p.set_meta("occ", 0.0)
		_occluders.append(p)


func play_at(sound_name: String, pos: Vector3, volume_db := 0.0, pitch := 1.0, unit_size := 6.0, max_dist := 60.0) -> AudioStreamPlayer3D:
	var s := stream(sound_name)
	var scene := get_tree().current_scene
	if s == null or scene == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.unit_size = unit_size
	p.max_distance = max_dist
	p.bus = "SFX"
	setup_3d(p)
	scene.add_child(p)
	p.global_position = pos
	_occlude(p, 1.0)
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Persistent looping 3D emitter owned by `parent` (facility hums, belts...). Not started.
func make_loop(sound_name: String, parent: Node3D, volume_db := 0.0, unit_size := 5.0, max_dist := 40.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream(sound_name)
	p.volume_db = volume_db
	p.unit_size = unit_size
	p.max_distance = max_dist
	p.bus = "SFX"
	setup_3d(p)
	parent.add_child(p)
	return p


# --- ambience / music / tension ---------------------------------------------------------------
func set_ambience(sound_name: String, volume_db := -6.0, fade := 2.0) -> void:
	var next := _amb_b if _amb_current == _amb_a else _amb_a
	var prev := _amb_current
	if sound_name != "":
		next.stream = stream(sound_name)
		next.volume_db = -60.0
		next.play()
		_amb_target_db = volume_db
		create_tween().tween_property(next, "volume_db", volume_db + _amb_duck, fade)
		_amb_current = next
	else:
		_amb_current = null
	if prev:
		var t := create_tween()
		t.tween_property(prev, "volume_db", -60.0, fade)
		t.tween_callback(prev.stop)


func set_music(sound_name: String, volume_db := -8.0, fade := 2.0) -> void:
	if sound_name == "":
		var t := create_tween()
		t.tween_property(_music, "volume_db", -60.0, fade)
		t.tween_callback(_music.stop)
		return
	var s := stream(sound_name)
	if _music.playing and _music.stream == s:
		create_tween().tween_property(_music, "volume_db", volume_db, fade)
		return
	_music.stream = s
	_music.volume_db = -60.0
	_music.play()
	create_tween().tween_property(_music, "volume_db", volume_db, fade)


## 0..1 global dread level (drives drone, heartbeat, whispers).
func set_tension(value: float) -> void:
	_tension = clampf(value, 0.0, 1.0)


func _process(delta: float) -> void:
	_update_layer(_drone, "drone_loop", _tension, -34.0, -9.0, 0.08, delta)
	_update_layer(_heart, "heartbeat_loop", clampf((_tension - 0.6) / 0.4, 0.0, 1.0), -30.0, -8.0, 0.0, delta)
	_update_layer(_whisper, "whisper_loop", clampf((_tension - 0.45) / 0.55, 0.0, 1.0), -36.0, -14.0, 0.0, delta)
	_update_scatter(delta)
	_update_occlusion(delta)
	# eyes-closed muffle
	if _muffle_fx_index >= 0:
		var fx := AudioServer.get_bus_effect(bus_master, _muffle_fx_index) as AudioEffectLowPassFilter
		var target := lerpf(20000.0, 600.0, _muffle_amount)
		fx.cutoff_hz = lerpf(fx.cutoff_hz, target, clampf(delta * 6.0, 0.0, 1.0))
		AudioServer.set_bus_effect_enabled(bus_master, _muffle_fx_index, fx.cutoff_hz < 19000.0)


func _update_layer(p: AudioStreamPlayer, sound_name: String, amount: float, min_db: float, max_db: float, threshold: float, delta: float) -> void:
	if get_tree().paused:
		return
	if amount <= threshold:
		if p.playing:
			p.volume_db = move_toward(p.volume_db, -60.0, delta * 20.0)
			if p.volume_db <= -59.0:
				p.stop()
		return
	if not p.playing:
		p.stream = stream(sound_name)
		if p.stream == null:
			return
		p.volume_db = -60.0
		p.play()
	var target := lerpf(min_db, max_db, amount)
	p.volume_db = move_toward(p.volume_db, target, delta * 12.0)


## Zone beds on/off (a shift in the terminal); off fades them out.
func set_beds(on: bool) -> void:
	_beds_on = on
	if not on:
		_set_bed("", 0.0, 0.0, 2.0)


func _on_zone(zone: String) -> void:
	if not _beds_on:
		return
	var b: Array = BEDS.get(zone, ["", 0.0, 0.0])
	_set_bed(b[0], b[1], b[2], 2.5)


func _set_bed(sound_name: String, volume_db: float, duck: float, fade: float) -> void:
	_amb_duck = duck
	if _amb_current:
		create_tween().tween_property(_amb_current, "volume_db", _amb_target_db + duck, fade)
	if sound_name == _bed_name:
		if _bed_current:
			create_tween().tween_property(_bed_current, "volume_db", volume_db, fade)
		return
	_bed_name = sound_name
	var prev := _bed_current
	_bed_current = null
	if sound_name != "":
		var next := _bed_b if prev == _bed_a else _bed_a
		next.stream = stream(sound_name)
		if next.stream:
			next.volume_db = -60.0
			next.play(randf() * maxf(0.0, next.stream.get_length() - 1.0))
			create_tween().tween_property(next, "volume_db", volume_db, fade)
			_bed_current = next
	if prev:
		var t := create_tween()
		t.tween_property(prev, "volume_db", -60.0, fade)
		t.tween_callback(prev.stop)


## Occlusion: every ~0.12 s a ray from the listener to each world sound; a wall in between (not the sound's own
## machine: hits within 1.2 m of it are ignored) muffles it (low-pass) and pulls it back (smaller unit size).
func _update_occlusion(delta: float) -> void:
	_occ_t -= delta
	if _occ_t > 0.0:
		return
	_occ_t = 0.12
	var keep: Array = []
	for p: Variant in _occluders:
		if is_instance_valid(p) and (p as Node).is_inside_tree():
			keep.append(p)
	_occluders = keep
	for p: AudioStreamPlayer3D in _occluders:
		if p.playing:
			_occlude(p, 0.35)


func _occlude(p: AudioStreamPlayer3D, rate: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or not p.is_inside_tree():
		return
	var from := cam.global_position
	var to := p.global_position
	var target := 0.0
	if from.distance_to(to) > 1.5:
		var q := PhysicsRayQueryParameters3D.create(from, to, Geo.LAYER_WORLD)
		var hit := cam.get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and (hit.position as Vector3).distance_to(to) > 1.2:
			target = 1.0
	var occ: float = lerpf(p.get_meta("occ", 0.0), target, rate)
	p.set_meta("occ", occ)
	p.attenuation_filter_cutoff_hz = lerpf(7000.0, 900.0, occ)
	p.unit_size = float(p.get_meta("occ_unit", p.unit_size)) * lerpf(1.0, 0.45, occ)


func set_scatter(on: bool) -> void:
	_scatter_on = on
	_scatter_t = randf_range(10.0, 20.0)


func _update_scatter(delta: float) -> void:
	if not _scatter_on or get_tree().paused or pa_busy:
		return
	_scatter_t -= delta
	if _scatter_t > 0.0:
		return
	_scatter_t = randf_range(22.0, 48.0) * lerpf(1.0, 0.55, _tension)
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var pick: String = SCATTER[randi() % SCATTER.size()]
	if pick == _scatter_last:
		pick = SCATTER[(SCATTER.find(pick) + 1) % SCATTER.size()]
	_scatter_last = pick
	var a := randf() * TAU
	var pos := cam.global_position + Vector3(cos(a), 0, sin(a)) * randf_range(14.0, 30.0) + Vector3(0, randf_range(1.0, 4.5), 0)
	play_at(pick, pos, randf_range(-4.0, 0.0), randf_range(0.88, 1.04), 8.0, 60.0)


func set_muffle(amount: float) -> void:
	_muffle_amount = clampf(amount, 0.0, 1.0)


func stop_all_world() -> void:
	_pa_cancel = true
	_pa.stop()
	pa_busy = false
	for p in [_amb_a, _amb_b, _drone, _heart, _whisper, _radio_static]:
		p.stop()
	_amb_current = null
	_tension = 0.0
	_muffle_amount = 0.0
	_scatter_on = false
	_beds_on = false
	_bed_name = ""
	_amb_duck = 0.0
	for p in [_bed_a, _bed_b]:
		p.stop()
	_bed_current = null


# --- radio ---------------------------------------------------------------------------------------
func radio_static(on: bool) -> void:
	if on:
		_radio_static.stream = stream("radio_static_loop")
		_radio_static.volume_db = -22.0
		_radio_static.play()
	else:
		_radio_static.stop()


# --- PA system -------------------------------------------------------------------------------------
## Plays a full PA announcement (chime → voice clips → closing chime). Await it.
## opts: subs (Array[String]), wrong (bool), slow_index (int, voice slows down), pitch (float),
##       pitches (Array[float], per clip), no_chime (bool, no opening chime — a tape starting by itself),
##       no_end (bool), tag (String), delay_between (float)
func pa_announce(clips: Array, opts: Dictionary = {}) -> bool:
	while pa_busy:
		await pa_finished
	pa_busy = true
	pa_tag = str(opts.get("tag", ""))
	_pa_cancel = false
	pa_started.emit(pa_tag)
	if not opts.get("no_chime", false):
		var chime := "pa_chime_wrong" if opts.get("wrong", false) else "pa_chime"
		await _pa_play(stream(chime), 1.0, false)
		if not _pa_cancel:
			await _wait(0.25)
	var subs: Array = opts.get("subs", [])
	var pitches: Array = opts.get("pitches", [])
	for i in clips.size():
		if _pa_cancel:
			break
		var s := voice(str(clips[i]))
		if s == null:
			continue
		var clip_pitch: float = float(pitches[i]) if i < pitches.size() else float(opts.get("pitch", 1.0))
		var slow: bool = int(opts.get("slow_index", -1)) == i
		if i < subs.size() and str(subs[i]) != "":
			var dur := s.get_length() / clip_pitch * (1.35 if slow else 1.0)
			Events.subtitle.emit("pa", str(subs[i]), dur + 0.4)
		await _pa_play(s, clip_pitch, slow)
		if not _pa_cancel and i < clips.size() - 1:
			await _wait(float(opts.get("delay_between", 0.6)))
	if not _pa_cancel and not opts.get("no_end", false):
		await _wait(0.2)
		await _pa_play(stream("pa_chime_end"), 1.0, false)
	var cancelled := _pa_cancel
	pa_busy = false
	pa_tag = ""
	_pa.pitch_scale = 1.0
	pa_finished.emit(cancelled)
	return not cancelled


func pa_stop(quiet := false) -> void:
	if not pa_busy:
		return
	_pa_cancel = true
	_pa.stop()
	if not quiet:
		play("glitch", -8.0, 1.0, "SFX")


func _pa_play(s: AudioStream, pitch: float, slow: bool) -> void:
	if s == null or _pa_cancel:
		return
	_pa.stream = s
	_pa.pitch_scale = pitch
	_pa.play()
	var t := 0.0
	var length := s.get_length()
	while _pa.playing and not _pa_cancel:
		await get_tree().process_frame
		if not get_tree().paused:
			t += get_process_delta_time()
		if slow and length > 0.0:
			var k := clampf((t / (length / pitch) - 0.35) / 0.5, 0.0, 1.0)
			_pa.pitch_scale = lerpf(pitch, pitch * 0.62, k)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout
