class_name CrewFigure
extends Node3D
## SCENE 02's 형체: someone in a cabin-crew uniform standing with their back to you, head bowed, tearing baggage tags
## to pieces. Built from primitives with real joints (hips → knees, shoulders → elbows, neck → head) so the turn can
## break them one at a time (`turn_around`), and then it comes after you (`chase`) on two legs with every joint wrong,
## so it reads from in front: the torso wrung round and fallen over to one side, the head lying over on its side nearly
## upside down, one arm out of its socket hanging long, the other wrenched up with the forearm dangling from the elbow,
## the knees bending backwards and knocking in — drawn like stop-motion with frames missing, stopping dead now and then
## to reach for you on a neck that draws out, then lurching on. The rattle of a baggage cart that is not there goes with it, and its throat croaks.
##
## The model looks down local -Z.

signal caught

const SKIN := Color(0.5, 0.47, 0.44)
const TEAR_EVERY := Vector2(1.1, 1.9)
## After the turn: both arms wrenched back and twisted round in their sockets (the elbows then bend the wrong way).
const SHOULDER_BROKEN := [Vector3(-0.55, 1.25, -0.45), Vector3(-0.35, -1.5, 0.55)]
## The chase walk: the pelvis height on the backward knees, the torso wrung round on the hips and fallen over to one
## side, the head lying over on its side.
const WALK_PELVIS := 0.84
const WALK_TWIST := 0.5
const WALK_LEAN := 0.42
const HEAD_ROLL := -2.1
## Held frames while it chases (seconds): it jumps from pose to pose instead of moving.
const FRAME := Vector2(1.0 / 15.0, 1.0 / 8.0)

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
var _jaw: Node3D
var _mouth: MeshInstance3D
var _neck_mesh: MeshInstance3D
var _throat: AudioStreamPlayer3D
var _walking := false
var _pos := Vector3.ZERO         # where it really is while it chases (drawn only on the held frames)
var _yaw := 0.0
var _frame_t := 0.0
var _phase := "run"              # run / stall (stops dead, the neck reaching for you) / lunge (a sudden scuttle)
var _phase_t := 0.0
var _pace := 1.0
var _pace_to := 1.0
var _stretch := 0.0
var _stretch_to := 0.0
var _head_spin := 0.0
var _jolt := Vector3.ZERO
var _crack_t := 1.0
var _croak_t := 2.0
var _jaw_t := 0.0
var _hush_t := 0.0
var _snap: Array[float] = [0.0, 0.0]      # a knee giving further backwards as its foot lands


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
	_jaw = Node3D.new()                                                                               # the jaw hangs
	_head.add_child(_jaw)
	_jaw.position = Vector3(0.016, 0.045, -0.03)
	Geo.sphere(_jaw, Vector3(0, -0.05, -0.005), 0.058, skin).scale = Vector3(0.8, 1.35, 0.9)
	# the neck it draws out when it reaches for you (scaled; the head sits at its end)
	_neck_mesh = MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.036
	nm.bottom_radius = 0.042
	nm.height = 1.0
	nm.radial_segments = 10
	_neck_mesh.mesh = nm
	_neck_mesh.material_override = skin
	_neck.add_child(_neck_mesh)
	_set_neck(0.0)
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
	_mouth = Geo.sphere(_head, Vector3(0.02, 0.018, -0.09), 0.02, dark)
	_mouth.scale = Vector3(1.25, 3.6, 0.6)
	_mouth.rotation.z = 0.45
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
	_throat = AudioStreamPlayer3D.new()
	_throat.unit_size = 5.0
	_throat.max_distance = 40.0
	_throat.bus = "SFX"
	Snd.setup_3d(_throat)
	_head.add_child(_throat)
	# barely there: enough to catch it when you look back in the dark
	_glow = Geo.omni(self, Vector3(0, 1.9, 0.4), Color(0.75, 0.85, 0.8), 0.0, 3.2)
	_glow.light_volumetric_fog_energy = 0.4
	_pose_tear(0.0)


