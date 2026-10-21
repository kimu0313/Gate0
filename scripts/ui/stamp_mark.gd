class_name StampMark
extends Control
## Rubber-stamp impression: tablet judgment (NORMAL / ANOMALY) and the morning report seal.
## Uses the generated ink art when present; otherwise draws the stamp.

var lines: Array = ["정상", "NORMAL"]
var ink := Color("3fd0b0")
var shape := "rect"           # rect | round
var art := ""                 # UiArt id of a white-ink stamp texture, tinted with `ink`
var angle_deg := -8.0


static func make(stamp_lines: Array, ink_color: Color, stamp_shape := "rect", art_id := "", px := Vector2(420, 190)) -> StampMark:
	var s := StampMark.new()
	# translated; a bilingual pair that reads the same in this language ("정상"/"NORMAL") keeps one line
	var out: Array = []
	for l in stamp_lines:
		var tl := UiKit.t(str(l), "stamp")
		if out.is_empty() or tl.to_upper() != str(out[out.size() - 1]).to_upper():
			out.append(tl)
	s.lines = out
	s.ink = ink_color
	s.shape = stamp_shape
	s.art = art_id
	s.custom_minimum_size = px
	s.size = px
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _draw() -> void:
	var c := size * 0.5
	draw_set_transform(c, deg_to_rad(angle_deg), Vector2.ONE)
	var half := size * 0.5
	var t: Texture2D = UiArt.tex(art) if art != "" else null
	if t:
		draw_texture_rect(t, Rect2(-half, size), false, ink)
		if shape == "round":
			_draw_round_text(half)
	elif shape == "round":
		var r := minf(half.x, half.y) * 0.96
		draw_arc(Vector2.ZERO, r, 0, TAU, 72, ink, r * 0.07, true)
		draw_arc(Vector2.ZERO, r * 0.84, 0, TAU, 72, ink, r * 0.025, true)
		_draw_round_text(half)
	else:
		var r := Rect2(-half + Vector2(6, 6), size - Vector2(12, 12))
		draw_rect(r, ink, false, 7.0)
		draw_rect(r.grow(-13), ink, false, 2.5)
		var f := UiKit.font("sans", 900)
		var fe := UiKit.font("display", 700)
		var big := int(size.y * 0.36)
		var small := int(size.y * 0.17)
		var y := -size.y * 0.04
		draw_string(f, Vector2(-half.x, y), str(lines[0]), HORIZONTAL_ALIGNMENT_CENTER, size.x, big, ink)
		if lines.size() > 1:
			draw_string(fe, Vector2(-half.x, y + small * 1.65), str(lines[1]), HORIZONTAL_ALIGNMENT_CENTER, size.x, small, ink)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_round_text(half: Vector2) -> void:
	var f := UiKit.font("serif", 700)
	var r := minf(half.x, half.y)
	var n := lines.size()
	var base := r * (0.3 if n <= 2 else 0.22)
	var y0 := -base * (n - 1) * 0.6 + base * 0.35
	# one size for every line, the largest that keeps each line inside the inner ring at its height
	# (measured, not counted: a Latin line is far narrower per character than Hangul)
	var fs := base
	for i in n:
		var w := f.get_string_size(str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x / 100.0
		fs = minf(fs, _ring_room(r, y0 + i * base * 1.2 - base * 0.35) / maxf(w, 0.01))
	y0 = -fs * (n - 1) * 0.6 + fs * 0.35
	for i in n:
		var sz := int(fs) if i != n / 2 or n <= 2 else int(fs * 1.25)
		var y := y0 + i * fs * 1.2
		var w := f.get_string_size(str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		if w > _ring_room(r, y - sz * 0.35):
			sz = int(sz * _ring_room(r, y - sz * 0.35) / w)
			w = f.get_string_size(str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		draw_string(f, Vector2(-w * 0.5, y), str(lines[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, sz, ink)


## Width a line centred at height y can use inside the stamp's inner ring (outer radius r).
static func _ring_room(r: float, y: float) -> float:
	var ri := r * 0.68
	return 1.8 * sqrt(maxf(ri * ri - y * y, 1.0))
