class_name TearStalker
extends Node3D
## What goes round baggage claim: never seen, only heard. The belts stop, the hall goes quiet, and the sound of a tag
## being torn comes closer along a route, then goes. Pressed against one of the big pillars (or with one between you
## and it) you are safe; out in the open when it comes within SIGHT and it has you (`seen`).

signal seen

const SIGHT := 7.0            # how near before it can have you
const HUG := 1.7              # this close to a pillar's middle and you are behind it
const GRACE := 0.5            # seconds in the open, in range, before it does
const SPEED := 2.8
const TEAR_EVERY := Vector2(0.9, 1.5)

var player: Player
var pillars: Array = []       # Vector2 (x, z)
var walking := false
var _exposed := 0.0
var _tear_t := 0.0


static func create(parent: Node3D, p: Player, pillar_spots: Array) -> TearStalker:
	var s := TearStalker.new()
	s.name = "TearStalker"
	s.player = p
	s.pillars = pillar_spots
	parent.add_child(s)
	return s


## Moves along `route` (Vector3 points) and is gone. Await it.
func walk(route: Array) -> void:
	global_position = route[0]
	walking = true
	_exposed = 0.0
	_tear_t = 0.0
	for i in range(1, route.size()):
		var to: Vector3 = route[i]
		while is_inside_tree() and walking and global_position.distance_to(to) > 0.15:
			global_position = global_position.move_toward(to, SPEED * get_physics_process_delta_time())
			await get_tree().physics_frame
		if not is_inside_tree() or not walking:
			return
	walking = false


func stop() -> void:
	walking = false


func _physics_process(delta: float) -> void:
	if not walking or player == null:
		return
	_tear_t -= delta
	if _tear_t <= 0.0:
		_tear_t = randf_range(TEAR_EVERY.x, TEAR_EVERY.y)
		Snd.play_at(Snd.variant("paper_tear"), global_position, 8.0, randf_range(0.75, 1.0), 9.0, 80.0)
	var at := player.global_position
	var dist := Vector2(at.x - global_position.x, at.z - global_position.z).length()
	if dist > SIGHT or _hidden(at):
		_exposed = maxf(_exposed - delta, 0.0)
		return
	_exposed += delta
	if _exposed >= GRACE:
		walking = false
		seen.emit()


func _hidden(at: Vector3) -> bool:
	var q := Vector2(at.x, at.z)
	for p: Vector2 in pillars:
		if q.distance_to(p) < HUG:
			return true
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.1, 0), at + Vector3(0, 1.1, 0), Geo.LAYER_WORLD)
	return not get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
