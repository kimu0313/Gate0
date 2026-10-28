extends Control
## Title screen (SCENE 05): black; a baggage cart rattling somewhere far off; the PA — "Flight 000편의 탑승이
## 시작되었습니다." — then silence; GATE 0 in the middle of the screen over a boarding gate barely there in the dark, its
## departure board showing no destination; then the menu fades in: 계속하기 (only when there is a save) / 새 게임 /
## 설정 / 크레딧 / 종료.
##
## 새 게임 plays the prologue (scripts/story/prologue.gd), which ends by coming back here with the main story saved, so
## 계속하기 is then at the top. A plain launch shows the menu at once; the full opening above plays after the prologue
## (any key or click skips it).

var _world: Node3D
var _cam: Camera3D
var _bridge: JetBridge
var _t := 0.0
var _black: ColorRect
var _main: Control
var _title: TitleLogo
var _title_box: Control
var _list: VBoxContainer
var _rows: Array = []
var _foot: HBoxContainer
var _sub: Label
var _settings: SettingsPanel
var _confirm: PanelContainer
var _confirm_rows: Array = []
var _state := "wait"            # wait | intro | menu
var _intro_id := 0
const TITLE_MID := 540.0         # title centre while it appears (1080p canvas)
const TITLE_UP := 250.0          # ... and once the menu is in
## The title screen's sound, at the levels the menu has always had: the menu music over the night room tone.
const MUSIC_DB := -10.0
const AMB_DB := -6.0
var _after_prologue := false      # straight after the prologue: the title and "press any key", nothing else
var _press: Label                 # 계속하려면 아무 키나 누르세요
var _press_ready := false         # set a moment after it appears, so the key that skipped the opening does not count
static var _boot_shown := false    # the launch notice shows once per run, not on every return to the menu


func _ready() -> void:
	if OS.get_cmdline_user_args().has("--after-prologue"):
		Game.title_intro = "after_prologue"
	_after_prologue = Game.title_intro == "after_prologue"
	UiKit.full_rect(self)
	theme = UiKit.theme()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = false
	_build_backdrop()
	_build_ui()
	_build_settings()
	_build_confirm()
	Events.subtitle.connect(_on_subtitle)
	var args := OS.get_cmdline_user_args()
	if args.has("--looptest") and not get_tree().root.has_node("LoopTest"):
		var lt = load("res://scripts/debug/loop_test.gd").new()
		lt.name = "LoopTest"
		get_tree().root.add_child.call_deferred(lt)
	if args.has("--menu-shots"):
		add_child(load("res://scripts/debug/menu_shots.gd").new())
	if args.has("--settingstest") and not get_tree().root.has_node("SettingsTest"):
		var st = load("res://scripts/debug/settings_test.gd").new()
		st.name = "SettingsTest"
		get_tree().root.add_child.call_deferred(st)
	# the photosensitivity / headphones notice and the brightness card come once, on the very first launch; after that
	# the menu is the first thing you see
	if not _boot_shown and not bool(Game.settings.calibrated) and not (args.has("--skip-boot") or args.has("--settingstest")):
		_boot_shown = true
		var notice := BootNotice.new()
		add_child(notice)
		notice.done.connect(_after_boot)
	else:
		_after_boot.call_deferred()


func _after_boot() -> void:
	_opening(Game.title_intro)
	Game.title_intro = "short"


