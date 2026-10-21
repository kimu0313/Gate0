class_name ShiftDirector
extends Node
## Runs a work phase: tasks, observation, judgment reports, anomaly responses, lethal rules,
## global rule events (blackout, name call, 3 AM), erosion pressure, deaths and phase transitions.

signal task_finished(task: Task)
signal punched
signal radio_free
signal action_seen(action: String, target: String)
signal office_denied
signal main_power_pulled

var world: Node
var t: Terminal
var p: Player
var ui: GameUI
var script_obj: PhaseScript
var tasks: Array[Task] = []
var current: Task
var clock_speed := 0.4          # game minutes per real second
var clock_running := true
var punch_enabled := false
var dead := false
var ending_started := false
var running_event := ""
var event_tension := 0.0
var night_log := {"correct": 0, "missed": 0, "false_alarm": 0, "cleared": 0, "failed": 0}
var erosion_start := 0.0
var ambient_enabled := true
var escape_mode := false
var office_locked := false
var main_power_enabled := false

var _clock_accum := 0.0
var _radio_busy := false
var _radio_chatter: AudioStreamPlayer
var _ambient_timer := 25.0
var _red_time := 0.0
var _away_time := 0.0
var _pa_slow_total := 0.0
var _pa_slow_away := 0.0
var _task_counter := 0
var _figure: Node3D


func setup(world_node: Node) -> void:
	world = world_node
	t = world.terminal
	p = world.player
	ui = world.ui
	erosion_start = Game.erosion
	_radio_chatter = AudioStreamPlayer.new()
	_radio_chatter.bus = "Radio"
	add_child(_radio_chatter)
	Events.player_action.connect(_on_player_action)
	Snd.pa_started.connect(_on_pa_started)
	Snd.pa_finished.connect(_on_pa_finished)
	t.punch_clock.callback = _on_punch
	_bind_world_objects()
	var path := "res://scripts/director/phases/%s%d.gd" % [Game.phase, Game.cycle]
	if ResourceLoader.exists(path):
		script_obj = load(path).new()
	else:
		script_obj = PhaseScript.new()
	script_obj.d = self
	script_obj.setup()


func start() -> void:
	script_obj.run()


# =========================================================================================
# helpers for phase scripts
# =========================================================================================
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout


func until(cond: Callable, poll := 0.1) -> void:
	while not cond.call():
		await get_tree().create_timer(poll, false).timeout


func radio(text: String, speaker := "소장", extra := 0.0) -> void:
	while _radio_busy:
		await radio_free
	if dead:
		return
	_radio_busy = true
	Snd.play("radio_on", -8.0, 1.0, "SFX")
	await wait(0.25)
	var dur := clampf(1.6 + text.length() * 0.06, 2.2, 9.0) + extra
	Events.subtitle.emit("radio", "%s|%s" % [speaker, text], dur)
	_radio_chatter.stream = Snd.stream("radio_chatter")
	if _radio_chatter.stream:
		_radio_chatter.volume_db = -16.0
		_radio_chatter.pitch_scale = randf_range(0.95, 1.05)
		_radio_chatter.play()
	var elapsed := 0.0
	while elapsed < dur:
		await get_tree().create_timer(0.1, false).timeout
		elapsed += 0.1
		if not _radio_chatter.playing and elapsed < dur - 1.0 and _radio_chatter.stream:
			_radio_chatter.pitch_scale = randf_range(0.93, 1.07)
			_radio_chatter.play()
	_radio_chatter.stop()
	Snd.play("radio_off", -9.0, 1.0, "SFX")
	await wait(0.35)
	_radio_busy = false
	radio_free.emit()


## Radio line that does not block the caller.
func radio_async(text: String, speaker := "소장") -> void:
	radio(text, speaker)


func say(text: String, dur := 3.0) -> void:
	Events.subtitle.emit("self", "나|" + text, dur)


func pa(clips: Array, opts := {}) -> bool:
	return await Snd.pa_announce(clips, opts)


func notify(text: String, kind := "info") -> void:
	Events.notify.emit(text, kind)


func objective(text: String) -> void:
	ui.hud.set_objective(text)


func open_zone(zone_name: String, instant := false) -> void:
	if t.shutters.has(zone_name):
		t.shutters[zone_name].open(instant)


