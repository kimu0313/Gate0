extends Control
## Title screen over a slow drifting shot of the empty terminal at night: a GATE [0] sign that
## flickers on, departure-board menu rows, a test-mode FIDS where FLIGHT 000 keeps boarding.

var _world: Node3D
var _cam: Camera3D
var _t := 0.0
var _main: Control
var _title_box: HBoxContainer
var _rows: Array = []
var _chapter_rows: Array = []
var _fids: Control
var _foot: HBoxContainer
var _name_panel: Control
var _chapter_panel: PanelContainer
var _settings: SettingsPanel
var _name_edit: LineEdit
var _fids_board: FidsBoard
var _intro_started := false
var _hold_intro := false
static var _boot_shown := false    # the launch notice shows once per run, not on every return to the menu


func _ready() -> void:
	UiKit.full_rect(self)
	theme = UiKit.theme()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	_build_backdrop()
	_build_ui()
	_build_settings()
	Snd.set_ambience("amb_night_loop", -6.0, 2.0)
	Snd.set_music("menu_music_loop", -10.0, 3.0)
	var args := OS.get_cmdline_user_args()
	if not _boot_shown and not (args.has("--uigallery") or args.has("--skip-boot")):
		_boot_shown = true
		_hold_intro = true
		var notice := BootNotice.new()
		add_child(notice)
		notice.done.connect(func():
			_hold_intro = false
			_t = 0.2)
	if args.has("--uigallery"):
		var g = load("res://scripts/debug/ui_gallery.gd").new()
		g.menu = self
		add_child(g)
	if args.has("--settingstest") and not get_tree().root.has_node("SettingsTest"):
		var st = load("res://scripts/debug/settings_test.gd").new()
		st.name = "SettingsTest"
		get_tree().root.add_child.call_deferred(st)


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
	t.shutters.baggage.open(true)
	t.shutters.security.open(true)
	t.shutters.corridor.open(true)
	t.shutters.gates.open(true)
	_fids_board = t.facility("fids")
	_fids_board.ghost_row(true)
	(t.facility("walkway") as MovingWalkway).start(false)
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_world.add_child(_cam)
	_cam.current = true
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.3)
	UiKit.full_rect(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var grad := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.95), Color(0, 0, 0, 0.72), Color(0, 0, 0, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	grad.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grad.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	grad.offset_right = 1200
	grad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(grad)


func _process(delta: float) -> void:
	_t += delta
	# start the intro once the first-frame shader compile hitch is over, so it is actually seen
	if not _intro_started and not _hold_intro and ((_t > 0.15 and delta < 0.05) or _t > 6.0):
		_intro_started = true
		_intro()
	# the sign's tube stutters now and then, like a lightbox on a failing ballast
	elif _intro_started and _t > 3.5 and randf() < delta * 0.25 and not Game.settings.reduce_motion:
		var tw := _title_box.create_tween()
		for a in [0.55, 1.0, 0.7, 1.0]:
			tw.tween_property(_title_box, "modulate:a", a, randf_range(0.03, 0.07))
		Snd.play("flicker_zap", -30.0, randf_range(1.2, 1.4))
	var z := -30.0 - fmod(_t * 0.9, 40.0)
	_cam.position = Vector3(1.6 + sin(_t * 0.13) * 0.3, 1.6 + sin(_t * 0.21) * 0.04, z)
	_cam.rotation = Vector3(-0.02 + sin(_t * 0.17) * 0.015, 0.08 + sin(_t * 0.07) * 0.06, 0.0)


# =========================================================================================
# main
# =========================================================================================
func _build_ui() -> void:
	_main = Control.new()
	UiKit.full_rect(_main)
	_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_main)
	var col := VBoxContainer.new()
	col.position = Vector2(140, 150)
	col.add_theme_constant_override("separation", 18)
	_main.add_child(col)
	_title_box = HBoxContainer.new()
	_title_box.add_theme_constant_override("separation", 0)
	col.add_child(_title_box)
	_title_box.add_child(TitleLogo.new())
	_build_menu_rows(col)


