class_name Tablet
extends Control
## The inspector's rugged work tablet: generated bezel art (assets/ui/tablet_bezel.png) around the facility app —
## tonight's inspection checklist and the terminal floor plan. In SCENE 04 it loses you: no position on the plan,
## a flicker, the checklist gone and LOCATION: UNKNOWN / EXIT: NOT FOUND in its place (`lose_signal`).

signal closed

const TEX_SCREEN := Rect2(147, 136, 1243, 718)   # display area inside tablet_bezel.png (pixels)
const TEX_DEVICE_CENTER := Vector2(768, 506)
const TEX_SIZE := Vector2(1536, 1024)
const ART_SCALE := 1.08
## Checklist states: [label, chip colour]
const STATES := {"ok": ["정상", UiKit.CLEAR], "check": ["확인 필요", UiKit.WARN], "todo": ["미점검", UiKit.TEXT_MUTE]}
## The main story's tablet is a list of what you carry: [name, what it is].
const BELONGINGS := {
	"key_gate": ["열쇠", "쇠사슬 자물쇠에 맞는 작은 놋쇠 열쇠."],
	"keycard": ["키 카드", "경비 책상 서랍에 있던 직원 카드."],
	"boarding_pass": ["탑승권", "FLIGHT 000 · GATE 0. 산 적 없는 표에 내 이름이 찍혀 있다."],
	"id_card": ["신원 카드", "사진은 나인데 직함이 승객으로 바뀌어 있다."],
	"bag_tag": ["수하물표", "맡긴 적 없는 가방에 달려 있던 표. 한쪽이 찢겨 있다."],
}

var ui: GameUI
var lost := false              # SCENE 04 on: the app has no idea where you are
var checklist: Array = []      # [[item, state]] (STATES keys)
var belongings := false        # the main story: the list page shows what you carry
var passenger := false         # the check-in is done: the first row is your passenger record

var _backdrop: Control
var _rig: Control
var _screen: Control
var _power_fx: Control
var _power_p := 1.0
var _status_bar: PanelContainer
var _header_title: FlapLabel
var _header_clock: Label
var _tab_bar: Control
var _tab_row: HBoxContainer
var _tab_indicator: ColorRect
var _tabs := {}               # key -> {button, icon, label, title}
var _pages := {}
var _current_tab := "list"
var _list: VBoxContainer
var _list_caption: Label
var _list_title: Label
var _map: MapView
var _sys: Control             # LOCATION: UNKNOWN overlay
var _sys_t := 0.0
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
	var content := Control.new()
	content.clip_contents = true
	pad.add_child(content)
	_build_list_page(content)
	_build_map_page(content)
	_build_footer(v)
	_sys = Control.new()
	UiKit.full_rect(_sys)
	_sys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sys.visible = false
	_sys.draw.connect(_draw_sys)
	_screen.add_child(_sys)
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
	_show_tab("list", false)


func bind_world(terminal: Terminal, player: Player) -> void:
	_map.terminal = terminal
	_map.player = player


## The order shown on the plan (zone highlighted, place ringed) and in its side panel.
func set_target(title: String, zone := "", pos := Vector3.INF) -> void:
	_map.target_title = title
	_map.target_zone = zone
	_map.target_pos = pos


func set_checklist(items: Array) -> void:
	checklist = items.duplicate(true)
	_refresh_list()


