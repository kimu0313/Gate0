class_name StaffNpc
extends Node3D
## 교대 근무자 — the evening-shift colleague who hands each dawn shift over in person, then clocks out.
## Built from primitives like every other prop: hi-vis vest, cap, face mask, staff card. Walks waypoint
## routes (`walk`), turns its head to the player, waves you over (`beckon`), holds items out (`present`).
## No voice: what they say is a subtitle you step through with [E] (ShiftDirector.npc_talk) while they
## mumble through the mask (`murmur`).

const NAME := "교대 근무자"
const WALK_SPEED := 1.35
const SKIN := Color(0.82, 0.64, 0.52)
const MUMBLE_DB := -4.0
const SHOVE_R := 0.68           # their body (0.28) + the player's (0.32) + a little: walking, they keep you this far off

var director: ShiftDirector
var player: Player
var on_talk: Callable           # what [E] does (ShiftDirector.npc_talk sets it)
var beckon := false             # wave and call out once when the player first comes into view
var walking := false
var interactable: Interactable

var _route: Array = []
var _speed := WALK_SPEED
var _phase := 0.0
var _last_sin := 0.0
var _walk_dir := Vector3.ZERO   # heading while walking (the push uses it)
var _collider: CollisionShape3D
var _body: Node3D
var _head: Node3D
var _hips: Array[Node3D] = []
var _shoulders: Array[Node3D] = []
var _voice: AudioStreamPlayer3D
var _face_target := Vector3.INF
var _t := 0.0
var _present_t := 0.0           # > 0 while holding an item out to the player
var _present_k := 0.0           # 0..1 how far the arm is raised
var _held: Node3D
var _wave_t := 0.0
var _wave_k := 0.0
var _beckoned := false
var _murmur_left := 0.0
var _murmur_fade: Tween


static func create(parent: Node3D, pos: Vector3, rot_y := 0.0) -> StaffNpc:
	var n := StaffNpc.new()
	n.name = "StaffNpc"
	parent.add_child(n)
	n.global_position = pos
	n.rotation.y = rot_y
	n._build()
	return n


## Facing for a direction on the floor (the model looks down local -Z).
static func yaw_for(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func _build() -> void:
	var trousers := Mats.std(Color(0.16, 0.2, 0.3), 0.8)
	var shirt := Mats.std(Color(0.58, 0.63, 0.7), 0.75)
	var vest := Mats.std(Color(0.95, 0.42, 0.08), 0.6)
	var strip := Mats.std(Color(0.86, 0.88, 0.86), 0.25, 0.3)
	var skin := Mats.std(SKIN, 0.7)
	var navy := Mats.std(Color(0.12, 0.16, 0.28), 0.7)
	var shoe := Mats.std(Color(0.2, 0.2, 0.22), 0.5)
	_body = Node3D.new()
	add_child(_body)
	# legs swing from the hips
	for sx in [-0.1, 0.1]:
		var hip := Node3D.new()
		_body.add_child(hip)
		hip.position = Vector3(sx, 0.9, 0)
		Geo.capsule(hip, Vector3(0, -0.42, 0), 0.08, 0.86, trousers)
		Geo.box(hip, Vector3(0, -0.85, -0.04), Vector3(0.12, 0.09, 0.27), shoe, false)
		_hips.append(hip)
	Geo.capsule(_body, Vector3(0, 0.95, 0), 0.17, 0.4, trousers).scale = Vector3(1.0, 1.0, 0.68)
	# torso: rounded, with the hi-vis vest over the shirt, reflective strips, staff card and radio
	Geo.capsule(_body, Vector3(0, 1.24, 0), 0.2, 0.66, shirt).scale = Vector3(1.0, 1.0, 0.62)
	Geo.capsule(_body, Vector3(0, 1.21, 0), 0.212, 0.6, vest).scale = Vector3(1.0, 1.0, 0.64)
	for y in [1.1, 1.3]:
		Geo.cyl(_body, Vector3(0, y, 0), 0.216, 0.035, strip).scale = Vector3(1.0, 1.0, 0.65)
	Geo.box(_body, Vector3(0.08, 1.2, -0.138), Vector3(0.07, 0.1, 0.008), Mats.get_mat("plastic_white"), false)
	Geo.box(_body, Vector3(0.08, 1.235, -0.143), Vector3(0.07, 0.02, 0.004), Mats.std(Color(0.12, 0.25, 0.68), 0.5), false)
	Geo.box(_body, Vector3(-0.11, 1.36, -0.13), Vector3(0.05, 0.1, 0.03), Mats.get_mat("plastic_dark"), false)
	for sx in [-0.235, 0.235]:
		var sh := Node3D.new()
		_body.add_child(sh)
		sh.position = Vector3(sx, 1.47, 0)
		Geo.capsule(sh, Vector3(0, -0.27, 0), 0.058, 0.6, shirt)
		Geo.sphere(sh, Vector3(0, -0.6, 0), 0.05, skin)
		_shoulders.append(sh)
	Geo.cyl(_body, Vector3(0, 1.57, 0), 0.05, 0.1, skin)
	# head: hair, cap, face mask, eyes
	_head = Node3D.new()
	_body.add_child(_head)
	_head.position = Vector3(0, 1.6, 0)
	Geo.sphere(_head, Vector3(0, 0.12, 0), 0.115, skin).scale = Vector3(0.92, 1.12, 1.0)
	Geo.sphere(_head, Vector3(0, 0.115, 0.03), 0.112, Mats.std(Color(0.26, 0.19, 0.14), 0.85)).scale = Vector3(0.98, 1.05, 0.92)
	Geo.sphere(_head, Vector3(0, 0.19, 0.005), 0.122, navy).scale = Vector3(1.0, 0.62, 1.0)
	Geo.box(_head, Vector3(0, 0.168, -0.15), Vector3(0.19, 0.014, 0.1), navy, false)
	Geo.box(_head, Vector3(0, 0.065, -0.105), Vector3(0.17, 0.085, 0.03), Mats.std(Color(0.78, 0.86, 0.94), 0.8), false)
	for ex in [-0.042, 0.042]:
		Geo.sphere(_head, Vector3(ex, 0.13, -0.104), 0.013, Mats.std(Color(0.1, 0.09, 0.09), 0.3))
	# the player bumps into them; [E] talks
	var body := StaticBody3D.new()
	body.collision_layer = Geo.LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.88, 0)
	body.add_child(cs)
	add_child(body)
	_collider = cs
	interactable = Interactable.create(self, Vector3(0, 0.95, 0), Vector3(0.8, 1.9, 0.8), "교대 근무자와 이야기하기", _on_talk)
	interactable.press_sound = ""
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 3.5
	Snd.setup_3d(_voice)
	_voice.bus = "SFX"
	_voice.max_distance = 30.0
	_head.add_child(_voice)


