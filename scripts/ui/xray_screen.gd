class_name XrayScreen
extends Control
## False-colour X-ray scan image drawn procedurally.
## content: "" (idle) | "bag" | "figure" | "heart" | "mybag" (your own bag, scanned as a passenger's)

var content := ""
var powered := true
var stare := 0.0          # 0..1, figure turns its head toward the viewer
var scan_progress := 1.0  # 0..1 reveal sweep
var _t := 0.0
var mono: Font

const ORANGE := Color(1.0, 0.55, 0.15)
const BLUE := Color(0.2, 0.45, 1.0)
const GREEN := Color(0.25, 0.85, 0.35)


func _ready() -> void:
	Geo.fonts()
	mono = Geo.mono_font


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if not powered:
		draw_rect(Rect2(0, 0, w, h), Color.BLACK)
		return
	draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.03, 0.06))
	draw_string(mono, Vector2(16, 30), "X-RAY 01   SEOHAE SEC   %s" % Game.clock_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.6, 0.7, 0.8))
	draw_string(mono, Vector2(16, h - 16), "kV 160  mA 0.8  DUAL-ENERGY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.4, 0.5, 0.6))
	if content == "":
		draw_string(mono, Vector2(0, h * 0.5), "NO OBJECT", HORIZONTAL_ALIGNMENT_CENTER, w, 34, Color(0.4, 0.5, 0.6))
		return
	var cx := w * 0.5
	var cy := h * 0.52
	# bag shell
	var bag := Rect2(cx - 220, cy - 130, 440, 260)
	draw_rect(bag, Color(0.95, 0.5, 0.15, 0.18))
	draw_rect(bag, Color(1.0, 0.6, 0.2, 0.6), false, 4.0)
	draw_rect(Rect2(cx - 50, cy - 160, 100, 30), Color(0.3, 0.5, 1.0, 0.5), false, 4.0)
	match content:
		"bag":
			_draw_normal_contents(cx, cy)
		"figure":
			_draw_figure(cx, cy)
		"mybag":
			_draw_normal_contents(cx, cy)
			_draw_passenger_tag(cx, cy)
		"heart":
			_draw_normal_contents(cx, cy)
			var beat := 1.0 + 0.18 * maxf(0.0, sin(_t * 7.5)) + 0.1 * maxf(0.0, sin(_t * 7.5 - 1.2))
			draw_circle(Vector2(cx + 90, cy + 40), 34.0 * beat, Color(1.0, 0.45, 0.12, 0.85))
			draw_circle(Vector2(cx + 66, cy + 22), 22.0 * beat, Color(1.0, 0.5, 0.15, 0.8))
			draw_circle(Vector2(cx + 112, cy + 22), 22.0 * beat, Color(1.0, 0.5, 0.15, 0.8))
			draw_line(Vector2(cx + 90, cy + 5), Vector2(cx + 100, cy - 40), Color(0.2, 0.5, 1.0, 0.8), 6.0)
	# reveal sweep
	if scan_progress < 1.0:
		var x := w * scan_progress
		draw_rect(Rect2(x, 0, w - x, h), Color(0.02, 0.03, 0.06))
		draw_line(Vector2(x, 0), Vector2(x, h), Color(0.6, 0.9, 1.0, 0.8), 3.0)
	for sy in range(0, int(h), 3):
		draw_line(Vector2(0, sy), Vector2(w, sy), Color(0, 0, 0, 0.15), 1.0)


func _draw_normal_contents(cx: float, cy: float) -> void:
	draw_rect(Rect2(cx - 190, cy - 100, 220, 150), Color(0.2, 0.45, 1.0, 0.65))      # laptop
	draw_rect(Rect2(cx - 180, cy - 90, 200, 130), Color(0.3, 0.6, 1.0, 0.35), false, 3.0)
	draw_rect(Rect2(cx + 60, cy - 90, 50, 150), Color(1.0, 0.55, 0.15, 0.55))       # bottle
	draw_circle(Vector2(cx + 85, cy - 95), 14.0, Color(0.2, 0.45, 1.0, 0.8))
	for i in 3:                                                                       # keys
		draw_line(Vector2(cx + 140 + i * 12, cy + 60), Vector2(cx + 150 + i * 12, cy + 100), BLUE, 6.0)
	draw_circle(Vector2(cx + 150, cy + 55), 12.0, Color(0.2, 0.45, 1.0, 0.9))
	var pts := PackedVector2Array()                                                     # cable
	for i in 20:
		pts.append(Vector2(cx - 170 + i * 14, cy + 80 + sin(i * 0.9) * 12.0))
	draw_polyline(pts, Color(0.3, 0.9, 0.4, 0.8), 4.0)


## A baggage tag on the handle: the airport scanned your bag as a passenger's (DAY 2 · 수칙 p.7 ③).
func _draw_passenger_tag(cx: float, cy: float) -> void:
	var red := Color(1.0, 0.32, 0.25)
	draw_string(mono, Vector2(0, 30), "PASSENGER BAGGAGE   ", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 16, 20, red)
	var tag := Rect2(cx + 60, cy - 214, 230, 70)
	draw_line(Vector2(cx + 30, cy - 160), tag.position + Vector2(20, 70), Color(0.95, 0.85, 0.4, 0.8), 3.0)
	draw_rect(tag, Color(0.95, 0.85, 0.4, 0.22))
	draw_rect(tag, Color(0.95, 0.85, 0.4, 0.8), false, 3.0)
	draw_string(mono, tag.position + Vector2(12, 28), "PAX  " + Game.player_name, HORIZONTAL_ALIGNMENT_LEFT, tag.size.x - 20, 22, Color(1, 0.95, 0.75))
	draw_string(mono, tag.position + Vector2(12, 56), "FLT 000  -> HOME", HORIZONTAL_ALIGNMENT_LEFT, tag.size.x - 20, 20, red)


func _draw_figure(cx: float, cy: float) -> void:
	var c := Color(1.0, 0.55, 0.15, 0.75)
	var bone := Color(0.3, 0.55, 1.0, 0.85)
	# curled body (fetal position)
	draw_circle(Vector2(cx - 120, cy - 40), 52.0, c)                     # head
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 90, cy - 10), Vector2(cx + 40, cy - 70), Vector2(cx + 150, cy - 30),
		Vector2(cx + 160, cy + 40), Vector2(cx + 60, cy + 90), Vector2(cx - 60, cy + 60)]), c)
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - 40, cy + 40), Vector2(cx + 20, cy + 110), Vector2(cx - 100, cy + 115), Vector2(cx - 110, cy + 70)]), c)
	# spine and ribs
	var spine := PackedVector2Array()
	for i in 14:
		var a := float(i) / 13.0
		spine.append(Vector2(cx - 80 + a * 220, cy - 40 + sin(a * PI) * -30 + a * 60))
	draw_polyline(spine, bone, 7.0)
	for i in range(2, 10):
		var p := spine[i]
		draw_line(p, p + Vector2(-10, 35), bone, 3.0)
	draw_circle(Vector2(cx - 135, cy - 45), 30.0, Color(0.35, 0.6, 1.0, 0.5))   # skull
	# eyes open as it "notices" the viewer
	if stare > 0.05:
		var e := Color(1, 1, 1, clampf(stare, 0.0, 1.0))
		draw_circle(Vector2(cx - 148, cy - 52), 6.0 * stare, e)
		draw_circle(Vector2(cx - 120, cy - 55), 6.0 * stare, e)
