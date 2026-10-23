class_name GameUI
extends Node
## Owns every screen-space layer of a phase: post FX, HUD, modals (tablet, binder, documents,
## keypad, camera), pause/settings, title cards & fades, the BOARDED screen and the morning report.

signal doc_closed
signal report_closed
signal keypad_closed

const STAMP_SIZE := 140.0   # morning-report 시설운영팀 stamp

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
var _fade_text: RichTextLabel
var _card: VBoxContainer
var _card_org: Label
var _card_board: FlapBoard
var _card_line: ColorRect
var _card_sub: FlapLabel
var _reader: Control
var _reader_paper: PaperPage
var _reader_rig: Control
var _reader_backdrop: Control
var _reader_holder: Control
var _camera_overlay: Control
var _cam_focus := 0.0
var _cam_target := ""
var _cam_t := 0.0
var _shutter := 0.0
var _pause_menu: Control
var _pause_backdrop: Control
var _pause_rows: Array = []
var _pause_status: VBoxContainer
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
	_build_fade()


func _build_fade() -> void:
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(_fade)
	_fade_layer.add_child(_fade)
	_card = VBoxContainer.new()
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	UiKit.full_rect(_card)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_theme_constant_override("separation", 22)
	_card.visible = false
	_fade.add_child(_card)
	_card_org = UiKit.caption("SEOHAE INT'L AIRPORT  ·  FACILITY OPS", UiKit.TEXT_MUTE, 18)
	_card_org.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_card_org)
	_card_board = FlapBoard.new()
	_card_board.font_size = 120
	_card_board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card.add_child(_card_board)
	_card_line = ColorRect.new()
	_card_line.color = UiKit.SIGNAL
	_card_line.custom_minimum_size = Vector2(0, 3)
	_card_line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card.add_child(_card_line)
	_card_sub = FlapLabel.make("", 24, UiKit.BODY, "sans", 400)
	_card_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_sub.tick_sound = false
	_card_sub.stagger = 0.012
	_card.add_child(_card_sub)
	_fade_text = UiKit.rich("", 30, UiKit.TEXT, "sans")
	UiKit.full_rect(_fade_text)
	_fade_text.fit_content = false
	_fade_text.offset_top = 300
	_fade_text.offset_left = 200
	_fade_text.offset_right = -200
	_fade_text.add_theme_constant_override("line_separation", 14)
	_fade_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.add_child(_fade_text)


func bind(p: Player, d: ShiftDirector) -> void:
	player = p
	director = d
	hud.player = p
	tablet.bind_world(d)
	p.interact_target_changed.connect(hud.set_prompt)


func _process(delta: float) -> void:
	if player:
		postfx.eyes = player.eyes
	if _camera_overlay.visible:
		_cam_t += delta
		_cam_focus = move_toward(_cam_focus, 1.0 if _cam_target != "" else 0.0, delta * 5.0)
		_camera_overlay.queue_redraw()
	elif _shutter > 0.0:
		_camera_overlay.queue_redraw()


# =========================================================================================
# input
# =========================================================================================
func _unhandled_input(event: InputEvent) -> void:
	if player == null or director == null or director.dead or director.ending_started:
		return
	if get_tree().paused:
		if event.is_action_pressed("pause"):
			get_viewport().set_input_as_handled()
			if _settings.visible:
				_close_settings()
			else:
				_resume()
		elif _pause_menu.visible and SignRow.navigate(_pause_rows, event):
			get_viewport().set_input_as_handled()
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
		if Game.cycle == 1 and not Game.flag("got_tablet"):
			# DAY 1: the evening-shift colleague hands the tablet over first
			Events.notify.emit("아직 점검 태블릿을 받지 않았습니다.", "info")
			return
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
			tablet.close_anim()
			Snd.play("tablet_close", -6.0)
		"binder":
			binder.close_anim()
			Snd.play("page_flip", -8.0, 0.8)
		"keypad":
			var tw := keypad.create_tween()
			tw.tween_property(keypad, "modulate:a", 0.0, 0.12)
			tw.tween_callback(func():
				keypad.visible = false
				keypad.modulate.a = 1.0)
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
	binder.refresh(page_id)
	binder.open_anim()


func open_keypad(cb: Callable) -> void:
	_keypad_cb = cb
	_open_modal("keypad")
	keypad.visible = true
	keypad.modulate.a = 1.0
	keypad.reset()
	keypad.open_anim()


