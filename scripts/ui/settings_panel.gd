class_name SettingsPanel
extends PanelContainer
## Settings: sensitivity, FOV, volumes, fullscreen, invert Y, graphics quality.

signal back


func _ready() -> void:
	add_theme_stylebox_override("panel", UiKit.box(Color(0.04, 0.05, 0.07, 0.97), UiKit.C_LINE, 10, 1, 30))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	v.add_child(UiKit.label("설정", 32, UiKit.C_TEXT, "sans", 700))
	_slider(v, "마우스 감도", "mouse_sensitivity", 0.2, 3.0, 0.05)
	_slider(v, "시야각 (FOV)", "fov", 60.0, 100.0, 1.0)
	_slider(v, "전체 볼륨", "master_volume", 0.0, 1.0, 0.01)
	_slider(v, "음악", "music_volume", 0.0, 1.0, 0.01)
	_slider(v, "효과음 · 방송", "sfx_volume", 0.0, 1.0, 0.01)
	_check(v, "전체 화면", "fullscreen")
	_check(v, "마우스 Y축 반전", "invert_y")
	var q := CheckButton.new()
	q.text = "고품질 그래픽 (볼륨 포그 · 반사 · GI) — 다음 근무부터 적용"
	q.button_pressed = Game.settings.quality == "high"
	q.add_theme_font_size_override("font_size", 19)
	q.add_theme_font_override("font", UiKit.font())
	q.toggled.connect(func(on):
		Game.settings.quality = "high" if on else "low"
		Game.save_settings())
	v.add_child(q)
	var b := UiKit.button("돌아가기", 22, func(): back.emit())
	b.custom_minimum_size = Vector2(240, 56)
	v.add_child(b)


func _slider(parent: Control, text: String, key: String, lo: float, hi: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)
	var l := UiKit.label(text, 19)
	l.custom_minimum_size = Vector2(220, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Game.settings[key])
	s.custom_minimum_size = Vector2(360, 28)
	s.focus_mode = Control.FOCUS_NONE
	row.add_child(s)
	var val := UiKit.label("%.2f" % s.value if step < 1.0 else "%d" % int(s.value), 18, UiKit.C_DIM, "mono")
	val.custom_minimum_size = Vector2(70, 0)
	row.add_child(val)
	s.value_changed.connect(func(x):
		Game.settings[key] = x
		val.text = "%.2f" % x if step < 1.0 else "%d" % int(x)
		Game.apply_settings()
		Game.save_settings())


func _check(parent: Control, text: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = bool(Game.settings[key])
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 19)
	c.add_theme_font_override("font", UiKit.font())
	c.toggled.connect(func(on):
		Game.settings[key] = on
		Game.apply_settings()
		Game.save_settings())
	parent.add_child(c)
