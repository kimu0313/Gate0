extends Control
## Title screen over a slow drifting shot of the empty terminal at night.

var _world: Node3D
var _cam: Camera3D
var _t := 0.0
var _main: VBoxContainer
var _name_panel: PanelContainer
var _chapter_panel: PanelContainer
var _settings: SettingsPanel
var _name_edit: LineEdit
var _fids: FidsBoard


func _ready() -> void:
	UiKit.full_rect(self)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	_build_backdrop()
	_build_ui()
	Snd.set_ambience("amb_night_loop", -6.0, 2.0)
	Snd.set_music("menu_music_loop", -10.0, 3.0)


func _build_backdrop() -> void:
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	UiKit.full_rect(vpc)
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vpc)
	var vp := SubViewport.new()
	vp.size = Vector2i(1920, 1080)
	vp.msaa_3d = Viewport.MSAA_2X
	vpc.add_child(vp)
	_world = Node3D.new()
	vp.add_child(_world)
	var atm := Atmosphere.new()
	_world.add_child(atm)
	atm.setup("night")
	var t := Terminal.new()
	_world.add_child(t)
	t.build()
	for zn in t.zones.keys():
		t.set_zone_light(zn, zn in ["corridor", "gates", "hall"], true)
	t.shutters.security.open(true)
	t.shutters.corridor.open(true)
	t.shutters.gates.open(true)
	_fids = t.facility("fids")
	_fids.ghost_row(true)
	(t.facility("walkway") as MovingWalkway).start(false)
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_world.add_child(_cam)
	_cam.current = true
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	UiKit.full_rect(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var grad := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.92))
	g.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	grad.offset_right = 1100
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grad)


func _process(delta: float) -> void:
	_t += delta
	var z := -30.0 - fmod(_t * 0.9, 40.0)
	_cam.position = Vector3(1.6 + sin(_t * 0.13) * 0.3, 1.6 + sin(_t * 0.21) * 0.04, z)
	_cam.rotation = Vector3(-0.02 + sin(_t * 0.17) * 0.015, 0.08 + sin(_t * 0.07) * 0.06, 0.0)


func _build_ui() -> void:
	_main = VBoxContainer.new()
	_main.position = Vector2(140, 250)
	_main.custom_minimum_size = Vector2(620, 0)
	_main.add_theme_constant_override("separation", 12)
	add_child(_main)
	var title := UiKit.label("GATE 0", 150, UiKit.C_ACCENT, "mono", 700)
	_main.add_child(title)
	var tag := UiKit.label("승객은 아무도 없는데, 탑승 안내 방송이 울립니다.", 26, Color(0.85, 0.87, 0.92), "sans", 300)
	_main.add_child(tag)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	_main.add_child(spacer)
	_menu_button("새 근무 시작", _on_new)
	if Game.has_save():
		_menu_button("이어하기", func(): Game.continue_game())
	_menu_button("챕터 선택", _on_chapters)
	_menu_button("설정", _on_settings)
	_menu_button("종료", func(): get_tree().quit())
	var seen := Game.endings_seen()
	var foot := UiKit.label("PROTOTYPE  ·  1인칭 리미널 호러  ·  엔딩 %d / 3  ·  헤드폰 착용을 권장합니다" % seen.size(), 17, UiKit.C_DIM)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot.offset_left = 140
	foot.offset_top = -70
	foot.offset_bottom = -40
	foot.offset_right = 1400
	add_child(foot)
	_build_name_panel()
	_build_chapter_panel()
	_settings = SettingsPanel.new()
	_settings.visible = false
	UiKit.center(_settings, Vector2(820, 700))
	add_child(_settings)
	_settings.back.connect(func():
		_settings.visible = false
		_main.visible = true)


func _menu_button(text: String, cb: Callable) -> void:
	var b := UiKit.button(text, 26, cb)
	b.custom_minimum_size = Vector2(380, 62)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_main.add_child(b)


