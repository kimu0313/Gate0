extends PhaseScript
## DAY 3 — 10/20, 개장 D-3. 보안검색대·탑승동 통로 개방. 전임자의 업무일지를 발견한다 (가짜 수칙 판별법).

var xray: XrayMachine
var mw: MovingWalkway


func title_lines() -> Array:
	return ["DAY 3", "10월 20일 · 정식 개장 D-3 · 09:00 낮 근무"]


func setup() -> void:
	d.set_shutters_for_cycle(3)
	d.clock_speed = 0.3
	xray = d.t.facility("xray")
	mw = d.t.facility("walkway")
	fax_pages(["p6", "p7"], "got_rev_d3", "개정 수칙 추록 p.6, p.7 (2026.10.20)을 바인더에 끼웠다.")
	place_documents()


func run() -> void:
	await d.wait(0.8)
	await d.radio("오늘은 보안검색대랑 탑승동 통로까지 열어요. 무빙워크도 오늘부터예요.")
	await await_fax("got_rev_d3", "개정 수칙 수령 (p.6, p.7)", "시설관리실 [b]팩스[/b]로 들어온 개정 수칙 추록(p.6 무빙워크, p.7 보안검색)을 챙기십시오.")
	var g2 := d.goal("보안검색 X-ray 1번 시운전", "보안검색 구역 1번 레인 데스크에서 [b][가방 투입][/b]을 누르고 판독 화면을 확인하십시오. (촬영 권장)", "security")
	await d.radio("보안검색 1번 레인 X-ray 테스트해 봐요. 판독 화면 사진 찍어 두면 밤에 편해요.")
	await d.until(func(): return xray.scanned)
	d.complete_goal(g2)
	var g3 := d.goal("무빙워크 MW-1 시운전", "탑승동 통로 남쪽 [b]MW-1 제어대[/b]에서 [가동]을 누르고 이동 방향(▲ 탑승동 쪽)을 확인하십시오.", "corridor")
	await d.radio("통로 무빙워크도 돌려 봐요. 표시대로 탑승동 쪽으로 가면 정상.")
	await d.until(func(): return mw.running and mw.speed > 0.5)
	await d.wait(3.0)
	d.complete_goal(g3)
	var g4 := d.goal("보안검색 데스크 서류 확인", "보안검색 구역 [b]2번 레인 데스크[/b]에 누군가 두고 간 서류가 있습니다. 확인하십시오.", "security")
	await d.radio("아, 보안팀이 2번 레인 데스크에 서류가 있다던데요. 한번 봐 줄래요?")
	await d.until(func(): return Game.has_clue("log2"))
	await d.wait(1.0)
	d.complete_goal(g4)
	await d.radio("…전임자요? 그 자리에 전임자는… 없었는데요. 장난인가 보네요.")
	await d.radio("오늘 밤부터는 수칙 페이지가 섞여 있을 수도 있대요. 본사 일이 원래 그래요. 퇴근 찍어요.")
	await punch_out()
