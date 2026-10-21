class_name Tablet
extends Control
## The inspector's work tablet: work orders + judgment report, photo album, map, records,
## camera, and (day 2+) the night lighting plan. Turns into BOARDING INFORMATION later.

signal closed
signal camera_requested

var ui: GameUI
var director: ShiftDirector
var boarding_mode := false

var _header_title: Label
var _header_clock: Label
var _tabs: HBoxContainer
var _pages := {}
var _tab_buttons := {}
var _current_tab := "tasks"
var _task_list: VBoxContainer
var _detail: VBoxContainer
var _selected: Task
var _erosion_bar: ProgressBar
var _erosion_label: Label
var _album_grid: GridContainer
var _album_viewer: Control
var _album_tex: TextureRect
var _album_caption: Label
var _records_list: VBoxContainer
var _records_body: RichTextLabel
var _power_buttons := {}
var _power_info: Label
var _map: MapView
var _camera_info: Label
var _frame: PanelContainer


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	UiKit.full_rect(dim)
	add_child(dim)
	_frame = PanelContainer.new()
	_frame.add_theme_stylebox_override("panel", UiKit.box(Color(0.035, 0.038, 0.045), Color(0.16, 0.17, 0.2), 34, 3, 30))
	UiKit.center(_frame, Vector2(1360, 860))
	add_child(_frame)
	var screen := PanelContainer.new()
	screen.add_theme_stylebox_override("panel", UiKit.box(Color(0.03, 0.05, 0.08), Color(0.08, 0.12, 0.18), 10, 1, 18))
	_frame.add_child(screen)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	screen.add_child(v)
	# header
	var head := HBoxContainer.new()
	v.add_child(head)
	_header_title = UiKit.label("SEOHAE OPS · MAINTENANCE TASKS", 20, UiKit.C_INFO, "mono", 700)
	_header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_header_title)
	_header_clock = UiKit.label("", 20, UiKit.C_TEXT, "mono", 700)
	head.add_child(_header_clock)
	head.add_child(UiKit.label("   ▮▮▮▯ 78%", 18, UiKit.C_DIM, "mono"))
	# tabs
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	v.add_child(_tabs)
	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2(0, 640)
	v.add_child(content)
	_build_tasks_page(content)
	_build_album_page(content)
	_build_map_page(content)
	_build_records_page(content)
	_build_camera_page(content)
	_build_power_page(content)
	for key in [["tasks", "점검 지시"], ["album", "점검 앨범"], ["map", "구역 지도"], ["records", "기록"], ["camera", "카메라"], ["power", "야간 조명 배분"]]:
		var b := UiKit.button(key[1], 18, _show_tab.bind(key[0]), UiKit.C_INFO)
		_tabs.add_child(b)
		_tab_buttons[key[0]] = b
	var foot := UiKit.label("[Tab] 닫기   ·   보고는 반드시 현장에서 관찰한 뒤에 하십시오.", 15, UiKit.C_DIM)
	v.add_child(foot)
	Events.tasks_changed.connect(refresh)
	Events.erosion_changed.connect(func(_v): _refresh_erosion())


func open() -> void:
	visible = true
	_selected = director.current if director and director.current else _selected
	_tab_buttons.power.visible = Game.phase == "day" and Game.cycle >= 2
	_tab_buttons.camera.visible = Game.phase == "day"
	if not _tab_buttons.get(_current_tab).visible:
		_current_tab = "tasks"
	_show_tab(_current_tab, false)
	refresh()
	_frame.scale = Vector2(0.96, 0.96)
	_frame.pivot_offset = _frame.size * 0.5
	_frame.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_frame, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_frame, "modulate:a", 1.0, 0.12)


func _process(_delta: float) -> void:
	if visible:
		_header_clock.text = Game.clock_text()
		if boarding_mode and randf() < 0.02:
			_header_title.text = ["BOARDING INFORMATION", "B0ARDING 1NFORMATI0N", "MAINTENANCE TASKS"][randi() % 3]
		elif boarding_mode:
			_header_title.text = "SEOHAE OPS · BOARDING INFORMATION"


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("tablet") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		closed.emit()


