extends Node
## Debug bot: `godot --path . res://scenes/game.tscn -- --day 1 --autotest <outdir> [--ending exit|board|return|announce] [--mistakes]`
## Plays phases by itself (teleporting, operating facilities, reporting, applying rulebook fixes,
## obeying emergency rules), prints a log and saves screenshots. Carries on across scene changes.

var world: Node
var d: ShiftDirector
var p: Player
var t: Terminal
var out_dir := ""
var ending := "exit"
var mistakes := false
var always_wrong := false   # `--wrong`: every report is the opposite (3 판정 실수 → game over check)
var _shot := 0
var _log_prefix := ""

const VIEW := {
	"lights": [Vector3(-19.6, 0.05, 4.6), Vector3(-21.78, 1.45, 4.6)],
	"fids": [Vector3(-11.0, 0.05, -6.5), Vector3(-11.0, 4.6, -13.8)],
	"pa": [Vector3(0.0, 0.05, 7.9), Vector3(0.0, 1.1, 6.6)],
	"baggage": [Vector3(26.3, 0.05, -1.6), Vector3(35.0, 0.6, 2.5)],
	"walkway": [Vector3(-0.8, 0.05, -28.6), Vector3(-2.8, 0.2, -40.0)],
	"xray": [Vector3(-2.5, 0.05, -21.0), Vector3(-3.6, 1.24, -21.0)],
	"punch": [Vector3(-28.4, 0.05, -4.4), Vector3(-28.4, 1.35, -5.8)],
}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--autotest")
	out_dir = args[i + 1] if i >= 0 and i + 1 < args.size() and not args[i + 1].begins_with("--") else OS.get_user_data_dir() + "/autotest"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var e := args.find("--ending")
	if e >= 0 and e + 1 < args.size():
		ending = args[e + 1]
	mistakes = args.has("--mistakes")
	always_wrong = args.has("--wrong")
	Engine.time_scale = 3.0
	if ending == "return" and Game.cycle == 5 and Game.phase == "night":
		for c in RulesDB.TRUE_CLUES:
			Game.add_clue(c)
	_log_prefix = "[%s%d] " % [Game.phase, Game.cycle]
	await get_tree().create_timer(0.3).timeout
	d = world.director
	p = world.player
	t = world.terminal
	p.controls_enabled = true
	d.start()
	_watch_events()
	_run()


func log_line(s: String) -> void:
	var line := "%s%s  %s" % [_log_prefix, Game.clock_text(), s]
	print(line)
	# stdout is buffered when redirected; mirror to a file that is flushed per line
	var path := out_dir + "/bot_log.txt"
	var f := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(line)
		f.close()


func shot(tag: String) -> void:
	if DisplayServer.get_name() == "headless":
		_shot += 1
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_shot += 1
	img.save_png("%s/%s%d_%02d_%s.png" % [out_dir, Game.phase, Game.cycle, _shot, tag])


## Headless runs draw no frames (frame_post_draw never fires), so the bot files a blank photo through the same events.
func _photo() -> void:
	if DisplayServer.get_name() != "headless":
		await world.ui._shoot()
		return
	var fac := d.facility_in_view()
	var img := Image.create(16, 9, false, Image.FORMAT_RGB8)
	Game.photos.append({"image": img, "tex": ImageTexture.create_from_image(img), "label": "headless",
		"cycle": Game.cycle, "altered": false, "facility": fac.id if fac else ""})
	Game.photos_left -= 1
	Events.photo_taken.emit(Game.photos.size() - 1)
	Events.player_action.emit("photo", fac.id if fac else "")


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func goto(pos: Vector3, look: Vector3) -> void:
	p.teleport(Transform3D(Basis(), pos))
	await get_tree().physics_frame
	p.look_at_point(look, 0.01)
	await wait(0.15)


