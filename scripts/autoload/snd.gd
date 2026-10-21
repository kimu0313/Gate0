extends Node
## Audio director: buses, one-shots, 3D sounds, ambience layers and the terminal PA system.

signal pa_started(tag: String)
signal pa_finished(cancelled: bool)

const SFX_DIR := "res://assets/audio/sfx/"
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
	AudioServer.set_bus_volume_db(pa, -2.0)

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

	var hall := _add_bus("RevHall", "SFX")
	var hrev := AudioEffectReverb.new()
	hrev.room_size = 0.95
	hrev.damping = 0.25
	hrev.dry = 0.0
	hrev.wet = 0.6
	hrev.predelay_msec = 45.0
	AudioServer.add_bus_effect(hall, hrev)

	var room := _add_bus("RevRoom", "SFX")
	var rrev := AudioEffectReverb.new()
	rrev.room_size = 0.35
	rrev.damping = 0.6
	rrev.dry = 0.0
	rrev.wet = 0.35
	AudioServer.add_bus_effect(room, rrev)


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
	if clip == "name_call":
		if Game.name_voice_path != "":
			if _cache.has("__name__" + Game.name_voice_path):
				return _cache["__name__" + Game.name_voice_path]
			var w := AudioStreamWAV.load_from_file(Game.name_voice_path)
			if w:
				_cache["__name__" + Game.name_voice_path] = w
				return w
		return stream("pa_call_generic_ko")
	return stream(clip)


func random_variant(base: String, count: int) -> String:
	return "%s_%d" % [base, randi_range(1, count)]


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
	scene.add_child(p)
	p.global_position = pos
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
		create_tween().tween_property(next, "volume_db", volume_db, fade)
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
##       no_end (bool), tag (String), delay_between (float)
func pa_announce(clips: Array, opts: Dictionary = {}) -> bool:
	while pa_busy:
		await pa_finished
	pa_busy = true
	pa_tag = str(opts.get("tag", ""))
	_pa_cancel = false
	pa_started.emit(pa_tag)
	var chime := "pa_chime_wrong" if opts.get("wrong", false) else "pa_chime"
	await _pa_play(stream(chime), 1.0, false)
	if not _pa_cancel:
		await _wait(0.25)
	var subs: Array = opts.get("subs", [])
	var base_pitch: float = opts.get("pitch", 1.0)
	for i in clips.size():
		if _pa_cancel:
			break
		var s := voice(str(clips[i]))
		if s == null:
			continue
		var slow: bool = int(opts.get("slow_index", -1)) == i
		if i < subs.size() and str(subs[i]) != "":
			var dur := s.get_length() / base_pitch * (1.35 if slow else 1.0)
			Events.subtitle.emit("pa", str(subs[i]), dur + 0.4)
		await _pa_play(s, base_pitch, slow)
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


func pa_stop() -> void:
	if not pa_busy:
		return
	_pa_cancel = true
	_pa.stop()
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
