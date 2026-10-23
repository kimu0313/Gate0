extends Node
## Debug: `godot --path . res://scenes/levels/security_baggage_level.tscn -- --walk-test` sweeps the player
## capsule along the level's main routes (CharacterBody3D.test_move every 10 cm) and quits:
## exit 0 = every route is walkable, 1 = blocked (the first blocked point of each route is printed).

var level: SecurityBaggageLevel

## [route name, waypoints on the floor (x, z)]
const ROUTES := [
	["spawn into the lanes", [Vector2(0, 1.0), Vector2(1.9, -3.5)]],
	["lane 1 through the metal detector", [Vector2(-0.65, -2.0), Vector2(-0.65, -10.6)]],
	["lane 2 through the metal detector", [Vector2(3.75, -2.0), Vector2(3.75, -10.6)]],
	["behind the partition", [Vector2(3.75, -10.6), Vector2(3.75, -11.6), Vector2(6.0, -12.5), Vector2(9.5, -15.0)]],
	["to the gate lounge (beside the walkway)", [Vector2(-0.65, -10.6), Vector2(-1.5, -14.0), Vector2(-1.0, -39.0), Vector2(-3.4, -40.3)]],
	["on the walkway", [Vector2(1.9, -15.4), Vector2(1.9, -38.6)]],
	["connector to baggage claim", [Vector2(0, 1.5), Vector2(11.0, 1.4), Vector2(17.0, 1.4), Vector2(24.5, -1.0)]],
	["baggage hall to the exit door", [Vector2(24.5, -1.0), Vector2(25.0, -4.0), Vector2(25.0, -35.2)]],
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().physics_frame
	await get_tree().physics_frame
	var body: CharacterBody3D = level.player
	var ok := true
	for r in ROUTES:
		var pts: Array = r[1]
		var blocked := ""
		for i in pts.size() - 1:
			var a := Vector3(pts[i].x, 0.15, pts[i].y)
			var b := Vector3(pts[i + 1].x, 0.15, pts[i + 1].y)
			var steps := int(ceil(a.distance_to(b) / 0.1))
			for s in steps:
				var from := Transform3D(Basis(), a.lerp(b, float(s) / steps))
				if body.test_move(from, (b - a) / steps):
					blocked = "blocked at (%.1f, %.1f)" % [from.origin.x, from.origin.z]
					break
			if blocked != "":
				break
		ok = ok and blocked == ""
		print("walk %-36s %s" % [r[0], blocked if blocked != "" else "ok"])
	print("WALK TEST ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
