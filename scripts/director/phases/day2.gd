extends PhaseScript
## DAY 2 — 10/19, 개장 D-4. 수하물 구역 개방, 야간 조명 배분 시작, 보관실의 추모 동판.

var belt: BaggageBelt


func title_lines() -> Array:
	return ["DAY 2", "10월 19일 · 정식 개장 D-4 · 09:00 낮 근무"]


func setup() -> void:
	d.set_shutters_for_cycle(2)
	d.clock_speed = 0.3
	belt = d.t.facility("baggage")
	fax_pages(["p5"], "got_rev_d2", "개정 수칙 추록 p.5 수하물 (2026.10.19)을 바인더에 끼웠다.")
	place_documents()


func run() -> void:
	await d.wait(0.8)
	await d.radio("어젯밤 고생했어요. 오늘은 수하물 구역을 열어요.")
	d.pa(["pa_welcome_ko", "pa_welcome_en"], {"subs": ["서해국제공항에 오신 것을 환영합니다. 즐거운 여행 되십시오.", "Welcome to Seohae International Airport. Have a pleasant journey."], "tag": "day"})
	await await_fax("got_rev_d2", "개정 수칙 수령 (p.5)", "시설관리실 [b]팩스[/b]로 들어온 개정 수칙 추록(p.5 수하물)을 챙기십시오.")
	await d.radio("추록 날짜 확인해 봐요. 10월 19일. 맨 앞 개정 이력에 적힌 날짜랑 같아야 진짜예요.")
	var g2 := d.goal("수하물 수취대 B-03 시운전", "수하물 수취 구역 [b]B-03 제어대[/b]에서 [가동]을 누르고 [b]TEST 태그 가방 3개[/b]가 나오는 것을 확인하십시오. (촬영 권장)", "baggage")
	await d.radio("B-03 가동하면 노란 TEST 태그 가방 세 개 나와요. 그게 정상이에요. 개수랑 색깔 사진 찍어 두면 밤에 편해요.")
	await d.until(func(): return belt.bags_seen >= 3 and belt.spawn_queue.is_empty())
	await d.wait(2.0)
	d.complete_goal(g2)
	var g3 := d.goal("야간 조명 배분", "태블릿 [b][야간 조명 배분][/b] 탭에서 밤에 켜 둘 구역 3곳을 고르고 확정하십시오.\n수칙 p.9 ③을 참고하십시오.", "")
	d.radio("오늘부터 야간 조명 배분도 해 줘요. 전력 한도 때문에 세 구역만 켜 둘 수 있어요. 태블릿에서 정하면 돼요.")   # not awaited: the plan may be confirmed while it talks
	await d.until_action("power_plan")
	d.complete_goal(g3)
	d.goal("수하물 보관실 확인 (선택)", "수하물 수취 구역 북쪽 [b]보관실[/b]에 임시 보관된 공사 자재를 확인하십시오.", "storage", {"optional": true})
	await d.radio("아, 수하물 보관실에… 옛날 비행장 때 물건이 좀 있어요. 신경 안 써도 돼요.")
	await d.radio("오늘은 끝. 퇴근 찍고 밤에 봐요.")
	await punch_out()
