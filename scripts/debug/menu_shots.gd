extends Node
## `-- --skip-boot --menu-shots <dir>` on the menu scene (windowed): screenshots of the title opening (SCENE 05)
## at fixed moments — black with the cart, the PA line, the title over the gate, the menu — then quits.

const AT := [[3.0, "t1_black"], [7.0, "t2"], [9.0, "t3"], [11.0, "t4"], [13.0, "t5"], [15.5, "t6"], [18.0, "t7"], [23.0, "t8_menu"]]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var dir := args[args.find("--menu-shots") + 1]
	DirAccess.make_dir_recursive_absolute(dir)
	var t0 := Time.get_ticks_msec()
	Snd.pa_started.connect(func(_t): print("[menu] PA started at %.1f" % ((Time.get_ticks_msec() - t0) / 1000.0)))
	Events.subtitle.connect(func(_s, txt, _d): print("[menu] subtitle at %.1f: %s" % [(Time.get_ticks_msec() - t0) / 1000.0, txt]))
	for s in AT:
		while (Time.get_ticks_msec() - t0) / 1000.0 < float(s[0]):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, s[1]])
		print("[menu] shot ", s[1])
	get_tree().quit()
