class_name MovingWalkway
extends Facility
## 무빙워크 MW-1. Built along -Z (toward the gates). Normal = 0.75 m/s toward the gates.
## Anomalies: walk_reverse (moves against the indicated direction), walk_fast (overspeed), auto_run.

const NORMAL_SPEED := 0.75

var length := 42.0
var width := 1.6
var speed := 0.0
var target_speed := 0.0
var direction := -1.0     # -1 = toward -Z (gates)
var offset := 0.0
var surface_mat: ShaderMaterial
var rail_mat: ShaderMaterial
var _motor: AudioStreamPlayer3D
var _ride_reported := false
var _arrow_labels: Array[Label3D] = []


func build(len_m := 42.0) -> void:
	length = len_m
	observe_radius = maxf(14.0, len_m * 0.5 + 4.0)   # focus is mid-belt: watching it from the control pedestal at either end counts
	surface_mat = Mats.shader_mat("res://shaders/conveyor.gdshader", {"axis": 2})
	rail_mat = Mats.shader_mat("res://shaders/conveyor.gdshader", {
		"axis": 2, "color": Color(0.03, 0.03, 0.03), "groove_color": Color(0.02, 0.02, 0.02),
		"metallic": 0.0, "roughness": 0.6, "pallet_length": 0.9})
	var mid_z := -length * 0.5
	# surface (with conveyor collider)
	var surf := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, 0.12, length)
	surf.mesh = bm
	surf.material_override = surface_mat
	add_child(surf)
	surf.position = Vector3(0, 0.06, mid_z)
	var body := StaticBody3D.new()
	body.collision_layer = Geo.LAYER_WORLD
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, 0.12, length)
	cs.shape = shape
	body.add_child(cs)
	surf.add_child(body)
	body.set_meta("conveyor", self)
	var tripo := TripoProps.exists("walkway", "SEC_WalkwayEnd")
	# comb plates
	for z in [0.4, -length - 0.4]:
		if tripo:
			Geo.blocker(self, Vector3(0, 0.06, z), Vector3(width + 0.2, 0.12, 0.8))   # the Tripo end units carry the plates
		else:
			Geo.box(self, Vector3(0, 0.06, z), Vector3(width + 0.2, 0.12, 0.8), Mats.get_mat("metal"), true)
	if tripo:
		_tripo_body()
	# balustrades (+ moving handrail below)
	for sx in [-1.0, 1.0]:
		var x: float = sx * (width * 0.5 + 0.08)
		if not tripo:
			Geo.box(self, Vector3(x, 0.2, mid_z), Vector3(0.16, 0.4, length + 1.2), Mats.get_mat("steel_frame"), true)
			Geo.box(self, Vector3(x, 0.68, mid_z), Vector3(0.03, 0.58, length + 0.8), Mats.get_mat("glass"), false)
		Geo.blocker(self, Vector3(x, 0.8, mid_z), Vector3(0.12, 1.6, length + 1.2))
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.09, 0.06, length + 1.4)
		rail.mesh = rm
		rail.material_override = rail_mat
		add_child(rail)
		rail.position = Vector3(x, 1.04 if tripo else 1.0, mid_z)   # rides on top of the Tripo handrail so its motion shows
		if not tripo:
			for z in [0.5, -length - 0.5]:
				Geo.cyl(self, Vector3(x, 0.5, z), 0.05, 1.0, Mats.get_mat("steel_frame"))
	# direction indicators (always show the *official* direction)
	for z in [1.3, -length - 1.3]:
		var post := Node3D.new()
		add_child(post)
		post.position = Vector3(width * 0.5 + 0.5, 0, z)
		Geo.box(post, Vector3(0, 0.55, 0), Vector3(0.18, 1.1, 0.18), Mats.get_mat("metal_dark"), true)
		var entry: bool = z > 0.0
		var face_rot := 0.0 if entry else PI
		var glyph_z := 0.095 if entry else -0.095
		if TripoProps.exists("common", "CMN_WallSign"):
			var plate := Node3D.new()
			post.add_child(plate)
			plate.position = Vector3(0, 1.0, 0.0)
			plate.rotation.y = face_rot
			Props.sign_body(plate, Vector3(0, 0, 0.09), Vector2(0.32, 0.32), 0.06)
			glyph_z = 0.125 if entry else -0.125
		var l := Geo.label(post, "▲" if entry else "⛔", Vector3(0, 1.0, glyph_z), face_rot, 72,
			Color(0.3, 1.0, 0.45) if entry else Color(1.0, 0.25, 0.2), 0.004)
		Geo.fit(l, 0.26, 0.26)
		l.set_meta("no_fit", true)
		_arrow_labels.append(l)
	var sign := Node3D.new()
	add_child(sign)
	sign.position = Vector3(0, 2.6, 1.0)
	Geo.box(sign, Vector3.ZERO, Vector3(2.5, 0.45, 0.08), Mats.get_mat("sign_back"), false)
	Geo.label(sign, "MW-1  ▲  탑승동 GATES", Vector3(0, 0, 0.045), 0.0, 44, Color(0.95, 0.95, 0.95), 0.005)
	Geo.cyl(sign, Vector3(0, 1.0, 0), 0.02, 2.0, Mats.get_mat("steel_frame"))
	focus = surf
	_motor = Snd.make_loop("walkway_loop", self, -10.0, 6.0, 30.0)
	_motor.position = Vector3(0, 0.3, -6.0)