# =========================================================================================
# tasks
# =========================================================================================
func inspect(fac_id: String, title: String, detail: String, anomaly := "", opts := {}) -> Task:
	var task := Task.new()
	_task_counter += 1
	task.id = "T%02d" % _task_counter
	task.kind = "inspect"
	task.title = title
	task.detail = detail
	task.facility_id = fac_id
	task.anomaly = anomaly
	task.urgent = opts.get("urgent", false)
	var f := t.facility(fac_id)
	task.location = f.zone if f else ""
	_add_task(task)
	return task


func goal(title: String, detail: String, location := "", opts := {}) -> Task:
	var task := Task.new()
	_task_counter += 1
	task.id = "T%02d" % _task_counter
	task.kind = "goal"
	task.title = title
	task.detail = detail
	task.location = location
	task.optional = opts.get("optional", false)
	_add_task(task)
	return task


func _add_task(task: Task) -> void:
	if task.urgent and current and current.state == "active":
		current.state = "pending"
		var idx := tasks.find(current)
		tasks.insert(idx, task)
		current = null
	else:
		tasks.append(task)
	if task.optional:
		task.state = "active"
		Events.tasks_changed.emit()
		return
	if current == null:
		_activate_next()
	else:
		Events.tasks_changed.emit()


func _activate_next() -> void:
	current = null
	for task in tasks:
		if task.state == "pending" and task.urgent:
			_activate(task)
			return
	for task in tasks:
		if task.state == "pending":
			_activate(task)
			return
	Events.tasks_changed.emit()


func _activate(task: Task) -> void:
	current = task
	task.state = "active"
	task.progress = 0.0
	task.observed = false
	if task.kind == "inspect":
		var f := t.facility(task.facility_id)
		if f:
			if f is PaConsole:
				(f as PaConsole).reset_inspection()
			if f is BoardingGate:
				(f as BoardingGate).checked = false
			if task.anomaly != "" and f.anomaly != task.anomaly:
				_prepare_anomaly(f, task.anomaly)
				f.set_anomaly(task.anomaly)
	Snd.play("ui_alert" if task.urgent else "ui_notify", -6.0)
	notify(tr("⚠ 긴급 지시: " if task.urgent else "새 점검 지시: ") + tr(task.title), "alert" if task.urgent else "task")
	objective(task.title)
	Events.tasks_changed.emit()


func _prepare_anomaly(f: Facility, anomaly_id: String) -> void:
	if f is LightPanel:
		var lp := f as LightPanel
		var candidates := []
		for zn in ["hall", "baggage"]:
			if lp.zones[zn].is_on:
				candidates.append(zn)
		if candidates.is_empty():
			candidates = ["hall"]
		lp.anomaly_zone = candidates[randi() % candidates.size()]
	elif f is FidsBoard:
		(f as FidsBoard).change_variant = randi() % 4
	elif f is PaConsole:
		(f as PaConsole).word_variant = randi() % 3


func complete_goal(task: Task) -> void:
	if task == null or task.state == "done":
		return
	task.state = "done"
	task.result = "done"
	if not task.optional:
		Snd.play("beep_ok", -8.0)
	_after_task(task)


func until_done(task: Task) -> void:
	while task.state != "done":
		await task_finished


func all_required_done(except: Task = null) -> bool:
	for task in tasks:
		if task == except:
			continue
		if not task.optional and task.state != "done":
			return false
	return true


func open_tasks() -> Array:
	return tasks.filter(func(x): return x.state != "done")


func _complete(task: Task, result: String) -> void:
	task.state = "done"
	task.result = result
	night_log[result] = int(night_log.get(result, 0)) + 1
	Game.stat(result)
	_after_task(task)


func _after_task(task: Task) -> void:
	if current == task:
		current = null
		_activate_next()
	if current == null:
		objective("")
	task_finished.emit(task)
	Events.tasks_changed.emit()


func task_for(fac_id: String) -> Task:
	for task in tasks:
		if task.facility_id == fac_id and task.is_open():
			return task
	return null


