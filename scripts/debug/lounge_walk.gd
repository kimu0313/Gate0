extends Node
## Debug: `godot --path . res://scenes/game.tscn -- --skip-boot --lounge` drops you in the main lounge (the east end
## of its south aisle, looking west like SKETCH_SHOTS ref_lounge) with the night lighting on, free to walk; no story
## runs. `--airhall` instead drops you on the aircraft hall's deck by its escalator's foot (SKETCH_SHOTS air_ref);
## `--cabinway` on the lounge's south aisle before the door of the cabin that leads there (CabinWay). `--office` puts you
## where the prologue starts, in the security office, only its lights on, its doors shut (walk the office only);
## `--maze` just outside its west door (the key card door) in the service corridors round it (ServiceHall), the office
## lit inside its windows (their doors are locked; the lift at the far end and the stairs at the north end go down to
## the lounge, which lights up when you get there).

var world: Node3D


func _ready() -> void:
	var t: Terminal = world.terminal
	var args := OS.get_cmdline_user_args()
	if args.has("--office") or args.has("--maze"):
		for zn in t.zones:
			t.set_zone_light(zn, zn == "secoffice", true)
		if args.has("--maze"):
			var hall := t.service_hall
			(hall.entry.leaf as Node3D).visible = true          # the office's key card door (west), shut behind you
			(hall.entry.leaf as Node3D).rotation.y = 0.0
			(hall.entry.block as StaticBody3D).collision_layer = Geo.LAYER_WORLD
			world.player.teleport(Transform3D(Basis(), hall.to_global(Vector3(-23.65, 0.05, Terminal.SEC_ENTRY_Z - 0.4))))
			world.player.zone_override = "servicehall"
			t.crossed.connect(func(to_lounge: bool):
				for zn: String in ["hall", "shops", "airhall"]:
					t.set_zone_light(zn, to_lounge, true)
					t.zones[zn].night_dim = Chapter1.HUB_DIM.get(zn, 0.62)
				t.service_hall.zone.set_on(not to_lounge, true)
				t.set_zone_light("secoffice", not to_lounge, true))
		else:
			world.player.teleport(Transform3D(Basis(), Prologue.START))
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return
	for zn in t.zones:
		t.set_zone_light(zn, true, true)
		t.zones[zn].night_dim = Chapter1.HUB_DIM.get(zn, 0.62)   # the story's night (ch1's, prologue 02:17)
	if args.has("--airhall"):
		world.player.teleport(Transform3D(Basis(Vector3.UP, deg_to_rad(160.0)), t.spot("airhall_start")))
	elif args.has("--cabinway"):
		world.player.teleport(Transform3D(Basis(Vector3.UP, PI / 2), t.spot("cabinway_front")))
	else:
		world.player.teleport(Transform3D(Basis(Vector3.UP, PI / 2), t.spot("lounge_start")))
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
