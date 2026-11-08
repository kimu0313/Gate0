class_name GuideView
extends Control
## The guidelines, open ([Tab] once you have them — user, with a picture of an open case file: "지침서는 이런 서류
## 연 디자인으로 했으면 좋겠네"): a worn kraft folder lying open on the dark, the tab of its back cover showing with
## a typed label; on the left a staff record (the name written in by hand, no photo) over a blank patrol log, a sheet
## under them peeking out; on the right the guidelines typed on a sheet held by a bulldog clip, signed with the
## team's red seal; two black-and-white prints of the building (a corridor, the records room — in-game shots,
## assets/ui/guide_photo_*.png) paper-clipped over its edge. All drawn here — shaders for the card
## (ui_kraft), the paper (ui_paper) and the prints (ui_photo) — in a fixed design space SIZE that GameUI scales
## to the screen; build() lays it out again in the player's language each time it opens.
##
## RULES is a STAND-IN made from the manager's handover (OfficeNpc.LINES) until the user gives the guidelines' text.

const SIZE := Vector2(1700, 1000)
const INK := Color(0.12, 0.115, 0.11)
const INK_2 := Color(0.35, 0.33, 0.3)
const LINE := Color(0.2, 0.19, 0.17, 0.75)
const FILL := Color(0.3, 0.27, 0.2, 0.08)
const PEN := Color(0.11, 0.16, 0.38)           # the ballpoint the name was written in
const SEAL := Color(0.7, 0.12, 0.09, 0.84)
const FOLDER := Rect2(34, 46, 1490, 908)       # the open folder (its tab inside the rect's top)
const FOLD := 738.0                            # the crease, in the folder's rect
const TAB := Vector2(1040, 1320)               # the back cover's tab, in the folder's rect
const ORG := "A국제공항 시설관리팀"
const RULES := [
	"근무 시간은 22:00부터 06:00까지이다. 근무 전 4층 관리실에서 작업복으로 갈아입고, 손전등과 무전기를 지참한다.",
	"근무자는 공항 내부를 순회하며 조명과 설비의 상태를 확인하고, 특이사항은 관리실에 보고한다.",
	"문제가 생기면 먼저 무전으로 관리실에 연락한다.",
	"근무 중 외부 이용객과 마주친 경우 평소처럼 응대한다. 불필요한 대화는 하지 않는다.",
	"이 지침의 모든 사항에는 이유가 있다. 이유를 묻지 말고, 적힌 대로 따른다.",
]
## The staff record's rows: [label, value] (the name is written in by hand).
const FIELDS := [
	["성명", ""], ["소속", "시설관리팀 (야간)"], ["직위", "시설관리원 · 계약직"], ["근무 시간", "22:00 – 06:00"],
	["근무지", "여객터미널 전 구역"], ["비상 연락", "관리실 · 무전"],
]
const LOG_HEADS := ["시각", "구역", "조명", "설비", "확인"]
const LOG_HOURS := ["22:00", "23:00", "00:00", "01:00", "02:00", "03:00", "04:00", "05:00"]
const RULE_SIZE := 19

var _rules: Array[RichTextLabel] = []
var _body: VBoxContainer
var _room := 0.0


func _init() -> void:
	size = SIZE
	pivot_offset = SIZE * 0.5
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Lays the folder out (again) in the player's language.
func build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_rules.clear()
	var kraft := ColorRect.new()
	kraft.position = FOLDER.position
	kraft.size = FOLDER.size
	kraft.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kraft.material = _mat("res://shaders/ui_kraft.gdshader", {"px": FOLDER.size, "fold": FOLD, "tab": TAB})
	add_child(kraft)
	_tab_label()
	_sheet(Vector2(100, 112), Vector2(634, 812), 1.7, 3.0, 0.0)            # a sheet under the record, peeking out
	var left := _sheet(Vector2(74, 90), Vector2(654, 834), -0.9, 1.0, 0.0)
	_staff_record(left)
	var right := _sheet(Vector2(806, 82), Vector2(664, 852), 0.6, 2.0, 0.34)
	_guidelines(right)
	_bulldog(right)
	_photo("res://assets/ui/guide_photo_corridor.png", Vector2(1530, 466), 7.0, 5.0)
	_photo("res://assets/ui/guide_photo_archive.png", Vector2(1524, 684), -4.5, 9.0)
	queue_redraw()
	_fit_rules()