# --- behaviour -------------------------------------------------------------------------------
## Walks the waypoints in order (floor points). Returns at once; poll `walking`.
func walk(points: Array, speed := WALK_SPEED) -> void:
	_route = points.duplicate()
	_speed = speed
	walking = not _route.is_empty()


func face(point: Vector3) -> void:
	_face_target = point


## Talks you cannot make out (behind the mask) for about `seconds` (npc_mumble_*, tools/gen_mumble.py).
func murmur(seconds: float) -> void:
	var s := Snd.stream(Snd.variant("npc_mumble"))
	if s == null:
		return
	if _murmur_fade and _murmur_fade.is_valid():
		_murmur_fade.kill()
	_voice.stream = s
	_voice.volume_db = -30.0
	_voice.pitch_scale = randf_range(0.97, 1.04)
	_voice.play(randf() * maxf(0.0, s.get_length() - seconds))
	_murmur_fade = create_tween()   # in from wherever the clip was picked up, no click
	_murmur_fade.tween_property(_voice, "volume_db", MUMBLE_DB, 0.06)
	_murmur_left = seconds


func wave(seconds := 2.2) -> void:
	_wave_t = seconds


func is_seen() -> bool:
	if player == null:
		return false
	var hp := _head.global_position
	return player.camera.global_position.distance_to(hp) < 32.0 and player.facing_dot(hp) > 0.55


func head_position() -> Vector3:
	return _head.global_position


