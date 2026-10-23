extends PhaseScript
## DAY 3 — 10/23, 개장일 새벽 · 마지막 근무. 탑승동 통로 + 탑승 게이트 + Gate 0.
## 출근: 탑승동 출입문이 직원 카드를 "PASSENGER ACCESS ONLY"로 거부한다 → 보안검색대 승객 통로로 돌아서 들어간다.
## 새벽 전반 (점검 4–6): 시설 셋이 동시에 혼자 켜진다. 어느 것부터 볼지는 플레이어가 정한다. 무전은 점점 "승객분".
## 새벽 후반 (점검 12 직후): 수칙끼리 충돌 — 방송 중에는 움직이지 마라(p.9 ③) vs 탑승 안내가 나오면 즉시
## 게이트를 떠나라(p.8 ④, 더 늦은 추록 → p.1 5에 따라 우선).
## 06:00 직전 Gate 0으로 가는 통로가 처음 열리고, 3일간의 판정 기록이 엔딩을 고른다:
##   정상 개장 — EXIT 표시가 켜지고 비상구로 나간다 · 탑승 — BOARD 표시를 따라 Gate 0으로 · 안내방송 — 당신의 목소리.

const GATE_FRONT_Z := -92.0

var finale := false
var ending := ""
var _reader: CardReader


func title_lines() -> Array:
	return ["DAY 3", "10월 23일 · 00:00 · 마지막 근무"]


func setup() -> void:
	# the boarding wing stays shut until the airport lets you in — as a passenger
	d.set_shutters_for_cycle(2)
	d.t.shutters.gates.open(true)
	d.clock_speed = 0.1
	Game.add_day_pages(3)
	place_documents()
	_reader = CardReader.create(d.t, Vector3(4.7, 1.25, -27.78), 0.0)
	_reader.swiped.connect(_on_wing_reader)
	for x in [2.0, -8.0]:   # either walk-through detector is a passenger lane
		var lane := Geo.area(d.t, Vector3(x, 1.0, -21.0), Vector3(1.4, 2.0, 1.0))
		lane.body_entered.connect(_on_passenger_lane)
	d.t.triggers.emergency_out.body_entered.connect(func(b: Node3D):
		if b.is_in_group("player") and finale and ending == "exit":
			d.start_ending("exit"))


func run() -> void:
	if OS.get_cmdline_user_args().has("--finale"):   # debug: skip the shift, straight to 05:50 at Gate 0
		Game.set_flag("passenger_lane")
		d.t.shutters.corridor.open(true)
		await d.wait(1.0)
		await _finale()
		return
	handover_ambience()
	await night_briefing("마지막 근무네요. 오늘은 탑승동까지 전부예요.")
	d.notify("바인더에 새 페이지가 끼워져 있다. 같은 번호가 두 장인 페이지가 또 있다.", "info")
	var g := d.goal("탑승동 출입", "보안검색 구역 남쪽 [b]탑승동 출입문[/b] 옆 카드 리더에 출입카드를 태그하십시오.", "security")
	await d.until(func(): return Game.flag("card_denied"))
	d.complete_goal(g)
	d.say("…카드가 안 찍힌다.", 2.5)
	await d.radio("안 열려요? …PASSENGER ACCESS ONLY? 그럴 리가 없는데.")
	await d.radio("일단 검색대 승객 통로로 돌아서 들어가 봐요. 거긴 열려 있을 거예요.")
	var g2 := d.goal("승객 통로로 돌아서 들어가기", "보안검색대의 [b]금속 탐지 게이트[/b]를 지나 탑승동으로 들어가십시오.", "security")
	await d.until(func(): return Game.flag("passenger_lane"))
	d.complete_goal(g2)
	await d.radio("…열렸네요. 그럼 시작하죠, 승객분. …아, 점검원님.")
	var plan := NightPlan.build(3)
	await d.run_inspections(plan, {3: _staff_leave, 10: _broadcast, 12: _boarding_call},
		{4: _all_at_once, 12: _gate_before_call})
	if d.dead:
		return
	await _finale()


func _on_wing_reader(r: CardReader) -> void:
	if Game.flag("passenger_lane"):
		r.show_result(true, "PASSENGER")
		return
	r.show_result(false, "PASSENGER\nACCESS ONLY")
	d.ui.postfx.pulse_glitch(0.4)
	Game.set_flag("card_denied")


## The walk-through detector is the passenger way in: it lets you through and the wing opens.
func _on_passenger_lane(body: Node3D) -> void:
	if not body.is_in_group("player") or not Game.flag("card_denied") or Game.flag("passenger_lane"):
		return
	Game.set_flag("passenger_lane")
	Game.set_flag("passenger")
	Snd.play("pa_chime_wrong", -10.0, 1.1, "SFX")
	d.notify("검색대 화면: 탑승객 확인 · PASSENGER — FLIGHT 000", "alert")
	d.office_mode = "passenger"
	d.ui.tablet.boarding_mode = true
	d.t.shutters.corridor.open()
	_reader.show_result(true, "PASSENGER")


func _staff_leave() -> void:
	await d.ev_staff_leave("…승객분, 먼저 들어갈게요. 수칙 꼭 지키세요.")
	if d.dead:
		return
	await d.radio("이제 혼자예요, 승객분. …점검원님.")


