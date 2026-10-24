extends Node
## Debug: `-- --audio-walk` on the game scene (with Godot's --write-movie for a capture): the player walks a fixed
## route at walking pace (lobby → security → corridor → baggage claim) with the shift ambience on, the moving walkway
## and the B-03 carousel running and the security partition opening in front of them, then quits. No director, no HUD.

var world: Node

const ROUTE := ["entrance_in", "hall_s", "hall_c", "hall_w", "hall_n", "strip_c", "sec_in", "sec_mid", "sec_out",
		"cor_s", "cor_bag", "bag_e", "bag_mid"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var t: Terminal = world.terminal
	var p: Player = world.player
	p.controls_enabled = true
	for zn in t.zones:
		t.set_zone_light(zn, true, true)
	for s in t.shutters.values():
		s.open(true)
	t.shutters.security.close(true)
	Snd.set_ambience("amb_night_loop", -2.0, 0.5)
	Snd.set_scatter(true)
	Snd.set_beds(true)
	Snd._scatter_t = 6.0
	t.facility("walkway").press_start()
	t.facility("baggage").press_start()
	var start: Vector3 = Terminal.NAV[ROUTE[0]][0]
	p.teleport(Transform3D(Basis(), start + Vector3(0, 0.05, 0)))
	await get_tree().physics_frame
	Events.zone_entered.emit(t.zone_at(start))
	await get_tree().create_timer(2.5).timeout
	var opened := false
	for k in range(1, ROUTE.size()):
		var goal: Vector3 = Terminal.NAV[ROUTE[k]][0]
		while true:
			var here := p.global_position
			if not opened and ROUTE[k] == "sec_in" and here.distance_to(goal) < 6.5:
				opened = true
				Input.action_release("move_forward")
				await get_tree().create_timer(0.6).timeout
				t.shutters.security.open()
				await get_tree().create_timer(2.6).timeout
			var flat := Vector2(goal.x - here.x, goal.z - here.z)
			if flat.length() < 0.7:
				break
			p.look_at_point(Vector3(goal.x, here.y + 1.5, goal.z), 0.25)
			Input.action_press("move_forward")
			await get_tree().physics_frame
	Input.action_release("move_forward")
	p.look_at_point(t.facility("baggage").global_position + Vector3(0, 0.6, 0), 0.8)
	await get_tree().create_timer(5.0).timeout
	print("[audio-walk] done")
	get_tree().quit()
