class_name Tablet
extends Control
## The inspector's rugged work tablet: generated bezel art (assets/ui/tablet_bezel.png) around an OPS
## app — work orders + judgment report, photo album, map, records, camera and the night lighting plan.
## Late in the game the same app turns into BOARDING INFORMATION.

signal closed
signal camera_requested

const TEX_SCREEN := Rect2(147, 136, 1243, 718)   # display area inside tablet_bezel.png (pixels)
const TEX_DEVICE_CENTER := Vector2(768, 506)
const TEX_SIZE := Vector2(1536, 1024)
const ART_SCALE := 1.08

var ui: GameUI
var director: ShiftDirector
var boarding_mode := false:
	set(v):
		boarding_mode = v
		if is_inside_tree():
			_apply_mode()

var _backdrop: Control
var _rig: Control
var _screen: Control
var _power_fx: Control
var _power_p := 1.0
var _status_bar: PanelContainer
var _app_label: Label
var _header_title: FlapLabel
var _header_clock: Label
var _tab_bar: Control
var _tab_row: HBoxContainer
var _tab_indicator: ColorRect
var _tabs := {}               # key -> {button, icon, label}
var _pages := {}
var _current_tab := "tasks"
var _content: Control
var _task_list: VBoxContainer
var _task_caption: Label
var _detail: VBoxContainer
var _detail_panel: PanelContainer
var _stamp_layer: Control
var _selected: Task
var _erosion_meter: ErosionMeter
var _erosion_state: Label
var _countdown: Label
var _album_grid: GridContainer
var _album_viewer: Control
var _album_tex: TextureRect
var _album_caption: Label
var _records_list: VBoxContainer
var _records_body: RichTextLabel
var _power_buttons := {}
var _power_info: Label
var _power_meter: HBoxContainer
var _map: MapView
var _camera_info: Label
var _film_row: HBoxContainer
var _anim: Tween
var _closing := false


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	_backdrop = UiKit.backdrop(Color(0.02, 0.025, 0.035, 0.5), 2.4)
	add_child(_backdrop)
	var device := Control.new()
	device.set_anchors_preset(Control.PRESET_CENTER)
	var s := ART_SCALE
	device.offset_left = -TEX_DEVICE_CENTER.x * s
	device.offset_top = -TEX_DEVICE_CENTER.y * s
	device.offset_right = device.offset_left + TEX_SIZE.x * s
	device.offset_bottom = device.offset_top + TEX_SIZE.y * s
	device.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(device)
	_rig = Control.new()
	UiKit.full_rect(_rig)
	_rig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig.draw.connect(_draw_rig_shadow)
	device.add_child(_rig)
	var bezel := UiArt.tex("tablet_bezel")
	if bezel:
		var tr := TextureRect.new()
		tr.texture = bezel
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		UiKit.full_rect(tr)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_rig.add_child(tr)
	else:
		_rig.draw.connect(_draw_fallback_bezel)
	_screen = Panel.new()
	_screen.position = TEX_SCREEN.position * s
	_screen.size = TEX_SCREEN.size * s
	_screen.clip_contents = true
	_screen.add_theme_stylebox_override("panel", UiKit.box(UiKit.SCREEN, Color(0, 0, 0, 0), 18, 0, 0))
	_rig.add_child(_screen)
	var v := VBoxContainer.new()
	UiKit.full_rect(v)
	v.add_theme_constant_override("separation", 0)
	_screen.add_child(v)
	_build_status_bar(v)
	_build_tab_bar(v)
	var pad := MarginContainer.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		pad.add_theme_constant_override(side, 18)
	v.add_child(pad)
	_content = Control.new()
	_content.clip_contents = true
	pad.add_child(_content)
	_build_tasks_page(_content)
	_build_album_page(_content)
	_build_map_page(_content)
	_build_records_page(_content)
	_build_camera_page(_content)
	_build_power_page(_content)
	_build_footer(v)
	var glass := Control.new()
	UiKit.full_rect(glass)
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glass.draw.connect(_draw_glass.bind(glass))
	_screen.add_child(glass)
	_power_fx = Control.new()
	UiKit.full_rect(_power_fx)
	_power_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_fx.draw.connect(_draw_power_fx)
	_screen.add_child(_power_fx)
	Events.tasks_changed.connect(refresh)
	Events.erosion_changed.connect(func(_v): _refresh_erosion())


# =========================================================================================
# chrome: status bar, tabs, footer, glass, power-on
# =========================================================================================
func _build_status_bar(parent: Control) -> void:
	_status_bar = PanelContainer.new()
	_status_bar.custom_minimum_size = Vector2(0, 46)
	parent.add_child(_status_bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	_status_bar.add_child(h)
	_app_label = UiKit.label("SEOHAE OPS", 18, UiKit.OPS, "display", 700)
	_app_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_app_label)
	_header_title = FlapLabel.make("MAINTENANCE TASKS", 18, UiKit.TEXT_DIM, "display", 600)
	_header_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_header_title)
	var sig := UiIcon.make("signal", 20, UiKit.TEXT_DIM)
	sig.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sig)
	_header_clock = UiKit.label("", 18, UiKit.TEXT, "mono", 700)
	_header_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_header_clock)
	var bat := UiIcon.make("battery", 26, UiKit.TEXT_DIM)
	bat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bat)
	var pct := UiKit.label("78%", 15, UiKit.TEXT_DIM, "mono")
	pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(pct)
	_apply_mode()


func _apply_mode() -> void:
	if _status_bar == null:
		return
	var bg := UiKit.NAVY if boarding_mode else UiKit.SCREEN_2
	var sb := UiKit.boxm(bg, Vector4(22, 0, 22, 0))
	sb.border_width_bottom = 1
	sb.border_color = Color("2a4486") if boarding_mode else UiKit.SCREEN_LINE
	_status_bar.add_theme_stylebox_override("panel", sb)
	_app_label.add_theme_color_override("font_color", UiKit.NAVY_TEXT if boarding_mode else UiKit.OPS)
	_header_title.add_theme_color_override("font_color", Color("9fb3e0") if boarding_mode else UiKit.TEXT_DIM)
	_header_title.flap_to("BOARDING INFORMATION" if boarding_mode else "MAINTENANCE TASKS", visible)