# =========================================================================================
# judgment reports (called by the tablet)
# =========================================================================================
func can_report(task: Task) -> String:
	if task == null or task.kind != "inspect":
		return "보고할 점검 지시가 없습니다."
	if task.state == "responding":
		return "이미 [이상] 보고됨 — 수칙에 따라 대응하십시오."
	if task.state != "active":
		return "아직 진행할 수 없는 지시입니다."
	if task.locked != "":
		return task.locked
	if not task.observed:
		var f := t.facility(task.facility_id)
		var hint := ""
		if f and not f.is_observable():
			hint = " (시설을 가동하거나 확인 버튼을 누르십시오)"
		return tr("현장에서 시설을 직접 관찰해야 보고할 수 있습니다.") + tr(hint)
	return ""


func report(task: Task, claim_anomaly: bool) -> void:
	if can_report(task) != "":
		return
	var f := t.facility(task.facility_id)
	var real := f != null and f.anomaly != "" and f.anomaly == task.anomaly
	task.reported_as = "anomaly" if claim_anomaly else "normal"
	Snd.play("ui_tap", -4.0)
	if claim_anomaly:
		if task.anomaly == "":
			_false_alarm(task)
		elif task.fix_done or not real:
			notify("이상 판정 접수 — 이미 정상화된 상태입니다.", "good")
			_complete(task, "cleared")
		else:
			var def := AnomalyDB.get_def(task.anomaly)
			task.state = "responding"
			task.deadline = float(def.get("timer", 120.0))
			notify(tr("이상 판정 접수. 근무 수칙에 따라 대응하십시오. (제한 %d초)") % int(task.deadline), "alert")
			objective(tr("수칙에 따라 대응: ") + tr(f.title if f else task.title))
			Snd.play("ui_alert", -6.0)
			Events.tasks_changed.emit()
	else:
		if task.anomaly == "":
			Game.add_erosion(-2.0)
			notify("정상 판정 접수.", "good")
			_complete(task, "correct")
		elif task.fix_done:
			Game.add_erosion(4.0)
			notify("판정 기록 불일치 — 대응은 확인되었습니다.", "info")
			_complete(task, "cleared")
		else:
			_missed(task, f)


func _false_alarm(task: Task) -> void:
	Game.add_erosion(7.0)
	Game.clock_minutes += 20
	notify("관제 확인 결과: 정상. 오판으로 기록됩니다. (시간 손실)", "bad")
	_complete(task, "false_alarm")
	radio_async(["확인해 봤는데 정상이에요. 시간만 버렸네요.", "그거 정상이에요. 너무 예민해지지 마요.", "정상이라는데요. 다음 거 봐요."][randi() % 3])
	# needless exposure: something wakes up elsewhere
	if Game.phase == "night":
		get_tree().create_timer(randf_range(6.0, 14.0), false).timeout.connect(func(): _ambient_scare(true))


func _missed(task: Task, f: Facility) -> void:
	var def := AnomalyDB.get_def(task.anomaly)
	Game.add_erosion(18.0)
	Game.add_clue("miss_" + task.anomaly)
	notify("판정 접수.", "info")
	if f:
		f.clear_anomaly()
	_complete(task, "missed")
	_airport_reacts()


## The terminal answers a missed anomaly: something, somewhere, checks in.
func _airport_reacts() -> void:
	await wait(randf_range(2.0, 4.0))
	if dead:
		return
	for z in t.zones.values():
		z.trigger_dip(0.4)
	Snd.play("stinger_soft", -6.0, 1.0, "SFX")
	await pa(["pa_one_passenger_ko"], {"wrong": true, "subs": ["승객 한 분이 탑승 수속을 마쳤습니다."], "no_end": true})


func _fail_response(task: Task) -> void:
	var f := t.facility(task.facility_id)
	Game.add_erosion(15.0)
	notify("대응 시간 초과 — 대응 실패로 기록됩니다.", "bad")
	if f:
		f.clear_anomaly()
	_complete(task, "failed")
	_scare_glimpse()


# =========================================================================================
# actions: fixes & lethal rules
# =========================================================================================
func _on_player_action(action: String, target: String) -> void:
	action_seen.emit(action, target)
	if dead or ending_started:
		return
	for f in t.facilities.values():
		var fac := f as Facility
		if fac.anomaly == "":
			continue
		var def := AnomalyDB.get_def(fac.anomaly)
		if def.is_empty():
			continue
		if _match_any(def.get("lethal", []), action, target, fac):
			kill(def.get("death", "근무 수칙을 위반했습니다."))
			return
		if _match_any(def.get("fix", []), action, target, fac):
			_resolve(fac)


