class_name Player
extends CharacterBody3D
## First-person night inspector: walk/sprint, head bob, surface footsteps, flashlight,
## close-eyes (hold C), interaction ray, conveyor riding, camera shake.

signal interact_target_changed(prompt: String)

const WALK_SPEED := 2.2
const SPRINT_SPEED := 4.4
const ACCEL := 11.0
const GRAVITY := 18.0
const EYE_HEIGHT := 1.62
const INTERACT_RANGE := 2.6
const STAMINA_MAX := 6.0

var controls_enabled := true
var look_enabled := true
var cutscene := false           # a scripted scene: no looking, walking or using things (walk_to still moves you);
                                # menus closing in between do not hand control back
var camera_mode := false
var terminal: Terminal

var head: Node3D
var camera: Camera3D
var flashlight: SpotLight3D
var flashlight_on := false
var eyes := 0.0                 # 0 open .. 1 closed
var eyes_closed_time := 0.0     # continuous seconds with eyes fully closed
var stamina := STAMINA_MAX
var current_interactable: Interactable
var current_prompt := ""
var move_vel := Vector3.ZERO
var conveyor_vel := Vector3.ZERO
var zone := ""
var still_time := 0.0           # continuous seconds standing still

var _pitch := 0.0
var _yaw := 0.0
var _bob_t := 0.0
var _shake := 0.0
var _shake_t := 0.0
var _feet: AudioStreamPlayer3D
var _feet_pool: Array[AudioStreamPlayer3D] = []
var _feet_i := 0
## Level of each step set by surface: the room-recorded steps carry long tails, so their strike sits lower than the
## dry steps they replaced (most of all the metal treads).
const STEP_DB := {"tile": 2.0, "tileroom": 3.0, "carpet": 0.0, "metal": 4.0}
var _breath: AudioStreamPlayer
var _fl_target := Basis()
var _forced_look: Tween
var _walk_to := Vector3.INF     # scripted walk (cutscenes): the floor point the player walks to by itself
var _walk_path: Array = []      # the points after it (walked through without stopping)
var _walk_speed := 1.4
var _glance := Vector3.INF      # cutscenes: a point the view drifts to like a head turning (glance())
var _glance_rate := 3.0
var _glance_vel := Vector2.ZERO


func _ready() -> void:
	add_to_group("player")
	collision_layer = Geo.LAYER_PLAYER
	collision_mask = Geo.LAYER_WORLD
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.875, 0)
	add_child(cs)
	head = Node3D.new()
	add_child(head)
	head.position = Vector3(0, EYE_HEIGHT, 0)
	camera = Camera3D.new()
	head.add_child(camera)
	camera.current = true
	camera.near = 0.05
	camera.far = 600.0
	camera.fov = Game.settings.fov
	flashlight = SpotLight3D.new()
	camera.add_child(flashlight)
	flashlight.position = Vector3(0.18, -0.2, 0.0)
	flashlight.light_color = Color(1.0, 0.94, 0.82)
	flashlight.light_energy = 0.0
	flashlight.spot_range = 24.0
	flashlight.spot_angle = 27.0
	flashlight.spot_attenuation = 1.2
	flashlight.spot_angle_attenuation = 0.7
	flashlight.shadow_enabled = true
	flashlight.light_volumetric_fog_energy = 0.5
	flashlight.visible = false
	# footsteps carry their own room (recorded in the space), so they skip the engine reverb zones; three players
	# take turns so each step's echo rings out under the next one
	for i in 3:
		var f := AudioStreamPlayer3D.new()
		f.unit_size = 4.0
		Snd.setup_3d(f, false)
		f.area_mask = 0
		add_child(f)
		f.position = Vector3(0, 0.05, 0)
		f.bus = "SFX"
		_feet_pool.append(f)
	_feet = _feet_pool[0]
	_breath = AudioStreamPlayer.new()
	_breath.bus = "SFX"
	add_child(_breath)
	_yaw = rotation.y


