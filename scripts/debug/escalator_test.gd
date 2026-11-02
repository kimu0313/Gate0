extends Node
## Debug: `godot --headless --path . res://scenes/game.tscn -- --chapter ch1 --skip-boot --escalator-test` walks the
## player up and down every escalator between the lounge floor and its 2F (Terminal.escalator_units), and the aircraft
## hall's from its deck to its 2F deck (AirHall.ESC_FOOT, rising the other way): from 3 m in front of its foot up onto
## the 2F, then back down to where it started. Then the way into the aircraft hall on foot (CabinWay): from the lounge's
## south aisle through the cabin's door and down its wide aisle into the haze, out of the section on the hall's deck,
## round the escalator and along the deck; and back: from the deck into the section's haze,
## out in the cabin and back through its door into the lounge. Exit 0 when every unit can be walked both ways and
## every walk gets through; otherwise it prints where the player got stuck.

var world: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().create_timer(1.5).timeout
	CabinWay.way.unseal()                                # (the story opens the cabin's door on the device: this walk uses it)
	var p: Player = world.player
	var bad := 0
	# [foot, which way it rises along z (-1 = north), the 2F edge it comes up over, name]
	var units := []
	for u: Array in Terminal.escalator_units():
		units.append([u[0], -1.0, Terminal.ATRIUM.position.y, "down" if u[1] else "up"])
	units.append([AirHall.ESC_FOOT, 1.0, AirHall.UPPER_Z0, "aircraft hall"])
	for u: Array in units:
		var foot: Vector3 = u[0]
		var dir: float = u[1]
		var top_z: float = foot.z + dir * (Terminal.MEZZ_Y / tan(deg_to_rad(Escalator.ANGLE)) + 2.6)      # past the top landing
		p.teleport(Transform3D(Basis(), foot + Vector3(0, 0.05, -dir * 3.0)))
		await get_tree().create_timer(0.3).timeout
		var up := await _walk(p, [Vector3(foot.x, 0, foot.z - dir), Vector3(foot.x, 0, top_z)])
		var ok_up: bool = not up[1] and p.global_position.y > Terminal.MEZZ_Y - 0.05 \
				and (p.global_position.z - float(u[2])) * dir > 0.0
		var down := await _walk(p, [Vector3(foot.x, 0, foot.z - dir * 3.0)])
		var ok_down: bool = not down[1] and p.global_position.y < 0.3
		print("[esc] %s unit x %.2f: up %s %s, down %s %s" % [u[3], foot.x,
				"ok" if ok_up else "BLOCKED", up[0], "ok" if ok_down else "BLOCKED", down[0]])
		if not (ok_up and ok_down):
			bad += 1
	bad += await _ways(p)
	print("[esc] %s" % ("PASS" if bad == 0 else "FAIL (%d)" % bad))
	get_tree().quit(0 if bad == 0 else 1)


