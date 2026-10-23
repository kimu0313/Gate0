extends PhaseScript
## DAY 3 — 10/21 · +보안검색대. 교대 근무자가 X-ray 옆에서 p.7 추록과 검색대 옆 사물함 열쇠를 건네고 퇴근한다.
## 그 뒤 바인더에는 받은 적 없는 첫 가짜 수칙(f7: 붉은 도장 없는 손글씨 7페이지)이 끼워져 있고, p.3은 젖어 번졌다.
## 사물함에서 사라진 정비사의 업무일지를 찾는다.
## 새벽 전반 (점검 6): 무전 돌발 호출 — 빈 벨트 위에 캐리어 하나, 이름표에 당신의 이름. 하루의 가장 큰 판정.
## 새벽 후반 (점검 11): X-ray 판독 화면에 당신의 가방이 승객 수하물로 찍힌다.
## 마지막 장면: 업무일지 마지막 줄 — "수칙 7번은 내가 쓴 게 아니다."


const POST := Vector3(-2.0, 0, -18.4)   # between the X-ray lanes, by the lane 1 monitor desk
const TALK := [
	["오늘은 보안검색대까지네요. 엑스레이는 가방 투입을 누르고 판독 화면을 보면 돼요.", ""],
	["7페이지 추록이요. 정상 판독 화면은 노트북, 물병, 열쇠, 케이블. 그게 다예요.", "p7"],
	["그리고 이거, 검색대 옆 사물함 열쇠. 전에 있던 정비사분 물건이 남아 있대요.", "key"],
	["어느 날부터 안 나오셨대요. …먼저 들어갈게요. 사물함 일지는, 끝까지 읽지 마요.", ""],
]


func title_lines() -> Array:
	return ["DAY 3", "10월 21일 · 00:00 · 보안검색 구역"]


func setup() -> void:
	d.set_shutters_for_cycle(3)
	d.clock_speed = 0.1
	place_documents()
	spawn_worker(POST, StaffNpc.yaw_for(Vector3(-1.5, 0, -2.6)))


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
	var g := d.goal("보안검색대 옆 사물함 확인", "보안검색 구역 동쪽 벽 [b]직원 사물함[/b]에 전 정비 담당자의 물건이 남아 있습니다. 확인하십시오.", "security")
	d.radio_async("검색대 옆 사물함에 전 정비 담당자 짐이 남아 있대요. 한번 봐 줄래요?")
	await d.until(func(): return Game.has_clue("log2"))
	d.complete_goal(g)
	await d.radio("…정비 담당자요? 지난주에 그만뒀다던데. 연락이 안 된대요.")
	var plan := NightPlan.build(3)
	await d.run_inspections(plan, {3: _lights_down, 6: _after_bag, 10: _broadcast}, {6: _name_bag_call, 11: _xray_mybag})
	if d.dead:
		return
	await d.radio("…오늘도 끝났네요. 퇴근 찍어요.")
	await punch_out()


func _give(item: String) -> void:
	match item:
		"p7":
			hand_pages(["p7"], "근무 수칙 p.7 보안검색 X-ray (추록) 수령 — 바인더에 끼움")
		"key":
			d.npc.present("key", 3.0)
			Game.set_flag("got_locker_key")
			Snd.play("button_press", -6.0, 1.3)
			d.notify("사물함 열쇠 수령 — 보안검색 구역 동쪽 벽 직원 사물함", "good")
			var e: Array = DOCS["log2"]
			d.spawn_doc("log2", e[0], e[1], e[2])


func _lights_down() -> void:
	await d.ev_lights_down("01시예요. 저녁 근무자들 다 나갔어요.")


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


## 새벽 후반: the X-ray scans your bag as a passenger's (수칙 p.7 ③ vs the fake handwritten f7 ③).
func _xray_mybag(slot: Dictionary) -> Task:
	return d.inspect("xray", slot.title, slot.detail, "xray_mybag", {"slot": 11})


func _broadcast() -> void:
	await d.wait(1.0)
	await d.ev_regular_broadcast(false)


## The work log's last page — a line that was not there when you first opened it.
func end_cut() -> void:
	await d.ui.fade_to(1.0, 0.8)
	Game.add_clue("log2_last")
	await d.ui.typewriter([
		"사물함에서 가져온 업무일지.",
		"처음 펼쳤을 때는 분명 비어 있던 마지막 장.",
		"",
		"\"수칙 7번은 내가 쓴 게 아니다.\"",
	])
