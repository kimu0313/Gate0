extends Node
## Debug: `godot --path . res://scenes/game.tscn -- --chapter ch1 --skip-boot --corridor-shots <dir>` plays the service
## corridor's red-ball beat (ServiceHall: open_locker, ball_out, ball_away, appear, vanish) in front of a fixed camera
## and saves a frame every 0.2 s (NNN.png), then quits. Windowed; add `--fixed-fps 30` when the GPU is shared.

var world: Node3D
var _filming := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[args.find("--corridor-shots") + 1] if args.find("--corridor-shots") + 1 < args.size() else OS.get_user_data_dir() + "/corridor_shots"
	DirAccess.make_dir_recursive_absolute(out_dir)
	await get_tree().create_timer(1.0).timeout
	var hall := world.find_child("ServiceHall", true, false) as ServiceHall
	hall.zone.set_on(true, true)
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var cam := Camera3D.new()
	cam.fov = 68.0
	hall.add_child(cam)
	cam.position = Vector3(-0.9, 1.6, 9.0)
	cam.look_at(hall.to_global(Vector3(0.9, 0.55, 17.0)))
	cam.make_current()
	await get_tree().create_timer(1.5).timeout
	_film(out_dir)
	await hall.open_locker()
	await hall.ball_out()
	await get_tree().create_timer(0.6).timeout
	await hall.ball_away()
	await get_tree().create_timer(0.8).timeout
	await hall.appear()
	await get_tree().create_timer(1.0).timeout
	await hall.vanish()
	await get_tree().create_timer(0.6).timeout
	_filming = false
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()


func _film(out_dir: String) -> void:
	var i := 0
	while _filming:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%03d.png" % [out_dir, i])
		i += 1
		await get_tree().create_timer(0.2).timeout
