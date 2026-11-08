class_name GameUI
extends Node
## Owns every screen-space layer of a story part: post FX, HUD, modals (tablet, documents, keypad),
## pause/settings, title cards and fades, and the screen you get when it catches you.

signal doc_closed
signal keypad_closed
signal tablet_closed

var player: Player
var story: StoryDirector
var postfx: PostFx
var hud: Hud
var tablet: Tablet
var keypad: KeypadView
var modal := ""
var tablet_locked := false      # the story holds the tablet open until something has played out on it

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
var _place: VBoxContainer
var _reader: Control
var _reader_paper: PaperPage
var _reader_rig: Control
var _reader_backdrop: Control
var _reader_holder: Control
var _pause_menu: Control
var _pause_backdrop: Control
var _pause_rows: Array = []
var _pause_status: VBoxContainer
var _settings: SettingsPanel
var _death: Control
var _keypad_cb: Callable
var _guide: Control              # the guidelines folder, open (open_guide)
var _guide_art: GuideView
var _guide_backdrop: Control


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
	_build_guide()
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 20
	add_child(_pause_layer)
	_build_pause()
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 30
	add_child(_fade_layer)
	_build_place_card()
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
	_card_org = UiKit.caption("GATE 0", UiKit.TEXT_MUTE, 18)
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


func bind(p: Player, d: StoryDirector) -> void:
	player = p
	story = d
	hud.player = p
	tablet.bind_world(d.terminal, p)
	p.interact_target_changed.connect(hud.set_prompt)
	p.camera_changed.connect(hud.set_camera_view)
	p.photo_taken.connect(hud.camera_shot)


func _process(_delta: float) -> void:
	if player:
		postfx.eyes = player.eyes



# =========================================================================================
# input
# =========================================================================================
func _unhandled_input(event: InputEvent) -> void:
	if player == null or story == null or story.dead:
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
	if modal == "doc":
		if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			_close_reader()
		return
	if modal == "guide":
		if event.is_action_pressed("pause") or event.is_action_pressed("tablet") or event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			close_guide()
		return
	if modal != "":
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_pause()
	elif event.is_action_pressed("tablet") and player.controls_enabled and not player.cutscene:
		get_viewport().set_input_as_handled()
		match story.tab_opens:
			"guide":
				open_guide()
			"none":
				pass
			_:
				if story.tablet_allowed:
					open_tablet()


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
	var was := modal
	match modal:
		"tablet":
			tablet.close_anim()
			Snd.play("tablet_close", -6.0)
		"keypad":
			var tw := keypad.create_tween()
			tw.tween_property(keypad, "modulate:a", 0.0, 0.12)
			tw.tween_callback(func():
				keypad.visible = false
				keypad.modulate.a = 1.0)
	modal = ""
	Game.paused_by_ui = false
	if story and not story.dead:
		player.controls_enabled = true
		player.look_enabled = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if was == "tablet":
		tablet_closed.emit()


func close_all() -> void:
	if modal == "doc":
		_close_reader()
	elif modal == "guide":
		close_guide()
	else:
		tablet_locked = false
		close_modal()
	if get_tree().paused:
		_resume()


func open_tablet(tab := "") -> void:
	_open_modal("tablet")
	Snd.play("tablet_open", -6.0)
	tablet.open(tab)


func open_keypad(cb: Callable) -> void:
	_keypad_cb = cb
	_open_modal("keypad")
	keypad.visible = true
	keypad.modulate.a = 1.0
	keypad.reset()
	keypad.open_anim()


