extends Node
## Debug: `godot --headless --path . res://scenes/game.tscn -- --day 2 --skip-boot --shovetest` stands the player in
## the colleague's way twice — dead centre on open floor, then in the office doorway — and checks that they walk
## through without stopping and push the player out of their path. Exit 0 = pass, 1 = fail.

var world: Node


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var d: ShiftDirector = world.director
	var p: Player = world.player
	var t: Terminal = world.terminal
	p.controls_enabled = true
	p.cutscene = false
	var n := d.npc
	if n == null or not is_instance_valid(n):
		n = StaffNpc.create(t, Vector3.ZERO)
		n.director = d
		n.player = p
	n.beckon = false
	var ok := true
	# 1) open hall floor, standing dead centre on their line, facing them
	var a := Vector3(-4.0, 0.05, 9.0)
	var b := Vector3(4.0, 0.05, 9.0)
	ok = await _case("open", n, p, a, [b], Vector3(0.0, 0.05, 9.0), a) and ok
	# 2) the office doorway, on their way out of the office
	t.doors.office.open()
	await get_tree().create_timer(1.2).timeout
	ok = await _case("doorway", n, p, t.spot("office_arrive"), [t.spot("office_doorway"), t.spot("office_door_front"),
		t.spot("reader_stand")], t.spot("office_doorway"), t.spot("office_arrive")) and ok
	print("[shovetest] %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


func _case(label: String, n: StaffNpc, p: Player, start: Vector3, route: Array, stand: Vector3, look: Vector3) -> bool:
	n.global_position = start
	n.rotation.y = StaffNpc.yaw_for(route[0] - start)
	p.teleport(Transform3D(Basis(), stand))
	p.set_look(StaffNpc.yaw_for(look - stand))
	await get_tree().create_timer(0.3).timeout
	var length := start.distance_to(route[0])
	for i in range(1, route.size()):
		length += (route[i - 1] as Vector3).distance_to(route[i])
	var expect := length / StaffNpc.WALK_SPEED
	var t0 := Time.get_ticks_msec()
	var closest := 99.0
	n.walk(route)
	while n.walking and (Time.get_ticks_msec() - t0) < (expect + 6.0) * 1000.0:
		await get_tree().physics_frame
		var rel := p.global_position - n.global_position
		closest = minf(closest, Vector2(rel.x, rel.z).length())
	var took := (Time.get_ticks_msec() - t0) / 1000.0
	var moved := Vector2(p.global_position.x - stand.x, p.global_position.z - stand.z).length()
	var pass_case := not n.walking and took < expect + 1.0 and moved > 0.3
	print("[shovetest] %-8s took %.2fs (free walk %.2fs)  player moved %.2fm  closest %.2fm  %s" % [
		label, took, expect, moved, closest, "ok" if pass_case else "WRONG"])
	return pass_case
