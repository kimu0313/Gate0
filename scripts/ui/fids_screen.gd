class_name FidsScreen
extends Control
## Draws the departure board into a SubViewport. Data-only: the FidsBoard facility feeds it rows.
## Laid out from its own size (the viewport follows the board's proportions, so nothing is stretched), every cell
## shrinks to fit its column, and overflows() lists any text that still would not fit (debug/fids_sheet.gd).

const AMBER := Color(0.96, 0.95, 0.88)  # the lettering: warm white on the blue board (the name stays for the board code)
const WHITE := Color(0.92, 0.94, 0.98)
const GREY := Color(0.66, 0.72, 0.84)
const GREEN := Color(0.3, 1.0, 0.45)
const RED := Color(1.0, 0.25, 0.2)
const BG := Color(0.02, 0.07, 0.3)       # a deep royal-blue board (night-airport reference)
const STRIPE := Color(0.035, 0.1, 0.37)
const HEAD_BG := Color(0.012, 0.035, 0.15)
const ICON_DEPARTURES := "res://assets/textures/level/icon_departures.png"
const MIN_SHRINK := 0.62               # a cell may shrink to this share of its font size before it counts as overflow
## Columns as [left, width] in shares of the screen width, and how each is aligned.
const COLS := [[0.02, 0.095], [0.122, 0.115], [0.248, 0.255], [0.512, 0.19], [0.71, 0.08], [0.8, 0.18]]
const HEADS := ["TIME", "FLIGHT", "DESTINATION", "목적지", "GATE", "REMARK"]

var rows: Array = []        # [{time, flight, dest, ko, gate, remark, color?}]
var clock := "23:00"
var mode := "normal"        # normal | black | reboot | story | final | message
var big_lines: Array = []   # for story/final/message modes
var title := "출발  DEPARTURES"
var icon: Texture2D         # header pictogram (departures by default; the arrivals board sets its own)
var badge := "TEST MODE"
var _blink := 0.0
var _over: Array[String] = []
var sans: Font
var mono: Font


func _ready() -> void:
	sans = _face(1)
	mono = _face(2)
	if icon == null:
		icon = load(ICON_DEPARTURES)


func _process(delta: float) -> void:
	_blink += delta
	queue_redraw()


static var _faces := {}


## The sign face (DIN-style, Hangul from the Korean face) with `tracking`, as plain raster fonts: this is 2D drawing
## and the world labels' MSDF fonts misdraw Bahnschrift's overlapping outlines at board sizes (a spur on the N).
static func _face(tracking: int) -> Font:
	if not _faces.has(tracking):
		var fv := FontVariation.new()
		fv.base_font = Geo.sign_face(false)
		fv.spacing_glyph = tracking
		fv.fallbacks = [Geo.korean_font(700, false)]
		_faces[tracking] = fv
	return _faces[tracking]


## Text that did not fit in the last frame drawn ("column: text").
func overflows() -> Array[String]:
	return _over


