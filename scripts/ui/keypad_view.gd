class_name KeypadView
extends Control
## 4-digit door lock. The whole device is generated art (assets/ui/keypad_staff.png, the staff-door access keypad;
## keypad_full.png is the older stainless one): invisible hit areas sit on the painted keys, presses darken the key,
## and the LCD digits and LED are drawn on top.

signal submitted(code: String)
signal closed

const ART := Vector2(1024, 1536)                    # coordinates below are in this space
const ART_LCD := Rect2(232, 236, 580, 181)          # measured on keypad_staff (debug: keypad r2 measure.py)
const ART_LED := Vector2(784, 134)
const ART_KEY0 := Vector2(243, 493)
const ART_KEY_STEP := Vector2(197.5, 194.0)
const ART_KEY_SIZE := Vector2(159, 144)
const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK"]
const K := 0.48
const LCD_GREEN := Color(0.45, 1.0, 0.55)
const LCD_IDLE := Color(0.72, 0.9, 1.0)              # cool backlit LCD segments while typing
## Lit segments per character (a top, b upper right, c lower right, d bottom, e lower left, f upper left, g middle).
const SEGMENTS := {"8": "abcdefg", "0": "abcdef", "O": "abcdef", "E": "adefg", "r": "eg", "P": "abefg", "n": "ceg",
	"-": "g", "_": "d", " ": ""}

var _rig: Control
var _lcd: Control
var _lcd_chars := "_   "
var _lcd_color := LCD_IDLE
var _led_color := Color(0.35, 0.05, 0.04)
var _code := ""
var _hover := -1
var _pressed := {}       # key index -> remaining press time


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiKit.backdrop(Color(0.02, 0.025, 0.035, 0.55), 2.2))
	var holder := Control.new()
	UiKit.center(holder, ART * K + Vector2(0, 90))
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_rig = Control.new()
	_rig.size = ART * K
	_rig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rig.draw.connect(_draw_device)
	holder.add_child(_rig)
	# 7-segment LCD inside the painted window: unlit segments show as faint ghosts, like real glass
	var lcd := Rect2(ART_LCD.position * K, ART_LCD.size * K).grow(-10)
	_lcd = Control.new()
	_lcd.position = lcd.position
	_lcd.size = lcd.size
	_lcd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lcd.draw.connect(_draw_lcd)
	_rig.add_child(_lcd)
	# invisible hit areas over the painted keys
	for i in KEYS.size():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, UiKit.empty_box())
		var r := _key_rect(i)
		b.position = r.position
		b.size = r.size
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(func():
			_flash_key(i)
			_press(KEYS[i]))
		b.mouse_entered.connect(func():
			_hover = i
			_rig.queue_redraw())
		b.mouse_exited.connect(func():
			if _hover == i:
				_hover = -1
			_rig.queue_redraw())
		_rig.add_child(b)
	var foot := VBoxContainer.new()
	foot.position = Vector2(0, ART.y * K + 14)
	foot.size = Vector2(ART.x * K, 70)
	foot.add_theme_constant_override("separation", 10)
	holder.add_child(foot)
	var cap := UiKit.caption("MAINT. ACCESS · 정비 통로 도어락", UiKit.TEXT_DIM, 16)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_child(cap)
	var hints := UiKit.key_hints([["0-9", "입력"], ["ENTER", "확인"], ["ESC", "닫기"]], UiKit.MIN_TEXT, UiKit.TEXT_DIM)
	hints.alignment = BoxContainer.ALIGNMENT_CENTER
	foot.add_child(hints)


func _key_rect(i: int) -> Rect2:
	var c := i % 3
	var r := i / 3
	return Rect2((ART_KEY0 + Vector2(c * ART_KEY_STEP.x, r * ART_KEY_STEP.y)) * K, ART_KEY_SIZE * K)


func _process(delta: float) -> void:
	if _pressed.is_empty():
		return
	for k in _pressed.keys():
		_pressed[k] -= delta
		if _pressed[k] <= 0.0:
			_pressed.erase(k)
	_rig.queue_redraw()


