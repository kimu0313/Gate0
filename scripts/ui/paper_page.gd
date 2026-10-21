class_name PaperPage
extends Control
## Renders one sheet of paper: rulebook pages (revision line, page number, approval stamp, stains,
## punched holes) or free-form documents (diaries, notes, logs). Uses the generated paper and stamp ink
## art when present. Fonts, stamps and revision dates are gameplay clues — draw them faithfully.

var page := {}            # RulesDB page dict, or {title, body, font}
var is_document := false
var left_margin := 64
var _title: Label
var _body: RichTextLabel
var _seed := 0
var _margin: MarginContainer
const HOLES := [0.2, 0.5, 0.8]
const MEMO_ANGLE := -0.03          # the sticky note sits slightly askew
const MEMO_COLOR := Color("e9d88a")


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_layout_memo)


func show_page(p: Dictionary, document := false) -> void:
	page = p
	is_document = document
	_seed = hash(str(p.get("title", "")) + str(p.get("rev", "")))
	for c in get_children():
		c.queue_free()
	var font_kind: String = p.get("font", "sans")
	var memo: bool = p.get("kind", "") == "memo"
	var dark := font_kind == "mono"
	var margin := MarginContainer.new()
	UiKit.full_rect(margin)
	margin.add_theme_constant_override("margin_left", left_margin if not document else 64)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_top", 56 if not document else 100)
	margin.add_theme_constant_override("margin_bottom", 124)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	_margin = margin
	_layout_memo()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(v)
	var ink := UiKit.PAPER_INK if not dark else Color(0.55, 0.95, 0.6)
	if not document and not memo:
		var head := HBoxContainer.new()
		v.add_child(head)
		var org := UiKit.label("서해국제공항 · 시설운영팀  |  야간 시설 점검 근무 수칙", UiKit.MIN_TEXT, Color(0.33, 0.32, 0.3), font_kind)
		org.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(org)
		var no := str(p.get("no", ""))
		head.add_child(UiKit.label("p.%s" % no if no != "" else "", 19, Color(0.23, 0.22, 0.2), font_kind, 700))
		var rule := ColorRect.new()
		rule.color = Color(0.23, 0.22, 0.2, 0.85)
		rule.custom_minimum_size = Vector2(0, 2)
		v.add_child(rule)
	_title = UiKit.label(str(p.get("title", "")), 34 if not memo else 30, ink, font_kind, 700)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	var body_size := 22
	if font_kind == "hand":
		body_size = 36
		_title.add_theme_font_size_override("font_size", 38)
	if font_kind == "mono":
		body_size = 18
	_body = UiKit.rich(_format_body(UiKit.t(str(p.get("body", "")))), body_size, ink, font_kind)
	_body.add_theme_constant_override("line_separation", 7)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_body)
	queue_redraw()
	_fit_body()


## Longer translations can run into the footer and stamp: shrink the body a point at a time until
## the text fits above them.
func _fit_body() -> void:
	if not is_inside_tree():
		return
	var body := _body
	await get_tree().process_frame
	while is_instance_valid(body) and body == _body:
		var limit := size.y - float(_margin.get_theme_constant("margin_top")) - float(_margin.get_theme_constant("margin_bottom"))
		var fs := body.get_theme_font_size("normal_font_size")
		if fs <= 15 or (_margin.get_child(0) as Control).get_combined_minimum_size().y <= limit:
			return
		body.add_theme_font_size_override("normal_font_size", fs - 1)
		body.add_theme_font_size_override("bold_font_size", fs - 1)
		await get_tree().process_frame


## Rule items ("① …", "→ …") become two-column rows so a wrapped line hangs under its text instead
## of running back to the margin ([ul] lists don't hang), and stray leading spaces are dropped.
static func _format_body(src: String) -> String:
	var numbered := RegEx.create_from_string("^([①-⑳])\\s*(.*)$")
	var out := ""
	for raw in src.split("\n"):
		# rule text indents sub-items with ideographic spaces (U+3000), which strip_edges keeps
		var line := raw.lstrip(" \t　")
		if line.begins_with("→"):
			out += _hanging("→", line.trim_prefix("→").strip_edges(true, false), 30)
			continue
		var m := numbered.search(line)
		if m:
			out += _hanging(m.get_string(1), m.get_string(2), 0)
			continue
		out += line + "\n"
	return out.trim_suffix("\n")


