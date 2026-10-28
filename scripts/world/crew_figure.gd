class_name CrewFigure
extends Node3D
## SCENE 02's 형체: someone in a cabin-crew uniform standing with their back to you, head bowed, tearing baggage tags
## to pieces. Built from primitives with real joints (hips → knees, shoulders → elbows, neck → head) so the turn can
## break them one at a time (`turn_around`), and then it comes after you (`chase`) — body still facing away, head
## turned all the way round, knees bent the wrong way — with the rattle of a baggage cart that is not there.
##
## The model looks down local -Z.

signal caught

const SKIN := Color(0.5, 0.47, 0.44)
const TEAR_EVERY := Vector2(1.1, 1.9)
## After the turn: both arms wrenched back and twisted round in their sockets (the elbows then bend the wrong way).
const SHOULDER_BROKEN := [Vector3(-0.55, 1.25, -0.45), Vector3(-0.35, -1.5, 0.55)]

var player: Player
var on_talk: Callable
var interactable: Interactable
var tearing := false
var chasing := false
var speed := 0.0
## Breadcrumbs of where the player went (the prologue drops one every few tenths of a second): it follows them
## instead of cutting through walls.
var trail: Array[Vector3] = []

var _pelvis: Node3D
var _spine: Node3D
var _neck: Node3D
var _head: Node3D
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _hips: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _sheet: Node3D
var _body_col: CollisionShape3D
var _voice: AudioStreamPlayer3D
var _rattle: AudioStreamPlayer3D
var _t := 0.0
var _tear_wait := 1.0
var _tear_k := 0.0
var _scraps: Array[Node3D] = []
var _gait := 0.0
var _step_side := 0
var _twitch := Vector3.ZERO
var _twitch_t := 0.0
var _glow: OmniLight3D


static func create(parent: Node3D, pos: Vector3, rot_y := 0.0) -> CrewFigure:
	var f := CrewFigure.new()
	f.name = "CrewFigure"
	parent.add_child(f)
	f.global_position = pos
	f.rotation.y = rot_y
	f._build()
	return f


