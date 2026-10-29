extends Node
## Debug: `godot --path . res://scenes/levels/security_baggage_level.tscn -- --level-shots <dir> [--shots a,b] [--settle s] [--bench]`
## (or on the game scene, for the Terminal) captures the level's SHOTS (player views) and SKETCH_SHOTS (shifted-lens views matching the sketches;
## render at the sketch aspect, e.g. --resolution 1920x1258) and quits (same flags as the terminal tour).

var level: Node3D          # SecurityBaggageLevel or Terminal: provides SHOTS / SKETCH_SHOTS
var player: Player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().create_timer(1.5).timeout
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[args.find("--level-shots") + 1] if args.find("--level-shots") + 1 < args.size() else OS.get_user_data_dir() + "/level_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var only := PackedStringArray()
	if args.find("--shots") >= 0 and args.find("--shots") + 1 < args.size():
		only = args[args.find("--shots") + 1].split(",")
	var wait := float(args[args.find("--settle") + 1]) if args.find("--settle") >= 0 else 0.9
	if player == null:
		player = level.get("player")
	if level is Terminal:
		# the terminal's zones start switched off: light them the way the story's night does (prologue 02:17)
		for zn in level.zones:
			level.set_zone_light(zn, true, true)
			level.zones[zn].night_dim = 0.62
		await get_tree().create_timer(1.0).timeout
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	for s in level.SKETCH_SHOTS:
		if not only.is_empty() and not (s[0] in only):
			continue
		var cam := _sketch_camera(s[1], s[2], s[3], s[4])
		await get_tree().create_timer(wait).timeout
		await _capture(out_dir, s[0])
		cam.queue_free()
	player.camera.make_current()
	for s in level.SHOTS:
		if not only.is_empty() and not (s[0] in only):
			continue
		player.teleport(Transform3D(Basis(), s[1]))
		await get_tree().process_frame
		player.look_at_point(s[2], 0.01)
		await get_tree().create_timer(wait).timeout
		await _capture(out_dir, s[0])
	get_tree().quit()


## Level camera looking along -Z turned by `yaw`, with the frustum shifted so the vanishing point of its axis
## lands at `vp` (fractions of the image) and the vertical field of view is `vfov`.
func _sketch_camera(eye: Vector3, yaw: float, vp: Vector2, vfov: float) -> Camera3D:
	var cam := Camera3D.new()
	level.add_child(cam)
	cam.position = eye
	cam.rotation.y = deg_to_rad(yaw)
	var aspect := get_viewport().get_visible_rect().size.aspect()
	cam.projection = Camera3D.PROJECTION_FRUSTUM
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.near = 0.05
	cam.far = 600.0              # the player's far plane: the skyline past the airfield shows
	cam.size = 2.0 * cam.near * tan(deg_to_rad(vfov) * 0.5)
	cam.frustum_offset = Vector2((0.5 - vp.x) * cam.size * aspect, (vp.y - 0.5) * cam.size)
	cam.make_current()
	return cam


func _capture(out_dir: String, shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])
	print("level shot: ", shot_name)
	if OS.get_cmdline_user_args().has("--bench"):
		await _bench(shot_name)


func _bench(shot_name: String) -> void:
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var gpu := 0.0
	var cpu := 0.0
	for i in 60:
		await RenderingServer.frame_post_draw
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
	print("bench %s gpu=%.2fms cpu=%.2fms" % [shot_name, gpu / 60.0, cpu / 60.0])
