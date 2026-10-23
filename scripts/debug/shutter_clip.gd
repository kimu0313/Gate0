extends Node
## Debug: `-- --shutter-clip <dir> <shutter | belt> <feet x,y,z> <look x,y,z>` on the game scene: stands at `feet`
## looking at `look`, opens the named Terminal shutter (or starts the B-03 belt) and saves the frames (frame_000.png …, 15 per second of
## game time) for a before/after GIF, then quits. Use with --fixed-fps 30 so the timing is exact.

var world: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shutter-clip")
	var out: String = args[i + 1]
	var shutter_name: String = args[i + 2]
	var feet := _vec(args[i + 3])
	var look := _vec(args[i + 4])
	DirAccess.make_dir_recursive_absolute(out)
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var p: Player = world.player
	p.teleport(Transform3D(Basis(), feet))
	await get_tree().physics_frame
	p.look_at_point(look, 0.01)
	await get_tree().create_timer(2.0).timeout
	var s = world.terminal.shutters.get(shutter_name)
	var frames := 0
	for k in 75:
		if k == 10:
			if s:
				s.open()
			else:
				world.terminal.facility("baggage").press_start()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/frame_%03d.png" % [out, frames])
		frames += 1
		await get_tree().process_frame
	print("shutter clip: %d frames" % frames)
	get_tree().quit()


func _vec(t: String) -> Vector3:
	var v := t.split(",")
	return Vector3(float(v[0]), float(v[1]), float(v[2]))
