class_name FidsScreen
extends Control
## Draws the departure board into a SubViewport. Data-only: the FidsBoard facility feeds it rows.

const AMBER := Color(1.0, 0.72, 0.22)
const WHITE := Color(0.92, 0.94, 0.98)
const GREY := Color(0.45, 0.48, 0.55)
const GREEN := Color(0.3, 1.0, 0.45)
const RED := Color(1.0, 0.25, 0.2)
const BG := Color(0.01, 0.015, 0.03)
const STRIPE := Color(0.03, 0.045, 0.08)

var rows: Array = []        # [{time, flight, dest, ko, gate, remark, color?}]
var clock := "23:00"
var mode := "normal"        # normal | black | reboot | story | final | message
var big_lines: Array = []   # for story/final/message modes
var title := "출발  DEPARTURES"
var badge := "TEST MODE"
var _blink := 0.0
var sans: Font
var mono: Font


func _ready() -> void:
	Geo.fonts()
	sans = Geo.sign_font
	mono = Geo.led_font


func _process(delta: float) -> void:
	_blink += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color.BLACK if mode == "black" else BG)
	match mode:
		"black":
			return
		"reboot":
			_draw_reboot(w, h)
			return
		"story", "final", "message":
			_draw_big(w, h)
			return
	# header
	draw_rect(Rect2(0, 0, w, 86), Color(0.04, 0.07, 0.16))
	draw_string(sans, Vector2(30, 60), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 46, WHITE)
	if badge != "":
		var bx := w * 0.55
		draw_rect(Rect2(bx, 20, 230, 48), Color(0.35, 0.25, 0.02))
		draw_string(mono, Vector2(bx, 56), badge, HORIZONTAL_ALIGNMENT_CENTER, 230, 30, AMBER)
	draw_string(mono, Vector2(w - 230, 62), clock, HORIZONTAL_ALIGNMENT_RIGHT, 200, 50, AMBER)
	# column titles
	var cols := [30.0, 190.0, 390.0, 800.0, 1140.0, 1290.0]
	var heads := ["TIME", "FLIGHT", "DESTINATION", "목적지", "GATE", "REMARK"]
	for i in heads.size():
		draw_string(sans, Vector2(cols[i], 122), heads[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, GREY)
	var y := 140.0
	var rh := 54.0
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
		var base := y + 39.0
		draw_string(mono, Vector2(cols[0], base), str(r.get("time", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 36, c)
		draw_string(mono, Vector2(cols[1], base), str(r.get("flight", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 36, c)
		draw_string(sans, Vector2(cols[2], base), str(r.get("dest", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, c)
		draw_string(sans, Vector2(cols[3], base), str(r.get("ko", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, c)
		draw_string(mono, Vector2(cols[4] + 20, base), str(r.get("gate", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 36, c)
		draw_string(mono, Vector2(cols[5], base), remark, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, rc)
		y += rh
	# scanline shimmer
	for sy in range(0, int(h), 4):
		draw_line(Vector2(0, sy), Vector2(w, sy), Color(0, 0, 0, 0.18), 1.0)


func _draw_reboot(w: float, h: float) -> void:
	var lines := ["SEOHAE FIDS v3.2.1", "SYSTEM REBOOT ...", "LOADING SCHEDULE DATA ...", ""]
	var shown := int(fmod(_blink * 3.0, 5.0))
	for i in mini(shown, lines.size()):
		draw_string(mono, Vector2(60, 120 + i * 60), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 40, GREY)
	if fmod(_blink, 0.8) < 0.4:
		draw_rect(Rect2(60, 120 + mini(shown, 3) * 60 - 30, 24, 36), GREY)


func _draw_big(w: float, h: float) -> void:
	var col := AMBER
	if mode == "final":
		col = RED if fmod(_blink, 1.0) < 0.6 else RED.darkened(0.6)
	var total := big_lines.size()
	for i in total:
		var line := str(big_lines[i])
		var fs := 110 if i == 0 else 80
		var y := h * 0.5 + (i - (total - 1) * 0.5) * 130.0 + 35.0
		draw_string(mono, Vector2(0, y), line, HORIZONTAL_ALIGNMENT_CENTER, w, fs, col if i != 0 or mode != "message" else WHITE)
	for sy in range(0, int(h), 4):
		draw_line(Vector2(0, sy), Vector2(w, sy), Color(0, 0, 0, 0.2), 1.0)
