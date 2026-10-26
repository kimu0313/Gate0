extends PhaseScript
## DAY 5 — 10/23, 개장일 새벽 · 마지막 근무. 모든 구역이 열려 있고, 터미널은 이미 당신을 승객으로 안다.
## 교대 근무자는 안내 데스크에 있다 ("닷새를 다 채운 분은 처음 봐요"). 바닥에 떨어져 있었다며 탑승권을 건넨다 —
## FLIGHT A0, 23:40, 당신의 이름. 분실물 보관함의 1987년 탑승권은 여전히 젖어 있다.
## "게이트에서 봬요" — 그리고 탑승동 쪽으로 걸어가 사라진다.
## 비상 수칙이 차례로 시험된다: 점검 6 뒤 이름을 부르는 방송(p.9 ②), 점검 8 뒤 정전(p.9 ①), 03:00 정기 방송(p.9 ③).
## 새벽 후반 (점검 12 직후): 수칙끼리 충돌 — 방송 중에는 움직이지 마라(p.9 ③) vs 탑승 안내가 나오면 즉시
## 게이트를 떠나라(p.8 ④, 더 늦은 추록 → p.1 5에 따라 우선).
## 06:00 직전 Gate 0으로 가는 통로가 처음 열리고, 닷새간의 판정 기록이 엔딩을 고른다:
##   정상 개장 — EXIT 표시가 켜지고 비상구로 나간다 · 탑승 — BOARD 표시를 따라 Gate 0으로 · 안내방송 — 당신의 목소리.

const GATE_FRONT_Z := -92.0

const POST := "npc_info"   # Terminal spot: at the information desk
const TALK := [
	["마지막 근무네요. 닷새를 다 채운 분은… 처음 봐요.", ""],
	["오늘이 개장일이에요.", ""],
	["세 시 방송, 이름 부르는 방송, 정전. 수칙 9페이지 다시 봐 둬요.", ""],
	["아, 이거. 아까 바닥에 떨어져 있었어요. …당신 이름이던데요.", "pass"],
	["그럼… 게이트에서 봬요.", ""],
]

var finale := false
var ending := ""


func title_lines() -> Array:
	return ["DAY 5", "10월 23일 · 00:00 · 개장일 · 마지막 근무"]


func setup() -> void:
	d.set_shutters_for_cycle(5)
	d.clock_speed = 0.1
	Game.add_day_pages(5)
	place_documents()
	# since yesterday the terminal only knows you as a passenger
	Game.set_flag("card_denied")
	Game.set_flag("passenger_lane")
	Game.set_flag("passenger")
	d.office_mode = "passenger"
	d.ui.tablet.boarding_mode = true
	var reader := CardReader.create(d.t, d.t.spot("wing_reader"), 0.0)
	reader.swiped.connect(func(r: CardReader): r.show_result(true, "PASSENGER"))
	d.t.lost_found.enabled = true
	d.t.lost_found.callback = func(): d.read_clue("ticket_wet", "sans", [], {"stain": true})
	spawn_worker(d.t.spot(POST), 0.0)
	d.t.triggers.emergency_out.body_entered.connect(func(b: Node3D):
		if b.is_in_group("player") and finale and ending == "exit":
			d.start_ending("exit"))


func run() -> void:
	if OS.get_cmdline_user_args().has("--finale"):   # debug: skip the shift, straight to 05:50 at Gate 0
		if d.npc:
			d.npc.queue_free()
			d.npc = null
		await d.wait(1.0)
		await _finale()
		return
	handover_ambience()
	await night_briefing("마지막 근무네요, 승객분. …오늘은 개장일이에요. 전 구역 다 봐야 해요.")
	await colleague_handover("체크인 홀 [b]안내 데스크[/b] 앞의 저녁 근무자에게 [E]로 인수인계를 받으십시오.", "hall", TALK, _give, "wing")
	if d.dead:
		return
	var plan := NightPlan.build(5)
	await d.run_inspections(plan, {3: _lights_down, 6: _namecall, 8: _blackout, 10: _broadcast, 12: _boarding_call},
		{12: _gate_before_call})
	if d.dead:
		return
	await _finale()


## The boarding pass they "found on the floor": FLIGHT 000, your name.
func _give(item: String) -> void:
	if item != "pass":
		return
	d.npc.present("pass", 3.0)
	Game.set_flag("boarding_pass")
	Snd.play("page_flip", -4.0, 1.1)
	d.ui.read_doc("탑승권 — FLIGHT A0", tr("PASSENGER　%s\nFLIGHT　A0\nFROM　SEOHAE · 서해\nTO　HOME · 집\nGATE　0\nBOARDING　23:40\nSEAT　—\n\n탑승이 확인되었습니다.") % Game.player_name, "mono")
	await d.until(func(): return d.ui.modal != "doc" or d.dead)


## 01:00 — the manager has a question about the colleague you were talking to.
func _lights_down() -> void:
	await d.ev_lights_down("01시예요, 승객분. 저녁 근무자들 다 나갔어요. …근데 아까 누구랑 얘기했어요? 오늘 저녁 근무자 명단엔 이름이 없는데.",
		"이제 혼자예요, 승객분. …마지막이에요.")


## 새벽 전반: the PA calls your name (수칙 p.9 ②: do not answer, do not move until it ends).
func _namecall() -> void:
	await d.wait(1.2)
	await d.ev_namecall(false)
	if d.dead:
		return
	await d.radio("…방금 방송, 누구 이름이었어요? 제 쪽에선 잡음만 들렸어요.")


## The lights go out (수칙 p.9 ①: close your eyes where you stand until they come back).
func _blackout() -> void:
	await d.wait(1.5)
	await d.ev_blackout(12.0, false, true)


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
	d.t.facility("fids").set_story("final", ["A0  23:40", "GATE 0", "BOARDING"])
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
	d.notify(tr("06:00 · 닷새간의 판정 기록 — 정확도 %d%% · 놓친 이상 %d · 수칙 위반 %d · 따른 가짜 수칙 %d") % [d.record_accuracy(),
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
