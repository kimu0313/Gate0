class_name Hud
extends CanvasLayer
## SIGN-language HUD: current-order sign, toasts, subtitles, reticle with observation ring, interaction
## prompt, warning banner and key hints. As erosion rises the same signage starts to slip:
## colors bleed, words swap ("점검" → "탑승") and finally the order sign becomes a boarding notice.

var has_target := false
var player: Player

# current-order sign (top left)
var _obj_root: VBoxContainer
var _obj_head: HBoxContainer
var _obj_tile: PanelContainer
var _obj_icon: UiIcon
var _obj_body: PanelContainer
var _obj_caption: FlapLabel
var _objective: FlapLabel
var _clock: FlapLabel
var _phase_chip: Label
var _phase_box: PanelContainer
var _zone: FlapLabel
var _obj_text := ""
var _boarding := false
# toasts (top right)
var _notes_root: Control
var _notes: Array = []          # [{node, life, max, accent}]
# subtitles
var _sub_root: VBoxContainer
var _sub_chip_slot: HBoxContainer
var _sub_text: Label
var _sub_band: PanelContainer
var _sub_time := 0.0
# reticle, prompt, observation
var _reticle: Control
var _target_k := 0.0
var _progress := -1.0
var _burst := 0.0
var _observe_label: Label
var _prompt_row: HBoxContainer
var _prompt_box: PanelContainer
var _prompt_text: Label
# warning, hints
var _warn: Control
var _warn_text := ""
var _warn_t := 0.0
var _warn_age := 0.0
var _keys: PanelContainer
var _keys_t := 0.0
# erosion glitches
var _glitch_cd := 3.0
var _glitch_t := 0.0
var _clock_override := ""


func _ready() -> void:
	layer = 5
	var root := Control.new()
	UiKit.full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_objective(root)
	_build_notes(root)
	_build_subtitles(root)
	_build_reticle(root)
	_build_warning(root)
	_build_controls(root)
	_keys_t = 40.0
	Events.subtitle.connect(show_subtitle)
	Events.notify.connect(add_note)


# =========================================================================================
# build
# =========================================================================================
func _build_objective(root: Control) -> void:
	_obj_root = VBoxContainer.new()
	_obj_root.position = Vector2(44, 44)
	_obj_root.add_theme_constant_override("separation", 0)
	_obj_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_obj_root)
	_obj_head = HBoxContainer.new()
	_obj_head.add_theme_constant_override("separation", 0)
	_obj_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_root.add_child(_obj_head)
	_obj_tile = PanelContainer.new()
	_obj_tile.custom_minimum_size = Vector2(72, 0)
	_obj_tile.add_theme_stylebox_override("panel", UiKit.box(UiKit.SIGNAL, Color(0, 0, 0, 0), 0, 0, 0))
	_obj_head.add_child(_obj_tile)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_tile.add_child(cc)
	_obj_icon = UiIcon.make("order", 34, UiKit.INK_0)
	cc.add_child(_obj_icon)
	_obj_body = PanelContainer.new()
	_obj_body.add_theme_stylebox_override("panel", UiKit.boxm(UiKit.SHADE, Vector4(18, 11, 22, 13)))
	_obj_head.add_child(_obj_body)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 2)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_body.add_child(bv)
	_obj_caption = FlapLabel.make("CURRENT ORDER · 현재 지시", 15, UiKit.SIGNAL, "display", 700)
	_obj_caption.tick_sound = false
	bv.add_child(_obj_caption)
	_objective = FlapLabel.make("", 27, UiKit.TEXT, "sans", 700)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size = Vector2(430, 0)
	bv.add_child(_objective)
	_obj_head.visible = false
	# meta row: clock · phase · zone
	var meta := PanelContainer.new()
	meta.add_theme_stylebox_override("panel", UiKit.boxm(Color(0.035, 0.043, 0.055, 0.62), Vector4(14, 6, 16, 7)))
	meta.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_obj_root.add_child(meta)
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 12)
	mh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_child(mh)
	_clock = FlapLabel.make(Game.clock_text(), 19, UiKit.TEXT, "mono", 700)
	_clock.tick_sound = false
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mh.add_child(_clock)
	_phase_box = PanelContainer.new()
	_phase_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mh.add_child(_phase_box)
	_phase_chip = UiKit.label("", 15, UiKit.INK_0, "display", 700)
	_phase_box.add_child(_phase_chip)
	_refresh_phase_chip()
	var pin := UiIcon.make("pin", 18, UiKit.TEXT_DIM)
	pin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mh.add_child(pin)
	_zone = FlapLabel.make("", 17, UiKit.BODY, "sans", 500)
	_zone.tick_sound = false
	_zone.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mh.add_child(_zone)


