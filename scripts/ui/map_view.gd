class_name MapView
extends Control
## Schematic terminal map in the OPS style. The terminal runs north–south, so the plan is turned a
## quarter (north → right) to fill the wide tablet screen. A side panel lists every zone's lights and
## access, the active work order and where the player is.

var terminal: Terminal
var player: Player
var director: ShiftDirector
var _t := 0.0
var _bounds := Rect2()     # world (x, z) extent of the drawn zones
var _scale := 1.0
var _origin := Vector2.ZERO

const SIDE_W := 380.0
const PAD := 30.0
const ZONE_ORDER := ["hall", "office", "baggage", "storage", "maint", "security", "corridor", "gates", "bridge0"]


func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		queue_redraw()


## World (x, z) → map. North (-z) points right, east (+x) points down.
func _to_map(p: Vector2) -> Vector2:
	return _origin + Vector2(_bounds.end.y - p.y, p.x - _bounds.position.x) * _scale


func _map_rect(r: Rect2) -> Rect2:
	var a := _to_map(r.position)
	var b := _to_map(r.end)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


func _zones() -> Array:
	var out := []
	for zn in ZONE_ORDER:
		if zn == "bridge0" and terminal.gate0_parts == null:
			continue
		out.append(zn)
	return out


func _layout(area: Rect2) -> void:
	var b := Rect2()
	for zn in _zones():
		for r: Rect2 in Terminal.zone_rects(zn):
			b = r if b.size == Vector2.ZERO else b.merge(r)
	_bounds = b.grow(2.0)
	# leave room below for outside name plates and the legend row
	_scale = minf((area.size.x - PAD * 2.0) / _bounds.size.y, (area.size.y - PAD * 2.0 - 64.0) / _bounds.size.x)
	var used := Vector2(_bounds.size.y, _bounds.size.x) * _scale
	_origin = area.position + Vector2((area.size.x - used.x) * 0.5, PAD)