## Holds an item out in the right hand for `seconds` (the hand-over):
## "tablet" | "radio" | "binder" | "page" | "key" | "card" | "pass".
func present(item: String, seconds := 2.6) -> void:
	if _held and is_instance_valid(_held):
		_held.queue_free()
	_held = Node3D.new()
	_shoulders[1].add_child(_held)
	_held.position = Vector3(0, -0.66, -0.02)
	match item:
		"tablet":
			Geo.box(_held, Vector3.ZERO, Vector3(0.25, 0.016, 0.18), Mats.get_mat("plastic_dark"), false)
			Geo.box(_held, Vector3(0, -0.009, 0), Vector3(0.21, 0.004, 0.14), Mats.emissive(Color(0.25, 0.45, 0.9), 0.7), false)
		"radio":
			Geo.box(_held, Vector3(0, -0.02, 0), Vector3(0.065, 0.05, 0.17), Mats.get_mat("plastic_dark"), false)
			Geo.box(_held, Vector3(0.02, -0.02, 0.11), Vector3(0.012, 0.012, 0.08), Mats.get_mat("plastic_dark"), false)
		"binder":
			Geo.box(_held, Vector3(0, -0.03, 0), Vector3(0.25, 0.06, 0.31), Mats.std(Color(0.14, 0.2, 0.42), 0.6), false)
			Geo.box(_held, Vector3(0, -0.062, 0.02), Vector3(0.12, 0.003, 0.06), Mats.get_mat("plastic_white"), false)
		"page":
			Geo.box(_held, Vector3(0, -0.01, 0.02), Vector3(0.21, 0.004, 0.29), Mats.get_mat("paper"), false)
			Geo.box(_held, Vector3(0.06, -0.013, 0.1), Vector3(0.05, 0.002, 0.05), Mats.std(Color(0.7, 0.12, 0.1), 0.7), false)
		"key":
			Geo.box(_held, Vector3(0, -0.01, 0), Vector3(0.03, 0.008, 0.05), Mats.get_mat("metal"), false)
			Geo.box(_held, Vector3(0, -0.01, 0.05), Vector3(0.012, 0.006, 0.06), Mats.get_mat("metal"), false)
			Geo.box(_held, Vector3(0, -0.01, -0.045), Vector3(0.04, 0.006, 0.03), Mats.std(Color(0.9, 0.75, 0.15), 0.6), false)
		"card":
			Geo.box(_held, Vector3(0, -0.006, 0), Vector3(0.055, 0.004, 0.086), Mats.get_mat("plastic_white"), false)
			Geo.box(_held, Vector3(0, -0.009, -0.03), Vector3(0.055, 0.002, 0.018), Mats.std(Color(0.12, 0.25, 0.68), 0.5), false)
		"pass":
			Geo.box(_held, Vector3(0, -0.006, 0), Vector3(0.08, 0.004, 0.2), Mats.std(Color(0.93, 0.93, 0.9), 0.7), false)
			Geo.box(_held, Vector3(0, -0.009, -0.07), Vector3(0.08, 0.002, 0.045), Mats.std(Color(0.12, 0.25, 0.68), 0.5), false)
	_present_t = seconds
	if player:
		face(player.global_position)


func _on_talk() -> void:
	if on_talk.is_valid():
		on_talk.call()


func _process(delta: float) -> void:
	_t += delta
	if _murmur_left > 0.0:
		_murmur_left -= delta
		if _murmur_left <= 0.0:
			_murmur_fade = create_tween()
			_murmur_fade.tween_property(_voice, "volume_db", -40.0, 0.15)
			_murmur_fade.tween_callback(_voice.stop)
	# first time you come into view: a wave and a word you cannot make out — come over here
	if beckon and not _beckoned and player and not walking:
		var d := player.global_position.distance_to(global_position)
		if d < 9.0 and is_seen():
			_beckoned = true
			face(player.global_position)
			wave()
			murmur(0.9)
	var moving := false
	if walking and not _route.is_empty():
		var target: Vector3 = _route[0]
		var to := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
		if to.length() < 0.06:
			_route.pop_front()
			if _route.is_empty():
				walking = false
		else:
			moving = true
			global_position += to.normalized() * minf(_speed * delta, to.length())
			rotation.y = lerp_angle(rotation.y, yaw_for(to), minf(1.0, delta * 7.0))
			_walk_dir = to.normalized()
	elif _face_target != Vector3.INF:
		var d := _face_target - global_position
		d.y = 0.0
		if d.length() > 0.05:
			rotation.y = lerp_angle(rotation.y, yaw_for(d), minf(1.0, delta * 4.0))
			if absf(angle_difference(rotation.y, yaw_for(d))) < 0.02:
				_face_target = Vector3.INF
	# walking, they push through instead of colliding (pinned against a wall, they pass through rather than stop)
	if _collider.disabled != walking:
		_collider.disabled = walking
	if not moving:
		_walk_dir = Vector3.ZERO
	_animate(delta, moving)


func _physics_process(_delta: float) -> void:
	if _walk_dir != Vector3.ZERO:
		_shove_player(_walk_dir)   # once per physics tick, so the push is as steady as the player's own walking