func _refresh_phase_chip() -> void:
	var day := Game.phase == "day"
	_phase_chip.text = "%s %d" % ["DAY" if day else "NIGHT", Game.cycle]
	_phase_box.add_theme_stylebox_override("panel", UiKit.boxm(UiKit.SIGNAL if day else UiKit.TEXT, Vector4(8, 1, 8, 2)))


func _build_notes(root: Control) -> void:
	_notes_root = Control.new()
	_notes_root.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_notes_root.offset_left = -604
	_notes_root.offset_right = -44
	_notes_root.offset_top = 44
	_notes_root.offset_bottom = 700
	_notes_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notes_root.clip_contents = false
	root.add_child(_notes_root)


func _build_subtitles(root: Control) -> void:
	_sub_root = VBoxContainer.new()
	_sub_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_sub_root.offset_left = -620
	_sub_root.offset_right = 620
	_sub_root.offset_top = -310
	_sub_root.offset_bottom = -156
	_sub_root.alignment = BoxContainer.ALIGNMENT_END
	_sub_root.add_theme_constant_override("separation", 10)
	_sub_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_sub_root)
	_sub_chip_slot = HBoxContainer.new()
	_sub_chip_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	_sub_chip_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_root.add_child(_sub_chip_slot)
	_sub_band = PanelContainer.new()
	var band := StyleBoxTexture.new()
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.14, 0.86, 1.0])
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.62), Color(0, 0, 0, 0.62), Color(0, 0, 0, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 256
	gt.height = 4
	band.texture = gt
	band.content_margin_left = 60
	band.content_margin_right = 60
	band.content_margin_top = 12
	band.content_margin_bottom = 14
	_sub_band.add_theme_stylebox_override("panel", band)
	_sub_band.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sub_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_root.add_child(_sub_band)
	_sub_text = UiKit.label("", 27, Color(0.97, 0.97, 0.97))
	_sub_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_text.custom_minimum_size = Vector2(1080, 0)
	_sub_text.add_theme_constant_override("outline_size", 6)
	_sub_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_sub_text.add_theme_constant_override("line_spacing", 4)
	_sub_band.add_child(_sub_text)
	_sub_root.visible = false


func _build_reticle(root: Control) -> void:
	_reticle = Control.new()
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.draw.connect(_draw_reticle)
	root.add_child(_reticle)
	_observe_label = UiKit.caption("", UiKit.SIGNAL, 16)
	_observe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_observe_label.set_anchors_preset(Control.PRESET_CENTER)
	_observe_label.offset_left = -300
	_observe_label.offset_right = 300
	_observe_label.offset_top = 40
	_observe_label.offset_bottom = 62
	_observe_label.add_theme_constant_override("outline_size", 5)
	_observe_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_observe_label.modulate.a = 0.0
	root.add_child(_observe_label)
	_prompt_row = HBoxContainer.new()
	_prompt_row.set_anchors_preset(Control.PRESET_CENTER)
	_prompt_row.offset_left = -500
	_prompt_row.offset_right = 500
	_prompt_row.offset_top = 72
	_prompt_row.offset_bottom = 118
	_prompt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_prompt_row)
	_prompt_box = PanelContainer.new()
	_prompt_box.add_theme_stylebox_override("panel", UiKit.boxm(Color(0.035, 0.043, 0.055, 0.72), Vector4(6, 6, 16, 6)))
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_row.add_child(_prompt_box)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 12)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_box.add_child(ph)
	ph.add_child(UiKit.keycap("E", 19))
	_prompt_text = UiKit.label("", 21, UiKit.TEXT, "sans", 700)
	_prompt_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ph.add_child(_prompt_text)
	_prompt_row.modulate.a = 0.0