func _match_any(entries: Array, action: String, target: String, f: Facility) -> bool:
	for e in entries:
		if e[0] != action:
			continue
		var want: String = e[1]
		if want == "*":
			return true
		if want == "$zone" and f is LightPanel:
			want = (f as LightPanel).anomaly_zone
		elif want == "$id":
			want = f.id
		if want == target:
			return true
		if target == "gates" and want.begins_with("gate"):
			return true
	return false


func _resolve(f: Facility) -> void:
	var task := task_for(f.id)
	f.clear_anomaly()
	Snd.play("beep_ok", -6.0)
	Snd.play_at("power_up", f.focus_position(), -14.0, 1.2, 6.0)
	if task:
		task.fix_done = true
		if task.state == "responding":
			notify("이상 현상 해제 — 대응 완료.", "good")
			_complete(task, "cleared")
		else:
			notify("시설 상태가 정상으로 돌아왔다…", "good")
			Events.tasks_changed.emit()
	else:
		notify("이상 현상 해제.", "good")


# =========================================================================================
# per-frame
# =========================================================================================
func _process(delta: float) -> void:
	if dead or get_tree().paused:
		return
	# clock
	if clock_running:
		_clock_accum += delta * clock_speed
		if _clock_accum >= 1.0:
			var m := int(_clock_accum)
			_clock_accum -= m
			Game.clock_minutes += m
			Events.clock_changed.emit(Game.clock_minutes)
	_update_observation(delta)
	_update_responding(delta)
	_update_continuous_rules(delta)
	_update_pressure(delta)


func _update_observation(delta: float) -> void:
	if current == null or current.kind != "inspect" or current.state != "active" or current.observed:
		ui.hud.set_inspect_progress(-1.0)
		return
	var f := t.facility(current.facility_id)
	if f == null or not f.is_observable():
		ui.hud.set_inspect_progress(-1.0)
		return
	var fp := f.focus_position()
	var dist := p.camera.global_position.distance_to(fp)
	var looking := p.facing_dot(fp) > 0.55 or f is LightPanel
	if dist <= f.observe_radius and looking and p.eyes < 0.4:
		current.progress += delta
		ui.hud.set_inspect_progress(current.progress / Task.OBSERVE_TIME)
		if current.progress >= Task.OBSERVE_TIME:
			current.observed = true
			ui.hud.set_inspect_progress(-1.0)
			Snd.play("beep_ok", -12.0, 1.3)
			notify("관찰 완료 — [Tab] 태블릿에서 정상/이상을 보고하십시오.", "task")
			Events.tasks_changed.emit()
	else:
		ui.hud.set_inspect_progress(-1.0)


func _update_responding(delta: float) -> void:
	for task in tasks:
		if task.state == "responding":
			task.deadline -= delta
			if int(task.deadline + delta) != int(task.deadline):
				Events.tasks_changed.emit()
			if task.deadline <= 0.0:
				_fail_response(task)
				return


func _update_continuous_rules(delta: float) -> void:
	# red light: do not stand under it
	var lp := t.lights_panel
	var red_hit := false
	for z in t.zones.values():
		var zone := z as LightZone
		if zone.has_red() and zone.is_on and zone.red_area and zone.red_area.overlaps_body(p):
			red_hit = true
	_red_time = _red_time + delta if red_hit else maxf(0.0, _red_time - delta)
	if _red_time > 2.5 and lp.anomaly == "light_red":
		_on_player_action("stand_under_red", "*")
	# X-ray figure: close your eyes in front of the screen
	var xr := t.facility("xray")
	if xr and xr.anomaly == "xray_figure" and (xr as XrayMachine).scanned:
		if p.eyes_closed_time >= 8.0 and p.global_position.distance_to(xr.focus_position()) < 6.0:
			_on_player_action("eyes_closed_near", "xray")
	# the passenger
	for g in t.gates.values():
		var gate := g as BoardingGate
		if gate.anomaly != "gate_passenger" or gate.passenger == null:
			continue
		var pp := gate.passenger_position()
		var dist := p.global_position.distance_to(Vector3(pp.x, p.global_position.y, pp.z))
		if dist < 2.2:
			_on_player_action("approach_passenger", gate.id)
			return
		if dist < 18.0 and p.facing_dot(pp) < -0.1:
			_away_time += delta
			if _away_time >= 8.0:
				_away_time = 0.0
				_on_player_action("face_away_from_passenger", gate.id)
		else:
			_away_time = 0.0
	# slow PA voice: face away from the gates (north = -Z) until it ends
	if Snd.pa_busy and Snd.pa_tag == "test":
		var pa := t.facility("pa")
		if pa and pa.anomaly == "pa_slow":
			_pa_slow_total += delta
			if p.forward().z > 0.35:
				_pa_slow_away += delta


