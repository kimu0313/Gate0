class_name GameUI
extends Node
## Owns every screen-space layer of a phase: post FX, HUD, modals (tablet, binder, documents,
## keypad, camera), pause/settings, fades & title cards, death and morning-report screens.

signal doc_closed
signal report_closed
signal keypad_closed

var player: Player
var director: ShiftDirector
var postfx: PostFx
var hud: Hud
var tablet: Tablet
var binder: BinderView
var keypad: KeypadView
var modal := ""

var _modal_layer: CanvasLayer
var _pause_layer: CanvasLayer
var _fade_layer: CanvasLayer
var _fade: ColorRect
var _fade_text: Label
var _fade_sub: Label
var _reader: Control
var _reader_paper: PaperPage
var _camera_overlay: Control
var _camera_info: Label
var _camera_target: Label
var _pause_menu: Control
var _settings: SettingsPanel
var _death: Control
var _keypad_cb: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	postfx = PostFx.new()
	add_child(postfx)
	hud = Hud.new()
	add_child(hud)
	_modal_layer = CanvasLayer.new()
	_modal_layer.layer = 10
	add_child(_modal_layer)
	tablet = Tablet.new()
	tablet.visible = false
	tablet.ui = self
	_modal_layer.add_child(tablet)
	tablet.closed.connect(close_modal)
	tablet.camera_requested.connect(_enter_camera)
	binder = BinderView.new()
	binder.visible = false
	_modal_layer.add_child(binder)
	binder.closed.connect(close_modal)
	keypad = KeypadView.new()
	keypad.visible = false
	_modal_layer.add_child(keypad)
	keypad.closed.connect(func():
		close_modal()
		keypad_closed.emit())
	keypad.submitted.connect(func(code):
		if _keypad_cb.is_valid():
			_keypad_cb.call(code))
	_build_reader()
	_build_camera_overlay()
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 20
	add_child(_pause_layer)
	_build_pause()
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 30
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(_fade)
	_fade_layer.add_child(_fade)
	var fv := VBoxContainer.new()
	fv.alignment = BoxContainer.ALIGNMENT_CENTER
	UiKit.full_rect(fv)
	fv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fv.add_theme_constant_override("separation", 18)
	_fade.add_child(fv)
	_fade_text = UiKit.label("", 54, Color(0.92, 0.92, 0.95), "sans", 300)
	_fade_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fv.add_child(_fade_text)
	_fade_sub = UiKit.label("", 24, UiKit.C_DIM, "sans", 400)
	_fade_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fv.add_child(_fade_sub)


func bind(p: Player, d: ShiftDirector) -> void:
	player = p
	director = d
	hud.player = p
	tablet.bind_world(d)
	p.interact_target_changed.connect(hud.set_prompt)


func _process(_delta: float) -> void:
	if player:
		postfx.eyes = player.eyes


# =========================================================================================
# input
# =========================================================================================
func _unhandled_input(event: InputEvent) -> void:
	if player == null or director == null or director.dead or director.ending_started:
		return
	if get_tree().paused:
		if event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			_resume()
		return
	if modal == "camera":
		if event.is_action_pressed("camera_shoot"):
			get_viewport().set_input_as_handled()
			_shoot()
		elif event.is_action_pressed("camera_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("tablet"):
			get_viewport().set_input_as_handled()
			_exit_camera()
		return
	if modal == "doc":
		if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			_close_reader()
		return
	if modal != "":
		return
	if not player.controls_enabled:
		return
	if event.is_action_pressed("tablet"):
		get_viewport().set_input_as_handled()
		open_tablet()
	elif event.is_action_pressed("binder"):
		get_viewport().set_input_as_handled()
		open_binder()
	elif event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_pause()


# =========================================================================================
# modals
# =========================================================================================
func _open_modal(name_text: String) -> void:
	modal = name_text
	Game.paused_by_ui = true
	player.controls_enabled = false
	player.look_enabled = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	hud.set_prompt("")


func close_modal() -> void:
	if modal == "":
		return
	match modal:
		"tablet":
			tablet.visible = false
			Snd.play("tablet_close", -6.0)
		"binder":
			binder.visible = false
			Snd.play("page_flip", -8.0, 0.8)
		"keypad":
			keypad.visible = false
	modal = ""
	Game.paused_by_ui = false
	if director and not director.dead:
		player.controls_enabled = true
		player.look_enabled = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func close_all() -> void:
	if modal == "camera":
		_exit_camera()
	elif modal == "doc":
		_close_reader()
	else:
		close_modal()
	if get_tree().paused:
		_resume()


func open_tablet() -> void:
	_open_modal("tablet")
	Snd.play("tablet_open", -6.0)
	tablet.open()


func open_binder(page_id := "") -> void:
	if Game.binder_pages.is_empty():
		Events.notify.emit("아직 근무 수칙 바인더를 받지 않았습니다.", "info")
		return
	_open_modal("binder")
	Snd.play("binder_open", -4.0)
	binder.visible = true
	binder.refresh(page_id)


func open_keypad(cb: Callable) -> void:
	_keypad_cb = cb
	_open_modal("keypad")
	keypad.visible = true
	keypad.reset()


# --- documents -----------------------------------------------------------------------------
func _build_reader() -> void:
	_reader = Control.new()
	UiKit.full_rect(_reader)
	_reader.visible = false
	_reader.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_layer.add_child(_reader)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	UiKit.full_rect(dim)
	_reader.add_child(dim)
	_reader_paper = PaperPage.new()
	UiKit.center(_reader_paper, Vector2(860, 940))
	_reader.add_child(_reader_paper)
	var hint := UiKit.label("[E] / [Esc] 닫기", 18, UiKit.C_DIM)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -48
	hint.offset_left = -100
	hint.offset_right = 100
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reader.add_child(hint)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close_reader())


