extends Node
## Debug: `godot --path . res://scenes/game.tscn -- --skip-boot --lounge` drops you in the main lounge (the east end
## of its south aisle, looking west like SKETCH_SHOTS ref_lounge) with the night lighting on, free to walk; no story
## runs.

var world: Node3D


func _ready() -> void:
	var t: Terminal = world.terminal
	for zn in t.zones:
		t.set_zone_light(zn, true, true)
		t.zones[zn].night_dim = 0.62          # the story's night (prologue 02:17)
	world.player.teleport(Transform3D(Basis(Vector3.UP, PI / 2), t.spot("lounge_start")))
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Snd.set_music("", 1.0)
