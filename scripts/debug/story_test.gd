extends Node
## `-- --storytest [caught|tear|loop]` on the game scene (headless OK, add `--prologue` or `--chapter ch1`, and
## `--checkpoint hub|baggage|final` to start further on): plays the part like a player — follows each beat, walks the
## routes, presses [E] on what it needs through the player's own ray — and quits with 0 once it has reached the end of
## the part (1 = a beat never came, 2 = caught when it should not be). `--order acb` picks the order of the three
## branches. `caught` stands still when the chase starts and checks that, once caught, the game restarts by itself at
## the checkpoint (the reloaded scene runs this again and escapes). `tear` (--checkpoint baggage) stands in the open in
## baggage claim and checks it has you. `loop` plays the part but does not quit at its end, so the game goes on to the
## next scene (scripts/debug/loop_test.gd drives the whole game that way). A story test never writes the player's save.
## Past the 2F the clock runs at SPEED so a whole run stays short.

const SPEED := 5.0

var world: Node3D
var _mode := ""
var _shots := ""                 # `--shots <dir>` (windowed): a screenshot at each beat
var _d: StoryDirector
var _p: Player
var _tree: SceneTree          # kept: the test outlives its scene by a frame when the part ends in a scene change
var _toasts: Array = []       # [text, where the player stood] for every notify toast


func _ready() -> void:
	_tree = get_tree()
	var args := OS.get_cmdline_user_args()
	var i := args.find("--storytest")
	if i + 1 < args.size() and not args[i + 1].begins_with("--"):
		_mode = args[i + 1]
	_d = world.director
	_p = world.player
	Events.notify.connect(func(text: String, _kind: String): _toasts.append([text, _p.global_position]))
	var si := args.find("--shots")
	if si >= 0 and si + 1 < args.size() and DisplayServer.get_name() != "headless":
		_shots = args[si + 1]
		DirAccess.make_dir_recursive_absolute(_shots)
	_tree.create_timer(1500.0, true, false, true).timeout.connect(func(): _end(1, "timeout at objective '%s'" % _d.objective_text))
	_log("start chapter=%s checkpoint=%s mode=%s" % [Game.chapter, Game.checkpoint, _mode])
	await _tree.process_frame
	_d.start()
	if Game.chapter == "ch1":
		await _ch1()
	else:
		await _prologue()


func _shot(name_text: String, settle := 0.6) -> void:
	if _shots == "":
		return
	await _tree.create_timer(settle).timeout
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [_shots, name_text])
	_log("shot " + name_text)


func _log(s: String) -> void:
	print("[story %6.1f] %s" % [Time.get_ticks_msec() / 1000.0, s])


func _end(code: int, why: String) -> void:
	_log(("PASS " if code == 0 else "FAIL ") + why)
	_tree.quit(code)


func _wait(s: float) -> void:
	await _tree.create_timer(s, false).timeout


func _obj(prefix: String, limit := 90.0) -> void:
	var t0 := Time.get_ticks_msec()
	while not _d.objective_text.begins_with(prefix):
		if _d.dead and _mode != "caught":
			_end(2, "caught while waiting for '%s'" % prefix)
			return
		if Time.get_ticks_msec() - t0 > limit * 1000.0:
			_end(1, "objective '%s' never came (now '%s')" % [prefix, _d.objective_text])
			return
		await _tree.process_frame
	_log("objective: " + _d.objective_text)


func _walk(points: Array, speed := 2.2) -> void:
	_p.walk_path(points, speed)
	var t0 := Time.get_ticks_msec()
	while _p.walking() and Time.get_ticks_msec() - t0 < 60000:
		await _tree.process_frame
	_log("at %s" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))


func _has_toast(prefix: String) -> bool:
	return _toasts.any(func(t): return str(t[0]).begins_with(prefix))


func _at(x: float, z: float) -> Vector3:
	return Vector3(x, 0.05, z)


## Looks at `target` and presses [E] on what the player's own ray finds there: it must be `prompt`.
func _press(target: Vector3, prompt: String) -> bool:
	_p.look_at_point(target, 0.05)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900:
		await _tree.process_frame
		if _p.current_interactable and _p.current_interactable.prompt == prompt:
			break
	var it := _p.current_interactable
	if it == null or it.prompt != prompt:
		_end(1, "the [E] ray does not reach '%s' (got '%s', at %s)" % [prompt, it.prompt if it else "nothing", str(_p.global_position.snapped(Vector3.ONE * 0.1))])
		return false
	it.interact()
	_log("[E] " + prompt)
	return true


func _use(root: Node, prompt: String) -> bool:
	for it: Interactable in root.find_children("*", "Interactable", true, false):
		if it.prompt == prompt and it.enabled:
			it.interact()
			_log("[E] " + prompt)
			return true
	_log("!! no '%s' to use" % prompt)
	return false