func _build() -> void:
	var navy := Mats.std(Color(0.06, 0.08, 0.17), 0.7)
	var navy_dark := Mats.std(Color(0.04, 0.05, 0.11), 0.75)
	var stocking := Mats.std(Color(0.42, 0.34, 0.3), 0.55)
	var skin := Mats.std(SKIN, 0.75)
	var white := Mats.std(Color(0.86, 0.86, 0.84), 0.6)
	var shoe := Mats.std(Color(0.03, 0.03, 0.035), 0.3)
	var gold := Mats.std(Color(0.7, 0.55, 0.22), 0.35, 0.8)
	var hair := Mats.std(Color(0.08, 0.06, 0.05), 0.8)
	_pelvis = Node3D.new()
	add_child(_pelvis)
	_pelvis.position = Vector3(0, 0.92, 0)
	# legs: hip → knee → shoe
	for sx in [-0.085, 0.085]:
		var hip := Node3D.new()
		_pelvis.add_child(hip)
		hip.position = Vector3(sx, -0.02, 0)
		Geo.capsule(hip, Vector3(0, -0.22, 0), 0.066, 0.46, stocking)
		var knee := Node3D.new()
		hip.add_child(knee)
		knee.position = Vector3(0, -0.44, 0)
		Geo.capsule(knee, Vector3(0, -0.21, 0), 0.052, 0.44, stocking)
		Geo.box(knee, Vector3(0, -0.43, -0.035), Vector3(0.075, 0.06, 0.2), shoe, false)
		Geo.box(knee, Vector3(0, -0.45, 0.05), Vector3(0.02, 0.05, 0.02), shoe, false)     # heel
		_hips.append(hip)
		_knees.append(knee)
	# pencil skirt to the knee
	var skirt := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.16
	sm.bottom_radius = 0.145
	sm.height = 0.46
	sm.radial_segments = 16
	skirt.mesh = sm
	skirt.material_override = navy
	_pelvis.add_child(skirt)
	skirt.position = Vector3(0, -0.2, 0)
	skirt.scale = Vector3(1.0, 1.0, 0.72)
	# torso: jacket over a white blouse, scarf at the throat, a pair of wings on the chest
	_spine = Node3D.new()
	_pelvis.add_child(_spine)
	_spine.position = Vector3(0, 0.03, 0)
	Geo.capsule(_spine, Vector3(0, 0.28, 0), 0.17, 0.62, navy).scale = Vector3(1.0, 1.0, 0.64)
	Geo.box(_spine, Vector3(0, 0.44, -0.095), Vector3(0.1, 0.16, 0.02), white, false)
	var scarf := Geo.box(_spine, Vector3(0.015, 0.53, -0.1), Vector3(0.09, 0.05, 0.03), Mats.std(Color(0.55, 0.08, 0.1), 0.6), false)
	scarf.rotation.z = 0.4
	Geo.box(_spine, Vector3(-0.075, 0.42, -0.112), Vector3(0.07, 0.016, 0.006), gold, false)
	Geo.box(_spine, Vector3(0.08, 0.36, -0.112), Vector3(0.06, 0.018, 0.006), white, false)     # name badge
	for y in [0.18, 0.3]:
		Geo.sphere(_spine, Vector3(0.0, y, -0.112), 0.009, gold)                                   # buttons
	# arms: shoulder → elbow → hand
	for sx in [-0.2, 0.2]:
		var sh := Node3D.new()
		_spine.add_child(sh)
		sh.position = Vector3(sx, 0.5, 0)
		Geo.capsule(sh, Vector3(0, -0.14, 0), 0.05, 0.32, navy)
		var el := Node3D.new()
		sh.add_child(el)
		el.position = Vector3(0, -0.28, 0)
		Geo.capsule(el, Vector3(0, -0.12, 0), 0.042, 0.28, navy)
		Geo.cyl(el, Vector3(0, -0.24, 0), 0.044, 0.02, white)                                         # cuff
		Geo.sphere(el, Vector3(0, -0.29, 0), 0.042, skin).scale = Vector3(0.8, 1.2, 0.6)
		_shoulders.append(sh)
		_elbows.append(el)
	Geo.cyl(_spine, Vector3(0, 0.6, 0), 0.045, 0.1, skin)
	# head: hair in a bun, a crew cap pinned on at an angle, and a face nobody could recognise
	_neck = Node3D.new()
	_spine.add_child(_neck)
	_neck.position = Vector3(0, 0.6, 0)
	_head = Node3D.new()
	_neck.add_child(_head)
	_head.position = Vector3(0, 0.07, 0)
	var face := Geo.sphere(_head, Vector3(0.006, 0.1, 0), 0.104, skin)
	face.scale = Vector3(0.86, 1.3, 0.96)          # drawn out long
	face.rotation.z = 0.12
	Geo.sphere(_head, Vector3(0.016, -0.005, -0.035), 0.058, skin).scale = Vector3(0.8, 1.35, 0.9)   # the jaw hangs
	Geo.sphere(_head, Vector3(0, 0.125, 0.018), 0.108, hair).scale = Vector3(0.98, 1.06, 0.94)
	Geo.sphere(_head, Vector3(0, 0.13, 0.115), 0.052, hair)
	var cap := Geo.cyl(_head, Vector3(0.025, 0.225, -0.01), 0.07, 0.055, navy_dark)
	cap.rotation.z = -0.22
	Geo.cyl(cap, Vector3(0, 0.0, 0), 0.072, 0.012, gold)
	var dark := Mats.std(Color(0.015, 0.01, 0.01), 0.9)
	# sunken sockets at two different heights, one dragged half-way down the cheek
	for e in [[-0.038, 0.142, 1.3, -0.1], [0.043, 0.098, 2.8, 0.25]]:
		var eye := Geo.sphere(_head, Vector3(e[0], e[1], -0.09), 0.016, dark)
		eye.scale = Vector3(0.95, e[2], 0.5)
		eye.rotation.z = e[3]
	# the mouth: a long crooked gash running down into the hanging jaw
	var mouth := Geo.sphere(_head, Vector3(0.02, 0.018, -0.09), 0.02, dark)
	mouth.scale = Vector3(1.25, 3.6, 0.6)
	mouth.rotation.z = 0.45
	var rot := Mats.std(Color(0.22, 0.07, 0.06), 0.8)
	for s in [[-0.04, 0.09, 0.05], [0.052, 0.05, -0.1], [0.0, -0.035, 0.3]]:
		var streak := Geo.sphere(_head, Vector3(s[0], s[1], -0.094), 0.008, rot)
		streak.scale = Vector3(0.7, 4.5, 0.4)
		streak.rotation.z = s[2]
	# a hank of hair come loose across one side of the face
	var strand := Geo.box(_head, Vector3(-0.045, 0.1, -0.1), Vector3(0.028, 0.2, 0.012), hair, false)
	strand.rotation.z = 0.18
	# the sheet being torn, held up in front of the chest
	_sheet = Node3D.new()
	_spine.add_child(_sheet)
	_sheet.position = Vector3(0, 0.3, -0.3)
	Geo.box(_sheet, Vector3.ZERO, Vector3(0.12, 0.08, 0.002), Mats.std(Color(0.9, 0.88, 0.8), 0.9), false)
	# you cannot walk through it while it stands there; [E] speaks to it
	var body := StaticBody3D.new()
	body.collision_layer = Geo.LAYER_WORLD
	body.collision_mask = 0
	_body_col = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.26
	capsule.height = 1.7
	_body_col.shape = capsule
	_body_col.position = Vector3(0, 0.85, 0)
	body.add_child(_body_col)
	add_child(body)
	interactable = Interactable.create(self, Vector3(0, 1.0, 0), Vector3(0.8, 1.9, 0.8), "말 걸기", func():
		if on_talk.is_valid():
			on_talk.call())
	interactable.press_sound = ""
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 4.0
	_voice.max_distance = 30.0
	_voice.bus = "SFX"
	Snd.setup_3d(_voice)
	_voice.max_polyphony = 3
	_spine.add_child(_voice)
	_voice.position = Vector3(0, 0.3, -0.2)
	_rattle = Snd.make_loop("cart_rattle_loop", self, 0.0, 7.0, 60.0)
	_rattle.position = Vector3(0, 0.4, 0)
	# barely there: enough to catch it when you look back in the dark
	_glow = Geo.omni(self, Vector3(0, 1.9, 0.4), Color(0.75, 0.85, 0.8), 0.0, 3.2)
	_glow.light_volumetric_fog_energy = 0.4
	_pose_tear(0.0)


