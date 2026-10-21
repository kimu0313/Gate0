class_name MapView
extends Control
## Schematic terminal map with zone states, the active work order and the player.

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
	var s := minf(size.x / span.x, size.y / span.y)
	var off := (size - span * s) * 0.5
	return off + (p - WORLD_MIN) * s


func _scale() -> float:
	var span := WORLD_MAX - WORLD_MIN
	return minf(size.x / span.x, size.y / span.y)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.05))
	if terminal == null:
		return
	var f := UiKit.font("sans", 600)
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
		var col := Color(0.07, 0.11, 0.18) if not locked else Color(0.04, 0.045, 0.05)
		if zn == target_zone:
			col = col.lerp(Color(0.35, 0.25, 0.05), 0.45 + 0.25 * sin(_t * 4.0))
		draw_rect(rect, col)
		draw_rect(rect, Color(0.3, 0.42, 0.6) if not locked else Color(0.2, 0.2, 0.22), false, 2.0)
		var lit: bool = terminal.zones.has(zn) and terminal.zones[zn].is_on
		var name_col := Color(0.85, 0.88, 0.95) if not locked else Color(0.35, 0.36, 0.4)
		draw_string(f, rect.position + Vector2(6, 20), Terminal.ZONE_NAMES.get(zn, zn), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8, 15, name_col)
		if terminal.zones.has(zn) and not locked:
			draw_string(f, rect.position + Vector2(6, 38), "조명 ON" if lit else "조명 OFF", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.3) if lit else Color(0.45, 0.45, 0.5))
		if locked:
			draw_string(f, rect.get_center() - Vector2(30, -6), "통제", HORIZONTAL_ALIGNMENT_CENTER, 60, 14, Color(0.4, 0.4, 0.42))
	# facility markers
	for fac in terminal.facilities.values():
		var fp: Vector3 = (fac as Facility).focus_position()
		var mp := _to_map(Vector2(fp.x, fp.z))
		draw_circle(mp, 4.0, Color(0.55, 0.7, 0.95, 0.8))
	if target_pos != Vector3.INF:
		var tp := _to_map(Vector2(target_pos.x, target_pos.z))
		var rr := 10.0 + 4.0 * sin(_t * 5.0)
		draw_arc(tp, rr, 0, TAU, 32, UiKit.C_ACCENT, 3.0, true)
		draw_string(f, tp + Vector2(14, -10), "점검 위치", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiKit.C_ACCENT)
	# player
	if player:
		var pp := _to_map(Vector2(player.global_position.x, player.global_position.z))
		var fw := player.forward()
		var dir := Vector2(fw.x, fw.z).normalized()
		var side := Vector2(-dir.y, dir.x)
		var pts := PackedVector2Array([pp + dir * 12.0, pp - dir * 7.0 + side * 7.0, pp - dir * 7.0 - side * 7.0])
		draw_colored_polygon(pts, Color(0.4, 1.0, 0.6))
	draw_string(f, Vector2(10, size.y - 12), "N ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiKit.C_DIM)


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