func _build_menu_rows(col: VBoxContainer) -> void:
	var space := Control.new()
	space.custom_minimum_size = Vector2(0, 40)
	col.add_child(space)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	col.add_child(list)
	var idx := 1
	var items := [["새 근무 시작", _on_new, ""]]
	if Game.has_save():
		items.append(["이어하기", func(): Game.continue_game(), _save_meta()])
	items.append_array([["챕터 선택", _on_chapters, ""], ["설정", _on_settings, ""], ["크레딧", _on_credits, ""],
		["종료", func(): get_tree().quit(), ""]])
	for it in items:
		var row := SignRow.make("%02d" % idx, it[0], it[1], it[2], UiKit.SIGNAL if it[0] != "종료" else UiKit.ALERT)
		list.add_child(row)
		_rows.append(row)
		idx += 1
	SignRow.link(_rows)
	_fids = FidsMini.new()
	_fids.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_fids.offset_left = -760
	_fids.offset_right = -110
	_fids.offset_top = 110
	_fids.offset_bottom = 420
	_main.add_child(_fids)
	_foot = HBoxContainer.new()
	_foot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_foot.offset_left = 140
	_foot.offset_right = -110
	_foot.offset_top = -86
	_foot.offset_bottom = -46
	_foot.add_theme_constant_override("separation", 22)
	_main.add_child(_foot)
	_foot.add_child(UiKit.label("1인칭 리미널 호러", 16, UiKit.TEXT_DIM))
	_foot.add_child(UiKit.label(UiKit.t("엔딩 %d / 3") % Game.endings_seen().size(), 16, UiKit.TEXT_DIM))
	_foot.add_child(UiKit.spacer())
	var hp := UiIcon.make("headphones", 22, UiKit.TEXT_DIM)
	hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_foot.add_child(hp)
	_foot.add_child(UiKit.label("헤드폰 착용을 권장합니다", 16, UiKit.TEXT_DIM))
	_build_name_panel()
	_build_chapter_panel()
	for c in [_title_box, _fids, _foot] + _rows:
		(c as CanvasItem).modulate.a = 0.0


func _build_settings() -> void:
	_settings = SettingsPanel.new()
	_settings.visible = false
	UiKit.center(_settings, Vector2(980, 820))
	add_child(_settings)
	_settings.back.connect(func():
		_settings.visible = false
		_show_main())
	_settings.language_changed.connect(_relocalize)


## The language was switched in the settings: the menu's own UI is rebuilt in the new language where it
## stands. The 3D backdrop keeps drifting and the open settings panel stays on the same tab (it rebuilds
## itself) — no scene reload, so nothing jumps.
func _relocalize() -> void:
	theme = UiKit.theme()
	for n in [_main, _name_panel, _chapter_panel]:
		if is_instance_valid(n):
			n.queue_free()
	_rows.clear()
	_chapter_rows.clear()
	_build_ui()
	move_child(_settings, -1)   # keep the open panel above the rebuilt menu
	_main.visible = false
	if _intro_started:
		for c in [_title_box, _fids, _foot] + _rows:
			(c as CanvasItem).modulate.a = 1.0


func _intro() -> void:
	UiFx.flicker_on(_title_box, 0.35)
	_fids.modulate.a = 0.0
	UiFx.fade(_fids, 1.0, 1.0, 0.7)
	_foot.modulate.a = 0.0
	UiFx.fade(_foot, 1.0, 0.8, 1.6)
	UiFx.stagger_slide(_rows, Vector2(-30, 0), 0.06, 0.3, 1.15)
	get_tree().create_timer(1.9).timeout.connect(func():
		if _main.visible and not _rows.any(func(r): return r.lit):
			SignRow.select_first(_rows))


func _show_main() -> void:
	_main.visible = true
	UiFx.stagger_slide(_rows, Vector2(-24, 0), 0.04, 0.22)


## Keyboard / d-pad: arrows move the highlighted row, Enter picks it, Esc backs out of a sub-panel.
func _unhandled_input(event: InputEvent) -> void:
	if _chapter_panel.visible:
		if event.is_action_pressed("ui_cancel"):
			_chapter_panel.visible = false
			_show_main()
		elif not SignRow.navigate(_chapter_rows, event):
			return
	elif _main.visible and _intro_started:
		if not SignRow.navigate(_rows, event):
			return
	elif _name_panel.visible and event.is_action_pressed("ui_cancel"):
		_name_panel.visible = false
		_show_main()
	else:
		return
	get_viewport().set_input_as_handled()


func _save_meta() -> String:
	var f := FileAccess.open(Game.SAVE_PATH, FileAccess.READ)
	if f == null:
		return ""
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return ""
	return "DAY %d · 00:00" % clampi(int(data.get("cycle", 1)), 1, Game.MAX_CYCLE)


