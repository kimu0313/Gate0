extends Node
## `res://scenes/game.tscn -- --chapter ch1 --warped-shots <dir> [--shots a,b]` (windowed): applies the warped terminal
## (WarpedTerminal — kept for later; the current chapter 1 does not use it) and puts a free camera at each of
## WarpedTerminal.SHOTS, one screenshot each, then quits. The story does not run.

var world: Node3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[args.find("--warped-shots") + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	var only: PackedStringArray = []
	var si := args.find("--shots")
	if si >= 0 and si + 1 < args.size():
		only = args[si + 1].split(",")
	if not world.director.part is Chapter1:
		print("[warped] run it with --chapter ch1")
		get_tree().quit(1)
		return
	var warp := WarpedTerminal.new()
	warp.name = "Warp"
	world.terminal.add_child(warp)
	warp.apply(world.terminal, world.bridge)
	world.ui.hud.visible = false
	world.player.toggle_flashlight(0)
	var cam := Camera3D.new()
	cam.fov = 70.0
	cam.far = 400.0
	world.add_child(cam)
	cam.current = true
	await get_tree().create_timer(1.0).timeout
	for s: Array in WarpedTerminal.SHOTS:
		if not only.is_empty() and not only.has(s[0]):
			continue
		cam.global_position = s[1]
		var to: Vector3 = s[2]
		cam.look_at(to, Vector3.FORWARD if absf((to - cam.global_position).normalized().y) > 0.98 else Vector3.UP)
		world.player.global_position = cam.global_position - Vector3(0, 1.6, 0)   # occlusion and reverb follow the view
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, s[0]])
		print("[warped] shot ", s[0])
	get_tree().quit(0)
