extends PhaseScript
## NIGHT 1 — 10/18. 체크인 구역 수동 점검 10회 (조명·전광판·안내방송). 수칙은 전부 진짜다.
## 첫 이상: Gate 04의 TEST MODE가 "FLIGHT 000 / GATE 04 / CHECK-IN"으로 바뀐다.
## 6번째 점검 전에 안내방송이 혼자 나온다. 퇴근 후, 꺼 둔 도착 전광판에 "GATE 0 — BOARDING".

var fids: FidsBoard


func title_lines() -> Array:
	return ["NIGHT 1", "10월 18일 · 23:00 · 야간 시설 점검"]


func setup() -> void:
	d.set_shutters_for_cycle(1)
	d.clock_speed = 0.12
	fids = d.t.facility("fids")
	d.t.arrivals.set_powered(false)
	place_documents()


func run() -> void:
	await night_briefing("야간 근무 시작이네요. 지금부터는 혼자예요.")
	await d.radio("태블릿 [Tab]에 점검 지시가 하나씩, 오늘 밤 열 번 떠요. 현장 가서 직접 보고, [정상]이든 [이상]이든 바로 보고하세요.")
	await d.radio("판정을 세 번 틀리면 그날 근무는 무효예요. 수칙 1페이지에 있어요.")
	var plan := NightPlan.build(1, true)
	await d.run_inspections(plan, {1: _first_done, 8: _blackout}, {3: _gate04_slot})
	if d.dead:
		return
	await d.radio("오늘 점검 끝. 수고했어요. 사무실 근태 기록기에 퇴근 찍어요.")
	await punch_out("근무 종료 기록", "시설관리실 [b]근태 기록기[/b]에서 근무 종료를 기록하십시오.")


func _first_done() -> void:
	await d.radio("네, 접수됐어요. 그런 식으로 하면 돼요.")


func _gate04_slot(slot: Dictionary) -> Task:
	var task := d.inspect(slot.fac, slot.title, slot.detail, slot.anomaly, {"slot": 3})
	_gate04_radio(task)
	return task


func _gate04_radio(task: Task) -> void:
	await d.until(func(): return task.state != "active")
	if task.anomaly != "fids_gate04" or d.dead:
		return
	await d.radio("FLIGHT 000…? 테스트 데이터겠죠. 무시하고 진행해주세요.")
	if task.state == "responding":
		await d.wait(0.8)
		d.notify("근무 수칙 p.0 — 수칙은 무전 지시보다 우선합니다.", "info")


func _blackout() -> void:
	await d.ev_blackout(11.0, false, true)
	if d.dead:
		return
	await d.wait(1.0)
	await d.radio("…괜찮아요? 정전이 잠깐 있었네요. 개장 전이라 전기가 불안정해서 그래요.")


## Clear cut: the arrivals board that was switched off lights up by itself.
func end_cut() -> void:
	await d.ui.fade_to(1.0, 0.6)
	d.p.teleport(Transform3D(Basis(), Vector3(6.0, 0.05, -3.0)))
	await d.get_tree().physics_frame
	d.p.look_at_point(d.t.arrivals.focus_position(), 0.01)
	d.t.set_zone_light("hall", false, true)
	await d.wait(0.4)
	await d.ui.fade_to(0.0, 1.0)
	await d.wait(1.2)
	d.t.arrivals.set_powered(true)
	d.t.arrivals.set_story("final", ["GATE 0", "BOARDING"])
	Snd.play_at("pa_chime_wrong", d.t.arrivals.focus_position(), -4.0, 1.0, 20.0)
	await d.wait(5.5)
