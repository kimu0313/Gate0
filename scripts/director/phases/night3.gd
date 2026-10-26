extends PhaseScript
## DAY 3 — 10/21 · +보안검색대. 교대 근무자가 X-ray 옆에서 p.7 추록을 건네고 퇴근한다. 그 뒤 바인더에는 받은 적
## 없는 첫 가짜 수칙(f7: 붉은 도장 없는 손글씨 7페이지)이 끼워져 있고, p.3은 젖어 번졌다.
## (Day1~5 초안 · Day 3: 관제 교신 녹취 테이프 · 소장의 반응 · 이관 장비 목록 · 승객들의 수 · A0편의 존재)
## 01:00 혼자가 되자 안내 데스크 PA 콘솔에 경고 — SPK-07 출력 없음, 예비 모듈은 자재창고 이관 설비 상자. 상자 안에는
## 예비 앰프와 "A0 / 87.11.03" 카세트테이프, 그리고 이관 목록: 방송 콘솔과 스피커는 구 A비행장 설비를 그대로 쓴다.
## 콘솔에 모듈을 끼우고 내장 데크로 테이프를 틀면 터미널 전체에 1987년 관제 교신이 흐르다 조종사가 무언가 말하려는
## 순간 끊긴다. 무전으로 보고하자 소장은 창고가 어디 있는지도 몰랐다는 듯 추궁하고, 날짜 얘기는 피하고, 경고를
## 남긴다: 다시 틀지 마라 — 끊긴 데 너머를 들으면 저쪽도 당신을 듣는다 (DAY 4에 회수).
## 새벽 전반 (점검 6): 무전 돌발 호출 — 빈 벨트 위의 캐리어, 이름표에 당신의 이름. 점검 8: 전광판 맨 위에 없는 항공편
## A0이 DEPARTED. 새벽 후반 (점검 11): 가방 하나를 넣었는데 X-ray 화면에 승객 소지품 41개가 연달아 지나간다.

const POST := "npc_xray"   # Terminal spot: between the X-ray lanes, by the lane 1 monitor desk
const TALK := [
	["오늘은 보안검색대까지네요. 엑스레이는 가방 투입을 누르고 판독 화면을 보면 돼요.", ""],
	["7페이지 추록이요. 정상 판독 화면은 노트북, 물병, 열쇠, 케이블. 그게 다예요.", "p7"],
	["어제 분실물 보관함 열어 보셨어요? …아뇨, 저는 열어 본 적 없어요. 그냥 물어본 거예요.", ""],
	["사흘째네요. 먼저 들어갈게요.", ""],
]
## the radio exchange after the tape: [speaker, line]
const REPORT := [
	["나", "소장님. 자재창고 이관 설비 상자에서 테이프가 하나 나왔는데요."],
	["소장", "…자재창고요? 그쪽에 창고가 있어요? 제 도면엔 그냥 벽인데요."],
	["소장", "거길 어떻게 찾아 들어갔어요? 누가 알려 줬어요?"],
	["나", "콘솔 진단 화면에 위치가 나와 있었어요. 테이프엔 날짜가 적혀 있고요. 87년 11월 3일, A0…"],
	["소장", "…그건 됐고요."],
	["소장", "하나만 말할게요. 그 테이프, 다시는 틀지 마세요. 끊긴 데서 끝나는 게 맞아요."],
	["소장", "그 너머를 들으면, 저쪽에서도 당신을 듣게 돼요. 이름 같은 건 더더욱 말하지 말고요. …점검 계속하세요."],
]

var pa: PaConsole


func title_lines() -> Array:
	return ["DAY 3", "10월 21일 · 00:00 · 보안검색 구역"]


func setup() -> void:
	d.set_shutters_for_cycle(3)
	d.clock_speed = 0.1
	pa = d.t.facility("pa")
	place_documents()
	d.t.lost_found.enabled = true
	d.t.lost_found.callback = func(): d.read_clue("ticket", "sans")
	spawn_worker(d.t.spot(POST), StaffNpc.yaw_for(Vector3(-1.5, 0, -2.6)))