## Spoken to: it stops tearing for `seconds`, the head coming up a little as if listening, then one loud rip.
func hush(seconds: float) -> void:
	_hush_t = seconds


func head_position() -> Vector3:
	return _head.global_position + _head.global_basis.y * 0.11


## Tearing pose: head bowed, both hands up in front of the chest pulling a sheet apart (k = how far apart).
func _pose_tear(k: float) -> void:
	_neck.rotation = Vector3(-0.3 if _hush_t > 0.0 else -0.55, 0.0, 0.0)
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
		if _hush_t > 0.0:
			_hush_t -= delta
			if _hush_t <= 0.0:
				_tear(4.0)
				_tear_wait = randf_range(TEAR_EVERY.x, TEAR_EVERY.y) + 0.6
		elif _tear_wait <= 0.0:
			_tear_wait = randf_range(TEAR_EVERY.x, TEAR_EVERY.y)
			_tear()
		_pose_tear(_tear_k)
	if chasing:
		_chase_step(delta)


## One rip: hands jerk apart, the sound, a scrap flutters down beside its feet.
func _tear(db := 0.0) -> void:
	_tear_k = 1.0
	_voice.stream = Snd.stream(Snd.variant("paper_tear"))
	_voice.volume_db = db + randf_range(-3.0, 0.0)
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


## Starts coming after the player along the trail: first it wrings itself round (_twist), then it walks.
func chase(p: Player) -> void:
	player = p
	chasing = true
	_walking = false
	_body_col.disabled = true
	interactable.enabled = false
	_glow.light_energy = 0.32
	_rattle.play()
	_pos = global_position
	_twist()


func stop_chase() -> void:
	chasing = false
	_rattle.stop()


## It wrings itself round, one snap at a time: the hips and legs swing round to face you, the torso twists and falls
## over to one side, the head drops over onto its side, one shoulder comes out of its socket and the other arm wrenches
## up, the knees give backwards and knock in.
func _twist() -> void:
	var tree := get_tree()
	var to_p := player.global_position - global_position
	_yaw = atan2(-to_p.x, -to_p.z)
	_crack(2.0)
	rotation.y = _yaw
	_spine.rotation = Vector3(-0.2, WALK_TWIST, WALK_LEAN * 0.4)
	_neck.rotation = Vector3(-0.1, -WALK_TWIST, 0.0)
	_head.rotation = Vector3(0.1, 0.0, -0.6)
	await tree.create_timer(0.26, false).timeout
	_crack(0.0)
	_spine.rotation.z = WALK_LEAN
	_neck.rotation.z = -WALK_LEAN * 0.5
	_head.rotation = Vector3(0.15, 0.0, HEAD_ROLL)
	await tree.create_timer(0.2, false).timeout
	_crack(-1.0)
	_shoulders[0].position.y = 0.4
	_shoulders[0].scale = Vector3.ONE * 1.3
	_shoulders[0].rotation = Vector3(0.1, 0.0, -0.12)
	_elbows[0].rotation = Vector3(-0.45, 0.0, 0.0)
	await tree.create_timer(0.16, false).timeout
	_crack(-2.0)
	_shoulders[1].rotation = Vector3(0.4, 0.0, 2.35)
	_elbows[1].rotation = Vector3(0.0, 0.0, -2.15)
	for i in 2:
		await tree.create_timer(0.16, false).timeout
		_crack(-1.0)
		var sd := -1.0 if i == 0 else 1.0
		_hips[i].rotation = Vector3(-0.55, 0.0, -sd * 0.14)
		_knees[i].rotation = Vector3(1.2, 0.0, sd * 0.5)
		_pelvis.position.y = WALK_PELVIS + 0.03 - 0.03 * i
	await tree.create_timer(0.2, false).timeout
	_croak()
	_phase = "run"
	_phase_t = 1.6
	_walking = true


func _crack(vol := 0.0) -> void:
	_voice.stream = Snd.stream(Snd.variant("bone_crack"))
	_voice.volume_db = vol
	_voice.pitch_scale = randf_range(0.9, 1.08)
	_voice.play()