func _on_pa_started(_tag: String) -> void:
	_pa_slow_total = 0.0
	_pa_slow_away = 0.0


func _on_pa_finished(cancelled: bool) -> void:
	var pa := t.facility("pa") if t else null
	if pa and pa.anomaly == "pa_slow" and not cancelled and _pa_slow_total > 2.0:
		if _pa_slow_away / _pa_slow_total >= 0.6:
			_on_player_action("pa_slow_survived", "pa")
		else:
			notify("방송이 끝났다. 무언가 등 뒤에서 멀어졌다…", "bad")
			Game.add_erosion(6.0)


func _update_pressure(delta: float) -> void:
	var e := Game.erosion / 100.0
	var night := Game.phase == "night"
	for z in t.zones.values():
		z.erratic = (e * 0.7 + (0.05 if night and Game.cycle >= 2 else 0.0)) if night else e * 0.2
	event_tension = move_toward(event_tension, 0.0, delta * 0.08)
	Snd.set_tension(clampf((e * 0.85 if night else e * 0.4) + event_tension, 0.0, 1.0))
	ui.postfx.erosion = e
	if Game.erosion >= 100.0 and not ending_started and not dead:
		start_ending("announce")
		return
	if night and ambient_enabled and running_event == "":
		_ambient_timer -= delta * (1.0 + e * 2.0 + (Game.cycle - 1) * 0.4)
		if _ambient_timer <= 0.0:
			_ambient_timer = randf_range(28.0, 55.0)
			_ambient_scare(false)


# =========================================================================================
# ambience & scares
# =========================================================================================
func _ambient_scare(strong: bool) -> void:
	if dead or ending_started:
		return
	var roll := randi() % (6 if strong else 5)
	var away := p.global_position - p.forward() * randf_range(10.0, 18.0)
	away.y = 1.0
	match roll:
		0:
			Snd.play_at("distant_footsteps", away, -2.0, randf_range(0.9, 1.05), 10.0, 70.0)
		1:
			Snd.play_at("distant_door", away, 0.0, randf_range(0.8, 1.0), 12.0, 80.0)
		2:
			var keys := t.zones.keys()
			t.zones[keys[randi() % keys.size()]].trigger_dip(randf_range(0.3, 0.9))
			Snd.play_at("flicker_zap", p.global_position + Vector3(randf_range(-6, 6), 4, randf_range(-6, 6)), -8.0)
		3:
			Snd.play_at("luggage_roll_loop", away, -6.0, 1.0, 8.0, 40.0)
		4:
			Snd.play("pa_chime_wrong", -16.0, randf_range(0.7, 0.9), "PA")
		5:
			_scare_glimpse()
	event_tension = minf(1.0, event_tension + (0.35 if strong else 0.15))


## A dark passenger stands somewhere ahead for a moment, then is gone.
func _scare_glimpse(dist := 9.0) -> void:
	if _figure and is_instance_valid(_figure):
		return
	var fwd := p.forward()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var pos := p.global_position + fwd * dist
	var q := PhysicsRayQueryParameters3D.create(p.camera.global_position, pos + Vector3(0, 1.0, 0), Geo.LAYER_WORLD)
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		pos = hit.position - fwd * 1.0
	pos.y = 0.0
	_figure = Props.figure(t, pos, atan2(-fwd.x, -fwd.z) + PI, false)
	Snd.play("stinger_hit", -4.0, 1.0, "SFX")
	p.add_shake(0.5)
	ui.postfx.pulse_glitch(0.6)
	event_tension = 1.0
	await wait(0.7)
	if _figure and is_instance_valid(_figure):
		_figure.queue_free()
	_figure = null