static func _hanging(marker: String, text: String, indent: int) -> String:
	return "[table=2][cell padding=%d,0,10,0]%s[/cell][cell expand=1]%s[/cell][/table]\n" % [indent, marker, text]


## Height the sheet needs for its text (documents are sized to fit instead of leaving a blank half).
func content_height() -> float:
	if _margin == null:
		return size.y
	var top := float(_margin.get_theme_constant("margin_top"))
	var bottom := float(_margin.get_theme_constant("margin_bottom"))
	return top + bottom + (_margin.get_child(0) as Control).get_combined_minimum_size().y


func _memo_rect() -> Rect2:
	return Rect2(size.x * 0.1, size.y * 0.09, size.x * 0.78, size.y * 0.66)


## A memo is written on a sticky note stuck to a blank page, so its text sits inside the note.
func _layout_memo() -> void:
	if _margin == null or page.get("kind", "") != "memo":
		return
	var n := _memo_rect()
	_margin.add_theme_constant_override("margin_left", int(n.position.x + 44))
	_margin.add_theme_constant_override("margin_right", int(size.x - n.end.x + 36))
	_margin.add_theme_constant_override("margin_top", int(n.position.y + 56))
	_margin.add_theme_constant_override("margin_bottom", int(size.y - n.end.y + 30))
	_margin.pivot_offset = n.get_center()
	_margin.rotation = MEMO_ANGLE


func _paper_color() -> Color:
	if page.get("kind", "") == "memo":
		return MEMO_COLOR
	return UiKit.PAPER


