extends Node
## Debug: `godot --headless --path . res://scenes/game.tscn -- --day 5 --skip-boot --reach-audit` checks that every
## Interactable can be aimed at with [E] the way Player._update_interact does it: from standing spots around it
## (eye height, 0.6–1.6 m away, where the player's capsule fits) a ray with the player's mask must hit the
## Interactable itself, not a collider in front of it. Prints the ones no spot reaches and what blocked them.
## Exit 0 = all reachable, 1 = some are not.

var world: Node


func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var p: Player = world.player
	var space := p.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	var bad := 0
	var total := 0
	for it: Interactable in _interactables(world):
		if not it.is_visible_in_tree() or it.collision_layer == 0:
			continue   # switched off on purpose until the story turns it on (e.g. the jet bridge doors)
		total += 1
		var c: Vector3 = it.global_position
		var floor_y := _floor_below(space, c)
		var reached := false
		var blockers := {}
		for dist: float in [0.6, 0.9, 1.2, 1.6]:
			for k in 16:
				var dir := Vector3(cos(k * TAU / 16.0), 0.0, sin(k * TAU / 16.0))
				var stand := Vector3(c.x, floor_y, c.z) + dir * dist
				if not _fits(space, cap, stand, p):
					continue
				var eye := stand + Vector3(0, Player.EYE_HEIGHT, 0)
				if eye.distance_to(c) > Player.INTERACT_RANGE - 0.05:
					continue
				var to := eye + (c - eye).normalized() * Player.INTERACT_RANGE
				var q := PhysicsRayQueryParameters3D.create(eye, to, Geo.LAYER_WORLD | Geo.LAYER_INTERACT)
				q.exclude = [p.get_rid()]
				var hit := space.intersect_ray(q)
				if hit and hit.collider == it:
					reached = true
					break
				if hit:
					blockers[_name(hit.collider)] = true
			if reached:
				break
		if not reached:
			bad += 1
			print("[reach] UNREACHABLE  %-28s at %s  blocked by: %s" % [it.prompt, c.snapped(Vector3.ONE * 0.01), ", ".join(blockers.keys())])
	print("[reach] %d / %d interactables reachable" % [total - bad, total])
	get_tree().quit(0 if bad == 0 else 1)


func _interactables(n: Node) -> Array:
	var out := []
	for ch in n.get_children():
		if ch is Interactable:
			out.append(ch)
		out += _interactables(ch)
	return out


func _floor_below(space: PhysicsDirectSpaceState3D, c: Vector3) -> float:
	var q := PhysicsRayQueryParameters3D.create(c + Vector3(0, 0.05, 0), c - Vector3(0, 6.0, 0), Geo.LAYER_WORLD)
	var hit := space.intersect_ray(q)
	return hit.position.y if hit else 0.0


func _fits(space: PhysicsDirectSpaceState3D, cap: CapsuleShape3D, stand: Vector3, p: Player) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis(), stand + Vector3(0, 0.9, 0))
	q.collision_mask = Geo.LAYER_WORLD
	q.exclude = [p.get_rid()]
	return space.intersect_shape(q, 1).is_empty()


func _name(o: Object) -> String:
	if o is Interactable:
		return "Interactable(%s)" % (o as Interactable).prompt
	if o is CollisionObject3D:
		var n := o as CollisionObject3D
		var sizes := []
		for ch in n.get_children():
			if ch is CollisionShape3D and (ch as CollisionShape3D).shape is BoxShape3D:
				sizes.append(((ch as CollisionShape3D).shape as BoxShape3D).size.snapped(Vector3.ONE * 0.01))
		return "%s/%s @%s box %s" % [n.get_parent().name, n.name, n.global_position.snapped(Vector3.ONE * 0.01), sizes]
	return str(o)
