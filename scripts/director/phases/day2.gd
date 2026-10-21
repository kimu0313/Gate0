extends PhaseScript
## DAY 2 — 개장 D-2. Security & walkway open, revision pages, night lighting plan, the memorial plaque.

var xray: XrayMachine
var mw: MovingWalkway


func title_lines() -> Array:
	return ["DAY 2", "10월 21일 · 정식 개장 D-2 · 09:00 낮 근무"]


func setup() -> void:
	d.set_shutters_for_cycle(2)
	d.clock_speed = 0.3
	xray = d.t.facility("xray")
	mw = d.t.facility("walkway")
	if Game.binder_pages.has("p6"):
		Game.set_flag("got_rev2")
	else:
		var pk := Pickup.create(d.t, Vector3(-23.3, 1.02, -4.6), 0.3, "rev2", "팩스로 온 개정 수칙 챙기기", "folder")
		pk.picked.connect(func(_p):
			Game.add_binder_page("p6")
			Game.add_binder_page("p7")
			Game.set_flag("got_rev2")
			Events.notify.emit("개정 수칙 추록 p.6, p.7 (2026.10.18)을 바인더에 끼웠다.", "good"))
	if not Game.has_clue("plaque"):
		var pl := Pickup.create(d.t, Vector3(41.0, 0.0, -21.4), 0.0, "plaque", "덮개 아래 동판 살펴보기", "plaque")
		pl.keep_after_pick = true
		pl.picked.connect(func(_p):
			if Game.has_clue("plaque"):
				return
			Game.add_clue("plaque")
			var c: Dictionary = RulesDB.CLUES.plaque
			d.ui.read_doc(c.title, c.body, "serif"))
	Geo.box(d.t, Vector3(-27.4, 0.38, 5.35), Vector3(0.7, 0.76, 0.5), Mats.get_mat("wood"))
	d.spawn_doc("log1", Vector3(-27.4, 0.77, 5.3), 0.2, "낡은 업무일지 읽기")
	d.spawn_doc("memo_worker", Vector3(31.2, 0.81, -9.0), 0.4, "구겨진 메모 읽기")


func run() -> void:
	await d.wait(0.8)
	await d.radio("어젯밤 고생했어요. 오늘은 보안검색이랑 탑승동 통로까지 열어요.")
	d.pa(["pa_welcome_ko", "pa_welcome_en"], {"subs": ["서해국제공항에 오신 것을 환영합니다. 즐거운 여행 되십시오.", "Welcome to Seohae International Airport. Have a pleasant journey."], "tag": "day"})
	var g1 := d.goal("개정 수칙 수령", "시설관리실 [b]팩스[/b]로 들어온 개정 수칙 추록을 챙기십시오.", "office")
	await d.radio("본사에서 개정 수칙 팩스로 보냈어요. 무빙워크랑 보안검색. 바인더에 끼워 두세요.")
	await d.until(func(): return Game.flag("got_rev2"))
	d.complete_goal(g1)
	await d.radio("추록 날짜 확인해 봐요. 10월 18일. 맨 앞 개정 이력에 적힌 날짜랑 같아야 진짜예요.")
	var g2 := d.goal("보안검색 X-ray 1번 시운전", "보안검색 구역 1번 레인 데스크에서 [b][가방 투입][/b]을 누르고 판독 화면을 확인하십시오. (촬영 권장)", "security")
	await d.radio("보안검색 1번 레인 X-ray 테스트해 봐요. 판독 화면 사진 찍어 두면 밤에 편해요.")
	await d.until(func(): return xray.scanned)
	d.complete_goal(g2)
	var g3 := d.goal("무빙워크 MW-1 시운전", "탑승동 통로 남쪽 [b]MW-1 제어대[/b]에서 [가동]을 누르고 이동 방향(▲ 탑승동 쪽)을 확인하십시오.", "corridor")
	await d.radio("통로 무빙워크도 돌려 봐요. 표시대로 탑승동 쪽으로 가면 정상.")
	await d.until(func(): return mw.running and mw.speed > 0.5)
	await d.wait(3.0)
	d.complete_goal(g3)
	var g4 := d.goal("야간 조명 배분", "태블릿 [b][야간 조명 배분][/b] 탭에서 밤에 켜 둘 구역 3곳을 고르고 확정하십시오.\n수칙 p.9 ③을 참고하십시오.", "")
	await d.radio("마지막으로 야간 조명 배분. 전력 한도 때문에 세 구역만 켜 둘 수 있어요. 태블릿에서 정하면 돼요.")
	await d.until_action("power_plan")
	d.complete_goal(g4)
	d.goal("수하물 보관실 확인 (선택)", "수하물 수취 구역 북쪽 [b]보관실[/b]에 임시 보관된 공사 자재를 확인하십시오.", "storage", {"optional": true})
	await d.radio("아, 수하물 보관실에… 옛날 비행장 때 물건이 좀 있어요. 신경 안 써도 돼요.")
	await d.radio("오늘은 끝. 퇴근 찍고 밤에 봐요.")
	var g5 := d.goal("퇴근 기록", "시설관리실 [b]근태 기록기[/b]에서 근무 종료를 기록하십시오.", "office")
	d.punch_enabled = true
	await d.punched
	d.complete_goal(g5)
	await d.end_phase()