# =========================================================================================
# backdrop: the gate at the end of the boarding bridge, in the dark
# =========================================================================================
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
	atm.env.tonemap_exposure = 0.9
	_bridge = JetBridge.new()
	_world.add_child(_bridge)
	_bridge.build()
	_bridge.zone.set_on(true, true)
	_bridge.zone.night_dim = 0.5
	_bridge.set_board(JetBridge.BOARD_NO_DEST, false)
	_cam = Camera3D.new()
	_cam.fov = 58.0
	_world.add_child(_cam)
	_cam.current = true
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.15), Color(0, 0, 0, 0.75)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	shade.texture = gt
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	UiKit.full_rect(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _process(delta: float) -> void:
	_t += delta
	if _press_ready:
		_press.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * cos(_t * 3.2))      # breathing, like a waiting sign
	# a slow drift toward the gate
	var k := fmod(_t * 0.06, 1.0)
	var z := lerpf(-JetBridge.LENGTH + 13.0, -JetBridge.LENGTH + 8.5, k)
	_cam.global_position = _bridge.to_global(Vector3(0.35 + sin(_t * 0.11) * 0.25, 1.55 + sin(_t * 0.19) * 0.03, z))
	_cam.rotation = Vector3(0.0 + sin(_t * 0.15) * 0.01, sin(_t * 0.07) * 0.03, 0.0)
	# the sign's tube stutters now and then
	if _state == "menu" and randf() < delta * 0.2 and not Game.settings.reduce_motion:
		var tw := _title.create_tween()
		for a in [0.55, 1.0, 0.7, 1.0]:
			tw.tween_property(_title, "modulate:a", a, randf_range(0.03, 0.07))
		Snd.play("flicker_zap", -30.0, randf_range(1.2, 1.4))


# =========================================================================================
# title + menu
# =========================================================================================
func _build_ui() -> void:
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 1)
	UiKit.full_rect(_black)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_main = Control.new()
	UiKit.full_rect(_main)
	_main.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_main)
	# the title first stands in the middle of the screen; when the menu comes in it rises to make room for the gate
	_title_box = CenterContainer.new()
	_title_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title_box.offset_top = TITLE_MID - 95.0
	_title_box.offset_bottom = TITLE_MID + 95.0
	_title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main.add_child(_title_box)
	_title = TitleLogo.new()
	_title_box.add_child(_title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_list.offset_left = -260
	_list.offset_right = 260
	_list.offset_top = 650
	_main.add_child(_list)
	_build_rows()
	_press = UiKit.label("계속하려면 아무 키나 누르세요", 24, UiKit.TEXT, "sans", 500)
	_press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_press.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_press.offset_left = -480
	_press.offset_right = 480
	_press.offset_top = 690
	_press.modulate.a = 0.0
	_press.visible = _after_prologue
	_main.add_child(_press)
	_foot = HBoxContainer.new()
	_foot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_foot.offset_left = 140
	_foot.offset_right = -110
	_foot.offset_top = -86
	_foot.offset_bottom = -46
	_foot.add_theme_constant_override("separation", 22)
	_main.add_child(_foot)
	_foot.add_child(UiKit.label("1인칭 리미널 호러", 16, UiKit.TEXT_DIM))
	_foot.add_child(UiKit.spacer())
	var hp := UiIcon.make("headphones", 22, UiKit.TEXT_DIM)
	hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_foot.add_child(hp)
	_foot.add_child(UiKit.label("헤드폰 착용을 권장합니다", 16, UiKit.TEXT_DIM))
	_sub = UiKit.label("", 26, Color(0.9, 0.92, 0.95), "sans", 500)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_sub.offset_top = -190
	_sub.offset_bottom = -140
	_sub.modulate.a = 0.0
	add_child(_sub)
	for c in [_title, _foot] + _rows:
		(c as CanvasItem).modulate.a = 0.0


func _build_rows() -> void:
	for r in _rows:
		r.queue_free()
	_rows.clear()
	var items := []
	if _after_prologue:
		# the prologue has just ended: no menu, only "계속하려면 아무 키나 누르세요" (see _build_ui)
		return
	if Game.saved_chapter() != "":
		items.append(["계속하기", func(): _go(Game.continue_game)])
	items.append_array([["새 게임", _on_new], ["설정", _on_settings], ["크레딧", _on_credits],
		["종료", func(): get_tree().quit()]])
	var idx := 1
	for it in items:
		var row := SignRow.make("%02d" % idx, it[0], it[1], "", UiKit.SIGNAL if it[0] != "종료" else UiKit.ALERT)
		_list.add_child(row)
		_rows.append(row)
		idx += 1
	SignRow.link(_rows)


## 계속하기 right after the prologue: the saved start of the main story (or that start itself if nothing was saved).
func _continue_after_prologue() -> void:
	if Game.saved_chapter() != "":
		Game.continue_game()
	else:
		Game.start_chapter("ch1")


func _build_settings() -> void:
	_settings = SettingsPanel.new()
	_settings.visible = false
	UiKit.center(_settings, Vector2(980, 820))
	add_child(_settings)
	_settings.back.connect(func():
		_settings.visible = false
		_show_main())
	_settings.language_changed.connect(_relocalize)


## The language was switched in the settings: the title, rows and footer are rebuilt in place (no scene reload; the
## open settings panel rebuilds itself on the same tab).
func _relocalize() -> void:
	theme = UiKit.theme()
	for n in [_main, _sub, _confirm, _black]:
		if is_instance_valid(n):
			n.queue_free()
	_rows.clear()
	_build_ui()
	_build_confirm()
	_black.color.a = 0.0
	move_child(_settings, -1)   # keep the open panel above the rebuilt menu
	_main.visible = false
	for c in [_title, _foot] + _rows:
		(c as CanvasItem).modulate.a = 1.0
	_set_title_y(TITLE_UP)


func _build_confirm() -> void:
	_confirm = PanelContainer.new()
	_confirm.add_theme_stylebox_override("panel", UiKit.sign_panel())
	UiKit.center(_confirm, Vector2(760, 330))
	_confirm.visible = false
	add_child(_confirm)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_confirm.add_child(v)
	v.add_child(UiKit.caption("NEW GAME", UiKit.SIGNAL_TEXT, 17))
	v.add_child(UiKit.label("새 게임을 시작할까요?", 32, UiKit.TEXT, "sans", 900))
	var d := UiKit.label("저장된 진행이 지워집니다.", 18, UiKit.TEXT_DIM)
	v.add_child(d)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 14)
	v.add_child(gap)
	_confirm_rows.clear()
	for it in [["01", "시작", func(): _go(Game.start_new_game)], ["02", "취소", func():
			_confirm.visible = false
			_show_main()]]:
		var r := SignRow.make(it[0], it[1], it[2], "", UiKit.SIGNAL, 680, 54)
		v.add_child(r)
		_confirm_rows.append(r)
	SignRow.link(_confirm_rows)