# =========================================================================================
## `--prologue --checkpoint bridge --storytest turnaudio` (windowed: it needs the real output device; Master is muted):
## a steady tone from the bridge's PA speaker — inside the bridge's reverb zone — heard facing it and turned round to
## the wall you fell through. Fails if it is silent there (Godot's own reverb-zone path played nothing on a surround
## output) or if turning round takes it out of the front speakers (more than 9 dB down).
func _turn_audio() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), -80.0)
	while _p.cutscene:
		await _tree.process_frame
	var b: JetBridge = world.bridge
	var rate := 44100
	var data := PackedByteArray()
	data.resize(rate * 2)
	for i in rate:
		data.encode_s16(i * 2, int(sin(TAU * 300.0 * i / rate) * 12000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = rate
	# its own bus, so nothing else playing in the bridge (hums, ambience) is in the reading
	AudioServer.add_bus()
	var bus := AudioServer.bus_count - 1
	AudioServer.set_bus_name(bus, "ProbeTone")
	AudioServer.set_bus_send(bus, "Master")
	await _tree.process_frame
	var tone := AudioStreamPlayer3D.new()
	tone.stream = w
	tone.bus = "ProbeTone"
	tone.unit_size = 9.0
	tone.max_distance = 80.0
	Snd.setup_3d(tone, false)
	world.add_child(tone)
	tone.global_position = b.pa_point()
	tone.play()
	_log("speaker mode %d (%d channel pairs), panning %.2f" % [AudioServer.get_speaker_mode(), AudioServer.get_bus_channels(bus), tone.panning_strength])
	var lv := {}
	for face: String in ["facing the PA", "turned to the wall"]:
		_p.look_at_point(b.pa_point() if face == "facing the PA" else b.to_global(Vector3(0.0, 1.3, 0.0)), 0.05)
		await _wait(0.8)
		var front := 0.0
		var n := 0
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 500:
			await _tree.process_frame
			front += (db_to_linear(AudioServer.get_bus_peak_volume_left_db(bus, 0)) + db_to_linear(AudioServer.get_bus_peak_volume_right_db(bus, 0))) * 0.5
			n += 1
		lv[face] = front / maxf(n, 1)
		_log("%-18s front pair %.1f dB" % [face, linear_to_db(lv[face])])
	_log("the room the world sounds are in: %s" % Snd.room_now())
	if lv["facing the PA"] < db_to_linear(-60.0):
		_end(1, "the PA speaker is silent in the bridge (its reverb zone)")
		return
	var drop := linear_to_db(maxf(lv["turned to the wall"], 1e-9) / lv["facing the PA"])
	if drop < -9.0:
		_end(1, "turned round in the bridge, the PA is %+.1f dB in the front speakers" % drop)
		return
	_end(0, "turned round in the bridge, the PA is %+.1f dB in the front speakers" % drop)


func _prologue() -> void:
	if _mode == "turnaudio":
		await _turn_audio()
		return
	if Game.checkpoint != "chase":
		await _obj("태블릿으로 점검 목록")
		await _shot("01_start", 0.2)
		world.ui.open_tablet()
		await _wait(1.2)
		await _shot("02_checklist", 0.0)
		_log("tablet checklist rows: %d" % world.ui.tablet.checklist.size())
		world.ui.close_modal()
		_p.walk_path([Vector3(-14.2, 0.05, -15.3)], 2.2)    # setting off starts the cart beyond the door
		await _obj("소리가 난 곳")
		await _shot("03_office", 0.2)
		if _p.flashlight_on:
			_end(1, "the flashlight came on by itself (it should stay off until [F])")
			return
		# the cart behind the shut door: faint, creeping up
		await _wait(1.0)
		var shut_gain := _d.guide_gain_db
		_log("cart behind the shut door: %+.1f dB" % shut_gain)
		if shut_gain > -12.0:
			_end(1, "the cart behind the shut office door is not faint (%+.1f dB)" % shut_gain)
			return
		# out through the office door ([E] from inside), up the passage
		await _walk([Vector3(-13.7, 0.05, -16.2)], 1.6)
		_p.look_at_point(Prologue.SEC_DOOR + Vector3(0, 1.1, 0), 0.05)
		await _wait(0.2)
		if _p.current_interactable != world.terminal.sec_use:
			_end(1, "the [E] ray does not reach the office door from inside")
			return
		if _has_toast("[F]"):
			_end(1, "the flashlight hint came inside the office (it should come out in the dark passage)")
			return
		_p.current_interactable.interact()
		_log("[E] 문 열기 (office door)")
		await _wait(1.2)
		await _shot("03b_door_open", 0.0)
		_log("cart with the door open: %+.1f dB" % _d.guide_gain_db)
		if _d.guide_gain_db < -1.0:
			_end(1, "the cart is still faint with the office door open (%+.1f dB)" % _d.guide_gain_db)
			return
		await _walk([Vector3(-11.2, 0.05, -16.0)])
		await _wait(0.3)
		var hint: Array = _toasts.filter(func(t): return str(t[0]).begins_with("[F]"))
		if hint.is_empty() or (hint[0][1] as Vector3).x < Prologue.OUT_OF_OFFICE_X:
			_end(1, "no flashlight hint out in the passage (%s)" % str(hint))
			return
		_log("flashlight hint out of the office at x %.2f" % (hint[0][1] as Vector3).x)
		# louder looking its way: the cart is up the passage, to the south
		var cart_at: Vector3 = _d._guide.global_position
		_p.look_at_point(Vector3(cart_at.x, 1.6, cart_at.z), 0.05)
		await _wait(1.2)
		var toward := _d._guide.volume_db
		var me := _p.global_position
		var away_pt := me - (cart_at - me)
		_p.look_at_point(Vector3(away_pt.x, 1.6, away_pt.z), 0.05)
		await _wait(1.2)
		var away := _d._guide.volume_db
		_log("cart looking toward it %+.1f dB, away %+.1f dB" % [toward, away])
		if toward - away < 4.0:
			_end(1, "the cart is not louder looking toward it (%+.1f vs %+.1f dB)" % [toward, away])
			return
		_p.toggle_flashlight(1)                          # out into the dark passage: [F], as the toast said
		_log("[F] flashlight on")
		# to the right, the fire doors at the passage's south end: locked, they only rattle and do not let you by
		await _walk([Vector3(-11.2, 0.05, -16.0), Vector3(-11.2, 0.05, -14.5), Vector3(-11.2, 0.05, -9.1)])
		_p.look_at_point(Prologue.FIRE_DOOR + Vector3(0, 1.1, 0), 0.05)
		await _wait(0.2)
		var fd := _p.current_interactable
		if fd == null or fd == world.terminal.sec_use or fd.prompt != "문 열기":
			_end(1, "the [E] ray does not reach the locked fire doors (got '%s')" % (fd.prompt if fd else "nothing"))
			return
		fd.interact()
		_log("[E] 문 열기 (fire doors)")
		await _shot("03c_fire_locked", 0.15)
		await _wait(1.0)
		_p.walk_to(Vector3(-11.2, 0.05, -7.0), 2.2)
		await _wait(1.5)
		_p.walk_to(_p.global_position, 1.0)
		if _p.global_position.z > Prologue.FIRE_DOOR.z - 0.3:
			_end(1, "the locked fire doors let the player through")
			return
		_log("fire doors locked: still in the passage at z %.2f" % _p.global_position.z)
		await _walk([Vector3(-11.2, 0.05, -16.0), Vector3(-11.2, 0.05, -38.6), Vector3(-11.4, 0.05, -40.6)])
		_log("office door shut behind: %s" % (world.terminal.sec_leaf.rotation.y < 0.05))
		await _obj("저 사람에게")
		await _shot("04_figure", 0.1)
		await _walk([Vector3(-12.2, 0.05, -41.6)], 1.4)
		_use(world.terminal, "종잇조각 살펴보기")
		await _wait(0.5)
		var fig: CrewFigure = (_d.part as Prologue).fig
		fig.interactable.interact()
		_log("[E] 말 걸기")
		await _obj("손전등으로")
		_p.look_at_point(fig.head_position(), 0.2)
		await _wait(0.4)
		await _walk([Vector3(-12.45, 0.05, -42.75)], 1.0)
		_p.look_at_point(fig.head_position(), 0.2)
		await _wait(3.2)
		await _shot("05_turn", 0.0)
		await _obj("도망쳐라", 30.0)
		await _shot("06_broken", 0.0)
		if _mode == "caught":
			_log("standing still")
			var t0 := Time.get_ticks_msec()
			var k := 0
			while not _d.dead and Time.get_ticks_msec() - t0 < 20000:
				# with --shots: watch it come (the fold onto its hands, then the crawl), a frame every 0.3 s
				if _shots != "" and k < 14 and Time.get_ticks_msec() - t0 > 300 * (k + 1):
					_p.look_at_point(fig.head_position(), 0.01)
					k += 1
					await _shot("06d_coming_%02d" % k, 0.0)
					continue
				await _tree.process_frame
			if not _d.dead:
				_end(1, "it never caught a player standing still")
				return
			_log("caught -> dark, the game restarts at the checkpoint by itself")
			await _wait(0.8)
			await _shot("06c_caught_dark", 0.0)
			# the reloaded scene runs this test again from checkpoint "chase" and escapes; if it never reloads, fail
			await _wait(8.0)
			_end(1, "caught, but the game did not restart from the checkpoint")
			return
	else:
		await _obj("도망쳐라", 30.0)
	if _mode == "chaseturn":
		await _chase_turn()
		return
	await _wait(0.3)
	if world.terminal.sec_door.visible:
		_end(1, "the security office door is still on the passage wall in the chase")
		return
	# down the passage, right up to the fire doors at its end (they must stop you), then push them with [E]
	_p.walk_path([Vector3(-11.3, 0.05, -39.8), Vector3(-11.2, 0.05, -30.0), Vector3(-11.2, 0.05, -16.0), Vector3(-11.2, 0.05, -9.05)], 4.4)
	await _wait(2.2)
	if _shots != "":
		_p.look_at_point((_d.part as Prologue).fig.head_position(), 0.01)
		await _shot("07_behind", 0.05)
		_p.set_look(PI, 0.0)
	await _wait(1.8)
	await _shot("08_fire_door", 0.0)
	var t2 := Time.get_ticks_msec()
	while _p.walking() and Time.get_ticks_msec() - t2 < 6000:
		await _tree.process_frame
	_p.walk_to(_p.global_position, 1.0)
	await _wait(0.4)
	if _d.bridge.contains(_p.global_position) or _p.global_position.z > Prologue.FIRE_DOOR.z - 0.3:
		_end(1, "running into the fire doors took the player through")
		return
	_log("ran into the fire doors, still in the passage at z %.2f" % _p.global_position.z)
	_p.look_at_point(Prologue.FIRE_DOOR + Vector3(0, 1.1, 0), 0.05)
	await _wait(0.15)
	var it := _p.current_interactable
	if it == null or it.prompt != "문 열고 나가기":
		_end(1, "the [E] ray does not reach the fire doors (got '%s')" % (it.prompt if it else "nothing"))
		return
	await _shot("08a_door_closed", 0.0)
	it.interact()
	_log("[E] 문 열고 나가기")
	await _wait(0.2)
	await _shot("08b_door_swings", 0.0)
	await _wait(0.15)
	await _shot("08c_stumbling", 0.0)
	# the impact: out for a moment, then the eyes flutter open on the floor
	await _wait(1.15)
	if _p.eyes < 0.9:
		_end(1, "the eyes are not shut after the fall (eyes %.2f)" % _p.eyes)
		return
	await _shot("09_dark", 0.0)
	await _wait(1.05)
	await _shot("09a_waking", 0.0)
	await _wait(1.1)
	await _shot("09b_waking", 0.0)
	await _wait(1.15)
	await _shot("09c_awake", 0.0)
	await _wait(2.0)
	await _shot("10_door_gone", 0.0)
	await _wait(2.7)
	await _shot("11_getting_up", 0.0)
	while _p.cutscene:
		await _tree.process_frame
	if _p.eyes > 0.05 or _p.eyes_script >= 0.0 or not world.ui.hud.visible:
		_end(1, "up, but the eyes are not open (eyes %.2f, held %.2f) or the HUD is hidden" % [_p.eyes, _p.eyes_script])
		return
	# on your feet: the tablet (nothing waits for it) has lost you; nothing happens until you set off — a second after
	# your first step, the chime, the PA and the board
	world.ui.open_tablet()
	await _wait(1.0)
	while world.ui.tablet_locked:
		await _tree.process_frame
	await _shot("12_unknown", 0.3)
	_log("tablet lost=%s sys=%s" % [world.ui.tablet.lost, world.ui.tablet._sys.visible])
	if not world.ui.tablet.lost:
		_end(1, "the tablet did not lose the player in the boarding bridge")
		return
	world.ui.close_modal()
	await _wait(1.5)
	if Snd.pa_busy or _d.pa_clip != "":
		_end(1, "the PA started before the player set off")
		return
	var t_go := Time.get_ticks_msec()
	_p.walk_to(_p.global_position + _p.forward() * 1.2, 1.4)
	while Snd.pa_busy == false:
		await _tree.process_frame
	_log("PA chime %.1f s after the first step" % ((Time.get_ticks_msec() - t_go) / 1000.0))
	await _obj("앞으로 나아가기", 30.0)
	_log("board lit %.1f s after the first step" % ((Time.get_ticks_msec() - t_go) / 1000.0))
	await _shot("13_board", 0.2)
	# up to the gate door: a fire door chained shut, it only rattles; the key on the carpet in front of it ends the
	# prologue (the title follows a couple of seconds after the blackout, so quit at once)
	var b: JetBridge = world.bridge
	await _walk([b.door_front()], 2.2)
	await _obj("문 열기", 6.0)
	_p.look_at_point(b.gate_door.global_position + Vector3(0, 1.1, 0), 0.05)
	await _wait(0.2)
	if _p.current_interactable != b.door_use:
		_end(1, "the [E] ray does not reach the gate door")
		return
	_p.current_interactable.interact()
	_log("[E] 문 열기 (gate door, chained)")
	await _obj("열쇠 찾기", 6.0)
	if world.ui.hud._obj_head.visible:
		_end(1, "an objective is shown on the HUD (none should be)")
		return
	await _shot("13b_gate_chained", 0.1)
	if not b.locked:
		_end(1, "the chained gate door opened in the prologue")
		return
	var key: Node3D = (_d.part as Prologue).key_node
	_p.look_at_point(key.global_position, 0.1)
	await _wait(0.25)
	if _p.current_interactable == null or _p.current_interactable.prompt != "열쇠 줍기":
		_end(1, "the [E] ray does not reach the key")
		return
	await _shot("13c_key", 0.0)
	_p.current_interactable.interact()
	_log("[E] 열쇠 줍기")
	if world.ui.fade_alpha() < 0.99:
		_end(1, "picking up the key did not go black at once")
		return
	if _mode == "loop":
		_log("prologue played through to the key and the blackout; the game goes on")
		return
	_end(0, "prologue played through to the key and the blackout (SCENE 05 next)")


## `chaseturn` (from checkpoint chase): run up the passage and turn round now and then with the run key still held —
## which takes you a few steps back toward it — and watch it come: from one drawn frame to the next its body and its
## head must never move away from you (a backward step reads as it falling back and coming again).
func _chase_turn() -> void:
	var fig: CrewFigure = (_d.part as Prologue).fig
	# one run without stopping: twice a look back that carries you `--back` metres (default 2.5) toward it before you turn
	# again
	var back_m := 2.5
	var args := OS.get_cmdline_user_args()
	var bi := args.find("--back")
	if bi >= 0 and bi + 1 < args.size():
		back_m = float(args[bi + 1])
	var turns := [-34.0, -25.0]
	var pts: Array = []
	for z: float in turns:
		pts.append(Vector3(-11.2, 0.05, z))
		pts.append(Vector3(-11.2, 0.05, z - back_m))
	pts.append(Vector3(-11.2, 0.05, -16.0))
	_p.walk_path(pts, 4.4)
	var last := fig.global_position
	var last_head := fig.head_position()
	var back := 0.0
	var back_head := 0.0
	var n_back := 0
	var n_frames := 0
	var closest := 100.0
	var gaps: Array = []                  # [time s, gap m]: the gap must never open up much while it is close
	var worst_open := 0.0
	var next_log := 0.0
	var t0 := Time.get_ticks_msec()
	while _p.walking():
		if _d.dead:
			_end(2, "caught while running up the passage (closest %.1f m)" % closest)
			return
		await _tree.process_frame
		if fig._walking and fig.speed >= 3.9:               # (not the head start while it wrings itself round)
			var gap := Vector2(_p.global_position.x - fig._pos.x, _p.global_position.z - fig._pos.z).length()
			closest = minf(closest, gap)
			var now := (Time.get_ticks_msec() - t0) / 1000.0
			gaps.append([now, gap])
			while gaps.size() > 1 and now - float(gaps[0][0]) > 1.0:
				var was: Array = gaps.pop_front()
				if float(was[1]) < 6.0:
					worst_open = maxf(worst_open, gap - float(was[1]))
			if now >= next_log:
				next_log = now + 0.5
				_log("  t %.1f  you at z %.1f  it is %.1f m behind" % [now, _p.global_position.z, gap])
		var at := fig.global_position
		var head := fig.head_position()
		if at.is_equal_approx(last):
			continue
		n_frames += 1
		var to_p := _p.global_position - last
		to_p.y = 0.0
		var dir := to_p.normalized()
		var b := -(at - last).dot(dir)
		var bh := -(head - last_head).dot(dir)
		if b > 0.05 or bh > 0.12:
			n_back += 1
			_log("drawn frame moves away: body %.2f m, head %.2f m (it at z %.1f, you at z %.1f)" % [b, bh, at.z, _p.global_position.z])
		back = maxf(back, b)
		back_head = maxf(back_head, bh)
		last = at
		last_head = head
	_log("%d drawn frames, %d moved away; worst body %.2f m, head %.2f m; closest it came %.1f m; once close, the gap opened at most %.1f m in a second" % [n_frames, n_back, back, back_head, closest, worst_open])
	if n_back > 0:
		_end(1, "it was drawn moving away from the player %d times" % n_back)
		return
	if worst_open > 1.0:
		_end(1, "once it was close, the gap opened %.1f m within a second (it fell back)" % worst_open)
		return
	_end(0, "chase: it never falls back, turning round or not")


# =========================================================================================
func _ch1() -> void:
	var part := _d.part as Chapter1
	if Chapter1.STAGES.find(Game.checkpoint) > 0:
		Engine.time_scale = SPEED
		await _after_lounge(part)
		return
	var b: JetBridge = world.bridge
	# where the prologue ended: at the chained door with the key in hand
	await _obj("자물쇠 열기")
	_log("carrying %s, %.1f m from the door" % [str(Game.inventory), _p.global_position.distance_to(b.door_front())])
	if not Game.has_item("key_gate"):
		_end(1, "ch1 opens without the key the prologue ended on")
		return
	if _p.flashlight_on:
		_end(1, "ch1 opens with the flashlight on (it should start off)")
		return
	_p.look_at_point(b.gate_door.global_position + Vector3(0, 1.1, 0), 0.05)
	await _wait(0.2)
	if _p.current_interactable != b.door_use:
		_end(1, "the [E] ray does not reach the gate door")
		return
	await _shot("20_door_chained", 0.4)
	_log("door prompt: " + b.door_use.prompt)
	_p.current_interactable.interact()
	await _obj("문 너머로", 10.0)
	_p.look_at_point(b.gate_door.global_position + Vector3(0, 1.2, 0), 0.3)
	await _shot("21_open", 0.8)
	_log("carrying %s, locked=%s" % [str(Game.inventory), b.locked])
	await _walk([b.to_global(Vector3(0, 0.05, -JetBridge.LENGTH - 1.4))], 1.4)
	await _wait(0.6)
	var q := _p.global_position
	if not part._through or q.x > -20.1 or q.x < -22.4 or absf(q.z + 14.6) > 1.4 or absf(q.y) > 0.5:
		_end(1, "through the gate door but not in the vestibule outside the office (at %s)" % str(q.snapped(Vector3.ONE * 0.1)))
		return
	_log("through the gate door: in the vestibule outside the office's west door at %s" % str(q.snapped(Vector3.ONE * 0.1)))
	await _shot("22_vestibule", 0.2)
	# into the office: the west door shuts and locks behind you
	var t: Terminal = world.terminal
	await _walk([Vector3(-19.6, 0.05, -14.6), Vector3(-17.6, 0.05, -14.6)], 1.4)
	await _wait(1.0)
	if (t.sec_entry.leaf as Node3D).rotation.y > 0.05:
		_end(1, "the west door did not shut behind the player")
		return
	_log("west door shut behind")
	_p.look_at_point(Vector3(-16.6, 1.2, -20.0), 0.3)
	await _shot("23_office", 0.4)
	# the passage door is locked: it rattles and the order is to find the card
	await _walk([Vector3(-13.2, 0.05, -16.0)], 1.4)
	_p.look_at_point(Prologue.SEC_DOOR + Vector3(0, 1.1, 0), 0.05)
	await _wait(0.2)
	if _p.current_interactable != t.sec_use:
		_end(1, "the [E] ray does not reach the office's passage door")
		return
	_p.current_interactable.interact()
	_log("[E] 문 열기 (passage door, locked)")
	await _obj("키 카드 찾기", 6.0)
	await _wait(0.6)
	if world.ui.hud._obj_head.visible:
		_end(1, "an objective is shown on the HUD (none should be)")
		return
	if t.sec_leaf.rotation.y > 0.05:
		_end(1, "the locked passage door opened")
		return
	# tried again, a thought says it wants a key card — once, not on every try
	var thoughts: Array[String] = []
	var on_sub := func(kind: String, text: String, _dur: float):
		if kind == "self":
			thoughts.append(text)
	Events.subtitle.connect(on_sub)
	for k in 2:
		_p.current_interactable.interact()
		await _wait(0.4)
	Events.subtitle.disconnect(on_sub)
	_log("thoughts at the locked door: %s" % [thoughts])
	if thoughts.size() != 1 or thoughts[0] != "……키 카드가 필요한 것 같다.":
		_end(1, "trying the locked passage door again should think it needs a key card, once")
		return
	await _shot("23b_needs_card", 0.2)
	# a wrong drawer first, then the right one (the guard's desk, bottom): look, [E], the card
	await _walk([Vector3(-13.6, 0.05, -16.4), Vector3(-13.6, 0.05, -19.3), Vector3(-14.4, 0.05, -19.3)], 1.4)
	for name_text: String in ["c1", Chapter1.CARD_DRAWER]:
		var dr: Drawer = t.sec_drawers[name_text]
		var stand := dr.global_position + dr.global_basis.z * 1.0
		await _walk([Vector3(stand.x, 0.05, stand.z)], 1.0)
		_p.look_at_point(dr.global_position, 0.1)
		await _wait(0.25)
		if _p.current_interactable != dr.interactable:
			_end(1, "the [E] ray does not reach drawer %s" % name_text)
			return
		dr.interactable.interact()
		_log("[E] 서랍 열기 (%s)" % name_text)
		await _wait(0.6)
		await _shot("24_drawer_" + name_text, 0.0)
		if part._card_use and part._card_use.enabled:
			_p.look_at_point(part._card_node.global_position, 0.1)
			await _wait(0.25)
			if _p.current_interactable != part._card_use:
				_end(1, "the [E] ray does not reach the key card in drawer %s" % name_text)
				return
			_p.current_interactable.interact()
			_log("[E] 키 카드 줍기 (%s)" % name_text)
			break
		_p.look_at_point(dr.global_position, 0.1)
		await _wait(0.2)
		dr.interactable.interact()
		_log("[E] 서랍 닫기 (%s)" % name_text)
		await _wait(0.4)
	if not Game.has_item("keycard"):
		_end(1, "no key card after the drawers")
		return
	await _obj("키 카드로", 6.0)
	# the reader by the door: OK, the lock lets go, the door swings open; out into the passage
	await _walk([Vector3(-13.6, 0.05, -19.3), Vector3(-13.6, 0.05, -17.2), Vector3(-13.3, 0.05, -16.85)], 1.4)
	_p.look_at_point(t.sec_reader.global_position, 0.1)
	await _wait(0.25)
	if _p.current_interactable != t.sec_reader.interactable:
		_end(1, "the [E] ray does not reach the card reader")
		return
	await _shot("25_reader", 0.0)
	_p.current_interactable.interact()
	_log("[E] 출입카드 태그")
	await _obj("밖으로 나가기", 6.0)
	await _wait(1.2)
	await _shot("26_door_open", 0.0)
	# through the door: not the passage but the long service corridor; its door slams and locks behind you
	await _walk([Vector3(-12.9, 0.05, -16.0), Vector3(-11.2, 0.05, -16.0)], 1.4)
	await _wait(0.3)
	var hall: ServiceHall = part.hall
	if not part._in_hall or not hall.contains(_p.global_position):
		_end(1, "through the office door but not in the service corridor (at %s)" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
		return
	_log("through the office door: in the service corridor at %s" % str(hall.to_local(_p.global_position).snapped(Vector3.ONE * 0.1)))
	await _obj("복도 끝", 6.0)
	await _wait(1.6)
	if (hall.entry.leaf as Node3D).rotation.y > 0.05:
		_end(1, "the corridor's entrance door did not shut behind the player")
		return
	_log("corridor door shut behind")
	_p.look_at_point(hall.to_global(Vector3(0, 1.4, ServiceHall.LENGTH)), 0.3)
	await _shot("27_corridor", 0.6)
	if not _p.no_sprint:
		_end(1, "the sprint key still works in the corridor")
		return
	# down the corridor: a locker creaks open and the red ball bounces out; come near and it runs off into a side room,
	# then the figure before the far doors shows and is gone before you get there
	await _walk([hall.to_global(Vector3(0, 0.05, 9.0))], 2.2)
	await _wait(1.5)
	_p.look_at_point(hall.ball.global_position, 0.3)
	await _shot("27b_ball", 0.6)
	await _walk([hall.to_global(Vector3(0, 0.05, 11.2))], 1.4)
	_p.look_at_point(hall.to_global(Vector3(1.4, 0.6, ServiceHall.SIDE_DOORS[ServiceHall.BALL_DOOR])), 0.2)
	await _wait(0.9)
	await _shot("27c_ball_door", 0.0)
	await _wait(2.0)
	_p.look_at_point(hall.to_global(Vector3(0, 1.4, ServiceHall.LENGTH)), 0.3)
	await _shot("27d_figure", 0.6)
	await _walk([hall.to_global(Vector3(0, 0.05, ServiceHall.LENGTH - 1.3))], 2.2)
	if not part._ball_gone:
		_end(1, "the red ball never ran off into the side room")
		return
	if not part._figure_shown:
		_end(1, "the figure never showed at the end of the corridor")
		return
	if hall.figure.visible:
		_end(1, "the figure at the end of the corridor is still there")
		return
	_log("corridor: the ball ran off into the side room, the figure showed and was gone")
	_p.look_at_point(hall.to_global(Vector3(0, 1.1, ServiceHall.LENGTH)), 0.05)
	await _wait(0.25)
	if _p.current_interactable != hall.far_doors.use:
		_end(1, "the [E] ray does not reach the corridor's far doors")
		return
	await _shot("28_far_doors", 0.0)
	_p.current_interactable.interact()
	_log("[E] 문 열기 (the corridor's far doors)")
	await _obj("라운지로", 6.0)
	await _wait(1.4)
	await _shot("29_far_open", 0.0)
	# through them: out onto the lounge's 2F deck by its staff doors, which slam behind you
	await _walk([hall.to_global(Vector3(0, 0.05, ServiceHall.LENGTH + 2.0))], 1.4)
	await _wait(0.3)
	var arrive := _p.global_position
	var door := Terminal.DECK_DOOR
	if not part._in_lounge or absf(arrive.x - door.x) > 1.0 or absf(arrive.z - (door.z + 1.4)) > 1.0 or absf(arrive.y - door.y) > 0.5:
		_end(1, "through the corridor's far doors but not on the lounge's 2F deck (at %s)" % str(arrive.snapped(Vector3.ONE * 0.1)))
		return
	_log("through the far doors: on the lounge's deck at %s" % str(arrive.snapped(Vector3.ONE * 0.1)))
	await _obj("수속 장치", 8.0)
	await _wait(1.2)
	var ld: Array[Node3D] = (world.terminal as Terminal).lounge_door.leaves
	if absf(ld[0].rotation.y) > 0.05 or absf(ld[1].rotation.y) > 0.05:
		_end(1, "the deck's staff doors did not shut behind the player")
		return
	_p.look_at_point(Vector3(10.0, 1.0, 42.0), 0.3)
	await _shot("30_deck", 0.6)
	Engine.time_scale = SPEED
	# along the edge to the nearest down escalator and down it to the lounge floor
	var downs: Array = Terminal.escalator_units().filter(func(u: Array) -> bool: return u[1])
	downs.sort_custom(func(a: Array, b: Array) -> bool: return absf(a[0].x - door.x) < absf(b[0].x - door.x))
	var down: Vector3 = downs[0][0]
	await _walk([Vector3(down.x, 0.0, door.z + 1.5), Vector3(down.x, 0.0, Terminal.ESC_FOOT_Z + 3.5)], 2.0)
	if _p.global_position.y > 0.3:
		_end(1, "could not walk down the escalator (at %s)" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
		return
	_log("down the escalator at %s" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
	await _shot("31_lounge_floor", 0.3)
	await _walk([_at(20.9, 17.3), _at(20.9, 7.5)], 3.0)
	await _after_lounge(part)


# =========================================================================================
## From the lounge floor on: the device, the three branches, the check-in, the last run.
func _after_lounge(part: Chapter1) -> void:
	var hub := part.hub
	if _mode == "tear":
		await _tear_test(part)
		return
	if Game.checkpoint != "final":
		if not hub.seen:
			await _walk([_at(1.2, 7.5), _at(1.2, -5.9)], 3.0)
			var t0 := Time.get_ticks_msec()
			while not hub.seen and Time.get_ticks_msec() - t0 < 6000:
				await _tree.process_frame
			if not hub.seen:
				_end(1, "standing at the device did not count as seeing it")
				return
			await _shot("32_device", 0.2)
			await _wait(9.0)
			if not (part.fog as PartFog).entered() and CabinWay.way._seal != null:
				_end(1, "the cabin's door did not open after the device")
				return
		var order := "acb"
		var args := OS.get_cmdline_user_args()
		var oi := args.find("--order")
		if oi >= 0 and oi + 1 < args.size():
			order = args[oi + 1]
		for b: String in order:
			if Game.flag("done_" + b):
				continue
			match b:
				"a":
					if not await _branch_a(part):
						return
				"b":
					if not await _branch_b(part):
						return
				"c":
					if not await _branch_c(part):
						return
			await _wait(1.0)
			_log("back in the lounge after %s: %d returns, carrying %s" % [b, int(Game.flags.get("returns", 0)), str(Game.inventory)])
			await _shot("40_back_" + b, 0.3)
		await _lounge_route(_at(1.2, -5.9))
		if not await _press(PartHub.DEVICE_AT + Vector3(0, 1.3, 0.2), "수속 장치에 넣기"):
			return
		# checked_in comes at the end of the check-in announcement, which plays in real time (not at SPEED): 13-15 s
		# on a free machine, more under load, so give it room
		var t1 := Time.get_ticks_msec()
		while not hub.checked_in and Time.get_ticks_msec() - t1 < 30000:
			await _tree.process_frame
		if not hub.checked_in:
			_end(1, "all three in the device and the check-in did not complete (%s)" % str(hub._in))
			return
		_log("check-in complete; tablet passenger=%s" % world.ui.tablet.passenger)
	await _final(part)


## Across the lounge floor to `to`, round the seats and the escalators.
func _lounge_route(to: Vector3) -> void:
	if _p.global_position.y > 3.0:
		# down from the 2F by the near escalator: round its north side
		var from := _p.global_position
		var first: Array = [_at(-16.0, from.z), _at(-16.0, 3.0)] if from.x < -12.0 else [_at(from.x, 3.0)]
		await _walk(first + [_at(6.83, 3.0), Vector3(6.83, 0.0, 17.3), _at(8.2, 17.3)], 2.4)
	var q := _p.global_position
	var pts: Array = []
	if q.x > 8.0 and q.x < 8.5:
		pts.append(_at(8.2, 7.5))
	elif q.z > 9.0:
		pts.append(_at(20.9, 27.5) if q.z > 21.0 else _at(20.9, q.z))
		pts.append(_at(20.9, 7.5))
	pts.append(_at(1.2, 7.5))
	pts.append(to)
	await _walk(pts, 3.0)


func _branch_a(part: Chapter1) -> bool:
	var fog := part.fog
	_log("branch A")
	if _p.global_position.z < 9.0:
		await _walk([_at(_p.global_position.x, 7.5), _at(20.9, 7.5)], 3.0)
	await _walk([_at(20.9, 27.5), _at(-15.6, 27.5), _at(-21.65, 27.6), _at(-21.65, 30.0)], 3.0)
	await _shot("41_cabin", 0.2)
	var way := CabinWay.way
	var t0 := Time.get_ticks_msec()
	while not fog._use.enabled and Time.get_ticks_msec() - t0 < 60000:
		_p.walk_to(_p.global_position + Vector3(0, 0, 3.0), 3.0)
		await _tree.process_frame
	if not fog._use.enabled:
		_end(1, "the reading light never came on (%d turns)" % way.turns)
		return false
	_log("the reading light is on after %d turns" % way.turns)
	await _walk([_at(-21.65, PartFog.SEAT.z - 0.4)], 2.0)
	await _shot("42_reading_light", 0.4)
	if not await _press(Vector3(-21.95, 0.8, PartFog.SEAT.z), "탑승권 줍기"):
		return false
	t0 = Time.get_ticks_msec()
	while _p.global_position.x > -26.0 and Time.get_ticks_msec() - t0 < 30000:
		_p.walk_to(_p.global_position + Vector3(0, 0, 3.0), 3.0)
		await _tree.process_frame
	if _p.global_position.x > -26.0:
		_end(1, "the aisle did not let the player through after the pass")
		return false
	await _shot("43_hall", 2.0)
	await _walk([_at(-29.03, -14.0), _at(-29.03, -4.0), _at(-28.0, 20.0), _at(-27.5, 26.0)], 3.0)
	if _p.global_position.y < 3.5:
		_end(1, "did not get up to the hall's 2F deck (at %s)" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
		return false
	if not await _press(PartFog.DECK_DOOR + Vector3(0, 1.2, 0), "문 열기"):
		return false
	var t1 := Time.get_ticks_msec()
	while not Game.flag("done_a") and Time.get_ticks_msec() - t1 < 12000:
		await _tree.process_frame
	if not Game.flag("done_a"):
		_end(1, "through the deck door but branch A did not end (at %s)" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
		return false
	return true


## Up on the 2F from wherever you are in the lounge.
func _to_2f(x: float) -> void:
	var q := _p.global_position
	if q.y > 3.0:
		var way: Array = [_at(-16.0, q.z), _at(-16.0, 3.0)] if q.x < -12.0 else [_at(q.x, 3.0)]
		await _walk(way + [_at(x, 3.0)], 3.0)
		return
	await _lounge_route(_at(20.9, 7.5))
	await _walk([_at(20.9, 17.3), _at(17.17, 17.3), Vector3(17.17, 0.0, 3.0)], 2.2)
	await _walk([_at(x, 3.0)], 3.0)


func _branch_b(part: Chapter1) -> bool:
	var rep := part.repeat
	_log("branch B")
	await _to_2f(40.0)
	await _walk([_at(40.0, 3.0), _at(40.0, 17.0), _at(47.9, 17.0)], 3.0)
	var t0 := Time.get_ticks_msec()
	while not rep.room.to_local(_p.global_position).length() < 12.0 and Time.get_ticks_msec() - t0 < 6000:
		await _tree.process_frame
	await _wait(1.0)
	if rep.room.to_local(_p.global_position).length() > 12.0:
		_end(1, "at the unit's back door but not in the repeat room (at %s)" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
		return false
	await _shot("44_repeat", 0.3)
	var room := rep.room
	for k in PartRepeat.ROOMS:
		var task: Array = PartRepeat.TASKS[k]
		_log("room %d: %s" % [k, str(task)])
		await _shot("45_room_%d" % k, 0.2)
		if task[0] == "switch":
			var sw: Node3D = room.switches[task[1]]
			var q := sw.position + sw.basis.z * 1.0
			await _walk([room.to_global(Vector3(0, 0.05, -1.2)), room.to_global(Vector3(q.x, 0.05, q.z))], 2.4)
			if not await _press(sw.global_position, "스위치 올리기"):
				return false
		elif task[0] == "drawer":
			var dr: Drawer = room.desk_drawers[task[1]]
			var stand := dr.global_position + dr.global_basis.z * 0.95
			await _walk([room.to_global(Vector3(0, 0.05, -1.2)), _at(stand.x, stand.z)], 2.4)
			_p.global_position.y = room.global_position.y + 0.05
			if not await _press(dr.global_position, dr.interactable.prompt):
				return false
		else:
			await _walk([room.to_global(Vector3(0, 0.05, -1.4)), room.to_global(Vector3(-0.5, 0.05, -3.25))], 2.4)
			if not await _press(room.card_node.global_position + Vector3(0, 0.1, 0), "신원 카드 줍기"):
				return false
		await _wait(1.0)
		if not rep._unlocked:
			_end(1, "room %d's task did not unlock its door" % k)
			return false
		await _walk([room.to_global(Vector3(0, 0.05, -4.6)), room.to_global(Vector3(0, 0.05, -6.8))], 2.4)
		await _wait(0.8)
	var t1 := Time.get_ticks_msec()
	while not Game.flag("done_b") and Time.get_ticks_msec() - t1 < 10000:
		await _tree.process_frame
	if not Game.flag("done_b"):
		_end(1, "through the last room but branch B did not end (at %s)" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
		return false
	return true


func _branch_c(part: Chapter1) -> bool:
	var bags := part.bags
	_log("branch C")
	if Game.checkpoint != "baggage":
		await _lounge_route(_at(1.2, -4.0))
		await _walk([_at(4.0, -5.5), _at(11.0, -5.5)], 3.0)
		await _wait(0.6)
		await _walk([_at(14.0, -5.5), _at(20.5, -5.5)], 3.0)
	var t0 := Time.get_ticks_msec()
	while not bags._inside and Time.get_ticks_msec() - t0 < 8000:
		await _tree.process_frame
	if not bags._inside:
		_end(1, "at the shutter but not in baggage claim (at %s)" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
		return false
	await _shot("46_baggage", 0.5)
	# along the north wall to the pillar there: hugging it you are safe, and the belt comes round within reach
	await _walk([_at(-29.9, -62.5)], 3.0)
	var belt: BaggageBelt = bags._belt
	t0 = Time.get_ticks_msec()
	var rounds := 0
	var was_busy := false
	while not bags._got_tag and Time.get_ticks_msec() - t0 < 120000:
		if _d.dead:
			_end(2, "caught behind the pillar in baggage claim")
			return false
		if bags._busy and not was_busy:
			rounds += 1
		was_busy = bags._busy
		for bag: Dictionary in belt.bags:
			if bag.kind == "name":
				var node: Node3D = bag.node
				if node.global_position.distance_to(_p.global_position) < 2.5:
					_p.look_at_point(node.global_position + Vector3(0, 0.5, 0), 0.02)
					var it := _p.current_interactable
					if it and it.prompt == "가방 들어 확인하기" and it.get_parent() == node:
						it.interact()
						_log("[E] 내 가방")
		await _tree.process_frame
	if not bags._got_tag:
		_end(1, "never found the bag with the player's name on the belt (%d bags)" % belt.bags.size())
		return false
	_log("the bag tag, after %d rounds of the tearing" % rounds)
	await _walk([_at(-19.6, -62.3)], 3.0)
	if not await _press(belt.global_position + Vector3(belt.half + belt.radius - 0.2, 1.3, 0), "벨트에 올라타기"):
		return false
	var t1 := Time.get_ticks_msec()
	while not Game.flag("done_c") and Time.get_ticks_msec() - t1 < 20000:
		if _d.dead:
			_end(2, "caught riding the belt out")
			return false
		await _tree.process_frame
	if not Game.flag("done_c"):
		_end(1, "rode the belt but branch C did not end (at %s)" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
		return false
	return true


func _tear_test(part: Chapter1) -> void:
	var t1 := Time.get_ticks_msec()
	while not part.bags._inside and Time.get_ticks_msec() - t1 < 8000:
		await _tree.process_frame
	await _walk([_at(-17.0, -62.8), _at(-17.0, -50.5), _at(-19.5, -46.0)], 3.0)
	_log("standing in the open in baggage claim")
	var t0 := Time.get_ticks_msec()
	while not _d.dead and Time.get_ticks_msec() - t0 < 30000:
		await _tree.process_frame
	if not _d.dead:
		_end(1, "the tearing went by a player standing in the open")
		return
	_end(0, "the tearing had the player in the open")


func _final(part: Chapter1) -> void:
	var fin := part.final_part
	await _obj("도망쳐라", 20.0)
	await _shot("50_partition_open", 0.3)
	await _walk([_at(-1.0, -7.0), _at(-1.0, -10.0)], 3.2)
	var t0 := Time.get_ticks_msec()
	while fin.fig == null and Time.get_ticks_msec() - t0 < 5000:
		await _tree.process_frame
	if fin.fig == null:
		_end(1, "moving off did not bring it running")
		return
	_log("it is running, %.1f m behind" % _p.global_position.distance_to(fin.fig.global_position))
	await _walk([_at(1.1, -11.0), _at(1.1, -26.0), _at(-1.5, -29.0)], 4.2)
	var seen_at := -999.0
	while _p.global_position.z > PartFinal.ARRIVED_Z - 0.5 and Time.get_ticks_msec() - t0 < 60000:
		if _d.dead:
			_end(2, "caught in the corridor after %d loops" % fin.loops)
			return
		_p.walk_to(Vector3(-1.5 if _p.global_position.z > -75.0 else 0.0, 0.05, _p.global_position.z - 3.0), 4.2)
		await _tree.process_frame
	if fin.loops != PartFinal.LOOPS:
		_end(1, "the corridor came round %d times, not %d" % [fin.loops, PartFinal.LOOPS])
		return
	_log("through the corridor after %d loops, into the gate lounge" % fin.loops)
	await _shot("51_gates", 0.3)
	var t1 := Time.get_ticks_msec()
	while world.terminal.gate0_parts == null and Time.get_ticks_msec() - t1 < 12000:
		await _tree.process_frame
	if world.terminal.gate0_parts == null:
		_end(1, "Gate 0 never opened")
		return
	await _shot("52_gate0", 1.0)
	await _walk([_at(0.0, -96.0), _at(0.0, -102.0), _at(0.0, -133.5)], 3.2)
	if _p.global_position.z > -132.0:
		_end(1, "could not walk the Gate 0 bridge (at %s)" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
		return
	Engine.time_scale = 1.0
	var t2 := Time.get_ticks_msec()
	while not fin.ended and Time.get_ticks_msec() - t2 < 30000:
		if _shots != "" and _p.global_position.distance_to(Prologue.START) < 1.0 and world.ui.fade_alpha() < 0.4:
			await _shot("53_first_shot", 1.0)
			break
		await _tree.process_frame
	while not fin.ended and Time.get_ticks_msec() - t2 < 30000:
		await _tree.process_frame
	if not fin.ended:
		_end(1, "the ending never finished")
		return
	if _mode == "loop":
		_log("the whole game played to the end; the game goes on")
		return
	_end(0, "ch1: the office, the corridor, the lounge, three branches, the check-in, the run, Gate 0, the first shot")


func _look_shot(target: Vector3, name_text: String) -> void:
	_p.look_at_point(target, 0.4)
	await _wait(0.5)
	await _shot(name_text, 0.4)