## Control guide (bottom left): a sign panel with a keyboard tile, a WASD cluster and grouped keys.
func _build_controls(root: Control) -> void:
	_keys = PanelContainer.new()
	_keys.add_theme_stylebox_override("panel", UiKit.boxm(Color(0.035, 0.043, 0.055, 0.8), Vector4.ZERO))
	_keys.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_keys.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_keys.offset_left = 44
	_keys.offset_top = -40
	_keys.offset_bottom = -40
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_keys)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys.add_child(h)
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(54, 0)
	tile.add_theme_stylebox_override("panel", UiKit.box(UiKit.SIGNAL, Color(0, 0, 0, 0), 0, 0, 0))
	h.add_child(tile)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(cc)
	cc.add_child(UiIcon.make("keyboard", 30, UiKit.INK_0))
	var body := MarginContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [["margin_left", 18], ["margin_top", 10], ["margin_right", 22], ["margin_bottom", 12]]:
		body.add_theme_constant_override(side[0], side[1])
	h.add_child(body)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(v)
	v.add_child(UiKit.caption("CONTROLS · 조작 안내", UiKit.SIGNAL, 13))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	# movement cluster
	var mv := HBoxContainer.new()
	mv.add_theme_constant_override("separation", 10)
	row.add_child(mv)
	var cluster := VBoxContainer.new()
	cluster.add_theme_constant_override("separation", 3)
	mv.add_child(cluster)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	cluster.add_child(top)
	top.add_child(UiKit.keycap("W", 14, false))
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 3)
	cluster.add_child(bottom)
	for k in ["A", "S", "D"]:
		bottom.add_child(UiKit.keycap(k, 14, false))
	mv.add_child(_guide_label("이동", "MOVE"))
	for group in [[["SHIFT", "달리기", "SPRINT"]], [["E", "상호작용", "USE"], ["F", "손전등", "LIGHT"], ["C", "눈 감기", "HOLD"]],
			[["TAB", "태블릿", "TABLET"], ["B", "근무 수칙", "RULES"], ["ESC", "메뉴", "MENU"]]]:
		var sep := ColorRect.new()
		sep.color = Color(1, 1, 1, 0.12)
		sep.custom_minimum_size = Vector2(1, 40)
		sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sep)
		for it in group:
			var item := HBoxContainer.new()
			item.add_theme_constant_override("separation", 8)
			var cap := UiKit.keycap(it[0], 14, false)
			cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			item.add_child(cap)
			item.add_child(_guide_label(it[1], it[2]))
			row.add_child(item)


func _guide_label(kr: String, en: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UiKit.label(kr, 15, UiKit.TEXT, "sans", 500))
	v.add_child(UiKit.caption(en, UiKit.TEXT_MUTE, 11))
	return v


func _build_warning(root: Control) -> void:
	_warn = Control.new()
	_warn.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	_warn.anchor_top = 0.5
	_warn.anchor_bottom = 0.5
	_warn.offset_top = -250
	_warn.offset_bottom = -158
	_warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warn.draw.connect(_draw_warning)
	root.add_child(_warn)


# =========================================================================================
# per frame
# =========================================================================================
func _process(delta: float) -> void:
	# subtitles
	if _sub_time > 0.0:
		_sub_time -= delta
		if _sub_time <= 0.0:
			var tw := create_tween()
			tw.tween_property(_sub_root, "modulate:a", 0.0, 0.3)
			tw.tween_callback(func(): _sub_root.visible = false)
	# warning
	if _warn_t > 0.0:
		_warn_t -= delta
		_warn_age += delta
	_warn.queue_redraw()
	# key hints
	if _keys_t > 0.0:
		_keys_t -= delta
		_keys.modulate.a = move_toward(_keys.modulate.a, clampf(_keys_t / 3.0, 0.0, 1.0), delta * 4.0)
		_keys.visible = _keys_t > 0.0
	# meta row
	_zone.flap_to(_zone_text())
	if _clock_override != "":
		_clock.flap_to(_clock_override, false)
	else:
		_clock.flap_to(Game.clock_text())
	# reticle
	_target_k = move_toward(_target_k, 1.0 if has_target else 0.0, delta * 7.0)
	_burst = move_toward(_burst, 0.0, delta * 1.8)
	_reticle.queue_redraw()
	_update_notes(delta)
	_update_erosion(delta)


