extends PhaseScript
## DAY 1 — 개장 D-3. Learn the normal: binder, photos, the standard PA text, the 3-bag test run.

var pa: PaConsole
var belt: BaggageBelt


func title_lines() -> Array:
	return ["DAY 1", "10월 20일 · 정식 개장 D-3 · 09:00 낮 근무"]


func setup() -> void:
	d.set_shutters_for_cycle(1)
	d.clock_speed = 0.3
	pa = d.t.facility("pa")
	belt = d.t.facility("baggage")
	if Game.binder_pages.has("p0"):
		Game.set_flag("got_binder")
	else:
		var pk := Pickup.create(d.t, Vector3(-33.0, 0.77, 0.3), PI / 2, "binder", "근무 수칙 바인더 챙기기", "binder")
		pk.picked.connect(func(_p):
			for id in ["p0", "p1", "p2", "p3", "p4", "p5", "p9"]:
				Game.add_binder_page(id)
			Game.set_flag("got_binder")
			Snd.play("binder_open", -4.0)
			Events.notify.emit("근무 수칙 바인더 획득 — [B]로 펼치기", "good"))
	Geo.box(d.t, Vector3(-27.4, 0.38, 5.35), Vector3(0.7, 0.76, 0.5), Mats.get_mat("wood"))
	d.spawn_doc("log1", Vector3(-27.4, 0.77, 5.3), 0.2, "낡은 업무일지 읽기")
	d.spawn_doc("memo_worker", Vector3(31.2, 0.81, -9.0), 0.4, "구겨진 메모 읽기")


func run() -> void:
	await d.wait(0.8)
	await d.radio("아, 들려요? 시설운영팀 소장입니다. 오늘부터 사흘간 잘 부탁해요.")
	await d.radio("본사에 묶여 있어서 얼굴은 못 봐요. 연락은 이 무전으로만 할게요.")
	var g1 := d.goal("근무 수칙 바인더 수령", "시설관리실 책상 위의 [b]근무 수칙 바인더[/b]를 챙기십시오. ([E])", "office")
	d.radio_async("책상 위에 바인더 있죠? 그게 근무 수칙이에요. 챙기세요.")
	await d.until(func(): return Game.flag("got_binder"))
	d.complete_goal(g1)
	await d.radio("[B]로 펼쳐볼 수 있어요. 밤에는 그게 전부예요. 수칙대로만 하면 아무 일 없어요.")
	var g2 := d.goal("FIDS 출발 전광판 촬영", "태블릿 [b][Tab] → 카메라[/b]로 체크인 홀의 [b]FIDS 출발 전광판[/b]을 촬영하십시오.\n밤에 테스트 목록이 바뀌었는지 비교할 기준이 됩니다.", "hall")
	d.ui.hud.show_key_hints(25.0)
	await d.radio("태블릿 열어서 카메라로 시설 정상 상태를 찍어 두세요. 하루 여섯 장이에요. 홀에 있는 출발 전광판부터요.")
	await d.until(func(): return _has_photo("fids"))
	d.complete_goal(g2)
	await d.radio("좋아요. 밤에 그 목록이랑 다르면 이상이에요. 테스트 항공편은 여덟 개뿐이에요.")
	var g3 := d.goal("안내방송 표준 문안 청취", "체크인 홀 안내 데스크의 [b]PA 콘솔[/b]에서 [테스트 방송]을 끝까지 들으십시오.\n표준 문안은 근무 수칙 p.4에 있습니다.", "hall")
	await d.radio("다음은 안내 데스크 방송 콘솔. 테스트 방송 한 번 끝까지 들어 봐요. 문안을 외워 두면 좋아요.")
	await d.until(func(): return pa.heard)
	d.complete_goal(g3)
	var g4 := d.goal("수하물 수취대 B-03 시운전", "수하물 수취 구역 [b]B-03 제어대[/b]에서 [가동]을 누르고 [b]TEST 태그 가방 3개[/b]가 나오는 것을 확인하십시오.", "baggage")
	await d.radio("마지막으로 수하물 B-03. 가동하면 노란 TEST 태그 가방 세 개 나와요. 그게 정상이에요.")
	await d.until(func(): return belt.bags_seen >= 3 and belt.spawn_queue.is_empty())
	await d.wait(2.0)
	d.complete_goal(g4)
	await d.radio("잘했어요. 사진 남았으면 벨트도 찍어 두고요. 가방 개수랑 색깔.")
	await d.radio("오늘은 여기까지. 사무실 근태 기록기에서 퇴근 찍고 쉬어요. 밤 열한 시에 다시 출근이에요.")
	var g5 := d.goal("퇴근 기록", "시설관리실 [b]근태 기록기[/b]에서 근무 종료를 기록하십시오. (야간 근무로 이어집니다)", "office")
	d.punch_enabled = true
	await d.punched
	d.complete_goal(g5)
	await d.end_phase()


func _has_photo(fid: String) -> bool:
	for ph in Game.photos:
		if ph.get("facility", "") == fid and int(ph.get("cycle", 0)) == Game.cycle:
			return true
	return false
