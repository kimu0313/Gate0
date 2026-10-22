extends PhaseScript
## NIGHT 4 — 10/21. +탑승 게이트. 수칙끼리 충돌한다(f4 · f6 · f7과 진짜 p.4 · p.6 · p.7).
## 비상 수칙 위반은 이제 치명적이다. 근무가 끝나면 공항이 당신을 승객으로 재분류한다:
## ACCESS DENIED → "그 번호, 직원 번호가 아닙니다" → 태블릿이 BOARDING INFORMATION으로 → PASSENGER ACCESS.


func title_lines() -> Array:
	return ["NIGHT 4", "10월 21일 · 23:00 · 야간 시설 점검"]


func setup() -> void:
	d.set_shutters_for_cycle(4)
	d.clock_speed = 0.12
	for id in ["f4", "f6", "f7"]:
		Game.add_binder_page(id)
	place_documents()


func run() -> void:
	await night_briefing("오늘부터 게이트 구역도 점검해요. 개장 이틀 전이라 다들 예민해요.")
	d.notify("바인더에 같은 번호의 페이지가 두 장씩 끼워져 있다…", "info")
	var plan := NightPlan.build(4)
	await d.run_inspections(plan, {3: _namecall, 8: _three_am})
	if d.dead:
		return
	await _reclassified()
	if d.dead:
		return
	await punch_out("근무 종료 기록", "시설관리실 [b]근태 기록기[/b]에서 근무 종료를 기록하십시오.")


func _namecall() -> void:
	await d.wait(2.0)
	await d.ev_namecall(true)


func _three_am() -> void:
	d.jump_clock(27 * 60)
	await d.wait(1.0)
	await d.ev_3am(true)


## The airport does not know you work here any more.
func _reclassified() -> void:
	await d.radio("오늘 점검 끝이에요. 사무실로 와서 퇴근 찍어요.")
	var g := d.goal("근무 종료 — 시설관리실 복귀", "시설관리실 출입문 [b]카드 리더[/b]에 출입카드를 태그하십시오.", "office")
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
	Game.set_flag("passenger")
	d.office_mode = "passenger"
	d.ui.tablet.boarding_mode = true
	d.ui.postfx.pulse_glitch(0.9)
	Snd.play("ui_alert", -2.0, 0.7)
	d.notify("태블릿: MAINTENANCE TASKS → BOARDING INFORMATION", "alert")
	await d.pa(["pa_flight0_checkin_ko", "pa_destination_home_ko"], {"wrong": true,
		"subs": ["영편 탑승 수속을 시작합니다. 승객 여러분께서는 영번 게이트로 이동해 주시기 바랍니다.", "목적지는, 집입니다."]})
	d.office_locked = false
	d.notify("카드 리더에 다시 불이 들어왔다: PASSENGER ACCESS — WELCOME", "info")
	d.complete_goal(g)


func end_cut() -> void:
	Snd.play("clock_punch", -2.0, 0.8)
	d.notify("근태 기록: 승객 1명 — 탑승 수속 완료", "bad")
	await d.wait(2.5)