func _zone_text() -> String:
	if player == null:
		return ""
	return Terminal.ZONE_NAMES.get(player.zone, "")


# =========================================================================================
# objective
# =========================================================================================
func set_objective(text: String) -> void:
	_obj_text = text
	if text == "":
		if _obj_head.visible:
			var tw := create_tween()
			tw.tween_property(_obj_head, "modulate:a", 0.0, 0.18)
			tw.tween_callback(func():
				if _obj_text == "":
					_obj_head.visible = false)
		return
	var was_hidden := not _obj_head.visible or _obj_head.modulate.a < 0.5
	_obj_head.visible = true
	_obj_head.modulate.a = 1.0
	_objective.flap_to(_shown(text), not was_hidden, 0.0)
	if was_hidden:
		_objective.flap_to(_shown(text), false)
		_obj_head.pivot_offset = Vector2(0, 0)
		_obj_head.scale = Vector2(0.0, 1.0)
		var tw := create_tween()
		tw.tween_property(_obj_head, "scale:x", 1.0, 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		var txt := _shown(text)
		_objective.text = ""
		tw.tween_callback(func(): _objective.flap_to(txt))
	# the icon tile flashes like a sign switching on
	_obj_tile.modulate = Color(2.2, 2.2, 2.2)
	create_tween().tween_property(_obj_tile, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _shown(text: String) -> String:
	return UiKit.corrupt(text, 1.0) if Game.erosion >= 75.0 and randf() < 0.3 else text


# =========================================================================================
# erosion: the signage slips
# =========================================================================================
func _update_erosion(delta: float) -> void:
	var e := Game.erosion
	var board := e >= 75.0
	if board != _boarding:
		_set_boarding(board)
	if _glitch_t > 0.0:
		_glitch_t -= delta
		if _glitch_t <= 0.0:
			_end_glitch()
	if e < 25.0:
		return
	_glitch_cd -= delta
	if _glitch_cd <= 0.0:
		_glitch_cd = randf_range(2.5, 7.0) * (1.6 - e / 100.0)
		_start_glitch(e)


func _start_glitch(e: float) -> void:
	_glitch_t = randf_range(0.08, 0.16) + (0.15 if e >= 50.0 else 0.0)
	_obj_root.position.x = 44.0 + randf_range(-6.0, 6.0) * (e / 100.0 + 0.3)
	_obj_root.modulate = Color(1.25, 0.75, 0.75) if randf() < 0.5 else Color(0.8, 1.1, 1.3)
	if randf() < 0.6:
		_clock_override = "--:--" if e < 60.0 or randf() < 0.5 else "00:00"
	if e >= 50.0 and _obj_text != "":
		_objective.flap_to(UiKit.corrupt(_obj_text, 1.0), false)
		if not _boarding:
			_obj_caption.flap_to("CURRENT B0ARD1NG · 현재 탑승", false)
	if e >= 40.0:
		Snd.play("glitch", -26.0, randf_range(1.2, 1.6))


func _end_glitch() -> void:
	_obj_root.position.x = 44.0
	_obj_root.modulate = Color.WHITE
	_clock_override = ""
	if _obj_text != "":
		_objective.flap_to(_obj_text, false)
	_obj_caption.flap_to("BOARDING · 탑승 안내" if _boarding else "CURRENT ORDER · 현재 지시", false)


func _set_boarding(on: bool) -> void:
	_boarding = on
	_obj_tile.add_theme_stylebox_override("panel", UiKit.box(UiKit.NAVY_TEXT if on else UiKit.SIGNAL, Color(0, 0, 0, 0), 0, 0, 0))
	_obj_icon.set_icon("plane" if on else "order", UiKit.NAVY if on else UiKit.INK_0)
	_obj_body.add_theme_stylebox_override("panel", UiKit.boxm(Color(UiKit.NAVY, 0.92) if on else UiKit.SHADE, Vector4(18, 11, 22, 13)))
	_obj_caption.add_theme_color_override("font_color", UiKit.NAVY_TEXT if on else UiKit.SIGNAL)
	_obj_caption.flap_to("BOARDING · 탑승 안내" if on else "CURRENT ORDER · 현재 지시")


# =========================================================================================
# prompt, observation, hints, warning
# =========================================================================================
func set_prompt(text: String) -> void:
	var had := has_target
	has_target = text != ""
	if has_target:
		_prompt_text.text = text
	if has_target == had:
		return
	var tw := _prompt_row.create_tween().set_parallel(true)
	if has_target:
		_prompt_row.offset_top = 82
		_prompt_row.offset_bottom = 128
		tw.tween_property(_prompt_row, "modulate:a", 1.0, 0.16)
		tw.tween_property(_prompt_row, "offset_top", 72.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_prompt_row, "offset_bottom", 118.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(_prompt_row, "modulate:a", 0.0, 0.12)


func set_inspect_progress(v: float) -> void:
	if v < 0.0 and _progress >= 0.97:
		_burst = 1.0
	_progress = v
	if v >= 0.0:
		_observe_label.text = "OBSERVING · 관찰 중 %d%%" % int(clampf(v, 0.0, 1.0) * 100.0)
		_observe_label.modulate.a = 1.0
	elif _burst > 0.9:
		_observe_label.text = "OBSERVED · 관찰 완료"
		_observe_label.add_theme_color_override("font_color", UiKit.CLEAR)
		var tw := _observe_label.create_tween()
		tw.tween_interval(0.7)
		tw.tween_property(_observe_label, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func(): _observe_label.add_theme_color_override("font_color", UiKit.SIGNAL))
	elif _observe_label.modulate.a > 0.0 and _burst <= 0.0:
		_observe_label.modulate.a = 0.0


func show_key_hints(seconds := 30.0) -> void:
	var hidden := not _keys.visible or _keys.modulate.a < 0.1
	_keys_t = seconds
	_keys.visible = true
	if hidden:
		_keys.offset_bottom = -20.0
		_keys.offset_top = -20.0
		_keys.modulate.a = 0.0
		var tw := _keys.create_tween().set_parallel(true)
		tw.tween_property(_keys, "offset_bottom", -40.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_keys, "offset_top", -40.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func flash_warning(text: String, seconds := 0.6) -> void:
	if _warn_t <= 0.0 or text != _warn_text:
		Snd.play("ui_alert", -14.0, 0.8)
		if _warn_t <= 0.0:
			_warn_age = 0.0
	_warn_text = text
	_warn_t = maxf(_warn_t, seconds)


## Rule-warning sign: an opaque plate (readable over any lighting) with a red hazard tile. Only the
## frame pulses — the text itself stays steady and high-contrast.
func _draw_warning() -> void:
	if _warn_t <= 0.0 or _warn_text == "":
		return
	var w := _warn.size.x
	var h := _warn.size.y
	var a := clampf(_warn_t * 4.0, 0.0, 1.0)
	var open := ease(clampf(_warn_age / 0.2, 0.0, 1.0), 0.3)
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.6 + 0.4 * absf(sin(t * 6.0))
	var f := UiKit.font("sans", 900)
	var fc := UiKit.font("display", 700)
	var fs := 34
	var tw := f.get_string_size(_warn_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tile := h
	var pw := (tile + 28.0 + tw + 34.0) * open
	var x0 := (w - pw) * 0.5
	var plate := Rect2(x0, 0, pw, h)
	# drop shadow + plate
	_warn.draw_rect(plate.grow(6), Color(0, 0, 0, 0.35 * a))
	_warn.draw_rect(plate, Color(0.06, 0.03, 0.03, 0.94 * a))
	if open < 0.98:
		return
	# hazard tile
	var tr := Rect2(x0, 0, tile, h)
	_warn.draw_rect(tr, Color(UiKit.ALERT, a))
	var c := tr.get_center() + Vector2(0, 2)
	var ink := Color(UiKit.INK_0, a)
	_warn.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -20), c + Vector2(22, 17), c + Vector2(-22, 17)]), ink)
	_warn.draw_line(c + Vector2(0, -7), c + Vector2(0, 6), Color(UiKit.ALERT, a), 4.0)
	_warn.draw_line(c + Vector2(0, 10), c + Vector2(0, 13), Color(UiKit.ALERT, a), 4.0)
	# pulsing frame (not the text)
	var fr := Color(UiKit.ALERT, a * pulse)
	_warn.draw_rect(Rect2(x0 + tile, 0, pw - tile, 3), fr)
	_warn.draw_rect(Rect2(x0 + tile, h - 3, pw - tile, 3), fr)
	_warn.draw_rect(Rect2(x0 + pw - 3, 0, 3, h), fr)
	# caption + message
	var tx := x0 + tile + 28.0
	_warn.draw_string(fc, Vector2(tx, 24), "WARNING · 수칙 경고", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(UiKit.ALERT.lightened(0.25), a))
	var base := h * 0.5 + 12.0 + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5 - 6.0
	_warn.draw_string(f, Vector2(tx + 2, base + 2), _warn_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6 * a))
	_warn.draw_string(f, Vector2(tx, base), _warn_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a))