# =========================================================================================
# global rule events (근무 수칙 p.9)
# =========================================================================================
func ev_blackout(duration := 12.0, lethal := false, hint := false) -> void:
	if dead:
		return
	running_event = "blackout"
	var saved := {}
	for zn in t.zones.keys():
		saved[zn] = t.zones[zn].is_on
		t.zones[zn].set_on(false, true)
	var fl := p.flashlight_on
	if fl:
		p.toggle_flashlight(0)
	Snd.play("power_down", -2.0, 1.0, "SFX")
	event_tension = 1.0
	if hint:
		radio_async("정전…? 수칙 9페이지! 그 자리에서 눈 감아요. [C] 길게!")
	await wait(2.2 if hint else 1.4)
	var violated := 0.0
	var elapsed := 0.0
	var roll := AudioStreamPlayer3D.new()
	roll.stream = Snd.stream("luggage_roll_loop")
	roll.unit_size = 4.0
	roll.bus = "SFX"
	t.add_child(roll)
	var start_angle := randf() * TAU
	roll.global_position = p.global_position + Vector3(cos(start_angle), 0.2, sin(start_angle)) * 9.0
	roll.play()
	var breath := Snd.play("breath_loop", -26.0, 0.8, "SFX")
	while elapsed < duration:
		await get_tree().process_frame
		if dead:
			roll.queue_free()
			return
		var dt := get_process_delta_time()
		if get_tree().paused:
			continue
		elapsed += dt
		if p.eyes < 0.9:
			violated += dt
		# something rolls a suitcase in a slow circle that tightens around you
		var k := elapsed / duration
		var ang := start_angle + k * PI * 1.6
		var r := lerpf(9.0, 1.4, sin(k * PI))
		roll.global_position = p.global_position + Vector3(cos(ang) * r, 0.2, sin(ang) * r)
	roll.queue_free()
	if breath:
		breath.stop()
	Snd.play("power_up", -4.0, 1.0, "SFX")
	for zn in saved.keys():
		t.zones[zn].set_on(saved[zn])
	running_event = ""
	if violated > 1.5:
		_violation("정전 중에 눈을 떴습니다. (수칙 p.9 ①)", lethal)
	else:
		notify("조명이 돌아왔다.", "good")


func ev_namecall(lethal := false) -> void:
	if dead:
		return
	running_event = "namecall"
	event_tension = 1.0
	var name_text := Game.player_name
	Snd.pa_announce(["name_call"], {"wrong": true, "pitch": 0.94, "no_end": true,
		"subs": [tr("%s 승객님. %s 승객님. 영번 게이트로 오시기 바랍니다. 기다리고 있습니다.") % [name_text, name_text]]})
	await get_tree().process_frame
	var moved := 0.0
	while Snd.pa_busy:
		await get_tree().process_frame
		if dead:
			return
		if get_tree().paused:
			continue
		if p.move_vel.length() > 0.6:
			moved += get_process_delta_time()
	running_event = ""
	if moved > 0.35:
		_violation("이름을 부르는 방송 중에 움직였습니다. (수칙 p.9 ②)", lethal)


func ev_3am(lethal := false) -> void:
	if dead:
		return
	running_event = "3am"
	event_tension = 1.0
	Snd.pa_announce(["pa_3am_ko", "pa_final_call_ko"], {"wrong": true,
		"subs": ["현재 시각, 새벽 세 시입니다. 영편 탑승을 마감합니다.", "영편 최종 탑승 안내입니다. 아직 탑승하지 않으신 승객께서는, 지금 즉시 영번 게이트로 오시기 바랍니다."]})
	await get_tree().process_frame
	var dark := 0.0
	while Snd.pa_busy:
		await get_tree().process_frame
		if dead:
			return
		if get_tree().paused:
			continue
		if not player_zone_lit():
			dark += get_process_delta_time()
			ui.hud.flash_warning("조명이 켜진 곳으로")
	running_event = ""
	if dark > 2.0:
		_violation("탑승 마감 방송 중 어두운 구역에 있었습니다. (수칙 p.9 ③)", lethal)