func run() -> void:
	handover_ambience()
	await night_briefing("셋째 날이에요. 오늘은 보안검색대까지 봐야 해요. 교대 근무자가 X-ray 쪽에 있어요.")
	await colleague_handover("보안검색 구역 [b]X-ray 1번[/b] 옆의 저녁 근무자에게 [E]로 인수인계를 받으십시오.", "security", TALK, _give)
	if d.dead:
		return
	# once they are gone: a page nobody handed over, and p.3 soaked through
	await d.wait(2.0)
	Game.add_day_pages(3, "fake")
	d.notify("바인더를 펼치자, 받은 적 없는 7페이지가 한 장 더 끼워져 있다. 3페이지는 젖어서 글자가 번져 있다.", "info")
	await d.radio("새 페이지들 확인해 두세요. …7페이지가 두 장이네요? 한 장은 손글씨인데.")
	var plan := NightPlan.build(3)
	await d.run_inspections(plan, {3: _lights_down, 6: _after_bag, 8: _after_a0, 10: _broadcast},
		{6: _name_bag_call, 8: _a0_departed, 11: _xray_41})
	if d.dead:
		return
	await d.radio("…오늘도 끝났네요. 퇴근 찍어요.")
	await punch_out()


func _give(item: String) -> void:
	if item == "p7":
		hand_pages(["p7"], "근무 수칙 p.7 보안검색 X-ray (추록) 수령 — 바인더에 끼움")


func _lights_down() -> void:
	await d.ev_lights_down("01시예요. 저녁 근무자들 다 나갔어요.")
	if d.dead:
		return
	await _the_tape()


## 01:00 — the PA console reports a dead speaker; the spare part is in a crate the old airfield's equipment came in.
func _the_tape() -> void:
	await d.wait(2.0)
	pa.set_fault(true)
	Snd.play_at("ui_alert", pa.focus_position(), -6.0, 0.7, 20.0, 60.0)
	d.notify("안내 데스크 PA 콘솔에서 경고음이 울린다.", "alert")
	pa.service.enabled = true
	pa.service.prompt = "콘솔 경고 표시 확인"
	pa.service.callback = func(): d.read_clue("pa_diag", "mono")
	await use_goal("PA 콘솔 경고 확인", "체크인 홀 [b]안내 데스크 PA 콘솔[/b]에 경고가 들어왔습니다. 콘솔의 진단 표시를 확인하십시오.",
		"hall", pa.service, func(): return Game.has_clue("pa_diag"))
	if d.dead:
		return
	pa.service.enabled = false
	d.t.crate_use.enabled = true
	d.t.crate_use.callback = _open_crate
	await use_goal("예비 앰프 모듈 가져오기 (자재창고)", "[b]자재창고[/b]의 이관 설비 상자에서 예비 앰프 모듈(AMP-2)을 꺼내 오십시오.",
		"storage", d.t.crate_use, func(): return Game.flag("got_amp"))
	if d.dead:
		return
	d.say("A0, 87.11.03… 비행기표랑 같은 날짜다. 그리고 방송 콘솔이 — 그때 그 비행장 거라고?", 4.5)
	pa.service.enabled = true
	pa.service.prompt = "예비 앰프 모듈 끼우기"
	pa.service.callback = func():
		Snd.play_at("switch_heavy", pa.focus_position(), -8.0, 1.3, 4.0)
		pa.set_fault(false)
		Game.set_flag("amp_fixed")
		d.notify("SPK-07 출력 복구. 콘솔이 다시 시작됐다.", "good")
	await use_goal("PA 콘솔에 앰프 모듈 끼우기", "[b]안내 데스크 PA 콘솔[/b]의 데크 쪽 모듈 칸에 예비 앰프 모듈을 끼우십시오.",
		"hall", pa.service, func(): return Game.flag("amp_fixed"))
	if d.dead:
		return
	await d.wait(1.0)
	d.say("콘솔에 테이프 데크가 달려 있다. …한번 틀어 볼까.", 3.0)
	pa.service.prompt = "테이프 넣고 재생"
	pa.service.callback = func():
		pa.service.enabled = false
		Game.set_flag("tape_played")
	await use_goal("테이프 재생해 보기", "PA 콘솔 왼쪽의 [b]테이프 데크[/b]에 카세트테이프를 넣고 재생하십시오.", "hall", pa.service,
		func(): return Game.flag("tape_played"))
	if d.dead:
		return
	Snd.play_at("button_press", pa.focus_position(), -4.0, 0.7, 4.0)
	await d.wait(0.8)
	await d.ev_tape(false)
	if d.dead:
		return
	await d.wait(2.0)
	for l in REPORT:
		await d.radio(l[1], l[0])
		if d.dead:
			return