## Shows a document and waits until the player closes it.
func read_doc(title: String, body: String, font_kind := "serif") -> void:
	_open_modal("doc")
	_reader_paper.show_page({"title": title, "body": body, "font": font_kind, "stamp": "none"}, true)
	_reader.visible = true
	Snd.play("page_flip", -4.0)
	await doc_closed


func _close_reader() -> void:
	_reader.visible = false
	close_modal()
	doc_closed.emit()


# --- camera ---------------------------------------------------------------------------------
func _build_camera_overlay() -> void:
	_camera_overlay = Control.new()
	UiKit.full_rect(_camera_overlay)
	_camera_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camera_overlay.visible = false
	_modal_layer.add_child(_camera_overlay)
	_camera_overlay.draw.connect(func():
		var s := _camera_overlay.size
		var m := 70.0
		var l := 70.0
		var c := Color(1, 1, 1, 0.85)
		for corner in [Vector2(m, m), Vector2(s.x - m, m), Vector2(m, s.y - m), Vector2(s.x - m, s.y - m)]:
			var dx := l if corner.x < s.x * 0.5 else -l
			var dy := l if corner.y < s.y * 0.5 else -l
			_camera_overlay.draw_line(corner, corner + Vector2(dx, 0), c, 3.0)
			_camera_overlay.draw_line(corner, corner + Vector2(0, dy), c, 3.0)
		_camera_overlay.draw_line(s * 0.5 - Vector2(20, 0), s * 0.5 + Vector2(20, 0), Color(1, 1, 1, 0.5), 1.5)
		_camera_overlay.draw_line(s * 0.5 - Vector2(0, 20), s * 0.5 + Vector2(0, 20), Color(1, 1, 1, 0.5), 1.5)
		if fmod(Time.get_ticks_msec() / 1000.0, 1.0) < 0.6:
			_camera_overlay.draw_circle(Vector2(m + 30, m + 40), 9, Color(1, 0.15, 0.1)))
	_camera_info = UiKit.label("", 22, Color(1, 1, 1, 0.9), "mono", 700)
	_camera_info.position = Vector2(130, 92)
	_camera_overlay.add_child(_camera_info)
	_camera_target = UiKit.label("", 24, UiKit.C_ACCENT, "sans", 700)
	_camera_target.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_camera_target.offset_top = -150
	_camera_target.offset_bottom = -110
	_camera_target.offset_left = -500
	_camera_target.offset_right = 500
	_camera_target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_camera_overlay.add_child(_camera_target)
	var hint := UiKit.label("[LMB] 촬영    [RMB] 카메라 종료", 20, Color(1, 1, 1, 0.8))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -100
	hint.offset_bottom = -70
	hint.offset_left = -300
	hint.offset_right = 300
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_camera_overlay.add_child(hint)
	var timer := Timer.new()
	timer.wait_time = 0.15
	timer.autostart = true
	timer.timeout.connect(func():
		if _camera_overlay.visible:
			_camera_overlay.queue_redraw()
			var fac := director.facility_in_view() if director else null
			_camera_target.text = ("인식: " + fac.title) if fac else ""
			_camera_info.text = "REC   남은 촬영 %d/%d" % [Game.photos_left, Game.PHOTOS_PER_DAY])
	_camera_overlay.add_child(timer)