func _heartbeat() -> void:
	while is_inside_tree():
		await get_tree().create_timer(5.0, true, false, true).timeout
		var cur := d.current.title if d and d.current else "-"
		log_line("♥ cur=%s radio_busy=%s pa_busy=%s modal=%s paused=%s ts=%.1f fps=%d" % [cur, d._radio_busy, Snd.pa_busy, world.ui.modal, get_tree().paused, Engine.time_scale, Engine.get_frames_per_second()])


func _run() -> void:
	_heartbeat()
	while true:
		await wait(0.3)
		if d.dead:
			log_line("!!! DIED  mistakes=%d/%d  erosion=%d" % [d.mistakes, ShiftDirector.MAX_MISTAKES, int(Game.erosion)])
			await shot("death")
			await wait(1.0)
			get_tree().quit(2)
			return
		if d.ending_started:
			log_line("ENDING STARTED")
			await wait(3.0)
			await shot("ending_start")
			return
		var task := d.current
		if task == null:
			if Game.phase == "night" and Game.cycle == 5 and d.script_obj.get("finale"):
				await _finale_choice()
				return
			continue
		if task.kind == "goal":
			await _do_goal(task)
		else:
			await _do_inspect(task)


# --- goals -----------------------------------------------------------------------------------
func _do_goal(task: Task) -> void:
	log_line("GOAL  " + task.title)
	var title := task.title
	if "바인더" in title:
		await _pick("binder")
	elif "FIDS 출발 전광판 촬영" in title:
		await goto(VIEW.fids[0], VIEW.fids[1])
		var fv := d.facility_in_view()
		log_line("  in view: %s  fwd=%s  photos_left=%d" % [fv.id if fv else "none", p.forward(), Game.photos_left])
		await _photo()
		await shot("fids_day")
		log_line("  photos: %s" % [Game.photos.map(func(x): return x.get("facility", "?"))])
	elif "표준 문안" in title:
		await goto(VIEW.pa[0], VIEW.pa[1])
		(t.facility("pa") as PaConsole)._on_test()
		await _until(func(): return task.state == "done", 60.0)
	elif "B-03 시운전" in title:
		await goto(VIEW.baggage[0], VIEW.baggage[1])
		(t.facility("baggage") as BaggageBelt).press_start()
		await _until(func(): return task.state == "done", 40.0)
		await shot("belt_day")
		await _photo()
	elif "개정 수칙" in title:
		await goto(Vector3(-24.2, 0.05, -3.6), Vector3(-23.3, 0.9, -4.6))
		await _pick_prefix("fax_")
	elif "조명 분전반 확인" in title:
		await goto(VIEW.lights[0], VIEW.lights[1])
		t.lights_panel.switches["hall"]._on_used()
		await wait(1.5)
		t.lights_panel.switches["hall"]._on_used()
	elif "보안검색 데스크 서류" in title:
		await _pick("log2")
	elif "전 구역 순회" in title:
		await goto(Vector3(0, 0.05, -82.0), Vector3(0, 1.8, -100.0))
		await shot("day5_gates")
	elif "X-ray 1번 시운전" in title:
		await goto(VIEW.xray[0], VIEW.xray[1])
		(t.facility("xray") as XrayMachine)._on_scan()
		await _until(func(): return task.state == "done", 30.0)
		await _photo()
	elif "MW-1 시운전" in title:
		await goto(VIEW.walkway[0], VIEW.walkway[1])
		(t.facility("walkway") as MovingWalkway).press_start()
		await _until(func(): return task.state == "done", 30.0)
		await shot("walkway_day")
	elif "야간 조명 배분" in title:
		Game.night_lights = {"hall": true, "baggage": true, "security": false, "corridor": true, "gates": false}
		Events.player_action.emit("power_plan", "")
	elif "탑승 게이트 구역 확인" in title:
		var g: BoardingGate = t.facility("gate03")
		await goto(g.to_global(Vector3(0, 0.05, 7.5)), g.focus_position())
		g._on_check()
		await shot("gate_day")
	elif "시설관리실 복귀" in title:
		await goto(Vector3(-20.8, 0.05, 1.55), Vector3(-21.78, 1.25, 1.55))
		d._on_office_reader(t.readers.office_out)
		await _until(func(): return task.state == "done", 120.0)
		await shot("reclassified")
	elif "퇴근" in title or "근무 종료" in title:
		await goto(VIEW.punch[0], VIEW.punch[1])
		await shot("before_punch")
		var got := [false]
		var mark := func(): got[0] = true
		d.punched.connect(mark, CONNECT_ONE_SHOT)
		d._on_punch()
		await wait(0.3)
		if not got[0]:
			log_line("  !! clock-out refused (regression: the time clock must end the phase)")
			await shot("clock_out_refused")
			get_tree().quit(3)
			return
		await _after_punch()
	# goals finish once the phase script has heard the radio out — don't redo the action meanwhile
	await _until(func(): return task.state == "done" or d.current != task, 90.0)
	await wait(0.5)


