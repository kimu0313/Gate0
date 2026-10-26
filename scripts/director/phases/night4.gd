extends PhaseScript
## DAY 4 — 10/22 · +탑승동 통로 (무빙워크) + 탑승 게이트. 바인더에 p.6 · p.8과 가짜 수칙 f4 · f8.
## (Day1~5 초안 · Day 4: 1987년 신문 스크랩 · 수색 종료 보고서 · 젖은 물건들 · 본격적인 이상 · 소장의 경고 회수)
## 출근: 사무실 책상 서랍이 반쯤 열려 있다 — 누렇게 바랜 1987년 신문 스크랩 묶음(A0편 수색 3주째… 수색 종료)과 그
## 사이의 공문: "발견물 없음. 기체 이륙 여부 재확인 요망."
## 탑승동 출입문이 직원 카드를 "PASSENGER ACCESS ONLY"로 거부한다 → 보안검색대 승객 통로로 돌아서 들어간다.
## 교대 근무자는 출입문 앞에서 당신을 "승객분"이라고 부르고, p.6 · p.8 추록과 새 탑승동 출입카드를 건넨다 — 거부된다.
## 새벽 전반 (점검 4–6): 시설 셋이 동시에 혼자 켜진다. 점검 7 뒤: 어제 그 테이프가 PA 콘솔에서 저절로 재생되고, 끊긴
## 데 너머 잡음 속 목소리가 당신의 이름을 부른다 (수칙 p.9 ②). 점검 8: 수하물 벨트에 바닷물에 젖은 1980년대 가방 →
## 분실물 보관함의 비행기표도 젖어 있다. 03:00 정기 방송: 밤 11시 40분, 서해비행장, 마지막 수하물이 도착했다.
## 점검 12: 게이트 대기석에 누군가 앉아 있다. 06:00 퇴근 → 근태 기록기에 한 줄이 더: PASSENGER · 10/23 06:00 · GATE 0.

const POST := "npc_wing"   # Terminal spot: by the boarding-wing door and its card reader
const TALK := [
	["오늘은 탑승동까지 다 보셔야 해요, 승객분. …아, 점검원님.", ""],
	["6페이지, 8페이지 추록이요. 무빙워크랑 탑승구.", "pages"],
	["탑승동 출입카드도 새로 나왔대요. 저 문 옆 리더에 찍으면 돼요.", "card"],
	["사무실 서랍이요? …그거 제가 열어 둔 거 아니에요.", ""],
	["게이트 대기석에 누가 앉아 있어도 다가가지 마요. 수칙 8페이지. …그럼, 먼저 갈게요.", ""],
]

var _reader: CardReader


func title_lines() -> Array:
	return ["DAY 4", "10월 22일 · 00:00 · 탑승동 · 탑승 게이트"]


func setup() -> void:
	# the boarding wing stays shut until the airport lets you in — as a passenger
	d.set_shutters_for_cycle(3)
	d.t.shutters.gates.open(true)
	d.clock_speed = 0.1
	place_documents()
	d.t.open_drawer(true)
	d.t.drawer_use.enabled = true
	d.t.drawer_use.callback = _read_drawer
	d.t.lost_found.enabled = true
	d.t.lost_found.callback = _open_lost_found
	_reader = CardReader.create(d.t, d.t.spot("wing_reader"), 0.0)
	_reader.swiped.connect(_on_wing_reader)
	for md in ["md_east", "md_west"]:   # either walk-through detector is a passenger lane
		var lane := Geo.area(d.t, d.t.spot(md) + Vector3(0, 1.0, 0), Vector3(1.4, 2.0, 1.0))
		lane.body_entered.connect(_on_passenger_lane)
	spawn_worker(d.t.spot(POST), 0.0)


func run() -> void:
	handover_ambience()
	await d.wait(1.0)
	d.notify("책상 옆 서랍 하나가 반쯤 열려 있다.", "info")
	await use_goal("열린 서랍 확인", "시설관리실 책상 옆 [b]서랍[/b]이 열려 있습니다. 확인하십시오.", "office", d.t.drawer_use,
		func(): return Game.has_clue("search_report"))
	if d.dead:
		return
	d.say("발견물 없음… 이륙했는지도 모른다고? 비행기가 떴는지조차?", 4.0)
	await night_briefing("넷째 날이에요. 오늘은 탑승동까지 전부예요. 교대 근무자가 탑승동 출입문 앞에 있어요.")
	await colleague_handover("보안검색 구역 북쪽 끝 [b]탑승동 출입문[/b] 앞의 저녁 근무자에게 [E]로 인수인계를 받으십시오.", "security", TALK, _give)
	if d.dead:
		return
	await d.wait(1.5)
	Game.add_day_pages(4, "fake")
	d.notify("바인더에 같은 번호가 두 장인 페이지가 또 있다. 받은 적 없는 페이지다.", "info")
	var g := d.goal("탑승동 출입", "보안검색 구역 북쪽 끝 [b]탑승동 출입문[/b] 옆 카드 리더에 출입카드를 태그하십시오.", "security",
		{"target": _reader.interactable})
	await d.until(func(): return Game.flag("card_denied"))
	d.complete_goal(g)
	d.say("…방금 받은 카드인데, 안 찍힌다.", 2.5)
	await d.radio("안 열려요? …PASSENGER ACCESS ONLY? 그럴 리가 없는데.")
	await d.radio("일단 검색대 승객 통로로 돌아서 들어가 봐요. 거긴 열려 있을 거예요.")
	var g2 := d.goal("승객 통로로 돌아서 들어가기", "보안검색대의 [b]금속 탐지 게이트[/b]를 지나 탑승동으로 들어가십시오.", "security")
	await d.until(func(): return Game.flag("passenger_lane"))
	d.complete_goal(g2)
	await d.radio("…열렸네요. 그럼 시작하죠, 승객분. …아, 점검원님.")
	var plan := NightPlan.build(4)
	await d.run_inspections(plan, {3: _lights_down, 7: _tape_by_itself, 8: _wet_ticket, 10: _broadcast},
		{4: _all_at_once, 8: _wet_bag, 12: _gate_passenger})
	if d.dead:
		return
	await d.radio("…끝났어요. 퇴근 찍으세요, 승객분. 내일이 개장일이에요.")
	await punch_out()