func _build_name_panel() -> void:
	_name_panel = PanelContainer.new()
	_name_panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.04, 0.05, 0.07, 0.97), UiKit.C_LINE, 10, 1, 36))
	UiKit.center(_name_panel, Vector2(720, 420))
	_name_panel.visible = false
	add_child(_name_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	_name_panel.add_child(v)
	v.add_child(UiKit.label("시설 점검원 등록", 32, UiKit.C_TEXT, "sans", 700))
	v.add_child(UiKit.label("서해국제공항 시설운영팀 · 단기 계약직 (야간)", 18, UiKit.C_DIM))
	v.add_child(UiKit.label("이름을 입력하십시오.", 20, UiKit.C_TEXT))
	_name_edit = LineEdit.new()
	_name_edit.max_length = 8
	_name_edit.placeholder_text = "예: 김훈철"
	_name_edit.add_theme_font_override("font", UiKit.font("sans", 600))
	_name_edit.add_theme_font_size_override("font_size", 30)
	_name_edit.custom_minimum_size = Vector2(0, 64)
	_name_edit.text_submitted.connect(func(_t): _confirm_name())
	v.add_child(_name_edit)
	v.add_child(UiKit.label("※ 이 이름은 게임 속에서 쓰입니다. (Windows에서는 음성으로도)", 16, UiKit.C_DIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var ok := UiKit.button("근무 시작", 24, _confirm_name, UiKit.C_ACCENT)
	ok.custom_minimum_size = Vector2(240, 60)
	row.add_child(ok)
	row.add_child(UiKit.button("취소", 22, func():
		_name_panel.visible = false
		_main.visible = true))


func _build_chapter_panel() -> void:
	_chapter_panel = PanelContainer.new()
	_chapter_panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.04, 0.05, 0.07, 0.97), UiKit.C_LINE, 10, 1, 36))
	UiKit.center(_chapter_panel, Vector2(760, 640))
	_chapter_panel.visible = false
	add_child(_chapter_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_chapter_panel.add_child(v)
	v.add_child(UiKit.label("챕터 선택", 32, UiKit.C_TEXT, "sans", 700))
	v.add_child(UiKit.label("프로토타입 검토용. 선택한 근무부터 시작합니다 (사진·단서 없이).", 17, UiKit.C_DIM))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	var items := [
		[1, "day", "DAY 1 — 정상 기록"], [1, "night", "NIGHT 1 — 수동 점검"],
		[2, "day", "DAY 2 — 구역 확장"], [2, "night", "NIGHT 2 — 자율 가동"],
		[3, "day", "DAY 3 — 어긋난 낮"], [3, "night", "NIGHT 3 — 0번 게이트"],
	]
	for it in items:
		var b := UiKit.button(it[2], 21, _start_chapter.bind(it[0], it[1]))
		b.custom_minimum_size = Vector2(330, 64)
		grid.add_child(b)
	var back := UiKit.button("돌아가기", 22, func():
		_chapter_panel.visible = false
		_main.visible = true)
	back.custom_minimum_size = Vector2(220, 56)
	v.add_child(back)


func _on_new() -> void:
	_main.visible = false
	_name_panel.visible = true
	_name_edit.grab_focus()


func _confirm_name() -> void:
	var n := _name_edit.text.strip_edges()
	if n == "":
		n = "점검원"
	Snd.set_music("", 2.0)
	Game.start_new_game(n)


func _on_chapters() -> void:
	_main.visible = false
	_chapter_panel.visible = true


func _on_settings() -> void:
	_main.visible = false
	_settings.visible = true


func _start_chapter(cycle: int, phase: String) -> void:
	Snd.set_music("", 2.0)
	var n := _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "점검원"
	Game.reset_session()
	Game.player_name = n
	Game.prepare_chapter(cycle, phase)
	Game._prepare_name_voice()
	Game.start_phase(cycle, phase)
