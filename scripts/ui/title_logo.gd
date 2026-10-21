class_name TitleLogo
extends Control
## "GATE [0] →" wayfinding-sign logo, drawn in code so the 0 sits optically centred in its lightbox
## tile and the word GATE shares the tile's centre line.

const CAP := 0.70          # Bahnschrift cap / figure height relative to font size

var font_size := 176
var _t := 0.0
var _font: Font


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UiKit.font("display", 700)


func _ready() -> void:
	custom_minimum_size = _layout().size


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _layout() -> Dictionary:
	var fs := font_size
	var gate_w := _font.get_string_size("GATE", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + _tracking() * 3.0
	var cap := fs * CAP
	var pad := fs * 0.2
	var tile_h := cap + pad * 2.0
	var tile_w := tile_h * 0.82
	var gap := fs * 0.13
	var arrow_w := fs * 0.4
	var glow := 18.0
	var w := gate_w + gap + tile_w + gap * 1.3 + arrow_w + glow
	return {"size": Vector2(w, tile_h + glow * 2.0), "gate_w": gate_w, "cap": cap, "tile": Vector2(tile_w, tile_h),
		"gap": gap, "arrow_w": arrow_w, "glow": glow}


func _draw() -> void:
	var L := _layout()
	var fs := font_size
	var cap: float = L.cap
	var tile: Vector2 = L.tile
	var cy: float = L.glow + tile.y * 0.5
	var baseline := cy + cap * 0.5
	# GATE, slightly tracked out like sign lettering
	var gx := 0.0
	for ch in "GATE":
		_draw_text(ch, Vector2(gx, baseline), Color("f2f2f0"))
		gx += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + _tracking()
	# lightbox tile with a slow breathing glow
	var tx: float = L.gate_w + L.gap
	var tr := Rect2(tx, cy - tile.y * 0.5, tile.x, tile.y)
	var breath := 0.75 + 0.25 * sin(_t * 1.7)
	for i in 7:
		var k := 1.0 - i / 7.0
		draw_rect(tr.grow(2.0 + i * 2.6), Color(UiKit.SIGNAL, 0.035 * k * breath))
	draw_rect(tr, UiKit.SIGNAL)
	# lightbox falloff: brighter under the top edge, fading smoothly down the acrylic
	var strips := 16
	for i in strips:
		var y := tr.position.y + tr.size.y * 0.6 * i / strips
		draw_rect(Rect2(tr.position.x, y, tr.size.x, tr.size.y * 0.6 / strips + 1.0), Color(1, 1, 1, 0.16 * (1.0 - float(i) / strips)))
	draw_rect(Rect2(tr.position.x, tr.end.y - 5.0, tr.size.x, 5.0), Color("c98f00"))
	draw_rect(tr, Color("b07d00"), false, 2.0)
	# the 0, centred on both axes inside the tile
	var zw := _font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_draw_text("0", Vector2(tr.position.x + (tr.size.x - zw) * 0.5, baseline), UiKit.INK_0)
	# arrow on the same centre line
	var ax: float = tr.end.x + L.gap * 1.3
	var aw: float = L.arrow_w
	var th := fs * 0.055
	var ah := cap * 0.36
	draw_line(Vector2(ax, cy), Vector2(ax + aw - th * 0.6, cy), UiKit.SIGNAL, th)
	draw_polyline(PackedVector2Array([Vector2(ax + aw - ah, cy - ah), Vector2(ax + aw, cy), Vector2(ax + aw - ah, cy + ah)]),
		UiKit.SIGNAL, th, true)


func _tracking() -> float:
	return font_size * 0.045


func _draw_text(s: String, pos: Vector2, col: Color) -> void:
	draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
