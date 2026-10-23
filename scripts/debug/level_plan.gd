extends Node
## Debug: `-- --level-plan <png> [--plan-rect x0,z0,x1,z1] [--plan-cut y] [--plan-bright]` on a level or game scene: an orthographic
## top-down plan (everything above the cut height hidden, so ceilings drop out and walls read as their tops) for the
## level design log, plus a three-quarter overview next to it (<png>_overview.png). Quits when done.

var level: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var out: String = args[args.find("--level-plan") + 1]
	var r := PackedFloat64Array([-13.0, -47.0, 33.0, 5.0])
	if args.find("--plan-rect") >= 0:
		r = PackedFloat64Array(Array(args[args.find("--plan-rect") + 1].split(",")).map(func(v): return float(v)))
	var cut := float(args[args.find("--plan-cut") + 1]) if args.find("--plan-cut") >= 0 else 2.4
	await get_tree().create_timer(1.5).timeout
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	if args.has("--plan-bright"):
		# night scenes: a soft sun from straight above so the plan reads (the overview keeps it too)
		var sun := DirectionalLight3D.new()
		level.add_child(sun)
		sun.rotation = Vector3(-PI / 2 + 0.25, 0.3, 0)
		sun.light_energy = 0.9
		sun.shadow_enabled = true
	# drop everything above the cut (ceilings, beams, fixtures, hanging signs): walls read as their tops
	for n in level.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if (mi.global_transform * mi.get_aabb()).position.y > cut:
			mi.visible = false
	var cam := Camera3D.new()
	level.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = r[3] - r[1]
	cam.near = 1.0
	cam.far = 80.0
	cam.position = Vector3((r[0] + r[2]) * 0.5, 40.0, (r[1] + r[3]) * 0.5)
	cam.rotation = Vector3(-PI / 2, 0, 0)     # looking down, north (-Z) at the top of the image
	cam.make_current()
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("level plan: ", out)
	# three-quarter overview from above the south-west corner
	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 40.0
	cam.near = 0.05
	cam.far = 300.0
	var centre := Vector3((r[0] + r[2]) * 0.5, 0, (r[1] + r[3]) * 0.5)
	cam.position = centre + Vector3(-34, 58, 42)
	cam.look_at(centre + Vector3(0, 0, -2), Vector3.UP)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.get_basename() + "_overview.png")
	print("level overview: ", out.get_basename() + "_overview.png")
	get_tree().quit()
