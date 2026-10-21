extends PhaseScript
## NIGHT 3 — Survive. Fake and conflicting pages, lethal emergency rules. Then the airport stops
## recognising you as staff. Every exit leads back inside. Gate 0 opens.
## Endings: BOARD (walk the bridge) · EXIT (cut the main power, leave by the emergency exit) ·
## ANNOUNCE (erosion reaches 100).

const OTHER := {
	"xray": ["보안검색 X-ray 1번 판독 점검", "보안검색 1번 레인에서 [b]테스트 가방을 스캔[/b]하고 판독 화면을 관찰하십시오."],
	"walkway": ["무빙워크 MW-1 가동 점검", "탑승동 통로 [b]MW-1[/b]을 가동하고 이동 방향과 속도를 관찰하십시오."],
	"baggage": ["수하물 B-03 가동 테스트", "수하물 B-03을 [가동]하고 나오는 가방을 끝까지 확인하십시오. 정상은 TEST 태그 가방 3개."],
}

var loops := 0
var escaping := false
var power_cut := false
var _busy := false
var _gate0_revealed := false
var _follower: AudioStreamPlayer3D


func title_lines() -> Array:
	return ["NIGHT 3", "10월 22일 · 23:00 · 마지막 야간 점검"]


func setup() -> void:
	d.set_shutters_for_cycle(3)
	d.clock_speed = 0.4
	if Game.binder_pages.has("p3"):
		Game.remove_binder_page("p3")
		Game.add_binder_page("p3_dmg")
	for id in ["f4", "f6", "f7", "f8"]:
		Game.add_binder_page(id)
	d.spawn_doc("log3", Vector3(20.8, 0.49, -94.6), 0.6, "의자 위에 놓인 업무일지 읽기")
	d.spawn_doc("log2", Vector3(6.6, 0.81, -20.6), 0.5, "누군가 두고 간 업무일지 읽기")
	if not Game.has_clue("plaque"):
		var pl := Pickup.create(d.t, Vector3(41.0, 0.0, -21.4), 0.0, "plaque", "덮개 아래 동판 살펴보기", "plaque")
		pl.keep_after_pick = true
		pl.picked.connect(func(_p):
			if Game.has_clue("plaque"):
				return
			Game.add_clue("plaque")
			var c: Dictionary = RulesDB.CLUES.plaque
			d.ui.read_doc(c.title, c.body, "serif"))
	d.t.triggers.entrance_out.body_entered.connect(_on_exit_trigger)
	d.t.triggers.emergency_out.body_entered.connect(_on_emergency_out)
	d.main_power_pulled.connect(_on_main_power)
	Events.zone_entered.connect(_on_zone)


func run() -> void:
	await d.wait(1.0)
	await d.radio("마지막 밤이에요. 내일 아침이면 개장이고요. 끝나면 정규직 얘기도 해 봅시다.")
	d.notify("바인더 사이에 낯선 페이지 여러 장이 끼워져 있다.", "info")
	var gate_no: String = ["01", "02", "03", "04"][randi() % 4]
	var other: String = OTHER.keys()[randi() % OTHER.size()]
	var plan := d.plan_anomalies(["gate", "fids", other], 2 + (1 if randf() < 0.5 else 0))
	var t1 := d.inspect("gate" + gate_no, "탑승구 GATE %s 점검" % gate_no,
		"GATE %s 포디움의 [b][상태 확인][/b]을 누르고 출입문·표시·대기석을 관찰하십시오. (수칙 p.8)" % gate_no, plan.gate)
	await d.until_done(t1)
	await d.wait(3.0)
	await d.ev_slow_broadcast(false)
	var t2 := d.inspect("fids", "FIDS 출발 전광판 점검",
		"출발 전광판의 테스트 목록과 시계를 낮의 기록·태블릿 시각과 비교하십시오.", plan.fids)
	await d.until_done(t2)
	await d.wait(2.0)
	await d.ev_namecall(true)
	var t3 := d.inspect(other, OTHER[other][0], OTHER[other][1], plan[other])
	await d.until_done(t3)
	d.jump_clock(26 * 60 + 40)
	await d.wait(2.0)
	await d.ev_blackout(10.0, true, false)
	await d.wait(1.5)
	await _act3()