func _show_tab(key: String, sound := true) -> void:
	_current_tab = key
	for k in _pages.keys():
		_pages[k].visible = k == key
	for k in _tab_buttons.keys():
		var b: Button = _tab_buttons[k]
		b.add_theme_color_override("font_color", UiKit.C_ACCENT if k == key else UiKit.C_TEXT)
	match key:
		"album":
			_refresh_album()
		"records":
			_refresh_records()
		"power":
			_refresh_power()
		"camera":
			_camera_info.text = "오늘 남은 촬영: %d / %d장" % [Game.photos_left, Game.PHOTOS_PER_DAY]
	if sound:
		Snd.play("ui_tap", -10.0)


# --- tasks ------------------------------------------------------------------------------
func _build_tasks_page(parent: Control) -> void:
	var page := HBoxContainer.new()
	UiKit.full_rect(page)
	page.add_theme_constant_override("separation", 16)
	parent.add_child(page)
	_pages["tasks"] = page
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(430, 0)
	page.add_child(left)
	left.add_child(UiKit.label("근무 지시 목록", 18, UiKit.C_DIM, "sans", 600))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_task_list = VBoxContainer.new()
	_task_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_task_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_task_list)
	var ebox := PanelContainer.new()
	ebox.add_theme_stylebox_override("panel", UiKit.box(Color(0.05, 0.07, 0.1), UiKit.C_LINE, 6, 1, 12))
	left.add_child(ebox)
	var ev := VBoxContainer.new()
	ebox.add_child(ev)
	_erosion_label = UiKit.label("터미널 시스템 상태", 16, UiKit.C_DIM, "sans", 600)
	ev.add_child(_erosion_label)
	_erosion_bar = ProgressBar.new()
	_erosion_bar.custom_minimum_size = Vector2(0, 12)
	_erosion_bar.show_percentage = false
	_erosion_bar.max_value = 100.0
	_erosion_bar.add_theme_stylebox_override("background", UiKit.box(Color(0, 0, 0, 0.6), Color(0, 0, 0, 0), 3, 0, 0))
	ev.add_child(_erosion_bar)
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_stylebox_override("panel", UiKit.box(Color(0.045, 0.065, 0.095), UiKit.C_LINE, 8, 1, 22))
	page.add_child(right)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 12)
	right.add_child(_detail)


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
	for task in director.tasks:
		var icon := "○"
		var col := UiKit.C_DIM
		match task.state:
			"active":
				icon = "▶"
				col = UiKit.C_ACCENT
			"responding":
				icon = "⚠"
				col = Color(1.0, 0.5, 0.3)
			"done":
				icon = "✓" if task.result in ["correct", "cleared", "done"] else "✗"
				col = UiKit.C_GOOD if icon == "✓" else UiKit.C_BAD
		if task.urgent and task.state != "done":
			col = Color(1.0, 0.45, 0.3)
		var b := Button.new()
		b.text = "%s  %s%s" % [icon, task.title, "  (선택)" if task.optional else ""]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.custom_minimum_size = Vector2(410, 44)
		b.add_theme_font_override("font", UiKit.font("sans", 500))
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_color", col)
		b.add_theme_color_override("font_hover_color", col.lightened(0.3))
		var sel := task == _selected
		b.add_theme_stylebox_override("normal", UiKit.box(Color(0.08, 0.11, 0.16) if sel else Color(0.05, 0.07, 0.1), UiKit.C_ACCENT if sel else UiKit.C_LINE, 5, 1, 12))
		b.add_theme_stylebox_override("hover", UiKit.box(Color(0.09, 0.12, 0.18), UiKit.C_INFO, 5, 1, 12))
		b.add_theme_stylebox_override("pressed", UiKit.box(Color(0.09, 0.12, 0.18), UiKit.C_INFO, 5, 1, 12))
		b.pressed.connect(func():
			_selected = task
			Snd.play("ui_tap", -10.0)
			refresh())
		_task_list.add_child(b)
	_build_detail()


