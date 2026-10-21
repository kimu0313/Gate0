class_name XrayMachine
extends Facility
## 보안검색대 X-ray 1번 레인. [테스트 가방 투입] scans the test bag and shows the image.
## Anomalies: xray_figure (a curled human shape in the bag), xray_heart (something beating).

var screen: XrayScreen
var viewport: SubViewport
var screen_mat: StandardMaterial3D
var monitor_on := true
var scanned := false
var _tray: Node3D
var _tray_t := 0.0
var _tray_target := 0.0
var _belt: AudioStreamPlayer3D
var _stare_time := 0.0
var monitor_node: Node3D


## Machine body along local Z. The operator monitor is offset to local +X.
func build() -> void:
	observe_radius = 6.0
	var dark := Mats.get_mat("plastic_grey")
	# roller tables
	for z in [2.0, -2.0]:
		Geo.box(self, Vector3(0, 0.38, z), Vector3(0.8, 0.76, 1.6), Mats.get_mat("metal_dark"), true)
		for i in 8:
			Geo.cyl(self, Vector3(0, 0.78, z - 0.7 + i * 0.2), 0.03, 0.75, Mats.get_mat("metal")).rotation.z = PI / 2
	# machine body with tunnel
	Geo.box(self, Vector3(0, 0.39, 0), Vector3(1.1, 0.78, 2.4), dark, true)
	Geo.box(self, Vector3(-0.47, 1.15, 0), Vector3(0.16, 0.75, 2.4), dark, true)
	Geo.box(self, Vector3(0.47, 1.15, 0), Vector3(0.16, 0.75, 2.4), dark, true)
	Geo.box(self, Vector3(0, 1.6, 0), Vector3(1.1, 0.16, 2.4), dark, true)
	Geo.box(self, Vector3(0, 1.15, 0), Vector3(0.78, 0.74, 2.3), Mats.get_mat("black"), false)
	for z in [1.18, -1.18]:
		for i in 5:
			Geo.box(self, Vector3(-0.3 + i * 0.15, 1.15, z), Vector3(0.14, 0.7, 0.01), Mats.get_mat("rubber"), false)
	Geo.box(self, Vector3(0.56, 1.3, 0.6), Vector3(0.01, 0.2, 0.5), Mats.get_mat("lamp_amber"), false)
	Geo.label(self, "X-RAY 01", Vector3(0.56, 1.0, 0.0), PI / 2, 44, Color(0.9, 0.9, 0.9), 0.004)
	# tray with test bag
	_tray = Node3D.new()
	add_child(_tray)
	Geo.box(_tray, Vector3(0, 0.82, 0), Vector3(0.6, 0.06, 0.8), Mats.std(Color(0.35, 0.36, 0.4), 0.5), false)
	Geo.box(_tray, Vector3(0, 0.98, 0), Vector3(0.45, 0.26, 0.6), Mats.std(Color(0.12, 0.13, 0.15), 0.6), false)
	Geo.label(_tray, "TEST", Vector3(0, 1.115, 0), 0.0, 24, Color(0.95, 0.8, 0.1), 0.003).rotation.x = -PI / 2
	_set_tray(0.0)
	# operator desk + monitor (local +X side)
	Geo.box(self, Vector3(1.5, 0.4, 0.0), Vector3(0.7, 0.8, 1.0), Mats.get_mat("metal_dark"), true)
	monitor_node = Node3D.new()
	add_child(monitor_node)
	monitor_node.position = Vector3(1.4, 0.82, 0.0)
	monitor_node.rotation.y = PI / 2
	Geo.box(monitor_node, Vector3(0, 0.08, -0.05), Vector3(0.08, 0.16, 0.08), Mats.get_mat("plastic_dark"), false)
	Geo.box(monitor_node, Vector3(0, 0.42, -0.04), Vector3(0.66, 0.5, 0.06), Mats.get_mat("plastic_dark"), false)
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	screen = XrayScreen.new()
	screen.size = Vector2(640, 480)
	viewport.add_child(screen)
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.6, 0.45)
	quad.mesh = qm
	screen_mat = StandardMaterial3D.new()
	screen_mat.albedo_color = Color.BLACK
	screen_mat.emission_enabled = true
	screen_mat.emission_texture = viewport.get_texture()
	screen_mat.emission = Color.BLACK
	screen_mat.emission_energy_multiplier = 1.4
	quad.material_override = screen_mat
	monitor_node.add_child(quad)
	quad.position = Vector3(0, 0.42, -0.005)
	focus = quad
	var glow := Geo.omni(monitor_node, Vector3(0, 0.45, 0.5), Color(0.5, 0.7, 1.0), 0.25, 3.0)
	glow.light_volumetric_fog_energy = 0.4
	# control buttons on the desk front edge
	var panel := Node3D.new()
	add_child(panel)
	panel.position = Vector3(1.86, 0.78, 0.0)
	panel.rotation.y = PI / 2
	panel.rotation.x = -0.9
	Geo.box(panel, Vector3(0, 0, -0.02), Vector3(0.9, 0.22, 0.04), Mats.get_mat("plastic_grey"), false)
	Props.button(panel, Vector3(-0.3, 0.0, 0), 0.0, "button_green", "가방 투입", "테스트 가방 투입 (스캔)", _on_scan)
	Props.button(panel, Vector3(0.0, 0.0, 0), 0.0, "button_blue", "모니터", "모니터 전원 끄기/켜기", _on_monitor)
	Props.button(panel, Vector3(0.3, 0.0, 0), 0.0, "button_red", "비상정지", "X-ray 비상정지", _on_estop)
	_belt = Snd.make_loop("xray_loop", self, -10.0, 4.0, 18.0)
	_belt.position = Vector3(0, 1.0, 0)


