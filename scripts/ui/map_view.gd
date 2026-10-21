class_name MapView
extends Control
## Schematic terminal map in the OPS style: zone states, the active work order and the player.

var terminal: Terminal
var player: Player
var director: ShiftDirector
var _t := 0.0
const WORLD_MIN := Vector2(-36, -104)
const WORLD_MAX := Vector2(60, 16)


func _process(delta: float) -> void:
	_t += delta
	if is_visible_in_tree():
		queue_redraw()


func _to_map(p: Vector2) -> Vector2:
	var span := WORLD_MAX - WORLD_MIN
	var s := minf((size.x - 40) / span.x, (size.y - 40) / span.y)
	var off := (size - span * s) * 0.5
	return off + (p - WORLD_MIN) * s


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiKit.SCREEN)
	var gx := 0.0
	while gx < size.x:
		var gy := 0.0
		while gy < size.y:
			draw_rect(Rect2(gx, gy, 1.5, 1.5), Color(1, 1, 1, 0.05))
			gy += 24.0
		gx += 24.0
	if terminal == null:
		return
	var f := UiKit.font("sans", 700)
	var disp := UiKit.font("display", 700)
	var target_zone := ""
	var target_pos := Vector3.INF
	if director and director.current:
		target_zone = director.current.location
		var fac := terminal.facility(director.current.facility_id)
		if fac:
			target_pos = fac.focus_position()
	for zn in Terminal.ZONE_RECTS.keys():
		if zn == "bridge0" and terminal.gate0_parts == null:
			continue
		var r: Rect2 = Terminal.ZONE_RECTS[zn]
		var a := _to_map(r.position)
		var b := _to_map(r.position + r.size)
		var rect := Rect2(a, b - a)
		var locked := _locked(zn)
		var col := UiKit.SCREEN_3 if not locked else Color("0b0f14")
		if zn == target_zone:
			col = col.lerp(Color(UiKit.SIGNAL, 1.0), 0.12 + 0.08 * sin(_t * 4.0))
		draw_rect(rect, col)
		if locked:
			var x := rect.position.x - rect.size.y
			while x < rect.end.x:
				var p0 := Vector2(maxf(x, rect.position.x), rect.position.y + maxf(0.0, rect.position.x - x))
				var p1 := Vector2(minf(x + rect.size.y, rect.end.x), rect.position.y + minf(rect.size.y, rect.end.x - x))
				draw_line(p0, p1, Color(1, 1, 1, 0.035), 1.0)
				x += 14.0
		draw_rect(rect, Color("2b3a4c") if not locked else Color("1c232c"), false, 2.0)
		if zn == target_zone:
			draw_rect(rect, Color(UiKit.SIGNAL, 0.7), false, 2.0)
		var lit: bool = terminal.zones.has(zn) and terminal.zones[zn].is_on
		var name_col := UiKit.TEXT if not locked else Color("4a525d")
		var roomy := rect.size.x >= 120.0 and rect.size.y >= 56.0
		draw_string(f, rect.position + Vector2(10, 24), Terminal.ZONE_NAMES.get(zn, zn), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 14, 15, name_col)
		if terminal.zones.has(zn) and not locked:
			var lp := rect.position + Vector2(16, 42) if roomy else rect.position + Vector2(rect.size.x - 12, 14)
			draw_circle(lp, 5.0, UiKit.SIGNAL if lit else Color("3a4552"))
			if lit:
				draw_circle(lp, 9.0, Color(UiKit.SIGNAL, 0.18))
			if roomy:
				draw_string(disp, lp + Vector2(12, 5), "LIGHT ON" if lit else "LIGHT OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiKit.SIGNAL if lit else UiKit.TEXT_MUTE)
		if locked and roomy:
			draw_string(disp, rect.get_center() + Vector2(-70, 6), "RESTRICTED · 통제", HORIZONTAL_ALIGNMENT_CENTER, 140, 13, Color("4a525d"))
	for fac in terminal.facilities.values():
		var fp: Vector3 = (fac as Facility).focus_position()
		var mp := _to_map(Vector2(fp.x, fp.z))
		draw_circle(mp, 4.0, Color(UiKit.OPS, 0.85))
		draw_arc(mp, 7.0, 0, TAU, 16, Color(UiKit.OPS, 0.3), 1.5, true)
	if target_pos != Vector3.INF:
		var tp := _to_map(Vector2(target_pos.x, target_pos.z))
		var k := fmod(_t, 1.2) / 1.2
		draw_arc(tp, 10.0 + k * 22.0, 0, TAU, 40, Color(UiKit.SIGNAL, 1.0 - k), 2.5, true)
		draw_arc(tp, 9.0, 0, TAU, 32, UiKit.SIGNAL, 3.0, true)
		var label := "점검 위치"
		var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_rect(Rect2(tp + Vector2(16, -26), Vector2(lw + 16, 24)), UiKit.SIGNAL)
		draw_string(f, tp + Vector2(24, -9), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiKit.INK_0)
	if player:
		var pp := _to_map(Vector2(player.global_position.x, player.global_position.z))
		var fw := player.forward()
		var dir := Vector2(fw.x, fw.z).normalized()
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([pp, pp + dir * 70.0 + side * 34.0, pp + dir * 70.0 - side * 34.0]), Color(UiKit.CLEAR, 0.12))
		draw_colored_polygon(PackedVector2Array([pp + dir * 13.0, pp - dir * 8.0 + side * 8.0, pp - dir * 4.0, pp - dir * 8.0 - side * 8.0]), UiKit.CLEAR)
	# compass + legend
	draw_string(disp, Vector2(size.x - 60, 34), "N ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, UiKit.TEXT_DIM)
	var ly := size.y - 18
	draw_circle(Vector2(20, ly - 5), 4.0, UiKit.OPS)
	draw_string(f, Vector2(32, ly), "시설", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiKit.TEXT_DIM)
	draw_colored_polygon(PackedVector2Array([Vector2(86, ly - 12), Vector2(93, ly + 1), Vector2(79, ly + 1)]), UiKit.CLEAR)
	draw_string(f, Vector2(100, ly), "현재 위치", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiKit.TEXT_DIM)
	draw_arc(Vector2(178, ly - 5), 6.0, 0, TAU, 20, UiKit.SIGNAL, 2.0, true)
	draw_string(f, Vector2(190, ly), "점검 위치", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiKit.TEXT_DIM)


func _locked(zn: String) -> bool:
	match zn:
		"security":
			return not terminal.shutters.security.is_open
		"corridor":
			return not terminal.shutters.corridor.is_open
		"gates":
			return not terminal.shutters.gates.is_open
		"maint":
			return not terminal.doors.maint.is_open
	return false
