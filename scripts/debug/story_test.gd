extends Node
## `-- --storytest [caught|tear|loop]` on the game scene (headless OK, add `--prologue` or `--chapter ch1`, and
## `--checkpoint hub|baggage|final` to start further on): plays the part like a player — follows each beat, walks the
## routes, presses [E] on what it needs through the player's own ray — and quits with 0 once it has reached the end of
## the part (1 = a beat never came, 2 = caught when it should not be). `--order acb` picks the order of the three
## branches. `caught` stands still when the chase starts and checks that, once caught, the game restarts by itself at
## the checkpoint (the reloaded scene runs this again and escapes). `tear` (--checkpoint baggage) stands in the open in
## baggage claim and checks it has you. `loop` plays the part but does not quit at its end, so the game goes on to the
## next scene (scripts/debug/loop_test.gd drives the whole game that way). A story test never writes the player's save.
## The game: with no chapter it plays Shift1 (the prologue) to the end — the dead lift, the handover, the camera, the
## power room, the lift breaking down, the escape lever, passing out; `--chapter shift1 --checkpoint lift` with `lift`
## rides and escapes from the checkpoint, with `liftfail` lets the minute run out (the car falls, the reloaded scene
## checks you are back at the lift); `--chapter wake` comes round in the lift and walks out into the dark corridor.
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
	elif Game.chapter == "prologue":
		await _prologue()
	elif Game.chapter == "wake":
		await _wake()
	elif Game.checkpoint == "lift" and _mode in ["lift", "liftfail"]:
		await _shift1_lift()
	else:
		await _shift1()


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


