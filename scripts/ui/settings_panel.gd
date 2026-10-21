class_name SettingsPanel
extends PanelContainer
## Settings in four sign-style tabs: 조작 (mouse, key bindings), 화면 (window, vsync, frame cap,
## quality, brightness), 오디오, 자막·접근성 (subtitles, calmer UI, crosshair).

signal back

const TABS := [["controls", "조작", "CONTROLS"], ["display", "화면", "DISPLAY"], ["audio", "오디오", "AUDIO"],
	["access", "자막 · 접근성", "ACCESSIBILITY"]]

var _last_tick := 0
var _tab_buttons := {}
var _pages := {}
var _current := "controls"
var _indicator: ColorRect
var _tab_row: HBoxContainer
var _key_buttons := {}      # action -> Button
var _capturing := ""


func _ready() -> void:
	theme = UiKit.theme()
	add_theme_stylebox_override("panel", UiKit.sign_panel(Vector4(44, 34, 44, 30)))
	_build()
	visibility_changed.connect(func():
		if visible:
			_refresh_keys()
		_capturing = "")


## Builds every tab from Game.settings (called again after 기본값 복원 so the controls show the reset values).
func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_tab_buttons.clear()
	_pages.clear()
	_key_buttons.clear()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	head.add_child(UiKit.label("설정", 36, UiKit.TEXT, "sans", 900))
	var cap := UiKit.caption("SETTINGS", UiKit.SIGNAL, 18)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(cap)
	_build_tabs(v)
	var holder := Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.custom_minimum_size = Vector2(0, 520)
	v.add_child(holder)
	for t in TABS:
		var scroll := ScrollContainer.new()
		UiKit.full_rect(scroll)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		holder.add_child(scroll)
		# right gutter so values and toggles never touch the scrollbar
		var pad := MarginContainer.new()
		pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pad.add_theme_constant_override("margin_right", 22)
		scroll.add_child(pad)
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 6)
		pad.add_child(page)
		_pages[t[0]] = scroll
		call("_build_" + t[0], page)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	var b := UiKit.primary("돌아가기", 21, func(): back.emit())
	b.custom_minimum_size = Vector2(220, 56)
	row.add_child(b)
	var hint := UiKit.key_hints([["ESC", "돌아가기"]], UiKit.MIN_TEXT, UiKit.TEXT_MUTE)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hint)
	row.add_child(UiKit.spacer())
	var reset := UiKit.button("기본값으로 되돌리기", 18, func():
		Game.reset_settings()
		var tab := _current
		_build()
		_show_tab(tab, false))
	reset.custom_minimum_size = Vector2(0, 56)
	row.add_child(reset)
	_show_tab(_current, false)


# =========================================================================================
# tabs
# =========================================================================================
func _build_tabs(parent: Control) -> void:
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(0, 52)
	bar.draw.connect(func(): bar.draw_line(Vector2(0, 51.5), Vector2(bar.size.x, 51.5), UiKit.LINE, 1.0))
	parent.add_child(bar)
	_tab_row = HBoxContainer.new()
	UiKit.full_rect(_tab_row)
	_tab_row.add_theme_constant_override("separation", 6)
	bar.add_child(_tab_row)
	for t in TABS:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, UiKit.boxm(Color(0, 0, 0, 0), Vector4(18, 0, 18, 0)))
		b.text = t[1]
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_color", UiKit.TEXT_DIM)
		b.add_theme_color_override("font_hover_color", UiKit.TEXT)
		b.pressed.connect(_show_tab.bind(t[0]))
		_tab_row.add_child(b)
		_tab_buttons[t[0]] = b
	_indicator = ColorRect.new()
	_indicator.color = UiKit.SIGNAL
	_indicator.size = Vector2(0, 3)
	_indicator.position = Vector2(0, 49)
	bar.add_child(_indicator)


