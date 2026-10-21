class_name BinderView
extends Control
## 근무 수칙 바인더: an open navy ring binder (generated cover, rings and paper art). Index tabs on the
## left cover, one page clamped in the rings on the right; pages turn around the ring axis.

signal closed

const BOOK := Vector2(1460, 980)
const PAPER_RECT := Rect2(520, 36, 904, 908)
const PLATE_X := 476.0
const RING_K := 0.62
const RING_BANDS := [155.0, 377.5, 599.0]   # ring centers in binder_rings.png (512 x 768)

var _backdrop: Control
var _rig: Control
var _index: VBoxContainer
var _paper: PaperPage
var _rings: Control
var _ids: Array = []
var _cur := 0
var _buttons: Array[Button] = []
var _anim: Tween
var _flip: Tween
var _closing := false


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	_backdrop = UiKit.backdrop(Color(0.02, 0.025, 0.035, 0.6), 2.6)
	add_child(_backdrop)
	var book := Control.new()
	UiKit.center(book, BOOK)
	book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(book)
	_rig = Control.new()
	UiKit.full_rect(_rig)
	_rig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig.draw.connect(_draw_book)
	book.add_child(_rig)
	# left cover: index
	var left := VBoxContainer.new()
	left.position = Vector2(44, 44)
	left.size = Vector2(300, BOOK.y - 88)
	left.add_theme_constant_override("separation", 6)
	_rig.add_child(left)
	left.add_child(UiKit.caption("SEOHAE INT'L AIRPORT · FACILITY OPS", Color("8fa2c8"), 14))
	var t := UiKit.label("근무 수칙 바인더", 32, Color("f2eee3"), "sans", 900)
	left.add_child(t)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	left.add_child(gap)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_index = VBoxContainer.new()
	_index.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_index.add_theme_constant_override("separation", 4)
	scroll.add_child(_index)
	left.add_child(UiKit.key_hints([["A/D", "넘기기"], ["B", "닫기"]], 15, Color("8fa2c8")))
	# the page
	_paper = PaperPage.new()
	_paper.left_margin = 118
	_paper.position = PAPER_RECT.position
	_paper.size = PAPER_RECT.size
	_rig.add_child(_paper)
	_rings = Control.new()
	UiKit.full_rect(_rings)
	_rings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rings.draw.connect(_draw_rings)
	_rig.add_child(_rings)
	refresh()


func refresh(select_id := "") -> void:
	_ids = RulesDB.sorted_ids(Game.binder_pages)
	for c in _index.get_children():
		c.queue_free()
	_buttons.clear()
	for i in _ids.size():
		var pg := RulesDB.page(_ids[i])
		_index.add_child(_index_button(i, str(pg.get("no", "")), str(pg.get("title", ""))))
	if _ids.is_empty():
		_paper.show_page({"title": "(비어 있음)", "body": "아직 수령한 페이지가 없습니다.", "stamp": "none", "rev": ""})
		return
	var idx := _ids.find(select_id) if select_id != "" else clampi(_cur, 0, _ids.size() - 1)
	_select(maxi(idx, 0), false, false)


