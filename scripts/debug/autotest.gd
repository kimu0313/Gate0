extends Node
## Debug bot: `godot --path . res://scenes/game.tscn -- --day 1 --autotest <outdir> [--ending exit|board|announce]
## [--mistakes|--wrong] [--leave-power-off]`. Plays the dawn shifts by itself (teleporting, operating facilities, reporting, applying
## rulebook fixes, obeying emergency rules), prints a log and saves screenshots. Carries on across scene changes.
## The DAY 5 ending comes from the judgment record; `--ending` seeds the record on DAY 5 so each one can be reached.

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

## Facilities with a fixed viewpoint: Terminal spots "view_<id>" (feet) and "look_<id>".
const VIEW := ["lights", "fids", "pa", "baggage", "walkway", "xray", "punch"]


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
	if Game.cycle == Game.MAX_CYCLE:
		match ending:
			"board":
				Game.stats["fake_followed"] = 1
			"announce":
				Game.stats["violations"] = int(Game.stats.get("violations", 0)) + 1
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
	if Game.cycle == 1:
		# the arrival scene: card reader, door, walking in to the colleague
		for k in 8:
			await wait(1.25)
			await shot("arrive_%d" % k)
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
			continue
		if task.kind == "goal":
			await _do_goal(task)
		else:
			await _do_inspect(task)


# --- goals -----------------------------------------------------------------------------------
func _do_goal(task: Task) -> void:
	log_line("GOAL  " + task.title)
	if Game.cycle <= 2:
		await wait(0.6)
		await shot("quest_" + task.id)   # the order panel and the green diamond, from wherever the last order left us
	var title := task.title
	if "태블릿 열어 보기" in title:
		await wait(1.0)
		world.ui.open_tablet()
		await wait(1.5)
		await shot("tablet_first")
		world.ui.close_modal()
	elif "바인더 펼쳐 보기" in title:
		await wait(1.0)
		world.ui.open_binder()
		await wait(1.5)
		await shot("binder_first")
		world.ui.close_modal()
	elif "교대 근무자" in title:
		# walk up to the colleague and step through the handover with [E]; the day's items change hands
		var n := d.npc
		if n:
			var to := (p.global_position - n.global_position)
			to.y = 0.0
			to = to.normalized() if to.length() > 0.1 else Vector3(1, 0, 0)
			await goto(n.global_position + to * 1.6 + Vector3(0, 0.05, 0), n.head_position())
			var presses := 0
			while task.state != "done" and presses < 40 and is_instance_valid(n):
				if world.ui.modal == "doc":
					await shot("handover_doc")
					world.ui._close_reader()
				n.interactable.interact()
				presses += 1
				await wait(1.2)
				if presses <= 3:
					await shot("colleague_%d" % presses)
			log_line("  handover talk: %d presses" % presses)
	elif "탑승동 출입" in title:
		var reader: CardReader = d.script_obj.get("_reader")
		await goto(reader.global_position + reader.global_basis.z * 1.1 + Vector3(0, -1.2, 0), reader.global_position)
		reader.interactable.interact()
		await wait(0.5)
		await shot("card_denied")
	elif "승객 통로" in title:
		var md := t.spot("md_east")
		await goto(md + Vector3(0, 0.05, 1.6), md + Vector3(0, 1.2, -3.0))
		await goto(md + Vector3(0, 0.05, -0.4), md + Vector3(0, 1.2, -3.0))
		await _until(func(): return Game.flag("passenger_lane"), 10.0)
		await shot("passenger_lane")
	elif "0번 게이트 앞으로" in title:
		await _finale_choice()
		return
	elif task.target != null and not ("퇴근" in title or "근무 종료" in title):
		await _use_target(task)
	elif "퇴근" in title or "근무 종료" in title:
		await goto(t.spot("view_punch"), t.spot("look_punch"))
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


## Story goals name what to use (Task.target): walk up to it and press [E] until the goal is done, closing
## whatever documents it opens (the DAY 4 drawer opens two in a row).
func _use_target(task: Task) -> void:
	var tries := 0
	while task.state != "done" and tries < 8 and not d.dead:
		var tg := task.target
		if not is_instance_valid(tg):
			await wait(0.5)
			tries += 1
			continue
		var it: Interactable = tg as Interactable if tg is Interactable else ((tg as Pickup).interactable if tg is Pickup else null)
		if it == null or not is_instance_valid(it):
			log_line("  !! goal target is not usable: " + task.title)
			return
		var at := it.global_position
		var away := Vector3(p.global_position.x - at.x, 0, p.global_position.z - at.z)
		away = away.normalized() if away.length() > 0.1 else Vector3(1, 0, 0)
		await goto(Vector3(at.x, 0.05, at.z) + away * 1.2, at)
		if it.enabled:
			it.interact()
		await wait(1.2)
		var closes := 0
		while world.ui.modal == "doc" and closes < 5:
			if closes == 0:
				await shot("doc_" + str(Game.clues.keys().back() if not Game.clues.is_empty() else ""))
			world.ui._close_reader()
			await wait(1.0)
			closes += 1
		tries += 1
		await wait(0.5)
	log_line("  used %s (%d tries) -> %s" % [task.title, tries, task.state])


