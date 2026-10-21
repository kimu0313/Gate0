class_name Hud
extends CanvasLayer
## Crosshair, interaction prompt, observation progress, subtitles, notifications, objective line.

var _crosshair: Control
var _prompt: Label
var _progress_box: Control
var _progress_bar: ProgressBar
var _sub_panel: PanelContainer
var _sub_speaker: Label
var _sub_text: Label
var _sub_time := 0.0
var _notes: VBoxContainer
var _objective_box: PanelContainer
var _objective: Label
var _clock: Label
var _warn: Label
var _warn_t := 0.0
var _keys: Label
var _keys_t := 0.0
var has_target := false
var player: Player


func _ready() -> void:
	layer = 5
	var root := Control.new()
	UiKit.full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# crosshair
	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(_draw_crosshair)
	root.add_child(_crosshair)
	# prompt
	_prompt = UiKit.label("", 22, Color(1, 1, 1, 0.95), "sans", 600)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.offset_left = -400
	_prompt.offset_right = 400
	_prompt.offset_top = 36
	_prompt.offset_bottom = 70
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	root.add_child(_prompt)
	# observation progress
	_progress_box = VBoxContainer.new()
	_progress_box.set_anchors_preset(Control.PRESET_CENTER)
	_progress_box.offset_left = -110
	_progress_box.offset_right = 110
	_progress_box.offset_top = 76
	_progress_box.offset_bottom = 120
	_progress_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pl := UiKit.label("관찰 중…", 16, UiKit.C_ACCENT, "sans", 600)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_box.add_child(pl)
	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(220, 6)
	_progress_bar.max_value = 1.0
	_progress_bar.add_theme_stylebox_override("background", UiKit.box(Color(0, 0, 0, 0.5), Color(0, 0, 0, 0), 3, 0, 0))
	_progress_bar.add_theme_stylebox_override("fill", UiKit.box(UiKit.C_ACCENT, Color(0, 0, 0, 0), 3, 0, 0))
	_progress_box.add_child(_progress_bar)
	_progress_box.visible = false
	root.add_child(_progress_box)
	# subtitles
	_sub_panel = PanelContainer.new()
	_sub_panel.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.62), Color(0, 0, 0, 0), 8, 0, 18))
	_sub_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_sub_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sub_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sub_panel.offset_left = -560
	_sub_panel.offset_right = 560
	_sub_panel.offset_bottom = -90
	_sub_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sv := VBoxContainer.new()
	_sub_panel.add_child(sv)
	_sub_speaker = UiKit.label("", 17, UiKit.C_ACCENT, "sans", 700)
	sv.add_child(_sub_speaker)
	_sub_text = UiKit.label("", 25, Color(0.95, 0.95, 0.95))
	_sub_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_text.custom_minimum_size = Vector2(1080, 0)
	sv.add_child(_sub_text)
	_sub_panel.visible = false
	root.add_child(_sub_panel)
	# notifications (top right)
	_notes = VBoxContainer.new()
	_notes.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_notes.offset_left = -560
	_notes.offset_right = -28
	_notes.offset_top = 28
	_notes.alignment = BoxContainer.ALIGNMENT_BEGIN
	_notes.add_theme_constant_override("separation", 8)
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_notes)
	# objective (top left)
	_objective_box = PanelContainer.new()
	_objective_box.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), 6, 0, 14))
	_objective_box.position = Vector2(28, 28)
	_objective_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ov := VBoxContainer.new()
	_objective_box.add_child(ov)
	_clock = UiKit.label("", 15, UiKit.C_DIM, "mono", 600)
	ov.add_child(_clock)
	_objective = UiKit.label("", 20, Color(0.95, 0.95, 0.95), "sans", 600)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size = Vector2(420, 0)
	ov.add_child(_objective)
	root.add_child(_objective_box)
	# center warning
	_warn = UiKit.label("", 34, UiKit.C_BAD, "sans", 700)
	_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warn.set_anchors_preset(Control.PRESET_CENTER)
	_warn.offset_left = -500
	_warn.offset_right = 500
	_warn.offset_top = -200
	_warn.offset_bottom = -150
	_warn.add_theme_constant_override("outline_size", 8)
	_warn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	root.add_child(_warn)
	# key hints
	_keys = UiKit.label("[WASD] 이동  [Shift] 달리기  [E] 상호작용  [Tab] 태블릿  [B] 근무 수칙  [F] 손전등  [C] 눈 감기(길게)  [Esc] 메뉴", 16, Color(0.8, 0.82, 0.86, 0.85))
	_keys.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_keys.offset_left = 28
	_keys.offset_top = -44
	_keys.offset_bottom = -20
	_keys.offset_right = 1400
	root.add_child(_keys)
	_keys_t = 40.0
	Events.subtitle.connect(show_subtitle)
	Events.notify.connect(add_note)