func _build_tab_bar(parent: Control) -> void:
	_tab_bar = Control.new()
	_tab_bar.custom_minimum_size = Vector2(0, 56)
	_tab_bar.draw.connect(func(): _tab_bar.draw_line(Vector2(0, 55.5), Vector2(_tab_bar.size.x, 55.5), UiKit.SCREEN_LINE, 1.0))
	parent.add_child(_tab_bar)
	_tab_row = HBoxContainer.new()
	UiKit.full_rect(_tab_row)
	_tab_row.offset_left = 10
	_tab_row.add_theme_constant_override("separation", 0)
	_tab_bar.add_child(_tab_row)
	for t in [["tasks", "점검 지시", "order"], ["album", "점검 앨범", "album"], ["map", "구역 지도", "map"],
			["records", "기록", "records"], ["camera", "카메라", "camera"], ["power", "야간 조명 배분", "power"]]:
		_tab_row.add_child(_make_tab(t[0], t[1], t[2]))
	_tab_indicator = ColorRect.new()
	_tab_indicator.color = UiKit.SIGNAL
	_tab_indicator.size = Vector2(0, 3)
	_tab_indicator.position = Vector2(0, 53)
	_tab_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab_bar.add_child(_tab_indicator)


func _make_tab(key: String, title: String, icon_name: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, UiKit.empty_box())
	b.custom_minimum_size = Vector2(72 + title.length() * 19, 56)
	var h := HBoxContainer.new()
	UiKit.full_rect(h)
	h.offset_left = 20
	h.offset_right = -18
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic := UiIcon.make(icon_name, 22, UiKit.TEXT_DIM)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := UiKit.label(title, 18, UiKit.TEXT_DIM, "sans", 500)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_FILL
	h.add_child(l)
	b.pressed.connect(_show_tab.bind(key))
	b.mouse_entered.connect(func():
		if _current_tab != key:
			l.add_theme_color_override("font_color", UiKit.TEXT)
			ic.color = UiKit.TEXT
			ic.queue_redraw())
	b.mouse_exited.connect(func(): _style_tab(key))
	_tabs[key] = {"button": b, "icon": ic, "label": l}
	return b


func _style_tab(key: String) -> void:
	var t: Dictionary = _tabs[key]
	var on := key == _current_tab
	var col := UiKit.SIGNAL if on else UiKit.TEXT_DIM
	(t.label as Label).add_theme_color_override("font_color", col)
	(t.label as Label).add_theme_font_override("font", UiKit.font("sans", 700 if on else 500))
	(t.icon as UiIcon).color = col
	(t.icon as UiIcon).queue_redraw()


func _move_indicator(animate: bool) -> void:
	var b: Button = _tabs[_current_tab].button
	var target_x := _tab_row.position.x + b.position.x
	var target_w := b.size.x
	if not animate or _tab_indicator.size.x <= 0.0:
		_tab_indicator.position.x = target_x
		_tab_indicator.size.x = target_w
		return
	var tw := _tab_indicator.create_tween().set_parallel(true)
	tw.tween_property(_tab_indicator, "position:x", target_x, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_tab_indicator, "size:x", target_w, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build_footer(parent: Control) -> void:
	var f := PanelContainer.new()
	var sb := UiKit.boxm(Color(0, 0, 0, 0), Vector4(22, 6, 22, 7))
	sb.border_width_top = 1
	sb.border_color = UiKit.SCREEN_LINE
	f.add_theme_stylebox_override("panel", sb)
	parent.add_child(f)
	f.add_child(UiKit.key_hints([["TAB", "닫기   ·   보고는 반드시 현장에서 관찰한 뒤에 하십시오."]], 14, UiKit.TEXT_MUTE))


func _draw_rig_shadow() -> void:
	var s := ART_SCALE
	var r := Rect2(Vector2(60, 70) * s, Vector2(1416, 900) * s)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 70
	sb.shadow_offset = Vector2(0, 26)
	sb.set_corner_radius_all(80)
	_rig.draw_style_box(sb, r)


func _draw_fallback_bezel() -> void:
	var s := ART_SCALE
	var r := Rect2(Vector2(48, 49) * s, Vector2(1440, 914) * s)
	var sb := UiKit.box(Color("23272d"), Color("33383f"), 46, 3, 0)
	_rig.draw_style_box(sb, r)
	for corner in [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]:
		var dx := 1.0 if corner.x < r.get_center().x else -1.0
		var dy := 1.0 if corner.y < r.get_center().y else -1.0
		_rig.draw_polyline(PackedVector2Array([corner + Vector2(0, 150 * dy), corner, corner + Vector2(150 * dx, 0)]), Color("e0a814"), 22.0)


func _draw_glass(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	var y := 0.0
	while y < h:
		c.draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.018), 1.0)
		y += 3.0
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.42, 0), Vector2(w * 0.16, h), Vector2(0, h)]), Color(1, 1, 1, 0.022))
	for i in 12:
		var a := 0.07 * (1.0 - i / 12.0)
		c.draw_rect(Rect2(Vector2(i, i), Vector2(w - i * 2, h - i * 2)), Color(0, 0, 0, a), false, 1.0)


