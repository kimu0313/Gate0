extends Node3D
## Ending cinematics. Game.ending_id: board | exit | announce

var _cam: Camera3D
var _layer: CanvasLayer
var _fade: ColorRect
var _title: Label
var _lines: Label
var _env: Environment
var _skip := false


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	_cam.fov = 60.0
	_layer = CanvasLayer.new()
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	UiKit.full_rect(_fade)
	_layer.add_child(_fade)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 22)
	UiKit.full_rect(v)
	_layer.add_child(v)
	_title = UiKit.label("", 110, Color(0.95, 0.95, 0.95), "mono", 700)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_lines = UiKit.label("", 28, Color(0.85, 0.86, 0.9), "sans", 300)
	_lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lines)
	match Game.ending_id:
		"board":
			_board()
		"exit":
			_exit()
		_:
			_announce()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_skip = true


func _wait(t: float) -> void:
	var e := 0.0
	while e < t and not _skip:
		await get_tree().process_frame
		e += get_process_delta_time()


func _fade_to(a: float, t: float) -> void:
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", a, t)
	await tw.finished


func _env_setup(bg: Color, ambient: Color, energy: float, fog := 0.0) -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = bg
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = ambient
	_env.ambient_light_energy = energy
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	_env.glow_enabled = true
	_env.glow_intensity = 0.6
	if fog > 0.0:
		_env.volumetric_fog_enabled = true
		_env.volumetric_fog_density = fog
	we.environment = _env
	add_child(we)


func _text(title: String, lines: String) -> void:
	_title.text = title
	_lines.text = lines
	_title.modulate.a = 0.0
	_lines.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_title, "modulate:a", 1.0, 1.5)
	tw.tween_property(_lines, "modulate:a", 1.0, 1.5)


# --- A: BOARD -------------------------------------------------------------------------------
func _board() -> void:
	_env_setup(Color(0, 0, 0), Color(0.3, 0.25, 0.2), 0.2, 0.03)
	var carpet := Mats.get_mat("carpet_red")
	for i in 14:
		var z := -i * 4.0
		Geo.box(self, Vector3(0, -0.05, z), Vector3(2.6, 0.1, 4.0), carpet, false)
		Geo.box(self, Vector3(0, 2.75, z), Vector3(2.6, 0.1, 4.0), Mats.get_mat("ceiling_dark"), false)
		for sx in [-1.35, 1.35]:
			Geo.box(self, Vector3(sx, 1.35, z), Vector3(0.1, 2.7, 4.0), Mats.get_mat("wall_service"), false)
		if i % 2 == 0:
			var l := Geo.omni(self, Vector3(0, 2.4, z), Color(1.0, 0.85, 0.6), 0.6, 4.5)
			l.light_volumetric_fog_energy = 2.0
	# the door at the end opens onto a warm home entrance
	var door := Geo.box(self, Vector3(0, 1.1, -54.0), Vector3(1.0, 2.2, 0.08), Mats.std(Color(0.3, 0.22, 0.15), 0.6), false)
	var home_light := Geo.omni(self, Vector3(0, 2.0, -56.5), Color(1.0, 0.75, 0.45), 0.0, 8.0)
	Geo.box(self, Vector3(0, -0.05, -57.5), Vector3(3.0, 0.1, 6.0), Mats.get_mat("wood"), false)
	Geo.box(self, Vector3(-1.2, 0.4, -57.0), Vector3(0.5, 0.8, 1.6), Mats.get_mat("wood"), false)
	for i in 3:
		Geo.box(self, Vector3(-1.2, 0.86, -56.6 - i * 0.4), Vector3(0.25, 0.1, 0.3), Mats.std(Color(0.1, 0.1, 0.12), 0.6), false)
	Geo.box(self, Vector3(0, 1.4, -60.3), Vector3(3.0, 2.8, 0.1), Mats.get_mat("wall_office"), false)
	_cam.position = Vector3(0, 1.6, 2.0)
	await _fade_to(0.0, 2.0)
	var tw := create_tween()
	tw.tween_property(_cam, "position:z", -51.5, 26.0).set_trans(Tween.TRANS_LINEAR)
	Snd.set_ambience("wind_loop", -14.0, 3.0)
	await _wait(25.0)
	var dt := create_tween()
	dt.tween_property(door, "position:x", -1.0, 1.6)
	dt.parallel().tween_property(home_light, "light_energy", 2.5, 2.0)
	Snd.play("door_heavy", -4.0, 0.9, "SFX")
	await _wait(3.0)
	await _fade_to(1.0, 2.0)
	Snd.set_ambience("", 1.0, 2.0)
	Snd.play("door_heavy", -2.0, 0.7, "SFX")
	await _wait(2.0)
	await Snd.pa_announce(["pa_arrived_ko"], {"subs": [], "no_end": true})
	_text("ARRIVED", "목적지: 집\n\n문이 닫혔다.\n정말 집으로 돌아온 걸까.")
	Snd.play("ending_tone", -6.0, 1.0, "Music")
	await _wait(9.0)
	_credits("엔딩 A — 탑승")