func _enter_camera() -> void:
	tablet.visible = false
	modal = "camera"
	Game.paused_by_ui = false
	player.controls_enabled = true
	player.look_enabled = true
	player.camera_mode = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_camera_overlay.visible = true
	hud.visible = false
	Snd.play("button_press", -8.0, 1.4)


func _exit_camera() -> void:
	_camera_overlay.visible = false
	hud.visible = true
	player.camera_mode = false
	modal = ""
	Snd.play("button_press", -8.0, 1.1)


func _shoot() -> void:
	if Game.photos_left <= 0:
		Events.notify.emit("오늘 촬영 가능한 장수를 모두 사용했습니다.", "bad")
		Snd.play("beep_error", -6.0)
		return
	var fac := director.facility_in_view()
	_camera_overlay.visible = false
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	_camera_overlay.visible = modal == "camera"
	img.resize(960, 540, Image.INTERPOLATE_BILINEAR)
	var label := "%s · DAY %d %s" % [fac.title if fac else "기타", Game.cycle, Game.clock_text()]
	Game.photos.append({"image": img, "tex": ImageTexture.create_from_image(img), "label": label,
		"cycle": Game.cycle, "altered": false, "facility": fac.id if fac else ""})
	Game.photos_left -= 1
	Game.stat("photos")
	Snd.play("camera_shutter", -2.0)
	postfx.flash(0.7)
	Events.photo_taken.emit(Game.photos.size() - 1)
	Events.player_action.emit("photo", fac.id if fac else "")
	Events.notify.emit("사진 저장: " + label, "good")


# =========================================================================================
# pause
# =========================================================================================
func _build_pause() -> void:
	_pause_menu = Control.new()
	UiKit.full_rect(_pause_menu)
	_pause_menu.visible = false
	_pause_layer.add_child(_pause_menu)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	UiKit.full_rect(dim)
	_pause_menu.add_child(dim)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	UiKit.center(v, Vector2(440, 520))
	_pause_menu.add_child(v)
	v.add_child(UiKit.label("일시정지", 40, UiKit.C_TEXT, "sans", 300))
	for item in [["계속하기", _resume], ["설정", _open_settings], ["이 근무 다시 시작", func(): Game.restart_phase()],
			["메인 메뉴로", func(): Game.go_menu()], ["게임 종료", func(): get_tree().quit()]]:
		var b := UiKit.button(item[0], 22, item[1])
		b.custom_minimum_size = Vector2(440, 58)
		v.add_child(b)
	_settings = SettingsPanel.new()
	_settings.visible = false
	UiKit.center(_settings, Vector2(820, 700))
	_pause_layer.add_child(_settings)
	_settings.back.connect(func():
		_settings.visible = false
		_pause_menu.visible = true)


func _pause() -> void:
	get_tree().paused = true
	_pause_menu.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _resume() -> void:
	get_tree().paused = false
	_pause_menu.visible = false
	_settings.visible = false
	if modal == "" or modal == "camera":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if player:
		player.camera.fov = Game.settings.fov


func _open_settings() -> void:
	_pause_menu.visible = false
	_settings.visible = true


# =========================================================================================
# fades, title cards, death & report
# =========================================================================================
func fade_to(alpha: float, time := 0.8) -> void:
	_fade_text.text = ""
	_fade_sub.text = ""
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, time)
	await tw.finished