func set_look(yaw: float, pitch := 0.0) -> void:
	_yaw = yaw
	_pitch = pitch
	rotation.y = _yaw
	head.rotation.x = _pitch


func teleport(xform: Transform3D) -> void:
	global_position = xform.origin
	var f := -xform.basis.z
	set_look(atan2(-f.x, -f.z), 0.0)
	velocity = Vector3.ZERO
	move_vel = Vector3.ZERO
	_walk_to = Vector3.INF
	_walk_path.clear()
	_glance = Vector3.INF
	_glance_vel = Vector2.ZERO


## Cutscenes: the player walks to a floor point by themselves (steps, head bob and collisions as usual) while
## their own movement input is ignored. walking() is true until they get there.
func walk_to(p: Vector3, speed := 1.4) -> void:
	walk_path([p], speed)


## Walks through the points one after another without stopping at the corners; slows down only for the last.
func walk_path(points: Array, speed := 1.4) -> void:
	_walk_path = points.duplicate()
	_walk_speed = speed
	var first: Vector3 = _walk_path.pop_front()
	_walk_to = Vector3(first.x, global_position.y, first.z)


func walking() -> bool:
	return _walk_to != Vector3.INF


## Cutscenes: the view turns toward a point the way a head does — it eases into the turn and settles (a damped
## spring), so it can run while walking and a new glance blends out of the last one. glance(Vector3.INF) lets go.
func glance(p: Vector3, rate := 3.0) -> void:
	if _forced_look and _forced_look.is_valid():
		_forced_look.kill()
	_glance = p
	_glance_rate = rate


func _update_glance(delta: float) -> void:
	if _glance == Vector3.INF:
		_glance_vel = Vector2.ZERO
		return
	var to := _glance - camera.global_position
	var yaw := atan2(-to.x, -to.z)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	var w := _glance_rate
	_glance_vel.x += (w * w * wrapf(yaw - _yaw, -PI, PI) - 2.0 * w * _glance_vel.x) * delta
	_glance_vel.y += (w * w * (pitch - _pitch) - 2.0 * w * _glance_vel.y) * delta
	set_look(_yaw + _glance_vel.x * delta, clampf(_pitch + _glance_vel.y * delta, deg_to_rad(-60), deg_to_rad(60)))


## Smoothly turns the camera to look at a world point (cutscenes / scares).
func look_at_point(p: Vector3, duration := 0.6) -> void:
	var to := p - camera.global_position
	var yaw := atan2(-to.x, -to.z)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	var dyaw := wrapf(yaw - _yaw, -PI, PI)
	if _forced_look and _forced_look.is_valid():
		_forced_look.kill()
	_glance = Vector3.INF
	_forced_look = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_forced_look.tween_method(func(v): set_look(v, _pitch), _yaw, _yaw + dyaw, duration)
	_forced_look.tween_method(func(v): set_look(_yaw, v), _pitch, pitch, duration)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and look_enabled and not cutscene:
		var sens: float = 0.0022 * float(Game.settings.mouse_sensitivity)
		if camera_mode:
			sens *= 0.6
		_yaw -= event.relative.x * sens
		var inv := -1.0 if Game.settings.invert_y else 1.0
		_pitch = clampf(_pitch - event.relative.y * sens * inv, deg_to_rad(-85), deg_to_rad(85))
		rotation.y = _yaw
		head.rotation.x = _pitch
	if not controls_enabled or cutscene:
		return
	if event.is_action_pressed("flashlight"):
		toggle_flashlight()
	elif event.is_action_pressed("interact") and not camera_mode:
		if current_interactable and is_instance_valid(current_interactable):
			current_interactable.interact()


func toggle_flashlight(force := -1) -> void:
	flashlight_on = not flashlight_on if force < 0 else force == 1
	flashlight.visible = flashlight_on
	flashlight.light_energy = 1.7 if flashlight_on else 0.0      # bright enough in the dark, does not burn out signs up close
	Snd.play("button_press", -10.0, 1.6, "SFX")


