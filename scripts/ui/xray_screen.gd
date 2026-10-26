class_name XrayScreen
extends Control
## The X-ray operator monitor: a real dual-energy scan image (generated art in assets/textures/xray: organics orange,
## mixed green, metals blue) on the scanner's white field, between the operator's header and status bars. The bag
## is drawn in line by line as it passes the detector (scan_progress); anomalies are overlaid on the scan.
## content: "" (idle) | "bag" | "figure" | "heart" | "mybag" (your own bag, scanned as a passenger's) |
## "pax" (one bag goes in, 41 passenger bags come through one after another — flight A0's 41)

var content := ""
var powered := true
var stare := 0.0          # 0..1, figure turns its head toward the viewer
var scan_progress := 1.0  # 0..1 reveal sweep
var pax_count := 0        # "pax": passenger bags shown so far (1..PAX_TOTAL)
var pax_running := false  # "pax": still counting (X-ray 비상정지 freezes it)
var _t := 0.0
var _pax_t := 0.0
var mono: Font

const SCANS := {
	"bag": "res://assets/textures/xray/xray_bag.png",
	"heart": "res://assets/textures/xray/xray_bag.png",
	"mybag": "res://assets/textures/xray/xray_mybag.png",
	"figure": "res://assets/textures/xray/xray_figure.png",
}
const SCAN_PX := Vector2(1536, 1024)          # the scan art's own pixel space (overlay positions below use it)
const FIGURE_EYES := [Vector2(352, 355), Vector2(372, 392)]
const HEART_AT := Vector2(1040, 560)          # among the folded clothes of xray_bag
const FIELD := Color(0.96, 0.97, 0.96)        # the scanner's empty (fully transparent) field
const BAR := Color(0.07, 0.09, 0.12)
const INK := Color(0.66, 0.74, 0.82)
const ORANGE := Color(0.86, 0.45, 0.12)
const BLUE := Color(0.12, 0.28, 0.75)
const PAX_TOTAL := 41
const PAX_EVERY := 0.65                       # seconds per passenger bag

var _tex := {}


func _ready() -> void:
	Geo.fonts()
	mono = Geo.mono_font


func _process(delta: float) -> void:
	_t += delta
	if content == "pax" and pax_running and pax_count < PAX_TOTAL:
		_pax_t += delta
		pax_count = mini(PAX_TOTAL, 1 + int(_pax_t / PAX_EVERY))
	queue_redraw()


## "pax": start counting passenger bags from the first one.
func start_pax() -> void:
	content = "pax"
	_pax_t = 0.0
	pax_count = 1
	pax_running = true


func _scan(id: String) -> Texture2D:
	if not _tex.has(id):
		_tex[id] = load(SCANS[id]) if SCANS.has(id) and ResourceLoader.exists(SCANS[id]) else null
	return _tex[id]


func _draw() -> void:
	var w := size.x
	var h := size.y
	if not powered:
		draw_rect(Rect2(0, 0, w, h), Color.BLACK)
		return
	var top := 34.0
	var bottom := 30.0
	var field := Rect2(0, top, w, h - top - bottom)
	draw_rect(field, FIELD)
	# operator bars
	draw_rect(Rect2(0, 0, w, top), BAR)
	draw_rect(Rect2(0, h - bottom, w, bottom), BAR)
	draw_string(mono, Vector2(12, 23), "X-RAY 01  ·  SEOHAE SEC", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)
	if content != "mybag" and content != "pax":   # the passenger notice takes the clock's place there
		draw_string(mono, Vector2(0, 23), Game.clock_text() + "  ", HORIZONTAL_ALIGNMENT_RIGHT, w - 8, 17, INK)
	var mode := "HI-PEN  ·  OS  ·  ZOOM 1.0"
	draw_string(mono, Vector2(12, h - 10), "kV 160  mA 0.8  DUAL-ENERGY", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(INK, 0.75))
	draw_string(mono, Vector2(0, h - 10), mode + "  ", HORIZONTAL_ALIGNMENT_RIGHT, w - 8, 14, Color(INK, 0.75))
	# belt direction
	var ax := w * 0.5
	draw_colored_polygon(PackedVector2Array([Vector2(ax - 8, h - 22), Vector2(ax + 8, h - 15), Vector2(ax - 8, h - 8)]), Color(INK, 0.6))
	if content == "":
		draw_string(mono, Vector2(0, field.get_center().y + 10), "NO OBJECT", HORIZONTAL_ALIGNMENT_CENTER, w, 26, Color(0.55, 0.6, 0.66))
		_scanlines(field)
		return
	# the scan, fitted into the field
	var k := minf(field.size.x / SCAN_PX.x, field.size.y / SCAN_PX.y)
	var img := Rect2(field.get_center() - SCAN_PX * k * 0.5, SCAN_PX * k)
	if content == "pax":
		_draw_pax(field, img, k)
		_scanlines(field)
		return
	var tex := _scan(content)
	if tex:
		draw_texture_rect(tex, img, false)
	else:
		draw_rect(img.grow(-20), Color(ORANGE, 0.3))
	match content:
		"figure":
			if stare > 0.05:
				# the sockets darken and a pale glint wakes in each, as dense as metal would read
				for e: Vector2 in FIGURE_EYES:
					var p := img.position + e * k
					draw_circle(p, 6.0 * k * 2.4, Color(0.04, 0.08, 0.22, 0.55 * stare))
					draw_circle(p, 2.0 * k * 2.4, Color(0.92, 0.96, 1.0, 0.85 * stare))
		"heart":
			# an organic mass among the clothes that beats (dense core blue, tissue orange)
			var beat := 1.0 + 0.18 * maxf(0.0, sin(_t * 7.5)) + 0.1 * maxf(0.0, sin(_t * 7.5 - 1.2))
			var c := img.position + HEART_AT * k
			var r := 95.0 * k
			draw_circle(c, r * beat, Color(ORANGE, 0.55))
			draw_circle(c + Vector2(-r * 0.55, -r * 0.45) * beat, r * 0.62 * beat, Color(ORANGE, 0.5))
			draw_circle(c + Vector2(r * 0.55, -r * 0.45) * beat, r * 0.62 * beat, Color(ORANGE, 0.5))
			draw_circle(c, r * 0.45 * beat, Color(0.55, 0.28, 0.08, 0.55))
			draw_line(c + Vector2(0, -r * 0.6), c + Vector2(r * 0.25, -r * 1.6), Color(BLUE, 0.7), 4.0)
		"mybag":
			_draw_passenger_tag(img, k)
	# the bag is drawn in line by line as it passes the detector
	if scan_progress < 1.0:
		var x := field.position.x + field.size.x * scan_progress
		draw_rect(Rect2(x, field.position.y, field.end.x - x, field.size.y), FIELD)
		draw_line(Vector2(x, field.position.y), Vector2(x, field.end.y), Color(0.3, 0.55, 0.9, 0.7), 2.0)
	_scanlines(field)