func _index_button(i: int, no: String, title: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(296, 48)
	var h := HBoxContainer.new()
	UiKit.full_rect(h)
	h.offset_left = 14
	h.offset_right = -8
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var nl := UiKit.label("p.%s" % no if no != "" else "  ─", 15, Color("8fa2c8"), "mono", 700)
	nl.custom_minimum_size = Vector2(36, 0)
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nl.size_flags_vertical = Control.SIZE_FILL
	nl.name = "No"
	h.add_child(nl)
	var tl := UiKit.label(title, 18, Color("c9d2e6"), "sans", 500)
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tl.size_flags_vertical = Control.SIZE_FILL
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.clip_text = true
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tl.name = "Title"
	h.add_child(tl)
	b.pressed.connect(_select.bind(i))
	b.mouse_entered.connect(func(): Snd.play("ui_click", -20.0, 1.25))
	_buttons.append(b)
	return b


func _style_index() -> void:
	for j in _buttons.size():
		var b := _buttons[j]
		var on := j == _cur
		var bg := UiKit.PAPER if on else Color(1, 1, 1, 0.035)
		b.add_theme_stylebox_override("normal", UiKit.box(bg, Color(0, 0, 0, 0), 0, 0, 0))
		b.add_theme_stylebox_override("hover", UiKit.box(UiKit.PAPER if on else Color(1, 1, 1, 0.09), Color(0, 0, 0, 0), 0, 0, 0))
		b.add_theme_stylebox_override("pressed", UiKit.box(UiKit.PAPER, Color(0, 0, 0, 0), 0, 0, 0))
		b.add_theme_stylebox_override("focus", UiKit.empty_box())
		var tl: Label = b.find_child("Title", true, false)
		var nl: Label = b.find_child("No", true, false)
		tl.add_theme_color_override("font_color", UiKit.PAPER_INK if on else Color("c9d2e6"))
		tl.add_theme_font_override("font", UiKit.font("sans", 700 if on else 500))
		nl.add_theme_color_override("font_color", UiKit.STAMP_RED if on else Color("8fa2c8"))


func _select(i: int, sound := true, animate := true) -> void:
	if _ids.is_empty():
		return
	var ni := clampi(i, 0, _ids.size() - 1)
	var forward := ni >= _cur
	_cur = ni
	_style_index()
	var pg := RulesDB.page(_ids[_cur])
	if sound:
		Snd.play("page_flip", -6.0, randf_range(0.95, 1.08))
	if not animate or not is_visible_in_tree():
		_paper.show_page(pg)
		return
	if _flip:
		_flip.kill()
	_paper.pivot_offset = Vector2(0, _paper.size.y * 0.5)
	_flip = create_tween()
	_flip.tween_property(_paper, "scale:x", 0.02, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_flip.parallel().tween_property(_paper, "modulate", Color(0.62, 0.6, 0.56), 0.1)
	_flip.tween_callback(func(): _paper.show_page(pg))
	_flip.tween_property(_paper, "scale:x", 1.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_flip.parallel().tween_property(_paper, "modulate", Color.WHITE, 0.18)
	if not forward:
		_paper.position.x = PAPER_RECT.position.x + 10


func open_anim() -> void:
	visible = true
	_closing = false
	if _anim:
		_anim.kill()
	_rig.pivot_offset = BOOK * 0.5
	_rig.position = Vector2(0, 130)
	_rig.rotation = deg_to_rad(-1.8)
	_rig.modulate.a = 0.0
	_anim = create_tween().set_parallel(true)
	_anim.tween_property(_rig, "position", Vector2.ZERO, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_anim.tween_property(_rig, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_anim.tween_property(_rig, "modulate:a", 1.0, 0.14)
	(_backdrop.get_node("Blur").material as ShaderMaterial).set_shader_parameter("amount", 0.0)
	UiFx.backdrop_to(_backdrop, 1.0, 0.25)
	UiFx.stagger(_buttons, 0.025, 0.16, 0.18)


func close_anim() -> void:
	if not visible or _closing:
		return
	_closing = true
	if _anim:
		_anim.kill()
	_anim = create_tween().set_parallel(true)
	_anim.tween_property(_rig, "position", Vector2(0, 160), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_anim.tween_property(_rig, "modulate:a", 0.0, 0.16)
	UiFx.backdrop_to(_backdrop, 0.0, 0.16)
	_anim.chain().tween_callback(func():
		if _closing:
			visible = false
			_closing = false)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _closing:
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


func _process(_delta: float) -> void:
	if visible and _paper.position.x != PAPER_RECT.position.x:
		_paper.position.x = lerpf(_paper.position.x, PAPER_RECT.position.x, 0.25)


# =========================================================================================
# drawing
# =========================================================================================
func _draw_book() -> void:
	var r := Rect2(Vector2.ZERO, BOOK)
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(0, 0, 0, 0)
	sh.shadow_color = Color(0, 0, 0, 0.6)
	sh.shadow_size = 60
	sh.shadow_offset = Vector2(0, 24)
	sh.set_corner_radius_all(18)
	_rig.draw_style_box(sh, r)
	var cover := UiArt.tex("binder_cover")
	if cover:
		_rig.draw_texture_rect(cover, r, false)
	else:
		_rig.draw_style_box(UiKit.box(Color("13213f"), Color("1d2d52"), 14, 2, 0), r)
	# spine groove where the ring plate sits
	_rig.draw_rect(Rect2(PLATE_X - 30, 18, 60, BOOK.y - 36), Color(0, 0, 0, 0.18))
	# a thin stack of pages under the current one
	for k in [3, 2, 1]:
		var off := Vector2(k * 3.0, k * 4.0)
		_rig.draw_rect(Rect2(PAPER_RECT.position + off, PAPER_RECT.size), Color(0.78, 0.75, 0.68).darkened(k * 0.06))
	_rig.draw_rect(Rect2(PAPER_RECT.position + Vector2(10, 16), PAPER_RECT.size), Color(0, 0, 0, 0.3))


func _draw_rings() -> void:
	var t := UiArt.tex("binder_rings")
	var top := PAPER_RECT.position.y - 14.0
	var bottom := PAPER_RECT.end.y + 14.0
	if t == null:
		_rings.draw_rect(Rect2(PLATE_X - 16, top, 32, bottom - top), Color(0.62, 0.64, 0.67))
		for f in PaperPage.HOLES:
			var cy: float = PAPER_RECT.position.y + PAPER_RECT.size.y * f
			_rings.draw_arc(Vector2(PLATE_X + 30, cy), 60.0, PI * 0.6, PI * 2.4, 40, Color(0.8, 0.82, 0.85), 9.0, true)
		return
	var k := RING_K
	var pw := 64.0 * k
	_rings.draw_texture_rect_region(t, Rect2(PLATE_X - pw * 0.5, top + 30, pw, bottom - top - 60), Rect2(224, 215, 64, 100))
	_rings.draw_texture_rect_region(t, Rect2(PLATE_X - pw * 0.5, top, pw, 46 * k * 1.6), Rect2(224, 36, 64, 74))
	_rings.draw_texture_rect_region(t, Rect2(PLATE_X - pw * 0.5, bottom - 46 * k * 1.6, pw, 46 * k * 1.6), Rect2(224, 650, 64, 74))
	for i in PaperPage.HOLES.size():
		var cy: float = PAPER_RECT.position.y + PAPER_RECT.size.y * PaperPage.HOLES[i]
		var band: float = RING_BANDS[i]
		var src := Rect2(98, band - 58.0, 316, 116)
		var dst := Rect2(Vector2(PLATE_X - (256.0 - 98.0) * k, cy - 58.0 * k), src.size * k)
		_rings.draw_texture_rect_region(t, dst, src)
