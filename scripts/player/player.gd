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
var _step_dist := 0.0
var _shake := 0.0
var _shake_t := 0.0
var _feet: AudioStreamPlayer3D
var _breath: AudioStreamPlayer
var _fl_target := Basis()
var _forced_look: Tween


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
	_feet = AudioStreamPlayer3D.new()
	add_child(_feet)
	_feet.position = Vector3(0, 0.05, 0)
	_feet.unit_size = 4.0
	_feet.bus = "SFX"
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


## Smoothly turns the camera to look at a world point (cutscenes / scares).
func look_at_point(p: Vector3, duration := 0.6) -> void:
	var to := p - camera.global_position
	var yaw := atan2(-to.x, -to.z)
	var pitch := atan2(to.y, Vector2(to.x, to.z).length())
	var dyaw := wrapf(yaw - _yaw, -PI, PI)
	if _forced_look and _forced_look.is_valid():
		_forced_look.kill()
	_forced_look = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_forced_look.tween_method(func(v): set_look(v, _pitch), _yaw, _yaw + dyaw, duration)
	_forced_look.tween_method(func(v): set_look(_yaw, v), _pitch, pitch, duration)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED and look_enabled:
		var sens: float = 0.0022 * float(Game.settings.mouse_sensitivity)
		if camera_mode:
			sens *= 0.6
		_yaw -= event.relative.x * sens
		var inv := -1.0 if Game.settings.invert_y else 1.0
		_pitch = clampf(_pitch - event.relative.y * sens * inv, deg_to_rad(-85), deg_to_rad(85))
		rotation.y = _yaw
		head.rotation.x = _pitch
	if not controls_enabled:
		return
	if event.is_action_pressed("flashlight"):
		toggle_flashlight()
	elif event.is_action_pressed("interact") and not camera_mode:
		if current_interactable and is_instance_valid(current_interactable):
			current_interactable.interact()


func toggle_flashlight(force := -1) -> void:
	flashlight_on = not flashlight_on if force < 0 else force == 1
	flashlight.visible = flashlight_on
	flashlight.light_energy = 2.6 if flashlight_on else 0.0
	Snd.play("button_press", -10.0, 1.6, "SFX")


func _physics_process(delta: float) -> void:
	# --- eyes ---
	var want_closed := controls_enabled and Input.is_action_pressed("close_eyes") and not camera_mode
	eyes = move_toward(eyes, 1.0 if want_closed else 0.0, delta * (4.5 if want_closed else 3.0))
	if eyes >= 0.98:
		eyes_closed_time += delta
	else:
		eyes_closed_time = 0.0
	Snd.set_muffle(eyes * 0.85)
	# --- movement ---
	var input := Vector2.ZERO
	if controls_enabled:
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
		_bob_t += delta * hspeed * 2.3
		_step_dist += hspeed * delta
		var stride := 1.8 if sprinting else 1.5
		if _step_dist >= stride * 0.5:
			_step_dist = 0.0
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
	if controls_enabled and not camera_mode and eyes < 0.5:
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
			"storage", "maint":
				surface = "tile"
	if conveyor_vel.length() > 0.01 or _on_metal():
		surface = "metal"
	var s := Snd.stream(Snd.random_variant("footstep_" + surface, 4))
	if s == null:
		return
	_feet.stream = s
	_feet.volume_db = (-6.0 if sprinting else -11.0) + randf_range(-1.5, 1.0)
	_feet.pitch_scale = randf_range(0.92, 1.08)
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
