extends PhaseScript
## DAY 5 — 10/22, 개장 D-1. 낮과 밤의 경계가 무너진다: 잿빛 낮, 승객으로 찍히는 출입카드,
## 마지막 추록(p.10 0번 게이트), 1987년 정비사의 근태 카드.

var fids: FidsBoard


func title_lines() -> Array:
	return ["DAY 5", "10월 22일 · 정식 개장 D-1 · 09:00 낮 근무 (승객)"]


func setup() -> void:
	d.set_shutters_for_cycle(5)
	d.clock_speed = 0.3
	d.office_mode = "passenger"
	fids = d.t.facility("fids")
	fids.set_story("final", ["SH 000", "GATE 0", "CHECK-IN"])
	fax_pages(["p10"], "got_rev_d5", "개정 수칙 추록 p.10 0번 게이트 (2026.10.22)를 바인더에 끼웠다.")
	place_documents()
	alter_a_photo()
	for zn in ["baggage", "security"]:
		(d.t.zones[zn] as LightZone).erratic = 0.6


func run() -> void:
	await d.wait(0.8)
	await d.radio("…오늘이 마지막 날이에요. 내일 아침이면 개장이고요.")
	await d.radio("근데 오늘 출근 기록이 이상하게 찍혔어요. 직원이 아니라… '승객'으로요. 시스템 오류겠죠.")
	await await_fax("got_rev_d5", "개정 수칙 수령 (p.10)", "시설관리실 [b]팩스[/b]로 들어온 마지막 추록(p.10 0번 게이트)을 챙기십시오.")
	await d.radio("p.10이요? …그런 페이지를 보낸 적이 없는데요. 그래도 도장 있으면 진짜예요.")
	var g2 := d.goal("전 구역 순회", "오늘은 모든 구역이 열려 있습니다. 탑승동 끝 [b]탑승 게이트 구역[/b]까지 걸어서 확인하십시오.", "gates")
	await d.until(func(): return d.p.zone == "gates")
	await d.wait(3.0)
	d.complete_goal(g2)
	for z in d.t.zones.values():
		(z as LightZone).trigger_dip(1.2)
	Snd.play("power_down", -6.0, 1.2, "SFX")
	await d.wait(2.0)
	await d.radio("…지금 거기 불 꺼졌어요? 낮인데 왜… 아니에요.")
	await d.radio("밤에는 무전이 잘 안 될 수도 있어요. 그러면, 수칙만 믿어요. 꼭이요.")
	d.goal("근태 기록기 옆 오래된 카드 (선택)", "시설관리실 근태 기록기 아래 선반에 오래된 근태 카드가 꽂혀 있습니다.", "office", {"optional": true})
	await punch_out("퇴근 기록", "시설관리실 [b]근태 기록기[/b]에서 근무 종료를 기록하십시오. 마지막 밤입니다.")