func _draw_power_fx() -> void:
	var p := _power_p
	if p >= 1.0:
		return
	var w := _power_fx.size.x
	var h := _power_fx.size.y
	var glow := Color(0.82, 0.93, 1.0)
	if p < 0.3:
		var k := p / 0.3
		_power_fx.draw_rect(Rect2(0, 0, w, h), Color.BLACK)
		var lw := w * k
		_power_fx.draw_rect(Rect2((w - lw) * 0.5, h * 0.5 - 6, lw, 12), Color(glow, 0.25))
		_power_fx.draw_rect(Rect2((w - lw) * 0.5, h * 0.5 - 1, lw, 2), glow)
	elif p < 0.5:
		var k := ease((p - 0.3) / 0.2, 0.4)
		var lh := lerpf(2.0, h, k)
		_power_fx.draw_rect(Rect2(0, 0, w, (h - lh) * 0.5), Color.BLACK)
		_power_fx.draw_rect(Rect2(0, (h + lh) * 0.5, w, (h - lh) * 0.5), Color.BLACK)
		_power_fx.draw_rect(Rect2(0, (h - lh) * 0.5, w, lh), Color(UiKit.OPS.lightened(0.3), 0.85 - k * 0.3))
	else:
		var k := (p - 0.5) / 0.5
		_power_fx.draw_rect(Rect2(0, 0, w, h), Color(UiKit.OPS.lightened(0.2), (1.0 - k) * 0.5))


func _set_power(p: float) -> void:
	_power_p = p
	_power_fx.queue_redraw()


# =========================================================================================
# open / close
# =========================================================================================
func open() -> void:
	visible = true
	_closing = false
	for c in _stamp_layer.get_children():
		c.queue_free()
	_selected = director.current if director and director.current else _selected
	_tabs.power.button.visible = Game.phase == "day" and Game.cycle >= 2
	_tabs.camera.button.visible = Game.phase == "day"
	if not _tabs[_current_tab].button.visible:
		_current_tab = "tasks"
	_show_tab(_current_tab, false)
	refresh()
	if _anim:
		_anim.kill()
	_rig.pivot_offset = _rig.size * 0.5
	_rig.position = Vector2(0, 150)
	_rig.rotation = deg_to_rad(2.2)
	_rig.modulate.a = 0.0
	_anim = create_tween().set_parallel(true)
	_anim.tween_property(_rig, "position", Vector2.ZERO, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim.tween_property(_rig, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_anim.tween_property(_rig, "modulate:a", 1.0, 0.12)
	_set_power(0.0)
	_anim.tween_method(_set_power, 0.0, 1.0, 0.5).set_delay(0.12)
	(_backdrop.get_node("Blur").material as ShaderMaterial).set_shader_parameter("amount", 0.0)
	UiFx.backdrop_to(_backdrop, 1.0, 0.25)
	await get_tree().process_frame
	_move_indicator(false)
	if _current_tab == "tasks":
		UiFx.stagger(_task_list.get_children(), 0.04, 0.2, 0.32)


## Slide the device away, then hide. Called by GameUI when the modal closes.
func close_anim() -> void:
	if not visible or _closing:
		return
	_closing = true
	if _anim:
		_anim.kill()
	_anim = create_tween().set_parallel(true)
	_anim.tween_property(_rig, "position", Vector2(0, 170), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_anim.tween_property(_rig, "modulate:a", 0.0, 0.16)
	UiFx.backdrop_to(_backdrop, 0.0, 0.16)
	_anim.chain().tween_callback(func():
		if _closing:
			visible = false
			_closing = false)


func _process(delta: float) -> void:
	if not visible:
		return
	_header_clock.text = Game.clock_text()
	if boarding_mode and randf() < delta * 1.2:
		_header_title.flap_to(["B0ARDING 1NFORMATI0N", "MAINTENANCE TASKS", "BOARDING INFORMATION"][randi() % 3], false)
		get_tree().create_timer(0.12).timeout.connect(func(): _header_title.flap_to("BOARDING INFORMATION", false))
	if _countdown and is_instance_valid(_countdown) and _selected and _selected.state == "responding":
		var d := maxf(_selected.deadline, 0.0)
		_countdown.text = "%02d:%02d" % [int(d) / 60, int(d) % 60]
		_countdown.modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)


func _unhandled_input(event: InputEvent) -> void:
	if visible and not _closing and (event.is_action_pressed("tablet") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		if _album_viewer.visible:
			_album_viewer.visible = false
			if event.is_action_pressed("pause"):
				return
		closed.emit()


func _show_tab(key: String, sound := true) -> void:
	var changed := key != _current_tab
	_current_tab = key
	for k in _pages.keys():
		_pages[k].visible = k == key
	for k in _tabs.keys():
		_style_tab(k)
	_move_indicator(sound)
	match key:
		"album":
			_refresh_album()
		"records":
			_refresh_records()
		"power":
			_refresh_power()
		"camera":
			_refresh_camera()
	if sound:
		Snd.play("ui_tap", -10.0)
	if changed and sound:
		var page: Control = _pages[key]
		page.position = Vector2(26, 0)
		page.modulate.a = 0.0
		var tw := page.create_tween().set_parallel(true)
		tw.tween_property(page, "position", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(page, "modulate:a", 1.0, 0.16)


# =========================================================================================
# tasks
# =========================================================================================
func _build_tasks_page(parent: Control) -> void:
	var page := HBoxContainer.new()
	UiKit.full_rect(page)
	page.add_theme_constant_override("separation", 18)
	parent.add_child(page)
	_pages["tasks"] = page
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(420, 0)
	left.add_theme_constant_override("separation", 8)
	page.add_child(left)
	_task_caption = UiKit.caption("WORK ORDERS · 근무 지시", UiKit.TEXT_MUTE, 15)
	left.add_child(_task_caption)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_task_list = VBoxContainer.new()
	_task_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_task_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_task_list)
	var ebox := PanelContainer.new()
	ebox.add_theme_stylebox_override("panel", UiKit.boxm(UiKit.SCREEN_3, Vector4(16, 12, 16, 14)))
	left.add_child(ebox)
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 10)
	ebox.add_child(ev)
	var eh := HBoxContainer.new()
	ev.add_child(eh)
	var ecap := UiKit.caption("TERMINAL SYSTEM · 침식도", UiKit.TEXT_DIM, 15)
	ecap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eh.add_child(ecap)
	_erosion_state = UiKit.caption("", UiKit.CLEAR, 15)
	eh.add_child(_erosion_state)
	_erosion_meter = ErosionMeter.new()
	_erosion_meter.custom_minimum_size = Vector2(0, 12)
	ev.add_child(_erosion_meter)
	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(holder)
	_detail_panel = PanelContainer.new()
	UiKit.full_rect(_detail_panel)
	_detail_panel.add_theme_stylebox_override("panel", UiKit.boxm(UiKit.SCREEN_2, Vector4(32, 26, 32, 28)))
	holder.add_child(_detail_panel)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 14)
	_detail_panel.add_child(_detail)
	_stamp_layer = Control.new()
	UiKit.full_rect(_stamp_layer)
	_stamp_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_stamp_layer)


