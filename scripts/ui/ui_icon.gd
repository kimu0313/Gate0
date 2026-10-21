class_name UiIcon
extends Control
## Stroke pictograms drawn in code (no image assets), in the spirit of airport signage.
## Drawn on a 30 x 30 grid and scaled to the control size.

@export var icon := "order"
@export var color := Color("e8eaed")
@export var stroke := 2.4
## Animated variants (radio bars bounce, play blinks) when true.
var animated := false
var _t := 0.0


static func make(icon_name: String, px := 24.0, col := Color("e8eaed"), anim := false) -> UiIcon:
	var ic := UiIcon.new()
	ic.icon = icon_name
	ic.color = col
	ic.animated = anim
	ic.custom_minimum_size = Vector2(px, px)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return ic


func set_icon(icon_name: String, col := Color(-1, 0, 0)) -> void:
	icon = icon_name
	if col.r >= 0.0:
		color = col
	queue_redraw()


func _process(delta: float) -> void:
	if animated and is_visible_in_tree():
		_t += delta
		queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y) / 30.0
	var off := (size - Vector2(30, 30) * s) * 0.5
	draw_set_transform(off, 0.0, Vector2(s, s))
	var w := stroke
	var c := color
	match icon:
		"order":
			draw_rect(Rect2(6, 4, 18, 23), c, false, w)
			for y in [11.0, 16.0]:
				draw_line(Vector2(10, y), Vector2(20, y), c, w)
			draw_line(Vector2(10, 21), Vector2(16, 21), c, w)
		"album":
			draw_rect(Rect2(3, 8, 24, 18), c, false, w)
			draw_arc(Vector2(15, 17), 5.0, 0, TAU, 24, c, w, true)
			draw_polyline(PackedVector2Array([Vector2(10, 8), Vector2(12, 5), Vector2(18, 5), Vector2(20, 8)]), c, w)
		"map":
			draw_polyline(PackedVector2Array([Vector2(3, 7), Vector2(11, 4), Vector2(19, 7), Vector2(27, 4), Vector2(27, 23),
				Vector2(19, 26), Vector2(11, 23), Vector2(3, 26), Vector2(3, 7)]), c, w)
			draw_line(Vector2(11, 4), Vector2(11, 23), c, w)
			draw_line(Vector2(19, 7), Vector2(19, 26), c, w)
		"records", "doc":
			draw_polyline(PackedVector2Array([Vector2(18, 3), Vector2(7, 3), Vector2(7, 27), Vector2(24, 27), Vector2(24, 9), Vector2(18, 3), Vector2(18, 9), Vector2(24, 9)]), c, w)
			draw_line(Vector2(11, 15), Vector2(20, 15), c, w)
			draw_line(Vector2(11, 20), Vector2(20, 20), c, w)
		"camera":
			draw_rect(Rect2(3, 9, 17, 13), c, false, w)
			draw_polyline(PackedVector2Array([Vector2(20, 13), Vector2(27, 9), Vector2(27, 22), Vector2(20, 18)]), c, w)
		"power":
			draw_polyline(PackedVector2Array([Vector2(17, 3), Vector2(7, 17), Vector2(14, 17), Vector2(12, 27), Vector2(23, 12), Vector2(16, 12), Vector2(17, 3)]), c, w)
		"pin":
			var pts := PackedVector2Array()
			for i in 25:
				var a := lerpf(PI * 0.85, PI * 2.15, i / 24.0)
				pts.append(Vector2(15, 11) + Vector2(cos(a), sin(a)) * 8.0)
			pts.append(Vector2(15, 27))
			pts.append(pts[0])
			draw_polyline(pts, c, w)
			draw_circle(Vector2(15, 11), 2.6, c)
		"lock":
			draw_rect(Rect2(6, 13, 18, 14), c, false, w)
			draw_arc(Vector2(15, 11), 5.0, PI, TAU, 16, c, w, true)
			draw_line(Vector2(10, 11), Vector2(10, 13), c, w)
			draw_line(Vector2(20, 11), Vector2(20, 13), c, w)
		"lamp":
			draw_arc(Vector2(15, 12), 8.0, PI * 0.75, PI * 2.25, 24, c, w, true)
			draw_polyline(PackedVector2Array([Vector2(9.5, 17.5), Vector2(10, 23), Vector2(20, 23), Vector2(20.5, 17.5)]), c, w)
			draw_line(Vector2(11, 27), Vector2(19, 27), c, w)
		"lamp_on":
			draw_circle(Vector2(15, 12), 8.0, c)
			draw_rect(Rect2(10, 19, 10, 4), c)
			draw_line(Vector2(11, 27), Vector2(19, 27), c, w)
			for a in [-2.4, -1.57, -0.74]:
				var d := Vector2(cos(a), sin(a))
				draw_line(Vector2(15, 12) + d * 11.0, Vector2(15, 12) + d * 14.0, c, w)
		"radio":
			for i in 4:
				var hh := 4.0 + i * 3.4
				if animated:
					hh *= 0.55 + 0.45 * absf(sin(_t * 7.0 + i * 1.3))
				draw_line(Vector2(5 + i * 6.5, 25), Vector2(5 + i * 6.5, 25 - hh * 1.4), c, w + 0.8)
		"speaker":
			draw_colored_polygon(PackedVector2Array([Vector2(3, 11), Vector2(9, 11), Vector2(16, 5), Vector2(16, 25), Vector2(9, 19), Vector2(3, 19)]), c)
			var k := 1.0 if not animated else 0.5 + 0.5 * absf(sin(_t * 5.0))
			draw_arc(Vector2(16, 15), 6.0, -0.9, 0.9, 12, Color(c, k), w, true)
			draw_arc(Vector2(16, 15), 11.0, -0.9, 0.9, 12, Color(c, k * 0.6), w, true)
		"check":
			draw_polyline(PackedVector2Array([Vector2(6, 15.5), Vector2(12.5, 22), Vector2(24, 8)]), c, w + 0.8)
		"check_circle":
			draw_arc(Vector2(15, 15), 12.5, 0, TAU, 40, c, w, true)
			draw_polyline(PackedVector2Array([Vector2(9, 15.5), Vector2(13.5, 20), Vector2(21.5, 10.5)]), c, w + 0.6)
		"cross":
			draw_line(Vector2(8, 8), Vector2(22, 22), c, w + 0.6)
			draw_line(Vector2(22, 8), Vector2(8, 22), c, w + 0.6)
		"warn":
			draw_polyline(PackedVector2Array([Vector2(15, 3), Vector2(28, 26), Vector2(2, 26), Vector2(15, 3)]), c, w)
			draw_line(Vector2(15, 11), Vector2(15, 19), c, w + 0.6)
			draw_line(Vector2(15, 21.5), Vector2(15, 23.5), c, w + 0.6)
		"info":
			draw_arc(Vector2(15, 15), 12.0, 0, TAU, 40, c, w, true)
			draw_line(Vector2(15, 13), Vector2(15, 22), c, w + 0.4)
			draw_line(Vector2(15, 8), Vector2(15, 10), c, w + 0.4)
		"circle":
			draw_arc(Vector2(15, 15), 8.0, 0, TAU, 32, c, w, true)
		"dot":
			draw_circle(Vector2(15, 15), 5.0, c)
		"play":
			var a := 1.0 if not animated else 0.55 + 0.45 * sin(_t * 6.0)
			draw_colored_polygon(PackedVector2Array([Vector2(8, 6), Vector2(24, 15), Vector2(8, 24)]), Color(c, a))
		"arrow":
			draw_line(Vector2(3, 15), Vector2(26, 15), c, w + 0.8)
			draw_polyline(PackedVector2Array([Vector2(18, 7), Vector2(26.5, 15), Vector2(18, 23)]), c, w + 0.8)
		"plane":
			draw_colored_polygon(PackedVector2Array([Vector2(27, 15), Vector2(3, 24), Vector2(7, 18), Vector2(2, 15), Vector2(7, 12), Vector2(3, 6)]), c)
		"headphones":
			draw_arc(Vector2(15, 17), 11.0, PI, TAU, 24, c, w, true)
			draw_rect(Rect2(3, 17, 5, 9), c)
			draw_rect(Rect2(22, 17, 5, 9), c)
		"battery":
			draw_rect(Rect2(2, 9, 23, 12), c, false, w * 0.8)
			draw_rect(Rect2(5, 12, 14, 6), c)
			draw_rect(Rect2(26, 12, 3, 6), c)
		"signal":
			for i in 4:
				draw_rect(Rect2(4 + i * 6.5, 24 - (i + 1) * 4.5, 4, (i + 1) * 4.5), c)
		"eye":
			draw_arc(Vector2(15, 26), 15.0, PI * 1.22, PI * 1.78, 24, c, w, true)
			draw_arc(Vector2(15, 4), 15.0, PI * 0.22, PI * 0.78, 24, c, w, true)
			draw_circle(Vector2(15, 15), 3.6, c)
		"exit":
			draw_rect(Rect2(3, 3, 24, 24), EXIT_GREEN)
			draw_rect(Rect2(9, 8, 8, 14), INK, false, 2.0)
			draw_line(Vector2(13, 15), Vector2(25, 15), INK, 2.0)
			draw_polyline(PackedVector2Array([Vector2(21, 11), Vector2(25, 15), Vector2(21, 19)]), INK, 2.0)
		"keyboard":
			var kb := StyleBoxFlat.new()
			kb.bg_color = Color(0, 0, 0, 0)
			kb.border_color = c
			kb.set_border_width_all(int(maxf(w * 0.9, 1.0)))
			kb.set_corner_radius_all(3)
			draw_style_box(kb, Rect2(2, 7, 26, 17))
			for row in 2:
				for col in 5:
					draw_rect(Rect2(5.5 + col * 4.2, 10.5 + row * 4.2, 2.6, 2.6), c)
			draw_rect(Rect2(9.5, 19, 11, 2.4), c)
		"film":
			draw_rect(Rect2(5, 4, 20, 22), c, false, w)
			for y in [8.0, 13.0, 18.0, 23.0]:
				draw_rect(Rect2(7, y - 1.2, 2.4, 2.4), c)
				draw_rect(Rect2(21, y - 1.2, 2.4, 2.4), c)
		_:
			draw_circle(Vector2(15, 15), 4.0, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


const EXIT_GREEN := Color("22c55e")
const INK := Color("0b0e12")
