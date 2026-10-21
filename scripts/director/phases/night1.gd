extends PhaseScript
## NIGHT 1 — Manual phase / tutorial. Rules are all genuine. First anomaly: SH 000 on the board.

var fids: FidsBoard
var pa: PaConsole
var belt: BaggageBelt


func title_lines() -> Array:
	return ["NIGHT 1", "10월 20일 · 23:00 · 야간 시설 점검"]


func setup() -> void:
	d.set_shutters_for_cycle(1)
	d.clock_speed = 0.4
	fids = d.t.facility("fids")
	pa = d.t.facility("pa")
	belt = d.t.facility("baggage")
	Geo.box(d.t, Vector3(-27.4, 0.38, 5.35), Vector3(0.7, 0.76, 0.5), Mats.get_mat("wood"))
	d.spawn_doc("log1", Vector3(-27.4, 0.77, 5.3), 0.2, "낡은 업무일지 읽기")
	d.spawn_doc("memo_worker", Vector3(31.2, 0.81, -9.0), 0.4, "구겨진 메모 읽기")


func run() -> void:
	await d.wait(1.0)
	await d.radio("야간 근무 시작이네요. 지금부터는 혼자예요.")
	await d.radio("태블릿 [Tab]에 점검 지시가 하나씩 떠요. 현장 가서 직접 보고, [정상]이든 [이상]이든 바로 보고하세요.")
	var t1 := d.inspect("lights", "조명 분전반 점등 확인",
		"시설관리실 출입문 옆 [b]조명 분전반[/b] 앞에서 체크인 홀·수하물 구역 조명 상태를 관찰하고 보고하십시오.\n(꺼진 구역이 있으면 스위치로 켜십시오)")
	d.ui.hud.show_key_hints(25.0)
	await d.until_done(t1)
	if t1.result == "correct":
		await d.radio("네, 접수됐어요. 그런 식으로 하면 돼요.")
	var t2 := d.inspect("fids", "FIDS 출발 전광판 테스트 모드 확인",
		"체크인 홀 북측 [b]출발 전광판[/b]이 낮에 기록한 테스트 목록과 같은지 확인하십시오.\n태블릿 [b]점검 앨범[/b]의 사진과 비교할 수 있습니다.", "fids_extra")
	await d.wait(5.0)
	d.radio_async("전광판은 낮에 찍은 사진이랑 비교해 봐요. 태블릿 [점검 앨범]에 있어요.")
	await d.until(func(): return t2.state != "active")
	if t2.state == "responding":
		await d.radio("SH 000…? 테스트 데이터겠죠. 그래도 규정은 규정이니까, 수칙 3페이지대로 처리해요.")
	await d.until_done(t2)
	if t2.result == "missed":
		await d.radio("…방금 전광판, 뭔가 이상하지 않았어요? …아니에요. 계속하죠.")
	elif t2.result == "cleared":
		await d.radio("처리됐네요. 개장 전이라 이런 게 가끔 있대요. 너무 신경 쓰지 마요.")
	var t3 := d.inspect("pa", "안내방송 테스트 송출",
		"안내 데스크 [b]PA 콘솔[/b]에서 테스트 방송을 송출하고 끝까지 들으십시오.\n표준 문안(수칙 p.4)과 비교해 보고하십시오.")
	await d.until_done(t3)
	# the board writes by itself
	fids.set_story("story", ["FLIGHT 000", "GATE 04", "CHECK-IN"])
	Snd.play_at("glitch", fids.focus_position(), -2.0, 0.7, 14.0)
	await d.wait(2.5)
	d.radio_async("…방금 전광판 봤어요? …아니, 아무것도 아니에요. 계속해요.")
	var bag_anom := "bag_extra" if randf() < 0.5 else ""
	var t4 := d.inspect("baggage", "수하물 수취대 B-03 가동 테스트",
		"수하물 B-03을 [가동]하고 나오는 가방을 끝까지 확인하십시오.\n정상은 [b]노란 TEST 태그 가방 3개[/b]입니다.", bag_anom)
	await d.until_done(t4)
	fids.set_story("")
	await d.wait(4.0)
	await d.ev_blackout(11.0, false, true)
	await d.wait(1.0)
	await d.radio("…괜찮아요? 정전이 잠깐 있었네요. 개장 전이라 전기가 불안정해서 그래요.")
	await d.radio("오늘은 여기까지. 사무실로 돌아가서 근태 기록기에 퇴근 찍어요.")
	var t5 := d.goal("근무 종료 기록", "시설관리실 [b]근태 기록기[/b]에서 근무 종료를 기록하십시오.", "office")
	d.punch_enabled = true
	await d.punched
	d.complete_goal(t5)
	await d.end_phase()