func refresh() -> void:
	if not is_inside_tree():
		return
	_refresh_erosion()
	for c in _task_list.get_children():
		c.queue_free()
	if director == null:
		return
	if boarding_mode:
		_build_boarding_pass()
		return
	if _selected == null or not director.tasks.has(_selected):
		_selected = director.current
	var open_n := 0
	for task in director.tasks:
		if task.state != "done":
			open_n += 1
		_task_list.add_child(_task_row(task))
	_task_caption.text = "WORK ORDERS · 근무 지시 %d" % open_n
	_build_detail()


func _task_row(task: Task) -> Button:
	var icon := "circle"
	var col := UiKit.TEXT_MUTE
	var title_col := UiKit.BODY
	match task.state:
		"active":
			icon = "play"
			col = UiKit.SIGNAL
			title_col = UiKit.TEXT
		"responding":
			icon = "warn"
			col = UiKit.WARN
			title_col = UiKit.TEXT
		"done":
			var ok: bool = task.result in ["correct", "cleared", "done"]
			icon = "check" if ok else "cross"
			col = UiKit.CLEAR if ok else UiKit.ALERT
			title_col = UiKit.TEXT_DIM
	if task.urgent and task.state != "done":
		col = UiKit.WARN
	var sel := task == _selected
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(404, 62)
	var normal := UiKit.boxm(UiKit.SCREEN_SEL if sel else UiKit.SCREEN_3, Vector4(16, 0, 12, 0))
	if sel:
		normal.border_width_left = 4
		normal.border_color = UiKit.SIGNAL
	var hover := UiKit.boxm(UiKit.SCREEN_SEL, Vector4(16, 0, 12, 0))
	hover.border_width_left = 4
	hover.border_color = UiKit.SIGNAL if sel else UiKit.TEXT_MUTE
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("hover_pressed", hover)
	b.add_theme_stylebox_override("focus", UiKit.empty_box())
	var h := HBoxContainer.new()
	UiKit.full_rect(h)
	h.offset_left = 18
	h.offset_right = -12
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic := UiIcon.make(icon, 20, col, task.state in ["active", "responding"])
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tv)
	var tl := UiKit.label(task.title + ("  (선택)" if task.optional else ""), 17, title_col, "sans", 700 if sel else 500)
	tl.clip_text = true
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tv.add_child(tl)
	tv.add_child(UiKit.label(task.status_text(), 13, col))
	b.pressed.connect(func():
		_selected = task
		Snd.play("ui_tap", -10.0)
		refresh())
	b.mouse_entered.connect(func(): Snd.play("ui_click", -18.0, 1.2))
	return b


func _build_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	_countdown = null
	var task := _selected
	if task == null:
		var empty := VBoxContainer.new()
		empty.alignment = BoxContainer.ALIGNMENT_CENTER
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty.add_theme_constant_override("separation", 12)
		_detail.add_child(empty)
		var ic := UiIcon.make("order", 56, UiKit.TEXT_MUTE)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		empty.add_child(ic)
		var t := UiKit.label("현재 지시 없음", 26, UiKit.TEXT_DIM, "sans", 700)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_child(t)
		var s := UiKit.label("새 지시를 기다리십시오.", 18, UiKit.TEXT_MUTE)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_child(s)
		return
	_detail.add_child(UiKit.label("WORK ORDER %s · %s" % [task.id, "INSPECT" if task.kind == "inspect" else "TASK"], 15, UiKit.TEXT_MUTE, "mono"))
	var title := UiKit.label(task.title, 36, UiKit.TEXT, "sans", 900)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(title)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 10)
	_detail.add_child(chips)
	if task.urgent and task.state != "done":
		chips.add_child(UiKit.chip("URGENT · 긴급", UiKit.INK_0, UiKit.WARN, "warn", 15))
	if task.location != "":
		chips.add_child(UiKit.chip(str(Terminal.ZONE_NAMES.get(task.location, task.location)), UiKit.OPS, Color("13283a"), "pin", 15))
	var st_col := UiKit.SIGNAL if task.state != "done" else UiKit.TEXT_DIM
	chips.add_child(UiKit.chip(task.status_text(), st_col, Color(st_col, 0.14), "", 15))
	var f: Facility = director.t.facility(task.facility_id) if task.facility_id != "" else null
	if f:
		chips.add_child(UiKit.chip("시설: " + f.describe_state(), UiKit.TEXT_DIM, Color(1, 1, 1, 0.05), "", 15))
	var body := UiKit.rich(task.detail, 20, UiKit.BODY)
	_detail.add_child(body)
	if task.kind != "inspect":
		return
	_detail.add_child(UiKit.spacer(false))
	if task.state == "responding":
		_build_response_block(task)
		return
	if task.state != "active":
		return
	var reason := director.can_report(task)
	if reason != "":
		var rh := HBoxContainer.new()
		rh.add_theme_constant_override("separation", 10)
		_detail.add_child(rh)
		var li := UiIcon.make("lock", 20, UiKit.TEXT_MUTE)
		li.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		rh.add_child(li)
		var rl := UiKit.label(reason, 17, UiKit.TEXT_DIM)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rh.add_child(rl)
	_detail.add_child(UiKit.caption("JUDGMENT REPORT · 판정 보고", UiKit.TEXT_MUTE, 15))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_detail.add_child(row)
	row.add_child(_report_button(task, false, reason == ""))
	row.add_child(_report_button(task, true, reason == ""))