func _pick_prefix(prefix: String) -> void:
	for n in t.get_children():
		if n is Pickup and (n as Pickup).item_id.begins_with(prefix):
			await _pick((n as Pickup).item_id)
			return
	log_line("pickup not found: " + prefix + "*")


func _pick(id: String) -> void:
	for n in t.get_children():
		if n is Pickup and (n as Pickup).item_id == id:
			await goto(n.global_position + Vector3(0.9, 0, 0.9), n.global_position)
			(n as Pickup).interactable.interact()
			await wait(0.6)
			if world.ui.modal == "doc":
				world.ui._close_reader()
			return
	log_line("pickup not found: " + id)


func _after_punch() -> void:
	log_line("PUNCHED OUT")
	if Game.phase == "night":
		await _until(func(): return world.ui._fade_layer.get_child_count() > 1, 30.0)
		await wait(2.0)
		await shot("morning_report")
		world.ui.report_closed.emit()


# --- inspections ---------------------------------------------------------------------------------
func _do_inspect(task: Task) -> void:
	var f := t.facility(task.facility_id)
	log_line("INSPECT %s  [%s]  anomaly=%s" % [task.title, task.facility_id, f.anomaly])
	if f is BoardingGate:
		# far enough back that a seated "passenger" never comes within reach
		await goto(f.to_global(Vector3(-1.0, 0.05, 11.5)), f.focus_position())
	elif VIEW.has(task.facility_id):
		await goto(VIEW[task.facility_id][0], VIEW[task.facility_id][1])
	# activate
	if f is LightPanel:
		for zn in ["hall", "baggage"]:
			if not t.zones[zn].is_on:
				t.lights_panel.switches[zn]._on_used()
	elif f is PaConsole:
		if f.anomaly == "pa_slow" and not mistakes:
			p.look_at_point(p.global_position + Vector3(0, 1.6, 10), 0.01)
		elif f.anomaly == "pa_word" and not mistakes:
			pass
		if f.anomaly != "pa_auto":
			await _until(func(): return not Snd.pa_busy, 60.0)   # a story announcement may still be on air
		(f as PaConsole)._on_test()
		if f.anomaly == "pa_word" and not mistakes:
			await wait(2.0)
			(f as PaConsole)._on_stop()
	elif f is BaggageBelt:
		if not f.running:
			(f as BaggageBelt).press_start()
	elif f is MovingWalkway:
		if not f.running:
			(f as MovingWalkway).press_start()
	elif f is XrayMachine:
		(f as XrayMachine)._on_scan()
	elif f is BoardingGate:
		(f as BoardingGate)._on_check()
	if f is PaConsole and f.anomaly == "pa_slow":
		await _until(func(): return not Snd.pa_busy, 40.0)
		p.look_at_point(f.focus_position(), 0.01)
	var ok := await _until(func(): return task.observed or task.state != "active" or task.locked != "", 45.0)
	if not ok and task.state == "active" and task.locked == "" and f.is_observable():
		# fixed viewpoint was out of range/sight: step to a spot 6 m from the facility's focus and look at it
		var fp := f.focus_position()
		var away := Vector3(p.global_position.x - fp.x, 0, p.global_position.z - fp.z)
		away = away.normalized() if away.length() > 0.1 else Vector3(0, 0, 1)
		log_line("  harness: re-positioning to observe %s" % task.facility_id)
		var spot := Vector3(fp.x, 0.05, fp.z) + away * 6.0
		if f is MovingWalkway:
			spot = Vector3(fp.x + 4.0, 0.05, fp.z)   # beside the belt, never on it
		await goto(spot, fp)
		ok = await _until(func(): return task.observed or task.state != "active" or task.locked != "", 30.0)
	if task.locked != "":
		log_line("  task locked: " + task.locked)
		if f is BaggageBelt:
			await wait(3.0)
			(f as BaggageBelt).press_stop()
			await _until(func(): return task.locked == "", 30.0)
			await _until(func(): return task.observed, 40.0)
	if not task.observed and task.state == "active":
		var diag := "powered=%s state=%s" % [f.powered, f.describe_state()]
		if f is XrayMachine:
			diag += " scanned=%s monitor=%s tray=%.2f→%.2f running=%s" % [f.scanned, f.monitor_on, f._tray_t, f._tray_target, f.running]
		log_line("  !! never observed (observable=%s) %s" % [f.is_observable(), diag])
		await shot("not_observed_" + task.facility_id)
		return
	await shot("observe_" + task.facility_id)
	var anomaly := task.anomaly if task.anomaly != "" and (f.anomaly != "" or task.fix_done) else ""
	if task.state == "active":
		var claim := anomaly != ""
		if (mistakes and randf() < 0.3) or always_wrong:
			claim = not claim
		log_line("  report %s" % ("ANOMALY" if claim else "NORMAL"))
		d.report(task, claim)
	if task.state == "responding":
		await _apply_fix(f, task.anomaly)
	await _until(func(): return task.state == "done", 40.0)
	log_line("  -> result=%s  erosion=%d" % [task.result, int(Game.erosion)])