func _scanlines(field: Rect2) -> void:
	for sy in range(int(field.position.y), int(field.end.y), 3):
		draw_line(Vector2(0, sy), Vector2(size.x, sy), Color(0, 0, 0, 0.035), 1.0)


## "pax": passenger bag after passenger bag (the two scan images, mirrored every other one), each with a
## 1987 tag, and a counter that runs up to 41 unless the X-ray is stopped.
func _draw_pax(field: Rect2, img: Rect2, _k: float) -> void:
	var n := maxi(1, pax_count)
	var tex := _scan("bag" if n % 3 != 0 else "mybag")
	var flip := n % 2 == 0
	if tex:
		if flip:
			draw_set_transform(Vector2(img.position.x * 2.0 + img.size.x, 0), 0.0, Vector2(-1, 1))
		draw_texture_rect(tex, img, false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var red := Color(0.85, 0.12, 0.1)
	draw_string(mono, Vector2(0, 23), "PASSENGER BAGGAGE  %02d / %d  " % [n, PAX_TOTAL], HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, 17, Color(1.0, 0.4, 0.32))
	var tag := Rect2(img.end.x - 230, img.position.y + 6, 216, 64)
	draw_rect(tag, Color(0.93, 0.88, 0.72, 0.92))
	draw_rect(tag, Color(0.6, 0.5, 0.25), false, 2.0)
	draw_string(mono, tag.position + Vector2(10, 26), "PAX %02d" % n, HORIZONTAL_ALIGNMENT_LEFT, tag.size.x - 16, 20, Color(0.15, 0.15, 0.18))
	draw_string(mono, tag.position + Vector2(10, 52), "A0  87.11.03", HORIZONTAL_ALIGNMENT_LEFT, tag.size.x - 16, 18, red)
	# each bag is drawn in as it passes the detector, then the next one follows
	if pax_running and n < PAX_TOTAL:
		var sweep := clampf(fmod(_pax_t, PAX_EVERY) / (PAX_EVERY * 0.7), 0.0, 1.0)
		var x := field.position.x + field.size.x * sweep
		draw_rect(Rect2(x, field.position.y, field.end.x - x, field.size.y), FIELD)
		draw_line(Vector2(x, field.position.y), Vector2(x, field.end.y), Color(0.3, 0.55, 0.9, 0.7), 2.0)


## A baggage tag on the handle: the airport scanned your bag as a passenger's (DAY 2 · 수칙 p.7 ③).
func _draw_passenger_tag(img: Rect2, _k: float) -> void:
	var red := Color(0.85, 0.12, 0.1)
	draw_string(mono, Vector2(0, 23), "PASSENGER BAGGAGE   " + Game.clock_text() + "  ", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8, 17, Color(1.0, 0.4, 0.32))
	var tag := Rect2(img.end.x - 250, img.position.y + 6, 236, 64)
	draw_rect(tag, Color(1.0, 0.97, 0.85, 0.92))
	draw_rect(tag, Color(0.75, 0.6, 0.2), false, 2.0)
	draw_line(tag.position + Vector2(18, 64), tag.position + Vector2(-10, 110), Color(0.7, 0.55, 0.2, 0.8), 2.0)
	draw_string(mono, tag.position + Vector2(10, 26), "PAX  " + Game.player_name, HORIZONTAL_ALIGNMENT_LEFT, tag.size.x - 16, 20, Color(0.15, 0.15, 0.18))
	draw_string(mono, tag.position + Vector2(10, 52), "FLT 000  -> HOME", HORIZONTAL_ALIGNMENT_LEFT, tag.size.x - 16, 18, red)
