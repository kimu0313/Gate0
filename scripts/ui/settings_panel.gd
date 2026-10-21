class_name SettingsPanel
extends PanelContainer
## Settings: sensitivity, FOV, invert Y, volumes, fullscreen, graphics quality — grouped like a sign
## schedule (CONTROLS / AUDIO / DISPLAY).

signal back

var _last_tick := 0


func _ready() -> void:
	theme = UiKit.theme()
	add_theme_stylebox_override("panel", UiKit.boxm(Color(0.047, 0.058, 0.075, 0.97), Vector4(44, 36, 44, 36), UiKit.LINE, 1))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	var t := UiKit.label("설정", 36, UiKit.TEXT, "sans", 900)
	head.add_child(t)
	var cap := UiKit.caption("SETTINGS", UiKit.SIGNAL, 18)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(cap)
	_section(v, "CONTROLS · 조작")
	_slider(v, "마우스 감도", "mouse_sensitivity", 0.2, 3.0, 0.05)
	_slider(v, "시야각 (FOV)", "fov", 60.0, 100.0, 1.0)
	_check(v, "마우스 Y축 반전", "invert_y")
	_section(v, "AUDIO · 오디오")
	_slider(v, "전체 볼륨", "master_volume", 0.0, 1.0, 0.01)
	_slider(v, "음악", "music_volume", 0.0, 1.0, 0.01)
	_slider(v, "효과음 · 방송", "sfx_volume", 0.0, 1.0, 0.01)
	_section(v, "DISPLAY · 화면")
	_check(v, "전체 화면", "fullscreen")
	var q := CheckButton.new()
	q.text = "고품질 그래픽 (볼륨 포그 · 반사 · GI) — 다음 근무부터 적용"
	q.button_pressed = Game.settings.quality == "high"
	q.focus_mode = Control.FOCUS_NONE
	q.add_theme_font_size_override("font_size", 19)
	q.toggled.connect(func(on):
		Snd.play("switch_heavy", -18.0, 1.4)
		Game.settings.quality = "high" if on else "low"
		Game.save_settings())
	v.add_child(q)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	v.add_child(gap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	v.add_child(row)
	var b := UiKit.primary("돌아가기", 21, func(): back.emit())
	b.custom_minimum_size = Vector2(220, 56)
	row.add_child(b)
	var hint := UiKit.key_hints([["ESC", "돌아가기"]], 14, UiKit.TEXT_MUTE)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hint)


func _section(parent: Control, title: String) -> void:
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	parent.add_child(gap)
	parent.add_child(UiKit.caption(title, UiKit.TEXT_MUTE, 15))
	parent.add_child(HSeparator.new())


func _slider(parent: Control, text: String, key: String, lo: float, hi: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	parent.add_child(row)
	var l := UiKit.label(text, 19, UiKit.BODY)
	l.custom_minimum_size = Vector2(230, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Game.settings[key])
	s.custom_minimum_size = Vector2(380, 30)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	row.add_child(s)
	var val := UiKit.label(_fmt(s.value, step), 18, UiKit.SIGNAL, "mono", 700)
	val.custom_minimum_size = Vector2(70, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(val)
	s.value_changed.connect(func(x):
		Game.settings[key] = x
		val.text = _fmt(x, step)
		Game.apply_settings()
		Game.save_settings()
		var now := Time.get_ticks_msec()
		if now - _last_tick > 70:
			_last_tick = now
			Snd.play("ui_click", -20.0, 0.8 + (x - lo) / maxf(hi - lo, 0.001) * 0.8))


static func _fmt(x: float, step: float) -> String:
	return "%.2f" % x if step < 1.0 else "%d" % int(x)


func _check(parent: Control, text: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = bool(Game.settings[key])
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 19)
	c.toggled.connect(func(on):
		Snd.play("switch_heavy", -18.0, 1.4)
		Game.settings[key] = on
		Game.apply_settings()
		Game.save_settings())
	parent.add_child(c)