func _report_button(task: Task, anomaly: bool, enabled: bool) -> Button:
	var col := UiKit.ALERT if anomaly else UiKit.CLEAR
	var bg := Color("2a0f0d") if anomaly else Color("0f1f1c")
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 112)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.disabled = not enabled
	b.add_theme_stylebox_override("normal", UiKit.box(bg, col, 0, 2, 0))
	b.add_theme_stylebox_override("hover", UiKit.box(bg.lightened(0.08), col.lightened(0.2), 0, 4, 0))
	b.add_theme_stylebox_override("pressed", UiKit.box(Color(col, 0.35), col, 0, 4, 0))
	b.add_theme_stylebox_override("hover_pressed", UiKit.box(Color(col, 0.35), col, 0, 4, 0))
	b.add_theme_stylebox_override("disabled", UiKit.box(Color("121820"), Color("26303b"), 0, 2, 0))
	b.add_theme_stylebox_override("focus", UiKit.empty_box())
	var h := HBoxContainer.new()
	UiKit.full_rect(h)
	h.offset_left = 26
	h.add_theme_constant_override("separation", 18)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var fg := col if enabled else Color("4a5562")
	var ic := UiIcon.make(("warn" if anomaly else "check_circle") if enabled else "lock", 50, fg)
	ic.stroke = 2.6
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", -4)
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tv)
	tv.add_child(UiKit.label("이상" if anomaly else "정상", 34, fg, "sans", 900))
	tv.add_child(UiKit.label("ANOMALY" if anomaly else "NORMAL", 19, fg, "display", 700))
	b.pressed.connect(_report.bind(task, anomaly))
	b.mouse_entered.connect(func():
		if b.disabled:
			return
		Snd.play("ui_click", -14.0, 0.9 if anomaly else 1.1)
		b.pivot_offset = b.size * 0.5
		b.create_tween().tween_property(b, "scale", Vector2(1.02, 1.04), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT))
	b.mouse_exited.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))
	return b


func _build_response_block(task: Task) -> void:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiKit.boxm(Color("2a0f0d"), Vector4(24, 18, 24, 20), UiKit.ALERT, 2))
	_detail.add_child(box)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 26)
	box.add_child(h)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", -6)
	h.add_child(tv)
	tv.add_child(UiKit.caption("RESPONSE WINDOW · 대응 제한", UiKit.ALERT, 15))
	_countdown = UiKit.label("00:00", 72, UiKit.ALERT, "display", 700)
	tv.add_child(_countdown)
	var rv := VBoxContainer.new()
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.add_theme_constant_override("separation", 12)
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(rv)
	var msg := UiKit.rich("[b]이상 판정 접수됨.[/b] 근무 수칙에서 해당 시설 페이지를 찾아 지시대로 대응하십시오.", 19, Color("ffc9c2"))
	rv.add_child(msg)
	rv.add_child(UiKit.key_hints([["B", "근무 수칙 열기"]], 16, Color("ffc9c2")))


func _report(task: Task, anomaly: bool) -> void:
	if _closing:
		return
	director.report(task, anomaly)
	for c in _stamp_layer.get_children():
		c.queue_free()
	var stamp := StampMark.make(["이상", "ANOMALY"] if anomaly else ["정상", "NORMAL"], UiKit.ALERT if anomaly else UiKit.CLEAR,
		"rect", "stamp_anomaly" if anomaly else "stamp_normal", Vector2(480, 320))
	stamp.angle_deg = randf_range(-11.0, -5.0)
	stamp.position = (_stamp_layer.size - stamp.size) * 0.5 + Vector2(randf_range(-30, 30), -20)
	_stamp_layer.add_child(stamp)
	UiFx.slam(stamp, 0.26)
	get_tree().create_timer(0.1).timeout.connect(func():
		Snd.play("clock_punch", -4.0, 1.25 if not anomaly else 1.0)
		UiFx.shake(_rig, 9.0, 0.24))
	refresh()
	if task.state == "done" or task.state == "responding":
		await get_tree().create_timer(0.8).timeout
		closed.emit()


func _refresh_erosion() -> void:
	if _erosion_meter == null:
		return
	var e := Game.erosion
	var st := UiKit.erosion_state(e)
	_erosion_meter.value = e
	_erosion_meter.color = st[0]
	_erosion_meter.queue_redraw()
	var txt: String = st[1]
	if e >= 75.0:
		txt = "위험 — 시스템이 당신을 인식하고 있습니다"
	_erosion_state.text = "%s · %d%%" % [txt, int(e)]
	_erosion_state.add_theme_color_override("font_color", st[0])


func _build_boarding_pass() -> void:
	for c in _detail.get_children():
		c.queue_free()
	_task_caption.text = "MAINTENANCE TASKS — 0건"
	var card := BoardingPassCard.make(800.0, Game.player_name)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail.add_child(card)
	var warn := UiKit.label("탑승구가 곧 닫힙니다.", 24, UiKit.ALERT, "sans", 700)
	_detail.add_child(warn)
	# the pass "prints": fades in a beat after the screen flips to BOARDING INFORMATION
	card.modulate.a = 0.0
	warn.modulate.a = 0.0
	var tw := card.create_tween()
	tw.tween_interval(0.25)
	tw.tween_callback(func(): Snd.play("camera_shutter", -16.0, 0.6))
	tw.tween_property(card, "modulate:a", 1.0, 0.45)
	tw.tween_callback(func(): UiFx.flicker_on(warn, 0.0, false))