# =========================================================================================
# the opening (SCENE 05)
# =========================================================================================
func _opening(kind: String) -> void:
	_state = "intro"
	_intro_id += 1
	var id := _intro_id
	if kind == "short":
		_reveal_now()
		return
	_black.color.a = 1.0
	# far off in the dark, a baggage cart
	await get_tree().create_timer(1.0).timeout
	if id != _intro_id:
		return
	var cart := Snd.variant("cart_rattle")
	Snd.play(cart, -26.0, 0.92, "SFX")
	Snd.play(cart, -4.0, 0.92, "RevLong")
	await get_tree().create_timer(3.4).timeout
	if id != _intro_id:
		return
	# the PA
	await Snd.pa_announce(["pa_v2_boarding_started"], {"subs": ["Flight 000편의 탑승이 시작되었습니다."], "tag": "title"})
	if id != _intro_id:
		return
	# silence, then the title over the gate in the dark
	await get_tree().create_timer(1.6).timeout
	if id != _intro_id:
		return
	_reveal(0.0)


## The title flickers on in the middle, the gate comes up out of the dark, then the menu.
func _reveal(delay: float) -> void:
	_state = "menu"
	_intro_id += 1
	Snd.pa_stop(true)
	_sub.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(_black, "color:a", 0.0, 3.0 if delay == 0.0 else 1.0).set_trans(Tween.TRANS_SINE)
	_title.modulate.a = 0.0
	_set_title_y(TITLE_MID)
	UiFx.flicker_on(_title, delay + 0.2)
	var rise := create_tween()
	rise.tween_interval(delay + 1.5)
	rise.tween_method(_set_title_y, TITLE_MID, TITLE_UP, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if not _after_prologue:
		UiFx.fade(_foot, 1.0, 0.8, delay + 1.8)
	else:
		_press_ready = false
		UiFx.fade(_press, 1.0, 0.8, delay + 2.4)
		get_tree().create_timer(delay + 3.0).timeout.connect(func(): _press_ready = true)
	UiFx.stagger_slide(_rows, Vector2(0, 12), 0.08, 0.4, delay + 2.2)
	Snd.set_music("menu_music_loop", MUSIC_DB, 2.0)          # comes in with the title
	Snd.set_ambience("amb_night_loop", AMB_DB, 2.0)
	get_tree().create_timer(delay + 3.0).timeout.connect(func():
		if _main.visible and not _rows.any(func(r): return r.lit):
			SignRow.select_first(_rows))


## A plain launch or a return from the game: the menu at once — title already in place, rows straight in.
func _reveal_now() -> void:
	_state = "menu"
	_intro_id += 1
	Snd.pa_stop(true)
	_sub.modulate.a = 0.0
	_black.color.a = 0.0
	_set_title_y(TITLE_UP)
	_title.modulate.a = 1.0
	_foot.modulate.a = 1.0
	UiFx.stagger_slide(_rows, Vector2(0, 8), 0.03, 0.18, 0.0)
	Snd.set_music("menu_music_loop", MUSIC_DB, 1.5)
	Snd.set_ambience("amb_night_loop", AMB_DB, 1.5)
	SignRow.select_first(_rows)


func _set_title_y(y: float) -> void:
	_title_box.offset_top = y - 95.0
	_title_box.offset_bottom = y + 95.0


func _on_subtitle(speaker: String, text: String, duration: float) -> void:
	if speaker != "pa" or not Game.settings.subtitles:
		return
	_sub.text = UiKit.keep_all(UiKit.t(text))
	_sub.modulate.a = 1.0
	var tw := _sub.create_tween()
	tw.tween_interval(duration)
	tw.tween_property(_sub, "modulate:a", 0.0, 0.4)


func _show_main() -> void:
	_main.visible = true
	UiFx.stagger_slide(_rows, Vector2(0, 10), 0.04, 0.22)


## Keyboard / d-pad: arrows move the highlighted row, Enter picks it, Esc backs out of a sub-panel. During the
## opening any key or click skips to the menu.
func _unhandled_input(event: InputEvent) -> void:
	if _state == "intro":
		if (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed():
			get_viewport().set_input_as_handled()
			for c in [_title, _foot] + _rows:
				(c as CanvasItem).modulate.a = 0.0
			_reveal(0.0)
		return
	if _state != "menu":
		return
	if _after_prologue:
		var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed()
		if _press_ready and pressed and not event.is_echo():
			get_viewport().set_input_as_handled()
			_press_ready = false
			_go(_continue_after_prologue)
		return
	if _confirm.visible:
		if event.is_action_pressed("ui_cancel"):
			_confirm.visible = false
			_show_main()
		elif not SignRow.navigate(_confirm_rows, event):
			return
	elif _main.visible:
		if not SignRow.navigate(_rows, event):
			return
	else:
		return
	get_viewport().set_input_as_handled()


func _on_new() -> void:
	if Game.saved_chapter() == "":
		_go(Game.start_new_game)
		return
	_main.visible = false
	_confirm.visible = true
	UiFx.pop_in(_confirm, 0.24, 0.96)
	SignRow.select_first(_confirm_rows)


func _on_settings() -> void:
	_main.visible = false
	_settings.visible = true
	UiFx.pop_in(_settings, 0.24, 0.96)


func _on_credits() -> void:
	_main.visible = false
	var cv := CreditsView.new()
	add_child(cv)
	cv.closed.connect(_show_main)


## Leave for the game: the screen goes black first.
func _go(action: Callable) -> void:
	_state = "wait"
	Snd.set_music("", 1.2)
	Snd.play("ui_tap", -8.0)
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 1.0, 0.8)
	tw.tween_callback(action)
