class_name FlapBoard
extends Control
## Solari-style split-flap tiles (title cards, BOARDED). Each tile flips through random glyphs,
## then settles; tiles settle left to right.

const GLYPHS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

var font_size := 120
var text_color := Color("e8eaed")
var tile_color := Color("0d1014")
var accent_first := Color(0, 0, 0, 0)   # optional color for the first character
var flip_time := 0.055
var gap := 8.0
var housing := false        # draw the tiles in a hung sign case (ending titles over the scene)
var _font: Font
var _tiles_w := 0.0
var _cells: Array = []    # {cur, target, settle}
var _t := 0.0
var _running := false
var _last_tick := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UiKit.font("display", 700)


func tile_size() -> Vector2:
	var widest := _font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	return Vector2(maxf(font_size * 0.66, widest + font_size * 0.08), font_size * 1.18)


## Sets the board text and starts flipping after `delay`.
func show_text(txt: String, delay := 0.0, per_tile := 0.07, min_flips := 5) -> void:
	_cells.clear()
	for i in txt.length():
		var ch := txt[i]
		_cells.append({"cur": " ", "target": ch, "settle": -1.0 if ch == " " else delay + (min_flips + i * per_tile / flip_time) * flip_time})
	var ts := tile_size()
	_tiles_w = txt.length() * ts.x + maxi(txt.length() - 1, 0) * gap
	custom_minimum_size = Vector2(_tiles_w, ts.y)
	if housing:
		# the case and its hanging rods take part in layout, so text below never touches them
		custom_minimum_size += Vector2(_case_pad() * 2.0, _case_pad() * 2.0 + _rod())
	_t = 0.0
	_running = true
	queue_redraw()


func _case_pad() -> float:
	return font_size * 0.16


func _rod() -> float:
	return font_size * 0.6


func settle_time() -> float:
	var m := 0.0
	for c in _cells:
		m = maxf(m, c.settle)
	return m


func _process(delta: float) -> void:
	if not _running:
		# keep redrawing: a glyph first rasterised on the settling frame can come up blank for that frame
		if is_visible_in_tree():
			queue_redraw()
		return
	_t += delta
	var done := true
	var flipped := false
	for c in _cells:
		if c.settle < 0.0:
			c.cur = c.target
			continue
		if _t >= c.settle:
			if c.cur != c.target:
				flipped = true
			c.cur = c.target
		else:
			done = false
			var step := int(_t / flip_time)
			if step != c.get("step", -1):
				c.step = step
				c.cur = GLYPHS[randi() % GLYPHS.length()]
				flipped = true
	if flipped:
		var now := Time.get_ticks_msec()
		if now - _last_tick > 45:
			_last_tick = now
			Snd.play("keypad_beep", -26.0, randf_range(1.9, 2.3))
	queue_redraw()
	if done:
		_running = false


func _draw() -> void:
	var ts := tile_size()
	var asc := _font.get_ascent(font_size)
	var desc := _font.get_descent(font_size)
	var x0 := (size.x - _tiles_w) * 0.5
	var y0 := (size.y - ts.y) * 0.5
	if housing and not _cells.is_empty():
		y0 += _rod() * 0.5
		var case := Rect2(Vector2(x0, y0), Vector2(_tiles_w, ts.y)).grow(_case_pad())
		for rx in [case.position.x + case.size.x * 0.15, case.end.x - case.size.x * 0.15]:
			draw_rect(Rect2(rx - 3, case.position.y - _rod(), 6, _rod()), Color(0.16, 0.17, 0.19))
		draw_rect(case.grow(6), Color(0, 0, 0, 0.35))
		draw_rect(case, Color("07090b"))
		draw_rect(case, Color(text_color, 0.45), false, 3.0)
	for i in _cells.size():
		var c: Dictionary = _cells[i]
		var r := Rect2(Vector2(x0 + i * (ts.x + gap), y0), ts)
		if c.target == " ":
			continue
		draw_rect(r, tile_color)
		draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.5)), tile_color.lightened(0.05))
		var col := text_color
		if i == 0 and accent_first.a > 0.0:
			col = accent_first
		var settled: bool = c.cur == c.target and (c.settle < 0.0 or _t >= c.settle)
		if not settled:
			col = Color(col, 0.85)
		var baseline := r.position.y + (r.size.y + asc - desc) * 0.5
		# no width limit: a width-constrained draw silently drops glyphs wider than the tile (M, N, W, D)
		var gw := _font.get_string_size(c.cur, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(_font, Vector2(r.position.x + (r.size.x - gw) * 0.5, baseline), c.cur, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
		# moving flap while the tile is still cycling
		if not settled:
			var p := fmod(_t, flip_time) / flip_time
			var fh := r.size.y * 0.5 * (1.0 - p)
			draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.5 - fh), Vector2(r.size.x, fh)), Color(0, 0, 0, 0.45))
		draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Color(0, 0, 0, 0.85), maxf(2.0, font_size * 0.02))
		draw_rect(r, Color(1, 1, 1, 0.05), false, 1.0)