# =========================================================================================
# chrome: status bar, tabs, footer, glass, power-on
# =========================================================================================
func _build_status_bar(parent: Control) -> void:
	_status_bar = PanelContainer.new()
	_status_bar.custom_minimum_size = Vector2(0, 46)
	var sb := UiKit.boxm(UiKit.SCREEN_2, Vector4(22, 0, 22, 0))
	sb.border_width_bottom = 1
	sb.border_color = UiKit.SCREEN_LINE
	_status_bar.add_theme_stylebox_override("panel", sb)
	parent.add_child(_status_bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	_status_bar.add_child(h)
	var app := UiKit.label("FACILITY OPS", 18, UiKit.OPS, "display", 700)
	app.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(app)
	_header_title = FlapLabel.make("NIGHT INSPECTION", 18, UiKit.TEXT_DIM, "display", 600)
	_header_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_header_title)
	var sig := UiIcon.make("signal", 20, UiKit.TEXT_DIM)
	sig.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(sig)
	_header_clock = UiKit.label("", 18, UiKit.TEXT, "display", 700)
	_header_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_header_clock)
	var bat := UiIcon.make("battery", 26, UiKit.TEXT_DIM)
	bat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bat)
	var pct := UiKit.label("64%", UiKit.MIN_TEXT, UiKit.TEXT_DIM, "display")
	pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(pct)


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
	for t in [["list", "점검 목록", "order"], ["map", "터미널 도면", "map"]]:
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
	var tw := UiKit.font("sans", 700).get_string_size(UiKit.t(title), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	b.custom_minimum_size = Vector2(72 + tw, 56)
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
	_tabs[key] = {"button": b, "icon": ic, "label": l, "title": title}
	return b


func _style_tab(key: String) -> void:
	var t: Dictionary = _tabs[key]
	var on := key == _current_tab
	var col := UiKit.SIGNAL_TEXT if on else UiKit.TEXT_DIM
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
	f.add_child(UiKit.key_hints([[Game.key_label("tablet"), "닫기"], ["A / D", "화면 전환"]], UiKit.MIN_TEXT, UiKit.TEXT_MUTE))


# =========================================================================================
# pages
# =========================================================================================
func _build_list_page(parent: Control) -> void:
	var page := VBoxContainer.new()
	UiKit.full_rect(page)
	page.add_theme_constant_override("separation", 10)
	parent.add_child(page)
	_pages["list"] = page
	_list_caption = UiKit.caption("NIGHT INSPECTION · 야간 시설 점검", UiKit.TEXT_MUTE)
	page.add_child(_list_caption)
	_list_title = UiKit.label("최종 점검 구역", 34, UiKit.TEXT, "sans", 900)
	page.add_child(_list_title)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	page.add_child(gap)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	page.add_child(_list)


func _refresh_list() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		c.queue_free()
	if belongings:
		_refresh_belongings()
		return
	for it in checklist:
		var st: Array = STATES.get(str(it[1]), STATES.todo)
		var row := PanelContainer.new()
		var sb := UiKit.boxm(UiKit.SCREEN_2, Vector4(22, 14, 22, 14))
		sb.border_width_left = 4
		sb.border_color = st[1]
		row.add_theme_stylebox_override("panel", sb)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		row.add_child(h)
		var name_l := UiKit.label(str(it[0]), 24, UiKit.TEXT, "sans", 700)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(name_l)
		var todo: bool = it[1] == "todo"
		var chip := UiKit.chip(str(st[0]), UiKit.TEXT_DIM if todo else UiKit.ink_on(st[1]), Color(0, 0, 0, 0) if todo else st[1], "", 18)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(chip)
		_list.add_child(row)


## What you carry, a row each; once the check-in is done your passenger record comes first.
func _refresh_belongings() -> void:
	if passenger:
		_list.add_child(_belonging("승객 · FLIGHT 000", "탑승 수속 완료. GATE 0으로 이동해 주십시오.", UiKit.ALERT))
	for id: String in Game.inventory:
		var it: Array = BELONGINGS.get(id, [id, ""])
		_list.add_child(_belonging(it[0], it[1], UiKit.SIGNAL_TEXT))
	if Game.inventory.is_empty() and not passenger:
		_list.add_child(UiKit.label("가진 것이 없다.", 20, UiKit.TEXT_DIM, "sans", 500))


func _belonging(title: String, body: String, edge: Color) -> Control:
	var row := PanelContainer.new()
	var sb := UiKit.boxm(UiKit.SCREEN_2, Vector4(22, 12, 22, 12))
	sb.border_width_left = 4
	sb.border_color = edge
	row.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	row.add_child(v)
	v.add_child(UiKit.label(title, 22, UiKit.TEXT, "sans", 700))
	v.add_child(UiKit.label(body, 18, UiKit.TEXT_DIM, "sans", 500))
	return row


## From the main story on: the checklist is gone, the list page is what you carry, the plan has lost you.
func show_belongings() -> void:
	lost = true
	belongings = true
	_map.show_player = false
	_header_title.flap_to("NO SIGNAL", false)
	_list_caption.text = UiKit.t("BELONGINGS · 소지품")
	_list_title.text = UiKit.t("소지품")
	(_tabs.list.label as Label).text = UiKit.t("소지품")
	_sys.visible = false
	if not Events.inventory_changed.is_connected(_refresh_list):
		Events.inventory_changed.connect(_refresh_list)
	_refresh_list()


## The check-in is done: you are a passenger now.
func set_passenger() -> void:
	passenger = true
	_header_title.flap_to("PASSENGER", false)
	_list_caption.text = UiKit.t("PASSENGER · 탑승객")
	_refresh_list()


func _build_map_page(parent: Control) -> void:
	_map = MapView.new()
	UiKit.full_rect(_map)
	_map.visible = false
	parent.add_child(_map)
	_pages["map"] = _map


func _show_tab(key: String, sound := true) -> void:
	var changed := key != _current_tab
	_current_tab = key
	for k in _pages.keys():
		_pages[k].visible = k == key
	for k in _tabs.keys():
		_style_tab(k)
	_move_indicator(sound)
	if sound:
		Snd.play("ui_tap", -10.0)
	if changed and sound:
		var page: Control = _pages[key]
		page.position = Vector2(26, 0)
		page.modulate.a = 0.0
		var tw := page.create_tween().set_parallel(true)
		tw.tween_property(page, "position", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(page, "modulate:a", 1.0, 0.16)


func current_tab() -> String:
	return _current_tab


# =========================================================================================
# SCENE 04: the app loses you
# =========================================================================================
## The plan has no marker for you any more; a moment later the screen flickers, the checklist goes and the
## system message takes its place. Await it (about four seconds).
func lose_signal() -> void:
	lost = true
	_map.show_player = false
	_header_title.flap_to("NO SIGNAL")
	await get_tree().create_timer(2.2).timeout
	Snd.play("glitch", -6.0, 0.8)
	for i in 6:
		_set_power(randf_range(0.32, 0.55) if i % 2 == 0 else 1.0)
		await get_tree().create_timer(randf_range(0.05, 0.12)).timeout
	checklist = []
	_refresh_list()
	_list_caption.text = "—"
	_set_power(1.0)
	_sys.visible = true
	_sys_t = 0.0
	Snd.play("ui_alert", -10.0, 0.7)
	await get_tree().create_timer(1.6).timeout


## Already lost (the main story): straight to LOCATION: UNKNOWN, no flicker.
func lose_signal_now() -> void:
	lost = true
	_map.show_player = false
	_header_title.flap_to("NO SIGNAL", false)
	checklist = []
	_refresh_list()
	_list_caption.text = "—"
	_sys.visible = true
	_sys_t = 10.0


func _draw_sys() -> void:
	var w := _sys.size.x
	var h := _sys.size.y
	_sys.draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.02, 0.025, 0.93))
	var mono := UiKit.font("mono", 700)
	var lines := [["LOCATION: UNKNOWN", clampf(_sys_t / 0.5, 0.0, 1.0)], ["EXIT: NOT FOUND", clampf((_sys_t - 0.7) / 0.5, 0.0, 1.0)]]
	for i in lines.size():
		var txt: String = lines[i][0]
		var k: float = lines[i][1]
		if k <= 0.0:
			continue
		var shown := txt.substr(0, int(ceil(txt.length() * k)))
		var fs := 54
		var tw := mono.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := Vector2((w - tw) * 0.5, h * 0.44 + i * 84.0)
		var jit := Vector2(randf_range(-2, 2), 0) if randf() < 0.08 and not Game.settings.reduce_motion else Vector2.ZERO
		_sys.draw_string(mono, p + jit + Vector2(3, 0), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.6, 1.0, 0.35))
		_sys.draw_string(mono, p + jit, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UiKit.ALERT, 0.95))
	if _sys_t > 1.4:
		var cap := UiKit.t("현재 위치를 확인할 수 없습니다.")
		var f := UiKit.font("sans", 500)
		var cw := f.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		_sys.draw_string(f, Vector2((w - cw) * 0.5, h * 0.44 + 170.0), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiKit.TEXT_DIM)
	var y := 0.0
	while y < h:
		_sys.draw_line(Vector2(0, y), Vector2(w, y), Color(1, 1, 1, 0.025), 1.0)
		y += 4.0


# =========================================================================================
# open / close
# =========================================================================================
func open(tab := "") -> void:
	visible = true
	_closing = false
	if tab != "":
		_show_tab(tab, false)
	_refresh_list()
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
	if _current_tab == "list":
		UiFx.stagger(_list.get_children(), 0.05, 0.2, 0.32)


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
	_header_clock.text = "--:--" if lost else Game.clock_text()
	if _sys.visible:
		_sys_t += delta
		_sys.queue_redraw()


## Tab / Esc close it (unless the story holds it open: GameUI.tablet_locked); A / D switch pages.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or _closing:
		return
	if event.is_action_pressed("tablet") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if ui == null or not ui.tablet_locked:
			closed.emit()
	elif event.is_action_pressed("ui_page_next") or event.is_action_pressed("ui_page_prev"):
		get_viewport().set_input_as_handled()
		_show_tab("map" if _current_tab == "list" else "list")


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


func _set_power(p: float) -> void:
	_power_p = p
	_power_fx.queue_redraw()


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