func _build_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var task := _selected
	if task == null:
		_detail.add_child(UiKit.label("현재 지시 없음", 26, UiKit.C_DIM, "sans", 700))
		_detail.add_child(UiKit.label("새 지시를 기다리십시오.", 18, UiKit.C_DIM))
		return
	_detail.add_child(UiKit.label(("⚠ 긴급  " if task.urgent else "") + task.title, 28, UiKit.C_TEXT, "sans", 700))
	if task.location != "":
		_detail.add_child(UiKit.label("위치: " + str(Terminal.ZONE_NAMES.get(task.location, task.location)), 18, UiKit.C_INFO))
	var body := UiKit.rich(task.detail, 20, Color(0.82, 0.85, 0.9))
	_detail.add_child(body)
	var f: Facility = director.t.facility(task.facility_id) if task.facility_id != "" else null
	var status := "상태: " + task.status_text()
	if f:
		status += "    ·    시설: " + f.describe_state()
	_detail.add_child(UiKit.label(status, 18, UiKit.C_ACCENT if task.state != "done" else UiKit.C_DIM, "sans", 600))
	if task.kind != "inspect":
		return
	if task.state == "responding":
		var warn := UiKit.rich("[b]이상 판정 접수됨.[/b] 근무 수칙 [b][B][/b]에서 해당 시설 페이지를 확인하고 지시대로 대응하십시오.\n남은 시간: [b]%d초[/b]" % int(ceil(task.deadline)), 20, Color(1.0, 0.6, 0.4))
		_detail.add_child(warn)
		return
	if task.state != "active":
		return
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(spacer)
	var reason := director.can_report(task)
	if reason != "":
		_detail.add_child(UiKit.label(reason, 18, UiKit.C_DIM))
	_detail.add_child(UiKit.label("판정 보고", 18, UiKit.C_DIM, "sans", 600))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_detail.add_child(row)
	var ok := UiKit.button("정상  NORMAL", 26, func(): _report(task, false), UiKit.C_GOOD)
	ok.custom_minimum_size = Vector2(300, 84)
	ok.disabled = reason != ""
	row.add_child(ok)
	var bad := UiKit.button("이상  ANOMALY", 26, func(): _report(task, true), UiKit.C_BAD)
	bad.custom_minimum_size = Vector2(300, 84)
	bad.disabled = reason != ""
	row.add_child(bad)


func _report(task: Task, anomaly: bool) -> void:
	director.report(task, anomaly)
	refresh()
	if task.state == "done" or task.state == "responding":
		await get_tree().create_timer(0.35).timeout
		closed.emit()


func _refresh_erosion() -> void:
	if _erosion_bar == null:
		return
	var e := Game.erosion
	_erosion_bar.value = e
	var col := UiKit.C_GOOD
	var txt := "안정"
	if e >= 25.0:
		col = UiKit.C_ACCENT
		txt = "주의"
	if e >= 50.0:
		col = Color(1.0, 0.5, 0.25)
		txt = "불안정"
	if e >= 75.0:
		col = UiKit.C_BAD
		txt = "위험 — 시스템이 당신을 인식하고 있습니다"
	_erosion_bar.add_theme_stylebox_override("fill", UiKit.box(col, Color(0, 0, 0, 0), 3, 0, 0))
	_erosion_label.text = "터미널 시스템 침식도: %s (%d%%)" % [txt, int(e)]


func _build_boarding_pass() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var pass_box := PanelContainer.new()
	pass_box.add_theme_stylebox_override("panel", UiKit.box(Color(0.92, 0.92, 0.9), Color(0.1, 0.2, 0.5), 14, 4, 30))
	_detail.add_child(pass_box)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	pass_box.add_child(pv)
	pv.add_child(UiKit.label("BOARDING PASS · 탑승권", 30, Color(0.08, 0.15, 0.4), "sans", 700))
	pv.add_child(UiKit.label("SEOHAE AIR", 18, Color(0.3, 0.3, 0.35), "mono", 700))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 60)
	grid.add_theme_constant_override("v_separation", 12)
	pv.add_child(grid)
	for kv in [["FLIGHT", "000"], ["PASSENGER", Game.player_name], ["SEAT", "—"], ["DESTINATION", "HOME"], ["GATE", "0"], ["BOARDING", "NOW"]]:
		var col := VBoxContainer.new()
		col.add_child(UiKit.label(kv[0], 14, Color(0.4, 0.4, 0.45), "mono", 700))
		col.add_child(UiKit.label(kv[1], 34, Color(0.06, 0.06, 0.08), "mono", 700))
		grid.add_child(col)
	pv.add_child(UiKit.label("▌▌▍▌▌▌▍▍▌▌▍▌▌▍▌▌▌▍▌▌▍▍▌▌▌▍▌", 40, Color(0.1, 0.1, 0.1), "mono"))
	_detail.add_child(UiKit.label("탑승구가 곧 닫힙니다.", 22, UiKit.C_BAD, "sans", 700))
	var l := UiKit.label("MAINTENANCE TASKS — 0건", 18, UiKit.C_DIM, "mono")
	_task_list.add_child(l)