# =========================================================================================
# album
# =========================================================================================
func _build_album_page(parent: Control) -> void:
	var page := Control.new()
	UiKit.full_rect(page)
	parent.add_child(page)
	_pages["album"] = page
	var scroll := ScrollContainer.new()
	UiKit.full_rect(scroll)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	_album_grid = GridContainer.new()
	_album_grid.columns = 4
	_album_grid.add_theme_constant_override("h_separation", 14)
	_album_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_album_grid)
	_album_viewer = PanelContainer.new()
	_album_viewer.add_theme_stylebox_override("panel", UiKit.boxm(Color(0.01, 0.015, 0.02, 0.97), Vector4(12, 12, 12, 12)))
	UiKit.full_rect(_album_viewer)
	_album_viewer.visible = false
	page.add_child(_album_viewer)
	var vv := VBoxContainer.new()
	vv.add_theme_constant_override("separation", 10)
	_album_viewer.add_child(vv)
	_album_tex = TextureRect.new()
	_album_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_album_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_album_tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_album_tex.mouse_filter = Control.MOUSE_FILTER_STOP
	_album_tex.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_album_viewer.visible = false)
	vv.add_child(_album_tex)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	vv.add_child(row)
	_album_caption = UiKit.label("", 18, UiKit.TEXT)
	_album_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_album_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_album_caption)
	row.add_child(UiKit.button("닫기", 17, func(): _album_viewer.visible = false))


func _refresh_album() -> void:
	_album_viewer.visible = false
	for c in _album_grid.get_children():
		c.queue_free()
	if Game.photos.is_empty():
		var empty := VBoxContainer.new()
		empty.add_theme_constant_override("separation", 12)
		empty.custom_minimum_size = Vector2(1200, 380)
		empty.alignment = BoxContainer.ALIGNMENT_CENTER
		_album_grid.add_child(empty)
		var ic := UiIcon.make("album", 60, UiKit.TEXT_MUTE)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		empty.add_child(ic)
		var l := UiKit.label("저장된 사진이 없습니다.", 24, UiKit.TEXT_DIM, "sans", 700)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_child(l)
		var s := UiKit.label("낮 근무 중 [카메라] 탭에서 시설의 정상 상태를 촬영하십시오.", 18, UiKit.TEXT_MUTE)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_child(s)
		return
	var cells := []
	for i in Game.photos.size():
		var cell := _photo_card(i)
		_album_grid.add_child(cell)
		cells.append(cell)
	UiFx.stagger(cells, 0.035, 0.18)


func _photo_card(i: int) -> Button:
	var ph: Dictionary = Game.photos[i]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(312, 218)
	b.add_theme_stylebox_override("normal", UiKit.box(UiKit.INK_2, UiKit.SCREEN_LINE, 0, 1, 0))
	b.add_theme_stylebox_override("hover", UiKit.box(UiKit.INK_2, UiKit.SIGNAL, 0, 2, 0))
	b.add_theme_stylebox_override("pressed", UiKit.box(UiKit.INK_2, UiKit.SIGNAL, 0, 2, 0))
	b.add_theme_stylebox_override("focus", UiKit.empty_box())
	var v := VBoxContainer.new()
	UiKit.full_rect(v)
	v.offset_left = 7
	v.offset_top = 7
	v.offset_right = -7
	v.offset_bottom = -7
	v.add_theme_constant_override("separation", 7)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var tr := TextureRect.new()
	tr.texture = ph.tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.custom_minimum_size = Vector2(298, 168)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.clip_contents = true
	v.add_child(tr)
	var parts := str(ph.label).split(" · ")
	var stamp := UiKit.label(parts[parts.size() - 1], 14, UiKit.SIGNAL, "mono", 700)
	stamp.add_theme_constant_override("outline_size", 4)
	stamp.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	stamp.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	stamp.offset_left = -200
	stamp.offset_top = -26
	stamp.offset_right = -8
	stamp.offset_bottom = -6
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(stamp)
	var cap := HBoxContainer.new()
	cap.add_theme_constant_override("separation", 8)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(cap)
	cap.add_child(UiKit.chip("#%02d" % (i + 1), UiKit.INK_0, UiKit.TEXT_DIM, "", 13))
	var l := UiKit.label(parts[0], 15, UiKit.BODY)
	l.clip_text = true
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap.add_child(l)
	b.pressed.connect(_view_photo.bind(i))
	return b


func _view_photo(i: int) -> void:
	var ph: Dictionary = Game.photos[i]
	_album_tex.texture = ph.tex
	_album_caption.text = "#%02d   %s" % [i + 1, ph.label]
	_album_viewer.visible = true
	_album_viewer.modulate.a = 0.0
	_album_tex.pivot_offset = _album_tex.size * 0.5
	_album_tex.scale = Vector2(0.94, 0.94)
	var tw := _album_viewer.create_tween().set_parallel(true)
	tw.tween_property(_album_viewer, "modulate:a", 1.0, 0.16)
	tw.tween_property(_album_tex, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Snd.play("camera_shutter", -18.0, 1.6)


# --- map -----------------------------------------------------------------------------------
func _build_map_page(parent: Control) -> void:
	_map = MapView.new()
	UiKit.full_rect(_map)
	parent.add_child(_map)
	_pages["map"] = _map


func bind_world(director_ref: ShiftDirector) -> void:
	director = director_ref
	_map.terminal = director.t
	_map.player = director.p
	_map.director = director


# --- records -------------------------------------------------------------------------------
func _build_records_page(parent: Control) -> void:
	var page := HBoxContainer.new()
	UiKit.full_rect(page)
	page.add_theme_constant_override("separation", 18)
	parent.add_child(page)
	_pages["records"] = page
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(380, 0)
	left.add_theme_constant_override("separation", 8)
	page.add_child(left)
	left.add_child(UiKit.caption("RECORDS · 수집한 기록", UiKit.TEXT_MUTE, 15))
	_records_list = VBoxContainer.new()
	_records_list.add_theme_constant_override("separation", 6)
	left.add_child(_records_list)
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_stylebox_override("panel", UiKit.boxm(UiKit.SCREEN_2, Vector4(32, 26, 32, 26)))
	page.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_records_body = UiKit.rich("", 19, UiKit.BODY)
	_records_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_records_body)