func _draw() -> void:
	var map_area := Rect2(0, 0, size.x - SIDE_W - 16.0, size.y)
	draw_rect(map_area, UiKit.SCREEN)
	var gx := 0.0
	while gx < map_area.size.x:
		var gy := 0.0
		while gy < size.y:
			draw_rect(Rect2(gx, gy, 1.5, 1.5), Color(1, 1, 1, 0.05))
			gy += 24.0
		gx += 24.0
	if terminal == null:
		return
	_layout(map_area)
	var f := UiKit.font("sans", 700)
	var disp := UiKit.font("display", 700)
	var target_zone := ""
	var target_pos := Vector3.INF
	if director and director.current:
		target_zone = director.current.location
		var fac := terminal.facility(director.current.facility_id)
		if fac:
			target_pos = fac.focus_position()
	# zones
	var rects := {}
	for zn in _zones():
		# a zone may have several footprints (hall + its strip, baggage + the staff passage): the largest carries
		# the name and the lamp
		var parts: Array = Terminal.zone_rects(zn).map(func(r): return _map_rect(r))
		var rect: Rect2 = parts[0]
		for pr: Rect2 in parts:
			if pr.get_area() > rect.get_area():
				rect = pr
		rects[zn] = rect
		var locked := _locked(zn)
		var col := UiKit.SCREEN_3 if not locked else Color("0b0f14")
		if zn == target_zone:
			col = col.lerp(Color(UiKit.SIGNAL, 1.0), 0.12 + 0.08 * sin(_t * 4.0))
		for pr: Rect2 in parts:
			draw_rect(pr, col)
			if locked:
				var x := pr.position.x - pr.size.y
				while x < pr.end.x:
					var p0 := Vector2(maxf(x, pr.position.x), pr.position.y + maxf(0.0, pr.position.x - x))
					var p1 := Vector2(minf(x + pr.size.y, pr.end.x), pr.position.y + minf(pr.size.y, pr.end.x - x))
					draw_line(p0, p1, Color(1, 1, 1, 0.035), 1.0)
					x += 14.0
			draw_rect(pr, Color("2b3a4c") if not locked else Color("1c232c"), false, 2.0)
			if zn == target_zone:
				draw_rect(pr, Color(UiKit.SIGNAL_TEXT, 0.7), false, 2.0)
		# lamp in the corner, clear of the name
		if terminal.zones.has(zn) and not locked and rect.size.x > 20.0 and rect.size.y > 20.0:
			var lp := Vector2(rect.end.x - 12.0, rect.position.y + 12.0)
			var lit: bool = terminal.zones[zn].is_on
			if lit:
				draw_circle(lp, 9.0, Color(UiKit.SIGNAL, 0.18))
			draw_circle(lp, 5.0, UiKit.SIGNAL_TEXT if lit else Color("3a4552"))
	# facilities
	for fac in terminal.facilities.values():
		var fp: Vector3 = (fac as Facility).focus_position()
		var mp := _to_map(Vector2(fp.x, fp.z))
		draw_circle(mp, 4.0, Color(UiKit.OPS, 0.85))
		draw_arc(mp, 7.0, 0, TAU, 16, Color(UiKit.OPS, 0.3), 1.5, true)
	# zone names on top (inside when they fit, else outside on a plate with a leader line)
	var placed: Array = []
	for zn in _zones():
		_draw_zone_name(zn, rects[zn], rects, placed, map_area, f)
	# work order target
	if target_pos != Vector3.INF:
		var tp := _to_map(Vector2(target_pos.x, target_pos.z))
		var k := fmod(_t, 1.2) / 1.2
		draw_arc(tp, 10.0 + k * 22.0, 0, TAU, 40, Color(UiKit.SIGNAL_TEXT, 1.0 - k), 2.5, true)
		draw_arc(tp, 9.0, 0, TAU, 32, UiKit.SIGNAL_TEXT, 3.0, true)
		var label := UiKit.t("점검 위치")
		var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.MIN_TEXT).x
		var lr := Rect2(tp + Vector2(16, -30), Vector2(lw + 18, 28))
		if lr.end.x > map_area.end.x - 4.0:
			lr.position.x = tp.x - 16.0 - lr.size.x
		draw_rect(lr, UiKit.SIGNAL)
		draw_string(f, lr.position + Vector2(9, 20), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.MIN_TEXT, UiKit.SIGNAL_INK)
	# player
	if player:
		var pp := _to_map(Vector2(player.global_position.x, player.global_position.z))
		var fw := player.forward()
		var dir := Vector2(-fw.z, fw.x).normalized()
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([pp, pp + dir * 70.0 + side * 34.0, pp + dir * 70.0 - side * 34.0]), Color(UiKit.CLEAR, 0.12))
		draw_colored_polygon(PackedVector2Array([pp + dir * 13.0, pp - dir * 8.0 + side * 8.0, pp - dir * 4.0, pp - dir * 8.0 - side * 8.0]), UiKit.CLEAR)
	# compass + legend
	var cx := Vector2(map_area.end.x - 70.0, 34.0)
	draw_string(disp, cx, "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UiKit.TEXT_DIM)
	draw_line(cx + Vector2(20, -7), cx + Vector2(46, -7), UiKit.TEXT_DIM, 2.0)
	draw_colored_polygon(PackedVector2Array([cx + Vector2(52, -7), cx + Vector2(42, -13), cx + Vector2(42, -1)]), UiKit.TEXT_DIM)
	var ly := size.y - 16.0
	var lx := 18.0
	for item in ["시설", "현재 위치", "점검 위치", "조명 켜짐"]:
		match item:
			"시설":
				draw_circle(Vector2(lx + 4, ly - 6), 4.5, UiKit.OPS)
			"현재 위치":
				draw_colored_polygon(PackedVector2Array([Vector2(lx + 12, ly - 6), Vector2(lx, ly - 13), Vector2(lx + 3, ly - 6), Vector2(lx, ly + 1)]), UiKit.CLEAR)
			"점검 위치":
				draw_arc(Vector2(lx + 6, ly - 6), 6.5, 0, TAU, 20, UiKit.SIGNAL_TEXT, 2.0, true)
			_:
				draw_circle(Vector2(lx + 5, ly - 6), 5.0, UiKit.SIGNAL_TEXT)
		var label := UiKit.t(item)
		draw_string(f, Vector2(lx + 20, ly), label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.MIN_TEXT, UiKit.TEXT_DIM)
		lx += 20.0 + f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.MIN_TEXT).x + 26.0
	_draw_side(Rect2(size.x - SIDE_W, 0, SIDE_W, size.y), target_zone, f, disp)


