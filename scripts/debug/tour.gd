extends Node
## Debug: `godot --path . -- --tour [outdir]` captures screenshots from fixed viewpoints and quits.

var world: Node
var shots := [
	["office", Vector3(-28.0, 0.05, 2.5), Vector3(-33.5, 1.0, -1.0)],
	["office_door", Vector3(-30.5, 0.05, -2.0), Vector3(-22.0, 1.5, 0.0)],
	["hall_from_office", Vector3(-19.0, 0.05, 2.0), Vector3(0.0, 3.0, -6.0)],
	["hall_fids", Vector3(-8.0, 0.05, 5.0), Vector3(-11.0, 4.5, -13.5)],
	["hall_entrance", Vector3(0.0, 0.05, -6.0), Vector3(0.0, 2.5, 14.0)],
	["pa_console", Vector3(0.0, 0.05, 8.2), Vector3(0.0, 1.0, 6.5)],
	["baggage", Vector3(25.0, 0.05, -1.0), Vector3(36.0, 0.5, 2.5)],
	["security", Vector3(0.0, 0.05, -15.5), Vector3(-5.0, 1.0, -21.0)],
	["xray_monitor", Vector3(-2.3, 0.05, -20.4), Vector3(-3.6, 1.2, -21.0)],
	["corridor", Vector3(1.5, 0.05, -29.5), Vector3(0.0, 1.5, -60.0)],
	["corridor_windows", Vector3(-1.0, 0.05, -45.0), Vector3(20.0, 3.0, -55.0)],
	["gates", Vector3(0.0, 0.05, -78.0), Vector3(0.0, 1.8, -100.0)],
	["gate03", Vector3(19.0, 0.05, -80.0), Vector3(26.0, 2.0, -82.0)],
]
var out_dir := ""
var _i := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var idx := args.find("--tour")
	out_dir = args[idx + 1] if idx >= 0 and idx + 1 < args.size() else OS.get_user_data_dir() + "/tour"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().create_timer(1.5).timeout
	_run()


func _run() -> void:
	var player: Player = world.player
	var terminal: Terminal = world.terminal
	for zn in terminal.zones.keys():
		terminal.set_zone_light(zn, true, true)
	for s in shots:
		player.teleport(Transform3D(Basis(), s[1]))
		await get_tree().process_frame
		player.look_at_point(s[2], 0.01)
		await get_tree().create_timer(0.9).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s_%s.png" % [out_dir, Game.phase, s[0]])
		print("tour shot: ", s[0])
	get_tree().quit()