# --- B: EXIT ----------------------------------------------------------------------------------
func _exit() -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.45, 0.6, 0.85)
	psm.sky_horizon_color = Color(0.95, 0.82, 0.7)
	sky.sky_material = psm
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 0.8
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	_env.glow_enabled = true
	_env.volumetric_fog_enabled = true
	_env.volumetric_fog_density = 0.006
	we.environment = _env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-14), deg_to_rad(30), 0)
	sun.light_color = Color(1.0, 0.8, 0.6)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	add_child(sun)
	# terminal facade
	Geo.box(self, Vector3(0, -0.1, 20), Vector3(300, 0.2, 200), Mats.get_mat("concrete"), false)
	Geo.box(self, Vector3(0, 6, -10), Vector3(60, 12, 0.3), Mats.get_mat("glass"), false)
	Geo.box(self, Vector3(0, 12.3, -10), Vector3(62, 0.6, 3), Mats.get_mat("plane_body"), false)
	for i in 21:
		Geo.box(self, Vector3(-30 + i * 3, 6, -10), Vector3(0.18, 12, 0.3), Mats.get_mat("steel_frame"), false)
	Geo.box(self, Vector3(0, 6, -16), Vector3(60, 12, 0.3), Mats.get_mat("wall"), false)
	var banner := Node3D.new()
	add_child(banner)
	banner.position = Vector3(0, 9.6, -9.7)
	Geo.box(banner, Vector3.ZERO, Vector3(20, 2.2, 0.05), Mats.std(Color(0.08, 0.2, 0.45), 0.8), false)
	Geo.label(banner, "GRAND OPENING — TODAY", Vector3(0, 0.35, 0.04), 0.0, 120, Color(1, 1, 1), 0.012)
	Geo.label(banner, "서해국제공항 오늘 정식 개장", Vector3(0, -0.55, 0.04), 0.0, 80, Color(1.0, 0.85, 0.3), 0.012)
	# FIDS seen through the glass
	var fids := FidsBoard.new()
	add_child(fids)
	fids.position = Vector3(3, 4.5, -14)
	fids.build(6.0, 2.4, false)
	fids.set_story("final", ["FLIGHT 000", "BOARDING"])
	# people walking in
	var people: Array[Node3D] = []
	for i in 14:
		var pn := Props.figure(self, Vector3(randf_range(-14, 14), 0, randf_range(8, 30)), PI, false)
		var col := Mats.std(Color(randf_range(0.2, 0.7), randf_range(0.2, 0.6), randf_range(0.2, 0.6)), 0.8)
		for c in pn.get_children():
			if c is MeshInstance3D:
				c.material_override = col
		people.append(pn)
	_cam.position = Vector3(0, 1.7, 26)
	_cam.rotation = Vector3(0.05, 0, 0)
	Snd.set_ambience("amb_day_loop", -2.0, 2.0)
	await _fade_to(0.0, 3.0)
	for pn in people:
		var tw := create_tween()
		tw.tween_property(pn, "position:z", -9.0, randf_range(14.0, 24.0))
	_text("EXIT", "")
	await _wait(3.0)
	create_tween().tween_property(_title, "modulate:a", 0.0, 1.5)
	Snd.pa_announce(["pa_grand_opening_ko"], {"subs": [], "no_end": true})
	var ct := create_tween()
	ct.tween_property(_cam, "position", Vector3(2.0, 3.5, -4.0), 16.0).set_trans(Tween.TRANS_SINE)
	ct.parallel().tween_property(_cam, "rotation", Vector3(0.08, 0.0, 0.0), 16.0)
	await _wait(14.0)
	Snd.pa_announce(["pa_flight0_boarding_en"], {"subs": [], "no_end": true, "wrong": true})
	await _wait(5.0)
	await _fade_to(1.0, 0.2)
	_text("", "당신은 빠져나왔다.\n\n…아마도, 당신만.")
	Snd.play("ending_tone", -6.0, 0.9, "Music")
	await _wait(8.0)
	_credits("엔딩 B — 출구")