func _draw() -> void:
	_over.clear()
	if sans == null:
		_ready()
	var w := size.x
	var h := size.y
	var k := w / 1600.0
	draw_rect(Rect2(0, 0, w, h), Color.BLACK if mode == "black" else BG)
	match mode:
		"black":
			return
		"reboot":
			_draw_reboot(w, h, k)
			return
		"story", "final", "message":
			_draw_big(w, h)
			return
	# header: pictogram, title, status badge, clock
	var hh := roundf(h * 0.135)
	draw_rect(Rect2(0, 0, w, hh), HEAD_BG)
	var x := 26.0 * k
	if icon:
		var isz := hh * 0.74
		draw_texture_rect(icon, Rect2(x, (hh - isz) * 0.5, isz, isz), false, WHITE)
		x += isz + 16.0 * k
	_text(sans, "title", title, x, hh * 0.5, w * 0.5 - x - 20.0 * k, 46.0 * k, WHITE)
	if badge != "":
		var bx := w * 0.55
		var bw := 230.0 * k
		draw_rect(Rect2(bx, hh * 0.22, bw, hh * 0.56), Color(0.07, 0.15, 0.42))
		_text(mono, "badge", badge, bx + 10.0 * k, hh * 0.5, bw - 20.0 * k, 30.0 * k, AMBER, HORIZONTAL_ALIGNMENT_CENTER)
	_text(mono, "clock", clock, w * 0.8, hh * 0.5, w * 0.2 - 30.0 * k, 50.0 * k, AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	# column titles
	var head_y := hh + 34.0 * k
	for i in HEADS.size():
		var col: Array = COLS[i]
		var al := HORIZONTAL_ALIGNMENT_CENTER if i == 4 else HORIZONTAL_ALIGNMENT_LEFT
		_text(sans, "head", HEADS[i], w * col[0], head_y, w * col[1], 24.0 * k, GREY, al)
	# rows: share what is left of the screen
	var y := head_y + 22.0 * k
	var rh := (h - y - 8.0 * k) / maxf(8.0, rows.size())
	var fs := minf(36.0 * k, rh * 0.66)
	for i in rows.size():
		var r: Dictionary = rows[i]
		if i % 2 == 0:
			draw_rect(Rect2(0, y, w, rh), STRIPE)
		var c: Color = r.get("color", AMBER)
		var remark := str(r.get("remark", ""))
		var rc := GREY if remark == "TEST" else c
		if remark == "BOARDING" or remark == "FINAL CALL":
			rc = GREEN if remark == "BOARDING" else RED
			if fmod(_blink, 1.0) > 0.6:
				rc = rc.darkened(0.7)
		var mid := y + rh * 0.5
		var cells := [[mono, "time", c], [mono, "flight", c], [sans, "dest", c], [sans, "ko", c], [mono, "gate", c], [mono, "remark", rc]]
		for j in cells.size():
			var cell: Array = cells[j]
			var col: Array = COLS[j]
			var al := HORIZONTAL_ALIGNMENT_CENTER if j == 4 else HORIZONTAL_ALIGNMENT_LEFT
			var size_k := 0.92 if cell[1] == "ko" else 1.0
			_text(cell[0], cell[1], str(r.get(cell[1], "")), w * col[0], mid, w * col[1], fs * size_k, cell[2], al)
		y += rh
	# scanline shimmer
	for sy in range(0, int(h), 4):
		draw_line(Vector2(0, sy), Vector2(w, sy), Color(0, 0, 0, 0.18), 1.0)


## One line of text vertically centred on `mid`, shrunk until it fits `width` (never cut: a width-limited
## draw_string drops whole glyphs). Text that still does not fit at MIN_SHRINK is drawn anyway and reported.
func _text(font: Font, what: String, text: String, x: float, mid: float, width: float, fs: float,
		col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	if text == "":
		return
	var px := int(fs)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	while tw > width and px > int(fs * MIN_SHRINK):
		px -= 1
		tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if tw > width:
		_over.append("%s: '%s' %.0f px in %.0f" % [what, text, tw, width])
	var dx := 0.0
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		dx = (width - tw) * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		dx = width - tw
	var base := mid + (font.get_ascent(px) - font.get_descent(px)) * 0.5
	draw_string(font, Vector2(x + dx, base), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _draw_reboot(w: float, h: float, k: float) -> void:
	var lines := ["SEOHAE FIDS v3.2.1", "SYSTEM REBOOT ...", "LOADING SCHEDULE DATA ...", ""]
	var shown := int(fmod(_blink * 3.0, 5.0))
	var lh := 60.0 * k
	for i in mini(shown, lines.size()):
		_text(mono, "reboot", lines[i], 60.0 * k, h * 0.19 + i * lh, w - 120.0 * k, 40.0 * k, GREY)
	if fmod(_blink, 0.8) < 0.4:
		draw_rect(Rect2(60.0 * k, h * 0.19 + mini(shown, 3) * lh - 18.0 * k, 24.0 * k, 36.0 * k), GREY)


## Story / final / message screens: big centred lines, each shrunk to the screen's width.
func _draw_big(w: float, h: float) -> void:
	var col := AMBER
	if mode == "final":
		col = RED if fmod(_blink, 1.0) < 0.6 else RED.darkened(0.6)
	var total := big_lines.size()
	var step := minf(h * 0.8 / maxf(1.0, total), h * 0.21)
	for i in total:
		var fs := minf(step * (0.85 if i == 0 else 0.62), h * (0.17 if i == 0 else 0.125))
		var mid := h * 0.5 + (i - (total - 1) * 0.5) * step
		var c := col if i != 0 or mode != "message" else WHITE
		_text(mono, "big", str(big_lines[i]), w * 0.05, mid, w * 0.9, fs, c, HORIZONTAL_ALIGNMENT_CENTER)
	for sy in range(0, int(h), 4):
		draw_line(Vector2(0, sy), Vector2(w, sy), Color(0, 0, 0, 0.2), 1.0)
