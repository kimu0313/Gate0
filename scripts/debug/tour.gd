extends Node
## Debug: `godot --path . -- --tour [outdir]` captures screenshots from fixed viewpoints and quits.

var world: Node
var shots := [
	["office", Vector3(-13.6, 0.05, 5.8), Vector3(-19.5, 1.0, 0.0)],
	["office_door", Vector3(-16.5, 0.05, 1.0), Vector3(-18.2, 1.5, 7.6)],
	["hall_from_office", Vector3(-18.2, 0.05, 9.8), Vector3(0.0, 3.0, 4.0)],
	["lobby", Vector3(-0.4, 0.05, -3.8), Vector3(-0.4, 2.0, 14.0)],
	["hall_fids", Vector3(-2.8, 0.05, 3.2), Vector3(-8.2, 4.5, -2.3)],
	["hall_entrance", Vector3(-3.5, 0.05, 2.0), Vector3(-7.8, 2.0, 14.0)],
	["pa_console", Vector3(0.2, 0.05, 7.1), Vector3(0.2, 1.0, 5.85)],
	["checkin", Vector3(2.6, 0.05, 0.2), Vector3(5.9, 1.3, 4.2)],
	["kiosks_west", Vector3(-2.8, 0.05, 0.6), Vector3(-6.6, 1.3, 4.6)],
	["pillar_sign", Vector3(-4.4, 0.05, 5.8), Vector3(-5.2, 1.85, 7.6)],
	["kiosk_close", Vector3(4.3, 0.05, 2.9), Vector3(5.9, 1.3, 2.4)],
	["fascia_east", Vector3(0.8, 0.05, 1.0), Vector3(4.4, 3.5, 4.4)],
	["escalator_sign", Vector3(-0.8, 0.05, 10.6), Vector3(0.9, 1.2, 12.3)],
	["escalator", Vector3(-2.0, 0.05, 6.5), Vector3(8.0, 2.5, 12.0)],
	["escalator_side", Vector3(7.6, 0.05, 8.6), Vector3(7.6, 1.9, 12.3)],
	["escalator_top", Vector3(9.4, 0.05, 9.2), Vector3(12.2, 4.5, 12.3)],
	["escalator_foot", Vector3(1.4, 0.05, 10.4), Vector3(3.2, 0.4, 12.3)],
	["lounge", Vector3(3.0, 0.05, 3.0), Vector3(14.0, 5.5, 6.0)],
	["strip", Vector3(7.0, 0.05, -3.8), Vector3(-10.0, 2.0, -7.0)],
	["storage", Vector3(13.4, 0.05, -4.0), Vector3(20.0, 1.0, -7.4)],
	["staff_passage", Vector3(-11.2, 0.05, -11.0), Vector3(-11.2, 1.4, -38.0)],
	["baggage", Vector3(-14.0, 0.05, -42.6), Vector3(-28.0, 0.8, -55.0)],
	["baggage_carousels", Vector3(-19.0, 0.05, -41.0), Vector3(-33.0, 1.0, -49.0)],
	["carousel_close", Vector3(-23.6, 0.05, -54.6), Vector3(-25.0, 0.35, -57.2)],
	["belt_far", Vector3(-23.2, 0.05, -63.4), Vector3(-25.5, 0.4, -59.6)],
	["belt_curve", Vector3(-28.0, 0.05, -55.6), Vector3(-31.2, 0.35, -59.6)],
	["carousel_b01", Vector3(-27.5, 0.05, -42.0), Vector3(-29.5, 0.35, -44.6)],
	["carousel_deco", Vector3(-26.0, 0.05, -49.0), Vector3(-29.0, 0.3, -51.4)],
	["pedestal_close", Vector3(-34.95, 0.05, -56.3), Vector3(-33.6, 0.95, -57.4)],
	["walkway_pedestal", Vector3(-0.2, 0.05, -27.8), Vector3(1.2, 0.95, -29.6)],
	["belt_pedestal", Vector3(-34.6, 0.05, -56.2), Vector3(-33.6, 1.0, -57.4)],
	["security", Vector3(1.1, 0.05, -10.5), Vector3(-2.0, 1.0, -20.0)],
	["xray_monitor", Vector3(-2.35, 0.05, -17.2), Vector3(-3.4, 1.2, -18.0)],
	["xray_panel", Vector3(-2.4, 0.05, -15.6), Vector3(-4.2, 1.0, -18.0)],
	["lightbox", Vector3(-6.6, 0.05, -11.2), Vector3(-9.78, 2.2, -11.2)],
	["corridor", Vector3(-1.5, 0.05, -28.4), Vector3(0.0, 1.5, -60.0)],
	["walkway_sign", Vector3(1.0, 0.05, -24.5), Vector3(3.4, 1.6, -31.5)],
	["corridor_windows", Vector3(-4.0, 0.05, -45.0), Vector3(20.0, 3.0, -55.0)],
	["corridor_ads", Vector3(-6.4, 0.05, -38.0), Vector3(-9.78, 2.1, -32.0)],
	["corridor_baggage", Vector3(-2.6, 0.05, -43.0), Vector3(-10.0, 1.6, -49.0)],
	["gates", Vector3(0.0, 0.05, -78.0), Vector3(0.0, 1.8, -100.0)],
	["gate03", Vector3(19.0, 0.05, -80.0), Vector3(26.0, 2.0, -82.0)],
	["gate_podium", Vector3(20.6, 0.05, -77.4), Vector3(23.4, 1.0, -80.2)],
	["fids_close", Vector3(-6.0, 0.05, -1.2), Vector3(-8.2, 4.3, -2.3)],
	["fids_view", Vector3(-1.0, 0.05, 1.0), Vector3(-8.2, 4.5, -2.1)],
	["arr_view", Vector3(1.0, 0.05, 1.0), Vector3(8.2, 4.5, -2.1)],
	["gates_sign", Vector3(0.0, 0.05, -71.5), Vector3(0.0, 3.85, -79.0)],
	["fids_lobby", Vector3(0.0, 0.05, 3.2), Vector3(0.0, 5.0, -2.3)],
	["desk_front", Vector3(0.2, 0.05, 2.6), Vector3(0.2, 0.85, 5.8)],
	["desk_op", Vector3(2.9, 0.05, 8.6), Vector3(0.3, 0.75, 5.9)],
	["hall_corner_w", Vector3(-3.4, 0.05, 2.4), Vector3(-6.4, 1.4, -2.2)],
	["gate_bins", Vector3(14.0, 0.05, -82.0), Vector3(20.0, 0.5, -76.5)],
	["sign_hall_baggage", Vector3(-7.4, 0.05, -1.2), Vector3(-7.4, 3.2, -6.2)],
	["door_staff", Vector3(-4.0, 0.05, 0.9), Vector3(-6.9, 2.0, 0.9)],
	["door_exit", Vector3(-18.0, 0.05, -60.0), Vector3(-18.0, 2.0, -63.8)],
	["door_exit_close", Vector3(-18.0, 0.05, -61.6), Vector3(-18.0, 2.3, -63.8)],
	["exit_emergency", Vector3(-17.0, 0.05, 10.5), Vector3(-17.0, 2.6, 13.66)],
	["door_office", Vector3(-18.2, 0.05, 11.0), Vector3(-18.2, 2.5, 7.8)],
	["door_storage", Vector3(8.5, 0.05, -5.5), Vector3(11.8, 2.4, -5.5)],
	["door_office_angle", Vector3(-13.5, 0.05, 11.5), Vector3(-17.6, 1.6, 7.8)],
	["door_storage_far", Vector3(4.0, 0.05, -4.2), Vector3(11.8, 1.6, -5.0)],
	["door_maint", Vector3(-32.0, 0.05, -50.0), Vector3(-35.8, 2.4, -50.0)],
	["pocket_security", Vector3(4.0, 0.05, -5.5), Vector3(6.0, 1.6, -8.5)],
	["sign_hall_staff", Vector3(-8.5, 0.05, 10.8), Vector3(-13.0, 4.0, 10.8)],
	["sign_baggage_main", Vector3(-25.5, 0.05, -50.5), Vector3(-25.5, 2.1, -55.4)],
	["sign_bag_claim", Vector3(-20.0, 0.05, -37.8), Vector3(-20.0, 3.0, -42.4)],
	["sign_inspection", Vector3(-3.6, 0.05, -9.8), Vector3(-3.6, 3.7, -13.0)],
	["sign_staff_passage", Vector3(-11.05, 0.05, -5.6), Vector3(-11.05, 2.95, -8.3)],
	["security_sign", Vector3(0.0, 0.05, -19.0), Vector3(0.0, 2.85, -26.0)],
	["corridor_sign", Vector3(-3.0, 0.05, -47.5), Vector3(-3.0, 2.9, -54.0)],
	["dep_sign", Vector3(0.6, 0.05, 2.2), Vector3(0.6, 3.15, -5.0)],
	["whiteboard", Vector3(-14.4, 0.05, 2.6), Vector3(-12.42, 1.6, 2.6)],
	["main_power", Vector3(-46.3, 0.05, -50.0), Vector3(-47.78, 1.4, -50.0)],
	["eq_punch", Vector3(-15.0, 0.05, -1.1), Vector3(-15.0, 1.35, -2.3)],
	["eq_breaker", Vector3(-13.3, 0.05, -1.1), Vector3(-13.3, 1.5, -2.3)],
	["eq_office_wall", Vector3(-14.3, 0.05, 1.6), Vector3(-14.3, 1.4, -2.3)],
	["eq_lights", Vector3(-18.5, 0.05, 8.9), Vector3(-19.78, 1.45, 8.9)],
	["eq_lights_gates", Vector3(-11.5, 0.05, -77.4), Vector3(-11.5, 1.45, -76.22)],
	["eq_fax", Vector3(-14.1, 0.05, 6.0), Vector3(-12.9, 0.95, 6.2)],
	["eq_power", Vector3(-46.5, 0.05, -50.0), Vector3(-47.78, 1.4, -50.0), "flashlight"],
	["eq_power_side", Vector3(-46.9, 0.05, -50.9), Vector3(-47.78, 1.35, -49.85), "flashlight"],
	["eq_fax_close", Vector3(-13.65, 0.05, 6.0), Vector3(-12.95, 1.0, 6.2)],
	# z-fighting checks (ceiling edges, lintels, beam crossings, door headers, block ends)
	["fids_bottom", Vector3(-8.2, 0.05, 0.4), Vector3(-8.2, 3.4, -2.3)],
	["fids_bottom_side", Vector3(-5.6, 0.05, -0.2), Vector3(-8.6, 3.5, -2.3)],
	["kiosk_side", Vector3(4.4, 0.05, 3.2), Vector3(5.9, 1.0, 2.5)],
	["kiosk_front", Vector3(4.6, 0.05, 2.5), Vector3(5.9, 1.1, 2.5)],
	["zf_lintel", Vector3(0.0, 0.05, -6.6), Vector3(0.0, 4.25, -8.7)],
	["zf_block_end", Vector3(3.6, 0.05, 10.0), Vector3(6.6, 3.7, 7.3)],
	["zf_office_wall", Vector3(-13.6, 0.05, 12.2), Vector3(-16.0, 3.3, 7.6)],
	["zf_beams", Vector3(1.0, 0.05, -14.6), Vector3(2.0, 4.1, -17.6)],
	["zf_door", Vector3(-18.2, 0.05, 10.2), Vector3(-18.2, 2.5, 7.6)],
	["zf_lounge", Vector3(6.4, 0.05, 6.0), Vector3(12.0, 4.2, 5.0)],
	# closures: the security partition seen from the strip, the staff passage door (`--day 1`)
	["shutter", Vector3(0.0, 0.05, -3.0), Vector3(0.0, 1.8, -8.5)],
	["shutter_passage", Vector3(-7.6, 0.05, -4.6), Vector3(-11.2, 1.4, -8.5)],
	# the evening-shift colleague at their DAY 1 spot in the office (`--day 1`)
	["colleague", Vector3(-14.6, 0.05, 3.6), Vector3(-16.0, 1.45, 1.2)],
	["colleague_wide", Vector3(-13.2, 0.05, 6.6), Vector3(-16.0, 1.0, 1.2)],
	["colleague_face", Vector3(-18.2, 0.05, 1.0), Vector3(-16.0, 1.5, 1.2)],
	# story props (Day1~5 초안)
	["locker04", Vector3(-17.6, 0.05, -0.6), Vector3(-17.59, 1.47, -1.8)],
	["office_pc", Vector3(-17.8, 0.05, 1.8), Vector3(-19.35, 0.95, 1.8)],
	["drawer", Vector3(-17.6, 0.05, 4.9), Vector3(-19.2, 0.45, 4.1)],
	["lostfound", Vector3(14.2, 0.05, -5.4), Vector3(14.1, 0.7, -2.95)],
	["crate", Vector3(17.6, 0.05, -4.4), Vector3(18.6, 0.4, -6.9)],
	["plaque", Vector3(9.4, 0.05, -5.4), Vector3(11.45, 0.9, -7.95)],
	["pa_deck", Vector3(-0.1, 0.05, 6.9), Vector3(-0.42, 1.0, 5.88)],
	["page_p2", Vector3(-18.0, 0.05, 10.4), Vector3(-19.8, 1.45, 9.8)],
	["page_p3", Vector3(-5.6, 0.05, 0.0), Vector3(-6.4, 1.45, -2.3)],
	["page_p9", Vector3(-14.0, 0.05, 5.4), Vector3(-13.0, 0.85, 5.9)],
	# things you press or pick up (checked with --reach-audit)
	["b03_controls", Vector3(-34.5, 0.05, -57.0), Vector3(-33.6, 0.95, -57.4)],
	["maint_keypad", Vector3(-34.5, 0.05, -51.0), Vector3(-35.64, 1.3, -51.6)],
	["log3_chair", Vector3(20.2, 0.05, -93.2), Vector3(20.8, 0.5, -94.8)],
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
		player.toggle_flashlight(1 if s.size() > 3 and s[3] == "flashlight" else 0)   # optional 4th: "flashlight"
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