# --- album -------------------------------------------------------------------------------
func _build_album_page(parent: Control) -> void:
	var page := Control.new()
	UiKit.full_rect(page)
	parent.add_child(page)
	_pages["album"] = page
	var scroll := ScrollContainer.new()
	UiKit.full_rect(scroll)
	page.add_child(scroll)
	_album_grid = GridContainer.new()
	_album_grid.columns = 4
	_album_grid.add_theme_constant_override("h_separation", 14)
	_album_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_album_grid)
	_album_viewer = PanelContainer.new()
	_album_viewer.add_theme_stylebox_override("panel", UiKit.box(Color(0, 0, 0, 0.96), UiKit.C_LINE, 6, 1, 10))
	UiKit.full_rect(_album_viewer)
	_album_viewer.visible = false
	page.add_child(_album_viewer)
	var vv := VBoxContainer.new()
	_album_viewer.add_child(vv)
	_album_tex = TextureRect.new()
	_album_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_album_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_album_tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vv.add_child(_album_tex)
	var row := HBoxContainer.new()
	vv.add_child(row)
	_album_caption = UiKit.label("", 18, UiKit.C_TEXT)
	_album_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_album_caption)
	row.add_child(UiKit.button("닫기", 18, func(): _album_viewer.visible = false))


func _refresh_album() -> void:
	_album_viewer.visible = false
	for c in _album_grid.get_children():
		c.queue_free()
	if Game.photos.is_empty():
		_album_grid.add_child(UiKit.label("저장된 사진이 없습니다. 낮 근무 중 [카메라] 탭에서 시설의 정상 상태를 촬영하십시오.", 18, UiKit.C_DIM))
		return
	for i in Game.photos.size():
		var ph: Dictionary = Game.photos[i]
		var cell := VBoxContainer.new()
		var tb := TextureButton.new()
		tb.texture_normal = ph.tex
		tb.ignore_texture_size = true
		tb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
		tb.custom_minimum_size = Vector2(300, 169)
		tb.pressed.connect(_view_photo.bind(i))
		cell.add_child(tb)
		cell.add_child(UiKit.label("#%02d  %s" % [i + 1, ph.label], 15, UiKit.C_DIM))
		_album_grid.add_child(cell)


func _view_photo(i: int) -> void:
	var ph: Dictionary = Game.photos[i]
	_album_tex.texture = ph.tex
	_album_caption.text = "#%02d   %s" % [i + 1, ph.label]
	_album_viewer.visible = true
	Snd.play("ui_tap", -8.0)


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
	page.add_theme_constant_override("separation", 16)
	parent.add_child(page)
	_pages["records"] = page
	_records_list = VBoxContainer.new()
	_records_list.custom_minimum_size = Vector2(380, 0)
	page.add_child(_records_list)
	var right := PanelContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_stylebox_override("panel", UiKit.box(Color(0.045, 0.065, 0.095), UiKit.C_LINE, 8, 1, 22))
	page.add_child(right)
	_records_body = UiKit.rich("", 19, Color(0.85, 0.87, 0.9))
	right.add_child(_records_body)


func _refresh_records() -> void:
	for c in _records_list.get_children():
		c.queue_free()
	_records_list.add_child(UiKit.label("수집한 기록", 18, UiKit.C_DIM, "sans", 600))
	var any := false
	for id in RulesDB.CLUES.keys():
		if not Game.has_clue(id):
			continue
		any = true
		var c: Dictionary = RulesDB.CLUES[id]
		var body := str(c.body)
		if id == "syslog":
			body = body % Game.player_name
		_records_list.add_child(UiKit.button(c.title, 17, func(): _records_body.text = "[b]%s[/b]\n\n%s" % [c.title, body]))
	_records_body.text = "" if any else "아직 수집한 기록이 없습니다. 터미널 곳곳의 문서를 살펴보십시오."


