class_name SignRow
extends Button
## Wayfinding-sign menu row: index number, label, optional meta text and an arrow.
## On hover a signal-blue fill sweeps in from the left and the text switches to the ink that reads on it.

var label_text := ""
var index_text := ""
var meta_text := ""
var accent := UiKit.SIGNAL
var font_size := 24
var group: Array = []      # rows of one menu (see link): one stays highlighted, arrow keys / d-pad move it
var lit := false
var _fill := 0.0
var _tw: Tween


static func make(idx: String, txt: String, cb: Callable, meta := "", accent_color := UiKit.SIGNAL, w := 520.0, h := 62.0) -> SignRow:
	var r := SignRow.new()
	r.index_text = idx
	r.label_text = UiKit.t(txt)
	r.meta_text = UiKit.t(meta)
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
	mouse_exited.connect(func():
		# in a linked menu the last row stays selected, like a console menu
		if group.is_empty():
			_on_hover(false))
	pressed.connect(func():
		Snd.play("ui_tap", -8.0)
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2(0.985, 0.94), 0.05)
		tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))
	resized.connect(func(): pivot_offset = size * 0.5)


func _on_hover(on: bool) -> void:
	if disabled or on == lit:
		return
	if on:
		Snd.play("ui_click", -16.0, 1.1)
		for r in group:
			if r != self and r.lit:
				r._on_hover(false)
	lit = on
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_method(_set_fill, _fill, 1.0 if on else 0.0, 0.2 if on else 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Makes `rows` one menu: a single highlighted row that the mouse or the keyboard / d-pad moves.
static func link(rows: Array) -> void:
	for r in rows:
		r.group = rows


## Highlights the first enabled row without the hover click (menu opened).
static func select_first(rows: Array) -> void:
	for r: SignRow in rows:
		if not r.disabled:
			r._on_hover(true)
			return


## ui_up / ui_down move the highlight, ui_accept presses it. Returns true if the event was used.
static func navigate(rows: Array, event: InputEvent) -> bool:
	var live: Array = rows.filter(func(r: SignRow): return r.is_visible_in_tree() and not r.disabled)
	if live.is_empty():
		return false
	var cur := -1
	for i in live.size():
		if live[i].lit:
			cur = i
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		var step := 1 if event.is_action_pressed("ui_down") else -1
		(live[0 if cur < 0 else wrapi(cur + step, 0, live.size())] as SignRow)._on_hover(true)
		return true
	if event.is_action_pressed("ui_accept") and cur >= 0:
		(live[cur] as SignRow).pressed.emit()
		return true
	return false


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
	var ink := UiKit.ink_on(accent)
	var fg := Color("e8eaed").lerp(ink, _fill)
	var fg_idx := Color("7c8590").lerp(ink, _fill)
	if dim:
		fg = Color("4a525d")
		fg_idx = fg
	var mono := UiKit.font("display", 700)
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
		draw_string(mono, Vector2(mx, base + ma * 0.5), meta_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("7c8590").lerp(ink, _fill))
	if _fill > 0.05:
		var ax := w - 50.0 - (1.0 - _fill) * 18.0
		var ac := Color(ink, _fill)
		draw_line(Vector2(ax, base), Vector2(ax + 28, base), ac, 3.5)
		draw_polyline(PackedVector2Array([Vector2(ax + 19, base - 8), Vector2(ax + 29, base), Vector2(ax + 19, base + 8)]), ac, 3.5)