## The scrap bundle, and the 1987 report clipped in among the cuttings.
func _read_drawer() -> void:
	if d.ui.modal != "":
		return
	await d.read_clue("scraps", "serif")
	await d.wait(0.3)
	d.notify("스크랩 사이에서 공문 한 장이 미끄러져 나왔다.", "info")
	await d.read_clue("search_report", "sans")


## DAY 4: the boarding pass from the lost-and-found is soaked in sea water now.
func _open_lost_found() -> void:
	Snd.play_at("door_heavy", d.t.lost_found.global_position, -12.0, 1.4, 4.0)
	await d.read_clue("ticket_wet", "sans", [], {"stain": true})


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


func _give(item: String) -> void:
	match item:
		"pages":
			hand_pages(["p6", "p8"], "근무 수칙 p.6 무빙워크 · p.8 탑승구 (추록) 수령 — 바인더에 끼움")
		"card":
			d.npc.present("card", 3.0)
			Game.set_flag("got_wing_card")
			Snd.play("card_beep", -6.0)
			d.notify("탑승동 출입카드 수령 — 출입문 옆 카드 리더에 태그", "good")


func _lights_down() -> void:
	await d.ev_lights_down("01시예요, 승객분. …저녁 근무자들 다 나갔어요.", "이제 혼자예요, 승객분. …점검원님.")


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
		made.append(d.inspect(e[0], txt[0], txt[1], e[1], {"urgent": true, "group": "day4_auto", "slot": 4 + made.size()}))
	d.event_tension = 1.0
	d.notify("시설 세 곳이 동시에 혼자 켜졌다. 어느 것부터 볼지는 당신이 정한다.", "alert")
	return made


## 소장의 경고 회수: yesterday's tape plays by itself from the PA console — and goes on past where it broke off.
func _tape_by_itself() -> void:
	await d.wait(2.0)
	d.notify("안내 데스크 쪽 스피커에서 테이프 감기는 소리가 난다.", "alert")
	Snd.play_at("glitch", d.t.facility("pa").focus_position(), -12.0, 0.6, 12.0, 60.0)
	await d.wait(2.5)
	await d.ev_tape(true)
	if d.dead:
		return
	await d.wait(1.5)
	await d.radio("…방금 그거, 그 테이프죠. 틀지 말라고 했잖아요.")
	await d.radio("…안 틀었다고요? 그럼, 누가.")


## 점검 8: among the test bags, a 1980s leather suitcase soaked in sea water.
func _wet_bag(slot: Dictionary) -> Task:
	return d.inspect("baggage", slot.title, slot.detail, "bag_wet", {"slot": 8})


## …and the boarding pass in the lost-and-found is wet too.
func _wet_ticket() -> void:
	if not Game.has_clue("ticket"):
		return
	await d.wait(1.5)
	d.say("바닷물 냄새… 창고 분실물 보관함, 그 비행기표.", 3.0)
	await use_goal("분실물 보관함 다시 확인 (자재창고)", "[b]자재창고[/b] 분실물 보관함의 1987년 탑승권을 다시 확인하십시오.", "storage",
		d.t.lost_found, func(): return Game.has_clue("ticket_wet"))
	if d.dead:
		return
	d.say("수색에선 아무것도 못 찾았는데… 바다에서 못 찾은 것들이, 여기로 돌아오고 있다.", 4.5)


## 03:00 — 23:40 again, 서해비행장, and the last baggage has arrived.
func _broadcast() -> void:
	await d.wait(1.0)
	await d.ev_regular_broadcast(false, false)


## 점검 12: someone is sitting in the gate's waiting seats (수칙 p.8 ③ vs the fake f8).
func _gate_passenger(slot: Dictionary) -> Task:
	return d.inspect(slot.fac, slot.title, slot.detail, "gate_passenger", {"slot": 12})


## The time clock prints one line more than it should.
func end_cut() -> void:
	await d.ui.fade_to(1.0, 0.8)
	await d.ui.typewriter([
		"퇴근 기록을 찍자, 근태 기록기가 한 줄을 더 뱉어 냈다.",
		"",
		"PASSENGER · %s" % Game.player_name,
		"10/23 06:00 · GATE 0",
	])