func title_card(title: String, sub := "", hold := 2.5) -> void:
	_fade.color.a = 1.0
	_fade_text.text = title
	_fade_sub.text = sub
	_fade_text.modulate.a = 0.0
	_fade_sub.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_fade_text, "modulate:a", 1.0, 1.0)
	tw.tween_property(_fade_sub, "modulate:a", 1.0, 0.8)
	tw.tween_interval(hold)
	tw.tween_property(_fade_text, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(_fade_sub, "modulate:a", 0.0, 0.6)
	tw.tween_property(_fade, "color:a", 0.0, 1.4)
	await tw.finished


## Black screen with lines typed one after another (prologue).
func typewriter(lines: Array, per_char := 0.045) -> void:
	_fade.color.a = 1.0
	_fade_sub.text = ""
	_fade_text.add_theme_font_size_override("font_size", 30)
	_fade_text.modulate.a = 1.0
	var shown := ""
	for line in lines:
		var s := str(line)
		for i in s.length():
			_fade_text.text = shown + s.substr(0, i + 1)
			if s[i] != " " and i % 2 == 0:
				Snd.play("keypad_beep", -30.0, randf_range(1.4, 1.7))
			await get_tree().create_timer(per_char).timeout
		shown += s + "\n"
		await get_tree().create_timer(0.55 if s != "" else 0.2).timeout
	await get_tree().create_timer(2.0).timeout
	var tw := create_tween()
	tw.tween_property(_fade_text, "modulate:a", 0.0, 1.0)
	await tw.finished
	_fade_text.add_theme_font_size_override("font_size", 54)
	_fade_text.text = ""


func show_death(reason: String) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_death = Control.new()
	UiKit.full_rect(_death)
	_fade_layer.add_child(_death)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	UiKit.full_rect(bg)
	_death.add_child(bg)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 22)
	UiKit.full_rect(v)
	_death.add_child(v)
	var t := UiKit.label("BOARDED", 96, Color(0.8, 0.1, 0.08), "mono", 700)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UiKit.label("탑승 처리되었습니다.", 28, UiKit.C_DIM)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var r := UiKit.label(reason, 22, Color(0.85, 0.82, 0.8))
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(1100, 0)
	v.add_child(r)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)
	var again := UiKit.button("이 %s 다시 시작" % ("밤" if Game.phase == "night" else "근무"), 24, func(): Game.restart_phase())
	again.custom_minimum_size = Vector2(320, 64)
	row.add_child(again)
	var menu := UiKit.button("메인 메뉴", 24, func(): Game.go_menu())
	menu.custom_minimum_size = Vector2(240, 64)
	row.add_child(menu)
	_death.modulate.a = 0.0
	create_tween().tween_property(_death, "modulate:a", 1.0, 1.2)


func show_report(summary: Dictionary) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var root := Control.new()
	UiKit.full_rect(root)
	_fade_layer.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.02, 0.03, 1)
	UiKit.full_rect(bg)
	root.add_child(bg)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.04, 0.05, 0.07), UiKit.C_LINE, 10, 1, 40))
	UiKit.center(panel, Vector2(900, 720))
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(UiKit.label("아침 보고  ·  NIGHT %d" % Game.cycle, 40, UiKit.C_TEXT, "sans", 300))
	v.add_child(UiKit.label("06:00  근무 종료 — 서해국제공항 시설운영팀", 18, UiKit.C_DIM, "mono"))
	v.add_child(HSeparator.new())
	var rows := [
		["정상 판정", summary.get("correct", 0), UiKit.C_GOOD],
		["이상 해제", summary.get("cleared", 0), UiKit.C_GOOD],
		["놓친 이상현상", summary.get("missed", 0), UiKit.C_BAD],
		["오판 (정상을 이상으로)", summary.get("false_alarm", 0), UiKit.C_ACCENT],
		["대응 실패", summary.get("failed", 0), UiKit.C_BAD],
	]
	for r in rows:
		var h := HBoxContainer.new()
		v.add_child(h)
		var l := UiKit.label(r[0], 24)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		h.add_child(UiKit.label(str(r[1]), 28, r[2] if int(r[1]) > 0 else UiKit.C_DIM, "mono", 700))
	v.add_child(HSeparator.new())
	var e0 := float(summary.get("erosion_before", 0.0))
	var e1 := float(summary.get("erosion_after", 0.0))
	v.add_child(UiKit.label("터미널 침식도  %d%%  →  %d%%" % [int(e0), int(e1)], 26, UiKit.C_BAD if e1 > e0 else UiKit.C_GOOD, "sans", 700))
	var line := "특이사항 없음. 개장 준비는 예정대로 진행됩니다."
	if int(summary.get("missed", 0)) + int(summary.get("failed", 0)) > 0:
		line = "※ 밤사이 누군가 탑승 수속을 마쳤다는 기록이 남아 있습니다. 승객 명단에는 아무도 없습니다."
	if e1 >= 60.0:
		line = "※ 시스템 로그: 직원 계정 1건의 분류가 '확인 필요'로 변경되었습니다."
	var nl := UiKit.label(line, 20, Color(0.8, 0.8, 0.85))
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nl)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var b := UiKit.button("다음 근무로  →", 26, func(): report_closed.emit(), UiKit.C_ACCENT)
	b.custom_minimum_size = Vector2(320, 70)
	v.add_child(b)
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, 0.8)
	await report_closed
