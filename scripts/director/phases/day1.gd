extends PhaseScript
## DAY 1 — 10/18, 개장 D-5. 체크인 카운터만 연다. 촬영·바인더 튜토리얼: 정상을 기록한다.

var pa: PaConsole


func title_lines() -> Array:
	return ["DAY 1", "10월 18일 · 정식 개장 D-5 · 09:00 낮 근무"]


func setup() -> void:
	d.set_shutters_for_cycle(1)
	d.clock_speed = 0.3
	pa = d.t.facility("pa")
	if Game.binder_pages.has("p0"):
		Game.set_flag("got_binder")
	else:
		var pk := Pickup.create(d.t, Vector3(-33.0, 0.77, 0.3), PI / 2, "binder", "근무 수칙 바인더 챙기기", "binder")
		pk.picked.connect(func(_p):
			for id in ["p0", "p1", "p2", "p3", "p4", "p9"]:
				Game.add_binder_page(id)
			Game.set_flag("got_binder")
			Snd.play("binder_open", -4.0)
			Events.notify.emit("근무 수칙 바인더 획득 — [B]로 펼치기", "good"))
	place_documents()


func run() -> void:
	await d.wait(0.8)
	await d.radio("아, 들려요? 시설운영팀 소장입니다. 오늘부터 닷새간 잘 부탁해요.")
	await d.radio("본사에 묶여 있어서 얼굴은 못 봐요. 연락은 이 무전으로만 할게요.")
	var g1 := d.goal("근무 수칙 바인더 수령", "시설관리실 책상 위의 [b]근무 수칙 바인더[/b]를 챙기십시오. ([E])", "office")
	d.radio_async("책상 위에 바인더 있죠? 그게 근무 수칙이에요. 챙기세요.")
	await d.until(func(): return Game.flag("got_binder"))
	d.complete_goal(g1)
	await d.radio("[B]로 펼쳐볼 수 있어요. 밤에는 그게 전부예요. 수칙대로만 하면 아무 일 없어요.")
	var g2 := d.goal("FIDS 출발 전광판 촬영", "태블릿 [b][Tab] → 카메라[/b]로 체크인 홀의 [b]FIDS 출발 전광판[/b]을 촬영하십시오.\n밤에 테스트 목록이 바뀌었는지 비교할 기준이 됩니다.", "hall")
	d.ui.hud.show_key_hints(25.0)
	await d.radio("태블릿 카메라로 시설 정상 상태를 찍어 두세요. 하루 여섯 장이에요. 홀의 출발 전광판부터요.")
	await d.until(func(): return has_photo("fids"))
	d.complete_goal(g2)
	await d.radio("좋아요. 밤에 그 목록이랑 다르면 이상이에요. 테스트 항공편은 여덟 개뿐이에요.")
	var g3 := d.goal("안내방송 표준 문안 청취", "체크인 홀 안내 데스크의 [b]PA 콘솔[/b]에서 [테스트 방송]을 끝까지 들으십시오.\n표준 문안은 근무 수칙 p.4에 있습니다.", "hall")
	await d.radio("다음은 안내 데스크 방송 콘솔. 테스트 방송 한 번 끝까지 들어 봐요. 문안을 외워 두면 좋아요.")
	await d.until(func(): return pa.heard)
	d.complete_goal(g3)
	var g4 := d.goal("조명 분전반 확인", "시설관리실 출입문 옆 [b]조명 분전반[/b]에서 체크인 홀 조명을 한 번 껐다가 다시 켜 보십시오.\n정상일 때 천장 패널이 어떻게 켜져 있는지 기억해 두십시오.", "hall")
	d.radio("마지막으로 사무실 문 옆 조명 분전반. 홀 조명 한 번 껐다 켜 봐요. 켜진 모습을 잘 봐 두고요.")   # not awaited: the switch may be flipped while it talks
	await d.until_action("lights_off")
	await d.until_action("lights_on")
	await d.wait(1.5)
	d.complete_goal(g4)
	await d.radio("잘했어요. 오늘은 체크인 구역만이에요. 수하물, 보안검색, 게이트는 하루에 한 구역씩 열어요.")
	await d.radio("퇴근 찍고 쉬어요. 밤 열한 시에 다시 출근이에요. 밤에는 열 번 점검하면 끝나요.")
	await punch_out("퇴근 기록", "시설관리실 [b]근태 기록기[/b]에서 근무 종료를 기록하십시오. (야간 근무로 이어집니다)")