func _apply_fix(f: Facility, a: String) -> void:
	var def := AnomalyDB.get_def(a)
	var fix: Array = def.fix[0]
	log_line("  fix: %s %s" % [fix[0], fix[1]])
	match fix[0]:
		"lights_cycle":
			var zn: String = (f as LightPanel).anomaly_zone
			t.lights_panel.switches[zn]._on_used()
			await wait(8.5)
			t.lights_panel.switches[zn]._on_used()
		"lights_off":
			var zn2: String = (f as LightPanel).anomaly_zone if f is LightPanel else "gates"
			if f is BoardingGate:
				zn2 = "gates"
			if t.zones[zn2].is_on:
				t.lights_panel.switches[zn2]._on_used()
		"reset":
			(f as FidsBoard)._on_reset()
		"power_off":
			await goto(Vector3(-25.2, 0.05, -4.6), Vector3(-25.2, 1.5, -5.8))
			t.breaker.switches[fix[1]]._on_used()
			await wait(1.0)
			t.breaker.switches[fix[1]]._on_used()
		"pa_stop":
			(f as PaConsole)._on_test()
			await wait(2.0)
			(f as PaConsole)._on_stop()
		"pa_still_survived":
			(f as PaConsole)._on_test()
			await _until(func(): return not Snd.pa_busy, 90.0)
			log_line("  pa_extra stillness: total=%.1f moved=%.2f anomaly=%s" % [d._pa_still_total, d._pa_still_moved, f.anomaly])
		"pa_slow_survived":
			p.look_at_point(p.global_position + Vector3(0, 1.6, 10), 0.01)
			(f as PaConsole)._on_test()
			await _until(func(): return not Snd.pa_busy, 40.0)
		"estop":
			if f is BaggageBelt:
				(f as BaggageBelt).press_estop()
			elif f is MovingWalkway:
				(f as MovingWalkway).press_estop()
			elif f is XrayMachine:
				(f as XrayMachine)._on_estop()
		"stop":
			(f as MovingWalkway).press_stop()
		"eyes_closed_near":
			Input.action_press("close_eyes")
			await wait(9.0)
			Input.action_release("close_eyes")
		"close_gate":
			(f as BoardingGate)._on_lock()
		"face_away_from_passenger":
			var pp := (f as BoardingGate).passenger_position()
			p.look_at_point(p.camera.global_position * 2.0 - pp, 0.01)
			await wait(9.5)
	await wait(1.0)


