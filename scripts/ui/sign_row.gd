class_name SignRow
extends Button
## Wayfinding-sign menu row: index number, label, optional meta text and an arrow.
## On hover a signal-yellow fill sweeps in from the left and the text inverts.

var label_text := ""
var index_text := ""
var meta_text := ""
var accent := Color("ffc21a")
var font_size := 24
var _fill := 0.0
var _tw: Tween


static func make(idx: String, txt: String, cb: Callable, meta := "", accent_color := Color("ffc21a"), w := 520.0, h := 62.0) -> SignRow:
	var r := SignRow.new()
	r.index_text = idx
	r.label_text = txt
	r.meta_text = meta
	r.accent = accent_color
	r.custom_minimum_size = Vector2(w, h)
	if cb.is_valid():
		r.pressed.connect(cb)
	return r


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	pressed.connect(func():
		Snd.play("ui_tap", -8.0)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(0.985, 0.94), 0.05)
		tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	resized.connect(func(): pivot_offset = size * 0.5)


func _on_hover(on: bool) -> void:
	if disabled:
		return
	if on:
		Snd.play("ui_click", -16.0, 1.1)
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_method(_set_fill, _fill, 1.0 if on else 0.0, 0.2 if on else 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _set_fill(v: float) -> void:
	_fill = v
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_line(Vector2(0, h - 0.5), Vector2(w, h - 0.5), Color(1, 1, 1, 0.1), 1.0)
	if _fill > 0.001:
		draw_rect(Rect2(0, 0, w * _fill, h), accent)
	var dim := disabled
	var fg := Color("e8eaed").lerp(Color("0b0e12"), _fill)
	var fg_idx := Color("7c8590").lerp(Color("0b0e12"), _fill)
	if dim:
		fg = Color("4a525d")
		fg_idx = fg
	var mono := UiKit.font("mono", 700)
	var sans := UiKit.font("sans", 700 if _fill > 0.5 else 500)
	var base := h * 0.5
	var x := 22.0
	if index_text != "":
		var ia := mono.get_ascent(16) - mono.get_descent(16)
		draw_string(mono, Vector2(x, base + ia * 0.5), index_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, fg_idx)
		x += 52.0
	var la := sans.get_ascent(font_size) - sans.get_descent(font_size)
	draw_string(sans, Vector2(x + _fill * 6.0, base + la * 0.5), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fg)
	if meta_text != "":
		var ma := mono.get_ascent(15) - mono.get_descent(15)
		var mw := mono.get_string_size(meta_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var mx := w - 22.0 - mw - (46.0 * _fill)
		draw_string(mono, Vector2(mx, base + ma * 0.5), meta_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("7c8590").lerp(Color("0b0e12"), _fill))
	if _fill > 0.05:
		var ax := w - 50.0 - (1.0 - _fill) * 18.0
		var ac := Color(Color("0b0e12"), _fill)
		draw_line(Vector2(ax, base), Vector2(ax + 28, base), ac, 3.5)
		draw_polyline(PackedVector2Array([Vector2(ax + 19, base - 8), Vector2(ax + 29, base), Vector2(ax + 19, base + 8)]), ac, 3.5)
