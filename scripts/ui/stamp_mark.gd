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
	s.lines = stamp_lines
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
	var longest := 1
	for l in lines:
		longest = maxi(longest, str(l).length())
	var fs := int(minf(r * (0.3 if n <= 2 else 0.22), r * 1.25 / longest))
	var y0 := -fs * (n - 1) * 0.6 + fs * 0.35
	for i in n:
		var sz := fs if i != n / 2 or n <= 2 else int(fs * 1.25)
		draw_string(f, Vector2(-r, y0 + i * fs * 1.2), str(lines[i]), HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, sz, ink)
