extends PhaseScript
## DAY 1 — 10/21, 개장 D-2 · 00:00–06:00 새벽 근무 첫날. 체크인 구역만 (조명·전광판·안내방송), 점검 14회.
## 00:00 인수인계: 저녁 근무자들이 퇴근 준비를 하는 동안 시설 셋을 직접 켜 본다 (점검 1–3).
## 01:00 마지막 저녁 근무자 퇴근 → 조명 절반이 꺼지고 혼자가 된다. 점검 4–6은 쉬운 이상현상.
## 02:00 점검 7: Gate 04의 TEST MODE가 "FLIGHT 000 / GATE 04 / CHECK-IN"으로 바뀐다. 무전: "테스트 데이터겠죠."
## 점검 8 직전 아무도 켜지 않은 안내방송이 혼자 나오고, 그것이 다음 지시가 된다.
## 03:00 정기 방송 (대기 수칙 p.9 ③) → 점검 11–14는 어려운 이상현상.
## 06:00 퇴근 → 꺼 둔 도착 전광판에 "GATE 0 — BOARDING"이 켜지고 암전.

var fids: FidsBoard


func title_lines() -> Array:
	return ["DAY 1", "10월 21일 · 00:00 · 새벽 근무 첫날"]


func setup() -> void:
	d.set_shutters_for_cycle(1)
	d.clock_speed = 0.1
	fids = d.t.facility("fids")
	d.t.arrivals.set_powered(false)
	binder_pickup()
	place_documents()


func run() -> void:
	handover_ambience()
	await d.wait(0.8)
	await d.radio("시설운영팀입니다. 오늘부터 사흘, 새벽 점검 잘 부탁해요. 어려울 건 없어요. 수칙만 지키시면 됩니다.")
	var g := d.goal("근무 수칙 바인더 챙기기", "시설관리실 책상 위의 [b]근무 수칙 바인더[/b]를 챙기십시오. ([E])", "office")
	await d.until(func(): return Game.flag("got_binder"))
	d.complete_goal(g)
	d.ui.hud.show_key_hints(20.0)
	await d.radio("[B]로 펼쳐 볼 수 있어요. 저녁 근무자들 퇴근하는 동안, 시설 세 개를 직접 켜 보면서 정상 상태를 익혀 두세요.")
	await d.radio("태블릿 [Tab]에 점검 지시가 하나씩 떠요. 오늘은 열네 번. 현장 가서 직접 보고, [정상]이든 [이상]이든 바로 보고하면 돼요.")
	var plan := NightPlan.build(1)
	await d.run_inspections(plan, {1: _first_done, 3: _staff_leave, 10: _broadcast}, {7: _gate04_slot})
	if d.dead:
		return
	await d.radio("오늘 점검 끝. 수고했어요. 사무실 근태 기록기에 퇴근 찍고 가세요.")
	await punch_out()


func _first_done() -> void:
	await d.radio("네, 접수됐어요. 그런 식으로 하면 돼요.")


func _staff_leave() -> void:
	await d.ev_staff_leave()
	if d.dead:
		return
	await d.radio("이제부터 혼자예요. 판정을 세 번 틀리면 그날 근무는 무효고요. 수칙 1페이지에 있어요.")


## 02:00 · 점검 7: the departure board's Gate 04 row.
func _gate04_slot(slot: Dictionary) -> Task:
	var task := d.inspect(slot.fac, "FIDS 출발 전광판 점검 (GATE 04)", "체크인 홀 [b]출발 전광판[/b]의 GATE 04 행이 정상(TEST MODE)인지 인수인계 때 본 목록과 비교하십시오.",
		"fids_gate04", {"slot": 7})
	_gate04_radio(task)
	return task


func _gate04_radio(task: Task) -> void:
	await d.until(func(): return task.state != "active")
	if task.anomaly != "fids_gate04" or d.dead or task.reported_as != "anomaly":
		return
	await d.radio("FLIGHT 000…? 테스트 데이터겠죠. 무시하고 진행해주세요.")
	if task.state == "responding":
		await d.wait(0.8)
		d.notify("근무 수칙 p.0 — 수칙은 무전 지시보다 우선합니다.", "info")


func _broadcast() -> void:
	await d.radio("곧 세 시 정기 방송 나와요. 수칙 9페이지 3번, 기억하죠?")
	await d.wait(1.5)
	await d.ev_regular_broadcast(false)


## 06:00: the arrivals board that was switched off lights up by itself — then the dark.
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
	await d.wait(4.5)
	Snd.play("power_down", -2.0, 0.8, "SFX")
	await d.ui.fade_to(1.0, 0.08)
	await d.wait(1.6)
