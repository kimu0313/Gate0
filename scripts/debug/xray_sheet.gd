extends Node
## Debug: `res://scenes/game.tscn -- --xray-sheet <out dir>` (windowed) renders every X-ray monitor state the
## game uses (idle, bag, mid-scan, your bag, heart, figure staring) into PNGs, then a shot of the real monitor at
## security showing a scanned bag, and quits.

var world: Node

const STATES := [["idle", "", 1.0, 0.0], ["bag", "bag", 1.0, 0.0], ["scanning", "bag", 0.55, 0.0], ["mybag", "mybag", 1.0, 0.0],
	["heart", "heart", 1.0, 0.0], ["figure", "figure", 1.0, 1.0]]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--xray-sheet")
	var out: String = args[i + 1]
	DirAccess.make_dir_recursive_absolute(out)
	for st in STATES:
		var vp := SubViewport.new()
		vp.size = Vector2i(640, 480)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var s := XrayScreen.new()
		s.size = Vector2(640, 480)
		vp.add_child(s)
		s.content = st[1]
		s.scan_progress = st[2]
		s.stare = st[3]
		for f in 4:
			await get_tree().process_frame
		vp.get_texture().get_image().save_png(out.path_join(st[0] + ".png"))
		vp.queue_free()
	# the real monitor at the security lane (no HUD, lights on, the start-up fade lifted)
	world.ui.fade_to(0.0, 0.01)
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	world.terminal.set_zone_light("security", true, true)
	var xr = world.terminal.facility("xray")
	xr.screen.content = "bag"
	xr.screen.scan_progress = 1.0
	world.player.teleport(Transform3D(Basis(), Vector3(-2.35, 0.05, -17.2)))
	await get_tree().process_frame
	world.player.look_at_point(Vector3(-3.4, 1.2, -18.0), 0.01)
	await get_tree().create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("ingame.png"))
	print("XRAY SHEET done")
	get_tree().quit(0)