func _draw_reticle() -> void:
	if player and (player.eyes > 0.5 or not player.controls_enabled):
		return
	var k := _target_k
	var r := _reticle
	r.draw_circle(Vector2.ZERO, 2.0 + k * 0.8, Color(1, 1, 1, 0.55 + 0.4 * k))
	if k > 0.01:
		r.draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 32, Color(1, 1, 1, 0.85 * k), 2.0, true)
		var d := 15.0 + (1.0 - k) * 10.0
		var l := 5.0
		var col := Color(1, 1, 1, 0.9 * k)
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var p := Vector2(d * sx, d * sy)
				r.draw_line(p, p - Vector2(l * sx, 0), col, 2.0)
				r.draw_line(p, p - Vector2(0, l * sy), col, 2.0)
	if _progress >= 0.0:
		r.draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 64, Color(1, 1, 1, 0.16), 4.0, true)
		var p := clampf(_progress, 0.0, 1.0)
		if p > 0.0:
			r.draw_arc(Vector2.ZERO, 30.0, -PI * 0.5, -PI * 0.5 + TAU * p, 64, UiKit.SIGNAL, 4.0, true)
	if _burst > 0.0:
		var b := _burst
		r.draw_arc(Vector2.ZERO, 30.0 + (1.0 - b) * 46.0, 0.0, TAU, 64, Color(UiKit.CLEAR, b), 3.0 + b * 2.0, true)
		r.draw_polyline(PackedVector2Array([Vector2(-8, 0), Vector2(-2, 6), Vector2(9, -7)]), Color(UiKit.CLEAR, b), 3.0, true)


