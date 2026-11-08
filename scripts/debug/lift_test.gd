extends Node
## Debug: `godot --headless --path . res://scenes/game.tscn -- --skip-boot --lift-test` rides and walks the way between
## the 4th floor's corridors and the lounge (1F) through the player's own physics, no story: the lift down (call it,
## step in, press 1, step out into the lounge) and back up; then the stairs, barred on every floor (the 4F gate keeps
## you on the landing; from the lounge through the stair lobby to the stairs' foot, the 1F gate keeps you there, and
## back out); the power room (its door, the lift panel's handle gives the lift its power back); the records room.
## Every [E] is aimed at like a player would (the ray must reach it). Exit 0 when all of it works; otherwise it prints
## where it got stuck.

const SPEED := 3.0

var world: Node3D
var _bad := 0
var _crossed: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().create_timer(1.5).timeout
	var t: Terminal = world.terminal
	var p: Player = world.player
	var hall := t.service_hall
	t.crossed.connect(func(to_lounge: bool): _crossed.append(to_lounge))
	for zn in t.zones:
		t.set_zone_light(zn, true, true)
	Engine.time_scale = SPEED
	var lift := t.lift
	# (the game scene still sets up the story underneath: its dead lift and its ride hook go)
	lift.ride_hook = Callable()
	lift.set_powered(true)
	# ---- the lift, down
	var far := ServiceHall.FAR
	p.teleport(Transform3D(Basis(Vector3.UP, PI), hall.to_global(far + Vector3(0, 0.05, -4.0))))
	await _settle()
	await _walk(p, [hall.to_global(far + Vector3(-0.5, 0, -1.0))])
	await _use(p, lift.cars[0].call, "lift call (4F)")
	await _until(func(): return lift.doors_open and not lift.busy, 8.0, "lift doors open at 4F")
	var c0: Node3D = lift.cars[0].root
	await _walk(p, [hall.to_global(far + Vector3(0, 0, -0.5)), c0.global_transform * Vector3(0.2, 0, -0.9)])
	_check(lift.is_inside(0), "in the car at 4F")
	await _use(p, lift.cars[0].go, "lift panel (4F)")
	await _until(func(): return lift.at == 1 and lift.doors_open and not lift.busy, 20.0, "lift rode down and opened")
	_check(lift.is_inside(1), "carried into the lounge's car (%s)" % str(p.global_position.snapped(Vector3.ONE * 0.1)))
	_check(_crossed == [true], "crossed down once (%s)" % str(_crossed))
	var l1: Node3D = lift.cars[1].root
	await _walk(p, [l1.global_transform * Vector3(0, 0, 0.6), Vector3(Terminal.HALL_E - 2.5, 0, Terminal.LIFT_Z)])
	_check(p.global_position.x < Terminal.HALL_E - 1.5 and absf(p.global_position.y) < 0.2, "out into the lounge (%s)" % str(p.global_position.snapped(Vector3.ONE * 0.1)))
	# ---- the lift, up
	await _walk(p, [l1.global_transform * Vector3(-0.5, 0, 1.0)])
	await _use(p, lift.cars[1].call, "lift call (1F)")
	await _until(func(): return lift.doors_open and not lift.busy, 8.0, "lift doors open at 1F")
	await _walk(p, [l1.global_transform * Vector3(0, 0, 0.5), l1.global_transform * Vector3(-0.2, 0, -0.9)])
	await _use(p, lift.cars[1].go, "lift panel (1F)")
	await _until(func(): return lift.at == 0 and lift.doors_open and not lift.busy, 20.0, "lift rode up and opened")
	await _walk(p, [c0.global_transform * Vector3(0, 0, 0.6), hall.to_global(far + Vector3(0, 0, -3.0))])
	_check(hall.contains(p.global_position) and absf(hall.to_local(p.global_position).y) < 0.2, "back out in the corridor")
	_check(_crossed == [true, false], "crossed back up (%s)" % str(_crossed))
	# ---- the stairs: barred on every floor (4F: the way down; 1F, from the lounge's side: the way up)
	_check(hall.stair_gates.size() == 6, "six iron gates on the stairs (%d)" % hall.stair_gates.size())
	_check((lift.cars[0].buttons as Dictionary).size() == 5, "five floor buttons in the car")
	var sx := StairCore.DOOR_X
	var west := (StairCore.X0 + StairCore.WELL[0]) * 0.5
	var east := (StairCore.WELL[1] + StairCore.X1) * 0.5
	var land_z := (StairCore.GATE_Z + StairCore.ZS) * 0.5
	# (the stair hall stands in its own frame, set into the corridors by StairCore.XF: st maps its points)
	var st := func(v: Vector3) -> Vector3: return hall.to_global(StairCore.hall_of(v))
	var gap_x := (StairCore.OPEN[0] + StairCore.OPEN[1]) * 0.5          # where W comes through
	p.teleport(Transform3D(Basis(Vector3.UP, PI), hall.to_global(Vector3(-23.65, 0.05, -14.0))))
	await _settle()
	await _walk(p, [hall.to_global(Vector3(-23.65, 0, -11.6)), st.call(Vector3(gap_x, 0, land_z))])
	await _use(p, hall.stair_gates[0].use, "the 4F gate")
	await _try_walk(p, [st.call(Vector3(west, 0, StairCore.LAND_N - 1.5))])
	var q := hall.to_local(p.global_position)
	_check(absf(q.y) < 0.25 and StairCore.local_of(q).z > StairCore.GATE_Z, "the 4F gate keeps you on the landing (at %s)" % str(q.snapped(Vector3.ONE * 0.1)))
	# from the lounge through the stair lobby to the stairs' foot: the gate across the way up
	var lob: Array = t.stairs.twins
	var r0: Node3D = lob[0].root
	var r1: Node3D = lob[1].root
	p.teleport(Transform3D(r1.global_basis, r1.global_transform * Vector3(0.0, 0.05, 1.8)))
	await _settle()
	await _walk(p, [r1.global_transform * Vector3(0.0, 0, 1.2)])
	await _use(p, lob[1].doors.b.use, "the stair lobby's door from the lounge")
	await _wait(0.8)
	await _walk(p, [r1.global_transform * Vector3(0, 0, 0.3), r1.global_transform * Vector3(0.2, 0, -1.6)])
	await _wait(3.0)
	await _use(p, lob[1].doors.a.use, "the stair lobby's door to the stairs")
	await _until(func(): return t.stairs.is_inside(0) and lob[0].doors.a.open, 6.0, "carried to the stairs' copy, its door open")
	await _walk(p, [r0.global_transform * Vector3(0, 0, -StairCore.LD - 0.6), st.call(Vector3(east, 0, land_z))])
	await _use(p, hall.stair_gates[5].use, "the 1F gate")
	await _try_walk(p, [st.call(Vector3(east, 0, StairCore.LAND_N - 1.5))])
	q = hall.to_local(p.global_position)
	_check(absf(q.y - StairCore.BOTTOM) < 0.25 and StairCore.local_of(q).z > StairCore.GATE_Z, "the 1F gate keeps you at the stairs' foot (at %s)" % str(q.snapped(Vector3.ONE * 0.1)))
	await _walk(p, [st.call(Vector3(sx, 0, StairCore.ZS - 0.4))])
	await _wait(2.5)
	await _use(p, lob[0].doors.a.use, "the 1F door into the stair lobby")
	await _wait(0.8)
	await _walk(p, [r0.global_transform * Vector3(0, 0, -StairCore.LD - 0.3), r0.global_transform * Vector3(0.2, 0, -1.0)])
	await _wait(3.0)
	await _use(p, lob[0].doors.b.use, "the stair lobby's far door")
	await _until(func(): return t.stairs.is_inside(1) and lob[1].doors.b.open, 6.0, "carried back to the lounge's copy, its door open")
	await _walk(p, [r1.global_transform * Vector3(0, 0, 0.6), Vector3(Terminal.HALL_E - 2.5, 0, Terminal.STAIR_Z)])
	_check(p.global_position.x < Terminal.HALL_E - 1.5 and absf(p.global_position.y) < 0.2, "back out into the lounge (%s)" % str(p.global_position.snapped(Vector3.ONE * 0.1)))
	_check(_crossed == [true, false, false, true], "crossed into the stairs and back (%s)" % str(_crossed))
	# ---- the power room (PowerRoom): its door opens, and the lift panel's handle gives the lift its power back
	var pr := hall.power_room
	pr.set_on(false, true)
	lift.set_powered(false)
	p.teleport(Transform3D(Basis(), hall.to_global(Vector3(-11.15, 0.05, -14.6))))
	await _settle()
	await _walk(p, [hall.to_global(Vector3(-11.1, 0, PowerRoom.DOOR_Z))])
	await _use(p, pr.door.use, "the power room's door")
	await _wait(1.0)
	_check(pr.door.open, "the power room's door opened")
	await _walk(p, [hall.to_global(Vector3(-9.3, 0, PowerRoom.DOOR_Z + 0.2)), hall.to_global(Vector3(-8.05, 0, PowerRoom.DOOR_Z))])
	_check(PowerRoom.contains_local(hall.to_local(p.global_position)) and hall.contains(p.global_position), "in the power room")
	await _use(p, pr.lever_use, "the lift panel's handle")
	await _wait(0.8)
	_check(pr.on and lift.powered and not lift.locked, "the lift has its power back")
	await _walk(p, [hall.to_global(Vector3(-9.3, 0, PowerRoom.DOOR_Z + 0.2)), hall.to_global(Vector3(-11.1, 0, PowerRoom.DOOR_Z))])
	_check(hall.to_local(p.global_position).x < -10.1, "back out of the power room")
	# ---- the records room at E's end (ArchiveRoom): its door opens, in up the first aisle and across, and out
	var ad: Dictionary = hall.doors_by["자료실"]
	p.teleport(Transform3D(Basis(), hall.to_global(Vector3(ArchiveRoom.DOOR_X, 0.05, -18.5))))
	await _settle()
	await _walk(p, [hall.to_global(Vector3(ArchiveRoom.DOOR_X, 0, -20.6))])
	p.look_at_point((ad.root as Node3D).global_position + Vector3(0, 1.1, 0), 0.05)
	await get_tree().create_timer(0.25).timeout
	_check(p.current_interactable == ad.use, "[E] reaches the records room's door")
	(ad.use as Interactable).interact()
	await _wait(1.0)
	_check(ad.open, "the records room's door opened")
	var a1: float = ArchiveRoom.AISLES[0]
	await _walk(p, [hall.to_global(Vector3(ArchiveRoom.DOOR_X, 0, -22.4)), hall.to_global(Vector3(a1, 0, -24.0)),
		hall.to_global(Vector3(a1, 0, -32.0)), hall.to_global(Vector3(ArchiveRoom.AISLES[2], 0, -32.1))])
	q = hall.to_local(p.global_position)
	_check(ArchiveRoom.contains_local(q) and q.z < -31.5 and hall.contains(p.global_position), "up the records room's first aisle to the back (at %s)" % str(q.snapped(Vector3.ONE * 0.1)))
	await _walk(p, [hall.to_global(Vector3(ArchiveRoom.AISLES[2], 0, -22.4)), hall.to_global(Vector3(ArchiveRoom.DOOR_X, 0, -22.4)),
		hall.to_global(Vector3(ArchiveRoom.DOOR_X, 0, -19.5))])
	q = hall.to_local(p.global_position)
	_check(q.z > -20.0 and absf(q.y) < 0.2, "back out of the records room (at %s)" % str(q.snapped(Vector3.ONE * 0.1)))
	Engine.time_scale = 1.0
	print("[lift] %s" % ("PASS" if _bad == 0 else "FAIL (%d)" % _bad))
	get_tree().quit(0 if _bad == 0 else 1)


