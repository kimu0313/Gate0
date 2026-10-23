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
	["fids_close", Vector3(-11.0, 0.05, -8.0), Vector3(-11.0, 4.3, -13.8)],
	["whiteboard", Vector3(-31.8, 0.05, -3.0), Vector3(-33.78, 1.6, -3.0)],
	["lightbox", Vector3(-8.0, 0.05, -17.5), Vector3(-11.78, 2.2, -17.5)],
	["walkway_sign", Vector3(-2.8, 0.05, -24.0), Vector3(-2.8, 2.6, -29.5)],
	["corridor_ads", Vector3(-2.0, 0.05, -40.0), Vector3(-4.78, 2.1, -46.0)],
	["main_power", Vector3(55.5, 0.05, 9.0), Vector3(57.78, 1.4, 9.0)],
	["belt_pedestal", Vector3(26.2, 0.05, -1.6), Vector3(27.0, 1.0, -1.6)],
	["xray_panel", Vector3(-2.3, 0.05, -18.6), Vector3(-2.0, 1.0, -21.0)],
	["checkin", Vector3(-6.5, 0.05, 7.5), Vector3(-10.5, 1.0, 1.8)],
	["gate_podium", Vector3(20.6, 0.05, -77.4), Vector3(23.4, 1.0, -80.2)],
	["shutter", Vector3(15.5, 0.05, 4.5), Vector3(22.0, 2.6, 0.0)],
	# the evening-shift colleague at their DAY 1 spot outside the office door (`--day 1`)
	["colleague", Vector3(-17.6, 0.05, 3.3), Vector3(-19.4, 1.45, 2.6)],
	["colleague_wide", Vector3(-12.5, 0.05, 6.0), Vector3(-19.4, 1.0, 2.6)],
	["colleague_face", Vector3(-21.2, 0.05, 3.1), Vector3(-19.4, 1.5, 2.6)],
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
	# `--shots a,b` captures only those viewpoints; `--lights-off` keeps the zones dark
	var args := OS.get_cmdline_user_args()
	var only := PackedStringArray()
	if args.find("--shots") >= 0 and args.find("--shots") + 1 < args.size():
		only = args[args.find("--shots") + 1].split(",")
	if args.has("--no-hud"):
		world.ui.hud.visible = false
	if args.has("--lights-off"):
		for zn in terminal.zones.keys():
			terminal.set_zone_light(zn, false, true)
	# `--settle s`: seconds to wait per viewpoint (GI needs longer to converge than the default)
	var wait := float(args[args.find("--settle") + 1]) if args.find("--settle") >= 0 else 0.9
	await get_tree().create_timer(wait).timeout
	for s in shots:
		if not only.is_empty() and not (s[0] in only):
			continue
		player.teleport(Transform3D(Basis(), s[1]))
		await get_tree().process_frame
		player.look_at_point(s[2], 0.01)
		await get_tree().create_timer(wait).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s_%s.png" % [out_dir, Game.phase, s[0]])
		print("tour shot: ", s[0])
		if args.has("--bench"):
			await _bench(s[0])
		if args.has("--ablate"):
			await _ablate(s[0])
	get_tree().quit()


## `--ablate`: GPU cost of each rendering feature, measured by switching it off and back on right
## away (3 rounds, mean of full − off), so a GPU shared with other work skews both sides alike.
func _ablate(shot_name: String) -> void:
	var env: Environment = world.atmosphere.env
	for zn in world.terminal.zones:
		world.terminal.zones[zn].set_process(false)   # keep LightZone from re-showing lights
	var feats := {
		"sdfgi": func(on: bool): env.sdfgi_enabled = on and Atmosphere.gi_enabled,
		"ssil": func(on: bool): env.ssil_enabled = on,
		"ssr": func(on: bool): env.ssr_enabled = on,
		"ssao": func(on: bool): env.ssao_enabled = on,
		"vol fog": func(on: bool): env.volumetric_fog_enabled = on,
		"glow": func(on: bool): env.glow_enabled = on,
		"area lights": func(on: bool): _show_lights(func(l): return l is AreaLight3D, on),
		"omni lights": func(on: bool): _show_lights(func(l): return l is OmniLight3D, on),
	}
	var cost := {}
	for r in 3:
		for k in feats:
			var full := await _gpu_ms(30)
			(feats[k] as Callable).call(false)
			var off := await _gpu_ms(30)
			(feats[k] as Callable).call(true)
			cost[k] = cost.get(k, 0.0) + (full - off) / 3.0
	for k in feats:
		print("ablate %s %-12s %+.2fms" % [shot_name, k, cost[k]])


func _show_lights(pred: Callable, on: bool) -> void:
	for zn in world.terminal.zones:
		for l in (world.terminal.zones[zn] as LightZone).lights:
			if pred.call(l):
				l.visible = on


func _gpu_ms(frames: int) -> float:
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for i in 8:
		await RenderingServer.frame_post_draw
	var gpu := 0.0
	for i in frames:
		await RenderingServer.frame_post_draw
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	return gpu / frames


## `--bench`: average GPU / CPU render time of the main viewport over 60 frames at this viewpoint.
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