# =========================================================================================
# subtitles
# =========================================================================================
func show_subtitle(speaker: String, text: String, duration: float) -> void:
	var who := ""
	var body := text
	if "|" in text:
		var parts := text.split("|", true, 1)
		who = parts[0]
		body = parts[1]
	for c in _sub_chip_slot.get_children():
		c.queue_free()
	var chip: Control
	match speaker:
		"radio":
			chip = UiKit.chip("RADIO · %s" % who, UiKit.OPS, Color("13283a"), "radio", 16)
		"pa":
			chip = UiKit.chip("PA · 안내방송", UiKit.SIGNAL, Color("3a2c05"), "speaker", 16)
		"self":
			chip = UiKit.chip(who if who != "" else "나", UiKit.TEXT_DIM, Color(0.12, 0.14, 0.17, 0.85), "", 16)
		_:
			chip = UiKit.chip(who if who != "" else "SYSTEM", UiKit.TEXT_DIM, Color(0.12, 0.14, 0.17, 0.85), "info", 16)
	for ic in chip.find_children("*", "UiIcon", true, false):
		(ic as UiIcon).animated = speaker in ["radio", "pa"]
	_sub_chip_slot.add_child(chip)
	_sub_text.add_theme_color_override("font_color", Color(0.86, 0.87, 0.9) if speaker == "self" else Color(0.97, 0.97, 0.97))
	_sub_text.text = body
	var was := _sub_root.visible and _sub_root.modulate.a > 0.5
	_sub_root.visible = true
	_sub_root.modulate.a = 1.0
	_sub_time = duration
	UiFx.typewrite(_sub_text, clampf(body.length() * 0.022, 0.2, 0.9))
	if not was:
		chip.modulate.a = 0.0
		UiFx.fade(chip, 1.0, 0.18)