# --- ACT 3: the airport doesn't know you work here ---------------------------------------------
func _act3() -> void:
	await d.radio("수고했어요. 중간 보고 받을게요. 사무실로 와서 태블릿 동기화해요.")
	var g := d.goal("중간 보고 — 시설관리실 복귀", "시설관리실 출입문 [b]카드 리더[/b]에 출입카드를 태그하십시오.", "office")
	d.office_locked = true
	await d.office_denied
	d.ui.postfx.pulse_glitch(0.5)
	await d.wait(0.6)
	d.say("…카드가 안 찍힌다.", 2.5)
	await d.radio("카드가 안 찍혀요? 잠깐만요, 확인해 볼게요.")
	await d.wait(2.0)
	await d.radio("…이상한데요. 시스템에 직원 등록이 안 되어 있는데요?")
	d.say("저 직원인데요. 사번… 1103이요.", 3.5)
	await d.wait(3.5)
	await d.radio("…그 번호.", "소장", 0.8)
	await d.radio("직원 번호가 아닌데요.", "소장", 1.2)
	Snd.radio_static(true)
	await d.wait(2.5)
	Snd.radio_static(false)
	Game.set_flag("denied_twice")
	d.notify("무전 연결이 끊겼다.", "bad")
	d.complete_goal(g)
	await d.wait(1.0)
	d.ui.tablet.boarding_mode = true
	d.ui.postfx.pulse_glitch(0.9)
	Snd.play("ui_alert", -2.0, 0.7)
	d.notify("태블릿: MAINTENANCE TASKS → BOARDING INFORMATION", "alert")
	d.t.facility("fids").set_story("final", ["SH 000", "GATE 0", "BOARDING"])
	await d.pa(["pa_flight0_checkin_ko", "pa_destination_home_ko"], {"wrong": true,
		"subs": ["영편 탑승 수속을 시작합니다. 승객 여러분께서는 영번 게이트로 이동해 주시기 바랍니다.", "목적지는, 집입니다."]})
	_start_escape()


func _start_escape() -> void:
	escaping = true
	d.escape_mode = true
	d.main_power_enabled = true
	d.ambient_enabled = true
	d.t.doors.entrance.open()
	d.objective("공항에서 나가십시오.")
	d.notify("체크인 홀 출구가 저절로 열려 있다.", "info")
	_pressure()


func _pressure() -> void:
	while escaping and not d.dead and not d.ending_started:
		await d.wait(8.0)
		if not power_cut:
			Game.add_erosion(1.0)


func _on_exit_trigger(body: Node3D) -> void:
	if not escaping or _busy or not body.is_in_group("player") or d.dead or power_cut:
		return
	_busy = true
	loops += 1
	d.p.controls_enabled = false
	Snd.play("door_slide", -4.0)
	await d.ui.fade_to(1.0, 0.6)
	if loops == 1:
		_change_signs()
		d.p.teleport(d.t.spawns.corridor_south)
	else:
		d.p.teleport(d.t.spawns.gates_entry)
	await d.wait(1.0)
	await d.ui.fade_to(0.0, 1.2)
	d.p.controls_enabled = true
	_busy = false
	if loops == 1:
		d.say("…통로? 방금 밖으로 나갔는데.", 3.5)
		d.objective("공항에서 나가십시오. (출구)")
	else:
		_reveal_gate0()


func _on_zone(zone: String) -> void:
	if escaping and loops >= 1 and zone == "gates" and not _gate0_revealed:
		_reveal_gate0()


func _change_signs() -> void:
	for key in ["hall_departures", "security_main", "corridor_mid", "gates_main", "hall_baggage", "hall_staff"]:
		for l in d.t.signs.get(key, []):
			Geo.set_text(l as Label3D, "↑   GATE 0")
			(l as Label3D).modulate = Color(1.0, 0.85, 0.3)


