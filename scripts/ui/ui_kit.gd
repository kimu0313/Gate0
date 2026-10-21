class_name UiKit
extends RefCounted
## Design tokens, fonts, theme and widget factories shared by every UI screen.
## Visual language (see the GATE 0 UI 시안): SIGN (airport signage — HUD, menus), OPS (work tablet),
## PAPER (rulebook, documents) and BOARDING (what the UI turns into as erosion rises).

# --- palette ---------------------------------------------------------------------------------
const INK_0 := Color("0b0e12")      # ground
const INK_1 := Color("12161c")      # panel
const INK_2 := Color("1a2028")      # raised
const LINE := Color("2a323d")
const TEXT := Color("e8eaed")
const TEXT_DIM := Color("9aa3ae")
const TEXT_MUTE := Color("7c8590")
const BODY := Color("c5cad1")
const SIGNAL := Color("ffc21a")     # orders, interaction, wayfinding
const OPS := Color("6cc4ff")        # radio, system information
const CLEAR := Color("3fd0b0")      # normal, done
const ALERT := Color("ff4b3e")      # anomaly, danger
const WARN := Color("ff8a3d")
const EXIT := Color("22c55e")
const SCREEN := Color("0a1017")     # tablet screen
const SCREEN_2 := Color("0f1720")
const SCREEN_3 := Color("101a24")
const SCREEN_SEL := Color("1a2430")
const SCREEN_LINE := Color("1e2a36")
const PAPER := Color("ece7da")
const PAPER_INK := Color("1c1b1a")
const STAMP_RED := Color("b3261e")
const NAVY := Color("0f2350")
const NAVY_TEXT := Color("f4f2ec")
const SHADE := Color(0.035, 0.043, 0.055, 0.88)

# legacy names kept for older call sites
const C_BG := Color(0.035, 0.045, 0.06, 0.96)
const C_PANEL := INK_1
const C_LINE := LINE
const C_TEXT := TEXT
const C_DIM := TEXT_DIM
const C_ACCENT := SIGNAL
const C_GOOD := CLEAR
const C_BAD := ALERT
const C_INFO := OPS

static var _fonts := {}
static var _theme: Theme
static var _textures := {}
static var _keep_all_re: RegEx


# =========================================================================================
# fonts
# =========================================================================================
## kind: sans (Korean UI) | display / sign (DIN-style sign face, Hangul from sans)
##       | mono | serif | hand
static func font(kind := "sans", weight := 400) -> Font:
	var key := "%s_%d" % [kind, weight]
	if _fonts.has(key):
		return _fonts[key]
	var out: Font
	match kind:
		"display", "sign":
			var fv := FontVariation.new()
			fv.base_font = Geo.sign_face()
			# Hangul is not in the sign face: fall back to the Korean UI font of the same weight
			fv.fallbacks = [font("sans", maxi(weight, 400))]
			out = fv
		# serif / hand are rulebook clues, so they ship with the game instead of relying on the OS
		"serif":
			out = Geo.bundled_font("res://assets/fonts/NanumMyeongjo-%s.ttf" % ("Bold" if weight >= 600 else "Regular"),
				["Batang", "BatangChe", "Noto Serif KR", "serif"])
		"hand":
			out = Geo.bundled_font("res://assets/fonts/NanumPenScript-Regular.ttf", ["Gungsuh", "GungsuhChe", "Batang", "serif"])
		"mono":
			var m: Font = Geo.installed_font(["Consolas"])
			if m:
				(m as SystemFont).font_weight = weight
			else:
				m = Geo.font_file("res://assets/fonts/IBMPlexMono-%s.ttf" % ("Bold" if weight >= 600 else "Regular"))
			m.fallbacks = [font("sans", weight)]
			out = m
		_:
			out = Geo.korean_font(weight)
	_fonts[key] = out
	return out