# --- camera -------------------------------------------------------------------------------------
func _build_camera_page(parent: Control) -> void:
	var page := VBoxContainer.new()
	UiKit.full_rect(page)
	page.add_theme_constant_override("separation", 18)
	parent.add_child(page)
	_pages["camera"] = page
	page.add_child(UiKit.label("점검 카메라", 28, UiKit.C_TEXT, "sans", 700))
	page.add_child(UiKit.rich("낮 근무 중 시설의 [b]정상 상태[/b]를 촬영해 두면, 밤에 [b]점검 앨범[/b]에서 비교할 수 있습니다.\n하루 촬영 가능 장수는 제한되어 있습니다. 무엇을 찍을지 신중하게 고르십시오.\n\n추천: FIDS 전광판(테스트 목록), 수하물 벨트(가방 개수·색), X-ray 판독 화면, 무빙워크 방향, 탑승구 대기석 배치", 20, Color(0.82, 0.85, 0.9)))
	_camera_info = UiKit.label("", 22, UiKit.C_ACCENT, "sans", 700)
	page.add_child(_camera_info)
	var b := UiKit.button("카메라 실행  ( [LMB] 촬영 · [RMB] 종료 )", 22, func(): camera_requested.emit(), UiKit.C_ACCENT)
	b.custom_minimum_size = Vector2(520, 70)
	page.add_child(b)


# --- night lighting plan ----------------------------------------------------------------------------
func _build_power_page(parent: Control) -> void:
	var page := VBoxContainer.new()
	UiKit.full_rect(page)
	page.add_theme_constant_override("separation", 14)
	parent.add_child(page)
	_pages["power"] = page
	page.add_child(UiKit.label("야간 조명 배분", 28, UiKit.C_TEXT, "sans", 700))
	page.add_child(UiKit.rich("야간 전력 한도 때문에 [b]최대 3개 구역[/b]만 조명을 예약할 수 있습니다.\n켜 둔 구역은 밤에 관찰이 쉽고, 수칙 p.9 ③(새벽 3시)에 대비할 수 있습니다. 꺼 둔 구역은 손전등에 의지해야 합니다.\n밤에도 조명 분전반에서 직접 켜고 끌 수는 있습니다.", 19, Color(0.82, 0.85, 0.9)))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	page.add_child(grid)
	for zn in ["hall", "baggage", "security", "corridor", "gates"]:
		var b := UiKit.button(Terminal.ZONE_NAMES[zn], 20, _toggle_power.bind(zn), UiKit.C_ACCENT)
		b.custom_minimum_size = Vector2(220, 90)
		b.toggle_mode = true
		grid.add_child(b)
		_power_buttons[zn] = b
	_power_info = UiKit.label("", 20, UiKit.C_ACCENT, "sans", 600)
	page.add_child(_power_info)
	var confirm := UiKit.button("배분 확정", 22, _confirm_power, UiKit.C_GOOD)
	confirm.custom_minimum_size = Vector2(260, 64)
	page.add_child(confirm)


func _refresh_power() -> void:
	var n := 0
	for zn in _power_buttons.keys():
		var on := bool(Game.night_lights.get(zn, false))
		_power_buttons[zn].set_pressed_no_signal(on)
		_power_buttons[zn].add_theme_color_override("font_color", UiKit.C_ACCENT if on else UiKit.C_DIM)
		if on:
			n += 1
	_power_info.text = "예약된 구역: %d / 3" % n


func _toggle_power(zn: String) -> void:
	var on := not bool(Game.night_lights.get(zn, false))
	var n := 0
	for k in Game.night_lights.keys():
		if Game.night_lights[k]:
			n += 1
	if on and n >= 3:
		Snd.play("beep_error", -8.0)
		_power_info.text = "한도 초과 — 다른 구역을 먼저 해제하십시오."
		_power_buttons[zn].set_pressed_no_signal(false)
		return
	Game.night_lights[zn] = on
	_refresh_power()


func _confirm_power() -> void:
	Snd.play("beep_ok", -6.0)
	Events.player_action.emit("power_plan", "")
	_power_info.text = "야간 조명 배분이 확정되었습니다."
