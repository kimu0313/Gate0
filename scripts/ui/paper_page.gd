class_name PaperPage
extends Control
## Renders one sheet of paper: rulebook pages (with revision line, page number, approval stamp,
## stains) or free-form documents (diaries, notes, logs).

var page := {}            # RulesDB page dict, or {title, body, font}
var is_document := false
var _title: Label
var _body: RichTextLabel
var _seed := 0


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
	var margin := MarginContainer.new()
	UiKit.full_rect(margin)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 120)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(v)
	var ink := Color(0.12, 0.12, 0.14)
	if not document and not memo:
		var head := HBoxContainer.new()
		v.add_child(head)
		var org := UiKit.label("서해국제공항 · 시설운영팀  |  야간 시설 점검 근무 수칙", 15, Color(0.35, 0.35, 0.38), font_kind)
		org.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(org)
		var no := str(p.get("no", ""))
		head.add_child(UiKit.label("p.%s" % no if no != "" else "", 18, Color(0.3, 0.3, 0.33), font_kind, 700))
		var rule := ColorRect.new()
		rule.color = Color(0.2, 0.2, 0.25, 0.6)
		rule.custom_minimum_size = Vector2(0, 2)
		v.add_child(rule)
	_title = UiKit.label(str(p.get("title", "")), 34 if not memo else 30, ink, font_kind, 700)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	var body_size := 22
	if font_kind == "hand":
		body_size = 25
	if font_kind == "mono":
		body_size = 18
	_body = UiKit.rich(str(p.get("body", "")), body_size, ink, font_kind)
	_body.add_theme_constant_override("line_separation", 6)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_body)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var memo: bool = page.get("kind", "") == "memo"
	var paper := Color(0.93, 0.91, 0.85) if not memo else Color(0.98, 0.9, 0.45)
	if page.get("font", "") == "mono":
		paper = Color(0.06, 0.08, 0.07)
	draw_rect(Rect2(0, 0, w, h), paper)
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	# paper grain
	for i in 220:
		var p := Vector2(rng.randf() * w, rng.randf() * h)
		draw_circle(p, rng.randf_range(0.5, 1.6), Color(0, 0, 0, rng.randf_range(0.01, 0.04)))
	# binder holes
	if not is_document and not memo:
		for y in [0.2, 0.5, 0.8]:
			draw_circle(Vector2(26, h * y), 9.0, Color(0.25, 0.25, 0.27))
	# stains for damaged pages
	if page.get("stain", false):
		for i in 7:
			var c := Vector2(rng.randf_range(0.15, 0.9) * w, rng.randf_range(0.25, 0.85) * h)
			var r := rng.randf_range(40, 120)
			draw_circle(c, r, Color(0.45, 0.3, 0.12, 0.12))
			draw_arc(c, r, 0, TAU, 48, Color(0.4, 0.25, 0.1, 0.25), 3.0)
	# footer
	if not is_document and not memo:
		var ff := UiKit.font(str(page.get("font", "sans")))
		draw_line(Vector2(64, h - 96), Vector2(w - 64, h - 96), Color(0.2, 0.2, 0.25, 0.5), 1.5)
		draw_string(ff, Vector2(64, h - 62), str(page.get("rev", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.25, 0.25, 0.28))
		draw_string(ff, Vector2(64, h - 36), "SEOHAE INT'L AIRPORT · FACILITY OPS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.4, 0.4, 0.43))
		_draw_stamp(str(page.get("stamp", "none")), Vector2(w - 150, h - 150), rng.randf_range(-0.35, 0.2))


func _draw_stamp(kind: String, c: Vector2, angle: float) -> void:
	var col := Color(0.75, 0.1, 0.1, 0.78)
	var lines := ["서해국제공항", "시설운영팀", "승  인"]
	match kind:
		"none":
			return
		"old":
			col = Color(0.08, 0.08, 0.1, 0.8)
			lines = ["서 해 비 행 장", "운 항 과", "1987"]
		"blue":
			col = Color(0.12, 0.2, 0.7, 0.8)
			lines = ["서해국제공항", "시설운영팀", "긴  급"]
		"team":
			lines = ["서해국제공항", "승객운송팀", "승  인"]
	var f := UiKit.font("serif", 700)
	draw_set_transform(c, angle)
	draw_arc(Vector2.ZERO, 66, 0, TAU, 64, col, 5.0, true)
	draw_arc(Vector2.ZERO, 56, 0, TAU, 64, col, 2.0, true)
	draw_string(f, Vector2(-60, -14), lines[0], HORIZONTAL_ALIGNMENT_CENTER, 120, 17, col)
	draw_string(f, Vector2(-60, 12), lines[1], HORIZONTAL_ALIGNMENT_CENTER, 120, 19, col)
	draw_string(f, Vector2(-60, 38), lines[2], HORIZONTAL_ALIGNMENT_CENTER, 120, 17, col)
	draw_set_transform(Vector2.ZERO, 0.0)