func _refresh_records() -> void:
	for c in _records_list.get_children():
		c.queue_free()
	var any := false
	for id in RulesDB.CLUES.keys():
		if not Game.has_clue(id):
			continue
		any = true
		var c: Dictionary = RulesDB.CLUES[id]
		var body := str(c.body)
		if id == "syslog":
			body = body % Game.player_name
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(370, 54)
		b.add_theme_stylebox_override("normal", UiKit.boxm(UiKit.SCREEN_3, Vector4(14, 0, 12, 0)))
		b.add_theme_stylebox_override("hover", UiKit.boxm(UiKit.SCREEN_SEL, Vector4(14, 0, 12, 0)))
		b.add_theme_stylebox_override("pressed", UiKit.boxm(UiKit.SCREEN_SEL, Vector4(14, 0, 12, 0)))
		b.add_theme_stylebox_override("focus", UiKit.empty_box())
		var h := HBoxContainer.new()
		UiKit.full_rect(h)
		h.offset_left = 14
		h.add_theme_constant_override("separation", 12)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		var ic := UiIcon.make("records", 20, UiKit.OPS)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		var l := UiKit.label(c.title, 17, UiKit.TEXT, "sans", 500)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_FILL
		h.add_child(l)
		var is_log: bool = id == "syslog"
		b.pressed.connect(func():
			Snd.play("page_flip", -14.0, 1.2)
			_records_body.add_theme_font_override("normal_font", UiKit.font("mono" if is_log else "sans", 400))
			_records_body.add_theme_font_override("bold_font", UiKit.font("mono" if is_log else "sans", 700))
			_records_body.text = "[b]%s[/b]\n\n%s" % [c.title, body]
			UiFx.typewrite(_records_body, clampf(body.length() * 0.004, 0.2, 0.7)))
		_records_list.add_child(b)
	_records_body.text = "" if any else "[color=#7c8590]아직 수집한 기록이 없습니다. 터미널 곳곳의 문서를 살펴보십시오.[/color]"
	UiFx.stagger(_records_list.get_children(), 0.035, 0.18)


# --- camera -------------------------------------------------------------------------------------
func _build_camera_page(parent: Control) -> void:
	var page := VBoxContainer.new()
	UiKit.full_rect(page)
	page.add_theme_constant_override("separation", 18)
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(page)
	_pages["camera"] = page
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	page.add_child(head)
	head.add_child(UiIcon.make("camera", 56, UiKit.SIGNAL))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	head.add_child(hv)
	hv.add_child(UiKit.caption("INSPECTION CAMERA", UiKit.TEXT_MUTE, 15))
	hv.add_child(UiKit.label("점검 카메라", 32, UiKit.TEXT, "sans", 900))
	var desc := UiKit.rich("낮 근무 중 시설의 [b]정상 상태[/b]를 촬영해 두면, 밤에 [b]점검 앨범[/b]에서 비교할 수 있습니다.\n하루 촬영 가능 장수는 제한되어 있습니다. 무엇을 찍을지 신중하게 고르십시오.\n\n[color=#9aa3ae]추천: FIDS 전광판(테스트 목록) · 수하물 벨트(가방 개수·색) · X-ray 판독 화면 · 무빙워크 방향 · 탑승구 대기석 배치[/color]", 20, UiKit.BODY)
	desc.custom_minimum_size = Vector2(900, 0)
	page.add_child(desc)
	_film_row = HBoxContainer.new()
	_film_row.add_theme_constant_override("separation", 8)
	page.add_child(_film_row)
	_camera_info = UiKit.label("", 20, UiKit.SIGNAL, "sans", 700)
	page.add_child(_camera_info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	page.add_child(row)
	var b := UiKit.primary("카메라 실행", 22, func(): camera_requested.emit())
	b.custom_minimum_size = Vector2(300, 66)
	row.add_child(b)
	var hints := UiKit.key_hints([["LMB", "촬영"], ["RMB", "종료"]], 16, UiKit.TEXT_DIM)
	hints.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hints)


func _refresh_camera() -> void:
	for c in _film_row.get_children():
		c.queue_free()
	for i in Game.PHOTOS_PER_DAY:
		var left := i < Game.photos_left
		var cell := Panel.new()
		cell.custom_minimum_size = Vector2(34, 46)
		cell.add_theme_stylebox_override("panel", UiKit.box(UiKit.SIGNAL if left else Color(0, 0, 0, 0), UiKit.SIGNAL if left else UiKit.LINE, 0, 2, 0))
		_film_row.add_child(cell)
	_camera_info.text = "오늘 남은 촬영  %d / %d" % [Game.photos_left, Game.PHOTOS_PER_DAY]


# --- night lighting plan ----------------------------------------------------------------------------
func _build_power_page(parent: Control) -> void:
	var page := VBoxContainer.new()
	UiKit.full_rect(page)
	page.add_theme_constant_override("separation", 16)
	parent.add_child(page)
	_pages["power"] = page
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	page.add_child(head)
	head.add_child(UiIcon.make("power", 46, UiKit.SIGNAL))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	head.add_child(hv)
	hv.add_child(UiKit.caption("NIGHT LIGHTING PLAN", UiKit.TEXT_MUTE, 15))
	hv.add_child(UiKit.label("야간 조명 배분", 30, UiKit.TEXT, "sans", 900))
	page.add_child(UiKit.rich("야간 전력 한도 때문에 [b]최대 3개 구역[/b]만 조명을 예약할 수 있습니다. 켜 둔 구역은 밤에 관찰이 쉽고, 수칙 p.9 ③(새벽 3시)에 대비할 수 있습니다.\n[color=#9aa3ae]꺼 둔 구역은 손전등에 의지해야 합니다. 밤에도 조명 분전반에서 직접 켜고 끌 수는 있습니다.[/color]", 19, UiKit.BODY))
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 12)
	page.add_child(grid)
	for zn in ["hall", "baggage", "security", "corridor", "gates"]:
		var b := _zone_card(zn)
		grid.add_child(b)
		_power_buttons[zn] = b
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 18)
	page.add_child(foot)
	var cap := UiKit.caption("POWER BUDGET · 전력 한도", UiKit.TEXT_DIM, 15)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(cap)
	_power_meter = HBoxContainer.new()
	_power_meter.add_theme_constant_override("separation", 4)
	_power_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_power_meter)
	_power_info = UiKit.label("", 19, UiKit.SIGNAL, "sans", 700)
	_power_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_power_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	foot.add_child(_power_info)
	var confirm := UiKit.primary("배분 확정", 21, _confirm_power, UiKit.CLEAR)
	confirm.custom_minimum_size = Vector2(220, 60)
	foot.add_child(confirm)