# --- the guidelines ------------------------------------------------------------------------
## The guidelines folder opened ([Tab] once you have it — user: "지침서를 얻으면 tab을 눌러 열 수 있고", then, with a
## picture of an open case file: "지침서는 이런 서류 연 디자인으로"): GuideView, the folder lying open, on a dark
## blurred backdrop; it drops in turning and settles a little askew, as if put down on a desk. [Tab] / ESC / [E]
## closes it.
func _build_guide() -> void:
	_guide = Control.new()
	UiKit.full_rect(_guide)
	_guide.visible = false
	_guide.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal_layer.add_child(_guide)
	_guide_backdrop = UiKit.backdrop(Color(0.0, 0.0, 0.0, 0.82), 3.0)
	_guide.add_child(_guide_backdrop)
	_guide_backdrop.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			close_guide())
	_guide_art = GuideView.new()
	_guide.add_child(_guide_art)
	var hint := UiKit.key_hints([["%s/ESC" % Game.key_label("tablet"), "닫기"]], UiKit.MIN_TEXT, UiKit.TEXT_DIM)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -56
	hint.offset_bottom = -24
	hint.offset_left = -200
	hint.offset_right = 200
	hint.alignment = BoxContainer.ALIGNMENT_CENTER
	_guide.add_child(hint)


func open_guide() -> void:
	_open_modal("guide")
	_guide_art.build()
	var vp := _guide.get_viewport_rect().size
	var s := minf(vp.x * 0.96 / GuideView.SIZE.x, (vp.y - 76.0) / GuideView.SIZE.y)
	_guide_art.scale = Vector2(s, s)
	var at := vp * 0.5 - GuideView.SIZE * 0.5 - Vector2(0, 22)
	_guide_art.position = at + Vector2(0, 70)
	_guide_art.rotation = deg_to_rad(-4.5)
	_guide_art.modulate.a = 0.0
	_guide.visible = true
	var tw := _guide_art.create_tween().set_parallel(true)
	tw.tween_property(_guide_art, "position", at, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_guide_art, "rotation", deg_to_rad(-1.2), 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_guide_art, "modulate:a", 1.0, 0.16)
	(_guide_backdrop.get_node("Blur").material as ShaderMaterial).set_shader_parameter("amount", 0.0)
	UiFx.backdrop_to(_guide_backdrop, 1.0, 0.25)
	Snd.play("page_flip", -4.0)


func close_guide() -> void:
	if not _guide.visible:
		return
	var tw := _guide_art.create_tween().set_parallel(true)
	tw.tween_property(_guide_art, "position", _guide_art.position + Vector2(0, 90), 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_guide_art, "modulate:a", 0.0, 0.14)
	UiFx.backdrop_to(_guide_backdrop, 0.0, 0.14)
	tw.chain().tween_callback(func(): _guide.visible = false)
	Snd.play("page_flip", -10.0, 0.85)
	close_modal()


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
func read_doc(title: String, body: String, font_kind := "serif", extra := {}) -> void:
	_open_modal("doc")
	var page := {"title": title, "body": body, "font": font_kind, "stamp": "none"}
	page.merge(extra, true)
	_reader_paper.show_page(page, true)
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
	left.add_child(UiKit.caption("GATE 0  ·  ON HOLD", UiKit.SIGNAL_TEXT, 18))
	left.add_child(UiKit.label("일시정지", 96, UiKit.TEXT, "sans", 900))
	if not UiKit.same("일시정지", "PAUSED"):
		left.add_child(UiKit.label("PAUSED", 26, UiKit.TEXT_DIM, "display", 700))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	left.add_child(gap)
	var items := [["01", "계속하기", _resume], ["02", "설정", _open_settings],
		["03", "마지막 지점부터 다시", func(): Game.restart_checkpoint()], ["04", "메인 메뉴로", func(): Game.go_menu()],
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
		Events.notify.emit("언어 변경은 다음 장면부터 모든 화면에 적용됩니다.", "info"))


func _close_settings() -> void:
	_settings.visible = false
	_pause_menu.visible = true
	hud.refresh_keys()
	_refresh_pause_status()


