extends Node
## `-- --storytest [caught|loop]` on the game scene (headless OK, add `--prologue` or `--chapter ch1`): plays the part like a
## player — follows each objective, walks the scripted routes, presses [E] on what the objective needs — and quits
## with 0 once it has reached the end of the part (1 = an objective never came, 2 = caught when it should not be).
## `caught` stands still when the chase starts and checks that, once caught, the game restarts by itself at the checkpoint (the
## reloaded scene runs this again and escapes). `loop` plays the part but does not quit at its end, so the game goes on
## to the next scene (scripts/debug/loop_test.gd drives the whole game that way). A story test never writes the
## player's save.

var world: Node3D
var _mode := ""
var _shots := ""                 # `--shots <dir>` (windowed): a screenshot at each beat
var _d: StoryDirector
var _p: Player
var _tree: SceneTree          # kept: the test outlives its scene by a frame when the part ends in a scene change


func _ready() -> void:
	_tree = get_tree()
	var args := OS.get_cmdline_user_args()
	var i := args.find("--storytest")
	if i + 1 < args.size() and not args[i + 1].begins_with("--"):
		_mode = args[i + 1]
	_d = world.director
	_p = world.player
	var si := args.find("--shots")
	if si >= 0 and si + 1 < args.size() and DisplayServer.get_name() != "headless":
		_shots = args[si + 1]
		DirAccess.make_dir_recursive_absolute(_shots)
	_tree.create_timer(420.0).timeout.connect(func(): _end(1, "timeout at objective '%s'" % _d.objective_text))
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


func _use(root: Node, prompt: String) -> bool:
	for it: Interactable in root.find_children("*", "Interactable", true, false):
		if it.prompt == prompt and it.enabled:
			it.interact()
			_log("[E] " + prompt)
			return true
	_log("!! no '%s' to use" % prompt)
	return false


# =========================================================================================
func _prologue() -> void:
	if Game.checkpoint != "chase":
		await _obj("태블릿으로 점검 목록")
		await _shot("01_start", 0.2)
		world.ui.open_tablet()
		await _wait(1.2)
		await _shot("02_checklist", 0.0)
		_log("tablet checklist rows: %d" % world.ui.tablet.checklist.size())
		world.ui.close_modal()
		await _obj("수하물 운송 설비")
		_p.walk_path([Vector3(-2.6, 0.05, 2.0)], 2.2)
		await _obj("소리가 난 곳")
		await _shot("03_passage_mouth", 0.2)
		await _walk([Vector3(-2.6, 0.05, -1.6), Vector3(-11.2, 0.05, -6.4), Vector3(-11.2, 0.05, -12.0),
			Vector3(-11.2, 0.05, -38.6), Vector3(-11.4, 0.05, -40.6)])
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
			while not _d.dead and Time.get_ticks_msec() - t0 < 20000:
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
	await _wait(0.3)
	# run past the door first (running into its doorway must not take you in), then come back and push it with [E]
	_p.walk_path([Vector3(-11.3, 0.05, -39.8), Vector3(-11.2, 0.05, -30.0), Vector3(-11.6, 0.05, -16.0), Vector3(-11.3, 0.05, -14.6)], 4.4)
	await _wait(2.2)
	if _shots != "":
		_p.look_at_point((_d.part as Prologue).fig.head_position(), 0.01)
		await _shot("07_behind", 0.05)
		_p.set_look(PI, 0.0)
	await _wait(1.8)
	await _shot("08_security_sign", 0.0)
	while _p.walking():
		await _tree.process_frame
	if _d.bridge.contains(_p.global_position):
		_end(1, "running past the door took the player in")
		return
	_log("ran past the door, still in the passage")
	await _walk([Vector3(-11.0, 0.05, -15.9)], 4.4)
	_p.look_at_point(Prologue.SEC_DOOR + Vector3(0, 1.1, 0), 0.05)
	await _wait(0.15)
	var it := _p.current_interactable
	if it == null or it.prompt != "문 열고 들어가기":
		_end(1, "the [E] ray does not reach the door (got '%s')" % (it.prompt if it else "nothing"))
		return
	await _shot("08a_door_closed", 0.0)
	it.interact()
	_log("[E] 문 열고 들어가기")
	await _wait(0.2)
	await _shot("08b_door_swings", 0.0)
	await _wait(0.15)
	await _shot("08c_stumbling", 0.0)
	await _wait(1.9)
	await _shot("09_fallen", 0.0)
	await _wait(2.6)
	await _shot("10_door_gone", 0.0)
	await _wait(4.0)
	await _shot("11_getting_up", 0.0)
	await _obj("태블릿으로 현재 위치", 60.0)
	world.ui.open_tablet()
	await _wait(1.0)
	while world.ui.tablet_locked:
		await _tree.process_frame
	await _shot("12_unknown", 0.3)
	_log("tablet lost=%s sys=%s" % [world.ui.tablet.lost, world.ui.tablet._sys.visible])
	await _wait(0.5)
	world.ui.close_modal()
	await _obj("벽 다시 살펴보기", 20.0)
	_p.look_at_point(_d.bridge.to_global(Vector3(0, 1.2, 0.0)), 0.3)
	await _wait(0.5)
	_use(world.bridge, "벽 더듬기")
	await _obj("앞으로 나아가기", 90.0)
	await _shot("13_board", 0.2)
	# walk on toward the gate; the blackout comes on the way (the title follows a couple of seconds later, so quit at once)
	var b: JetBridge = world.bridge
	_p.walk_path([b.to_global(Vector3(0, 0.05, -JetBridge.LENGTH + 9.0))], 2.2)
	var t1 := Time.get_ticks_msec()
	while world.ui.fade_alpha() < 0.99 and Time.get_ticks_msec() - t1 < 12000:
		await _tree.process_frame
	if world.ui.fade_alpha() < 0.99:
		_end(1, "no blackout at the end of SCENE 04")
		return
	if _mode == "loop":
		_log("prologue played through to the blackout; the game goes on")
		return
	_end(0, "prologue played through to the blackout (SCENE 05 next)")


# =========================================================================================
func _ch1() -> void:
	var b: JetBridge = world.bridge
	await _obj("앞으로 나아가기")
	await _walk([b.door_front()], 2.2)
	await _obj("문 열기")
	b.door_use.interact()
	await _obj("열쇠 찾기", 10.0)
	var part := _d.part as Chapter1
	_p.look_at_point(part.key_node.global_position, 0.3)
	await _shot("20_door_key", 0.5)
	await _walk([part.key_node.global_position + Vector3(-0.3, 0, 0.6)], 1.4)
	if not _use(part.key_node, "열쇠 줍기"):
		_end(1, "no key")
		return
	_log("carrying %s" % str(Game.inventory))
	await _shot("20b_key_held", 0.6)
	await _obj("자물쇠 열기", 10.0)
	_log("door prompt: " + b.door_use.prompt)
	b.door_use.interact()
	await _obj("문 너머로", 10.0)
	_p.look_at_point(b.gate_door.global_position + Vector3(0, 1.2, 0), 0.3)
	await _shot("21_open", 0.8)
	_log("carrying %s, locked=%s" % [str(Game.inventory), b.locked])
	await _walk([b.to_global(Vector3(0, 0.05, -JetBridge.LENGTH - 1.4))], 1.4)
	await _wait(1.0)
	if not part._through:
		_end(1, "walked through the door but it did not register")
		return
	if _mode == "loop":
		_log("ch1: key, padlock, through the door; the game goes on")
		return
	_end(0, "ch1: key picked up, padlock opened, through the door")
