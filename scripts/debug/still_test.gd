extends Node
## Debug: `godot --headless --path . res://scenes/game.tscn -- --day 1 --skip-boot --stilltest` plays the 03:00
## broadcast (수칙 p.9 ③) three times — standing still, only turning the view, then one short step (W held 0.25 s)
## — and checks that only the step is a violation. Exit 0 = pass, 1 = fail.

var world: Node


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var d: ShiftDirector = world.director
	var p: Player = world.player
	p.controls_enabled = true
	p.cutscene = false
	var want := {"still": false, "look": false, "step": true}
	var ok := true
	for mode in ["still", "look", "step"]:
		var before := int(Game.stats.get("violations", 0))
		_act(p, mode)
		await d.ev_regular_broadcast(false, false)
		var broke := int(Game.stats.get("violations", 0)) > before
		var pass_mode: bool = broke == want[mode]
		ok = ok and pass_mode
		print("[stilltest] %-5s violation=%s  %s" % [mode, broke, "ok" if pass_mode else "WRONG"])
		await get_tree().create_timer(1.0).timeout
	print("[stilltest] %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)


## What the player does a few seconds into the broadcast.
func _act(p: Player, mode: String) -> void:
	await get_tree().create_timer(4.0).timeout
	match mode:
		"look":
			for i in 90:
				p.set_look(p.rotation.y + 0.04, sin(i * 0.1) * 0.4)
				await get_tree().physics_frame
		"step":
			Input.action_press("move_forward")
			await get_tree().create_timer(0.25).timeout
			Input.action_release("move_forward")