# =========================================================================================
# staff registration (generated ID card art)
# =========================================================================================
func _build_name_panel() -> void:
	_name_panel = Control.new()
	UiKit.center(_name_panel, Vector2(960, 800))
	_name_panel.visible = false
	add_child(_name_panel)
	var card := Control.new()
	card.size = Vector2(960, 640)
	card.draw.connect(func():
		var tex := UiArt.tex("staff_card")
		if tex:
			card.draw_texture_rect(tex, Rect2(Vector2.ZERO, card.size), false)
		else:
			card.draw_style_box(UiKit.box(Color("f2f0ea"), Color(0, 0, 0, 0), 26, 0, 0), Rect2(40, 38, 882, 564))
			card.draw_rect(Rect2(40, 38, 882, 124), UiKit.NAVY)
			card.draw_rect(Rect2(40, 162, 882, 9), UiKit.SIGNAL)
			card.draw_rect(Rect2(72, 194, 248, 334), Color("a5a8ad")))
	_name_panel.add_child(card)
	var band := VBoxContainer.new()
	band.position = Vector2(80, 62)
	band.add_theme_constant_override("separation", 0)
	card.add_child(band)
	band.add_child(UiKit.caption("SEOHAE INT'L AIRPORT · FACILITY OPS", Color("c9d4ee"), 17))
	band.add_child(UiKit.label("STAFF REGISTRATION", 30, UiKit.NAVY_TEXT, "display", 700))
	var fields := VBoxContainer.new()
	fields.position = Vector2(356, 200)
	fields.size = Vector2(520, 360)
	fields.add_theme_constant_override("separation", 6)
	card.add_child(fields)
	for kv in [["소속 · DEPT", "서해국제공항 시설운영팀"], ["고용 · TYPE", "단기 계약직 (야간 시설 점검)"], ["사번 · ID", "2026-N-0417"]]:
		fields.add_child(UiKit.caption(kv[0], Color("6b7586"), 14))
		fields.add_child(UiKit.label(kv[1], 21, UiKit.PAPER_INK, "sans", 700))
	var g2 := Control.new()
	g2.custom_minimum_size = Vector2(0, 6)
	fields.add_child(g2)
	fields.add_child(UiKit.caption("성명 · NAME", UiKit.STAMP_RED, 14))
	_name_edit = LineEdit.new()
	_name_edit.max_length = 8
	_name_edit.placeholder_text = UiKit.t("이름을 입력하십시오")
	_name_edit.add_theme_font_override("font", UiKit.font("sans", 900))
	_name_edit.add_theme_font_size_override("font_size", 34)
	_name_edit.add_theme_color_override("font_color", UiKit.PAPER_INK)
	_name_edit.add_theme_color_override("font_placeholder_color", Color("9a9a96"))
	_name_edit.add_theme_color_override("caret_color", UiKit.STAMP_RED)
	_name_edit.add_theme_color_override("selection_color", Color(UiKit.SIGNAL, 0.5))
	var ln := UiKit.boxm(Color(0, 0, 0, 0.04), Vector4(4, 4, 4, 6))
	ln.border_width_bottom = 3
	ln.border_color = UiKit.NAVY
	_name_edit.add_theme_stylebox_override("normal", ln)
	var lf := ln.duplicate() as StyleBoxFlat
	lf.border_color = UiKit.STAMP_RED
	_name_edit.add_theme_stylebox_override("focus", lf)
	_name_edit.custom_minimum_size = Vector2(480, 60)
	_name_edit.text_submitted.connect(func(_t): _confirm_name())
	fields.add_child(_name_edit)
	var row := HBoxContainer.new()
	row.position = Vector2(40, 668)
	row.add_theme_constant_override("separation", 14)
	_name_panel.add_child(row)
	var ok := UiKit.primary("근무 시작", 22, _confirm_name)
	ok.custom_minimum_size = Vector2(240, 62)
	row.add_child(ok)
	var cancel := UiKit.button("취소", 20, func():
		_name_panel.visible = false
		_show_main())
	cancel.custom_minimum_size = Vector2(150, 62)
	row.add_child(cancel)
	var note := UiKit.label("※ 이 이름은 근무 기록과 안내방송에 쓰입니다.", 17, UiKit.TEXT_DIM)
	note.position = Vector2(44, 748)
	_name_panel.add_child(note)


