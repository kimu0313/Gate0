extends PhaseScript
## NIGHT 5 — 10/22, 개장 전날 밤. 전 구역 동시 이상, 마지막 10회 점검. 무전은 끊긴다 (수칙 p.9 ④).
## 점검이 끝나면 FINAL CALL과 함께 0번 게이트가 열린다. 최종 수칙 선택 → 엔딩 4종:
##   A 탑승     — 0번 게이트 탑승교 끝까지 걸어간다 (가짜 f10을 따른다)
##   B 정상 개장 — 진짜 p.10대로 정비 통로의 주 전원을 내리고 비상구로 나간다 (판정 기록이 나쁘면 레버가 움직이지 않는다)
##   C 안내방송  — 침식도 100 (판정 기록이 무너졌다)
##   D 귀환     — 1987년의 흔적 3개(동판·신문 조각·근태 카드)를 모았다면, PA 콘솔에서 도착 안내를 한다

const MAIN_POWER_LIMIT := 60.0    # erosion at/above this: the lever will not move for a passenger
const ARRIVAL_LIMIT := 75.0

var finale := false
var power_cut := false
var _follower: AudioStreamPlayer3D


func title_lines() -> Array:
	return ["NIGHT 5", "10월 22일 · 23:00 · 마지막 밤"]


func setup() -> void:
	d.set_shutters_for_cycle(5)
	d.clock_speed = 0.12
	d.office_mode = "passenger"
	for id in ["f8", "f10"]:
		Game.add_binder_page(id)
	place_documents()
	d.t.triggers.emergency_out.body_entered.connect(_on_emergency_out)
	d.main_power_pulled.connect(_on_main_power)


func run() -> void:
	if OS.get_cmdline_user_args().has("--finale"):   # debug: skip the inspections, straight to FINAL CALL
		await d.wait(1.0)
		await _finale()
		return
	await d.wait(1.0)
	await d.radio("…들려요? 오늘은… 무전이 잘 안…")
	Snd.radio_static(true)
	await d.wait(2.0)
	Snd.radio_static(false)
	d.notify("무전 연결이 끊겼다. 수칙만 믿으십시오. (p.9 ④)", "bad")
	d.notify("바인더에 낯선 페이지가 또 끼워져 있다. p.10이 두 장이다.", "info")
	d.ui.hud.show_key_hints(15.0)
	var plan := NightPlan.build(5)
	await d.run_inspections(plan, {4: _blackout, 7: _slow_pa})
	if d.dead:
		return
	await _finale()


func _blackout() -> void:
	await d.wait(1.5)
	await d.ev_blackout(10.0, true)


func _slow_pa() -> void:
	await d.wait(2.0)
	await d.ev_slow_broadcast(true)


# --- FINAL CALL ------------------------------------------------------------------------------
func _finale() -> void:
	finale = true
	d.jump_clock(27 * 60 + 40)
	d.t.facility("fids").set_story("final", ["SH 000", "GATE 0", "FINAL CALL"])
	Snd.play("sub_boom", 0.0, 0.8, "SFX")
	d.p.add_shake(0.4)
	d.t.reveal_gate0()
	var g0: BoardingGate = d.t.gates["0"]
	g0._set_status("FLIGHT 000\nFINAL CALL", Color(1.0, 0.3, 0.25))
	g0.open_door(true)
	d.t.triggers.board_door.body_entered.connect(func(b):
		if b.is_in_group("player") and not power_cut and not d.ending_started:
			d.start_ending("board"))
	d.ui.tablet.boarding_mode = true
	d.main_power_enabled = Game.erosion < MAIN_POWER_LIMIT
	if not d.main_power_enabled:
		Game.set_flag("lever_refused")
	var pa: PaConsole = d.t.facility("pa")
	if RulesDB.TRUE_CLUES.all(func(c): return Game.has_clue(c)) and Game.erosion < ARRIVAL_LIMIT:
		pa.enable_arrival(_on_arrival)
		Game.set_flag("arrival_ready")
	d.objective("최종 수칙을 선택하십시오.")
	d.notify("0번 게이트가 열렸다. 수칙 p.10을 확인하십시오.", "alert")
	if Game.flag("arrival_ready"):
		d.notify("안내 데스크 PA 콘솔에 처음 보는 버튼이 켜져 있다.", "info")
	_lights_die()
	_final_call_loop()
	_pressure()


