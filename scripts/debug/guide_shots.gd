extends Node
## Debug: `godot --path . res://scenes/game.tscn -- --skip-boot --guide-shots <dir>` (windowed) opens the guidelines
## folder (GameUI.open_guide → GuideView) in Korean, English and Japanese and saves guide_ko/en/ja.png, then quits.

var world: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var out: String = args[args.find("--guide-shots") + 1]
	DirAccess.make_dir_recursive_absolute(out)
	var keep := TranslationServer.get_locale()
	await get_tree().create_timer(1.5).timeout
	for lang in ["ko", "en", "ja"]:
		TranslationServer.set_locale(lang)
		world.ui.open_guide()
		await get_tree().create_timer(0.9).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("guide_%s.png" % lang))
		print("guide shot: ", lang)
		world.ui.close_guide()
		await get_tree().create_timer(0.4).timeout
	TranslationServer.set_locale(keep)
	get_tree().quit()
