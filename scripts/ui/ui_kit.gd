class_name UiKit
extends RefCounted
## Fonts and widget factories shared by every UI screen.

const C_BG := Color(0.035, 0.045, 0.06, 0.96)
const C_PANEL := Color(0.06, 0.075, 0.1, 1.0)
const C_LINE := Color(0.2, 0.26, 0.34, 1.0)
const C_TEXT := Color(0.88, 0.9, 0.94)
const C_DIM := Color(0.55, 0.6, 0.68)
const C_ACCENT := Color(1.0, 0.72, 0.22)
const C_GOOD := Color(0.4, 0.95, 0.55)
const C_BAD := Color(1.0, 0.35, 0.3)
const C_INFO := Color(0.45, 0.75, 1.0)

static var _fonts := {}


static func font(kind := "sans", weight := 400) -> Font:
	var key := "%s_%d" % [kind, weight]
	if _fonts.has(key):
		return _fonts[key]
	var f := SystemFont.new()
	match kind:
		"mono":
			f.font_names = PackedStringArray(["Consolas", "D2Coding", "Lucida Console", "monospace"])
		"serif":
			f.font_names = PackedStringArray(["Batang", "BatangChe", "Noto Serif KR", "Nanum Myeongjo", "serif"])
		"hand":
			f.font_names = PackedStringArray(["Gungsuh", "GungsuhChe", "Nanum Pen Script", "Batang", "serif"])
		_:
			f.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans KR", "Noto Sans CJK KR", "sans-serif"])
	f.font_weight = weight
	_fonts[key] = f
	return f


static func box(bg: Color, border := Color(0, 0, 0, 0), radius := 6, border_w := 0, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	return s


static func label(text: String, size := 20, color := C_TEXT, kind := "sans", weight := 400) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind, weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func rich(text: String, size := 20, color := C_TEXT, kind := "sans") -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = text
	r.add_theme_font_override("normal_font", font(kind, 400))
	r.add_theme_font_override("bold_font", font(kind, 700))
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", color)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


static func button(text: String, size := 20, cb := Callable(), accent := C_ACCENT) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font("sans", 600))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", C_TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", accent)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.42, 0.46))
	b.add_theme_stylebox_override("normal", box(Color(0.1, 0.12, 0.16), C_LINE, 6, 1, 16))
	b.add_theme_stylebox_override("hover", box(Color(0.14, 0.17, 0.22), accent, 6, 2, 16))
	b.add_theme_stylebox_override("pressed", box(Color(0.08, 0.09, 0.12), accent, 6, 2, 16))
	b.add_theme_stylebox_override("disabled", box(Color(0.07, 0.08, 0.1), Color(0.14, 0.16, 0.2), 6, 1, 16))
	if cb.is_valid():
		b.pressed.connect(cb)
	b.mouse_entered.connect(func(): if not b.disabled: Snd.play("ui_click", -14.0))
	b.pressed.connect(func(): Snd.play("ui_tap", -8.0))
	return b


static func full_rect(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0
	return c


static func center(c: Control, size: Vector2) -> Control:
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.offset_left = -size.x * 0.5
	c.offset_right = size.x * 0.5
	c.offset_top = -size.y * 0.5
	c.offset_bottom = size.y * 0.5
	return c
