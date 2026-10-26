class_name PaConsole
extends Facility
## 안내방송 콘솔. [테스트 방송] plays the standard test announcement; [송출 중지] cuts the PA.
## Anomalies: pa_word (one word differs from the standard text), pa_slow (the voice drags and deepens),
## pa_extra (a sentence is added after the standard text), pa_auto (the PA keeps broadcasting by itself).
## The console came from the old airfield (DAY 3 transfer list): its left end is a built-in cassette deck. `service`
## is the story's handle on it (fault check, module swap, playing the A0 tape), switched on by the day script;
## [송출 중지] does nothing while the tape is on air.

const TEXT_NORMAL := "안내 말씀 드립니다. 현재 터미널 시설 점검이 진행 중입니다. 관계자 외에는 출입을 삼가 주시기 바랍니다. 감사합니다."
const TEXT_EN := "Attention please. Facility inspection is currently in progress in this terminal. Authorized personnel only. Thank you."
const WORD_VARIANTS := [
	["pa_test_anom_a_ko", "안내 말씀 드립니다. 현재 터미널 탑승 수속이 진행 중입니다. 관계자 외에는 출입을 삼가 주시기 바랍니다. 감사합니다."],
	["pa_test_anom_b_ko", "안내 말씀 드립니다. 현재 터미널 시설 점검이 진행 중입니다. 승객 외에는 출입을 삼가 주시기 바랍니다. 감사합니다."],
	["pa_test_anom_c_ko", "안내 말씀 드립니다. 현재 터미널 시설 점검이 진행 중입니다. 관계자 외에는 출입을 삼가 주시기 바랍니다. 기다리고 있겠습니다."],
]
const TEXT_EXTRA := "안내 말씀 드립니다. 현재 터미널 시설 점검이 진행 중입니다. 관계자 외에는 출입을 삼가 주시기 바랍니다. 감사합니다. 지금 움직이시는 분, 거기 계신 거 다 보입니다."
const AUTO_SUBS := ["영편 승객께서는 출국장으로 이동해 주시기 바랍니다.", "Passengers of flight zero, please proceed to the departure area."]

var heard := false
var word_variant := 0
var _lcd: Label3D
var _vu: Array[MeshInstance3D] = []
var _onair: MeshInstance3D
var _t := 0.0
var _auto_running := false
var _quiet_cancel := false
var service: Interactable     # story use of the console / deck (disabled until a day script sets it up)
var fault := false            # DAY 3: SPK-07 has no output until the spare module is fitted
var _deck_lamp: MeshInstance3D