func _croak() -> void:
	var st := Snd.stream(Snd.variant("creature_croak"))
	if st == null:
		return
	_throat.stream = st
	_throat.volume_db = randf_range(-3.0, 0.0)
	_throat.pitch_scale = randf_range(0.88, 1.04)
	_throat.play()
	_jaw_t = st.get_length() / _throat.pitch_scale
	_croak_t = randf_range(2.4, 4.4)


## A heel coming down: the step, and now and then the knee cracking further back under it.
func _footfall(i: int) -> void:
	Snd.play_at(Snd.variant("footstep_tile"), _pos, -5.0, randf_range(0.6, 0.72), 5.0)
	_snap[i] = randf_range(0.25, 0.5)
	if randf() < 0.22:
		_crack(randf_range(-12.0, -7.0))
		_snap[i] += 0.3


## The neck between the shoulders and the head, `extra` metres longer than it should be.
func _set_neck(extra: float) -> void:
	var l := 0.07 + extra
	_head.position = Vector3(0, l, 0)
	_neck_mesh.position = Vector3(0, l * 0.5, 0)
	_neck_mesh.scale = Vector3(1.0, l, 1.0)


func _chase_step(delta: float) -> void:
	if player == null:
		return
	var goal := player.global_position
	var dist := Vector2(goal.x - _pos.x, goal.z - _pos.z).length()
	if dist < 1.0:
		chasing = false
		caught.emit()
		return
	if not _walking:
		return                                           # still wringing itself round
	_update_phase(delta, dist)
	# follow the trail while there is one, else straight for the player
	while not trail.is_empty() and Vector2(trail[0].x - _pos.x, trail[0].z - _pos.z).length() < 0.35:
		trail.pop_front()
	var to: Vector3 = (trail[0] if not trail.is_empty() else goal) - _pos
	to.y = 0.0
	var v := speed * _pace
	if to.length() > 0.01:
		var dir := to.normalized()
		_pos += dir * v * delta
		_yaw = lerp_angle(_yaw, atan2(-dir.x, -dir.z), clampf(delta * 9.0, 0.0, 1.0))
	_pos.y = goal.y
	# a heel comes down at the end of each stride
	var was := cos(_gait)
	_gait += delta * v * 2.6
	if signf(cos(_gait)) != signf(was):
		_footfall(0 if was > 0.0 else 1)
	for i in 2:
		_snap[i] = move_toward(_snap[i], 0.0, delta * 2.2)
	_stretch = move_toward(_stretch, _stretch_to, delta * (5.0 if _stretch_to > _stretch else 9.0))
	_jolt = _jolt.move_toward(Vector3.ZERO, delta * 2.5)
	_rattle.volume_db = lerpf(-16.0, 0.0, clampf(_pace, 0.0, 1.0))
	_rattle.pitch_scale = 0.8 + 0.22 * clampf(_pace, 0.0, 1.8)
	# a joint goes now and then; the throat rattles
	_crack_t -= delta
	if _crack_t <= 0.0:
		_crack_t = randf_range(0.8, 2.2)
		_crack(randf_range(-10.0, -5.0))
		_jolt = Vector3(randf_range(-0.5, 0.5), randf_range(-0.4, 0.4), randf_range(-0.35, 0.35))
	_croak_t -= delta
	if _croak_t <= 0.0:
		_croak()
	_jaw_t = maxf(0.0, _jaw_t - delta)
	_twitch_t -= delta
	if _twitch_t <= 0.0:
		_twitch_t = randf_range(0.06, 0.25)
		_twitch = Vector3(randf_range(-0.25, 0.25), randf_range(-0.3, 0.3), randf_range(-0.4, 0.4))
	# drawn on held frames only, now and then one held far too long
	_frame_t -= delta
	if _frame_t <= 0.0:
		_frame_t = randf_range(0.2, 0.36) if randf() < 0.07 else randf_range(FRAME.x, FRAME.y)
		_draw_walk()