## Autonomous slow broadcast (rule p.4 ②): turn your back on the gates until it ends.
func ev_slow_broadcast(lethal := false) -> void:
	if dead:
		return
	running_event = "slowpa"
	event_tension = 0.8
	var pa := t.facility("pa")
	if pa:
		pa.anomaly = "pa_slow"  # makes [송출 중지] lethal while it speaks (rule p.4 ②)
	Snd.pa_announce(["pa_test_normal_ko"], {"slow_index": 0, "tag": "auto",
		"subs": ["안내 말씀 드립니다… 현재 터미널 시설 점검이… 진행 중… 입니다…"]})
	await get_tree().process_frame
	var total := 0.0
	var away := 0.0
	while Snd.pa_busy:
		await get_tree().process_frame
		if dead:
			return
		if get_tree().paused:
			continue
		var dt := get_process_delta_time()
		total += dt
		if p.forward().z > 0.35:
			away += dt
	running_event = ""
	if pa and pa.anomaly == "pa_slow":
		pa.anomaly = ""
	if dead:
		return
	if total > 2.0 and away / total < 0.6:
		_violation("늘어지는 방송 중에 탑승동 쪽을 바라봤습니다. (수칙 p.4 ②)", lethal)
	else:
		notify("방송이 끝났다.", "good")


func player_zone_lit() -> bool:
	var zn := p.zone
	match zn:
		"storage", "maint":
			zn = "service"
		"outside", "bridge0":
			return false
	return t.zones.has(zn) and t.zones[zn].is_on and t.zones[zn].powered


func _violation(reason: String, lethal: bool) -> void:
	if lethal:
		kill(reason)
		return
	Game.add_erosion(15.0)
	notify(tr("수칙 위반: ") + tr(reason), "bad")
	_scare_glimpse(4.0)


# =========================================================================================
# death / endings / punch clock
# =========================================================================================
func kill(reason: String) -> void:
	if dead or ending_started:
		return
	dead = true
	Game.stat("deaths")
	p.controls_enabled = false
	ui.close_all()
	Snd.play("death_sting", 0.0, 1.0, "SFX")
	ui.postfx.pulse_glitch(1.0)
	p.add_shake(1.0)
	for z in t.zones.values():
		z.set_on(false, true)
	if p.flashlight_on:
		p.toggle_flashlight(0)
	await get_tree().create_timer(0.8).timeout
	ui.fade_to(1.0, 0.25)
	await get_tree().create_timer(0.6).timeout
	await Snd.pa_announce(["pa_passenger_confirmed_ko"], {"wrong": true, "subs": ["승객 확인되었습니다."], "no_end": true})
	ui.show_death(reason)


func _on_punch() -> void:
	if dead or ending_started:
		return
	if not punch_enabled or not script_obj.can_punch_out():
		Snd.play("beep_error", -6.0)
		var left := open_tasks().filter(func(x): return not x.optional)
		if left.is_empty():
			notify("지금은 기록할 수 없습니다.", "info")
		else:
			notify(tr("남은 업무가 있습니다: ") + tr(left[0].title), "info")
		return
	punched.emit()


func end_phase() -> void:
	p.controls_enabled = false
	ui.close_all()
	if Game.phase == "day":
		await ui.fade_to(1.0, 1.2)
		Game.start_phase(Game.cycle, "night")
	else:
		await ui.fade_to(1.0, 1.2)
		Snd.stop_all_world()
		var summary := night_log.duplicate()
		summary["erosion_before"] = erosion_start
		summary["erosion_after"] = Game.erosion
		await ui.show_report(summary)
		Game.erosion *= 0.8
		Game.start_phase(Game.cycle + 1, "day")


func start_ending(id: String) -> void:
	if ending_started:
		return
	ending_started = true
	p.controls_enabled = false
	ui.close_all()
	if id == "announce":
		Snd.play("glitch", 0.0, 0.7, "SFX")
		ui.postfx.pulse_glitch(1.0)
		Snd.play("tension_rise", -2.0, 1.0, "SFX")
		await get_tree().create_timer(2.0).timeout
	await ui.fade_to(1.0, 1.0 if id != "announce" else 0.3)
	Game.go_ending(id)


## Best facility in view, for photo labels.
func facility_in_view() -> Facility:
	var best: Facility = null
	var best_score := 0.0
	for f in t.facilities.values():
		var fac := f as Facility
		var fp := fac.focus_position()
		var dist := p.camera.global_position.distance_to(fp)
		if dist > 30.0:
			continue
		var dot := p.facing_dot(fp)
		if dot < 0.8:
			continue
		var score := dot * 2.0 - dist / 30.0
		if score > best_score:
			best_score = score
			best = fac
	return best

