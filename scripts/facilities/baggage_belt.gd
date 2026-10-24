class_name BaggageBelt
extends Facility
## 수하물 수취대 B-03 — oval carousel. Normal test run = exactly three tagged TEST bags.
## Anomalies: bag_extra (a 4th unknown red bag), bag_reverse (belt runs backwards),
## bag_nostop ([정지] is ignored), bag_name (story: a bag with the player's name).

const SPEED := 0.5
const BELT_Y := CarouselMesh.PLATE_Y

var half := 4.0
var radius := 2.3
var path_len := 0.0
var speed := 0.0
var target_speed := 0.0
var direction := 1.0
var estopped := false
var slats: Array[MeshInstance3D] = []
var slat_s: Array[float] = []
var bags: Array[Dictionary] = []
var spawn_queue: Array[String] = []
var spawn_timer := 0.0
var hatch_s := 0.0
var bags_seen := 0
var expect_bags := 3     # bags this run puts on the belt before it counts as observed (a lone suitcase = 1)
var _motor: AudioStreamPlayer3D
var _beacon: OmniLight3D
var _beacon_mesh: MeshInstance3D
var _beacon_t := 0.0
var _display: Label3D
var _flaps: Array[MeshInstance3D] = []


func build() -> void:
	observe_radius = 13.0
	path_len = 4.0 * half + 2.0 * PI * radius
	hatch_s = 2.0 * half + PI * radius * 0.5
	var dark := CarouselMesh.mat("kick")
	var steel := CarouselMesh.mat("steel")
	# flat-plate carousel: stainless rim, skirt and island, rubber bumper (CarouselMesh), moving crescent plates
	add_child(CarouselMesh.hull(half, radius))
	Geo.blocker(self, Vector3(0, 0.45, 0), Vector3(half * 2.0 + radius * 2.0 + 1.3, 0.9, radius * 2.0 + 1.3))
	var count := int(path_len / (CarouselMesh.PLATE_LEN - 0.02))
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = CarouselMesh.plate()
		mi.material_override = CarouselMesh.mat("rubber")
		add_child(mi)
		slats.append(mi)
		slat_s.append(i * path_len / count)
	_place_slats()
	# hatch at the east end where bags emerge: stainless housing, rubber strip curtain
	var hatch := Node3D.new()
	add_child(hatch)
	hatch.position = Vector3(half + radius + 0.75, 0, 0)
	Geo.box(hatch, Vector3(0.35, 1.0, 0), Vector3(0.9, 2.0, 1.6), steel, true)
	Geo.box(hatch, Vector3(0.35, 0.06, 0), Vector3(0.94, 0.12, 1.64), dark, false)
	Geo.box(hatch, Vector3(-0.12, 0.75, 0), Vector3(0.05, 0.9, 1.1), Mats.get_mat("black"), false)
	for i in 6:
		_flaps.append(Geo.box(hatch, Vector3(-0.15, 0.78, -0.45 + i * 0.18), Vector3(0.02, 0.85, 0.16), Mats.get_mat("rubber"), false))
	_beacon_mesh = Geo.cyl(hatch, Vector3(0.3, 2.12, 0.5), 0.08, 0.16, Mats.get_mat("screen_off"))
	_beacon = Geo.omni(hatch, Vector3(0.3, 2.3, 0.5), Color(1.0, 0.55, 0.05), 0.0, 8.0)
	# direction arrows painted on the island
	for side in [-1.0, 1.0]:
		var arrow := Geo.label(self, "▶ ▶ ▶" if side < 0 else "◀ ◀ ◀", Vector3(0, CarouselMesh.ISLAND_Y + 0.003, side * (radius - 0.95)), 0.0, 64, Geo.SIGN_BLUE, 0.006, false, "print")
		Geo.fit(arrow, half * 2.0, 0.5)      # painted inside the island's edge
		arrow.rotation.x = -PI / 2
	# carousel display
	var disp_holder := Node3D.new()
	add_child(disp_holder)
	disp_holder.position = Vector3(-half - radius - 0.2, 2.6, 0)
	disp_holder.rotation.y = -PI / 2
	Geo.box(disp_holder, Vector3(0, 0, -0.05), Vector3(1.6, 0.8, 0.1), steel, false)
	Geo.box(disp_holder, Vector3(0, 0, 0.001), Vector3(1.5, 0.7, 0.004), CarouselMesh.mat("panel"), false)
	var pole := MeshInstance3D.new()
	pole.mesh = CarouselMesh.rounded_prism(Vector3(0.09, 2.2, 0.09), 0.03)
	pole.material_override = steel
	disp_holder.add_child(pole)
	pole.position = Vector3(0, -2.6, -0.05)
	Geo.label(disp_holder, "B-03", Vector3(0, 0.13, 0.005), 0.0, 70, Geo.SIGN_BLUE, 0.004, true)
	_display = Geo.label(disp_holder, "TEST", Vector3(0, -0.18, 0.005), 0.0, 42, Color(0.6, 0.65, 0.7), 0.004, true)
	focus = self
	_motor = Snd.make_loop("belt_loop", self, -6.0, 5.0, 26.0)
	_motor.position = Vector3(0, 0.5, 0)