func _physics_process(delta: float) -> void:
	# --- eyes ---
	var want_closed := controls_enabled and not cutscene and Input.is_action_pressed("close_eyes") and not camera_mode
	eyes = move_toward(eyes, 1.0 if want_closed else 0.0, delta * (4.5 if want_closed else 3.0))
	if eyes >= 0.98:
		eyes_closed_time += delta
	else:
		eyes_closed_time = 0.0
	Snd.set_muffle(eyes * 0.85)
	# --- movement ---
	var input := Vector2.ZERO
	if controls_enabled and not cutscene:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var sprinting := Input.is_action_pressed("sprint") and input.y < -0.1 and stamina > 0.2 and controls_enabled and not camera_mode
	var speed := SPRINT_SPEED if sprinting else WALK_SPEED
	if camera_mode:
		speed *= 0.45
	if eyes > 0.5:
		speed *= 0.35
	var dir := (global_basis * Vector3(input.x, 0, input.y))
	dir.y = 0.0
	dir = dir.normalized() * minf(input.length(), 1.0)
	var target := dir * speed
	if _walk_to != Vector3.INF:
		var to := Vector3(_walk_to.x - global_position.x, 0.0, _walk_to.z - global_position.z)
		var last := _walk_path.is_empty()
		if not last and to.length() < 0.45:
			var nxt: Vector3 = _walk_path.pop_front()       # round the corner without stopping
			_walk_to = Vector3(nxt.x, global_position.y, nxt.z)
			to = Vector3(_walk_to.x - global_position.x, 0.0, _walk_to.z - global_position.z)
			last = _walk_path.is_empty()
		if last and to.length() < 0.12:
			_walk_to = Vector3.INF
		else:
			target = to.normalized() * (minf(_walk_speed, to.length() * 2.2 + 0.25) if last else _walk_speed)
	_update_glance(delta)
	move_vel = move_vel.lerp(target, clampf(ACCEL * delta, 0.0, 1.0))
	stamina = clampf(stamina + (-delta if sprinting else delta * 0.6), 0.0, STAMINA_MAX)
	_update_breath(delta)
	# conveyor under our feet?
	conveyor_vel = Vector3.ZERO
	if is_on_floor():
		for i in get_slide_collision_count():
			var col := get_slide_collision(i).get_collider()
			if col and col.has_meta("conveyor"):
				var conv = col.get_meta("conveyor")
				conveyor_vel = conv.get_conveyor_velocity()
				conv.on_ridden()
				break
	var vy := velocity.y
	if not is_on_floor():
		vy -= GRAVITY * delta
	else:
		vy = -0.5
	velocity = Vector3(move_vel.x + conveyor_vel.x, vy, move_vel.z + conveyor_vel.z)
	move_and_slide()
	# --- stillness tracking (for "do not move" rules) ---
	if move_vel.length() < 0.35:
		still_time += delta
	else:
		still_time = 0.0
	# --- head bob + footsteps ---
	var hspeed := Vector2(move_vel.x, move_vel.z).length()
	if is_on_floor() and hspeed > 0.4:
		# one head dip per step (bob = -|sin|, lowest at PI/2 + k*PI) and the step sounds at the dip, where the heel
		# lands: ~1.9 steps/s walking, ~3.1 sprinting
		var before := floori(_bob_t / PI + 0.5)
		_bob_t += delta * hspeed * (2.2 if sprinting else 2.65)
		if floori(_bob_t / PI + 0.5) > before:
			_footstep(sprinting)
	else:
		_bob_t = lerpf(_bob_t, roundf(_bob_t / PI) * PI, delta * 4.0)
	var amp := 0.045 if sprinting else 0.028
	var bob := Vector3(cos(_bob_t * 0.5) * amp * 0.6, -absf(sin(_bob_t)) * amp, 0)
	# shake
	_shake = maxf(0.0, _shake - delta * 1.2)
	_shake_t += delta * 40.0
	var sh := _shake * _shake
	var shake_off := Vector3(sin(_shake_t * 1.3) * sh * 0.05, cos(_shake_t * 1.7) * sh * 0.05, 0)
	head.position = Vector3(0, EYE_HEIGHT, 0) + bob + shake_off
	head.rotation.z = sin(_bob_t * 0.5) * (0.006 if not sprinting else 0.012) + sin(_shake_t) * sh * 0.03
	var target_fov: float = Game.settings.fov * (0.7 if camera_mode else 1.0) + (4.0 if sprinting and hspeed > 3.4 else 0.0)
	camera.fov = lerpf(camera.fov, target_fov, delta * 6.0)
	# flashlight sway (lags slightly behind the view)
	if flashlight_on:
		_fl_target = _fl_target.slerp(camera.global_basis, clampf(delta * 14.0, 0.0, 1.0))
		flashlight.global_basis = _fl_target
	else:
		_fl_target = camera.global_basis
	# --- interaction ray ---
	_update_interact()
	if terminal:
		var z := terminal.zone_at(global_position)
		if z != zone:
			zone = z
			Events.zone_entered.emit(z)


