extends PhaseScript
## DAY 2 — 10/20 · 체크인 구역 + 수하물 수취대 B-03 (바인더에 p.5 추록). 점검 14회, 이상현상이 시작되는 날.
## (Day1~5 초안 · Day 2: 1987년의 비행기표 · 녹슨 추모 동판 · 막혀 있는 기록 · 이상해진 안내방송)
## 00:00 인수인계: 교대 근무자가 B-03 제어대 앞에서 p.5를 건네고, 분실물 보관함 확인을 맡기고 퇴근한다.
## 점검 1–3: B-03, 전광판, 안내방송. 01:00 조명 절반이 꺼지고 혼자가 된다 → 자재창고 분실물 보관함: 개장도 안 한
## 공항에 1987년 11월 3일 A0편 탑승권. 창고 앞 복도 구석의 녹슨 동판: 1987년 11월, A0편, 41명. 사무실 PC에서 A0를
## 찾아보면 사고 보고서는 공란, 내부 문서는 "A0 관련, 관계자 외 열람 금지".
## 점검 4–6은 쉬운 이상현상. 02:00 점검 7: Gate 04의 TEST MODE가 "FLIGHT 000 / GATE 04 / CHECK-IN"으로.
## 점검 8 직전 아무도 켜지 않은 안내방송이 혼자 나온다. 03:00 정기 방송 — 날짜가 1987년 11월 3일, 시각은 밤 11시
## 40분 (비행기표 · 동판과 같은 날). 06:00 퇴근 → 꺼 둔 도착 전광판에 "GATE 0 — BOARDING"이 켜지고 암전.

const POST := "npc_b03"   # Terminal spot: beside the B-03 control pedestal, facing the belt
const TALK := [
	["왔어요? 하루 버티셨네요. 오늘부터 수하물도 보시죠. B-03 제어대가 여기예요.", ""],
	["새 수칙 페이지요. 5페이지, 수하물 수취대. 바인더에 끼워 두세요.", "p5"],
	["가동 누르면 노란 TEST 태그 가방이 세 개 나와요. 딱 세 개. 그게 정상이에요.", ""],
	["아, 그리고 분실물 보관함. 동쪽 끝 자재창고에 있는데, 하루 한 번 열어 보래요. 개장 전이라 비어 있을 거예요.", ""],
	["창고 얘기는 소장님한테 굳이 안 하셔도 돼요. …그럼 먼저 갈게요. 오늘도 수칙 꼭 지키세요.", ""],
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
	d.t.lost_found.enabled = true
	d.t.lost_found.callback = _open_lost_found
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


## 01:00, alone — then the lost-and-found round the colleague asked for, and what it turns up.
func _lights_down() -> void:
	await d.ev_lights_down("01시예요. 저녁 근무자들 다 나갔어요.", "이제 혼자예요. 판정 실수 세 번이면 근무 무효, 기억하죠?")
	if d.dead:
		return
	await _the_ticket()


## 1987의 비행기표 → 녹슨 동판 → 막혀 있는 기록 (Day 2 1–3).
func _the_ticket() -> void:
	await use_goal("분실물 보관함 확인 (자재창고)", "교대 근무자가 맡긴 일: 체크인 홀 동쪽 끝 [b]자재창고[/b]의 분실물 보관함을 열어 확인하십시오.",
		"storage", d.t.lost_found, func(): return Game.has_clue("ticket"))
	if d.dead:
		return
	d.say("1987년 11월 3일…? 개장도 안 한 공항에, 39년 전 비행기표가 분실물로?", 4.0)
	var plaque := d.t.get_node_or_null("plaque") as Pickup
	if plaque and not Game.has_clue("plaque"):
		await d.wait(4.5)
		d.say("…아까 창고 앞 복도 구석에, 동판 같은 게 서 있었는데.", 3.0)
		await use_goal("창고 앞 복도의 동판 살펴보기", "자재창고로 가는 복도 구석에 [b]녹슨 동판[/b]이 세워져 있습니다. 살펴보십시오.",
			"hall", plaque, func(): return Game.has_clue("plaque"))
	if d.dead:
		return
	d.say("같은 날짜다. 1987년 11월, A0편… 41명.", 3.5)
	await d.wait(3.5)
	await use_goal("A0편 기록 찾아보기 (사무실 PC)", "A0편에 대해 알아보십시오. 시설관리실 [b]PC[/b]에서 사내 문서를 검색할 수 있습니다.",
		"office", d.t.office_pc, func(): return Game.has_clue("a0_search"))
	if d.dead:
		return
	d.say("보고서는 비어 있고, 나머지는 열람 금지… 기록이 없는 게 아니다. 누가 막아 둔 거다.", 4.5)
	await d.wait(2.0)


## The lost-and-found cabinet: empty, as it should be before opening day — except for one boarding pass.
func _open_lost_found() -> void:
	Snd.play_at("door_heavy", d.t.lost_found.global_position, -12.0, 1.4, 4.0)
	await d.read_clue("ticket", "sans")


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


## 03:00 — the date and time it announces are the boarding pass's: 1987. 11. 3., 23:40.
func _broadcast() -> void:
	await d.radio("곧 세 시 정기 방송 나와요. 수칙 9페이지 3번, 기억하죠?")
	await d.wait(1.5)
	await d.ev_regular_broadcast(false, false)
	if d.dead:
		return
	await d.wait(1.0)
	d.say("…비행기표랑 같은 날짜, 같은 시각이다.", 3.5)


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