## Tripo walkway units (stainless balustrades, newel ends, landing plates) along the belt: an entry unit at
## each end and straight sections between, widened so the balustrades straddle the moving surface; the
## conveyor-shader surface and handrails above stay the moving parts.
func _tripo_body() -> void:
	var span := length + 1.6                    # comb plate to comb plate
	var end_len := 3.0
	var mids := maxi(1, int(round((span - 2.0 * end_len) / 4.0)))
	var mid_len := (span - 2.0 * end_len) / mids
	var z0 := 0.8
	var w := width + 0.36
	for i in mids + 2:
		var is_end := i == 0 or i == mids + 1
		var seg := end_len if is_end else mid_len
		var zc := z0 - (end_len * 0.5 if i == 0 else end_len + mid_len * (i - 0.5) if not is_end else span - end_len * 0.5)
		var n := TripoProps.spawn(self, "walkway", "SEC_WalkwayEnd" if is_end else "SEC_WalkwayMid", Vector3(0, 0, zc), 0.0 if i == 0 else PI if is_end else 0.0)
		TripoProps.fit(n, Vector3(w, 1.05, seg))


func _process(delta: float) -> void:
	var want := target_speed if powered else 0.0
	speed = move_toward(speed, want, delta * 0.8)
	var v := speed * direction
	offset -= v * delta
	surface_mat.set_shader_parameter("offset", offset)
	rail_mat.set_shader_parameter("offset", offset * 1.04 if anomaly != "walk_fast" else offset * 0.6)
	_motor.pitch_scale = clampf(0.6 + speed / NORMAL_SPEED * 0.4, 0.5, 2.2)
	_motor.volume_db = lerpf(-34.0, -8.0, clampf(speed / NORMAL_SPEED, 0.0, 1.0))
	if speed > 0.02 and not _motor.playing:
		_motor.play(randf())
	elif speed <= 0.02 and _motor.playing:
		_motor.stop()


## World-space velocity applied to anything standing on the surface.
func get_conveyor_velocity() -> Vector3:
	return Vector3(0, 0, speed * direction)


## The player script calls this every physics frame while standing on the walkway.
func on_ridden() -> void:
	if speed < 0.2:
		return
	if (anomaly == "walk_reverse" or anomaly == "walk_fast" or anomaly == "auto_run") and not _ride_reported:
		_ride_reported = true
		act("ride_walkway", id)


func _on_start() -> void:
	target_speed = NORMAL_SPEED
	direction = 1.0 if anomaly == "walk_reverse" else -1.0
	if anomaly == "walk_fast":
		target_speed = 3.2
	_ride_reported = false


func _on_stop() -> void:
	target_speed = 0.0


func press_start() -> void:
	act("start", id)
	if not running:
		start(true)


func press_stop() -> void:
	act("stop", id)
	stop()


func press_estop() -> void:
	act("estop", id)
	target_speed = 0.0
	speed = 0.0
	running = false
	Snd.play_at("ui_alert", focus_position(), -6.0, 0.8, 8.0)
	changed.emit()


func _apply_anomaly(anomaly_id: String) -> void:
	_ride_reported = false
	match anomaly_id:
		"walk_reverse":
			direction = 1.0
		"walk_fast":
			if running:
				target_speed = 3.2
		"auto_run":
			start(false)


func _remove_anomaly(anomaly_id: String) -> void:
	direction = -1.0
	if anomaly_id == "walk_fast" and running:
		target_speed = NORMAL_SPEED


func describe_state() -> String:
	if not powered:
		return "전원 차단"
	return (tr("가동 중 %.1fm/s") % speed) if running else tr("정지")