func _process(delta: float) -> void:
	if _sub_time > 0.0:
		_sub_time -= delta
		if _sub_time <= 0.0:
			var tw := create_tween()
			tw.tween_property(_sub_panel, "modulate:a", 0.0, 0.3)
			tw.tween_callback(func(): _sub_panel.visible = false)
	if _warn_t > 0.0:
		_warn_t -= delta
		_warn.modulate.a = clampf(_warn_t * 2.0, 0.0, 1.0) * (0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.012))
	else:
		_warn.text = ""
	if _keys_t > 0.0:
		_keys_t -= delta
		_keys.modulate.a = clampf(_keys_t / 3.0, 0.0, 1.0)
	_clock.text = "%s   %s %d   %s" % [Game.clock_text(), "DAY" if Game.phase == "day" else "NIGHT", Game.cycle, _zone_text()]
	_objective_box.visible = _objective.text != "" or true
	_crosshair.queue_redraw()


func _zone_text() -> String:
	if player == null:
		return ""
	return Terminal.ZONE_NAMES.get(player.zone, "")


func set_prompt(text: String) -> void:
	has_target = text != ""
	_prompt.text = ("[E]  " + text) if text != "" else ""


func set_objective(text: String) -> void:
	_objective.text = text
	if text != "":
		_objective_box.modulate = Color(1, 1, 1, 0)
		create_tween().tween_property(_objective_box, "modulate:a", 1.0, 0.4)


func set_inspect_progress(v: float) -> void:
	_progress_box.visible = v >= 0.0
	if v >= 0.0:
		_progress_bar.value = v


func show_key_hints(seconds := 30.0) -> void:
	_keys_t = seconds


func flash_warning(text: String, seconds := 0.6) -> void:
	_warn.text = text
	_warn_t = maxf(_warn_t, seconds)


func show_subtitle(speaker: String, text: String, duration: float) -> void:
	var who := ""
	var body := text
	if "|" in text:
		var parts := text.split("|", true, 1)
		who = parts[0]
		body = parts[1]
	match speaker:
		"radio":
			_sub_speaker.text = "무전 · %s" % who
			_sub_speaker.add_theme_color_override("font_color", UiKit.C_INFO)
		"pa":
			_sub_speaker.text = "안내방송 · PA"
			_sub_speaker.add_theme_color_override("font_color", UiKit.C_ACCENT)
		"self":
			_sub_speaker.text = who if who != "" else "나"
			_sub_speaker.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		_:
			_sub_speaker.text = who
			_sub_speaker.add_theme_color_override("font_color", UiKit.C_DIM)
	_sub_text.text = body
	_sub_panel.visible = true
	_sub_panel.modulate.a = 1.0
	_sub_time = duration


func add_note(text: String, kind: String) -> void:
	var col := UiKit.C_TEXT
	var border := UiKit.C_LINE
	match kind:
		"task":
			col = UiKit.C_ACCENT
			border = UiKit.C_ACCENT
		"alert":
			col = Color(1.0, 0.55, 0.3)
			border = col
		"good":
			col = UiKit.C_GOOD
			border = col
		"bad":
			col = UiKit.C_BAD
			border = col
	var panel := PanelContainer.new()
	var sb := UiKit.box(Color(0.02, 0.025, 0.035, 0.82), Color(0, 0, 0, 0), 4, 0, 14)
	sb.border_width_left = 4
	sb.border_color = border
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UiKit.label(text, 18, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(500, 0)
	panel.add_child(l)
	_notes.add_child(panel)
	while _notes.get_child_count() > 4:
		_notes.get_child(0).queue_free()
		_notes.remove_child(_notes.get_child(0))
	panel.modulate.a = 0.0
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.25)
	tw.tween_interval(5.0 if kind != "alert" else 7.0)
	tw.tween_property(panel, "modulate:a", 0.0, 0.6)
	tw.tween_callback(panel.queue_free)


func _draw_crosshair() -> void:
	if player and (player.eyes > 0.5 or not player.controls_enabled):
		return
	if has_target:
		_crosshair.draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 24, Color(1, 1, 1, 0.9), 2.0, true)
		_crosshair.draw_circle(Vector2.ZERO, 2.5, Color(1, 1, 1, 0.95))
	else:
		_crosshair.draw_circle(Vector2.ZERO, 2.0, Color(1, 1, 1, 0.55))


func set_visible_all(v: bool) -> void:
	visible = v