# --- documents -----------------------------------------------------------------------------
func _build_reader() -> void:
	_reader = Control.new()
	UiKit.full_rect(_reader)
	_reader.visible = false
	_reader.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_layer.add_child(_reader)
	_reader_backdrop = UiKit.backdrop(Color(0.02, 0.025, 0.035, 0.6), 2.6)
	_reader.add_child(_reader_backdrop)
	_reader_backdrop.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close_reader())
	var holder := Control.new()
	UiKit.center(holder, Vector2(860, 940))
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reader.add_child(holder)
	_reader_holder = holder
	_reader_rig = Control.new()
	_reader_rig.size = Vector2(860, 940)
	_reader_rig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reader_rig.draw.connect(func():
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.shadow_color = Color(0, 0, 0, 0.55)
		sb.shadow_size = 40
		sb.shadow_offset = Vector2(0, 18)
		_reader_rig.draw_style_box(sb, Rect2(Vector2.ZERO, _reader_rig.size)))
	holder.add_child(_reader_rig)
	_reader_paper = PaperPage.new()
	_reader_paper.size = Vector2(860, 940)
	_reader_rig.add_child(_reader_paper)
	var clip := UiArt.tex("clip_bulldog")
	if clip:
		var tr := TextureRect.new()
		tr.texture = clip
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		tr.size = Vector2(126, 180)
		tr.position = Vector2(430 - 63, -112)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_reader_rig.add_child(tr)
	var hint := UiKit.key_hints([["%s/ESC" % Game.key_label("interact"), "닫기"]], UiKit.MIN_TEXT, UiKit.TEXT_DIM)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -56
	hint.offset_bottom = -24
	hint.offset_left = -200
	hint.offset_right = 200
	hint.alignment = BoxContainer.ALIGNMENT_CENTER
	_reader.add_child(hint)


## Shows a document and waits until the player closes it.
func read_doc(title: String, body: String, font_kind := "serif") -> void:
	_open_modal("doc")
	_reader_paper.show_page({"title": title, "body": body, "font": font_kind, "stamp": "none"}, true)
	_reader.visible = true
	# size the sheet to its text so short notes are not two-thirds blank paper
	_reader_rig.modulate.a = 0.0
	await get_tree().process_frame
	var h := clampf(_reader_paper.content_height() + 40.0, 560.0, 940.0)
	UiKit.center(_reader_holder, Vector2(860, h))
	_reader_rig.size = Vector2(860, h)
	_reader_paper.size = Vector2(860, h)
	_reader_rig.queue_redraw()
	_reader_rig.pivot_offset = _reader_rig.size * 0.5
	_reader_rig.position = Vector2(0, 90)
	_reader_rig.rotation = deg_to_rad(randf_range(-3.5, -2.0))
	_reader_rig.modulate.a = 0.0
	var tw := _reader_rig.create_tween().set_parallel(true)
	tw.tween_property(_reader_rig, "position", Vector2.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_reader_rig, "rotation", 0.0, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_reader_rig, "modulate:a", 1.0, 0.14)
	(_reader_backdrop.get_node("Blur").material as ShaderMaterial).set_shader_parameter("amount", 0.0)
	UiFx.backdrop_to(_reader_backdrop, 1.0, 0.25)
	Snd.play("page_flip", -4.0)
	await doc_closed


func _close_reader() -> void:
	if not _reader.visible:
		return
	var tw := _reader_rig.create_tween().set_parallel(true)
	tw.tween_property(_reader_rig, "position", Vector2(0, 120), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_reader_rig, "modulate:a", 0.0, 0.14)
	UiFx.backdrop_to(_reader_backdrop, 0.0, 0.14)
	tw.chain().tween_callback(func(): _reader.visible = false)
	Snd.play("page_flip", -10.0, 0.85)
	close_modal()
	doc_closed.emit()


# --- camera ---------------------------------------------------------------------------------
func _build_camera_overlay() -> void:
	_camera_overlay = Control.new()
	UiKit.full_rect(_camera_overlay)
	_camera_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camera_overlay.visible = false
	_camera_overlay.draw.connect(_draw_camera)
	_modal_layer.add_child(_camera_overlay)
	var hint := UiKit.key_hints([["LMB", "촬영"], ["RMB", "카메라 종료"]], 17, Color(1, 1, 1, 0.85))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -108
	hint.offset_bottom = -72
	hint.offset_left = -300
	hint.offset_right = 300
	hint.alignment = BoxContainer.ALIGNMENT_CENTER
	_camera_overlay.add_child(hint)
	var timer := Timer.new()
	timer.wait_time = 0.15
	timer.autostart = true
	timer.timeout.connect(func():
		if _camera_overlay.visible:
			var fac := director.facility_in_view() if director else null
			_cam_target = fac.title if fac else "")
	_camera_overlay.add_child(timer)


