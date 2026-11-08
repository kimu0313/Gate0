class_name Viewfinder
extends Control
## The camera's viewfinder over the screen while you hold the camera up (Player.camera_mode, the right mouse button — user:
## "카메라 꺼내기는 마우스 우클릭"): a soft dark edge, corner brackets, a focus box and a cross in the middle, a battery and the shot count
## at the top, the keys at the bottom. Drawn in code; Hud shows it and flashes white on a shot.

var shots := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.full_rect(self)


func _draw() -> void:
	var s := size
	var ink := Color(0.93, 0.94, 0.92, 0.9)
	# a soft dark edge round the frame
	var edge := Color(0, 0, 0, 0.35)
	var b := minf(s.x, s.y) * 0.06
	draw_rect(Rect2(0, 0, s.x, b), edge)
	draw_rect(Rect2(0, s.y - b, s.x, b), edge)
	draw_rect(Rect2(0, b, b, s.y - 2.0 * b), edge)
	draw_rect(Rect2(s.x - b, b, b, s.y - 2.0 * b), edge)
	# corner brackets
	var inset := Vector2(s.x * 0.1, s.y * 0.12)
	var arm := minf(s.x, s.y) * 0.06
	var w := 3.0
	for c: Vector2 in [inset, Vector2(s.x - inset.x, inset.y), Vector2(inset.x, s.y - inset.y), s - inset]:
		var dx := arm if c.x < s.x * 0.5 else -arm
		var dy := arm if c.y < s.y * 0.5 else -arm
		draw_line(c, c + Vector2(dx, 0), ink, w)
		draw_line(c, c + Vector2(0, dy), ink, w)
	# the focus box and the cross in the middle
	var mid := s * 0.5
	var fb := Vector2(s.y * 0.11, s.y * 0.08)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var p := mid + Vector2(sx * fb.x, sy * fb.y)
			draw_line(p, p - Vector2(sx * fb.x * 0.35, 0), ink, 2.0)
			draw_line(p, p - Vector2(0, sy * fb.y * 0.45), ink, 2.0)
	draw_line(mid - Vector2(10, 0), mid + Vector2(10, 0), ink, 1.5)
	draw_line(mid - Vector2(0, 10), mid + Vector2(0, 10), ink, 1.5)
	# the battery and the shot count at the top
	var f := UiKit.font("mono", 500)
	var fs := 22
	var top := inset.y - 18.0
	var bat := Rect2(inset.x, top - 18.0, 40.0, 18.0)
	draw_rect(bat, ink, false, 2.0)
	draw_rect(Rect2(bat.end.x, top - 13.0, 4.0, 8.0), ink)
	draw_rect(Rect2(bat.position + Vector2(4, 4), Vector2(18, 10)), ink)
	var count := "%03d" % shots
	var cw := f.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(f, Vector2(s.x - inset.x - cw, top), count, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	# the keys at the bottom
	var keys := "[%s] %s     [%s] %s" % [UiKit.t("좌클릭"), UiKit.t("촬영"), Game.key_label("camera"), UiKit.t("카메라 내리기")]
	var kf := UiKit.font("sans", 600)
	var kw := kf.get_string_size(keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(kf, Vector2((s.x - kw) * 0.5, s.y - inset.y + 40.0), keys, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, ink)
