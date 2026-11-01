extends Node
## Debug: `godot --path . res://scenes/game.tscn -- --skip-boot --lounge` drops you in the main lounge (the east end
## of its south aisle, looking west like SKETCH_SHOTS ref_lounge) with the night lighting on, free to walk; no story
## runs. `--airhall` instead drops you on the aircraft hall's deck by its escalator's foot (SKETCH_SHOTS air_ref);
## `--cabinway` on the lounge's south aisle before the door of the cabin that leads there (CabinWay).

var world: Node3D


func _ready() -> void:
	var t: Terminal = world.terminal
	for zn in t.zones:
		t.set_zone_light(zn, true, true)
		t.zones[zn].night_dim = 0.62          # the story's night (prologue 02:17)
	var args := OS.get_cmdline_user_args()
	if args.has("--airhall"):
		world.player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(160.0)), t.spot("airhall_start")))
	elif args.has("--cabinway"):
		world.player.teleport(Transform3D(Basis(Vector3.UP, PI / 2), t.spot("cabinway_front")))
	else:
		world.player.teleport(Transform3D(Basis(Vector3.UP, PI / 2), t.spot("lounge_start")))
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