## They do not stop for you: standing in the way you are pushed aside (to the side you are already on, back along
## their way where a wall leaves no side), so nobody can block them. The push grows over the last 30 cm before
## contact and keeps pace with their walk, so you slide out of the way instead of being knocked (no view shake).
func _shove_player(dir: Vector3) -> void:
	if player == null:
		return
	var rel := player.global_position - global_position
	rel.y = 0.0
	var dist := rel.length()
	var k := clampf((SHOVE_R + 0.15 - dist) / 0.3, 0.0, 1.0)
	if k <= 0.0:
		return
	var ahead := rel.dot(dir)
	var lateral := rel - dir * ahead
	var side := lateral.normalized() if lateral.length() > 0.04 else dir.cross(Vector3.UP)   # dead centre: their right
	var out := rel / dist if dist > 0.04 else side
	if ahead > 0.0:
		out = (out + side * 1.3).normalized()    # in front: mostly sideways, out of their path
	player.shove(out * (_speed * 1.15 * k + maxf(0.0, SHOVE_R - dist) * 6.0))


func _animate(delta: float, moving: bool) -> void:
	var swing := 0.0
	if moving:
		_phase += delta * _speed * 4.1
		swing = sin(_phase)
		if signf(swing) != signf(_last_sin):
			_footstep()
		_last_sin = swing
	else:
		_phase = lerpf(_phase, roundf(_phase / PI) * PI, minf(1.0, delta * 6.0))
		swing = sin(_phase)
	for i in 2:
		var side := 1.0 if i == 0 else -1.0
		_hips[i].rotation.x = swing * 0.42 * side
		_shoulders[i].rotation.x = -swing * 0.32 * side
		_shoulders[i].rotation.z = -0.05 if i == 0 else 0.05   # arms hang slightly away from the body
	# handing something over: the right arm comes up and forward, then drops once it has been taken
	_present_k = move_toward(_present_k, 1.0 if _present_t > 0.0 else 0.0, delta * 3.0)
	if _present_k > 0.0:
		_shoulders[1].rotation.x = lerpf(_shoulders[1].rotation.x, 1.15, smoothstep(0.0, 1.0, _present_k))
	if _present_t > 0.0:
		_present_t -= delta
		if _present_t <= 0.0 and _held and is_instance_valid(_held):
			_held.queue_free()   # taken
			_held = null
	# waving you over: right arm up, hand going side to side
	_wave_k = move_toward(_wave_k, 1.0 if _wave_t > 0.0 else 0.0, delta * 4.0)
	if _wave_t > 0.0:
		_wave_t -= delta
	if _wave_k > 0.0 and _present_k <= 0.0:
		var k := smoothstep(0.0, 1.0, _wave_k)
		_shoulders[1].rotation.x = lerpf(_shoulders[1].rotation.x, 2.7, k)
		_shoulders[1].rotation.z = lerpf(_shoulders[1].rotation.z, 0.05 + sin(_t * 9.0) * 0.35, k)
	_body.position.y = absf(cos(_phase)) * 0.025 if moving else 0.0
	_body.scale.y = 1.0 + (0.0 if moving else sin(_t * 1.7) * 0.006)
	# head turns toward the player when they are close and in front
	var yaw := 0.0
	var pitch := 0.0
	if player:
		var rel := player.camera.global_position - _head.global_position
		var flat := Vector3(rel.x, 0.0, rel.z)
		if flat.length() < 6.0:
			var local := global_transform.basis.inverse() * flat
			var a := atan2(-local.x, -local.z)
			if absf(a) < 1.9:
				yaw = clampf(a, -1.1, 1.1)
				pitch = clampf(atan2(rel.y, flat.length()), -0.4, 0.3)
	if _voice.playing:
		pitch += sin(_t * 9.0) * 0.03   # a small nod while talking
	_head.rotation.y = lerp_angle(_head.rotation.y, yaw, minf(1.0, delta * 4.0))
	_head.rotation.x = lerpf(_head.rotation.x, pitch, minf(1.0, delta * 4.0))


func _footstep() -> void:
	var surface := "carpet" if global_position.z < -76.0 else "tile"
	var p := Snd.play_at(Snd.variant("footstep_" + surface), global_position + Vector3(0, 0.1, 0), -15.0,
		randf_range(0.95, 1.05), 3.0, 26.0)
	if p:
		p.area_mask = 0   # the step recordings carry their own room, like the player's


# --- routes through the terminal (Terminal.NAV: floor points clear of counters, pillars and carousels) ---------
## From anywhere in the open zones to just inside the main entrance.
static func route_to_entrance(from: Vector3) -> Array:
	return Terminal.current.route(from, "entrance_in")


## From the hall or security north through the corridor towards the gates (the wing shutters must be open).
static func route_to_wing(from: Vector3) -> Array:
	return Terminal.current.route(from, "cor_n")