func _update_interact() -> void:
	var found: Interactable = null
	if controls_enabled and not cutscene and not camera_mode and eyes < 0.5:
		var space := get_world_3d().direct_space_state
		var from := camera.global_position
		var to := from - camera.global_basis.z * INTERACT_RANGE
		var q := PhysicsRayQueryParameters3D.create(from, to, Geo.LAYER_WORLD | Geo.LAYER_INTERACT)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if hit and hit.collider is Interactable and (hit.collider as Interactable).enabled:
			found = hit.collider
	var prompt := found.get_prompt() if found else ""
	if found != current_interactable or prompt != current_prompt:
		current_interactable = found
		current_prompt = prompt
		interact_target_changed.emit(prompt)


func _footstep(sprinting: bool) -> void:
	var surface := "tile"
	if terminal:
		var p := global_position
		match zone:
			"gates":
				surface = "tile" if absf(p.x) < 3.0 else "carpet"
			"bridge0":
				surface = "carpet"
			"office", "storage", "maint":
				surface = "tileroom"
	if conveyor_vel.length() > 0.01 or _on_metal():
		surface = "metal"
	var s := Snd.stream(Snd.variant("footstep_" + surface))
	if s == null:
		return
	_feet_i = (_feet_i + 1) % _feet_pool.size()
	_feet = _feet_pool[_feet_i]
	_feet.stream = s
	# steady steps: only a light touch of variation on top of the takes themselves
	_feet.volume_db = (-4.0 if sprinting else -8.0) + STEP_DB.get(surface, 0.0) + randf_range(-0.6, 0.6)
	_feet.pitch_scale = randf_range(0.97, 1.03)
	_feet.play()


func _on_metal() -> bool:
	if not is_on_floor():
		return false
	for i in get_slide_collision_count():
		var col := get_slide_collision(i).get_collider()
		if col and col.has_meta("conveyor"):
			return true
	return false


func _update_breath(delta: float) -> void:
	var want := stamina < STAMINA_MAX * 0.35
	if want and not _breath.playing:
		_breath.stream = Snd.stream("breath_loop")
		if _breath.stream:
			_breath.volume_db = -30.0
			_breath.play()
	if _breath.playing:
		var target := -14.0 if want else -60.0
		_breath.volume_db = move_toward(_breath.volume_db, target, delta * 20.0)
		if not want and _breath.volume_db <= -59.0:
			_breath.stop()


func add_shake(amount: float) -> void:
	_shake = clampf(_shake + amount, 0.0, 1.0)


func forward() -> Vector3:
	return -camera.global_basis.z


## Dot of view direction vs. direction to a point (1 = looking straight at it).
func facing_dot(p: Vector3) -> float:
	var to := p - camera.global_position
	if to.length() < 0.01:
		return 1.0
	return forward().dot(to.normalized())


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()