## A to-do line as the HUD shows it: its [b] marks (yellow) taken out.
func _plain(s: String) -> String:
	return s.replace("[b]", "").replace("[/b]", "")


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
		# out through the office door (its only one, the west door: [E] from inside), out into the passage
		await _walk([Vector3(-19.5, 0.05, -16.5), Vector3(-21.2, 0.05, Terminal.SEC_ENTRY_Z)], 1.6)
		_p.look_at_point((world.terminal.sec_entry.root as Node3D).global_position + Vector3(0, 1.1, 0), 0.05)
		await _wait(0.2)
		if _p.current_interactable != world.terminal.sec_entry.use:
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
		await _walk([Vector3(-23.6, 0.05, Terminal.SEC_ENTRY_Z)], 1.6)       # through it: out in the passage
		if _p.global_position.x < Prologue.OUT_OF_OFFICE_X:
			_end(1, "through the office door but not out in the staff passage (at %s)" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
			return
		_log("through the office door: in the passage at %s" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
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
	if not part._through or q.x > Terminal.SEC_LEG.position.x - 0.1 or q.x < Terminal.SEC_ENTRY_PLANE.x - 0.4 or absf(q.z - Terminal.SEC_ENTRY_Z) > 1.4 or absf(q.y) > 0.5:
		_end(1, "through the gate door but not in the vestibule outside the office (at %s)" % str(q.snapped(Vector3.ONE * 0.1)))
		return
	_log("through the gate door: in the vestibule outside the office's west door at %s" % str(q.snapped(Vector3.ONE * 0.1)))
	await _shot("22_vestibule", 0.2)
	# into the office by its west door (its only door): it shuts and locks behind you
	var t: Terminal = world.terminal
	await _walk([Vector3(-20.8, 0.05, Terminal.SEC_ENTRY_Z), Vector3(-19.4, 0.05, -17.2), Vector3(-18.0, 0.05, -17.2)], 1.4)
	await _wait(1.0)
	if (t.sec_entry.leaf as Node3D).rotation.y > 0.05:
		_end(1, "the west door did not shut behind the player")
		return
	_log("west door shut behind")
	_p.look_at_point(Vector3(-16.6, 1.2, -20.0), 0.3)
	await _shot("23_office", 0.4)
	# the key card door (west) is locked: it rattles and the order is to find the card
	await _walk([Vector3(-19.5, 0.05, -16.5), Vector3(-21.2, 0.05, Terminal.SEC_ENTRY_Z)], 1.4)
	var west: Node3D = t.sec_entry.root
	_p.look_at_point(west.global_position + Vector3(0, 1.1, 0), 0.05)
	await _wait(0.2)
	if _p.current_interactable != t.sec_entry.use:
		_end(1, "the [E] ray does not reach the office's key card door")
		return
	_p.current_interactable.interact()
	_log("[E] 문 열기 (the key card door, locked)")
	await _obj("키 카드 찾기", 6.0)
	await _wait(0.6)
	if world.ui.hud._obj_head.visible:
		_end(1, "an objective is shown on the HUD (none should be)")
		return
	if (t.sec_entry.leaf as Node3D).rotation.y > 0.05:
		_end(1, "the locked key card door opened")
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
		_end(1, "trying the locked key card door again should think it needs a key card, once")
		return
	await _shot("23b_needs_card", 0.2)
	# a wrong drawer first, then the right one (the guard's desk, bottom): look, [E], the card
	await _walk([Vector3(-19.5, 0.05, -16.6), Vector3(-17.3, 0.05, -17.2)], 1.4)
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
	# the reader by the west door: OK, the lock lets go, the door swings open; out into the corridor past it
	await _walk([Vector3(-17.3, 0.05, -17.2), Vector3(-19.5, 0.05, -16.5), Vector3(-21.45, 0.05, -15.55)], 1.4)
	_p.look_at_point(t.sec_reader.global_position, 0.1)
	await _wait(0.25)
	if _p.current_interactable != t.sec_reader.interactable:
		_end(1, "the [E] ray does not reach the card reader")
		return
	await _shot("25_reader", 0.0)
	_p.current_interactable.interact()
	_log("[E] 출입카드 태그")
	await _obj("밖으로 나가기", 6.0)
	await _wait(1.6)
	await _shot("26_door_open", 0.0)
	# through the door: not the dark vestibule but the service corridor; its door slams and locks behind you
	await _walk([Vector3(-21.6, 0.05, Terminal.SEC_ENTRY_Z), Vector3(-23.5, 0.05, Terminal.SEC_ENTRY_Z)], 1.4)
	await _wait(0.3)
	var hall: ServiceHall = part.hall
	if not part._in_hall or not hall.contains(_p.global_position):
		_end(1, "through the office door but not in the service corridor (at %s)" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
		return
	_log("through the office door: in the service corridor at %s" % str(hall.to_local(_p.global_position).snapped(Vector3.ONE * 0.1)))
	await _obj("1층으로", 6.0)
	await _wait(1.6)
	if (hall.entry.leaf as Node3D).rotation.y > 0.05:
		_end(1, "the corridor's entrance door did not shut behind the player")
		return
	_log("corridor door shut behind")
	_p.look_at_point(hall.to_global(Vector3(-23.65, 1.4, -24.0)), 0.3)
	await _shot("27_corridor", 0.6)
	if not _p.no_sprint:
		_end(1, "the sprint key still works in the corridor")
		return
	# north up the corridor past the office's windows, along the north arm's and down the last run to the lift
	# (nothing happens on the way any more)
	var far := ServiceHall.FAR
	await _walk([hall.to_global(Vector3(-23.65, 0.05, Terminal.SEC_VIEW_W[0]))], 2.2)
	_p.look_at_point(hall.to_global(Vector3(Terminal.SEC_LEG.position.x, 1.7, Terminal.SEC_VIEW_W[0])), 0.3)
	await _shot("27e_office_window", 0.6)
	await _walk([hall.to_global(Vector3(-23.65, 0.05, -24.75)), hall.to_global(Vector3(far.x, 0.05, -24.75)),
			hall.to_global(Vector3(far.x - 0.5, 0.05, far.z - 1.3))], 2.2)
	_log("corridor: walked through to the lift")
	# the lift at the run's end, down to the lounge on 1F (the stairs are --lift-test's)
	var lift: Lift = (world.terminal as Terminal).lift
	if not await _press((lift.cars[0].call as Node3D).global_position, "엘리베이터 부르기"):
		return
	var t_call := Time.get_ticks_msec()
	while not (lift.doors_open and not lift.busy) and Time.get_ticks_msec() - t_call < 8000:
		await _tree.process_frame
	if not lift.doors_open:
		_end(1, "the lift's doors did not open at 4F")
		return
	await _shot("28_lift", 0.0)
	var car0: Node3D = lift.cars[0].root
	await _walk([hall.to_global(far + Vector3(0, 0.05, -0.5)), car0.global_transform * Vector3(0.2, 0.05, -0.9)], 1.4)
	if not lift.is_inside(0):
		_end(1, "could not step into the lift (at %s)" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
		return
	if not await _press((lift.cars[0].go as Node3D).global_position, "1층 누르기"):
		return
	var t_ride := Time.get_ticks_msec()
	while not (lift.at == 1 and lift.doors_open and not lift.busy) and Time.get_ticks_msec() - t_ride < 20000:
		await _tree.process_frame
	await _shot("29_lift_open", 0.0)
	var arrive := _p.global_position
	if not part._in_lounge or not lift.is_inside(1):
		_end(1, "the lift did not bring the player down to the lounge (at %s)" % str(arrive.snapped(Vector3.ONE * 0.1)))
		return
	_log("down in the lift: in the lounge's car at %s" % str(arrive.snapped(Vector3.ONE * 0.1)))
	var car1: Node3D = lift.cars[1].root
	await _walk([car1.global_transform * Vector3(0, 0.05, 0.6), _at(Terminal.HALL_E - 2.5, Terminal.LIFT_Z)], 1.6)
	if _p.global_position.x > Terminal.HALL_E - 1.5 or absf(_p.global_position.y) > 0.3:
		_end(1, "could not step out of the lift into the lounge (at %s)" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
		return
	await _obj("수속 장치", 8.0)
	_p.look_at_point(Vector3(-3.0, 1.2, 20.0), 0.3)
	await _shot("30_lounge_1f", 0.6)
	Engine.time_scale = SPEED
	_log("out of the lift on the lounge floor at %s" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
	await _shot("31_lounge_floor", 0.3)
	await _walk([_at(Terminal.HALL_E - 2.5, NORTH_AISLE), _at(MID_LANE, NORTH_AISLE)], 3.0)
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
			await _walk([_at(MID_LANE, NORTH_AISLE), _at(MID_LANE, -4.0), _at(1.2, -5.9)], 3.0)
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


## The lounge's walking lanes (since it was cut down to 37 x 32 m): the north aisle under the 2F's edge, a south lane
## past the ends of the escalators' side rails (1.2 m out past the foot) and short of the down unit's side of their
## out-of-service clutter, north of the seats the nose threw (the cabin's door is at its west end), the lane between
## the north seat blocks (it runs on through the strip's opening), and the 2F's north gallery.
const NORTH_AISLE := 3.8
const SOUTH_LANE := 13.6
const MID_LANE := 1.25
const GALLERY_Z := 0.0


## Across the lounge floor to `to`, round the seats and the escalators: from among the seats on the glass side out
## along the east wall, then by the lanes above.
func _lounge_route(to: Vector3) -> void:
	if _p.global_position.y > 3.0:
		# down from the 2F by the down escalator: round its north side
		var from := _p.global_position
		var first: Array
		if from.x < -15.0:
			first = [_at(-17.5, from.z), _at(-17.5, GALLERY_Z)]
		elif from.x > 3.0 and from.z > 2.5:
			first = [_at(5.5, from.z), _at(5.5, GALLERY_Z)]
		else:
			first = [_at(from.x, GALLERY_Z)]
		var down: float = Terminal.escalator_units().filter(func(u: Array) -> bool: return u[1])[0][0].x
		await _walk(first + [_at(down, GALLERY_Z), Vector3(down, 0.0, SOUTH_LANE), _at(down + 1.6, SOUTH_LANE)], 2.4)
	var q := _p.global_position
	var pts: Array = []
	if q.z > 16.0:
		pts += [_at(Terminal.HALL_E - 1.7, q.z), _at(Terminal.HALL_E - 1.7, SOUTH_LANE)]
	elif q.z > 9.0:
		pts += [_at(q.x, SOUTH_LANE)]
	elif q.z < -2.5:
		pts += [_at(MID_LANE, -4.0)]
	else:
		pts += [_at(q.x, NORTH_AISLE)]
	var south := q.z > 9.0
	if to.z > 9.0:
		if not south:
			pts += [_at(MID_LANE, NORTH_AISLE), _at(MID_LANE, SOUTH_LANE)]
		pts += [_at(to.x, SOUTH_LANE)]
	else:
		if south:
			pts += [_at(MID_LANE, SOUTH_LANE)]
		pts += [_at(MID_LANE, NORTH_AISLE)]
		if to.z < -2.5:
			pts += [_at(MID_LANE, -4.0)]
	pts.append(to)
	await _walk(pts, 3.0)


func _branch_a(part: Chapter1) -> bool:
	var fog := part.fog
	_log("branch A")
	await _lounge_route(_at(-16.0, SOUTH_LANE))
	await _walk([_at(-19.0, CabinWay.DOOR_Z), _at(-21.65, CabinWay.DOOR_Z + 0.1), _at(-21.65, CabinWay.DOOR_Z + 2.5)], 3.0)
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
		var way: Array = [_at(-17.5, q.z), _at(-17.5, GALLERY_Z)] if q.x < -15.0 else [_at(q.x, GALLERY_Z)]
		await _walk(way + [_at(x, GALLERY_Z)], 3.0)
		return
	var up: float = Terminal.escalator_units().filter(func(u: Array) -> bool: return not u[1])[0][0].x
	await _lounge_route(_at(up + 3.0, SOUTH_LANE))
	await _walk([_at(up, SOUTH_LANE), Vector3(up, 0.0, GALLERY_Z - 0.5)], 2.2)
	await _walk([_at(x, GALLERY_Z)], 3.0)


func _branch_b(part: Chapter1) -> bool:
	var rep := part.repeat
	_log("branch B")
	# up on the 2F and along its east gallery into unit e2, to the door in its back wall
	var e2 := Shops.frame(Shops.UNITS[6])
	var gx := (Terminal.ATRIUM.end.x + Terminal.HALL_E) * 0.5
	await _to_2f(gx)
	await _walk([_at(gx, GALLERY_Z), _at(gx, e2.origin.z), _at(Terminal.HALL_E + 4.4, e2.origin.z)], 3.0)
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


# =========================================================================================
## The game (Shift1): the letter, the corridor at the lift (its doors shut behind you), round the corridors to the
## office's door, through it, and the supervisor's handover line by line. In `loop` mode it then leaves to the main
## menu (as the pause menu does).
func _shift1() -> void:
	var part := _d.part as Shift1
	var t: Terminal = world.terminal
	var hall := t.service_hall
	if _shots != "":
		await _wait(9.4)
		await _shot("49_letter", 0.0)
	await _obj("시설관리팀", 40.0)
	var q := hall.to_local(_p.global_position)
	if q.distance_to(Shift1.START_LOCAL) > 0.6:
		_end(1, "the game does not start before the lift (at %s)" % str(q.snapped(Vector3.ONE * 0.1)))
		return
	_log("at the lift, back to it: %s" % str(q.snapped(Vector3.ONE * 0.1)))
	await _shot("50_start", 0.4)
	await _wait(3.0)
	if t.lift.doors_open:
		_end(1, "the lift's doors did not shut behind the player")
		return
	_log("lift doors shut behind")
	var hud: Hud = world.ui.hud
	if hud._clock.is_visible_in_tree():
		_end(1, "the clock is on screen (it should be gone)")
		return
	var want: Array[String] = ["[ ] " + Shift1.TASK_FIND, "[ ] " + Shift1.TASK_TALK]
	if not hud._task_box.visible or hud.task_lines() != want:
		_end(1, "the to-do list should read %s (got %s)" % [want, hud.task_lines()])
		return
	_log("to-do: %s" % [hud.task_lines()])
	# no controls guide on screen at the start, and [Tab] opens nothing yet
	if hud._keys.visible:
		_end(1, "the controls guide (bottom left) is on screen at the start")
		return
	var tab0 := InputEventAction.new()
	tab0.action = "tablet"
	tab0.pressed = true
	Input.parse_input_event(tab0)
	await _wait(0.4)
	if world.ui.modal != "":
		_end(1, "[Tab] opened '%s' before the guidelines were found" % world.ui.modal)
		return
	await _shot("50b_todo", 0.0)
	# the lift is dead: its call button beeps, you think it through, and two lines join the to-do list
	var thought: Array[String] = []
	var on_self := func(kind: String, text: String, _dur: float):
		if kind == "self":
			thought.append(text)
	Events.subtitle.connect(on_self)
	_p.look_at_point((t.lift.cars[0].call as Node3D).global_position, 0.3)
	t.lift._call(0)
	await _wait(1.0)
	await _shot("50c_lift_thought", 0.0)
	await _wait(2.8)
	Events.subtitle.disconnect(on_self)
	if t.lift.doors_open:
		_end(1, "the lift opened (it should have no power)")
		return
	if thought.size() != 2 or thought[0] != Shift1.LIFT_THOUGHT[0] or thought[1] != Shift1.LIFT_THOUGHT[1]:
		_end(1, "pressing the dead lift's button should think %s (got %s)" % [Shift1.LIFT_THOUGHT, thought])
		return
	var want4: Array[String] = ["[ ] " + Shift1.TASK_FIND, "[ ] " + Shift1.TASK_TALK, "[ ] " + Shift1.TASK_POWER_FIND, "[ ] " + Shift1.TASK_POWER_ON]
	if hud.task_lines() != want4:
		_end(1, "after the dead lift the to-do list should read %s (got %s)" % [want4, hud.task_lines()])
		return
	_log("the lift is dead; thought %s; to-do %s" % [thought, hud.task_lines()])
	if _p.no_sprint:
		_end(1, "you cannot run in the corridors ([SHIFT] should work there)")
		return
	await _shot("50d_power_todo", 0.0)
	# north up the last run, east along the north arm's windows, south down the west corridor to the office's door
	var ez := Terminal.SEC_ENTRY_Z
	await _walk([hall.to_global(Vector3(-36.1, 0.05, -24.75)), hall.to_global(Vector3(-23.65, 0.05, -24.75)),
			hall.to_global(Vector3(-23.65, 0.05, ez))], 2.2)
	_p.look_at_point((hall.entry.root as Node3D).global_position + Vector3(0, 1.1, 0), 0.05)
	await _wait(0.25)
	if _p.current_interactable != hall.entry.use:
		_end(1, "the [E] ray does not reach the office's door from the corridor")
		return
	_p.current_interactable.interact()
	_log("[E] 문 열기 (the office's door, from the corridor)")
	await _wait(0.4)
	if _tl(hud) != ["[x] " + Shift1.TASK_FIND, "[ ] " + Shift1.TASK_TALK]:
		_end(1, "opening the office's door did not tick '%s' (%s)" % [Shift1.TASK_FIND, _tl(hud)])
		return
	_log("to-do after the door: %s" % [_tl(hud)])
	await _shot("51a_ticked", 0.0)
	await _wait(0.8)
	await _shot("51_door_open", 0.0)
	await _walk([hall.to_global(Vector3(-21.4, 0.05, ez))], 1.4)
	await _wait(0.3)
	if not part.in_office or _p.global_position.x < -22.4 or absf(_p.global_position.y) > 0.3:
		_end(1, "through the office's door but not in the office (at %s)" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
		return
	_log("in the office at %s" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
	await _walk([Vector3(-20.6, 0.05, -16.6)], 1.4)
	await _wait(2.5)
	if (t.sec_entry.leaf as Node3D).rotation.y > 0.05:
		_end(1, "the office's door did not shut behind the player")
		return
	_log("the door shut behind")
	if _tl(hud) != ["[ ] " + Shift1.TASK_TALK]:
		_end(1, "the ticked line did not go, leaving '%s' (%s)" % [Shift1.TASK_TALK, _tl(hud)])
		return
	_log("to-do once in: %s" % [_tl(hud)])
	# the supervisor at the deepest desk (the north arm's west end): [E] till he has said it all
	var boss := part.boss
	await _walk([Vector3(-21.0, 0.05, -18.0), Vector3(-21.0, 0.05, -30.7), Vector3(-24.0, 0.05, -30.7)], 1.6)
	_p.look_at_point(boss.global_position + Vector3(0, 1.1, 0), 0.05)
	await _wait(0.3)
	if _p.current_interactable != boss.use:
		_end(1, "the [E] ray does not reach the supervisor (got '%s')" % (_p.current_interactable.prompt if _p.current_interactable else "nothing"))
		return
	var heard: Array[String] = []
	var on_sub := func(kind: String, text: String, _dur: float):
		if kind == "npc":
			heard.append(text)
	Events.subtitle.connect(on_sub)
	for i in OfficeNpc.LINES.size() + 1:
		boss.use.interact()
		await _wait(0.7)
		if i == 0:
			if _tl(hud) != ["[x] " + Shift1.TASK_TALK]:
				_end(1, "starting the talk did not tick '%s' (%s)" % [Shift1.TASK_TALK, _tl(hud)])
				return
			await _shot("52a_talk_ticked", 0.0)
		if i == 2:
			await _shot("52_boss", 0.0)
		if i == 5 and not _tl(hud).is_empty():
			_end(1, "the to-do list is still up after its last line was ticked (%s)" % [_tl(hud)])
			return
		# the radio changes hands on its line: in your belongings, and a toast says so
		if i == OfficeNpc.RADIO_LINE - 1 and Game.has_item("radio"):
			_end(1, "the radio was handed over before its line")
			return
		if i == OfficeNpc.RADIO_LINE:
			if not Game.has_item("radio") or not _has_toast("무전기를 받았다"):
				_end(1, "no radio (or no toast) on the radio line (items %s)" % [Game.inventory])
				return
			_log("the radio handed over on: %s" % OfficeNpc.LINES[i])
			await _shot("52b_radio", 0.0)
	_log("the supervisor said %d lines: %s" % [heard.size(), heard[0] if not heard.is_empty() else ""])
	if not boss.talked or heard.size() != OfficeNpc.LINES.size():
		_end(1, "the handover did not play line by line (%d lines, talked=%s)" % [heard.size(), boss.talked])
		return
	# the next things to do, on the to-do list
	await _wait(1.2)
	var after: Array[String] = []
	for task: String in Shift1.TASKS_AFTER:
		after.append("[ ] " + _plain(task))
	if _tl(hud) != after:
		_end(1, "after the talk the to-do list should read %s (got %s)" % [after, _tl(hud)])
		return
	_log("to-do after the talk: %s" % [_tl(hud)])
	await _shot("52c_tasks", 0.0)
	boss.use.interact()
	await _wait(0.5)
	Events.subtitle.disconnect(on_sub)
	if heard.size() != OfficeNpc.LINES.size() + 1:
		_end(1, "talking to him again says nothing")
		return
	# no flashlight yet: [F] does nothing and its hint is hidden
	if _p.flashlight_owned or hud._flash_hint.visible:
		_end(1, "the flashlight works (or its [F] hint shows) before it has been found")
		return
	# changing locker 04 on the north arm's north wall: open it, [E] on the uniform, change
	await _wait(0.4)
	await _walk([Vector3(-21.3, 0.05, -30.6), Vector3(-19.6, 0.05, -30.15)], 1.4)
	var lk: Dictionary = t.sec_locker
	_p.look_at_point((lk.use as Interactable).global_position, 0.05)
	await _wait(0.3)
	if _p.current_interactable != lk.use:
		_end(1, "the [E] ray does not reach locker 04 (got '%s')" % (_p.current_interactable.prompt if _p.current_interactable else "nothing"))
		return
	_p.current_interactable.interact()
	await _wait(0.9)
	_p.look_at_point((lk.hang as Node3D).global_position + Vector3(0, -0.32, 0), 0.05)
	await _wait(0.3)
	if _p.current_interactable != part._uniform_use:
		_end(1, "the [E] ray does not reach the uniform in the open locker (got '%s')" % (_p.current_interactable.prompt if _p.current_interactable else "nothing"))
		return
	await _shot("52d_locker", 0.0)
	_p.current_interactable.interact()
	await _wait(4.0)
	if not part.changed or not Game.flag("uniform") or not _p.controls_enabled or not _has_toast("직원복으로 갈아입었다"):
		_end(1, "changing into the uniform did not finish (changed=%s)" % part.changed)
		return
	_log("changed into the uniform")
	await _shot("52e_changed", 0.0)
	# the flashlight on the guard's desk
	await _walk([Vector3(-20.4, 0.05, -29.0), Vector3(-20.7, 0.05, -26.95), Vector3(-20.7, 0.05, -22.0),
			Vector3(-20.6, 0.05, -17.7), Vector3(-18.0, 0.05, -17.85)], 1.4)
	_p.look_at_point(part._light_node.global_position + Vector3(0, 0.02, 0), 0.1)
	await _wait(0.3)
	if _p.current_interactable != part._light_use:
		var rq := PhysicsRayQueryParameters3D.create(_p.camera.global_position, _p.camera.global_position - _p.camera.global_basis.z * Player.INTERACT_RANGE, Geo.LAYER_WORLD | Geo.LAYER_INTERACT)
		rq.exclude = [_p.get_rid()]
		var hit := _p.get_world_3d().direct_space_state.intersect_ray(rq)
		_end(1, "the [E] ray does not reach the flashlight on the desk (got '%s'; the ray hits %s at %s)" % [
			_p.current_interactable.prompt if _p.current_interactable else "nothing",
			(hit.collider as Node).get_path() if hit else "nothing", str(hit.position) if hit else "-"])
		return
	await _shot("52f_flashlight", 0.0)
	_p.current_interactable.interact()
	await _wait(0.5)
	if not part.has_light or not _p.flashlight_owned or not Game.has_item("flashlight") or not hud._flash_hint.visible:
		_end(1, "picking up the flashlight did not hand it over")
		return
	_p.toggle_flashlight(1)
	await _wait(3.0)
	if _tl(hud) != ["[ ] " + _plain(Shift1.TASK_GUIDE)] or not _has_toast("[F] 손전등"):
		_end(1, "after the uniform and the flashlight the to-do list should read only '%s' (%s)" % [Shift1.TASK_GUIDE, _tl(hud)])
		return
	_log("flashlight found; to-do: %s" % [_tl(hud)])
	await _shot("52g_light_on", 0.0)
	_p.toggle_flashlight(0)
	# out of the office and back in: he has gone to rest, asleep on the night-duty room's bed, and only snores
	await _wait(0.4)
	await _walk([Vector3(-20.6, 0.05, -16.6), Vector3(-21.5, 0.05, ez)], 1.6)
	_p.look_at_point((t.sec_entry.root as Node3D).global_position + Vector3(0, 1.1, 0), 0.05)
	await _wait(0.25)
	if _p.current_interactable != t.sec_entry.use:
		_end(1, "the [E] ray does not reach the office's door from inside")
		return
	_p.current_interactable.interact()
	await _wait(0.9)
	await _walk([Vector3(-23.6, 0.05, ez)], 1.4)
	await _wait(0.3)
	if not hall.contains(_p.global_position):
		_end(1, "out through the office's door but not in the corridor (at %s)" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
		return
	if not part.boss.asleep:
		_end(1, "the manager is not asleep on the bed once you have left the office")
		return
	_log("out in the corridor; the manager has gone to bed")
	# round to the records room at E's end: its door, the third aisle, the folder on its shelf
	await _walk([hall.to_global(Vector3(-23.65, 0.05, -11.75)), hall.to_global(Vector3(-11.15, 0.05, -11.75)),
			hall.to_global(Vector3(ArchiveRoom.DOOR_X, 0.05, -20.4))], 2.0)
	var ad: Dictionary = hall.doors_by["자료실"]
	_p.look_at_point((ad.root as Node3D).global_position + Vector3(0, 1.1, 0), 0.05)
	await _wait(0.3)
	if _p.current_interactable != ad.use:
		_end(1, "the [E] ray does not reach the records room's door")
		return
	await _shot("53a_archive_door", 0.0)
	_p.current_interactable.interact()
	await _wait(1.0)
	var gx := ArchiveRoom.guide_xform()
	var a3: float = ArchiveRoom.AISLES[2]
	await _walk([hall.to_global(Vector3(ArchiveRoom.DOOR_X, 0.05, -22.4)), hall.to_global(Vector3(a3, 0.05, -22.5)),
			hall.to_global(Vector3(a3 + 0.15, 0.05, gx.origin.z))], 1.6)
	_p.look_at_point(hall.to_global(gx * Vector3(0, Shift1.GUIDE_H * 0.5, 0)), 0.1)
	await _wait(0.3)
	if _p.current_interactable != part._guide_use:
		_end(1, "the [E] ray does not reach the guidelines on their shelf (got '%s')" % (_p.current_interactable.prompt if _p.current_interactable else "nothing"))
		return
	await _shot("53b_guide", 0.0)
	_p.current_interactable.interact()
	await _wait(3.2)
	if not part.has_guide or not Game.has_item("guide") or not _has_toast("지침서를 찾았다") or not _tl(hud).is_empty():
		_end(1, "taking the guidelines did not finish the list (%s)" % [_tl(hud)])
		return
	_log("the guidelines taken; the to-do list is done")
	if not _has_toast("[TAB] 지침서"):
		_end(1, "no notice that [Tab] opens the guidelines")
		return
	# the manager comes running from your right and talks
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 12000 and not (part._runner and part._runner.talking):
		await _tree.process_frame
	var runner := part._runner
	if runner == null or not runner.talking:
		_end(1, "the manager did not come running up and start talking")
		return
	var gap := Vector2(runner.global_position.x - _p.global_position.x, runner.global_position.z - _p.global_position.z).length()
	if gap > 2.0:
		_end(1, "the manager stopped %.1f m away (should be right by you)" % gap)
		return
	_log("the manager ran up (%.1f m away) and talks" % gap)
	_p.look_at_point(runner.global_position + Vector3(0, 1.6, 0), 0.2)
	await _wait(0.4)
	await _shot("53c_manager", 0.0)
	# he holds out a camera; it is yours on its line (and not before), a toast says so
	if runner._held == null or Game.has_item("camera"):
		_end(1, "the manager should be holding out a camera (held %s, camera in hand %s)" % [runner._held, Game.has_item("camera")])
		return
	for k in Shift1.ARCHIVE_LINES.size():
		runner.use.interact()
		await _wait(0.3)
		if k == Shift1.CAMERA_LINE - 1:
			if not Game.has_item("camera") or not _has_toast("카메라를 받았다") or runner._held != null:
				_end(1, "no camera handed over on its line (items %s)" % [Game.inventory])
				return
			_log("the camera handed over on: %s" % Shift1.ARCHIVE_LINES[Shift1.CAMERA_LINE])
			await _shot("53c2_camera", 0.0)
	if runner.talking:
		_end(1, "the manager's talk did not end")
		return
	# [Tab] opens the guidelines now (it did nothing before), and closes them
	var tab := InputEventAction.new()
	tab.action = "tablet"
	tab.pressed = true
	Input.parse_input_event(tab)
	await _wait(0.5)
	if world.ui.modal != "guide":
		_end(1, "[Tab] did not open the guidelines (modal '%s')" % world.ui.modal)
		return
	await _shot("53d_guide_open", 0.2)
	Input.parse_input_event(tab)
	await _wait(0.4)
	if world.ui.modal != "":
		_end(1, "[Tab] did not close the guidelines")
		return
	_log("[Tab] opens and closes the guidelines")
	# the camera on the mouse: a toast says so; the right button takes it out (the viewfinder), the left takes a
	# shot, the right again puts it away
	var rmb := false
	for ev in InputMap.action_get_events("camera"):
		rmb = rmb or (ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT)
	if not _has_toast("[우클릭] 카메라") or not _p.camera_owned or not rmb:
		_end(1, "no camera on the right mouse button (toast %s, owned %s, bound %s)" % [_has_toast("[우클릭] 카메라"), _p.camera_owned, rmb])
		return
	var click := func(button: MouseButton):
		var e := InputEventMouseButton.new()
		e.button_index = button
		e.pressed = true
		Input.parse_input_event(e)
		var u := InputEventMouseButton.new()
		u.button_index = button
		u.pressed = false
		Input.parse_input_event(u)
	click.call(MOUSE_BUTTON_RIGHT)
	await _wait(0.4)
	if not _p.camera_mode or not hud._viewfinder.visible:
		_end(1, "the right mouse button did not take the camera out")
		return
	var shots0 := Game.photos.size()
	click.call(MOUSE_BUTTON_LEFT)
	await _wait(0.6)
	await _shot("53e_camera_up", 0.0)
	if Game.photos.size() != shots0 + 1:
		_end(1, "the left mouse button with the camera out took no photo")
		return
	click.call(MOUSE_BUTTON_RIGHT)
	await _wait(0.4)
	if _p.camera_mode or hud._viewfinder.visible:
		_end(1, "the right mouse button again did not put the camera away")
		return
	_log("right click takes the camera out and puts it away; left click took a shot")
	# out of the records room and down E to the power room: its door ticks the first power line, the lift panel's
	# handle the second
	var power := hall.power_room
	await _walk([hall.to_global(Vector3(a3, 0.05, -22.4)), hall.to_global(Vector3(ArchiveRoom.DOOR_X, 0.05, -22.4)),
			hall.to_global(Vector3(ArchiveRoom.DOOR_X, 0.05, -20.0)), hall.to_global(Vector3(-11.1, 0.05, PowerRoom.DOOR_Z))], 2.0)
	if not await _press((power.door.root as Node3D).global_position + Vector3(0, 1.1, 0), "문 열기"):
		_end(1, "the [E] ray does not reach the power room's door")
		return
	await _wait(0.5)
	if hud.task_lines() != ["[x] " + Shift1.TASK_POWER_FIND, "[ ] " + Shift1.TASK_POWER_ON]:
		_end(1, "opening the power room's door did not tick '%s' (%s)" % [Shift1.TASK_POWER_FIND, hud.task_lines()])
		return
	await _shot("54a_power_door", 0.0)
	await _walk([hall.to_global(Vector3(-9.3, 0.05, PowerRoom.DOOR_Z + 0.2)), hall.to_global(Vector3(-8.05, 0.05, PowerRoom.DOOR_Z))], 1.4)
	await _shot("54b_power_room", 0.2)
	if not await _press(power.lever_use.global_position, "승강기 전원 올리기"):
		_end(1, "the [E] ray does not reach the lift panel's handle")
		return
	await _wait(0.9)
	if not t.lift.powered or t.lift.locked or not part.lift_powered:
		_end(1, "throwing the lift panel's handle did not give the lift its power back")
		return
	if hud.task_lines().size() != 1 or hud.task_lines()[0] != "[x] " + Shift1.TASK_POWER_ON:
		_end(1, "powering the lift did not tick '%s' (%s)" % [Shift1.TASK_POWER_ON, hud.task_lines()])
		return
	_log("the lift has power; to-do %s" % [hud.task_lines()])
	await _shot("54c_power_on", 0.0)
	await _wait(2.2)
	if hud._task_box.visible:
		_end(1, "the to-do list is still up after its last line was ticked (%s)" % [hud.task_lines()])
		return
	# all the way back round to the lift
	await _walk([hall.to_global(Vector3(-9.3, 0.05, PowerRoom.DOOR_Z + 0.2)), hall.to_global(Vector3(-11.1, 0.05, PowerRoom.DOOR_Z)),
			hall.to_global(Vector3(-11.15, 0.05, -11.75)), hall.to_global(Vector3(-23.65, 0.05, -11.75)),
			hall.to_global(Vector3(-23.65, 0.05, -24.75)), hall.to_global(Vector3(-36.1, 0.05, -24.75)),
			hall.to_global(ServiceHall.FAR + Vector3(-0.4, 0.05, -1.6))], 2.4)
	if not await _lift_ride(part, true):
		return
	if _mode == "loop":
		_log("the prologue is over; on to the title")
		Game.finish_shift1()
		return
	_end(0, "shift1: the letter, the dead lift, the corridors, the office's door, the handover, the camera, the power room, the breakdown, passed out")


## The to-do list without the two power lines (they stay up from the start until the power room).
func _tl(hud: Hud) -> Array[String]:
	var out: Array[String] = []
	for l: String in hud.task_lines():
		if not l.ends_with(Shift1.TASK_POWER_FIND) and not l.ends_with(Shift1.TASK_POWER_ON):
			out.append(l)
	return out


## Calls the lift (at 4F, with power), steps in, presses 1: it breaks down RIDE_BREAK s in (red light, alarm, the floor
## screen scrambled); `escape`: turns the escape box's latch and pulls the lever — the car stops and you pass out
## (Shift1.prologue_over); else waits for the minute to run out (Shift1.failed). False (and the test ended) on a fault.
func _lift_ride(part: Shift1, escape: bool) -> bool:
	var lift: Lift = world.terminal.lift
	var hall := world.terminal.service_hall as ServiceHall
	if not lift.doors_open:
		if not await _press((lift.cars[0].call as Node3D).global_position, "엘리베이터 부르기"):
			_end(1, "the [E] ray does not reach the lift's call button")
			return false
		var t0 := Time.get_ticks_msec()
		while not (lift.doors_open and not lift.busy) and Time.get_ticks_msec() - t0 < 8000:
			await _tree.process_frame
		if not lift.doors_open:
			_end(1, "the lift with power did not open when called")
			return false
	var c0: Node3D = lift.cars[0].root
	await _walk([hall.to_global(ServiceHall.FAR + Vector3(0, 0.05, -0.5)), c0.global_transform * Vector3(-0.2, 0.05, -1.1)], 1.6)
	if not lift.is_inside(0):
		_end(1, "not in the lift's car (at %s)" % str(_p.global_position.snapped(Vector3.ONE * 0.1)))
		return false
	await _shot("55a_car", 0.3)
	if not await _press((lift.cars[0].buttons[1] as Node3D).global_position, "1층 누르기"):
		_end(1, "the [E] ray does not reach the car's 1 button")
		return false
	var t1 := Time.get_ticks_msec()
	while not part.emergency and Time.get_ticks_msec() - t1 < 12000:
		await _tree.process_frame
	if not part.emergency:
		_end(1, "the lift did not break down on the way down")
		return false
	var secs := (Time.get_ticks_msec() - t1) / 1000.0
	await _wait(0.5)
	var lamp: OmniLight3D = lift.cars[0].lights[0]
	var shown: String = (lift.cars[0].screen[0] as Label3D).text
	if lamp.light_color.g > 0.2 or not part._siren or not part._siren.playing or shown in ["3", "4", "1"]:
		_end(1, "the breakdown is not red / has no alarm / shows a real floor (light %s, siren %s, screen '%s')" % [lamp.light_color, part._siren, shown])
		return false
	_log("broke down %.1f s after the doors shut; screen '%s'" % [secs, shown])
	await _shot("55b_breakdown", 0.0)
	var esc: Dictionary = lift.cars[0].escape
	if not escape:
		return true
	_p.look_at_point((esc.root as Node3D).global_position, 0.3)
	await _wait(0.5)
	await _shot("55c_escape_box", 0.0)
	for k in Shift1.LATCH_TURNS:
		if not await _press((esc.lock_use as Node3D).global_position, "잠금 풀기"):
			_end(1, "the [E] ray does not reach the escape box's latch (turn %d)" % (k + 1))
			return false
		await _wait(0.35)
	await _wait(0.4)
	if not part.lid_open:
		_end(1, "%d turns did not open the escape box (turns %d)" % [Shift1.LATCH_TURNS, part.latch_turns])
		return false
	await _shot("55d_box_open", 0.0)
	if not await _press((esc.lever_use as Node3D).global_position, "레버 당기기"):
		_end(1, "the [E] ray does not reach the escape lever")
		return false
	var t2 := Time.get_ticks_msec()
	while not part.prologue_over and Time.get_ticks_msec() - t2 < 15000:
		await _tree.process_frame
	if not part.prologue_over or part.failed:
		_end(1, "pulling the lever did not stop the car and knock you out")
		return false
	_log("the lever pulled %.1f s into the breakdown; the car stopped, passed out" % part.emergency_t)
	return true


## After the prologue (Wake): you come round on the lift's floor, its doors open by themselves, you get up; the car
## is still red, the corridors dark with a green glow and fog on the floor. Walk out.
func _wake() -> void:
	var part := _d.part as Wake
	var t: Terminal = world.terminal
	var hall := t.service_hall
	await _wait(2.0)
	await _shot("60_coming_round", 0.0)
	var t0 := Time.get_ticks_msec()
	while not part.awake and Time.get_ticks_msec() - t0 < 25000:
		await _tree.process_frame
	if not part.awake or not part.doors_open or not t.lift.doors_open:
		_end(1, "did not come round in the lift with its doors open (awake %s, doors %s)" % [part.awake, t.lift.doors_open])
		return
	if not t.lift.is_inside(0) or _p.view_drop > 0.01 or not _p.controls_enabled:
		_end(1, "not up on your feet in the car (view_drop %.2f)" % _p.view_drop)
		return
	if (t.lift.cars[0].lights[0] as OmniLight3D).light_color.g > 0.2 or hall.zone.is_on:
		_end(1, "the car should still be red and the corridors dark")
		return
	for id: String in ["radio", "flashlight", "guide", "camera"]:
		if not Game.has_item(id):
			_end(1, "lost '%s' between the prologue and waking (items %s)" % [id, Game.inventory])
			return
	_log("came round; the doors open on the dark corridor")
	await _shot("61_awake", 0.2)
	await _walk([hall.to_global(ServiceHall.FAR + Vector3(0, 0.05, -1.0)), hall.to_global(ServiceHall.FAR + Vector3(0, 0.05, -4.0))], 1.4)
	if not hall.contains(_p.global_position) or t.lift.is_inside(0):
		_end(1, "could not walk out of the lift into the corridor")
		return
	_p.look_at_point(hall.to_global(Vector3(-36.1, 1.2, -18.0)), 0.3)
	await _wait(0.6)
	await _shot("62_corridor", 0.0)
	_p.look_at_point(hall.to_global(ServiceHall.FAR + Vector3(0, 1.3, 0.5)), 0.3)
	await _wait(0.6)
	await _shot("63_lift_behind", 0.0)
	if _mode == "loop":
		_log("woke up in the lift; back to the main menu")
		Game.go_menu()
		return
	_end(0, "wake: came round in the lift, the doors open, out into the dark corridor")


## From the checkpoint before the ride (`--chapter shift1 --checkpoint lift`): `lift` rides, escapes and passes out;
## `liftfail` rides and lets the minute run out (at 6x) — the car falls and the game starts again at the lift, which
## the reloaded scene (this test again) checks.
func _shift1_lift() -> void:
	var part := _d.part as Shift1
	var t: Terminal = world.terminal
	if Engine.has_meta("liftfail_restarted"):
		Engine.remove_meta("liftfail_restarted")
		await _wait(1.5)
		var q := t.service_hall.to_local(_p.global_position)
		if Game.checkpoint != "lift" or q.distance_to(Shift1.START_LOCAL) > 0.6 or not t.lift.powered or not t.lift.doors_open:
			_end(1, "after the fall the game did not start again at the lift (checkpoint '%s', at %s, powered %s)" % [Game.checkpoint, q, t.lift.powered])
			return
		_end(0, "liftfail: the car fell after the minute; back at the lift with its power on")
		return
	await _wait(1.6)
	if not t.lift.powered or not part.lift_powered:
		_end(1, "at the checkpoint the lift should have its power")
		return
	if not await _lift_ride(part, _mode == "lift"):
		return
	if _mode == "lift":
		_end(0, "lift: the breakdown, the escape box, passed out")
		return
	Engine.time_scale = 6.0
	var t0 := Time.get_ticks_msec()
	while not part.failed and Time.get_ticks_msec() - t0 < 30000:
		await _tree.process_frame
	Engine.time_scale = 1.0
	if not part.failed:
		_end(1, "the car did not fall when the minute ran out (%.1f s)" % part.emergency_t)
		return
	_log("the minute ran out: the car falls")
	await _shot("56_fall", 0.0)
	Engine.set_meta("liftfail_restarted", true)