## 새벽 전반: three facilities switch on by themselves at once; which one to look at first is up to you.
func _all_at_once(_slot: Dictionary) -> Array:
	await d.radio("…잠깐만요, 승객분. 지금 세 군데서 동시에 신호가 들어와요.")
	var gate_id: String = NightPlan.GATES[randi() % NightPlan.GATES.size()]
	var made: Array = []
	for e in [["pa", "pa_auto"], ["walkway", "auto_run"], [gate_id, "gate_open"]]:
		var f := d.t.facility(e[0])
		d.t.breaker.restore_for(f)
		f.set_anomaly(e[1])
		if e[1] == "gate_open":
			Snd.play_at("door_heavy", f.focus_position(), -4.0, 0.8, 30.0)
		var txt: Array = NightPlan.AUTO_TEXT[e[0]]
		made.append(d.inspect(e[0], txt[0], txt[1], e[1], {"urgent": true, "group": "day3_auto", "slot": 4 + made.size()}))
	d.event_tension = 1.0
	d.notify("시설 세 곳이 동시에 혼자 켜졌다. 어느 것부터 볼지는 당신이 정한다.", "alert")
	return made


func _broadcast() -> void:
	await d.wait(1.0)
	await d.ev_regular_broadcast(false)


## 점검 12 is at a gate — so the boarding call finds you standing in the gate area.
func _gate_before_call(slot: Dictionary) -> Task:
	return d.inspect(slot.fac, slot.title, slot.detail, "", {"slot": 12})


func _boarding_call() -> void:
	await d.wait(1.2)
	await d.ev_boarding_call(false)
	if d.dead:
		return
	await d.radio("…승객분, 방금 방송 들었어요? 다들 기다리고 있대요.")


# --- 06:00 · Gate 0 -------------------------------------------------------------------------------
func _finale() -> void:
	finale = true
	d.jump_clock(5 * 60 + 50)
	d.t.facility("fids").set_story("final", ["SH 000", "GATE 0", "BOARDING"])
	Snd.play("sub_boom", 0.0, 0.8, "SFX")
	d.p.add_shake(0.4)
	d.t.reveal_gate0()   # builds Gate 0 and its jet bridge trigger
	d.t.triggers.board_door.body_entered.connect(func(b: Node3D):
		if b.is_in_group("player") and finale and ending == "board":
			d.start_ending("board"))
	var g0: BoardingGate = d.t.gates["0"]
	g0._set_status("FLIGHT 000\nBOARDING", Color(1.0, 0.3, 0.25))
	d.t.set_zone_light("gates", true)
	await d.radio("05시 50분이에요, 승객분. 0번 게이트로 가는 통로가 열렸대요. 가 보세요.")
	var g := d.goal("0번 게이트 앞으로", "탑승 게이트 구역 북쪽, 처음 보는 [b]0번 게이트[/b] 앞으로 가십시오.", "gates")
	await d.until(func(): return d.p.global_position.z < GATE_FRONT_Z and absf(d.p.global_position.x) < 9.0)
	d.complete_goal(g)
	if d.dead or d.ending_started:
		return
	Game.clock_minutes = 6 * 60
	Events.clock_changed.emit(Game.clock_minutes)
	ending = d.decide_ending()
	d.notify(tr("06:00 · 3일간의 판정 기록 — 정확도 %d%% · 놓친 이상 %d · 수칙 위반 %d · 따른 가짜 수칙 %d") % [d.record_accuracy(),
		int(Game.stats.get("missed", 0)), int(Game.stats.get("violations", 0)), int(Game.stats.get("fake_followed", 0))], "info")
	await d.wait(2.0)
	match ending:
		"exit":
			await _exit_lights()
		"board":
			await _board_sign()
		_:
			await _your_voice()


## 정상 개장: the EXIT signs light up and the chained emergency door opens.
func _exit_lights() -> void:
	Game.set_flag("main_power_cut")   # ShiftDirector._on_exit_door opens the door once this is set
	d.t.emergency_light_root.visible = true
	for i in 3:
		var ch := d.t.get_node_or_null("Chain%d" % i)
		if ch:
			ch.visible = false
	d.t.exit_door_use.prompt = "비상구로 나가기"
	d.t.doors.emergency.open()
	Snd.play("beep_ok", -4.0, 0.9)
	d.notify("체크인 홀 쪽에서 초록 EXIT 표시에 불이 들어왔다.", "good")
	d.objective("EXIT 표시를 따라 나가십시오. (체크인 홀 남측 비상구)")


## 탑승: only one sign is lit — BOARD, into Gate 0.
func _board_sign() -> void:
	var g0: BoardingGate = d.t.gates["0"]
	g0._set_status("BOARD  →", Geo.SIGN_BLUE)
	g0.open_door(true)
	d.notify("0번 게이트 위에 BOARD 표시가 켜졌다. 다른 표시는 모두 꺼져 있다.", "alert")
	d.objective("BOARD 표시를 따라가십시오.")
	while finale and not d.dead and not d.ending_started:
		await d.pa(["pa_final_call_ko", "pa_final_call_en"], {"wrong": true, "tag": "final",
			"subs": ["영편 최종 탑승 안내입니다. 아직 탑승하지 않으신 승객께서는, 지금 즉시 영번 게이트로 오시기 바랍니다.",
				"This is the final boarding call for flight zero. Remaining passenger, please proceed to gate zero immediately."]})
		await d.wait(18.0)


## 세 번째 엔딩: the PA comes on — in your own voice.
func _your_voice() -> void:
	d.p.controls_enabled = false
	d.notify("안내 데스크 마이크에 불이 들어왔다. 터미널에 울리는 목소리는 — 당신의 것이다.", "alert")
	await d.pa(["name_call"], {"wrong": true, "pitch": 0.94, "no_end": true,
		"subs": [tr("%s 승객님. %s 승객님. 영번 게이트로 오시기 바랍니다. 기다리고 있습니다.") % [Game.player_name, Game.player_name]]})
	await d.wait(1.0)
	d.start_ending("announce")