# --- emergency rules ---------------------------------------------------------------------------------
func _watch_events() -> void:
	while is_inside_tree():
		await wait(0.1)
		if d == null or d.dead:
			continue
		match d.running_event:
			"blackout":
				log_line("EVENT blackout → eyes closed")
				Input.action_press("close_eyes")
				await _until(func(): return d.running_event != "blackout", 40.0)
				Input.action_release("close_eyes")
			"namecall":
				log_line("EVENT name call → stand still")
				await shot("namecall")
				await _until(func(): return d.running_event != "namecall", 40.0)
			"3am":
				log_line("EVENT 3am → stay in a lit zone (lit=%s)" % d.player_zone_lit())
				if not d.player_zone_lit():
					await goto(Vector3(-28, 0.05, 0), Vector3(-33, 1, 0))
				await _until(func(): return d.running_event != "3am", 40.0)
			"slowpa":
				log_line("EVENT slow PA → face south")
				p.look_at_point(p.camera.global_position + Vector3(0, 0, 10), 0.01)
				await _until(func(): return d.running_event != "slowpa", 40.0)


# --- night 5 finale: pick one of the four endings ---------------------------------------------------
func _finale_choice() -> void:
	log_line("FINALE → ending " + ending + "  erosion=%d lever=%s arrival=%s" % [int(Game.erosion), d.main_power_enabled, Game.flag("arrival_ready")])
	await wait(4.0)
	await goto(Vector3(0, 0.05, -90.0), Vector3(0, 2.5, -110))
	await shot("gate0_open")
	match ending:
		"board":
			await goto(Vector3(0, 0.05, -125.0), Vector3(0, 1.4, -136))
			await shot("jet_bridge")
			await goto(Vector3(0, 0.05, -134.4), Vector3(0, 1.4, -136))
		"return":
			await goto(VIEW.pa[0], VIEW.pa[1])
			await shot("arrival_button")
			var pa: PaConsole = t.facility("pa")
			pa._arrival_button.interact()
		"announce":
			Game.add_erosion(100.0)
		_:
			await goto(Vector3(44.5, 0.05, 10.4), Vector3(45.8, 1.3, 10.4))
			d._on_keypad_code("1103")
			await wait(2.0)
			await goto(Vector3(55.5, 0.05, 9.0), Vector3(57.8, 1.4, 9.0))
			d.t.syslog_terminal.interact()
			await wait(1.0)
			await shot("syslog")
			if world.ui.modal == "doc":
				world.ui._close_reader()
			d._on_main_power()
			await wait(4.0)
			await goto(Vector3(17, 0.05, 11.5), Vector3(17, 1.5, 14))
			await shot("emergency_exit")
			d._on_exit_door()
			await wait(1.5)
			await goto(Vector3(17, 0.05, 16.0), Vector3(17, 1.5, 20))
	await _until(func(): return d.ending_started, 60.0)
	log_line("ENDING STARTED: " + ending)


func _until(cond: Callable, timeout: float) -> bool:
	var e := 0.0
	while not cond.call():
		await get_tree().create_timer(0.1).timeout
		e += 0.1
		if e > timeout:
			log_line("  (timeout)")
			return false
	return true
