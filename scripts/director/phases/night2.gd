extends PhaseScript
## DAY 2 — 10/20 · 체크인 구역 + 수하물 수취대 B-03 (바인더에 p.5 추록). 점검 14회, 이상현상이 시작되는 날.
## 00:00 인수인계: 교대 근무자가 B-03 제어대 앞에서 기다린다. [E]로 이야기하며 p.5 추록을 받고, 근무자는 퇴근한다.
## 점검 1–3: B-03, 전광판, 안내방송. 01:00 조명 절반이 꺼지고 혼자가 된다. 점검 4–6은 쉬운 이상현상.
## 02:00 점검 7: Gate 04의 TEST MODE가 "FLIGHT 000 / GATE 04 / CHECK-IN"으로 바뀐다. 무전: "테스트 데이터겠죠."
## 점검 8 직전 아무도 켜지 않은 안내방송이 혼자 나오고, 그것이 다음 지시가 된다.
## 03:00 정기 방송 (대기 수칙 p.9 ③) — 단어 하나가 평소와 다르다 → 점검 11–14는 어려운 이상현상.
## 06:00 퇴근 → 꺼 둔 도착 전광판에 "GATE 0 — BOARDING"이 켜지고 암전.

const POST := "npc_b03"   # Terminal spot: beside the B-03 control pedestal, facing the belt
const TALK := [
	["왔어요? 오늘부터 수하물도 보시죠. B-03 제어대가 여기예요.", ""],
	["새 수칙 페이지요. 5페이지, 수하물 수취대. 바인더에 끼워 두세요.", "p5"],
	["가동 누르면 노란 TEST 태그 가방이 세 개 나와요. 딱 세 개. 그게 정상이에요.", ""],
	["어제 퇴근할 때 출발 전광판 봤어요? …아니에요. 아무것도.", ""],
	["먼저 갈게요. 오늘도 수칙 꼭 지키세요.", ""],
]

var fids: FidsBoard


func title_lines() -> Array:
	return ["DAY 2", "10월 20일 · 00:00 · 수하물 수취 구역"]


func setup() -> void:
	d.set_shutters_for_cycle(2)
	d.clock_speed = 0.1
	fids = d.t.facility("fids")
	d.t.arrivals.set_powered(false)
	place_documents()
	spawn_worker(d.t.spot(POST), -PI / 2)


func run() -> void:
	handover_ambience()
	await night_briefing("둘째 날이네요. 오늘부터 수하물 수취대도 봐야 해요. 교대 근무자가 B-03 앞에서 기다리고 있어요.")
	await colleague_handover("수하물 수취대 [b]B-03 제어대[/b] 앞의 저녁 근무자에게 [E]로 인수인계를 받으십시오.", "baggage", TALK, _give)
	if d.dead:
		return
	var plan := NightPlan.build(2)
	await d.run_inspections(plan, {1: _first_done, 3: _lights_down, 10: _broadcast}, {7: _gate04_slot})
	if d.dead:
		return
	await d.radio("오늘 점검 끝. 수고했어요. 사무실 근태 기록기에 퇴근 찍고 가세요.")
	await punch_out()


func _first_done() -> void:
	await d.radio("네, 접수됐어요. 오늘부터는 진짜 이상한 게 섞여 있을 수 있어요.")


func _give(item: String) -> void:
	if item == "p5":
		hand_pages(["p5"], "근무 수칙 p.5 수하물 수취대 (추록) 수령 — 바인더에 끼움")


func _lights_down() -> void:
	await d.ev_lights_down("01시예요. 저녁 근무자들 다 나갔어요.", "이제 혼자예요. 판정 실수 세 번이면 근무 무효, 기억하죠?")


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
	d.p.teleport(Transform3D(Basis(), d.t.spot("cut_arrivals")))
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