func _draw_camera() -> void:
	var c := _camera_overlay
	var s := c.size
	if _camera_overlay.visible:
		var m := 64.0
		var l := 78.0
		var white := Color(1, 1, 1, 0.88)
		for corner in [Vector2(m, m), Vector2(s.x - m, m), Vector2(m, s.y - m), Vector2(s.x - m, s.y - m)]:
			var dx := l if corner.x < s.x * 0.5 else -l
			var dy := l if corner.y < s.y * 0.5 else -l
			c.draw_line(corner, corner + Vector2(dx, 0), white, 3.0)
			c.draw_line(corner, corner + Vector2(0, dy), white, 3.0)
		for i in [1, 2]:
			c.draw_line(Vector2(s.x * i / 3.0, m + 40), Vector2(s.x * i / 3.0, s.y - m - 40), Color(1, 1, 1, 0.08), 1.0)
			c.draw_line(Vector2(m + 40, s.y * i / 3.0), Vector2(s.x - m - 40, s.y * i / 3.0), Color(1, 1, 1, 0.08), 1.0)
		# focus box locks onto a recognized facility
		var f := ease(_cam_focus, 0.5)
		var bs := Vector2(440, 290).lerp(Vector2(250, 166), f)
		var col := Color(1, 1, 1, 0.6).lerp(UiKit.SIGNAL_TEXT, f)
		var r := Rect2(s * 0.5 - bs * 0.5, bs)
		var bl := 24.0
		for corner in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
			var dx := bl if corner.x < s.x * 0.5 else -bl
			var dy := bl if corner.y < s.y * 0.5 else -bl
			c.draw_line(corner, corner + Vector2(dx, 0), col, 2.5)
			c.draw_line(corner, corner + Vector2(0, dy), col, 2.5)
		c.draw_line(s * 0.5 - Vector2(14, 0), s * 0.5 + Vector2(14, 0), Color(1, 1, 1, 0.55), 1.5)
		c.draw_line(s * 0.5 - Vector2(0, 14), s * 0.5 + Vector2(0, 14), Color(1, 1, 1, 0.55), 1.5)
		var disp := UiKit.font("display", 700)
		if f > 0.5 and _cam_target != "":
			var txt := "FOCUS LOCK  ·  " + UiKit.t(_cam_target)
			var tw := disp.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			var p := Vector2(s.x * 0.5 - tw * 0.5, r.end.y + 34)
			c.draw_rect(Rect2(p - Vector2(12, 22), Vector2(tw + 24, 32)), Color(0, 0, 0, 0.55 * f))
			c.draw_string(disp, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(UiKit.SIGNAL_TEXT, f))
		# stills camera readout: mode + date stamp (it takes photos, so no REC timecode)
		c.draw_circle(Vector2(m + 34, m + 42), 9, Color(UiKit.CLEAR, 0.9 if f > 0.5 else 0.35))
		c.draw_string(disp, Vector2(m + 54, m + 50), UiKit.t("STILL  ·  점검 촬영"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, white)
		var stamp := "DAY %d  ·  %s" % [Game.cycle, Game.clock_text()]
		c.draw_string(disp, Vector2(s.x - m - 330, m + 49), stamp, HORIZONTAL_ALIGNMENT_RIGHT, 260, 22, white)
		var bp := Vector2(s.x - m - 58, m + 30)
		c.draw_rect(Rect2(bp, Vector2(44, 22)), white, false, 2.0)
		c.draw_rect(Rect2(bp + Vector2(4, 4), Vector2(28, 14)), white)
		c.draw_rect(Rect2(bp + Vector2(45, 7), Vector2(4, 8)), white)
		# remaining film
		for i in Game.PHOTOS_PER_DAY:
			var fr := Rect2(Vector2(m + 30 + i * 26, s.y - m - 66), Vector2(18, 26))
			if i < Game.photos_left:
				c.draw_rect(fr, UiKit.SIGNAL)
			else:
				c.draw_rect(fr, Color(1, 1, 1, 0.4), false, 2.0)
		c.draw_string(disp, Vector2(m + 36 + Game.PHOTOS_PER_DAY * 26, s.y - m - 45), "%d / %d" % [Game.photos_left, Game.PHOTOS_PER_DAY],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, white)
	# shutter blades
	if _shutter > 0.0:
		var hgt := s.y * 0.5 * _shutter
		c.draw_rect(Rect2(0, 0, s.x, hgt), Color.BLACK)
		c.draw_rect(Rect2(0, s.y - hgt, s.x, hgt), Color.BLACK)


func _enter_camera() -> void:
	tablet.visible = false
	modal = "camera"
	Game.paused_by_ui = false
	player.controls_enabled = true
	player.look_enabled = true
	player.camera_mode = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_camera_overlay.visible = true
	_camera_overlay.modulate.a = 0.0
	UiFx.fade(_camera_overlay, 1.0, 0.2)
	_cam_t = 0.0
	_cam_focus = 0.0
	hud.visible = false
	Snd.play("button_press", -8.0, 1.4)


func _exit_camera() -> void:
	_camera_overlay.visible = false
	hud.visible = true
	player.camera_mode = false
	modal = ""
	Snd.play("button_press", -8.0, 1.1)


func _set_shutter(v: float) -> void:
	_shutter = v
	_camera_overlay.queue_redraw()


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
	var tex := ImageTexture.create_from_image(img)
	Game.photos.append({"image": img, "tex": tex, "label": label,
		"cycle": Game.cycle, "altered": false, "facility": fac.id if fac else ""})
	Game.photos_left -= 1
	Game.stat("photos")
	Snd.play("camera_shutter", -2.0)
	postfx.flash(0.7)
	var tw := create_tween()
	tw.tween_method(_set_shutter, 0.0, 1.0, 0.05)
	tw.tween_method(_set_shutter, 1.0, 0.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_fly_thumbnail(tex)
	Events.photo_taken.emit(Game.photos.size() - 1)
	Events.player_action.emit("photo", fac.id if fac else "")
	Events.notify.emit(UiKit.t("사진 저장: ") + Tablet.photo_label(label), "good")


## The captured frame shrinks into the corner like a print dropping into the album.
func _fly_thumbnail(tex: Texture2D) -> void:
	var s := _camera_overlay.get_viewport_rect().size
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiKit.boxm(UiKit.NAVY_TEXT, Vector4(7, 7, 7, 30)))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.custom_minimum_size = Vector2(480, 270)
	card.add_child(tr)
	_modal_layer.add_child(card)
	card.size = Vector2(494, 307)
	card.pivot_offset = card.size * 0.5
	card.position = s * 0.5 - card.size * 0.5
	var saved := UiKit.caption("SAVED · %02d / %02d" % [Game.photos_left, Game.PHOTOS_PER_DAY], UiKit.CLEAR, 18)
	saved.position = Vector2(s.x - 330, 230)
	saved.modulate.a = 0.0
	_modal_layer.add_child(saved)
	var target := Vector2(s.x - 300, 70)
	var tw := card.create_tween()
	tw.tween_interval(0.14)
	tw.set_parallel(true)
	tw.tween_property(card, "position", target - card.size * 0.5 + Vector2(card.size.x * 0.2, card.size.y * 0.2), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(card, "scale", Vector2(0.4, 0.4), 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(card, "rotation", deg_to_rad(-5.0), 0.42)
	tw.set_parallel(false)
	tw.tween_callback(func(): UiFx.fade(saved, 1.0, 0.15))
	tw.tween_interval(0.8)
	tw.tween_property(card, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func():
		card.queue_free()
		var t2 := saved.create_tween()
		t2.tween_property(saved, "modulate:a", 0.0, 0.25)
		t2.tween_callback(saved.queue_free))


# =========================================================================================
# pause
# =========================================================================================
func _build_pause() -> void:
	_pause_backdrop = UiKit.backdrop(Color(0.015, 0.02, 0.03, 0.66), 3.2)
	_pause_backdrop.visible = false
	_pause_layer.add_child(_pause_backdrop)
	_pause_menu = Control.new()
	UiKit.full_rect(_pause_menu)
	_pause_menu.visible = false
	_pause_menu.theme = UiKit.theme()
	_pause_layer.add_child(_pause_menu)
	var left := VBoxContainer.new()
	left.position = Vector2(140, 170)
	left.add_theme_constant_override("separation", 6)
	_pause_menu.add_child(left)
	# Korean first, like every other sign in the game; the English line is the sign's sub-label
	left.add_child(UiKit.caption("SEOHAE OPS  ·  SHIFT ON HOLD", UiKit.SIGNAL_TEXT, 18))
	left.add_child(UiKit.label("일시정지", 96, UiKit.TEXT, "sans", 900))
	if not UiKit.same("일시정지", "PAUSED  ·  근무가 잠시 멈췄습니다"):
		left.add_child(UiKit.label("PAUSED  ·  근무가 잠시 멈췄습니다", 26, UiKit.TEXT_DIM, "display", 700))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	left.add_child(gap)
	var items := [["01", "계속하기", _resume], ["02", "설정", _open_settings],
		["03", "이 근무 다시 시작", func(): Game.restart_phase()], ["04", "메인 메뉴로", func(): Game.go_menu()],
		["05", "게임 종료", func(): get_tree().quit()]]
	for it in items:
		var row := SignRow.make(it[0], it[1], it[2], "", UiKit.SIGNAL if it[0] != "05" else UiKit.ALERT)
		left.add_child(row)
		_pause_rows.append(row)
	SignRow.link(_pause_rows)
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	card.offset_left = -640
	card.offset_right = -140
	card.offset_top = 200
	card.add_theme_stylebox_override("panel", UiKit.boxm(UiKit.SHADE, Vector4(30, 26, 30, 28)))
	_pause_menu.add_child(card)
	_pause_status = VBoxContainer.new()
	_pause_status.add_theme_constant_override("separation", 12)
	card.add_child(_pause_status)
	_settings = SettingsPanel.new()
	_settings.visible = false
	UiKit.center(_settings, Vector2(980, 820))
	_pause_layer.add_child(_settings)
	_settings.back.connect(_close_settings)
	_settings.language_changed.connect(func():
		Events.notify.emit("언어 변경은 다음 근무부터 모든 화면에 적용됩니다.", "info"))


func _close_settings() -> void:
	_settings.visible = false
	_pause_menu.visible = true
	hud.refresh_keys()
	_refresh_pause_status()


func _refresh_pause_status() -> void:
	for c in _pause_status.get_children():
		c.queue_free()
	_pause_status.add_child(UiKit.caption("CURRENT SHIFT · 현재 근무", UiKit.TEXT_MUTE, 15))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	_pause_status.add_child(h)
	var chip := UiKit.chip("DAY %d" % Game.cycle, UiKit.INK_0, UiKit.TEXT, "", 20)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(chip)
	h.add_child(UiKit.label(Game.clock_text(), 48, UiKit.TEXT, "display", 700))
	if player:
		var zh := HBoxContainer.new()
		zh.add_theme_constant_override("separation", 8)
		_pause_status.add_child(zh)
		zh.add_child(UiIcon.make("pin", 18, UiKit.TEXT_DIM))
		zh.add_child(UiKit.label(str(Terminal.ZONE_NAMES.get(player.zone, "")), 18, UiKit.BODY))
	var sep := HSeparator.new()
	_pause_status.add_child(sep)
	_pause_status.add_child(UiKit.caption("CURRENT ORDER · 현재 지시", UiKit.SIGNAL_TEXT, 15))
	var cur := director.current.title if director and director.current else "—"
	var cl := UiKit.label(cur, 22, UiKit.TEXT, "sans", 700)
	cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cl.custom_minimum_size = Vector2(430, 0)
	_pause_status.add_child(cl)
	var st := UiKit.erosion_state(Game.erosion)
	var eh := HBoxContainer.new()
	_pause_status.add_child(eh)
	var ec := UiKit.caption("TERMINAL SYSTEM", UiKit.TEXT_DIM, 15)
	ec.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eh.add_child(ec)
	eh.add_child(UiKit.caption("%s · %d%%" % [st[1], int(Game.erosion)], st[0], 15))
	var keys := UiKit.key_hints([[Game.key_label("tablet"), "태블릿"], [Game.key_label("binder"), "근무 수칙"], ["ESC", "돌아가기"]], UiKit.MIN_TEXT, UiKit.TEXT_DIM)
	_pause_status.add_child(keys)


func _pause() -> void:
	get_tree().paused = true
	_pause_menu.visible = true
	_pause_backdrop.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_pause_status()
	(_pause_backdrop.get_node("Blur").material as ShaderMaterial).set_shader_parameter("amount", 0.0)
	UiFx.backdrop_to(_pause_backdrop, 1.0, 0.22)
	UiFx.stagger_slide(_pause_rows, Vector2(-26, 0), 0.04, 0.24, 0.06)
	SignRow.select_first(_pause_rows)
	Snd.play("tablet_close", -14.0, 1.4)


func _resume() -> void:
	get_tree().paused = false
	_pause_menu.visible = false
	_pause_backdrop.visible = false
	_settings.visible = false
	if modal == "" or modal == "camera":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if player:
		player.camera.fov = Game.settings.fov


func _open_settings() -> void:
	_pause_menu.visible = false
	_settings.visible = true
	UiFx.pop_in(_settings, 0.22, 0.96)


# =========================================================================================
# fades, title cards, death & report
# =========================================================================================
func fade_to(alpha: float, time := 0.8) -> void:
	_card.visible = false
	_fade_text.text = ""
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, time)
	await tw.finished


## Waits out the first-frames shader-compile hitch so an animation that starts now is actually seen.
func _settle_frames() -> void:
	var t0 := Time.get_ticks_msec()
	var last := t0
	while Time.get_ticks_msec() - t0 < 4000:
		await get_tree().process_frame
		var now := Time.get_ticks_msec()
		if now - last < 50 and now - t0 > 120:
			return
		last = now


## Departure-board title card: tiles flip to "DAY 1", a signal line draws, the date line flaps in.
func title_card(title: String, sub := "", hold := 2.5) -> void:
	_fade.color.a = 1.0
	await _settle_frames()
	_fade_text.text = ""
	_card.visible = true
	_card.modulate.a = 1.0
	_card_org.modulate.a = 0.0
	_card_sub.text = ""
	_card_line.custom_minimum_size.x = 0.0
	_card_board.text_color = UiKit.SIGNAL_TEXT if title.begins_with("DAY") else UiKit.TEXT
	_card_board.show_text(title, 0.35)
	var settle := _card_board.settle_time()
	var tw := create_tween()
	tw.tween_property(_card_org, "modulate:a", 1.0, 0.5)
	tw.tween_interval(maxf(settle - 0.4, 0.1))
	tw.tween_callback(func(): Snd.play("clock_punch", -14.0, 1.4))
	tw.tween_property(_card_line, "custom_minimum_size:x", 560.0, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _card_sub.flap_to(sub))
	tw.tween_interval(0.6 + hold)
	tw.tween_property(_card, "modulate:a", 0.0, 0.6)
	tw.tween_property(_fade, "color:a", 0.0, 1.4)
	tw.tween_callback(func(): _card.visible = false)
	await tw.finished


## Black screen with lines typed one after another (prologue). Earlier lines dim; a caret blinks.
func typewriter(lines: Array, per_char := 0.045) -> void:
	lines = lines.map(func(l): return UiKit.t(str(l)))
	_fade.color.a = 1.0
	await _settle_frames()
	_card.visible = false
	_fade_text.modulate.a = 1.0
	var done := ""
	for line in lines:
		var s := str(line)
		for i in s.length():
			_fade_text.text = "[center][color=#6b7480]%s[/color]%s[color=#ffc21a]▍[/color][/center]" % [done, s.substr(0, i + 1)]
			if s[i] != " " and i % 2 == 0:
				Snd.play("keypad_beep", -30.0, randf_range(1.4, 1.7))
			await get_tree().create_timer(per_char).timeout
		done += s + "\n"
		_fade_text.text = "[center][color=#6b7480]%s[/color][/center]" % done
		await get_tree().create_timer(0.55 if s != "" else 0.2).timeout
	await get_tree().create_timer(2.0).timeout
	var tw := create_tween()
	tw.tween_property(_fade_text, "modulate:a", 0.0, 1.0)
	await tw.finished
	_fade_text.text = ""


func show_death(reason: String) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_death = Control.new()
	UiKit.full_rect(_death)
	_death.theme = UiKit.theme()
	_fade_layer.add_child(_death)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	UiKit.full_rect(bg)
	_death.add_child(bg)
	var fx := Control.new()
	UiKit.full_rect(fx)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.draw.connect(func():
		var s := fx.size
		for i in 14:
			var k := 1.0 - i / 14.0
			fx.draw_circle(s * 0.5, s.x * 0.08 * (i + 1), Color(0.35, 0.02, 0.02, 0.022 * k))
		var y := 0.0
		while y < s.y:
			fx.draw_line(Vector2(0, y), Vector2(s.x, y), Color(1, 1, 1, 0.02), 1.0)
			y += 4.0)
	_death.add_child(fx)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 24)
	UiKit.full_rect(v)
	_death.add_child(v)
	var top := UiKit.label("FLIGHT 000  ·  GATE 0", 24, UiKit.TEXT_DIM, "display", 700)
	top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(top)
	var board := FlapBoard.new()
	board.font_size = 120
	board.text_color = UiKit.ALERT
	board.tile_color = Color("140707")
	board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(board)
	board.show_text("BOARDED", 0.5, 0.08, 6)
	var s := UiKit.label("탑승 처리되었습니다.", 30, UiKit.BODY, "sans", 300)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var r := UiKit.label(reason, 21, UiKit.TEXT_DIM)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(1100, 0)
	v.add_child(r)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var again := UiKit.primary(UiKit.t("이 %s 다시 시작") % UiKit.t("근무"), 22, func(): Game.restart_phase(), UiKit.ALERT)
	again.custom_minimum_size = Vector2(300, 62)
	row.add_child(again)
	var menu := UiKit.button("메인 메뉴", 22, func(): Game.go_menu())
	menu.custom_minimum_size = Vector2(220, 62)
	row.add_child(menu)
	# entrance: a red glitch flicker, then the board flips, then the text and buttons
	_death.modulate.a = 0.0
	var tw := create_tween()
	for a in [0.7, 0.1, 0.9, 0.3, 1.0]:
		tw.tween_property(_death, "modulate:a", a, 0.05)
	s.modulate.a = 0.0
	r.modulate.a = 0.0
	row.modulate.a = 0.0
	var settle := board.settle_time()
	UiFx.fade(s, 1.0, 0.6, settle + 0.2)
	UiFx.fade(r, 1.0, 0.1, settle + 0.6)
	UiFx.typewrite(r, clampf(reason.length() * 0.03, 0.5, 2.0), settle + 0.6)
	UiFx.fade(row, 1.0, 0.4, settle + 1.6)


func show_report(summary: Dictionary) -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var root := Control.new()
	UiKit.full_rect(root)
	root.theme = UiKit.theme()
	_fade_layer.add_child(root)
	var bg := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.62, 1.0])
	g.colors = PackedColorArray([Color("0a1220"), Color("152238"), Color("3a2e2a")])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	UiKit.full_rect(bg)
	root.add_child(bg)
	var holder := Control.new()
	UiKit.center(holder, Vector2(600, 920))
	holder.offset_top += 30
	holder.offset_bottom += 30
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	var sheet := Control.new()
	sheet.size = Vector2(600, 920)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.draw.connect(func():
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.shadow_color = Color(0, 0, 0, 0.5)
		sb.shadow_size = 40
		sb.shadow_offset = Vector2(0, 20)
		sheet.draw_style_box(sb, Rect2(Vector2.ZERO, sheet.size))
		var paper := UiArt.tex("paper_sheet")
		if paper:
			sheet.draw_texture_rect(paper, Rect2(Vector2.ZERO, sheet.size), false, Color(1.05, 1.05, 1.04))
		else:
			sheet.draw_rect(Rect2(Vector2.ZERO, sheet.size), Color("f4f1e8")))
	holder.add_child(sheet)
	var m := MarginContainer.new()
	UiKit.full_rect(m)
	for side in [["margin_left", 46], ["margin_top", 70], ["margin_right", 46], ["margin_bottom", 40]]:
		m.add_theme_constant_override(side[0], side[1])
	sheet.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)
	var ink := UiKit.PAPER_INK
	var head := HBoxContainer.new()
	v.add_child(head)
	var hc := UiKit.caption("MORNING REPORT", ink, 18)
	hc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hc)
	head.add_child(UiKit.label("06:00 · DAY %d" % Game.cycle, UiKit.MIN_TEXT, Color("5a564e"), "display", 700))
	v.add_child(UiKit.label("아침 보고", 40, ink, "sans", 900))
	var rule := ColorRect.new()
	rule.color = ink
	rule.custom_minimum_size = Vector2(0, 3)
	v.add_child(rule)
	v.add_child(UiKit.label("서해국제공항 시설운영팀 · 야간 시설 점검 결과", UiKit.MIN_TEXT, Color("5a564e")))
	# accuracy and judgment mistakes (concept doc: 실력이 보이는 지표)
	var acc := int(summary.get("accuracy", -1))
	if acc >= 0:
		var ah := HBoxContainer.new()
		v.add_child(ah)
		var al := UiKit.label("판정 정확도", 22, ink, "sans", 900)
		al.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		al.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ah.add_child(al)
		ah.add_child(UiKit.label("%d%%" % acc, 34, Color("0f7a62") if acc >= 70 else UiKit.STAMP_RED, "display", 700))
		var mh := HBoxContainer.new()
		v.add_child(mh)
		var ml := UiKit.label("판정 실수", 18, ink)
		ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mh.add_child(ml)
		var mn := int(summary.get("mistakes", 0))
		mh.add_child(UiKit.label("%d / 3" % mn, 20, UiKit.STAMP_RED if mn > 0 else Color("0f7a62"), "display", 700))
	var rows := [
		["정상 판정", summary.get("correct", 0), Color("0f7a62")],
		["이상 해제", summary.get("cleared", 0), Color("0f7a62")],
		["놓친 이상현상", summary.get("missed", 0), UiKit.STAMP_RED],
		["오판 (정상을 이상으로)", summary.get("false_alarm", 0), Color("8a6a12")],
		["대응 실패", summary.get("failed", 0), UiKit.STAMP_RED],
	]
	var counters := []
	for row in rows:
		var h := HBoxContainer.new()
		h.custom_minimum_size = Vector2(0, 34 if acc >= 0 else 46)
		v.add_child(h)
		var l := UiKit.label(row[0], 20, ink)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
		var n := int(row[1])
		var cl := UiKit.label("00", 26, row[2] if n > 0 else Color("8a857a"), "display", 700)
		cl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(cl)
		h.draw.connect(func():
			var x := 0.0
			while x < h.size.x:
				h.draw_line(Vector2(x, h.size.y - 1), Vector2(minf(x + 6, h.size.x), h.size.y - 1), Color("b9b3a5"), 1.0)
				x += 11.0)
		counters.append([h, cl, n])
	var e0 := float(summary.get("erosion_before", 0.0))
	var e1 := float(summary.get("erosion_after", 0.0))
	var eh := HBoxContainer.new()
	v.add_child(eh)
	var el := UiKit.label("터미널 침식도", 19, ink, "sans", 700)
	el.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eh.add_child(el)
	eh.add_child(UiKit.label("%d%%  →  %d%%" % [int(e0), int(e1)], 19, UiKit.STAMP_RED if e1 > e0 else Color("0f7a62"), "display", 700))
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 16)
	bar.set_meta("k", 0.0)
	bar.draw.connect(func():
		var w := bar.size.x
		var k: float = bar.get_meta("k")
		bar.draw_rect(Rect2(0, 0, w, 16), Color("dcd6c7"))
		bar.draw_rect(Rect2(0, 0, w * minf(e0, e1) / 100.0, 16), Color("6b665c"))
		var cur := lerpf(e0, e1, k)
		if cur > e0:
			bar.draw_rect(Rect2(w * e0 / 100.0, 0, w * (cur - e0) / 100.0, 16), UiKit.STAMP_RED)
		elif cur < e0:
			bar.draw_rect(Rect2(w * cur / 100.0, 0, w * (e0 - cur) / 100.0, 16), Color(0.06, 0.48, 0.38, 0.5)))
	v.add_child(bar)
	var line := "특이사항 없음. 개장 준비는 예정대로 진행됩니다."
	if int(summary.get("missed", 0)) + int(summary.get("failed", 0)) > 0:
		line = "※ 밤사이 누군가 탑승 수속을 마쳤다는 기록이 남아 있습니다. 승객 명단에는 아무도 없습니다."
	if e1 >= 60.0:
		line = "※ 시스템 로그: 직원 계정 1건의 분류가 '확인 필요'로 변경되었습니다."
	# what was missed tonight, revealed now (concept doc: 사후 정답 공개)
	var misses: Array = summary.get("missed_list", [])
	if not misses.is_empty():
		var parts := [UiKit.t("놓친 이상현상 · 사후 공개")]
		for i in mini(misses.size(), 4):
			parts.append("· %s — %s" % [UiKit.t(str(misses[i][0])), UiKit.t(str(misses[i][1]))])
		if misses.size() > 4:
			parts.append(UiKit.t("외 %d건") % (misses.size() - 4))
		line = "\n".join(parts)
	var nl := UiKit.label(line, 15 if not misses.is_empty() else 16, Color("3b3934"))
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# the remark wraps short of the right column, where the stamp lands
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 0)
	v.add_child(nh)
	nh.add_child(nl)
	var stamp_gap := Control.new()
	stamp_gap.custom_minimum_size = Vector2(STAMP_SIZE - 16.0, 0)
	stamp_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nh.add_child(stamp_gap)
	v.add_child(UiKit.spacer(false))
	var b := UiKit.primary("다음 근무로  →", 22, func(): report_closed.emit(), ink, UiKit.PAPER)
	b.custom_minimum_size = Vector2(0, 64)
	v.add_child(b)
	var clip := UiArt.tex("clip_bulldog")
	if clip:
		var tr := TextureRect.new()
		tr.texture = clip
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		tr.size = Vector2(118, 168)
		tr.position = Vector2(300 - 59, -104)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sheet.add_child(tr)
	var stamp := StampMark.make(["시설운영팀", "확인"], Color(UiKit.STAMP_RED, 0.85), "round", "stamp_seal_ring", Vector2(STAMP_SIZE, STAMP_SIZE))
	stamp.angle_deg = 14.0
	stamp.position = Vector2(392, 636)   # placed beside the remark once the layout is known
	stamp.modulate.a = 0.0
	sheet.add_child(stamp)
	# sequence: sheet drops in, numbers count, erosion bar moves, remark types, stamp lands, button appears
	sheet.pivot_offset = sheet.size * 0.5
	sheet.position = Vector2(0, 260)
	sheet.rotation = deg_to_rad(-3.0)
	root.modulate.a = 0.0
	b.modulate.a = 0.0
	nl.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.5)
	tw.parallel().tween_property(sheet, "position", Vector2.ZERO, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(sheet, "rotation", 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): Snd.play("page_flip", -6.0, 0.9))
	for i in counters.size():
		var c: Array = counters[i]
		UiFx.count_up(c[1], c[2], 0.45, "%02d", 0.8 + i * 0.22)
	tw.tween_interval(0.25 + counters.size() * 0.22)
	var bar_set := func(k: float):
		bar.set_meta("k", k)
		bar.queue_redraw()
	tw.tween_method(bar_set, 0.0, 1.0, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		UiFx.fade(nl, 1.0, 0.1)
		UiFx.typewrite(nl, clampf(line.length() * 0.025, 0.4, 1.4)))
	tw.tween_interval(clampf(line.length() * 0.025, 0.4, 1.4) + 0.2)
	tw.tween_callback(func():
		var to_sheet := sheet.get_global_transform().affine_inverse()
		var top := (to_sheet * nh.global_position).y
		var bottom := (to_sheet * b.global_position).y - 6.0
		stamp.position = Vector2(sheet.size.x - 40.0 - STAMP_SIZE, clampf(top - 4.0, 0.0, bottom - STAMP_SIZE))
		UiFx.slam(stamp, 0.28)
		get_tree().create_timer(0.1).timeout.connect(func():
			Snd.play("clock_punch", -2.0, 1.0)
			UiFx.shake(sheet, 6.0, 0.2)))
	tw.tween_interval(0.5)
	tw.tween_property(b, "modulate:a", 1.0, 0.35)
	await report_closed