func _draw() -> void:
	_shadow(self, FOLDER, Vector2(12, 16), 16, 0.04, 3.0)


# --- pieces --------------------------------------------------------------------------------
## A sheet of paper at `pos` (its own shadow under it), turned `deg` about its middle.
func _sheet(pos: Vector2, sz: Vector2, deg: float, seed: float, crease: float) -> Control:
	var s := Control.new()
	s.position = pos
	s.size = sz
	s.pivot_offset = sz * 0.5
	s.rotation = deg_to_rad(deg)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(s)
	s.draw.connect(func(): _shadow(s, Rect2(Vector2.ZERO, sz), Vector2(4, 7), 8, 0.05, 1.6))
	var paper := ColorRect.new()
	paper.size = sz
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.material = _mat("res://shaders/ui_paper.gdshader", {"px": sz, "seed": seed, "crease": crease})
	s.add_child(paper)
	return s


## A typed label stuck on the back cover's tab.
func _tab_label() -> void:
	var l := Control.new()
	l.position = FOLDER.position + Vector2(TAB.x + 42, 7)
	l.size = Vector2(TAB.y - TAB.x - 84, 26)
	l.rotation = deg_to_rad(-0.6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	l.draw.connect(func():
		l.draw_rect(Rect2(Vector2.ZERO, l.size), Color(0.87, 0.85, 0.79))
		l.draw_rect(Rect2(Vector2.ZERO, l.size), Color(0.3, 0.28, 0.25, 0.35), false, 1.0)
		_text(l, UiKit.font("sans", 700), Vector2(l.size.x * 0.5, 19), UiKit.t("야간 근무 지침"), 15, INK, l.size.x - 16,
			HORIZONTAL_ALIGNMENT_CENTER))


## The left page: the staff record and a blank patrol log, drawn on the sheet.
func _staff_record(sheet: Control) -> void:
	var f := Control.new()
	f.size = sheet.size
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(f)
	f.draw.connect(func(): _draw_record(f))


func _draw_record(c: Control) -> void:
	var x0 := 48.0
	var x1 := c.size.x - 48.0
	var sans := UiKit.font("sans", 400)
	var bold := UiKit.font("sans", 700)
	var mono := UiKit.font("mono", 400)
	var disp := UiKit.font("display", 700)
	# the head
	_text(c, sans, Vector2(x0, 58), UiKit.t(ORG), 16, INK_2, 380.0)
	_text(c, mono, Vector2(x1, 58), "No. 0418", 16, INK_2, -1.0, HORIZONTAL_ALIGNMENT_RIGHT)
	c.draw_line(Vector2(x0, 70), Vector2(x1, 70), LINE, 1.5)
	_text(c, bold, Vector2(x0, 114), UiKit.t("근무자 기록카드"), 30, INK, x1 - x0)
	if not _english():
		_text(c, disp, Vector2(x0, 140), "STAFF RECORD", 15, INK_2)
	# the record: six rows, the photo box beside the first four
	var top := 162.0
	var rh := 46.0
	var lw := 128.0
	var photo := Rect2(x1 - 124.0, top, 124.0, 4.0 * rh)
	for i in FIELDS.size():
		var y := top + i * rh
		var right := photo.position.x - 12.0 if i < 4 else x1
		c.draw_rect(Rect2(x0, y, lw, rh), FILL)
		c.draw_rect(Rect2(x0, y, right - x0, rh), LINE, false, 1.2)
		c.draw_line(Vector2(x0 + lw, y), Vector2(x0 + lw, y + rh), LINE, 1.2)
		_text(c, bold, Vector2(x0 + 12, y + 29), UiKit.t(FIELDS[i][0]), 17, INK, lw - 20.0)
		var v: String = FIELDS[i][1]
		if v != "":
			_text(c, mono if v.begins_with("22:") else sans, Vector2(x0 + lw + 14, y + 30), UiKit.t(v), 18, INK,
				right - x0 - lw - 24.0)
	# the name, written in by hand
	c.draw_set_transform(Vector2(x0 + lw + 20, top + 35), deg_to_rad(-3.0))
	_text(c, UiKit.font("hand"), Vector2.ZERO, UiKit.t("신규"), 40, PEN, 280.0)
	c.draw_set_transform(Vector2.ZERO)
	# the photo box, empty
	c.draw_rect(photo, Color(0.3, 0.27, 0.2, 0.05))
	c.draw_rect(photo, LINE, false, 1.2)
	var pc := photo.get_center()
	_text(c, sans, Vector2(pc.x, pc.y - 2), UiKit.t("사진"), 17, INK_2, photo.size.x - 16.0, HORIZONTAL_ALIGNMENT_CENTER)
	_text(c, sans, Vector2(pc.x, pc.y + 22), UiKit.t("미부착"), 15, Color(INK_2, 0.8), photo.size.x - 16.0,
		HORIZONTAL_ALIGNMENT_CENTER)
	# the patrol log: an hour a row, nothing filled in
	var ly := 492.0
	_text(c, bold, Vector2(x0, ly), UiKit.t("순회 점검 기록"), 21, INK, 360.0)
	if not _english():
		_text(c, disp, Vector2(x1, ly), "PATROL LOG", 14, INK_2, -1.0, HORIZONTAL_ALIGNMENT_RIGHT)
	var gt := ly + 16.0
	var hh := 32.0
	var row := 28.0
	var cols := [x0, x0 + 84.0, x0 + 280.0, x0 + 370.0, x0 + 460.0, x1]
	var bottom := gt + hh + LOG_HOURS.size() * row
	c.draw_rect(Rect2(x0, gt, x1 - x0, hh), FILL)
	c.draw_rect(Rect2(x0, gt, x1 - x0, bottom - gt), LINE, false, 1.2)
	for k in range(1, cols.size() - 1):
		c.draw_line(Vector2(cols[k], gt), Vector2(cols[k], bottom), LINE, 1.0)
	for k in LOG_HEADS.size():
		_text(c, bold, Vector2((cols[k] + cols[k + 1]) * 0.5, gt + 22), UiKit.t(LOG_HEADS[k], "form"), 16, INK,
			cols[k + 1] - cols[k] - 10.0, HORIZONTAL_ALIGNMENT_CENTER)
	for r in LOG_HOURS.size():
		var y := gt + hh + r * row
		c.draw_line(Vector2(x0, y), Vector2(x1, y), LINE, 1.0)
		_text(c, mono, Vector2((cols[0] + cols[1]) * 0.5, y + 20), LOG_HOURS[r], 15, INK_2, -1.0, HORIZONTAL_ALIGNMENT_CENTER)
	# signed off by
	var sy := bottom + 34.0
	_text(c, sans, Vector2(x1 - 150, sy), UiKit.t("확인자"), 16, INK_2, 200.0, HORIZONTAL_ALIGNMENT_RIGHT)
	c.draw_line(Vector2(x1 - 140, sy + 3), Vector2(x1 - 44, sy + 3), LINE, 1.0)
	_text(c, sans, Vector2(x1, sy), UiKit.t("(인)"), 16, INK_2, -1.0, HORIZONTAL_ALIGNMENT_RIGHT)


## The right page: the guidelines, typed, the team head's seal at the foot.
func _guidelines(sheet: Control) -> void:
	var m := MarginContainer.new()
	UiKit.full_rect(m)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: Array in [["margin_left", 56], ["margin_right", 108], ["margin_top", 50], ["margin_bottom", 176]]:
		m.add_theme_constant_override(side[0], side[1])
	sheet.add_child(m)
	_room = sheet.size.y - 50.0 - 176.0
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	_body = v
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var org := UiKit.label(ORG, 16, INK_2)
	org.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(org)
	head.add_child(UiKit.label("FM-N-001", 15, INK_2, "mono"))
	var rule := ColorRect.new()
	rule.color = LINE
	rule.custom_minimum_size = Vector2(0, 2)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(rule)
	var title := UiKit.label("야간 시설관리 근무 지침", 32, INK, "sans", 700)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(title)
	if not _english():
		v.add_child(UiKit.label("NIGHT FACILITY DUTY GUIDELINES", 14, INK_2, "display", 600))
	v.add_child(UiKit.rich("[b]%s[/b]  %s      [b]%s[/b]  %s" % [UiKit.t("대상"), UiKit.t("야간 시설관리원"),
		UiKit.t("열람"), UiKit.t("관계자 외 열람 금지")], 16, INK_2))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	v.add_child(gap)
	for i in RULES.size():
		var r := UiKit.rich("[table=2][cell padding=0,0,12,0][b]%d.[/b][/cell][cell expand=1]%s[/cell][/table]" % [
			i + 1, UiKit.t(RULES[i])], RULE_SIZE, INK)
		r.add_theme_constant_override("line_separation", 6)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(r)
		_rules.append(r)
	# the foot: a rule, when it applies from, the team head and his seal
	var foot := Control.new()
	foot.size = sheet.size
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(foot)
	var h := sheet.size.y
	foot.draw.connect(func():
		foot.draw_line(Vector2(56, h - 150), Vector2(sheet.size.x - 56, h - 150), LINE, 1.5)
		_text(foot, UiKit.font("sans", 400), Vector2(56, h - 120), UiKit.t("본 지침은 근무 시작일부터 적용한다."), 16, INK_2,
			sheet.size.x - 112.0)
		_text(foot, UiKit.font("sans", 700), Vector2(sheet.size.x - 216, h - 64), UiKit.t("시설관리팀장"), 21, INK, 300.0,
			HORIZONTAL_ALIGNMENT_RIGHT))
	var seal := StampMark.make(["A국제공항", "시설관리팀", "승  인"], SEAL, "round", "stamp_seal_ring", Vector2(132, 132))
	seal.angle_deg = -14.0
	seal.position = Vector2(sheet.size.x - 198, h - 142)        # beside the name, its ring clear of the letters
	sheet.add_child(seal)


## A bulldog clip on the sheet's top edge (its jaw over the paper, the handles up off it).
func _bulldog(sheet: Control) -> void:
	var t: Texture2D = UiArt.tex("clip_bulldog")
	if t == null:
		return
	var sz := Vector2(80, 80.0 * t.get_height() / t.get_width())
	var at := Vector2(sheet.size.x - 104.0 - sz.x * 0.5, -sz.y * 0.58)     # right of the back cover's tab, over the doc number
	for k in 2:
		var r := TextureRect.new()
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.size = sz
		r.position = at + (Vector2(5, 8) if k == 0 else Vector2.ZERO)
		r.modulate = Color(0, 0, 0, 0.35) if k == 0 else Color.WHITE
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sheet.add_child(r)


## A black-and-white print in its white border, centred at `centre`, turned `deg`, a paper clip on its top edge.
func _photo(path: String, centre: Vector2, deg: float, seed: float) -> void:
	var sz := Vector2(300, 222)
	var p := Control.new()
	p.size = sz
	p.position = centre - sz * 0.5
	p.pivot_offset = sz * 0.5
	p.rotation = deg_to_rad(deg)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(p)
	p.draw.connect(func():
		_shadow(p, Rect2(Vector2.ZERO, sz), Vector2(6, 9), 10, 0.055, 1.8)
		p.draw_rect(Rect2(Vector2.ZERO, sz), Color(0.86, 0.85, 0.8)))
	var img := TextureRect.new()
	img.texture = load(path)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	img.position = Vector2(12, 12)
	img.size = sz - Vector2(24, 24)
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.material = _mat("res://shaders/ui_photo.gdshader", {"seed": seed})
	p.add_child(img)
	var clip := Control.new()
	clip.position = Vector2(sz.x * 0.7, -30)
	clip.rotation = deg_to_rad(-5.0)
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(clip)
	clip.draw.connect(func(): _paper_clip(clip))


## A gem paper clip, its round end up, drawn as wire (a shadow, the steel, a highlight).
static func _paper_clip(c: CanvasItem) -> void:
	var pts := PackedVector2Array()
	for y in range(40, 11, -4):
		pts.append(Vector2(-3, y))
	for k in 9:
		var a := PI + PI * k / 8.0
		pts.append(Vector2(0, 12) + Vector2(cos(a), sin(a)) * 3.0)
	for y in range(12, 55, 4):
		pts.append(Vector2(3, y))
	for k in 9:
		var a := PI * k / 8.0
		pts.append(Vector2(-2.5, 54) + Vector2(cos(a), sin(a)) * 5.5)
	for y in range(54, 7, -4):
		pts.append(Vector2(-8, y))
	for k in 9:
		var a := PI + PI * k / 8.0
		pts.append(Vector2(0, 8) + Vector2(cos(a), sin(a)) * 8.0)
	for y in range(8, 49, 4):
		pts.append(Vector2(8, y))
	var s := PackedVector2Array()
	for q in pts:
		s.append(q * 1.35)
	var sh := PackedVector2Array()
	for q in s:
		sh.append(q + Vector2(2.5, 3.5))
	c.draw_polyline(sh, Color(0, 0, 0, 0.35), 3.2, true)
	c.draw_polyline(s, Color(0.42, 0.43, 0.45), 3.0, true)
	c.draw_polyline(s, Color(0.78, 0.79, 0.8), 1.8, true)
	var hi := PackedVector2Array()
	for q in s:
		hi.append(q + Vector2(-0.5, -0.6))
	c.draw_polyline(hi, Color(1, 1, 1, 0.45), 0.7, true)


# --- helpers -------------------------------------------------------------------------------
## The guidelines a point smaller at a time until they fit their page (longer translations).
func _fit_rules() -> void:
	var body := _body
	var fs := RULE_SIZE
	while is_inside_tree():
		await get_tree().process_frame
		if not is_instance_valid(body) or body != _body or fs <= 15 or body.get_combined_minimum_size().y <= _room:
			return
		fs -= 1
		for r in _rules:
			r.add_theme_font_size_override("normal_font_size", fs)
			r.add_theme_font_size_override("bold_font_size", fs)


static func _english() -> bool:
	return TranslationServer.get_locale().begins_with("en")


static func _mat(path: String, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	return m


## A soft shadow under `r`: `layers` rects, each smaller and on top of the last.
static func _shadow(c: CanvasItem, r: Rect2, off: Vector2, layers := 9, a := 0.05, step := 1.8) -> void:
	for i in layers:
		var g := (layers - i) * step
		c.draw_rect(Rect2(r.position + off - Vector2(g, g), r.size + Vector2(g, g) * 2.0), Color(0, 0, 0, a))


## One line of `s` with its baseline at `at` (x = its left, centre or right per `align`), shrunk to `max_w`.
static func _text(c: CanvasItem, f: Font, at: Vector2, s: String, fs: int, col: Color, max_w := -1.0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> float:
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if max_w > 0.0 and w > max_w:
		fs = maxi(8, int(fs * max_w / w))
		w = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x := at.x
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	c.draw_string(f, Vector2(x, at.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	return w