func _reveal_gate0() -> void:
	if _gate0_revealed:
		return
	_gate0_revealed = true
	d.t.reveal_gate0()
	var g0: BoardingGate = d.t.gates["0"]
	g0._set_status("FLIGHT 000\nFINAL CALL", Color(1.0, 0.3, 0.25))
	g0.open_door(true)
	d.t.triggers.board_door.body_entered.connect(func(b):
		if b.is_in_group("player") and not power_cut:
			d.start_ending("board"))
	Snd.play("sub_boom", 0.0, 0.8, "SFX")
	d.p.add_shake(0.4)
	d.objective("…")
	_lights_die()
	_final_call_loop()


func _lights_die() -> void:
	for zn in ["hall", "baggage", "security", "corridor", "office", "service"]:
		await d.wait(1.2)
		if power_cut:
			return
		d.t.zones[zn].set_on(false)
		Snd.play_at("flicker_zap", d.p.global_position + Vector3(randf_range(-8, 8), 4, randf_range(-8, 8)), -6.0, 0.8)
	d.t.set_zone_light("gates", true)
	d.notify("탑승동만 불이 켜져 있다. 북쪽 창밖에 무언가 서 있다.", "info")


func _final_call_loop() -> void:
	while escaping and not power_cut and not d.dead and not d.ending_started:
		await d.pa(["pa_final_call_ko", "pa_final_call_en"], {"wrong": true, "tag": "final",
			"subs": ["영편 최종 탑승 안내입니다. 아직 탑승하지 않으신 승객께서는, 지금 즉시 영번 게이트로 오시기 바랍니다.",
				"This is the final boarding call for flight zero. Remaining passenger, please proceed to gate zero immediately."]})
		await d.wait(22.0)


# --- EXIT route ---------------------------------------------------------------------------------
func _on_main_power() -> void:
	if power_cut:
		return
	power_cut = true
	Game.set_flag("main_power_cut")
	Snd.pa_stop()
	Snd.play("power_down", 0.0, 0.75, "SFX")
	d.p.add_shake(0.3)
	for z in d.t.zones.values():
		z.set_powered(false)
	for f in d.t.facilities.values():
		(f as Facility).set_powered(false)
	d.t.arrivals.set_powered(false)
	if d.t.gate0_parts:
		for n in d.t.gate0_parts.find_children("*", "Light3D", true, false):
			(n as Light3D).visible = false
	if d.t.final_plane:
		for n in d.t.final_plane.find_children("*", "Light3D", true, false):
			(n as Light3D).visible = false
	for n in d.t.outside_lights:
		n.visible = false
	d.t.emergency_light_root.visible = true
	for i in 3:
		var ch := d.t.get_node_or_null("Chain%d" % i)
		if ch:
			ch.visible = false
	d.t.exit_door_use.prompt = "비상구로 나가기"
	await d.wait(2.5)
	d.objective("비상구로 나가십시오. (체크인 홀 남측, 초록 표시등)")
	d.notify("완전한 어둠. 비상구 표시등만 켜져 있다.", "info")
	_follow_me()


## Something rolls a suitcase behind you all the way to the exit.
func _follow_me() -> void:
	_follower = AudioStreamPlayer3D.new()
	_follower.stream = Snd.stream("luggage_roll_loop")
	_follower.unit_size = 5.0
	_follower.bus = "SFX"
	d.t.add_child(_follower)
	_follower.play()
	var dist := 16.0
	while not d.ending_started and not d.dead:
		await d.wait(0.05)
		dist = maxf(3.0, dist - 0.05 * 0.18)
		var back := -d.p.forward()
		back.y = 0.0
		var target := d.p.global_position + back.normalized() * dist
		_follower.global_position = _follower.global_position.lerp(target, 0.08)


func _on_emergency_out(body: Node3D) -> void:
	if power_cut and body.is_in_group("player"):
		d.start_ending("exit")