# =========================================================================================
# styles
# =========================================================================================
static func box(bg: Color, border := Color(0, 0, 0, 0), radius := 0, border_w := 0, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	s.anti_aliasing = radius > 0
	return s


## Box with explicit margins (left, top, right, bottom).
static func boxm(bg: Color, margins: Vector4, border := Color(0, 0, 0, 0), border_w := 0, radius := 0) -> StyleBoxFlat:
	var s := box(bg, border, radius, border_w, 0)
	s.content_margin_left = margins.x
	s.content_margin_top = margins.y
	s.content_margin_right = margins.z
	s.content_margin_bottom = margins.w
	return s


## Modal panel in the sign style: dark plate with a signal-yellow top edge and a soft shadow
## (chapter select, settings).
static func sign_panel(pad := Vector4(40, 34, 40, 34), accent := SIGNAL) -> StyleBoxFlat:
	var s := boxm(Color(0.047, 0.058, 0.075, 0.97), pad)
	s.border_width_top = 4
	s.border_color = accent
	s.shadow_color = Color(0, 0, 0, 0.5)
	s.shadow_size = 28
	s.shadow_offset = Vector2(0, 12)
	return s


static func empty_box() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()


## Shared theme: sliders, toggles, scrollbars, line edits and separators in the SIGN style.
static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font("sans")
	t.default_font_size = 19
	t.set_color("font_color", "Label", TEXT)
	# buttons
	t.set_stylebox("normal", "Button", box(INK_2, LINE, 0, 1, 16))
	t.set_stylebox("hover", "Button", box(Color("222a35"), SIGNAL, 0, 2, 16))
	t.set_stylebox("pressed", "Button", box(Color("151a21"), SIGNAL, 0, 2, 16))
	t.set_stylebox("disabled", "Button", box(Color("10141a"), Color("1c222b"), 0, 1, 16))
	t.set_stylebox("focus", "Button", empty_box())
	# sliders
	var track := box(Color("232b36"), Color(0, 0, 0, 0), 0, 0, 0)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	var fill := box(SIGNAL, Color(0, 0, 0, 0), 0, 0, 0)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", fill)
	var fill_hi := fill.duplicate() as StyleBoxFlat
	fill_hi.bg_color = Color("ffd660")
	t.set_stylebox("grabber_area_highlight", "HSlider", fill_hi)
	t.set_icon("grabber", "HSlider", _tex("grabber", Vector2i(14, 26), func(img: Image):
		img.fill(TEXT)
		img.fill_rect(Rect2i(0, 22, 14, 4), TEXT_DIM)))
	t.set_icon("grabber_highlight", "HSlider", _tex("grabber_hi", Vector2i(14, 26), func(img: Image):
		img.fill(SIGNAL)
		img.fill_rect(Rect2i(0, 22, 14, 4), Color("c98f00"))))
	t.set_stylebox("focus", "HSlider", empty_box())
	# toggles
	t.set_icon("checked", "CheckButton", _tex("switch_on", Vector2i(56, 28), func(img: Image):
		img.fill(SIGNAL)
		img.fill_rect(Rect2i(30, 4, 22, 20), INK_0)))
	# OFF must read as "off", not "disabled": outlined track with a bright knob
	t.set_icon("unchecked", "CheckButton", _tex("switch_off2", Vector2i(56, 28), func(img: Image):
		img.fill(Color("6b7480"))
		img.fill_rect(Rect2i(2, 2, 52, 24), Color("1d242d"))
		img.fill_rect(Rect2i(5, 5, 20, 18), TEXT)))
	t.set_icon("checked_disabled", "CheckButton", t.get_icon("checked", "CheckButton"))
	t.set_icon("unchecked_disabled", "CheckButton", t.get_icon("unchecked", "CheckButton"))
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		t.set_stylebox(st, "CheckButton", boxm(Color(0, 0, 0, 0), Vector4(0, 6, 0, 6)))
	t.set_stylebox("hover", "CheckButton", boxm(Color(1, 1, 1, 0.03), Vector4(0, 6, 0, 6)))
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	t.set_color("font_hover_pressed_color", "CheckButton", Color.WHITE)
	t.set_color("font_focus_color", "CheckButton", TEXT)
	t.set_constant("h_separation", "CheckButton", 18)
	# scrollbars
	t.set_stylebox("scroll", "VScrollBar", boxm(Color(1, 1, 1, 0.03), Vector4(3, 0, 3, 0)))
	t.set_stylebox("grabber", "VScrollBar", box(Color("3a4552"), Color(0, 0, 0, 0), 0, 0, 3))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(TEXT_MUTE, Color(0, 0, 0, 0), 0, 0, 3))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(SIGNAL, Color(0, 0, 0, 0), 0, 0, 3))
	t.set_stylebox("scroll", "HScrollBar", boxm(Color(1, 1, 1, 0.03), Vector4(0, 3, 0, 3)))
	t.set_stylebox("grabber", "HScrollBar", box(Color("3a4552"), Color(0, 0, 0, 0), 0, 0, 3))
	t.set_stylebox("panel", "ScrollContainer", empty_box())
	# line edit
	t.set_stylebox("normal", "LineEdit", boxm(Color("0d1116"), Vector4(18, 10, 18, 10), LINE, 2))
	t.set_stylebox("focus", "LineEdit", boxm(Color(0, 0, 0, 0), Vector4(18, 10, 18, 10), SIGNAL, 2))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_MUTE)
	t.set_color("caret_color", "LineEdit", SIGNAL)
	t.set_color("selection_color", "LineEdit", Color(SIGNAL, 0.35))
	t.set_constant("caret_width", "LineEdit", 3)
	# separators, progress
	var sep := StyleBoxLine.new()
	sep.color = LINE
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_stylebox("background", "ProgressBar", box(Color(0, 0, 0, 0.5), Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(SIGNAL, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_stylebox("panel", "PanelContainer", empty_box())
	_theme = t
	return t


static func _tex(key: String, size: Vector2i, paint: Callable) -> Texture2D:
	if _textures.has(key):
		return _textures[key]
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	paint.call(img)
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex


# =========================================================================================
# widgets
# =========================================================================================
## ICU wraps Korean between any two syllables ("정상/이 | 상을"). Gluing the syllables of a word
## with WORD JOINER (zero width in every UI font) makes lines break only at spaces, like CSS keep-all.
static func keep_all(s: String) -> String:
	if _keep_all_re == null:
		_keep_all_re = RegEx.create_from_string("([가-힣])(?=[가-힣])")
	return _keep_all_re.sub(s, "$1" + String.chr(0x2060), true)


## Text in the player's language (Settings › 화면 › 언어). The Korean source text is the key; the
## translations live in assets/i18n/*.po. Text that is assembled at runtime must translate its template
## first (t("…%d…") % n), because the assembled string is not a key.
static func t(s: String, ctx := "") -> String:
	if s == "":
		return s
	if ctx != "":
		# a context only overrides where one is given ("stamp": 확인 → CHECKED, not OK)
		var c := String(TranslationServer.translate(s, ctx))
		if c != s:
			return c
	return String(TranslationServer.translate(s))


## True when a bilingual pair says the same thing in the current language ("정상"/"NORMAL" in English),
## so the secondary line can be dropped.
static func same(a: String, b: String) -> bool:
	return t(a).to_upper() == t(b).to_upper()


static func label(text: String, size := 20, color := TEXT, kind := "sans", weight := 400) -> Label:
	var l := Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = keep_all(t(text))
	l.add_theme_font_override("font", font(kind, weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Smallest UI text at 1080p. Captions, chips and key hints never go below it; only print on props
## (boarding pass, staff card fields) and decorative English sub-labels may.
const MIN_TEXT := 16


## Small uppercase sign caption, e.g. "CURRENT ORDER · 현재 지시".
static func caption(text: String, color := TEXT_MUTE, size := MIN_TEXT) -> Label:
	return label(text, maxi(size, MIN_TEXT), color, "display", 700)


## Default keys named in game text, mapped to their action so a rebound key is shown instead.
const _KEY_ACTIONS := {"TAB": "tablet", "B": "binder", "E": "interact", "F": "flashlight", "C": "close_eyes", "SHIFT": "sprint"}


## BBCode for rich text that mentions keys: "[Tab] 태블릿" draws Tab as a pale key cap, matching
## keycap(), and follows the player's bindings; any other "[" is escaped so bracketed words
## ("[표시 테스트]") stay literal.
static func key_bbcode(text: String) -> String:
	var re := RegEx.create_from_string("\\[(Tab|TAB|Esc|ESC|Shift|SHIFT|Enter|ENTER|LMB|RMB|[A-Z0-9])\\]")
	var out := ""
	var at := 0
	for m in re.search_all(text):
		var k := m.get_string(1).to_upper()
		if _KEY_ACTIONS.has(k):
			k = Game.key_label(_KEY_ACTIONS[k])
		out += text.substr(at, m.get_start() - at).replace("[", "[lb]")
		out += "[bgcolor=#e8eaedf0][color=#0b0e12][b] %s [/b][/color][/bgcolor] " % k
		at = m.get_end()
	return out + text.substr(at).replace("[", "[lb]")


static func rich(text: String, size := 20, color := TEXT, kind := "sans") -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	r.text = keep_all(t(text))
	r.add_theme_font_override("normal_font", font(kind, 400))
	r.add_theme_font_override("bold_font", font(kind, 700))
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", color)
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	return r


## Secondary button (dark panel, accent outline on hover). `accent` also tints the pressed text.
static func button(text: String, size := 20, cb := Callable(), accent := SIGNAL) -> Button:
	var b := Button.new()
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.text = t(text)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font("sans", 700))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", accent)
	b.add_theme_color_override("font_hover_pressed_color", accent)
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.42, 0.46))
	b.add_theme_stylebox_override("normal", box(INK_2, LINE, 0, 1, 18))
	b.add_theme_stylebox_override("hover", box(Color("222a35"), accent, 0, 2, 18))
	b.add_theme_stylebox_override("pressed", box(Color("151a21"), accent, 0, 2, 18))
	b.add_theme_stylebox_override("hover_pressed", box(Color("151a21"), accent, 0, 2, 18))
	b.add_theme_stylebox_override("disabled", box(Color("10141a"), Color("1c222b"), 0, 1, 18))
	b.add_theme_stylebox_override("focus", empty_box())
	if cb.is_valid():
		b.pressed.connect(cb)
	_wire_sounds(b)
	return b


## Filled call-to-action button (accent background, dark text).
static func primary(text: String, size := 22, cb := Callable(), accent := SIGNAL, fg := INK_0) -> Button:
	var b := button(text, size, cb, accent)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_hover_pressed_color", fg)
	b.add_theme_stylebox_override("normal", box(accent, Color(0, 0, 0, 0), 0, 0, 22))
	b.add_theme_stylebox_override("hover", box(accent.lightened(0.18), Color(0, 0, 0, 0), 0, 0, 22))
	b.add_theme_stylebox_override("pressed", box(accent.darkened(0.15), Color(0, 0, 0, 0), 0, 0, 22))
	b.add_theme_stylebox_override("hover_pressed", box(accent.darkened(0.15), Color(0, 0, 0, 0), 0, 0, 22))
	return b


static func _wire_sounds(b: BaseButton) -> void:
	b.mouse_entered.connect(func(): if not b.disabled: Snd.play("ui_click", -16.0, 1.15))
	b.pressed.connect(func(): Snd.play("ui_tap", -8.0))


## Keyboard key cap, e.g. [E] [TAB].
## `light`: solid pale cap for primary prompts; dark outlined cap for quiet guides.
static func keycap(text: String, size := 18, light := true) -> PanelContainer:
	var p := PanelContainer.new()
	var sb: StyleBoxFlat
	if light:
		sb = boxm(Color(TEXT, 0.94), Vector4(size * 0.42, size * 0.1, size * 0.42, size * 0.22))
		sb.border_width_bottom = maxi(2, int(size * 0.18))
		sb.border_color = Color("8f98a3")
	else:
		sb = boxm(Color(1, 1, 1, 0.07), Vector4(size * 0.42, size * 0.1, size * 0.42, size * 0.2))
		sb.set_border_width_all(1)
		sb.border_width_bottom = maxi(2, int(size * 0.18))
		sb.border_color = Color(1, 1, 1, 0.42)
	sb.set_corner_radius_all(maxi(2, int(size * 0.2)))
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(size * 1.7, size * 1.7)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, size, INK_0 if light else TEXT, "display", 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## Row of key hints: [["E", "상호작용"], ["TAB", "태블릿"]].
static func key_hints(pairs: Array, size := MIN_TEXT, color := BODY, light := true) -> HBoxContainer:
	size = maxi(size, MIN_TEXT)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in pairs.size():
		var pair: Array = pairs[i]
		if i > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(8, 0)
			h.add_child(gap)
		for k in String(pair[0]).split("/"):
			h.add_child(keycap(k, size, light))
		var l := label(str(pair[1]), size, color)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
	return h


## Colored tag with optional icon: RADIO · 소장, DAY 2 ...
static func chip(text: String, fg: Color, bg: Color, icon_name := "", size := MIN_TEXT) -> PanelContainer:
	size = maxi(size, MIN_TEXT)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", boxm(bg, Vector4(10, 3, 12, 4)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	if icon_name != "":
		var ic := UiIcon.make(icon_name, size + 2, fg)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
	var l := label(text, size, fg, "display", 700)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	return p


## Full-screen blurred, tinted backdrop for modals. Animate with UiFx.backdrop_in/out.
static func backdrop(tint := Color(0.02, 0.025, 0.035, 0.55), blur := 2.6) -> Control:
	var root := Control.new()
	full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var bbc := BackBufferCopy.new()
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	root.add_child(bbc)
	var rect := ColorRect.new()
	full_rect(rect)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/ui_blur.gdshader")
	mat.set_shader_parameter("tint", tint)
	mat.set_shader_parameter("lod", blur)
	mat.set_shader_parameter("amount", 1.0)
	rect.material = mat
	rect.name = "Blur"
	root.add_child(rect)
	return root


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


static func spacer(h := true) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	else:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


const _CORRUPT := {
	"점검": "탑승", "보고": "탑승", "지시": "안내", "시설": "승객", "확인": "탑승", "근무": "탑승", "직원": "승객",
	"MAINTENANCE": "B0ARDING", "ORDER": "B0ARDING", "TASKS": "1NF0RMATI0N",
	# the same slip in English
	"Inspect": "Board", "inspect": "board", "Inspection": "Boarding", "inspection": "boarding",
	"Report": "Board", "report": "board", "Facility": "Passenger", "facility": "passenger",
	"Staff": "Passenger", "staff": "passenger", "Shift": "Flight", "shift": "flight",
	"CONFIRMED": "B0ARDED", "SYSTEM": "B0ARDING", "Order": "Boarding",
}


## The terminal starts treating the inspector as a passenger: swaps work words for boarding words.
static func corrupt(s: String, amount := 1.0) -> String:
	var out := s
	for k in _CORRUPT:
		if randf() < amount:
			out = out.replace(k, _CORRUPT[k])
	return out


## Erosion state color + label used by the tablet meter and status cards.
static func erosion_state(e: float) -> Array:
	if e >= 75.0:
		return [ALERT, t("위험")]
	if e >= 50.0:
		return [WARN, t("불안정")]
	if e >= 25.0:
		return [SIGNAL, t("주의")]
	return [CLEAR, t("안정")]