func _check(ok: bool, what: String) -> void:
	print("[lift] %s: %s" % [what, "ok" if ok else "FAILED"])
	if not ok:
		_bad += 1


func _settle() -> void:
	await get_tree().create_timer(0.4).timeout


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _until(cond: Callable, limit: float, what: String) -> void:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < limit * 1000.0 / SPEED:
		await get_tree().process_frame
	_check(cond.call(), what)


## Aims at `it` like a player and presses [E]: fails the check if the ray does not reach it (then presses it anyway).
func _use(p: Player, it: Interactable, what: String) -> void:
	p.look_at_point(it.global_position, 0.05)
	await get_tree().create_timer(0.25).timeout
	_check(p.current_interactable == it, "[E] reaches %s" % what)
	it.interact()


## Walks `pts` through the player's own physics; logs where it got stuck.
func _walk(p: Player, pts: Array) -> void:
	p.walk_path(pts, 1.8)
	var dist := 0.0
	var from := p.global_position
	for q: Vector3 in pts:
		dist += Vector2(from.x, from.z).distance_to(Vector2(q.x, q.z))
		from = q
	var limit := (dist / 1.8 + 8.0) * 1000.0 / SPEED
	var t0 := Time.get_ticks_msec()
	while p.walking() and Time.get_ticks_msec() - t0 < limit:
		await get_tree().process_frame
	if p.walking():
		print("[lift] walk stuck at %s" % str(p.global_position.snapped(Vector3.ONE * 0.1)))
		p.teleport(p.global_transform)
		_bad += 1


## Tries to walk `pts` (where something should stop you): gives up after `secs` without counting it a failure.
func _try_walk(p: Player, pts: Array, secs := 4.0) -> void:
	p.walk_path(pts, 1.8)
	var t0 := Time.get_ticks_msec()
	while p.walking() and Time.get_ticks_msec() - t0 < secs * 1000.0 / SPEED:
		await get_tree().process_frame
	p.teleport(p.global_transform)