func path_point(s: float) -> Array:
	s = fposmod(s, path_len)
	var straight := 2.0 * half
	var arc := PI * radius
	if s < straight:
		return [Vector3(-half + s, 0, -radius), Vector3(1, 0, 0)]
	s -= straight
	if s < arc:
		var a := -PI * 0.5 + s / radius
		return [Vector3(half + radius * cos(a), 0, radius * sin(a)), Vector3(-sin(a), 0, cos(a))]
	s -= arc
	if s < straight:
		return [Vector3(half - s, 0, radius), Vector3(-1, 0, 0)]
	s -= straight
	var a2 := PI * 0.5 + s / radius
	return [Vector3(-half + radius * cos(a2), 0, radius * sin(a2)), Vector3(-sin(a2), 0, cos(a2))]


func _place_slats() -> void:
	for i in slats.size():
		var p: Array = path_point(slat_s[i])
		var pos: Vector3 = p[0]
		var tan: Vector3 = p[1]
		slats[i].position = pos + Vector3(0, BELT_Y, 0)
		slats[i].rotation.y = atan2(tan.x, tan.z)


func _process(delta: float) -> void:
	var want := target_speed if powered else 0.0
	speed = move_toward(speed, want, delta * (0.6 if want > speed else 0.9))
	if estopped:
		speed = 0.0
	var v := speed * direction
	if absf(v) > 0.0001:
		for i in slat_s.size():
			slat_s[i] += v * delta
		_place_slats()
		for b in bags:
			b.s += v * delta
			_place_bag(b)
	_motor.volume_db = lerpf(-30.0, -6.0, clampf(speed / SPEED, 0.0, 1.0))
	if speed > 0.02 and not _motor.playing:
		_motor.play(randf())
	elif speed <= 0.02 and _motor.playing:
		_motor.stop()
	# bag spawning
	if running and powered and not estopped and not spawn_queue.is_empty():
		spawn_timer -= delta
		if spawn_timer <= 0.0 and _hatch_clear():
			_spawn_bag(spawn_queue.pop_front())
			spawn_timer = 2.6
	# beacon
	if _beacon_t > 0.0:
		_beacon_t -= delta
		var on := fmod(_beacon_t, 0.6) < 0.3
		_beacon.light_energy = 2.0 if on else 0.0
		_beacon_mesh.material_override = Mats.get_mat("lamp_amber") if on else Mats.get_mat("screen_off")
		if _beacon_t <= 0.0:
			_beacon.light_energy = 0.0
			_beacon_mesh.material_override = Mats.get_mat("screen_off")


func _hatch_clear() -> bool:
	for b in bags:
		var d := fposmod(b.s - hatch_s, path_len)
		if d < 1.0 or d > path_len - 1.0:
			return false
	return true