func _lights_die() -> void:
	for zn in ["office", "service", "baggage", "security", "corridor", "hall"]:
		await d.wait(1.4)
		if power_cut or d.ending_started:
			return
		d.t.zones[zn].set_on(false)
		Snd.play_at("flicker_zap", d.p.global_position + Vector3(randf_range(-8, 8), 4, randf_range(-8, 8)), -6.0, 0.8)
	d.t.set_zone_light("gates", true)
	d.t.set_zone_light("hall", true)
	d.notify("북쪽 창밖, 터미널을 마주 보고 비행기 한 대가 서 있다.", "info")


func _final_call_loop() -> void:
	while finale and not power_cut and not d.dead and not d.ending_started:
		await d.pa(["pa_final_call_ko", "pa_final_call_en"], {"wrong": true, "tag": "final",
			"subs": ["영편 최종 탑승 안내입니다. 아직 탑승하지 않으신 승객께서는, 지금 즉시 영번 게이트로 오시기 바랍니다.",
				"This is the final boarding call for flight zero. Remaining passenger, please proceed to gate zero immediately."]})
		await d.wait(22.0)


## Waiting is a choice too: the terminal keeps checking you in.
func _pressure() -> void:
	while finale and not d.dead and not d.ending_started:
		await d.wait(8.0)
		if not power_cut:
			Game.add_erosion(1.0)


# --- ending D · 귀환: the arrival nobody announced in 1987 --------------------------------------------
func _on_arrival() -> void:
	if d.ending_started or power_cut:
		return
	finale = false
	Snd.pa_stop()
	d.p.controls_enabled = false
	await d.wait(1.0)
	var g0: BoardingGate = d.t.gates["0"]
	await d.pa(["pa_arrival_ko", "pa_arrival_en"], {"tag": "arrival",
		"subs": ["서해비행장을 출발한 영편이, 지금 도착했습니다. 마중 나오신 분들께서는, 일번 출구에서 기다려 주시기 바랍니다.",
			"Flight zero from Seohae Airfield has now arrived. Those meeting passengers, please wait at exit one."]})
	g0._on_lock()
	for z in d.t.zones.values():
		(z as LightZone).intensity = 1.0
		(z as LightZone).set_on(true)
	d.arrival_announced.emit()
	await d.wait(2.0)
	d.start_ending("return")


# --- ending B · 정상 개장: main power → emergency exit -----------------------------------------------
func _on_main_power() -> void:
	if power_cut:
		return
	power_cut = true
	finale = false
	Game.set_flag("main_power_cut")
	Snd.pa_stop()
	Snd.play("power_down", 0.0, 0.75, "SFX")
	d.p.add_shake(0.3)
	for z in d.t.zones.values():
		z.set_powered(false)
	for f in d.t.facilities.values():
		(f as Facility).set_powered(false)
	d.t.arrivals.set_powered(false)
	if d.t.gate0_parts:
		for n in d.t.gate0_parts.find_children("*", "Light3D", true, false):
			(n as Light3D).visible = false
	if d.t.final_plane:
		for n in d.t.final_plane.find_children("*", "Light3D", true, false):
			(n as Light3D).visible = false
	for n in d.t.outside_lights:
		n.visible = false
	d.t.emergency_light_root.visible = true
	for i in 3:
		var ch := d.t.get_node_or_null("Chain%d" % i)
		if ch:
			ch.visible = false
	d.t.exit_door_use.prompt = "비상구로 나가기"
	await d.wait(2.5)
	d.objective("비상구로 나가십시오. (체크인 홀 남측, 초록 표시등)")
	d.notify("완전한 어둠. 비상구 표시등만 켜져 있다.", "info")
	_follow_me()


## Something rolls a suitcase behind you all the way to the exit.
func _follow_me() -> void:
	_follower = AudioStreamPlayer3D.new()
	_follower.stream = Snd.stream("luggage_roll_loop")
	_follower.unit_size = 5.0
	_follower.bus = "SFX"
	d.t.add_child(_follower)
	_follower.play()
	var dist := 16.0
	while not d.ending_started and not d.dead:
		await d.wait(0.05)
		dist = maxf(3.0, dist - 0.05 * 0.18)
		var back := -d.p.forward()
		back.y = 0.0
		var target := d.p.global_position + back.normalized() * dist
		_follower.global_position = _follower.global_position.lerp(target, 0.08)


func _on_emergency_out(body: Node3D) -> void:
	if power_cut and body.is_in_group("player"):
		d.start_ending("exit")