func _draw_zone_name(zn: String, rect: Rect2, rects: Dictionary, placed: Array, area: Rect2, f: Font) -> void:
	var name_text: String = UiKit.t(Terminal.ZONE_NAMES.get(zn, zn))
	var fs := 17
	var tw := f.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var col := UiKit.TEXT if not _locked(zn) else Color("5a636e")
	if tw + 34.0 <= rect.size.x and rect.size.y >= 34.0:
		draw_string(f, rect.position + Vector2(10, 24), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		return
	var box := Vector2(tw + 16.0, 26.0)
	var cands := [
		Rect2(Vector2(rect.get_center().x - box.x * 0.5, rect.end.y + 10.0), box),
		Rect2(Vector2(rect.get_center().x - box.x * 0.5, rect.position.y - 10.0 - box.y), box),
		Rect2(Vector2(rect.end.x + 10.0, rect.get_center().y - box.y * 0.5), box),
		Rect2(Vector2(rect.position.x - 10.0 - box.x, rect.get_center().y - box.y * 0.5), box),
	]
	var pick: Rect2 = cands[0]
	var best := INF
	for c: Rect2 in cands:
		if not area.grow(-4.0).encloses(c):
			continue
		var cost := 0.0
		for other in rects:
			if other != zn and (rects[other] as Rect2).intersects(c):
				cost += 1.0
		for p: Rect2 in placed:
			if p.intersects(c):
				cost += 5.0
		if cost < best:
			best = cost
			pick = c
	placed.append(pick)
	var to := rect.get_center().clamp(pick.position, pick.end)
	draw_line(to.clamp(rect.position, rect.end), to, Color("4a5a6e"), 1.0)
	draw_rect(pick, Color(UiKit.SCREEN_2, 0.96))
	draw_rect(pick, Color("2b3a4c"), false, 1.0)
	draw_string(f, pick.position + Vector2(8, 19), name_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Right panel: every zone's lights and access, then the active order.
func _draw_side(r: Rect2, target_zone: String, f: Font, disp: Font) -> void:
	draw_rect(r, UiKit.SCREEN_2)
	var x := r.position.x + 22.0
	var w := r.size.x - 44.0
	var y := r.position.y + 34.0
	draw_string(disp, Vector2(x, y), UiKit.t("ZONE STATUS · 구역 상태"), HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.MIN_TEXT, UiKit.TEXT_MUTE)
	y += 16.0
	var here: String = player.zone if player else ""
	for zn in _zones():
		var row := Rect2(r.position.x + 10.0, y, r.size.x - 20.0, 38.0)
		if zn == target_zone:
			draw_rect(row, Color(UiKit.SIGNAL, 0.08))
			draw_rect(Rect2(row.position, Vector2(3, row.size.y)), UiKit.SIGNAL)
		elif zn == here:
			draw_rect(Rect2(row.position, Vector2(3, row.size.y)), UiKit.CLEAR)
		var locked := _locked(zn)
		draw_string(f, Vector2(x, y + 26.0), UiKit.t(Terminal.ZONE_NAMES.get(zn, zn)), HORIZONTAL_ALIGNMENT_LEFT, w - 150.0, 18,
			UiKit.TEXT if not locked else UiKit.TEXT_MUTE)
		var state := UiKit.t("통제") if locked else ("—" if not terminal.zones.has(zn) else ("ON" if terminal.zones[zn].is_on else "OFF"))
		var sc := UiKit.ALERT.darkened(0.15) if locked else (UiKit.SIGNAL_TEXT if state == "ON" else UiKit.TEXT_MUTE)
		var sw := disp.get_string_size(state, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.MIN_TEXT).x
		var chip := Rect2(Vector2(x + w - sw - 18.0, y + 8.0), Vector2(sw + 18.0, 24.0))
		if state == "ON":
			draw_rect(chip, UiKit.SIGNAL)
			sc = UiKit.SIGNAL_INK
		else:
			draw_rect(chip, sc if locked else Color("3a4552"), false, 1.0)
		draw_string(disp, chip.position + Vector2(9, 18), state, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.MIN_TEXT, sc)
		draw_line(Vector2(x, y + 38.0), Vector2(x + w, y + 38.0), UiKit.SCREEN_LINE, 1.0)
		y += 40.0
	# active order
	y += 40.0
	draw_string(disp, Vector2(x, y), UiKit.t("CURRENT ORDER · 현재 지시"), HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.MIN_TEXT, UiKit.SIGNAL_TEXT)
	var title := UiKit.t(director.current.title) if director and director.current else "—"
	draw_multiline_string(f, Vector2(x, y + 30.0), title, HORIZONTAL_ALIGNMENT_LEFT, w, 20, 2, UiKit.TEXT)
	var th := f.get_multiline_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, w, 20, 2).y
	if target_zone != "":
		draw_string(f, Vector2(x, y + 30.0 + th + 6.0), UiKit.t("위치 · %s") % UiKit.t(Terminal.ZONE_NAMES.get(target_zone, target_zone)), HORIZONTAL_ALIGNMENT_LEFT, w, UiKit.MIN_TEXT, UiKit.TEXT_DIM)


func _locked(zn: String) -> bool:
	match zn:
		"baggage":
			return terminal.shutters.has("baggage") and not terminal.shutters.baggage.is_open
		"security":
			return not terminal.shutters.security.is_open
		"corridor":
			return not terminal.shutters.corridor.is_open
		"gates":
			return not terminal.shutters.gates.is_open
		"maint":
			return not terminal.doors.maint.is_open
	return false
