extends PhaseScript
## DAY 4 — 10/21, 개장 D-2. 탑승 게이트 개방. 낮에도 이상현상: 전광판의 SH 000, 혼자 나오는 방송, 바뀐 사진.

var fids: FidsBoard
var gate03: BoardingGate


func title_lines() -> Array:
	return ["DAY 4", "10월 21일 · 정식 개장 D-2 · 09:00 낮 근무"]


func setup() -> void:
	d.set_shutters_for_cycle(4)
	d.clock_speed = 0.3
	fids = d.t.facility("fids")
	gate03 = d.t.facility("gate03")
	fids.ghost_row(true)
	fax_pages(["p8"], "got_rev_d4", "개정 수칙 추록 p.8 탑승구 (2026.10.21)를 바인더에 끼웠다.")
	place_documents()
	alter_a_photo()


func run() -> void:
	await d.wait(0.8)
	await d.radio("오늘은 탑승 게이트 구역까지 열어요. 이제 이틀 남았네요.")
	if Game.flag("photo_altered"):
		d.notify("점검 앨범 동기화 완료 — 변경된 사진 1건", "info")
	await await_fax("got_rev_d4", "개정 수칙 수령 (p.8)", "시설관리실 [b]팩스[/b]로 들어온 개정 수칙 추록(p.8 탑승구)을 챙기십시오.")
	await d.radio("…근데 전광판 봤어요? 낮인데 SH 000이 떠 있다고 보안팀이 그러던데. 테스트 데이터겠죠.")
	var g2 := d.goal("탑승 게이트 구역 확인", "탑승동 끝 [b]탑승 게이트 구역[/b]으로 가서 GATE 03 포디움의 [b][상태 확인][/b]을 누르십시오. (대기석 배치 촬영 권장)", "gates")
	await d.until(func(): return gate03.checked)
	d.complete_goal(g2)
	await d.wait(2.0)
	await d.pa(["pa_flight0_checkin_ko"], {"wrong": true, "tag": "auto",
		"subs": ["영편 탑승 수속을 시작합니다. 승객 여러분께서는 영번 게이트로 이동해 주시기 바랍니다."]})
	await d.radio("…방금 방송, 누가 튼 거예요? 거기 지금 아무도 없죠?")
	await d.radio("영번 게이트 같은 건 없어요. 도면에도 없어요. …오늘은 그냥 일찍 들어가요.")
	d.goal("탑승 게이트 구역 둘러보기 (선택)", "게이트 구역 대기석 주변을 둘러보십시오.", "gates", {"optional": true})
	await punch_out()