# --- C: ANNOUNCE --------------------------------------------------------------------------------
func _announce() -> void:
	_env_setup(Color(0, 0, 0), Color(0.08, 0.09, 0.12), 0.3, 0.02)
	Geo.box(self, Vector3(0, -0.05, 0), Vector3(60, 0.1, 60), Mats.get_mat("floor"), false)
	Geo.box(self, Vector3(0, 0.55, 0), Vector3(3.6, 1.1, 1.0), Mats.get_mat("counter_front"), false)
	var pa := PaConsole.new()
	add_child(pa)
	pa.position = Vector3(0, 1.14, 0.2)
	pa.build()
	var lamp := Geo.omni(self, Vector3(0.4, 1.8, 1.0), Color(1.0, 0.3, 0.2), 0.8, 5.0)
	lamp.light_volumetric_fog_energy = 2.0
	# a new night worker, far away, with a flashlight
	var worker := Node3D.new()
	add_child(worker)
	worker.position = Vector3(-14, 0, -24)
	var fl := Geo.spot(worker, Vector3(0, 1.5, 0), Vector3(4, 0.5, 10), Color(1.0, 0.92, 0.8), 3.0, 30.0, 25.0, true)
	fl.light_volumetric_fog_energy = 2.0
	_cam.position = Vector3(0.0, 1.55, 1.25)
	_cam.rotation = Vector3(-0.35, 0, 0)
	await _fade_to(0.0, 2.0)
	await _wait(1.5)
	var tw := create_tween()
	tw.tween_property(_cam, "rotation", Vector3(-0.05, 0.25, 0.0), 6.0).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(worker, "position", Vector3(-4, 0, -10), 16.0)
	await _wait(2.0)
	await Snd.pa_announce(["pa_next_worker_ko"], {"subs": [], "pitch": 0.9})
	await _wait(1.0)
	await Snd.pa_announce(["name_call"], {"subs": [], "pitch": 0.85, "no_end": true, "wrong": true})
	await _fade_to(1.0, 2.0)
	_text("ANNOUNCEMENT", "당신은 안내방송이 되었다.\n\n오늘 밤에도, 누군가 수칙을 펼친다.")
	Snd.play("ending_tone", -6.0, 0.8, "Music")
	await _wait(9.0)
	_credits("엔딩 C — 안내방송")


func _credits(ending_name: String) -> void:
	_skip = false
	var st := Game.stats
	var seen := Game.endings_seen()
	_title.text = "GATE 0"
	_title.modulate.a = 1.0
	_lines.text = "%s\n\n정확 판정 %d  ·  이상 해제 %d  ·  놓침 %d  ·  오판 %d  ·  사망 %d\n발견한 엔딩 %d / 3\n\n프로토타입 — 기획 김훈철 외 · Godot 4.7\n\n[Esc] 메인 메뉴" % [
		ending_name, int(st.get("correct", 0)), int(st.get("cleared", 0)), int(st.get("missed", 0)),
		int(st.get("false_alarm", 0)), int(st.get("deaths", 0)), seen.size()]
	_lines.modulate.a = 1.0
	if FileAccess.file_exists(Game.SAVE_PATH):
		DirAccess.remove_absolute(Game.SAVE_PATH)
	var args := OS.get_cmdline_user_args()
	var ai := args.find("--autotest")
	if ai >= 0:
		print("[ending] ", Game.ending_id, " credits shown")
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		if ai + 1 < args.size():
			get_viewport().get_texture().get_image().save_png("%s/ending_%s.png" % [args[ai + 1], Game.ending_id])
		get_tree().quit()
		return
	while not _skip:
		await get_tree().process_frame
	Snd.set_music("", 1.0)
	Game.go_menu()