# =========================================================================================
# toasts
# =========================================================================================
const NOTE_KINDS := {
	"task": ["ORDER · 지시", "order"],
	"alert": ["URGENT · 긴급", "warn"],
	"good": ["CONFIRMED · 확인", "check"],
	"bad": ["WARNING · 경고", "warn"],
	"info": ["SYSTEM · 안내", "info"],
}


func add_note(text: String, kind: String) -> void:
	var accent := UiKit.OPS
	match kind:
		"task":
			accent = UiKit.SIGNAL
		"alert":
			accent = UiKit.WARN
		"good":
			accent = UiKit.CLEAR
		"bad":
			accent = UiKit.ALERT
	var meta: Array = NOTE_KINDS.get(kind, NOTE_KINDS.info)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.boxm(Color(0.035, 0.043, 0.055, 0.9), Vector4.ZERO))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = Vector2(560, 0)
	panel.custom_minimum_size = Vector2(560, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(h)
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(56, 0)
	tile.add_theme_stylebox_override("panel", UiKit.box(accent, Color(0, 0, 0, 0), 0, 0, 0))
	h.add_child(tile)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(cc)
	cc.add_child(UiIcon.make(meta[1], 26, UiKit.INK_0))
	var body := MarginContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [["margin_left", 16], ["margin_top", 11], ["margin_right", 16], ["margin_bottom", 13]]:
		body.add_theme_constant_override(side[0], side[1])
	h.add_child(body)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(v)
	v.add_child(UiKit.caption(meta[0], accent, 14))
	var l := UiKit.label(text, 17, UiKit.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(472, 0)
	v.add_child(l)
	var rec := {"node": panel, "life": 5.0 if kind != "alert" else 7.0, "max": 5.0 if kind != "alert" else 7.0, "accent": accent}
	panel.draw.connect(func():
		var rem := clampf(rec.life / rec.max, 0.0, 1.0)
		panel.draw_rect(Rect2(56, panel.size.y - 2, (panel.size.x - 56) * rem, 2), accent))
	_notes_root.add_child(panel)
	_notes.insert(0, rec)
	panel.position = Vector2(600, 0)
	panel.modulate.a = 0.0
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "position:x", 0.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)
	tile.modulate = Color(1.8, 1.8, 1.8)
	tw.tween_property(tile, "modulate", Color.WHITE, 0.5)
	while _notes.size() > 4:
		_dismiss(_notes[_notes.size() - 1])


func _dismiss(rec: Dictionary) -> void:
	_notes.erase(rec)
	var panel: Control = rec.node
	if not is_instance_valid(panel):
		return
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "position:x", 600.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(panel, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(panel.queue_free)


func _update_notes(delta: float) -> void:
	var y := 0.0
	for rec in _notes.duplicate():
		var panel: Control = rec.node
		if not is_instance_valid(panel):
			_notes.erase(rec)
			continue
		rec.life -= delta
		if rec.life <= 0.0:
			_dismiss(rec)
			continue
		panel.position.y = lerpf(panel.position.y, y, 1.0 - exp(-delta * 14.0))
		panel.queue_redraw()
		y += panel.size.y + 8.0


func set_visible_all(v: bool) -> void:
	visible = v