func head_position() -> Vector3:
	return _head.global_position + _head.global_basis.y * 0.11


## Tearing pose: head bowed, both hands up in front of the chest pulling a sheet apart (k = how far apart).
func _pose_tear(k: float) -> void:
	_neck.rotation = Vector3(-0.55, 0.0, 0.0)
	_head.rotation = Vector3(-0.15, 0.0, 0.0)
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		_shoulders[i].rotation = Vector3(0.95, 0.0, s * (0.32 + 0.12 * k))
		_elbows[i].rotation = Vector3(1.15, 0.0, -s * (0.55 - 0.25 * k))
	_sheet.scale = Vector3(1.0 + 0.6 * k, 1.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	if tearing:
		_tear_wait -= delta
		_tear_k = move_toward(_tear_k, 0.0, delta * 1.6)
		if _tear_wait <= 0.0:
			_tear_wait = randf_range(TEAR_EVERY.x, TEAR_EVERY.y)
			_tear()
		_pose_tear(_tear_k)
	if chasing:
		_chase_step(delta)


## One rip: hands jerk apart, the sound, a scrap flutters down beside its feet.
func _tear() -> void:
	_tear_k = 1.0
	_voice.stream = Snd.stream(Snd.variant("paper_tear"))
	_voice.volume_db = randf_range(-3.0, 0.0)
	_voice.pitch_scale = randf_range(0.92, 1.08)
	_voice.play()
	var scrap := Node3D.new()
	get_parent().add_child(scrap)
	scrap.global_position = _sheet.global_position + Vector3(randf_range(-0.08, 0.08), 0, randf_range(-0.05, 0.05))
	Geo.box(scrap, Vector3.ZERO, Vector3(randf_range(0.03, 0.06), 0.002, randf_range(0.025, 0.05)), Mats.std(Color(0.9, 0.88, 0.8), 0.9), false)
	var land := Vector3(scrap.global_position.x + randf_range(-0.35, 0.35), global_position.y + 0.003, scrap.global_position.z + randf_range(-0.35, 0.35))
	var tw := scrap.create_tween().set_parallel(true)
	tw.tween_property(scrap, "global_position", land, randf_range(0.9, 1.4)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(scrap, "rotation", Vector3(0, randf() * TAU, 0), 1.0)
	_scraps.append(scrap)
	if _scraps.size() > 30:
		_scraps.pop_front().queue_free()


func _crack(vol := 0.0) -> void:
	_voice.stream = Snd.stream(Snd.variant("bone_crack"))
	_voice.volume_db = vol
	_voice.pitch_scale = randf_range(0.9, 1.08)
	_voice.play()


## Neck yaw that turns the face toward `p` while the body stays as it is (PI = straight behind it).
func face_yaw_to(p: Vector3) -> float:
	var l := to_local(p)
	return atan2(-l.x, -l.z)


## SCENE 02's turn, about five seconds: it stops, the neck snaps and the head comes round to you (`face_yaw`) while
## the body stays where it is, a shoulder goes back the wrong way, then each elbow and each knee, one at a time.
## Await it.
func turn_around(face_yaw := PI) -> void:
	tearing = false
	interactable.enabled = false
	_sheet.visible = false
	await get_tree().create_timer(1.3, false).timeout   # 짧은 정적
	_crack(3.0)                                          # 뚝
	var tw := create_tween()
	tw.tween_property(_neck, "rotation", Vector3(-0.3, face_yaw * 0.55, 0.12), 0.09)
	tw.tween_interval(0.35)
	tw.tween_property(_neck, "rotation", Vector3(-0.1, face_yaw, 0.18), 0.12)
	tw.tween_interval(0.25)
	tw.tween_property(_head, "rotation", Vector3(0.18, 0.0, -0.35), 0.5).set_trans(Tween.TRANS_SINE)
	await tw.finished
	await get_tree().create_timer(0.5, false).timeout
	# shoulders twist round, then the joints go one by one
	_crack(0.0)
	var t2 := create_tween().set_parallel(true)
	t2.tween_property(_shoulders[0], "rotation", SHOULDER_BROKEN[0], 0.14)
	t2.tween_property(_shoulders[1], "rotation", SHOULDER_BROKEN[1], 0.18).set_delay(0.06)
	await t2.finished
	for j in [[_elbows[0], Vector3(-1.7, 0.3, 0.2)], [_elbows[1], Vector3(-1.4, -0.4, -0.3)],
			[_knees[0], Vector3(1.25, 0.0, 0.1)], [_knees[1], Vector3(1.05, 0.0, -0.15)]]:
		await get_tree().create_timer(randf_range(0.28, 0.42), false).timeout
		_crack(-2.0)
		var t3 := create_tween().set_parallel(true)
		t3.tween_property(j[0], "rotation", j[1], 0.09)
		if j[0] in _knees:
			# the knees give the wrong way: it sinks a little and the hips tip
			t3.tween_property(_pelvis, "position:y", _pelvis.position.y - 0.07, 0.12)
			t3.tween_property(_spine, "rotation:x", _spine.rotation.x - 0.12, 0.12)
	await get_tree().create_timer(0.6, false).timeout


## The pose it is left in after turn_around, at once (retrying from the chase).
func pose_broken(face_yaw := PI) -> void:
	tearing = false
	_sheet.visible = false
	_neck.rotation = Vector3(-0.1, face_yaw, 0.18)
	_head.rotation = Vector3(0.18, 0.0, -0.35)
	_shoulders[0].rotation = SHOULDER_BROKEN[0]
	_shoulders[1].rotation = SHOULDER_BROKEN[1]
	_elbows[0].rotation = Vector3(-1.7, 0.3, 0.2)
	_elbows[1].rotation = Vector3(-1.4, -0.4, -0.3)
	_knees[0].rotation = Vector3(1.25, 0.0, 0.1)
	_knees[1].rotation = Vector3(1.05, 0.0, -0.15)
	_pelvis.position.y = 0.92 - 0.14
	_spine.rotation.x = -0.24


## Starts coming after the player along the trail. Its body keeps facing away; it moves backwards on bent-back
## knees with the head turned round toward you.
func chase(p: Player) -> void:
	player = p
	chasing = true
	_body_col.disabled = true
	interactable.enabled = false
	_glow.light_energy = 0.28
	_rattle.play()


func stop_chase() -> void:
	chasing = false
	_rattle.stop()


func _chase_step(delta: float) -> void:
	if player == null:
		return
	var here := global_position
	var goal := player.global_position
	# follow the trail while there is one, else straight for the player
	while not trail.is_empty() and Vector2(trail[0].x - here.x, trail[0].z - here.z).length() < 0.35:
		trail.pop_front()
	var to: Vector3 = (trail[0] if not trail.is_empty() else goal) - here
	to.y = 0.0
	var dist := Vector2(goal.x - here.x, goal.z - here.z).length()
	if dist < 1.0:
		chasing = false
		caught.emit()
		return
	if to.length() > 0.01:
		var dir := to.normalized()
		global_position += dir * speed * delta
		global_position.y = goal.y
		# torso faces away from where it is going
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(delta * 8.0, 0.0, 1.0))
	# gait: a lurching, uneven stride on the broken knees, the arms swinging loose behind
	_gait += delta * speed * 3.1
	var sw := sin(_gait)
	_hips[0].rotation.x = 0.55 * sw - 0.15
	_hips[1].rotation.x = -0.55 * sw - 0.15
	_knees[0].rotation.x = 1.0 + 0.45 * maxf(0.0, -sw)
	_knees[1].rotation.x = 0.85 + 0.45 * maxf(0.0, sw)
	_pelvis.position.y = 0.84 + absf(sw) * 0.06
	_shoulders[0].rotation.x = SHOULDER_BROKEN[0].x + 0.3 * sin(_gait * 0.5 + 1.0)
	_shoulders[1].rotation.x = SHOULDER_BROKEN[1].x + 0.35 * sin(_gait * 0.5 + 2.4)
	var side := 1 if sw > 0.0 else -1
	if side != _step_side:
		_step_side = side
		Snd.play_at(Snd.variant("footstep_tile"), global_position, -6.0, randf_range(0.62, 0.74), 5.0)
	# the head twitches
	_twitch_t -= delta
	if _twitch_t <= 0.0:
		_twitch_t = randf_range(0.06, 0.25)
		_twitch = Vector3(randf_range(-0.25, 0.25), randf_range(-0.3, 0.3), randf_range(-0.4, 0.4))
	_head.rotation = _head.rotation.lerp(Vector3(0.18, 0.0, -0.35) + _twitch, clampf(delta * 18.0, 0.0, 1.0))
	_neck.rotation.y = lerp_angle(_neck.rotation.y, PI, clampf(delta * 5.0, 0.0, 1.0))   # face where it is going