func _refresh_pause_status() -> void:
	for c in _pause_status.get_children():
		c.queue_free()
	_pause_status.add_child(UiKit.caption("NOW · 현재", UiKit.TEXT_MUTE, 15))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	_pause_status.add_child(h)
	h.add_child(UiKit.label(hud.clock_shown(), 48, UiKit.TEXT, "display", 700))
	if player:
		var zh := HBoxContainer.new()
		zh.add_theme_constant_override("separation", 8)
		_pause_status.add_child(zh)
		zh.add_child(UiIcon.make("pin", 18, UiKit.TEXT_DIM))
		zh.add_child(UiKit.label(str(Terminal.ZONE_NAMES.get(player.zone, "—")), 18, UiKit.BODY))
	_pause_status.add_child(HSeparator.new())
	var keys := UiKit.key_hints([[Game.key_label("tablet"), "태블릿"], [Game.key_label("flashlight"), "손전등"], ["ESC", "돌아가기"]], UiKit.MIN_TEXT, UiKit.TEXT_DIM)
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
	if modal == "":
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if player:
		player.camera.fov = Game.settings.fov


func _open_settings() -> void:
	_pause_menu.visible = false
	_settings.visible = true
	UiFx.pop_in(_settings, 0.22, 0.96)


# =========================================================================================
# fades, title cards, place card, death
# =========================================================================================
func fade_to(alpha: float, time := 0.8) -> void:
	_card.visible = false
	_fade_text.text = ""
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", alpha, time)
	await tw.finished


func fade_alpha() -> float:
	return _fade.color.a


## Straight to black (or back), no fade: a cut.
func cut_to(alpha: float) -> void:
	_card.visible = false
	_fade_text.text = ""
	_fade.color.a = alpha


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


## Departure-board title card: tiles flip to the title, a signal line draws, the sub line flaps in.
func title_card(title: String, sub := "", hold := 2.5, fade_back := true) -> void:
	_fade.color.a = 1.0
	await _settle_frames()
	_fade_text.text = ""
	_card.visible = true
	_card.modulate.a = 1.0
	_card_org.modulate.a = 0.0
	_card_sub.text = ""
	_card_line.custom_minimum_size.x = 0.0
	_card_board.text_color = UiKit.TEXT
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
	if fade_back:
		tw.tween_property(_fade, "color:a", 0.0, 1.4)
	tw.tween_callback(func(): _card.visible = false)
	await tw.finished


## Black screen with lines typed one after another. Earlier lines dim; a caret blinks.
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
			_fade_text.text = "[center][color=#6b7480]%s[/color]%s[color=#6e9cff]▍[/color][/center]" % [done, s.substr(0, i + 1)]
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


func _build_place_card() -> void:
	_place = VBoxContainer.new()
	_place.position = Vector2(64, 760)
	_place.add_theme_constant_override("separation", 2)
	_place.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place.visible = false
	_fade_layer.add_child(_place)


## Where and when, typed in the lower left over the opening shot (SCENE 01: "A국제공항 터미널 / AM 02:17 / 정상 근무").
## Returns at once; the card fades by itself.
func place_card(lines: Array, hold := 4.0) -> void:
	for c in _place.get_children():
		c.queue_free()
	_place.visible = true
	_place.modulate.a = 1.0
	var labels: Array = []
	for i in lines.size():
		var l := UiKit.label(str(lines[i]), 34 if i == 0 else 22, UiKit.TEXT if i == 0 else UiKit.TEXT_DIM, "sans" if i == 0 else "display", 700 if i == 0 else 600)
		l.visible_ratio = 0.0
		_place.add_child(l)
		labels.append(l)
	var tw := create_tween()
	for l: Label in labels:
		tw.tween_property(l, "visible_ratio", 1.0, clampf(l.text.length() * 0.05, 0.3, 1.0))
		tw.tween_interval(0.25)
	tw.tween_interval(hold)
	tw.tween_property(_place, "modulate:a", 0.0, 1.2)
	tw.tween_callback(func(): _place.visible = false)


## Caught. The board flips to BOARDED; retry from the last checkpoint or leave for the title.
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
	var again := UiKit.primary("다시 시도", 22, func(): Game.restart_checkpoint(), UiKit.ALERT)
	again.custom_minimum_size = Vector2(260, 62)
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
