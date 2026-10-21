extends PhaseScript
## NIGHT 2 — Autonomous phase. A damaged page, the first fake page, unbidden machines,
## the name call, 3 AM, and the last suitcase.

var belt: BaggageBelt
var mw: MovingWalkway


func title_lines() -> Array:
	return ["NIGHT 2", "10월 21일 · 23:00 · 야간 시설 점검"]


func setup() -> void:
	d.set_shutters_for_cycle(2)
	d.clock_speed = 0.4
	belt = d.t.facility("baggage")
	mw = d.t.facility("walkway")
	# the binder has changed overnight
	if Game.binder_pages.has("p6"):
		Game.remove_binder_page("p6")
		Game.add_binder_page("p6_dmg")
	Game.add_binder_page("f5")
	d.spawn_doc("log2", Vector3(6.6, 0.81, -20.6), 0.5, "누군가 두고 간 업무일지 읽기")
	if not Game.has_clue("plaque"):
		var pl := Pickup.create(d.t, Vector3(41.0, 0.0, -21.4), 0.0, "plaque", "덮개 아래 동판 살펴보기", "plaque")
		pl.keep_after_pick = true
		pl.picked.connect(func(_p):
			if Game.has_clue("plaque"):
				return
			Game.add_clue("plaque")
			var c: Dictionary = RulesDB.CLUES.plaque
			d.ui.read_doc(c.title, c.body, "serif"))


func run() -> void:
	await d.wait(1.0)
	await d.radio("둘째 날 밤이네요. 오늘은 구역이 넓어요. 무빙워크는 꼭 정지 상태로 두고 퇴근하고요.")
	d.notify("바인더가 어제보다 두꺼워진 것 같다…", "info")
	var plan := d.plan_anomalies(["lights", "xray", "walkway", "fids", "pa"], 2 + (1 if Game.erosion > 30.0 else 0))
	var t1 := d.inspect("xray", "보안검색 X-ray 1번 판독 점검",
		"보안검색 1번 레인에서 [b]테스트 가방을 스캔[/b]하고 판독 화면을 관찰하십시오.\n정상: 노트북, 물병, 열쇠, 케이블.", plan.xray)
	await d.until_done(t1)
	var t2 := d.inspect("walkway", "무빙워크 MW-1 가동 점검",
		"탑승동 통로 [b]MW-1[/b]을 가동하고 이동 방향과 속도를 관찰하십시오.\n정상: 표시 방향(▲ 탑승동 쪽), 천천히.", plan.walkway)
	await d.until_done(t2)
	if mw.running:
		mw.press_stop()
	# 00:00 — the airport starts running itself
	d.jump_clock(24 * 60)
	await d.wait(2.0)
	d.pa(["pa_flight0_move_ko", "pa_flight0_move_en"], {"wrong": true, "tag": "auto",
		"subs": ["영편 승객께서는 출국장으로 이동해 주시기 바랍니다.", "Passengers of flight zero, please proceed to the departure area."]})
	await d.wait(3.0)
	await d.radio("…방금 방송 뭐예요? 콘솔 건드렸어요? …안 건드렸다고요?")
	var urgent := d.inspect("walkway", "⚠ MW-1 무단 가동 감지",
		"아무도 가동하지 않은 [b]무빙워크 MW-1[/b]이 움직이고 있습니다. 현장을 확인하고 보고하십시오.", "auto_run", {"urgent": true})
	await d.until_done(urgent)
	var t3 := d.inspect("fids", "FIDS 출발 전광판 점검",
		"출발 전광판의 테스트 목록과 시계를 낮의 기록과 비교하십시오.", plan.fids)
	await d.until_done(t3)
	await d.wait(3.0)
	await d.ev_namecall(false)
	var t4 := d.inspect("pa", "안내방송 테스트 송출",
		"PA 콘솔에서 테스트 방송을 송출하고 끝까지 들으십시오. 표준 문안(수칙 p.4)과 비교하십시오.", plan.pa)
	await d.until_done(t4)
	var t5 := d.inspect("lights", "조명 분전반 점검",
		"조명 분전반 앞에서 켜져 있는 구역의 조명 상태를 관찰하고 보고하십시오.", plan.lights)
	await d.until_done(t5)
	# 03:00
	d.jump_clock(27 * 60)
	await d.wait(1.0)
	await d.ev_3am(false)
	await d.wait(2.0)
	await _last_baggage()
	await d.radio("…오늘 이상한 게 많았네요. 끝났으면 퇴근 찍어요. 내일이면 마지막이에요.")
	var t7 := d.goal("근무 종료 기록", "시설관리실 [b]근태 기록기[/b]에서 근무 종료를 기록하십시오.", "office")
	d.punch_enabled = true
	await d.punched
	d.complete_goal(t7)
	await d.end_phase()


## Story: the belt runs by itself; you stop it; the last suitcase arrives — with your name.
func _last_baggage() -> void:
	belt.clear_bags()
	belt.start(false)
	var task := d.inspect("baggage", "⚠ 수하물 B-03 비인가 가동",
		"수하물 수취대 B-03이 혼자 가동 중입니다. 현장에서 [b]정지[/b]시키고 상태를 보고하십시오.", "", {"urgent": true})
	task.locked = "벨트를 정지시키고 끝까지 확인하십시오."
	await d.radio("수하물 B-03이 혼자 돌고 있대요. 가서 멈춰 줄래요?")
	while true:
		var r: Array = await d.action_seen
		if r[1] == "baggage" and (r[0] == "stop" or r[0] == "estop"):
			break
	await d.wait(2.5)
	await d.pa(["pa_last_baggage_ko"], {"wrong": true, "subs": ["마지막 수하물이 도착했습니다."], "no_end": true, "tag": "auto"})
	task.anomaly = "bag_name"
	belt.estopped = false
	belt.set_anomaly("bag_name")
	belt.start(false)
	Snd.play_at("power_up", belt.global_position, -6.0, 0.8, 10.0)
	task.locked = ""
	task.progress = 0.0
	task.observed = false
	await d.until_done(task)
	if task.result == "cleared":
		await d.radio("…가방 이름표에 뭐라고 쓰여 있었어요? …아니, 말하지 마요.")