# =========================================================================================
# world objects: doors, keypad, logs, main power, pickups
# =========================================================================================
func _bind_world_objects() -> void:
	t.readers.office_out.swiped.connect(_on_office_reader)
	t.readers.office_in.swiped.connect(func(_r):
		t.readers.office_in.show_result(true, "OPEN")
		_open_door_briefly(t.doors.office))
	t.keypad.callback = func(): ui.open_keypad(_on_keypad_code)
	t.syslog_terminal.callback = _on_syslog
	t.main_power.callback = _on_main_power
	t.exit_door_use.callback = _on_exit_door


func _open_door_briefly(door: SlidingDoor, seconds := 4.0) -> void:
	door.open()
	await wait(seconds)
	while door.is_open and p.global_position.distance_to(door.global_position) < 1.6:
		await wait(0.5)
	door.close()


func _on_office_reader(r: CardReader) -> void:
	if office_locked:
		r.show_result(false, "DENIED" if not Game.flag("denied_twice") else "PASSENGER")
		office_denied.emit()
		return
	r.show_result(true, "STAFF OK")
	_open_door_briefly(t.doors.office)


func _on_keypad_code(code: String) -> void:
	if code == "1103":
		ui.keypad.show_result(true)
		Game.set_flag("maint_open")
		await wait(0.6)
		ui.close_modal()
		t.doors.maint.open()
	else:
		ui.keypad.show_result(false)


func _on_syslog() -> void:
	if Game.phase == "night" and Game.cycle >= 3:
		Game.add_clue("syslog")
		var c: Dictionary = RulesDB.CLUES.syslog
		await ui.read_doc(c.title, tr(str(c.body)) % Game.player_name, "mono")
	else:
		Snd.play("beep_error", -6.0)
		notify("SYSTEM LOG — 로그인 필요 (시설운영팀 관리자 계정)", "info")


func _on_main_power() -> void:
	if not main_power_enabled:
		Snd.play_at("switch_heavy", t.main_power.global_position, -6.0, 0.7)
		notify("주 전원 레버가 잠금 장치에 걸려 있다. 지금은 움직이지 않는다.", "info")
		return
	main_power_enabled = false
	main_power_pulled.emit()


func _on_exit_door() -> void:
	if not Game.flag("main_power_cut"):
		Snd.play_at("door_heavy", t.exit_door_use.global_position, -8.0, 1.2)
		notify("비상구가 체인으로 잠겨 있다.", "info")
		return
	t.doors.emergency.open()


## A collectable document; returns the Pickup.
func spawn_doc(clue_id: String, pos: Vector3, rot_y := 0.0, prompt := "문서 읽기", kind := "paper") -> Pickup:
	if Game.has_clue(clue_id):
		return null
	var pk := Pickup.create(t, pos, rot_y, clue_id, prompt, kind)
	pk.picked.connect(func(_p):
		Game.add_clue(clue_id)
		var c: Dictionary = RulesDB.CLUES[clue_id]
		var font_kind := "serif" if clue_id.begins_with("log") else ("hand" if clue_id == "memo_worker" else "sans")
		ui.read_doc(c.title, c.body, font_kind))
	return pk


func until_action(action: String, target := "") -> void:
	while true:
		var r: Array = await action_seen
		if r[0] == action and (target == "" or r[1] == target):
			return


func plan_anomalies(kinds: Array, count: int) -> Dictionary:
	var pool := kinds.duplicate()
	pool.shuffle()
	var out := {}
	for k in kinds:
		out[k] = ""
	for i in mini(count, pool.size()):
		out[pool[i]] = AnomalyDB.pick(pool[i], Game.cycle)
	return out


func set_shutters_for_cycle(c: int) -> void:
	if c >= 2:
		t.shutters.security.open(true)
		t.shutters.corridor.open(true)
	if c >= 3:
		t.shutters.gates.open(true)


func jump_clock(minutes: int) -> void:
	Game.clock_minutes = minutes
	Events.clock_changed.emit(minutes)
	ui.postfx.pulse_glitch(0.5)