func _spawn_bag(kind: String) -> void:
	var color := Color(0.06, 0.06, 0.07)
	var tag := ""
	var soft := false
	match kind:
		"test1":
			color = Color(0.05, 0.05, 0.06)
			tag = "TEST 01"
		"test2":
			color = Color(0.06, 0.09, 0.2)
			tag = "TEST 02"
			soft = true
		"test3":
			color = Color(0.32, 0.33, 0.35)
			tag = "TEST 03"
		"extra":
			color = Color(0.45, 0.03, 0.03)
		"name":
			color = Color(0.2, 0.14, 0.09)
			tag = "%s\nFLIGHT 000\n→ ---" % Game.player_name
		"pax":
			# 1987: a passenger's bag, finally on a carousel
			color = Color.from_hsv(randf_range(0.0, 1.0), randf_range(0.15, 0.45), randf_range(0.18, 0.42))
			tag = "A0 · 1987\n→ HOME"
			soft = randf() < 0.4
	var root := Props.suitcase(self, color, tag, soft)
	var it := Interactable.create(root, Vector3(0, 0.15, 0), Vector3(0.5, 0.32, 0.72), "가방 들어 확인하기", _on_touch_bag.bind(kind))
	it.press_sound = ""
	var b := {"node": root, "s": hatch_s, "kind": kind}
	bags.append(b)
	_place_bag(b)
	root.position.y += 0.6
	create_tween().tween_property(root, "position:y", root.position.y - 0.6, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	Snd.play_at("luggage_thump", global_position + Vector3(half + radius, 0.5, 0), -2.0, randf_range(0.9, 1.1), 5.0)
	bags_seen += 1
	for flap in _flaps:
		var t := create_tween()
		t.tween_property(flap, "rotation:z", 0.5, 0.15)
		t.tween_property(flap, "rotation:z", 0.0, 0.6)


func _place_bag(b: Dictionary) -> void:
	var p: Array = path_point(b.s)
	var node: Node3D = b.node
	node.position = Vector3(p[0].x, BELT_Y + 0.02, p[0].z)
	node.rotation.y = atan2(p[1].x, p[1].z)


func _on_touch_bag(kind: String) -> void:
	Snd.play_at("luggage_thump", global_position, -10.0, 1.3, 3.0)
	act("touch_bag", kind)
	if kind.begins_with("test"):
		Events.notify.emit("노란 TEST 태그가 붙은 점검용 가방이다.", "info")


func remove_bag(kind: String, fade := true) -> void:
	for b in bags.duplicate():
		if b.kind == kind:
			bags.erase(b)
			var n: Node3D = b.node
			if fade:
				var t := n.create_tween()
				t.tween_property(n, "scale", Vector3(1, 0.01, 1), 0.6)
				t.tween_callback(n.queue_free)
			else:
				n.queue_free()


func has_bag(kind: String) -> bool:
	for b in bags:
		if b.kind == kind:
			return true
	return false


## A new work order starts from an empty, stopped belt.
func reset_for_inspection() -> void:
	clear_bags()
	bags_seen = 0
	expect_bags = 3
	estopped = false
	target_speed = 0.0
	running = false
	direction = 1.0


func clear_bags() -> void:
	for b in bags:
		b.node.queue_free()
	bags.clear()
	spawn_queue.clear()


func _on_start() -> void:
	estopped = false
	target_speed = SPEED
	Geo.set_text(_display, "RUN")
	_display.modulate = Color(0.4, 1.0, 0.5)
	direction = -1.0 if anomaly == "bag_reverse" else 1.0
	if bags.is_empty() and spawn_queue.is_empty():
		spawn_queue.assign(["test1", "test2", "test3"])
		if anomaly == "bag_extra":
			spawn_queue.append("extra")
		elif anomaly == "bag_name":
			spawn_queue.append("name")
		spawn_timer = 1.2
		expect_bags = 3
	elif bags.is_empty():
		expect_bags = spawn_queue.size()


func _on_stop() -> void:
	target_speed = 0.0
	Geo.set_text(_display, "STOP")
	_display.modulate = Color(0.6, 0.65, 0.7)


func press_start() -> void:
	act("start", id)
	if running and not estopped:
		return
	start(true)


func press_stop() -> void:
	act("stop", id)
	if anomaly == "bag_nostop" and running:
		Snd.play_at("beep_error", focus_position(), -6.0)
		Geo.set_text(_display, "RUN")
		return
	stop()


func press_estop() -> void:
	act("estop", id)
	estopped = true
	target_speed = 0.0
	speed = 0.0
	running = false
	_beacon_t = 6.0
	Geo.set_text(_display, "E-STOP")
	_display.modulate = Color(1.0, 0.3, 0.2)
	Snd.play_at("ui_alert", focus_position(), -4.0, 0.8, 8.0)
	changed.emit()


func _on_power_lost() -> void:
	target_speed = 0.0
	Geo.set_text(_display, "")


func _on_power_restored() -> void:
	Geo.set_text(_display, "STOP")


func _apply_anomaly(anomaly_id: String) -> void:
	match anomaly_id:
		"bag_reverse":
			if running:
				direction = -1.0
		"bag_extra":
			if running and not has_bag("extra"):
				spawn_queue.append("extra")
		"bag_name":
			if not has_bag("name"):
				spawn_queue.append("name")


func _remove_anomaly(anomaly_id: String) -> void:
	match anomaly_id:
		"bag_reverse":
			direction = 1.0
		"bag_extra":
			spawn_queue.erase("extra")
			remove_bag("extra")
		"bag_name":
			spawn_queue.erase("name")
			remove_bag("name")


func is_observable() -> bool:
	return powered and spawn_queue.is_empty() and bags_seen >= expect_bags


func describe_state() -> String:
	if not powered:
		return "전원 차단"
	if estopped:
		return "비상정지"
	return "가동 중" if running else "정지"