func _draw_device() -> void:
	var tex := UiArt.tex("keypad_staff")
	var full := Rect2(Vector2.ZERO, ART * K)
	if tex:
		_rig.draw_texture_rect(tex, full, false)
	else:
		_rig.draw_style_box(UiKit.box(Color("8a8d92"), Color("5d6066"), 16, 3, 0), full.grow(-40))
		for i in KEYS.size():
			_rig.draw_style_box(UiKit.box(Color("2c3138"), Color(0, 0, 0, 0), 8, 0, 0), _key_rect(i))
	# LCD glass: faint backlight and a reflection band over the painted black window
	var lcd := Rect2(ART_LCD.position * K, ART_LCD.size * K).grow(-6)
	_rig.draw_rect(lcd, Color(0.06, 0.09, 0.11, 0.9))
	_rig.draw_colored_polygon(PackedVector2Array([lcd.position, lcd.position + Vector2(lcd.size.x * 0.45, 0),
		lcd.position + Vector2(lcd.size.x * 0.3, lcd.size.y), lcd.position + Vector2(0, lcd.size.y)]), Color(1, 1, 1, 0.025))
	# key feedback: hover lifts, press sinks
	for i in KEYS.size():
		var r := _key_rect(i).grow(-3)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(10 * K * 2))
		sb.anti_aliasing = true
		if _pressed.has(i):
			sb.bg_color = Color(0, 0, 0, 0.42 * clampf(_pressed[i] / 0.14, 0.0, 1.0))
			sb.border_color = Color(0, 0, 0, 0.5)
			sb.border_width_top = 4
			_rig.draw_style_box(sb, r)
		elif i == _hover:
			sb.bg_color = Color(1, 1, 1, 0.07)
			_rig.draw_style_box(sb, r)
	# status LED
	var led := ART_LED * K
	_rig.draw_circle(led, 13.0, Color(_led_color, 0.22))
	_rig.draw_circle(led, 7.0, _led_color)


func open_anim() -> void:
	_rig.pivot_offset = _rig.size * 0.5
	UiFx.pop_in(_rig, 0.24, 0.92)


func reset() -> void:
	_code = ""
	_set_led(Color(0.35, 0.05, 0.04))
	_refresh()


func _press(k: String) -> void:
	Snd.play("keypad_beep", -6.0)
	match k:
		"C":
			_code = ""
		"OK":
			submitted.emit(_code)
			_code = ""
			return
		_:
			if _code.length() < 4:
				_code += k
	_refresh()


func _flash_key(i: int) -> void:
	_pressed[i] = 0.14
	_rig.queue_redraw()


func show_result(ok: bool) -> void:
	_lcd_chars = "OPEn" if ok else "Err "
	_lcd_color = LCD_GREEN if ok else Color(1.0, 0.32, 0.26)
	_lcd.queue_redraw()
	Snd.play("beep_ok" if ok else "beep_error", -4.0)
	_set_led(Color(0.3, 1.0, 0.45) if ok else Color(1.0, 0.2, 0.15))
	if not ok:
		UiFx.shake(_rig, 10.0, 0.3)
		var tw := create_tween()
		for i in 3:
			tw.tween_callback(_set_led.bind(Color(0.35, 0.05, 0.04))).set_delay(0.12)
			tw.tween_callback(_set_led.bind(Color(1.0, 0.2, 0.15))).set_delay(0.12)


func _set_led(c: Color) -> void:
	_led_color = c
	_rig.queue_redraw()


## Entered digits stay masked ("-"); "_" marks the next position.
func _refresh() -> void:
	_lcd_chars = ""
	for i in 4:
		_lcd_chars += "-" if i < _code.length() else ("_" if i == _code.length() else " ")
	_lcd_color = LCD_IDLE
	_lcd.queue_redraw()


func _draw_lcd() -> void:
	var cw := _lcd.size.x / 4.0
	# real segment displays lean slightly
	_lcd.draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-0.1, 1), Vector2(_lcd.size.y * 0.05, 0)))
	for i in 4:
		var ch := _lcd_chars[i] if i < _lcd_chars.length() else " "
		var box := Rect2(i * cw + cw * 0.2, _lcd.size.y * 0.13, cw * 0.6, _lcd.size.y * 0.74)
		_draw_digit(box, SEGMENTS.get(ch, ""))
	_lcd.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_digit(box: Rect2, lit: String) -> void:
	var w := box.size.x
	var h := box.size.y
	var t := w * 0.17
	var half := h * 0.5
	var segs := {
		"a": Rect2(t * 0.7, 0, w - t * 1.4, t), "g": Rect2(t * 0.7, half - t * 0.5, w - t * 1.4, t),
		"d": Rect2(t * 0.7, h - t, w - t * 1.4, t),
		"f": Rect2(0, t * 0.7, t, half - t * 1.1), "b": Rect2(w - t, t * 0.7, t, half - t * 1.1),
		"e": Rect2(0, half + t * 0.4, t, half - t * 1.1), "c": Rect2(w - t, half + t * 0.4, t, half - t * 1.1),
	}
	for k in segs:
		var r: Rect2 = segs[k]
		r.position += box.position
		if lit.contains(k):
			_lcd.draw_rect(r.grow(3.0), Color(_lcd_color, 0.12))
			_lcd.draw_rect(r, _lcd_color)
		else:
			_lcd.draw_rect(r, Color(LCD_IDLE, 0.06))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		closed.emit()
	elif event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode
		var key := ""
		if kc >= KEY_0 and kc <= KEY_9:
			key = str(kc - KEY_0)
		elif kc >= KEY_KP_0 and kc <= KEY_KP_9:
			key = str(kc - KEY_KP_0)
		elif kc == KEY_ENTER or kc == KEY_KP_ENTER:
			key = "OK"
		elif kc == KEY_BACKSPACE:
			key = "C"
		if key != "":
			_flash_key(KEYS.find(key))
			_press(key)
			get_viewport().set_input_as_handled()
