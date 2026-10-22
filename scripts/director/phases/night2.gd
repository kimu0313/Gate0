extends PhaseScript
## NIGHT 2 — 10/19. +수하물 구역. 첫 훼손 수칙(p.3). 관찰 포인트: 벨트 위 가방의 개수·색, 방송 문안.
## 6번째 점검: B-03이 혼자 돈다 → 멈추면 "마지막 수하물이 도착했습니다" → 당신의 이름이 적힌 가방.


func title_lines() -> Array:
	return ["NIGHT 2", "10월 19일 · 23:00 · 야간 시설 점검"]


func setup() -> void:
	d.set_shutters_for_cycle(2)
	d.clock_speed = 0.12
	if Game.binder_pages.has("p3"):
		Game.remove_binder_page("p3")
		Game.add_binder_page("p3_dmg")
	place_documents()


func run() -> void:
	await night_briefing("둘째 날 밤이네요. 오늘은 수하물 구역까지 점검해요.")
	d.notify("바인더 3페이지가 젖어서 글자가 번져 있다…", "info")
	var plan := NightPlan.build(2)
	await d.run_inspections(plan, {4: _namecall, 8: _three_am}, {6: _last_baggage})
	if d.dead:
		return
	await d.radio("…오늘 이상한 게 많았네요. 끝났으면 퇴근 찍어요.")
	await punch_out("근무 종료 기록", "시설관리실 [b]근태 기록기[/b]에서 근무 종료를 기록하십시오.")


func _namecall() -> void:
	await d.wait(2.0)
	await d.ev_namecall(false)


func _three_am() -> void:
	d.jump_clock(27 * 60)
	await d.wait(1.0)
	await d.ev_3am(false)


## The belt runs by itself; you stop it; the last suitcase arrives — with your name.
func _last_baggage(slot: Dictionary) -> Task:
	var belt: BaggageBelt = d.t.facility("baggage")
	belt.reset_for_inspection()
	belt.start(false)
	var task := d.inspect("baggage", slot.title, slot.detail, "", {"urgent": true, "slot": 6})
	task.locked = "벨트를 정지시키고 끝까지 확인하십시오."
	_last_baggage_flow(task, belt)
	return task


func _last_baggage_flow(task: Task, belt: BaggageBelt) -> void:
	d.radio("수하물 B-03이 혼자 돌고 있대요. 가서 멈춰 줄래요?")   # not awaited: the belt may be stopped while it talks
	while not d.dead and belt.running:
		await d.wait(0.2)
	if d.dead:
		return
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
