class_name BinderView
extends Control
## 근무 수칙 바인더: page index on the left, one paper page on the right.

signal closed

var _index: VBoxContainer
var _paper: PaperPage
var _ids: Array = []
var _cur := 0
var _buttons: Array[Button] = []


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	UiKit.full_rect(dim)
	add_child(dim)
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 26)
	UiKit.center(root, Vector2(1360, 1000))
	add_child(root)
	var left := PanelContainer.new()
	left.custom_minimum_size = Vector2(400, 0)
	left.add_theme_stylebox_override("panel", UiKit.box(Color(0.07, 0.1, 0.2, 0.97), Color(0.15, 0.2, 0.35), 10, 2, 22))
	root.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	left.add_child(lv)
	lv.add_child(UiKit.label("근무 수칙 바인더", 28, Color(0.95, 0.92, 0.8), "sans", 700))
	lv.add_child(UiKit.label("서해국제공항 시설운영팀", 15, UiKit.C_DIM))
	var sep := HSeparator.new()
	lv.add_child(sep)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(scroll)
	_index = VBoxContainer.new()
	_index.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_index.add_theme_constant_override("separation", 4)
	scroll.add_child(_index)
	lv.add_child(UiKit.label("[A/D] 넘기기   [B/Esc] 닫기", 15, UiKit.C_DIM))
	_paper = PaperPage.new()
	_paper.custom_minimum_size = Vector2(900, 1000)
	root.add_child(_paper)
	refresh()


func refresh(select_id := "") -> void:
	_ids = RulesDB.sorted_ids(Game.binder_pages)
	for c in _index.get_children():
		c.queue_free()
	_buttons.clear()
	for i in _ids.size():
		var pg := RulesDB.page(_ids[i])
		var no := str(pg.get("no", ""))
		var txt := ("p.%s  %s" % [no, pg.get("title", "")]) if no != "" else "　 " + str(pg.get("title", ""))
		var b := Button.new()
		b.text = txt
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_override("font", UiKit.font("sans", 500))
		b.add_theme_font_size_override("font_size", 19)
		b.add_theme_color_override("font_color", Color(0.85, 0.86, 0.9))
		b.add_theme_stylebox_override("normal", UiKit.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 0, 10))
		b.add_theme_stylebox_override("hover", UiKit.box(Color(1, 1, 1, 0.06), Color(0, 0, 0, 0), 4, 0, 10))
		b.add_theme_stylebox_override("pressed", UiKit.box(Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 4, 0, 10))
		b.pressed.connect(_select.bind(i))
		_index.add_child(b)
		_buttons.append(b)
	if _ids.is_empty():
		_paper.show_page({"title": "(비어 있음)", "body": "아직 수령한 페이지가 없습니다.", "stamp": "none", "rev": ""})
		return
	var idx := _ids.find(select_id) if select_id != "" else clampi(_cur, 0, _ids.size() - 1)
	_select(maxi(idx, 0), false)


func _select(i: int, sound := true) -> void:
	_cur = clampi(i, 0, _ids.size() - 1)
	_paper.show_page(RulesDB.page(_ids[_cur]))
	for j in _buttons.size():
		_buttons[j].add_theme_color_override("font_color", UiKit.C_ACCENT if j == _cur else Color(0.85, 0.86, 0.9))
	if sound:
		Snd.play("page_flip", -6.0, randf_range(0.95, 1.08))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_page_next"):
		_select(_cur + 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_page_prev"):
		_select(_cur - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("binder") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		closed.emit()