# =========================================================================================
# chapters
# =========================================================================================
func _build_chapter_panel() -> void:
	_chapter_panel = PanelContainer.new()
	_chapter_panel.add_theme_stylebox_override("panel", UiKit.sign_panel())
	UiKit.center(_chapter_panel, Vector2(960, 594))
	_chapter_panel.visible = false
	add_child(_chapter_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_chapter_panel.add_child(v)
	v.add_child(UiKit.caption("CHAPTER SELECT", UiKit.SIGNAL_TEXT, 17))
	v.add_child(UiKit.label("챕터 선택", 34, UiKit.TEXT, "sans", 900))
	var d := UiKit.label("선택한 근무부터 다시 시작합니다. 이전 근무의 사진과 단서는 넘어가지 않습니다.", 17, UiKit.TEXT_DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(880, 0)
	v.add_child(d)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	v.add_child(gap)
	var items := [
		[1, "night", "D1", "DAY 1 — 첫 근무 · 또 새로 오신 분"],
		[2, "night", "D2", "DAY 2 — 수하물 수취대 · 1987년의 비행기표"],
		[3, "night", "D3", "DAY 3 — 보안검색 · A0 / 87.11.03"],
		[4, "night", "D4", "DAY 4 — 탑승동 · 젖은 물건들"],
		[5, "night", "D5", "DAY 5 — 개장일 · GATE 0"],
	]
	var grid := GridContainer.new()
	grid.columns = 1
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for it in items:
		var r := SignRow.make(it[2], it[3], _start_chapter.bind(it[0], it[1]), "00:00", UiKit.SIGNAL, 880, 56)
		r.font_size = 20
		grid.add_child(r)
		_chapter_rows.append(r)
	SignRow.link(_chapter_rows)
	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 10)
	v.add_child(gap2)
	var back := UiKit.button("돌아가기", 20, func():
		_chapter_panel.visible = false
		_show_main())
	back.custom_minimum_size = Vector2(200, 54)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(back)


func _on_new() -> void:
	_main.visible = false
	_name_panel.visible = true
	_name_panel.pivot_offset = _name_panel.size * 0.5
	UiFx.pop_in(_name_panel, 0.3, 0.92)
	_name_panel.rotation = deg_to_rad(-2.0)
	_name_panel.create_tween().tween_property(_name_panel, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Snd.play("card_beep", -10.0)
	_name_edit.grab_focus()


func _confirm_name() -> void:
	var n := _name_edit.text.strip_edges()
	if n == "":
		n = "점검원"
	Snd.play("card_beep", -4.0)
	Snd.set_music("", 2.0)
	Game.start_new_game(n)


func _on_chapters() -> void:
	_main.visible = false
	_chapter_panel.visible = true
	UiFx.pop_in(_chapter_panel, 0.24, 0.96)
	SignRow.select_first(_chapter_rows)


func _on_credits() -> void:
	_main.visible = false
	var cv := CreditsView.new()
	add_child(cv)
	cv.closed.connect(_show_main)


func _on_settings() -> void:
	_main.visible = false
	_settings.visible = true
	UiFx.pop_in(_settings, 0.24, 0.96)


func _start_chapter(cycle: int, phase: String) -> void:
	Snd.set_music("", 2.0)
	var n := _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "점검원"
	Game.reset_session()
	Game.player_name = n
	Game.prepare_chapter(cycle, phase)
	Game._prepare_name_voice()
	Game.start_phase(cycle, phase)


# =========================================================================================
# test-mode departure board where FLIGHT 000 keeps boarding
# =========================================================================================
class FidsMini extends Control:
	const ROWS := [["SH 101", "BUSAN", "03", "TEST"], ["SH 214", "JEJU", "02", "TEST"], ["SH 330", "OSAKA", "04", "TEST"],
		["SH 452", "TAIPEI", "01", "TEST"], ["SH 517", "FUKUOKA", "05", "TEST"], ["000", "———", "0", "BOARDING"]]
	const AMBER := Color("7aa6ff")   # the board's LED lettering (signal blue)
	var _t := 0.0
	var _scramble := {}
	var _next := 2.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		_next -= delta
		if _next <= 0.0:
			_next = randf_range(2.5, 5.5)
			_scramble[randi() % ROWS.size()] = 0.45
		for k in _scramble.keys():
			_scramble[k] -= delta
			if _scramble[k] <= 0.0:
				_scramble.erase(k)
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.016, 0.02, 0.027, 0.92))
		draw_rect(r, Color("1a2028"), false, 8.0)
		var disp := UiKit.font("display", 700)
		var mono := UiKit.font("display", 400)
		var monob := UiKit.font("display", 700)
		draw_string(disp, Vector2(28, 46), UiKit.t("DEPARTURES · 출발"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, AMBER)
		draw_string(disp, Vector2(28, 46), "TEST MODE", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 56, 22, AMBER)
		draw_line(Vector2(28, 60), Vector2(size.x - 28, 60), Color(AMBER, 0.25), 1.0)
		var cols := [28.0, 160.0, size.x - 230.0, size.x - 150.0]
		for i in ROWS.size():
			var row: Array = ROWS[i]
			var y := 98.0 + i * 36.0
			var last := i == ROWS.size() - 1
			var col := Color(AMBER, 0.82)
			var f := mono
			if last:
				var blink := 0.6 + 0.4 * sin(_t * 5.0)
				col = Color(UiKit.ALERT, blink)
				f = monob
				draw_rect(Rect2(20, y - 25, size.x - 40, 34), Color(UiKit.ALERT, 0.08))
			for c in row.size():
				var txt: String = row[c]
				if _scramble.has(i):
					var s := ""
					for ch in txt:
						s += FlapLabel._glyph_like(ch)
					txt = s
				draw_string(f, Vector2(cols[c], y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)