func build() -> void:
	needs_running = true
	observe_radius = 30.0
	Geo.box(self, Vector3(0, 0.04, 0), Vector3(0.9, 0.08, 0.45), Mats.get_mat("plastic_dark"), false)
	var face := Node3D.new()
	add_child(face)
	face.position = Vector3(0, 0.1, 0.05)
	face.rotation.x = -1.1
	Geo.box(face, Vector3(0, 0, -0.02), Vector3(0.86, 0.36, 0.04), Mats.get_mat("plastic_grey"), false)
	Geo.label(face, "PA-01  안내방송", Vector3(-0.22, 0.13, 0.002), 0.0, 22, Geo.SIGN_BLUE, 0.0024, false, "print")
	Props.button(face, Vector3(-0.25, -0.04, 0), 0.0, "button_green", "테스트 방송", "테스트 방송 송출", _on_test)
	Props.button(face, Vector3(-0.05, -0.04, 0), 0.0, "button_red", "송출 중지", "방송 송출 중지", _on_stop)
	# LCD + VU meter
	Geo.box(face, Vector3(0.24, 0.04, 0.0), Vector3(0.3, 0.12, 0.004), Mats.get_mat("screen_off"), false)
	_lcd = Geo.label(face, "READY", Vector3(0.24, 0.05, 0.004), 0.0, 22, Color(0.35, 1.0, 0.5), 0.0022, true)
	for i in 8:
		var bar := Geo.box(face, Vector3(0.12 + i * 0.033, -0.07, 0.004), Vector3(0.022, 0.06, 0.004), Mats.get_mat("lamp_green") if i < 6 else Mats.get_mat("lamp_red"), false)
		bar.scale.y = 0.05
		_vu.append(bar)
	# gooseneck mic
	var mic := Node3D.new()
	add_child(mic)
	mic.position = Vector3(0.3, 0.08, -0.12)
	Geo.cyl(mic, Vector3(0, 0.02, 0), 0.05, 0.04, Mats.get_mat("plastic_dark"))
	var neck := Geo.cyl(mic, Vector3(0, 0.2, 0.04), 0.008, 0.38, Mats.get_mat("metal_dark"))
	neck.rotation.x = 0.35
	Geo.capsule(mic, Vector3(0, 0.38, 0.12), 0.022, 0.1, Mats.get_mat("plastic_dark")).rotation.x = 1.2
	_onair = Geo.box(self, Vector3(-0.3, 0.12, -0.2), Vector3(0.18, 0.06, 0.02), Mats.get_mat("screen_off"), false)
	Geo.label(_onair, "ON AIR", Vector3(0, 0, 0.012), 0.0, 18, Color(0.9, 0.9, 0.9), 0.002)
	# cassette deck built into the left end of the console
	var deck := Node3D.new()
	add_child(deck)
	deck.position = Vector3(-0.62, 0.0, 0.03)
	Geo.box(deck, Vector3(0, 0.05, 0), Vector3(0.3, 0.1, 0.34), Mats.get_mat("plastic_dark"), false)
	Geo.box(deck, Vector3(0, 0.1015, 0.03), Vector3(0.21, 0.003, 0.13), Mats.get_mat("screen_off"), false)      # cassette door
	Geo.box(deck, Vector3(0, 0.1035, 0.03), Vector3(0.1, 0.002, 0.04), Mats.std(Color(0.32, 0.33, 0.35), 0.35), false)   # window
	for i in 4:
		Geo.box(deck, Vector3(-0.075 + i * 0.05, 0.103, -0.1), Vector3(0.04, 0.008, 0.03), Mats.get_mat("plastic_grey"), false)
	_deck_lamp = Geo.box(deck, Vector3(0.115, 0.1025, 0.11), Vector3(0.018, 0.004, 0.018), Mats.get_mat("screen_off"), false)
	var tape_l := Geo.label(deck, "TAPE", Vector3(-0.1, 0.104, 0.12), 0.0, 16, Color(0.75, 0.78, 0.8), 0.0018, false, "print")
	tape_l.rotation.x = -PI / 2
	service = Interactable.create(deck, Vector3(0, 0.08, 0), Vector3(0.34, 0.18, 0.38), "", Callable())
	service.enabled = false
	focus = face
	Snd.pa_started.connect(_on_pa_started)
	Snd.pa_finished.connect(_on_pa_finished)


func _process(delta: float) -> void:
	_t += delta
	if fault and not Snd.pa_busy:
		_lcd.modulate = Color(1.0, 0.62, 0.15) if fmod(_t, 1.0) < 0.6 else Color(0.35, 0.2, 0.05)
	var live := Snd.pa_busy
	for i in _vu.size():
		var level := 0.05
		if live:
			level = clampf(0.3 + 0.7 * absf(sin(_t * (7.0 + i * 1.3) + i)) * randf_range(0.6, 1.0) - i * 0.07, 0.05, 1.0)
		_vu[i].scale.y = lerpf(_vu[i].scale.y, level, 0.4)


func _on_test() -> void:
	if not powered:
		Snd.play_at("beep_error", focus_position(), -8.0)
		return
	if Snd.pa_busy:
		Events.notify.emit("방송이 이미 송출 중입니다.", "info")
		return
	act("pa_test", id)
	start(true)
	play_test()