func _draw() -> void:
	var w := size.x
	var h := size.y
	var memo: bool = page.get("kind", "") == "memo"
	var dark: bool = page.get("font", "") == "mono"
	var binder_page := not is_document and not memo
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var tex := UiArt.tex("paper_sheet")
	if dark:
		draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.07, 0.06))
		var y := 0.0
		while y < h:
			draw_line(Vector2(0, y), Vector2(w, y), Color(0.4, 1.0, 0.5, 0.025), 1.0)
			y += 3.0
	elif tex:
		# offset the texture per page so sheets don't look identical; keep the grain's aspect on
		# shorter sheets (documents are sized to their text)
		var sw := float(tex.get_width() - 100)
		var sh := minf(sw * h / maxf(w, 1.0), tex.get_height() - 140.0)
		var src := Rect2(rng.randf_range(0, 80), rng.randf_range(0, 120), sw, sh)
		draw_texture_rect_region(tex, Rect2(0, 0, w, h), src)
	else:
		draw_rect(Rect2(0, 0, w, h), UiKit.PAPER)
	if not dark:
		# fibres and specks
		for i in (90 if tex else 220):
			var p := Vector2(rng.randf() * w, rng.randf() * h)
			draw_circle(p, rng.randf_range(0.5, 1.5), Color(0, 0, 0, rng.randf_range(0.01, 0.035)))
		# soft shading toward the binding edge and the outer edge
		for i in 18:
			var a := 0.055 * (1.0 - i / 18.0)
			draw_rect(Rect2(i * 2.0, 0, 2.0, h), Color(0.25, 0.2, 0.12, a))
			draw_rect(Rect2(w - (i + 1) * 1.5, 0, 1.5, h), Color(0.25, 0.2, 0.12, a * 0.5))
	# punched holes with reinforcement rings
	if binder_page or memo:
		for f in HOLES:
			var c := Vector2(36, h * f)
			draw_circle(c, 15.0, Color(0.84, 0.81, 0.73))
			draw_arc(c, 15.0, 0, TAU, 32, Color(0.6, 0.56, 0.48, 0.5), 1.2, true)
			draw_circle(c, 9.0, Color("101a33"))
			draw_arc(c, 9.0, PI * 0.9, PI * 1.9, 16, Color(0, 0, 0, 0.5), 2.0, true)
	if memo:
		_draw_memo(rng)
	# stains for damaged pages
	if page.get("stain", false):
		for i in 7:
			var c := Vector2(rng.randf_range(0.15, 0.9) * w, rng.randf_range(0.25, 0.85) * h)
			var r := rng.randf_range(40, 120)
			draw_circle(c, r, Color(0.45, 0.3, 0.12, 0.12))
			draw_arc(c, r, 0, TAU, 48, Color(0.4, 0.25, 0.1, 0.25), 3.0)
	# footer
	if binder_page:
		var ff := UiKit.font(str(page.get("font", "sans")))
		var x0 := float(left_margin)
		draw_line(Vector2(x0, h - 100), Vector2(w - 64, h - 100), Color(0.23, 0.22, 0.2, 0.55), 1.5)
		draw_string(ff, Vector2(x0, h - 66), UiKit.t(str(page.get("rev", ""))), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.24, 0.23, 0.21))
		draw_string(UiKit.font("display", 600), Vector2(x0, h - 38), "SEOHAE INT'L AIRPORT · FACILITY OPS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.42, 0.4, 0.36))
		_draw_stamp(str(page.get("stamp", "none")), Vector2(w - 160, h - 160), rng.randf_range(-0.35, 0.2))


## Lined sticky note (duller than signal yellow) with a strip of tape, drawn askew like the text on it.
func _draw_memo(rng: RandomNumberGenerator) -> void:
	var n := _memo_rect()
	var c := n.get_center()
	draw_set_transform(c, MEMO_ANGLE)
	var r := Rect2(-n.size * 0.5, n.size)
	for i in 6:
		draw_rect(r.grow(i * 1.5).grow_individual(0, -i, 0, i * 1.5), Color(0, 0, 0, 0.035))
	draw_rect(r, MEMO_COLOR)
	draw_rect(Rect2(r.position, Vector2(r.size.x, 34)), MEMO_COLOR.darkened(0.06))
	var y := r.position.y + 96.0
	while y < r.end.y - 24.0:
		draw_line(Vector2(r.position.x + 22, y), Vector2(r.end.x - 22, y), Color(0.35, 0.45, 0.6, 0.22), 1.2)
		y += 47.0
	for i in 40:
		draw_circle(r.position + Vector2(rng.randf() * r.size.x, rng.randf() * r.size.y), rng.randf_range(0.5, 1.2), Color(0.3, 0.25, 0.1, 0.05))
	var tape := Rect2(Vector2(-70, r.position.y - 16), Vector2(140, 36))
	draw_set_transform(c, MEMO_ANGLE + 0.05)
	draw_rect(tape, Color(0.95, 0.94, 0.88, 0.55))
	draw_rect(tape, Color(1, 1, 1, 0.25), false, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_stamp(kind: String, c: Vector2, angle: float) -> void:
	var col := Color(0.72, 0.13, 0.1, 0.82)
	var lines := ["서해국제공항", "시설운영팀", "승  인"]
	match kind:
		"none":
			return
		"old":
			col = Color(0.08, 0.08, 0.1, 0.82)
			lines = ["서 해 비 행 장", "운 항 과", "1987"]
		"blue":
			col = Color(0.12, 0.22, 0.68, 0.82)
			lines = ["서해국제공항", "시설운영팀", "긴  급"]
		"team":
			lines = ["서해국제공항", "승객운송팀", "승  인"]
	# the department name stays the clue in every language (official vs. other team)
	for i in lines.size():
		lines[i] = UiKit.t(lines[i], "stamp")
	var f := UiKit.font("serif", 700)
	var r := 80.0
	draw_set_transform(c, angle)
	var ring := UiArt.tex("stamp_seal_ring")
	if ring:
		draw_texture_rect(ring, Rect2(-r, -r, r * 2, r * 2), false, col)
	else:
		draw_arc(Vector2.ZERO, r * 0.86, 0, TAU, 64, col, 6.0, true)
		draw_arc(Vector2.ZERO, r * 0.72, 0, TAU, 64, col, 2.0, true)
	# each line shrinks to stay inside the inner ring (English department names run long);
	# drawn without a width limit, which would silently drop glyphs that do not fit
	for i in 3:
		var fs: int = [16, 19, 16][i]
		var y: float = [-12, 14, 40][i]
		var room := StampMark._ring_room(r, y - fs * 0.35)
		var w := f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if w > room:
			fs = maxi(9, int(fs * room / w))
			w = f.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(-w * 0.5, y), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	# ink voids: paper-colored specks over the impression
	var grunge := UiArt.tex("stamp_grunge")
	if grunge:
		draw_texture_rect(grunge, Rect2(-r, -r, r * 2, r * 2), false, Color(_paper_color(), 0.85))
	draw_set_transform(Vector2.ZERO, 0.0)
