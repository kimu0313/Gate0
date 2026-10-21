class_name KeypadView
extends Control
## 4-digit door lock keypad.

signal submitted(code: String)
signal closed

var _display: Label
var _code := ""


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	UiKit.full_rect(dim)
	add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.box(Color(0.12, 0.13, 0.14), Color(0.3, 0.3, 0.32), 14, 3, 26))
	UiKit.center(panel, Vector2(420, 620))
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(UiKit.label("정비 통로 도어락", 22, UiKit.C_TEXT, "sans", 700))
	var dbox := PanelContainer.new()
	dbox.add_theme_stylebox_override("panel", UiKit.box(Color(0.02, 0.06, 0.03), Color(0.1, 0.2, 0.1), 6, 2, 12))
	v.add_child(dbox)
	_display = UiKit.label("- - - -", 46, Color(0.4, 1.0, 0.5), "mono", 700)
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dbox.add_child(_display)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK"]:
		var b := UiKit.button(k, 30, _press.bind(k))
		b.custom_minimum_size = Vector2(112, 76)
		grid.add_child(b)
	v.add_child(UiKit.label("[Esc] 닫기", 15, UiKit.C_DIM))


func reset() -> void:
	_code = ""
	_refresh()


func _press(k: String) -> void:
	Snd.play("keypad_beep", -6.0)
	match k:
		"C":
			_code = ""
		"OK":
			submitted.emit(_code)
			_code = ""
		_:
			if _code.length() < 4:
				_code += k
	_refresh()


func show_result(ok: bool) -> void:
	_display.text = "OPEN" if ok else "ERROR"
	_display.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if ok else Color(1.0, 0.3, 0.25))
	Snd.play("beep_ok" if ok else "beep_error", -4.0)


func _refresh() -> void:
	var s := ""
	for i in 4:
		s += ("* " if i < _code.length() else "- ")
	_display.text = s.strip_edges()
	_display.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		closed.emit()
	elif event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.physical_keycode
		if kc >= KEY_0 and kc <= KEY_9:
			_press(str(kc - KEY_0))
			get_viewport().set_input_as_handled()
		elif kc >= KEY_KP_0 and kc <= KEY_KP_9:
			_press(str(kc - KEY_KP_0))
			get_viewport().set_input_as_handled()
		elif kc == KEY_ENTER or kc == KEY_KP_ENTER:
			_press("OK")
			get_viewport().set_input_as_handled()
		elif kc == KEY_BACKSPACE:
			_press("C")
			get_viewport().set_input_as_handled()