func play_test() -> void:
	var clips := ["pa_test_normal_ko", "pa_test_normal_en"]
	var subs := [TEXT_NORMAL, TEXT_EN]
	var opts := {"tag": "test"}
	match anomaly:
		"pa_word":
			var v: Array = WORD_VARIANTS[word_variant % WORD_VARIANTS.size()]
			clips[0] = v[0]
			subs[0] = v[1]
		"pa_slow":
			opts["slow_index"] = 0
			subs[0] = "안내 말씀 드립니다… 현재 터미널 시설 점검이… 진행 중… 입니다…"
		"pa_extra":
			clips[0] = "pa_test_anom_d_ko"
			subs[0] = TEXT_EXTRA
	opts["subs"] = subs
	var finished := await Snd.pa_announce(clips, opts)
	running = false
	if finished:
		heard = true
	changed.emit()


func _on_stop() -> void:
	act("pa_stop", id)
	if Snd.pa_busy and Snd.pa_tag == "tape":
		# the old deck does not answer the console any more
		Snd.play_at("beep_error", focus_position(), -6.0)
		Events.notify.emit("[송출 중지]가 듣지 않는다. 테이프가 계속 돈다.", "alert")
		return
	if Snd.pa_busy:
		Snd.pa_stop()


## DAY 3: speaker channel SPK-07 is dead (the spare amp module is in the storage room's transfer crate).
func set_fault(on: bool) -> void:
	fault = on
	_deck_lamp.material_override = Mats.get_mat("lamp_red") if on else Mats.get_mat("screen_off")
	Geo.set_text(_lcd, "SPK-07 FAULT" if on else "READY")
	_lcd.modulate = Color(1.0, 0.62, 0.15) if on else Color(0.35, 1.0, 0.5)


## pa_auto: the console keeps announcing flight 000 by itself until someone presses [송출 중지].
func _auto_loop() -> void:
	if _auto_running:
		return
	_auto_running = true
	while anomaly == "pa_auto" and is_inside_tree():
		if powered and not Snd.pa_busy:
			running = true
			await Snd.pa_announce(["pa_flight0_move_ko", "pa_flight0_move_en"], {"wrong": true, "tag": "auto", "subs": AUTO_SUBS})
			running = false
			heard = true
			changed.emit()
		await get_tree().create_timer(7.0, false).timeout
	_auto_running = false


func _apply_anomaly(a: String) -> void:
	if a == "pa_auto":
		_auto_loop()


func _on_pa_started(tag: String) -> void:
	_onair.material_override = Mats.get_mat("lamp_red")
	Geo.set_text(_lcd, "ON AIR" if tag != "tape" else "TAPE PLAY")
	_lcd.modulate = Color(1.0, 0.35, 0.3)
	if tag == "tape":
		_deck_lamp.material_override = Mats.get_mat("lamp_green")


func _on_pa_finished(cancelled: bool) -> void:
	_onair.material_override = Mats.get_mat("screen_off")
	_deck_lamp.material_override = Mats.get_mat("lamp_red") if fault else Mats.get_mat("screen_off")
	Geo.set_text(_lcd, "SPK-07 FAULT" if fault else ("STOPPED" if cancelled and not _quiet_cancel else "READY"))
	_lcd.modulate = Color(1.0, 0.62, 0.15) if fault else Color(0.35, 1.0, 0.5)
	if _quiet_cancel:
		_quiet_cancel = false
		return
	if cancelled:
		heard = true
		running = false


func is_observable() -> bool:
	return powered and (heard or running)


func _on_power_lost() -> void:
	if Snd.pa_busy:
		Snd.pa_stop()
	Geo.set_text(_lcd, "")


func _on_power_restored() -> void:
	Geo.set_text(_lcd, "READY")


func reset_inspection() -> void:
	# a test broadcast still on air from the last inspection would block [테스트 방송] (or stand in for it)
	if Snd.pa_busy and Snd.pa_tag == "test":
		_quiet_cancel = true
		Snd.pa_stop(true)
	heard = false
	running = false


func describe_state() -> String:
	if not powered:
		return "전원 차단"
	if Snd.pa_busy:
		return "송출 중"
	return "청취 완료" if heard else "대기"
