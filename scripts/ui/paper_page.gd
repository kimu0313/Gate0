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
const HOLES := [0.2, 0.5, 0.8]


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS


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
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(v)
	var ink := UiKit.PAPER_INK if not dark else Color(0.55, 0.95, 0.6)
	if not document and not memo:
		var head := HBoxContainer.new()
		v.add_child(head)
		var org := UiKit.label("서해국제공항 · 시설운영팀  |  야간 시설 점검 근무 수칙", 15, Color(0.33, 0.32, 0.3), font_kind)
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
	_body = UiKit.rich(str(p.get("body", "")), body_size, ink, font_kind)
	_body.add_theme_constant_override("line_separation", 7)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_body)
	queue_redraw()


func _paper_color() -> Color:
	if page.get("kind", "") == "memo":
		return Color(0.98, 0.9, 0.45)
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
		var tint := Color(1.06, 0.98, 0.5) if memo else Color.WHITE
		# offset the texture per page so sheets don't look identical
		var src := Rect2(rng.randf_range(0, 80), rng.randf_range(0, 120), tex.get_width() - 100, tex.get_height() - 140)
		draw_texture_rect_region(tex, Rect2(0, 0, w, h), src, tint)
	else:
		draw_rect(Rect2(0, 0, w, h), _paper_color())
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
	if binder_page:
		for f in HOLES:
			var c := Vector2(36, h * f)
			draw_circle(c, 15.0, Color(0.84, 0.81, 0.73))
			draw_arc(c, 15.0, 0, TAU, 32, Color(0.6, 0.56, 0.48, 0.5), 1.2, true)
			draw_circle(c, 9.0, Color("101a33"))
			draw_arc(c, 9.0, PI * 0.9, PI * 1.9, 16, Color(0, 0, 0, 0.5), 2.0, true)
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
		draw_string(ff, Vector2(x0, h - 66), str(page.get("rev", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.24, 0.23, 0.21))
		draw_string(UiKit.font("display", 600), Vector2(x0, h - 38), "SEOHAE INT'L AIRPORT · FACILITY OPS", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.42, 0.4, 0.36))
		_draw_stamp(str(page.get("stamp", "none")), Vector2(w - 160, h - 160), rng.randf_range(-0.35, 0.2))


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
	var f := UiKit.font("serif", 700)
	var r := 80.0
	draw_set_transform(c, angle)
	var ring := UiArt.tex("stamp_seal_ring")
	if ring:
		draw_texture_rect(ring, Rect2(-r, -r, r * 2, r * 2), false, col)
	else:
		draw_arc(Vector2.ZERO, r * 0.86, 0, TAU, 64, col, 6.0, true)
		draw_arc(Vector2.ZERO, r * 0.72, 0, TAU, 64, col, 2.0, true)
	draw_string(f, Vector2(-r, -12), lines[0], HORIZONTAL_ALIGNMENT_CENTER, r * 2, 16, col)
	draw_string(f, Vector2(-r, 14), lines[1], HORIZONTAL_ALIGNMENT_CENTER, r * 2, 19, col)
	draw_string(f, Vector2(-r, 40), lines[2], HORIZONTAL_ALIGNMENT_CENTER, r * 2, 16, col)
	# ink voids: paper-colored specks over the impression
	var grunge := UiArt.tex("stamp_grunge")
	if grunge:
		draw_texture_rect(grunge, Rect2(-r, -r, r * 2, r * 2), false, Color(_paper_color(), 0.85))
	draw_set_transform(Vector2.ZERO, 0.0)