func _show_tab(key: String, sound := true) -> void:
	_current = key
	_capturing = ""
	_refresh_keys()
	for k in _pages:
		(_pages[k] as Control).visible = k == key
	for k in _tab_buttons:
		var b: Button = _tab_buttons[k]
		var on: bool = k == key
		b.add_theme_color_override("font_color", UiKit.SIGNAL if on else UiKit.TEXT_DIM)
		b.add_theme_font_override("font", UiKit.font("sans", 700 if on else 500))
	if sound:
		Snd.play("ui_tap", -12.0, 1.2)
	await get_tree().process_frame
	var tb: Button = _tab_buttons[key]
	var tw := _indicator.create_tween().set_parallel(true)
	tw.tween_property(_indicator, "position:x", tb.position.x, 0.2 if sound else 0.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_indicator, "size:x", tb.size.x, 0.2 if sound else 0.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Q / E (or LB / RB style page keys) switch tabs; ESC cancels a key capture before closing.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or _capturing != "":
		return
	var keys: Array = TABS.map(func(t): return t[0])
	var i := keys.find(_current)
	if event.is_action_pressed("ui_page_next") and event is InputEventKey and (event as InputEventKey).physical_keycode in [KEY_PAGEDOWN]:
		_show_tab(keys[wrapi(i + 1, 0, keys.size())])
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_page_prev") and event is InputEventKey and (event as InputEventKey).physical_keycode in [KEY_PAGEUP]:
		_show_tab(keys[wrapi(i - 1, 0, keys.size())])
		get_viewport().set_input_as_handled()


# =========================================================================================
# pages
# =========================================================================================
func _build_controls(p: VBoxContainer) -> void:
	_section(p, "MOUSE · 마우스")
	_slider(p, "마우스 감도", "mouse_sensitivity", 0.2, 3.0, 0.05, func(x): return "×%.2f" % x)
	_slider(p, "시야각 (FOV)", "fov", 60.0, 100.0, 1.0, func(x): return "%d°" % int(x))
	_toggle(p, "마우스 Y축 반전", "invert_y")
	_section(p, "KEY BINDINGS · 키 설정")
	for r in Game.REBINDABLE:
		_key_row(p, r[0], r[1])
	var reset := UiKit.button("기본 키로 되돌리기", 18, func():
		Game.settings.keys = {}
		_commit()
		_refresh_keys())
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	p.add_child(reset)


func _build_display(p: VBoxContainer) -> void:
	_section(p, "WINDOW · 창")
	_choice(p, "화면 모드", "window_mode", [["windowed", "창 모드"], ["borderless", "테두리 없는 전체 화면"], ["fullscreen", "전체 화면"]])
	_toggle(p, "수직 동기화 (VSync)", "vsync")
	_choice(p, "최대 프레임", "max_fps", [[30, "30"], [60, "60"], [120, "120"], [144, "144"], [0, "제한 없음"]])
	_choice(p, "렌더 해상도", "render_scale", [[1.0, "100% (네이티브)"], [0.77, "77% · FSR 품질"], [0.67, "67% · FSR 균형"],
		[0.5, "50% · FSR 성능"]])
	_section(p, "PICTURE · 화질 · 밝기")
	_toggle(p, "고품질 그래픽 (볼륨 포그 · 반사 · GI)", "quality", "다음 근무부터 적용")
	_slider(p, "밝기", "brightness", 0.6, 1.6, 0.02, func(x): return "%d%%" % roundi(x * 100.0))
	var prev := BrightnessPreview.new()
	prev.custom_minimum_size = Vector2(0, 150)
	p.add_child(prev)


func _build_audio(p: VBoxContainer) -> void:
	_section(p, "VOLUME · 음량")
	var pct := func(x): return "%d%%" % roundi(x * 100.0)
	_slider(p, "전체 볼륨", "master_volume", 0.0, 1.0, 0.01, pct)
	_slider(p, "음악", "music_volume", 0.0, 1.0, 0.01, pct)
	_slider(p, "효과음 · 방송", "sfx_volume", 0.0, 1.0, 0.01, pct)


func _build_access(p: VBoxContainer) -> void:
	_section(p, "SUBTITLES · 자막")
	_toggle(p, "자막 표시", "subtitles")
	_choice(p, "자막 크기", "subtitle_size", [[0, "작게"], [1, "보통"], [2, "크게"]])
	_slider(p, "자막 배경", "subtitle_bg", 0.0, 1.0, 0.05, func(x): return "%d%%" % roundi(x * 100.0))
	_section(p, "COMFORT · 편의")
	_toggle(p, "UI 흔들림 · 깜빡임 줄이기", "reduce_motion", "경고·화면 연출의 진동과 점멸을 줄입니다")
	_toggle(p, "조준점 표시", "crosshair")


# =========================================================================================
# widgets
# =========================================================================================
func _section(parent: Control, title: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	parent.add_child(gap)
	parent.add_child(UiKit.caption(title, UiKit.TEXT_MUTE))
	parent.add_child(HSeparator.new())


func _row(parent: Control, text: String, sub := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.custom_minimum_size = Vector2(0, 48)
	parent.add_child(row)
	var lv := VBoxContainer.new()
	lv.custom_minimum_size = Vector2(300, 0)
	lv.alignment = BoxContainer.ALIGNMENT_CENTER
	lv.add_theme_constant_override("separation", -2)
	row.add_child(lv)
	lv.add_child(UiKit.label(text, 19, UiKit.BODY))
	if sub != "":
		lv.add_child(UiKit.label(sub, UiKit.MIN_TEXT, UiKit.TEXT_MUTE))
	return row


func _slider(parent: Control, text: String, key: String, lo: float, hi: float, step: float, fmt: Callable) -> void:
	var row := _row(parent, text)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Game.settings[key])
	s.custom_minimum_size = Vector2(340, 30)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	row.add_child(s)
	var val := UiKit.label(fmt.call(s.value), 19, UiKit.SIGNAL, "display", 700)
	val.custom_minimum_size = Vector2(80, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(val)
	s.value_changed.connect(func(x):
		Game.settings[key] = x
		val.text = fmt.call(x)
		_commit()
		var now := Time.get_ticks_msec()
		if now - _last_tick > 70:
			_last_tick = now
			Snd.play("ui_click", -20.0, 0.8 + (x - lo) / maxf(hi - lo, 0.001) * 0.8))


## On/off switch with its state spelled out (an OFF switch must not read as disabled).
## `quality` stores "high" / "low" instead of a bool.
func _toggle(parent: Control, text: String, key: String, sub := "") -> void:
	var row := _row(parent, text, sub)
	row.add_child(UiKit.spacer())
	var state := UiKit.label("", UiKit.MIN_TEXT, UiKit.TEXT_DIM, "display", 700)
	state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state.custom_minimum_size = Vector2(44, 0)
	state.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(state)
	var c := CheckButton.new()
	c.focus_mode = Control.FOCUS_NONE
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var on: bool = Game.settings.quality == "high" if key == "quality" else bool(Game.settings[key])
	c.button_pressed = on
	row.add_child(c)
	var paint := func(v: bool):
		state.text = "ON" if v else "OFF"
		state.add_theme_color_override("font_color", UiKit.SIGNAL if v else UiKit.TEXT_DIM)
	paint.call(on)
	c.toggled.connect(func(v):
		Snd.play("switch_heavy", -18.0, 1.4)
		if key == "quality":
			Game.settings.quality = "high" if v else "low"
		else:
			Game.settings[key] = v
		paint.call(v)
		_commit())


## ‹ value › stepper over a fixed list of [value, label].
func _choice(parent: Control, text: String, key: String, options: Array) -> void:
	var row := _row(parent, text)
	row.add_child(UiKit.spacer())
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	row.add_child(box)
	var idx := 0
	for i in options.size():
		if str(options[i][0]) == str(Game.settings[key]):
			idx = i
	var val := UiKit.label("", 19, UiKit.TEXT, "sans", 700)
	val.custom_minimum_size = Vector2(250, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var state := {"i": idx}
	var step := func(d: int):
		state.i = wrapi(state.i + d, 0, options.size())
		Game.settings[key] = options[state.i][0]
		val.text = UiKit.keep_all(options[state.i][1])
		Snd.play("ui_click", -14.0, 1.1)
		_commit()
	var prev := UiKit.button("‹", 22, step.bind(-1))
	prev.custom_minimum_size = Vector2(46, 44)
	var next := UiKit.button("›", 22, step.bind(1))
	next.custom_minimum_size = Vector2(46, 44)
	box.add_child(prev)
	box.add_child(val)
	box.add_child(next)
	val.text = UiKit.keep_all(options[idx][1])


func _key_row(parent: Control, action: String, text: String) -> void:
	var row := _row(parent, text)
	row.custom_minimum_size = Vector2(0, 44)
	row.add_child(UiKit.spacer())
	var b := UiKit.button("", 18, func():
		_capturing = action
		_refresh_keys()
		Snd.play("ui_tap", -10.0))
	b.custom_minimum_size = Vector2(190, 40)
	# drawn like the HUD's key caps so it reads as a key, not a disabled box
	var cap := UiKit.boxm(Color(1, 1, 1, 0.08), Vector4(14, 4, 14, 6), Color(1, 1, 1, 0.42), 1, 4)
	cap.border_width_bottom = 3
	b.add_theme_stylebox_override("normal", cap)
	var cap_hover := cap.duplicate() as StyleBoxFlat
	cap_hover.border_color = UiKit.SIGNAL
	b.add_theme_stylebox_override("hover", cap_hover)
	b.add_theme_stylebox_override("pressed", cap_hover)
	row.add_child(b)
	_key_buttons[action] = b


func _refresh_keys() -> void:
	for action in _key_buttons:
		var b: Button = _key_buttons[action]
		if action == _capturing:
			b.text = "키를 누르십시오…"
			b.add_theme_color_override("font_color", UiKit.SIGNAL)
		else:
			b.text = Game.key_label(action)
			b.add_theme_color_override("font_color", UiKit.TEXT)


## Captures the next key for the action being rebound. A key already used by another rebindable
## action is swapped with it, so no action is ever left unbound.
func _input(event: InputEvent) -> void:
	if _capturing == "" or not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		_capturing = ""
		_refresh_keys()
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var code: Key = (event as InputEventKey).physical_keycode
	if code == KEY_ESCAPE:
		_capturing = ""
		_refresh_keys()
		return
	var keys: Dictionary = (Game.settings.keys as Dictionary).duplicate()
	var old := _primary(_capturing)
	for r in Game.REBINDABLE:
		if r[0] != _capturing and _primary(r[0]) == code:
			keys[r[0]] = old
	keys[_capturing] = code
	Game.settings.keys = keys
	_capturing = ""
	_commit()
	_refresh_keys()
	Snd.play("card_beep", -12.0)


func _primary(action: String) -> int:
	var rebound: Dictionary = Game.settings.keys
	if rebound.has(action):
		return int(rebound[action])
	var keys: Array = Game.BINDINGS[action][0]
	return int(keys[0]) if not keys.is_empty() else 0


func _commit() -> void:
	Game.apply_settings()
	Game.save_settings()


## Calibration card: three GATE 0 tiles just above black. The left one should be barely visible.
class BrightnessPreview extends Control:
	func _process(_d: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var b := float(Game.settings.brightness)
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.008, 0.008, 0.01))
		var f := UiKit.font("display", 700)
		var tile := Vector2(84, 84)
		var gap := 60.0
		var x0 := 30.0
		for i in 3:
			var lum: float = [0.035, 0.07, 0.14][i] * b
			var c := Color(lum, lum, lum)
			var p := Vector2(x0 + i * (tile.x + gap), (size.y - tile.y) * 0.5)
			draw_rect(Rect2(p, tile), c)
			draw_string(f, p + Vector2(0, 66), "0", HORIZONTAL_ALIGNMENT_CENTER, tile.x, 64, Color(0.004, 0.004, 0.006))
		var tx := x0 + 3 * (tile.x + gap) - 20.0
		var sans := UiKit.font("sans", 500)
		draw_multiline_string(sans, Vector2(tx, size.y * 0.5 - 14), "왼쪽 표시가 겨우 보일 정도로\n밝기를 맞추십시오.", HORIZONTAL_ALIGNMENT_LEFT, size.x - tx - 20.0, 19, 2, UiKit.TEXT_DIM)
