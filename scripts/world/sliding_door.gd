class_name SlidingDoor
extends Node3D
## Two-leaf sliding door (glass or metal). Can auto-open by proximity, or be driven by script.

signal opened
signal closed

var width := 2.0
var height := 2.4
var is_open := false
var locked := false
var auto := false
var _left: MeshInstance3D
var _right: MeshInstance3D
var _blocker: StaticBody3D
var _sensor: Area3D
var _inside := 0
var _close_timer := 0.0
var hold_open := 0.0


static func create(parent: Node3D, pos: Vector3, rot_y: float, w := 2.0, h := 2.4, glass := true, auto_open := false) -> SlidingDoor:
	var d := SlidingDoor.new()
	d.width = w
	d.height = h
	d.auto = auto_open
	parent.add_child(d)
	d.position = pos
	d.rotation.y = rot_y
	d._build(glass)
	return d


func _build(glass: bool) -> void:
	var mat := Mats.get_mat("glass") if glass else Mats.get_mat("shutter")
	var leaf := Vector3(width * 0.5, height, 0.05)
	_left = Geo.box(self, Vector3(-width * 0.25, height * 0.5, 0), leaf, mat, false)
	_right = Geo.box(self, Vector3(width * 0.25, height * 0.5, 0), leaf, mat, false)
	if glass:
		for leaf_node in [_left, _right]:
			var frame := Mats.get_mat("steel_frame")
			Geo.box(leaf_node, Vector3(0, height * 0.5 - 0.03, 0), Vector3(width * 0.5, 0.06, 0.07), frame, false)
			Geo.box(leaf_node, Vector3(0, -height * 0.5 + 0.05, 0), Vector3(width * 0.5, 0.1, 0.07), frame, false)
			Geo.box(leaf_node, Vector3(0, 0, 0), Vector3(width * 0.5 - 0.1, 0.05, 0.06), Mats.get_mat("plastic_dark"), false)
	# header: its underside 5 mm below the opening top, so it never shares a plane with the wall lintel above
	Geo.box(self, Vector3(0, height + 0.115, 0), Vector3(width + 0.3, 0.24, 0.3), Mats.get_mat("metal_dark"), false)
	_blocker = Geo.blocker(self, Vector3(0, height * 0.5, 0), Vector3(width, height, 0.25))
	if auto:
		_sensor = Geo.area(self, Vector3(0, 1.0, 0), Vector3(width + 0.6, 2.0, 4.0))
		_sensor.body_entered.connect(func(_b): _inside += 1)
		_sensor.body_exited.connect(func(_b): _inside = maxi(0, _inside - 1))


func _process(delta: float) -> void:
	if hold_open > 0.0:
		hold_open -= delta
	if auto and not locked:
		if _inside > 0 and not is_open:
			open()
		elif _inside == 0 and is_open and hold_open <= 0.0:
			_close_timer += delta
			if _close_timer > 1.2:
				close()
		else:
			_close_timer = 0.0


func open(silent := false) -> void:
	if is_open:
		return
	is_open = true
	_close_timer = 0.0
	_blocker.collision_layer = 0
	if not silent:
		Snd.play_at("door_slide", global_position + Vector3(0, 2, 0), -4.0, randf_range(0.95, 1.05), 5.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(_left, "position:x", -width * 0.75 + 0.05, 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_property(_right, "position:x", width * 0.75 - 0.05, 0.9).set_trans(Tween.TRANS_SINE)
	opened.emit()


func close(silent := false) -> void:
	if not is_open:
		return
	is_open = false
	_blocker.collision_layer = Geo.LAYER_WORLD
	if not silent:
		Snd.play_at("door_slide", global_position + Vector3(0, 2, 0), -6.0, randf_range(0.9, 1.0), 5.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(_left, "position:x", -width * 0.25, 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_property(_right, "position:x", width * 0.25, 0.9).set_trans(Tween.TRANS_SINE)
	closed.emit()