## The way into the aircraft hall and back (see the notes at the top): the number of walks that failed.
func _ways(p: Player) -> int:
	var bad := 0
	var aisle := CabinWay.AXIS_X + 0.73                       # the cabin's wide aisle (its left, the east side)
	var off := CabinWay.offset()
	var stub := CabinWay.stub_rect()
	# in: the lounge -> the door -> down the aisle until the haze gives you back on the deck
	p.teleport(Transform3D(Basis(), Vector3(-14.0, 0.05, CabinWay.DOOR_Z)))
	await get_tree().create_timer(0.3).timeout
	var w := await _walk(p, [Vector3(-19.0, 0, CabinWay.DOOR_Z), Vector3(aisle, 0, CabinWay.DOOR_Z),
			Vector3(aisle, 0, CabinWay.DOOR_Z + 1.0), Vector3(aisle, 0, CabinWay.join_z() + 2.0)])
	var at := p.global_position
	var ok: bool = not w[1] and stub.has_point(Vector2(at.x, at.z)) and at.z > CabinWay.JOIN_HALL and absf(at.x - (aisle + off.x)) < 0.3
	print("[esc] walk lounge -> cabin -> through the haze: %s %s" % ["ok" if ok else "FAILED", w[0]])
	bad += 0 if ok else 1
	# on: out of the section, round the escalator and down the walkway beside it, along the deck under the 2F deck
	var far := Vector3(-29.3, 0, 40.0)
	w = await _walk(p, [Vector3(at.x, 0, -19.2), Vector3(-27.2, 0, -18.4), Vector3(-27.2, 0, 0.0), Vector3(-29.3, 0, 2.0), far])
	ok = not w[1] and Vector2(p.global_position.x, p.global_position.z).distance_to(Vector2(far.x, far.z)) < 0.6 \
			and absf(p.global_position.y) < 0.2
	print("[esc] walk landing -> beside the escalator -> along the deck: %s %s" % ["ok" if ok else "FAILED", w[0]])
	bad += 0 if ok else 1
	# guards: walking hard at the drop from the landing, past the escalator's side, from the walkway, nobody falls
	for g: Array in [[Vector3(-29.35, 0.05, -18.5), Vector3(-31.2, 0, -13.0), "landing -> its parapet"],
			[Vector3(-29.35, 0.05, -18.5), Vector3(-29.7, 0, -12.0), "landing -> beside the escalator"],
			[Vector3(-27.2, 0.05, -9.0), Vector3(-31.0, 0, -9.0), "walkway -> under the escalator"]]:
		p.teleport(Transform3D(Basis(), g[0]))
		await get_tree().create_timer(0.3).timeout
		var gw := await _walk(p, [g[1]])
		var safe := p.global_position.y > -0.3
		print("[esc] guard %s: %s %s" % [g[2], "ok" if safe else "FELL", gw[0]])
		bad += 0 if safe else 1
	# back: from the deck into the section's haze, out in the cabin, back through its door
	p.teleport(Transform3D(Basis(), Vector3(aisle + off.x, 0.05, -16.0)))
	await get_tree().create_timer(0.3).timeout
	w = await _walk(p, [Vector3(aisle + off.x, 0, CabinWay.JOIN_HALL - 1.5)])
	at = p.global_position
	ok = not w[1] and CabinWay.cabin_rect().has_point(Vector2(at.x, at.z)) and at.z < CabinWay.join_z()
	print("[esc] walk deck -> back through the haze: %s %s" % ["ok" if ok else "FAILED", w[0]])
	bad += 0 if ok else 1
	w = await _walk(p, [Vector3(aisle, 0, CabinWay.DOOR_Z + 0.6), Vector3(aisle, 0, CabinWay.DOOR_Z),
			Vector3(-18.0, 0, CabinWay.DOOR_Z), Vector3(-15.0, 0, CabinWay.DOOR_Z)])
	ok = not w[1] and p.global_position.x > -15.6
	print("[esc] walk cabin -> out of its door into the lounge: %s %s" % ["ok" if ok else "FAILED", w[0]])
	bad += 0 if ok else 1
	return bad


## Walks `pts` (scripted, through the player's own physics): [where it ended, whether it got stuck on the way].
func _walk(p: Player, pts: Array) -> Array:
	p.walk_path(pts, 1.6)
	var dist := 0.0
	var from := p.global_position
	for q: Vector3 in pts:
		dist += Vector2(from.x, from.z).distance_to(Vector2(q.x, q.z))
		from = q
	var limit := int((dist / 1.6 + 10.0) * 1000.0)       # walking pace, and time to spare
	var t0 := Time.get_ticks_msec()
	while p.walking() and Time.get_ticks_msec() - t0 < limit:
		await get_tree().process_frame
	var stuck := p.walking()
	var at := p.global_position
	if stuck:
		p.teleport(p.global_transform)                # stops the walk where it is
	return ["at %s%s" % [str(at.snapped(Vector3.ONE * 0.1)), " (stuck)" if stuck else ""], stuck]