func _zone_card(zn: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 176)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	UiKit.full_rect(v)
	v.offset_left = 18
	v.offset_top = 16
	v.offset_right = -16
	v.offset_bottom = -14
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ic := UiIcon.make("lamp", 40, UiKit.TEXT_MUTE)
	ic.name = "Icon"
	v.add_child(ic)
	var name_l := UiKit.label(Terminal.ZONE_NAMES[zn], 20, UiKit.TEXT, "sans", 700)
	v.add_child(name_l)
	var st := UiKit.caption("", UiKit.TEXT_MUTE, 14)
	st.name = "State"
	v.add_child(st)
	v.add_child(UiKit.spacer(false))
	var sw := Control.new()
	sw.name = "Switch"
	sw.custom_minimum_size = Vector2(56, 26)
	sw.set_meta("k", 0.0)
	sw.draw.connect(func():
		var k: float = sw.get_meta("k")
		sw.draw_rect(Rect2(0, 0, 56, 26), Color("232b36").lerp(UiKit.SIGNAL, k))
		sw.draw_rect(Rect2(lerpf(4, 30, k), 4, 22, 18), UiKit.TEXT_MUTE.lerp(UiKit.INK_0, k)))
	v.add_child(sw)
	b.toggled.connect(func(_on): pass)
	b.pressed.connect(_toggle_power.bind(zn))
	b.mouse_entered.connect(func(): Snd.play("ui_click", -18.0, 1.2))
	return b


func _style_zone(zn: String, on: bool, animate: bool) -> void:
	var b: Button = _power_buttons[zn]
	var bg := Color("2a2206") if on else UiKit.SCREEN_3
	var border := UiKit.SIGNAL if on else UiKit.SCREEN_LINE
	for st in ["normal", "pressed", "hover_pressed"]:
		b.add_theme_stylebox_override(st, UiKit.box(bg, border, 0, 2 if on else 1, 0))
	b.add_theme_stylebox_override("hover", UiKit.box(bg.lightened(0.04), UiKit.SIGNAL if on else UiKit.TEXT_MUTE, 0, 2, 0))
	b.add_theme_stylebox_override("focus", UiKit.empty_box())
	var ic: UiIcon = b.find_child("Icon", true, false)
	ic.set_icon("lamp_on" if on else "lamp", UiKit.SIGNAL if on else UiKit.TEXT_MUTE)
	var st_l: Label = b.find_child("State", true, false)
	st_l.text = "ON · 예약됨" if on else "OFF · 꺼짐"
	st_l.add_theme_color_override("font_color", UiKit.SIGNAL if on else UiKit.TEXT_MUTE)
	var sw: Control = b.find_child("Switch", true, false)
	var target := 1.0 if on else 0.0
	if animate:
		var tw := sw.create_tween()
		var setter := func(k: float):
			sw.set_meta("k", k)
			sw.queue_redraw()
		tw.tween_method(setter, float(sw.get_meta("k")), target, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		sw.set_meta("k", target)
		sw.queue_redraw()


func _refresh_power(animate := false) -> void:
	var n := 0
	for zn in _power_buttons.keys():
		var on := bool(Game.night_lights.get(zn, false))
		_power_buttons[zn].set_pressed_no_signal(on)
		_style_zone(zn, on, animate)
		if on:
			n += 1
	for c in _power_meter.get_children():
		c.queue_free()
	for i in 3:
		var seg := Panel.new()
		seg.custom_minimum_size = Vector2(46, 16)
		seg.add_theme_stylebox_override("panel", UiKit.box(UiKit.SIGNAL if i < n else Color("232b36"), Color(0, 0, 0, 0), 0, 0, 0))
		_power_meter.add_child(seg)
	_power_info.text = "%d / 3 구역 예약됨" % n
	_power_info.add_theme_color_override("font_color", UiKit.SIGNAL)


func _toggle_power(zn: String) -> void:
	var on := not bool(Game.night_lights.get(zn, false))
	var n := 0
	for k in Game.night_lights.keys():
		if Game.night_lights[k]:
			n += 1
	if on and n >= 3:
		Snd.play("beep_error", -8.0)
		_power_buttons[zn].set_pressed_no_signal(false)
		_power_info.text = "한도 초과 — 다른 구역을 먼저 해제하십시오."
		_power_info.add_theme_color_override("font_color", UiKit.ALERT)
		UiFx.shake(_rig, 6.0, 0.2)
		return
	Game.night_lights[zn] = on
	Snd.play("switch_heavy", -14.0, 1.3)
	_refresh_power(true)


func _confirm_power() -> void:
	Snd.play("beep_ok", -6.0)
	Events.player_action.emit("power_plan", "")
	_power_info.text = "야간 조명 배분이 확정되었습니다."
	_power_info.add_theme_color_override("font_color", UiKit.CLEAR)


# =========================================================================================
# small drawn widgets
# =========================================================================================
class ErosionMeter extends Control:
	var value := 0.0
	var color := Color("3fd0b0")
	var _shown := -1.0

	func _process(delta: float) -> void:
		if _shown < 0.0:
			_shown = value
		if absf(_shown - value) > 0.05:
			_shown = move_toward(_shown, value, delta * 45.0)
			queue_redraw()

	func _draw() -> void:
		var n := 20
		var gap := 3.0
		var w := (size.x - gap * (n - 1)) / n
		var filled := maxf(_shown, 0.0) / 100.0 * n
		var off := Color("1e2a36")
		for i in n:
			var c := off
			if i < floor(filled):
				c = color
			elif i < filled:
				c = off.lerp(color, filled - i)
			draw_rect(Rect2(i * (w + gap), 0, w, size.y), c)