## DAY 1: the rule page waiting at a facility goes into the binder first.
func _pick_page_near(f: Facility) -> void:
	for n in t.get_children():
		if n is Pickup and (n as Pickup).item_id.begins_with("page_") and n.global_position.distance_to(f.focus_position()) < 8.0:
			log_line("  page " + (n as Pickup).item_id)
			await _pick((n as Pickup).item_id)
			return


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
	if Game.cycle <= 2:
		await wait(0.6)
		await shot("quest_" + task.id)
	if Game.cycle == 1:
		await _pick_page_near(f)
	if f is BoardingGate:
		# far enough back that a seated "passenger" never comes within reach
		await goto(f.to_global(Vector3(-1.0, 0.05, 11.5)), f.focus_position())
	elif task.facility_id in VIEW:
		await goto(t.spot("view_" + task.facility_id), t.spot("look_" + task.facility_id))
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
			spot = Vector3(fp.x - 3.0, 0.05, fp.z)   # beside the belt (west, MW-2 is on the east), never on it
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
		await _report_on_tablet(task, claim)
	if task.state == "responding":
		await _apply_fix(f, task.anomaly)
	await _until(func(): return task.state == "done", 40.0)
	log_line("  -> result=%s  erosion=%d" % [task.result, int(Game.erosion)])


## Reports the way a player does: open the tablet and press its 정상 / 이상 button (calling d.report() directly
## once hid a tablet that showed no buttons at all). A missing button is logged and the run carries on.
func _report_on_tablet(task: Task, claim: bool) -> void:
	var tab: Tablet = world.ui.tablet
	world.ui.open_tablet()
	await wait(0.6)
	tab._selected = task
	tab.refresh()
	await wait(0.1)
	var btn: Button = null
	for b in tab._detail.find_children("*", "Button", true, false):
		if b.has_meta("report") and bool(b.get_meta("report")) == claim:
			btn = b as Button
	if btn == null or btn.disabled:
		log_line("  !! tablet has no usable %s button (%s)" % ["이상" if claim else "정상", "missing" if btn == null else "disabled"])
		await shot("no_report_button")
		d.report(task, claim)
	else:
		btn.pressed.emit()
	await wait(1.2)
	if world.ui.modal == "tablet":
		world.ui.close_modal()
		await wait(0.3)


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
			await goto(t.spot("view_breaker"), t.spot("look_breaker"))
			t.breaker.switches[fix[1]]._on_used()
			if not OS.get_cmdline_user_args().has("--leave-power-off"):   # like a player who never switches it back on
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
			"tapecall":
				log_line("EVENT the tape says your name → stand still (p.9 ②)")
				await shot("tapecall")
				await _until(func(): return d.running_event != "tapecall", 60.0)
			"3am":
				log_line("EVENT 3am → stay in a lit zone (lit=%s)" % d.player_zone_lit())
				if not d.player_zone_lit():
					await goto(t.spot("office_inside"), t.spot("office_look"))
				await _until(func(): return d.running_event != "3am", 40.0)
			"slowpa":
				log_line("EVENT slow PA → face south")
				p.look_at_point(p.camera.global_position + Vector3(0, 0, 10), 0.01)
				await _until(func(): return d.running_event != "slowpa", 40.0)
			"broadcast":
				log_line("EVENT 03:00 broadcast → stand still")
				await shot("regular_broadcast")
				# about a minute of real audio; timers here run at Engine.time_scale
				await _until(func(): return d.running_event != "broadcast", 90.0 * Engine.time_scale)
			"boardingcall":
				log_line("EVENT boarding call in zone %s → leave the gate area (p.8 ④)" % p.zone)
				await goto(t.spot("boarding_hold"), t.spot("boarding_look"))
				await _until(func(): return d.running_event != "boardingcall", 90.0)


# --- DAY 5 06:00: walk to Gate 0, then follow whichever sign the record lit -----------------------------
func _finale_choice() -> void:
	await goto(Vector3(0, 0.05, -95.0), Vector3(0, 2.5, -110))
	await shot("gate0_front")
	await _until(func(): return str(d.script_obj.get("ending")) != "", 30.0)
	var picked := str(d.script_obj.get("ending"))
	log_line("FINALE → %s  accuracy=%d%% missed=%d violations=%d fakes=%d (wanted %s)" % [picked, d.record_accuracy(),
		int(Game.stats.get("missed", 0)), int(Game.stats.get("violations", 0)), int(Game.stats.get("fake_followed", 0)), ending])
	await wait(2.0)
	match picked:
		"board":
			await shot("board_sign")
			await goto(Vector3(0, 0.05, -125.0), Vector3(0, 1.4, -136))
			await goto(Vector3(0, 0.05, -134.4), Vector3(0, 1.4, -136))
		"exit":
			await shot("exit_lights")
			await goto(t.spot("exit_inside"), t.spot("exit_look"))
			await shot("emergency_exit")
			await wait(1.0)
			await goto(t.spot("exit_outside"), t.spot("exit_out_look"))
		_:
			await shot("your_voice")
	await _until(func(): return d.ending_started, 90.0)
	log_line("ENDING STARTED: " + picked)


func _until(cond: Callable, timeout: float) -> bool:
	var e := 0.0
	while not cond.call():
		await get_tree().create_timer(0.1).timeout
		e += 0.1
		if e > timeout:
			log_line("  (timeout)")
			return false
	return true