func _open_crate() -> void:
	if Game.flag("got_amp"):
		return
	d.t.open_crate()
	Snd.play_at("door_heavy", d.t.crate.global_position, -10.0, 1.6, 4.0)
	await d.read_clue("transfer_list", "sans")
	Game.set_flag("got_amp")
	Game.set_flag("got_tape")
	d.t.crate_use.enabled = false
	Snd.play("button_press", -6.0, 1.3)
	d.notify("예비 앰프 모듈과 카세트테이프 한 개를 꺼냈다. 테이프 라벨: A0 / 87.11.03", "good")


## 새벽 전반 · 돌발 호출: an empty conveyor, one suitcase going round. Its tag has your name on it.
func _name_bag_call(_slot: Dictionary) -> Task:
	await d.radio("수하물 쪽 벨트 돌아가는 소리 나는데, 확인 좀 해 주세요.")
	var belt: BaggageBelt = d.t.facility("baggage")
	d.t.breaker.restore_for(belt)   # it runs by itself — even if its circuit was cut for an earlier response
	belt.reset_for_inspection()
	belt.set_anomaly("bag_name")
	belt.start(false)
	Snd.play_at("power_up", belt.global_position, -6.0, 0.8, 18.0)
	return d.inspect("baggage", "⚠ 수하물 B-03 — 혼자 도는 벨트",
		"아무도 가동하지 않은 [b]B-03[/b]이 돌고 있습니다. 현장에서 벨트 위를 끝까지 확인하고 보고하십시오. (수칙 p.5)",
		"bag_name", {"urgent": true, "slot": 6})


func _after_bag() -> void:
	await d.radio("…가방이요? 이 시간에 수하물이 나올 리가 없는데. 이름표는… 아니, 말하지 마요.")


## 점검 8: a flight that does not exist tops the departure board — A0, 23:40, GATE 0, DEPARTED.
func _a0_departed(slot: Dictionary) -> Task:
	return d.inspect(slot.fac, slot.title, slot.detail, "fids_a0", {"slot": 8})


func _after_a0() -> void:
	if Game.has_clue("miss_fids_a0"):
		return
	d.say("A0… 떠났다고? 지금 그런 편은 없는데.", 3.0)


## 새벽 후반: one test bag goes in, and 41 passengers' belongings come through (수칙 p.7 ④ vs the fake f7).
func _xray_41(slot: Dictionary) -> Task:
	return d.inspect("xray", slot.title, slot.detail, "xray_41", {"slot": 11})


func _broadcast() -> void:
	await d.wait(1.0)
	await d.ev_regular_broadcast(false)


## Clocking out, a tape winding somewhere in the hall — and the deck is empty.
func end_cut() -> void:
	await d.ui.fade_to(1.0, 0.8)
	await d.ui.typewriter([
		"퇴근 기록을 찍는 순간, 안내 데스크 쪽 스피커에서 테이프 감기는 소리가 났다.",
		"",
		"콘솔의 테이프 데크는 비어 있었다.",
	])
