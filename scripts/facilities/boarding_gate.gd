class_name BoardingGate
extends Facility
## 탑승구 (Gate 01~04, and the impossible Gate 0). Local frame: door in the wall at origin,
## +Z points into the lounge. Normal = door closed & locked, display "CLOSED".
## Anomalies: gate_open (door open, FLIGHT 000 BOARDING), gate_seats (seats turned to face the door),
## gate_passenger (one passenger is sitting there).

var number := "03"
var door: SlidingDoor
var status_label: Label3D
var podium_label: Label3D
var seat_rows: Array[Node3D] = []
var passenger: Node3D
var checked := false
var _wind: AudioStreamPlayer3D
var _bridge_light: OmniLight3D
var _blink := 0.0
var _enter_area: Area3D
var _status_text := "CLOSED"
var _status_color := Color(1.0, 0.3, 0.25)
var _door_interact: Interactable


func build(num: String, with_seats := true, with_bridge := true) -> void:
	number = num
	observe_radius = 13.0
	# door frame + door
	Geo.box(self, Vector3(0, 2.75, 0), Vector3(2.6, 0.5, 0.5), Mats.get_mat("metal_dark"), true)
	for sx in [-1.2, 1.2]:
		Geo.box(self, Vector3(sx, 1.25, 0), Vector3(0.2, 2.5, 0.5), Mats.get_mat("metal_dark"), true)
	door = SlidingDoor.create(self, Vector3(0, 0, 0), 0.0, 2.2, 2.5, true, false)
	# jet bridge stub behind the door (local -Z)
	var bridge := Node3D.new()
	add_child(bridge)
	bridge.position = Vector3(0, 0, -4.2)
	if with_bridge:
		Geo.box(bridge, Vector3(0, -0.05, 0), Vector3(2.6, 0.1, 7.6), Mats.get_mat("carpet"), true)
		Geo.box(bridge, Vector3(0, 2.75, 0), Vector3(2.6, 0.1, 7.6), Mats.get_mat("ceiling_dark"), false)
		for sx in [-1.35, 1.35]:
			Geo.box(bridge, Vector3(sx, 1.35, 0), Vector3(0.1, 2.7, 7.6), Mats.get_mat("wall_service"), true)
		Geo.box(bridge, Vector3(0, 1.35, -3.85), Vector3(2.8, 2.7, 0.1), Mats.get_mat("shutter"), true)
		_enter_area = Geo.area(bridge, Vector3(0, 1.0, 2.6), Vector3(2.2, 2.0, 1.2))
		_enter_area.body_entered.connect(_on_enter_bridge)
	_bridge_light = Geo.omni(bridge, Vector3(0, 2.3, -1.0), Color(0.55, 0.7, 1.0), 0.0, 8.0)
	_door_interact = Interactable.create(self, Vector3(0, 1.2, 0.1), Vector3(2.2, 2.4, 0.2), "탑승교로 들어가기", _on_door_used)
	_door_interact.press_sound = ""
	_door_interact.enabled = false
	_door_interact.collision_layer = 0
	# sign + status display above the door
	var sign := Node3D.new()
	add_child(sign)
	sign.position = Vector3(0, 3.45, 0.3)
	var plate := Geo.box(sign, Vector3.ZERO, Vector3(2.6, 0.8, 0.12), Mats.get_mat("sign_back"), false)
	if TripoProps.exists("common", "CMN_WallSign"):
		plate.visible = false        # kept as the label-fitting backing
		Props.sign_body(sign, Vector3.ZERO, Vector2(2.6, 0.8), 0.12)
	Geo.label(sign, "GATE " + number, Vector3(-0.5, 0.1, 0.065), 0.0, 70, Geo.SIGN_BLUE, 0.005)
	Geo.label(sign, "탑승구 " + number, Vector3(-0.5, -0.24, 0.065), 0.0, 36, Color(0.9, 0.9, 0.9), 0.005)
	Geo.box(sign, Vector3(0.82, 0, 0.065), Vector3(0.85, 0.6, 0.01), Mats.get_mat("screen_off"), false)
	status_label = Geo.label(sign, "CLOSED", Vector3(0.82, 0.0, 0.075), 0.0, 40, _status_color, 0.004, true)
	# podium in front of the door
	var podium := Node3D.new()
	add_child(podium)
	podium.position = Vector3(1.8, 0, 2.6)
	podium.rotation.y = -0.5
	if TripoProps.exists("terminal", "TRM_BoardingPodium"):
		TripoProps.spawn(podium, "terminal", "TRM_BoardingPodium", Vector3.ZERO, 0.0, true, null, Vector3(1.4, 1.14, 0.7))
	else:
		Geo.box(podium, Vector3(0, 0.55, 0), Vector3(1.3, 1.1, 0.6), Mats.get_mat("counter_front"), true)
		Geo.box(podium, Vector3(0, 1.12, 0), Vector3(1.4, 0.04, 0.7), Mats.get_mat("counter"), false)
	var top := Node3D.new()
	podium.add_child(top)
	top.position = Vector3(0, 1.16, 0.12)
	top.rotation.x = -0.9
	Geo.box(top, Vector3(0, 0, -0.02), Vector3(0.9, 0.3, 0.04), Mats.get_mat("plastic_grey"), false)
	Geo.box(top, Vector3(-0.18, 0.02, 0.0), Vector3(0.4, 0.2, 0.004), Mats.get_mat("screen_off"), false)
	podium_label = Geo.label(top, "GATE %s\nSTANDBY" % number, Vector3(-0.18, 0.02, 0.004), 0.0, 20, Color(0.6, 0.8, 1.0), 0.0022, true)
	Props.button(top, Vector3(0.12, 0.0, 0), 0.0, "button_blue", "상태 확인", "게이트 상태 확인", _on_check, 0.04)
	Props.button(top, Vector3(0.32, 0.0, 0), 0.0, "button_red", "닫기·잠금", "출입문 닫기 및 잠금", _on_lock, 0.04)
	focus = sign
	if with_seats:
		for i in 2:
			var row := Props.seat_row(self, Vector3(-1.2, 0, 5.2 + i * 1.6), 6, PI)
			seat_rows.append(row)
	_wind = Snd.make_loop("wind_loop", self, -8.0, 4.0, 20.0)
	_wind.position = Vector3(0, 1.5, -0.5)