func _set_tray(t: float) -> void:
	_tray_t = t
	_tray.position = Vector3(0, 0, lerpf(2.2, -2.2, t * 0.5))


func _process(delta: float) -> void:
	if absf(_tray_t - _tray_target) > 0.001:
		_set_tray(move_toward(_tray_t, _tray_target, delta * 0.45))
		if not _belt.playing:
			_belt.play()
		if is_equal_approx(_tray_t, 1.0) and _tray_target == 1.0:
			_belt.stop()
			_reveal()
	elif _belt.playing and not running:
		_belt.stop()
	if screen.scan_progress < 1.0:
		screen.scan_progress = minf(1.0, screen.scan_progress + delta * 0.8)
	# the figure slowly notices whoever stares at it
	if anomaly == "xray_figure" and scanned and monitor_on:
		var cam := get_viewport().get_camera_3d()
		if cam and cam.global_position.distance_to(focus_position()) < 4.0:
			var to := (focus_position() - cam.global_position).normalized()
			if -cam.global_basis.z.dot(to) > 0.85:
				_stare_time += delta
		screen.stare = clampf((_stare_time - 4.0) / 3.0, 0.0, 1.0)


func _on_scan() -> void:
	act("start", id)
	if not powered:
		Snd.play_at("beep_error", focus_position(), -8.0)
		return
	if _tray_target == 1.0 and scanned:
		# send the bag out and re-scan
		_tray_target = 0.0
		_set_tray(0.0)
		scanned = false
	start(true)
	screen.content = ""
	_tray_target = 1.0


func _reveal() -> void:
	scanned = true
	screen.scan_progress = 0.0
	_stare_time = 0.0
	screen.stare = 0.0
	screen.content = _content_for(anomaly)
	Snd.play_at("beep_ok", focus_position(), -10.0, 1.0, 4.0)
	changed.emit()


func _content_for(a: String) -> String:
	match a:
		"xray_figure":
			return "figure"
		"xray_heart":
			return "heart"
	return "bag"


func _on_monitor() -> void:
	monitor_on = not monitor_on
	screen.powered = monitor_on
	screen_mat.emission_energy_multiplier = 1.4 if monitor_on else 0.0
	act("monitor_off" if not monitor_on else "monitor_on", id)


func _on_estop() -> void:
	act("estop", id)
	_tray_target = _tray_t
	running = false
	_belt.stop()
	Snd.play_at("ui_alert", focus_position(), -6.0, 0.8, 6.0)
	changed.emit()


func _on_power_lost() -> void:
	screen.powered = false
	screen_mat.emission_energy_multiplier = 0.0


func _on_power_restored() -> void:
	screen.powered = monitor_on
	screen_mat.emission_energy_multiplier = 1.4 if monitor_on else 0.0


func _apply_anomaly(a: String) -> void:
	if scanned:
		screen.content = _content_for(a)


func _remove_anomaly(_a: String) -> void:
	_stare_time = 0.0
	screen.stare = 0.0
	if scanned:
		screen.content = "bag"


func is_observable() -> bool:
	return powered and scanned and monitor_on


func describe_state() -> String:
	if not powered:
		return "전원 차단"
	if not monitor_on:
		return "모니터 꺼짐"
	return "판독 화면 표시" if scanned else "대기"
