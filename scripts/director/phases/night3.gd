extends PhaseScript
## NIGHT 3 — 10/20. +보안검색대·무빙워크. 첫 가짜 수칙(f5, 1987년 개정일·검은 도장).
## 자율 가동 본격화: 자정에 방송이 혼자 나오고, 6번째 점검 전 MW-1이 혼자 움직인다.


func title_lines() -> Array:
	return ["NIGHT 3", "10월 20일 · 23:00 · 야간 시설 점검"]


func setup() -> void:
	d.set_shutters_for_cycle(3)
	d.clock_speed = 0.12
	Game.add_binder_page("f5")
	place_documents()


func run() -> void:
	await night_briefing("오늘 밤은 보안검색대랑 통로까지예요. 무빙워크는 꼭 정지 상태 확인하고요.")
	d.notify("바인더에 낯선 페이지가 한 장 끼워져 있다.", "info")
	var plan := NightPlan.build(3)
	await d.run_inspections(plan, {2: _midnight, 4: _slow_pa, 8: _blackout})
	if d.dead:
		return
	var mw: MovingWalkway = d.t.facility("walkway")
	if mw.running:
		mw.press_stop()
	await d.radio("…오늘은 공항이 저 혼자 일하는 것 같네요. 퇴근 찍어요.")
	await punch_out("근무 종료 기록", "시설관리실 [b]근태 기록기[/b]에서 근무 종료를 기록하십시오.")


func _midnight() -> void:
	d.jump_clock(24 * 60)
	await d.wait(2.0)
	await d.pa(["pa_flight0_move_ko", "pa_flight0_move_en"], {"wrong": true, "tag": "auto",
		"subs": ["영편 승객께서는 출국장으로 이동해 주시기 바랍니다.", "Passengers of flight zero, please proceed to the departure area."]})
	await d.radio("…방금 방송 뭐예요? 콘솔 건드렸어요? …안 건드렸다고요?")


func _slow_pa() -> void:
	await d.wait(2.0)
	await d.ev_slow_broadcast(false)


func _blackout() -> void:
	await d.wait(1.5)
	await d.ev_blackout(10.0, false)
