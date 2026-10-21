class_name BoardingPassCard
extends Control
## FLIGHT 000 boarding pass: generated paper art (assets/ui/boarding_pass.png) with every field printed
## by the game. Coordinates are in the art's original 1774 x 887 space and scale with the card width.

const ART := Vector2(1774, 887)
const TICKET := Rect2(36, 109, 1705, 667)
const BAND_BOTTOM := 249.0
const PERF_X := 1318.0
const BARCODE := Rect2(84, 626, 1196, 98)

var passenger := ""
var _k := 1.0


static func make(width: float, passenger_name: String) -> BoardingPassCard:
	var c := BoardingPassCard.new()
	c.passenger = passenger_name
	c._k = width / ART.x
	c.custom_minimum_size = ART * c._k
	c.size = c.custom_minimum_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _ready() -> void:
	var white := UiKit.NAVY_TEXT
	var ink := UiKit.INK_0
	var red := UiKit.STAMP_RED
	# header band
	var plane := UiIcon.make("plane", 74 * _k, white)
	plane.position = _at(Vector2(80, 142))
	add_child(plane)
	_text("SEOHAE AIR", Vector2(176, 132), 66, white, "display", 700)
	_text("탑승권 · BOARDING PASS", Vector2(700, 150), 40, white, "sans", 700, 580, HORIZONTAL_ALIGNMENT_RIGHT)
	_text("BOARDING PASS", Vector2(1360, 150), 40, Color(white, 0.85), "display", 700)
	# main section
	_field("FLIGHT", "000", Vector2(84, 280), 88, ink, "mono")
	_field("PASSENGER", passenger, Vector2(430, 280), 88, ink, "sans", 900)
	_field("GATE", "0", Vector2(84, 440), 120, red, "display")
	_field("SEAT", "—", Vector2(430, 440), 88, ink, "mono")
	_field("DESTINATION", "HOME", Vector2(700, 440), 88, ink, "mono")
	# stub
	_field("FLIGHT", "000", Vector2(1360, 280), 64, ink, "mono")
	_field("BOARDING", "NOW", Vector2(1360, 420), 80, red, "display")
	_field("ORIGIN", "UNKNOWN", Vector2(1360, 590), 46, ink, "mono")


func _at(p: Vector2) -> Vector2:
	return p * _k


func _text(t: String, pos: Vector2, art_size: float, col: Color, kind := "sans", weight := 400,
		width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := UiKit.label(t, maxi(8, int(art_size * _k)), col, kind, weight)
	l.position = _at(pos)
	if width > 0.0:
		l.size = Vector2(width * _k, art_size * _k * 1.4)
		l.horizontal_alignment = align
	add_child(l)
	return l


func _field(caption: String, value: String, pos: Vector2, art_size: float, col: Color, kind := "mono", weight := 700) -> void:
	_text(caption, pos, 30, Color("5a6478"), "display", 700)
	_text(value, pos + Vector2(0, 34), art_size, col, kind, weight)


func _draw() -> void:
	var tex := UiArt.tex("boarding_pass")
	if tex:
		draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	else:
		var t := Rect2(_at(TICKET.position), TICKET.size * _k)
		draw_rect(t, UiKit.NAVY_TEXT)
		draw_rect(Rect2(t.position, Vector2(t.size.x, (BAND_BOTTOM - TICKET.position.y) * _k)), UiKit.NAVY)
		var y := t.position.y
		while y < t.end.y:
			draw_line(Vector2(PERF_X * _k, y), Vector2(PERF_X * _k, y + 6), Color("b9b3a5"), 2.0)
			y += 12.0
	# barcode printed into the pale strip
	var r := Rect2(_at(BARCODE.position), BARCODE.size * _k)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4127
	var x := r.position.x + 6.0
	while x < r.end.x - 6.0:
		var w := rng.randi_range(1, 4) * maxf(1.0, 3.2 * _k)
		if rng.randf() < 0.62:
			draw_rect(Rect2(x, r.position.y + 6.0, minf(w, r.end.x - 6.0 - x), r.size.y - 12.0), Color(0.06, 0.07, 0.09, 0.9))
		x += w + rng.randi_range(1, 3) * maxf(1.0, 2.6 * _k)