## run → (now and then) stall: it stops dead, cracks, croaks, the head turns over and the neck draws out toward you →
## lunge: a burst of lurching strides (only when you have pulled away; never onto you) → run.
func _update_phase(delta: float, dist: float) -> void:
	_phase_t -= delta
	if _phase == "lunge" and dist < 2.6:
		_phase_t = 0.0
	if _phase_t <= 0.0:
		match _phase:
			"run":
				if randf() < 0.55:
					_phase = "stall"
					_phase_t = randf_range(0.35, 0.6)
					_stretch_to = 1.0
					_head_spin = randf_range(0.7, 1.5) * (1.0 if randf() < 0.5 else -1.0)
					_crack(-3.0)
					_croak()
				else:
					_phase_t = randf_range(1.0, 2.2)
			"stall":
				_phase = "lunge"
				_phase_t = randf_range(0.45, 0.75)
				_stretch_to = 0.0
				_head_spin = 0.0
			_:
				_phase = "run"
				_phase_t = randf_range(1.3, 2.6)
		match _phase:
			"stall":
				_pace_to = 0.08
			"lunge":
				_pace_to = 1.8 if dist > 4.5 else 1.15
			_:
				_pace_to = 1.0
	_pace = move_toward(_pace, _pace_to, delta * 9.0)


## One held frame of the walk.
func _draw_walk() -> void:
	global_position = _pos
	rotation.y = _yaw
	var sw := sin(_gait)
	var cw := cos(_gait)
	# the pelvis drops onto each step and heaves over the leg it lands on
	_pelvis.position = Vector3(0.05 * sw, WALK_PELVIS - 0.08 * (1.0 - absf(sw)), 0.0)
	_pelvis.rotation = Vector3(0.06, 0.15 * sw, 0.18 * sw + _jolt.z)
	# the torso wrung round on the hips and fallen over to one side, hunched at you, rocking against the steps
	_spine.rotation = Vector3(-0.25 + _jolt.x * 0.3, WALK_TWIST + 0.25 * sw + _jolt.y * 0.4, WALK_LEAN + 0.1 * cw)
	# legs: the knees bend backwards and knock in (thighs in, shins out), more as each foot lands; the left one drags
	for i in 2:
		var sd := -1.0 if i == 0 else 1.0
		var ph := sw if i == 0 else -sw
		var lift := maxf(0.0, cw if i == 0 else -cw)
		var stride := 0.22 if i == 0 else 0.4
		_hips[i].rotation = Vector3(-0.55 + stride * ph, 0.0, -sd * 0.14)
		_knees[i].rotation = Vector3(1.05 + 0.35 * lift + _snap[i], 0.0, sd * (0.38 + 0.6 * _snap[i]))
	# arms: the left out of its socket, hanging long and loose; the right wrenched up over the shoulder, the forearm
	# dangling from the raised elbow
	_shoulders[0].rotation = Vector3(0.25 * sin(_gait * 0.5 + 1.0), 0.0, -0.12 + 0.1 * sin(_gait + 0.7))
	_elbows[0].rotation = Vector3(-0.45 + 0.15 * sin(_gait + 1.6), 0.0, 0.0)
	_shoulders[1].rotation = Vector3(0.4 + 0.2 * sin(_gait * 0.5 + 2.2), 0.0, 2.35 + 0.15 * sin(_gait + 0.3))
	_elbows[1].rotation = Vector3(0.3 * sin(_gait * 1.3), 0.0, -2.15 + 0.3 * sin(_gait + 2.0))
	# the head turned back round to face you, lying over on its side; when it stops the neck draws out and leans in
	_neck.rotation = Vector3(-0.1 - 0.9 * _stretch, -(WALK_TWIST + 0.25 * sw) + _head_spin * _stretch, -WALK_LEAN * 0.5)
	_set_neck(0.5 * _stretch)
	_head.rotation = Vector3(0.15, 0.0, HEAD_ROLL) + _twitch
	var open := 0.0
	if _jaw_t > 0.0:
		open = 0.18 + 0.27 * absf(sin(_t * 23.0))          # it chatters while it croaks
	_jaw.rotation.x = open
	_mouth.scale.y = 3.6 + 3.0 * open