func _process(delta: float) -> void:
	_blink += delta
	if anomaly == "gate_open" and powered:
		status_label.modulate = Color(0.3, 1.0, 0.45) if fmod(_blink, 1.0) < 0.65 else Color(0.1, 0.35, 0.15)
	if passenger and is_instance_valid(passenger):
		var head := passenger.get_node_or_null("Head") as Node3D
		var cam := get_viewport().get_camera_3d()
		if head and cam:
			var target := cam.global_position
			var flat := Vector3(target.x, head.global_position.y, target.z)
			if head.global_position.distance_to(flat) > 0.1:
				var desired := head.global_transform.looking_at(flat, Vector3.UP)
				head.global_basis = head.global_basis.slerp(desired.basis, delta * 0.4)


func _set_status(text: String, color: Color) -> void:
	_status_text = text
	_status_color = color
	Geo.set_text(status_label, text)
	status_label.modulate = color


func _on_check() -> void:
	act("start", id)
	if not powered:
		Snd.play_at("beep_error", focus_position(), -8.0)
		return
	checked = true
	running = true
	var door_state := "OPEN" if door.is_open else "LOCKED"
	Geo.set_text(podium_label, "GATE %s\nDOOR: %s" % [number, door_state])
	podium_label.modulate = Color(1.0, 0.4, 0.3) if door.is_open else Color(0.5, 1.0, 0.6)
	Snd.play_at("beep_ok", focus_position(), -10.0)
	changed.emit()


func _on_lock() -> void:
	act("close_gate", id)
	if door.is_open:
		door.close()
		_wind_off()
	Geo.set_text(podium_label, "GATE %s\nDOOR: LOCKED" % number)
	podium_label.modulate = Color(0.5, 1.0, 0.6)
	Snd.play_at("door_heavy", global_position + Vector3(0, 1.2, 0), -6.0, 1.0, 8.0)


func _on_door_used() -> void:
	act("enter_gate", id)


func _on_enter_bridge(body: Node3D) -> void:
	if body.is_in_group("player") and door.is_open:
		act("enter_gate", id)


func open_door(with_wind := true) -> void:
	door.open()
	_door_interact.enabled = true
	_door_interact.collision_layer = Geo.LAYER_INTERACT
	_bridge_light.light_energy = 1.2
	if with_wind:
		_wind.play()


func _wind_off() -> void:
	_door_interact.enabled = false
	_door_interact.collision_layer = 0
	_bridge_light.light_energy = 0.0
	var t := create_tween()
	t.tween_property(_wind, "volume_db", -60.0, 1.5)
	t.tween_callback(func():
		_wind.stop()
		_wind.volume_db = -8.0)


func _apply_anomaly(a: String) -> void:
	match a:
		"gate_open":
			_set_status("FLIGHT 000\nBOARDING", Color(0.3, 1.0, 0.45))
			open_door()
		"gate_seats":
			for row in seat_rows:
				row.rotation.y = 0.0
		"gate_passenger":
			if seat_rows.size() > 0:
				var row := seat_rows[seat_rows.size() - 1]
				passenger = Props.figure(row, Vector3(0.31 + 0.62, 0.0, 0.05), 0.0, true)


func _remove_anomaly(a: String) -> void:
	match a:
		"gate_open":
			_set_status("CLOSED", Color(1.0, 0.3, 0.25))
			if door.is_open:
				door.close()
			_wind_off()
		"gate_seats":
			for row in seat_rows:
				row.rotation.y = PI
		"gate_passenger":
			if passenger:
				passenger.queue_free()
				passenger = null


func passenger_position() -> Vector3:
	if passenger and is_instance_valid(passenger):
		return passenger.global_position + Vector3(0, 1.0, 0)
	return focus_position()


func _on_power_lost() -> void:
	Geo.set_text(status_label, "")
	Geo.set_text(podium_label, "")


func _on_power_restored() -> void:
	Geo.set_text(status_label, _status_text)
	Geo.set_text(podium_label, "GATE %s\nSTANDBY" % number)


func is_observable() -> bool:
	return powered and checked


func describe_state() -> String:
	if not powered:
		return "전원 차단"
	return "출입문 열림" if door.is_open else "출입문 잠김"
