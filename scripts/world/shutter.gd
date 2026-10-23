class_name Shutter
extends Node3D
## Roller shutter that closes off unopened zones.

var width := 4.0
var height := 4.0
var is_open := false
var _curtain: MeshInstance3D
var _blocker: StaticBody3D


static func create(parent: Node3D, pos: Vector3, rot_y: float, w: float, h: float, label_text := "") -> Shutter:
	var s := Shutter.new()
	s.width = w
	s.height = h
	parent.add_child(s)
	s.position = pos
	s.rotation.y = rot_y
	s._build(label_text)
	return s


func _build(label_text: String) -> void:
	var mat := Mats.shader_mat("res://shaders/wall_panel.gdshader", {
		"color": Color(0.38, 0.39, 0.4), "seam_color": Color(0.16, 0.16, 0.17),
		"panel_w": 100.0, "panel_h": 0.11, "roughness": 0.4, "skirting": 0.0})
	_curtain = Geo.box(self, Vector3(0, height * 0.5, 0), Vector3(width, height, 0.08), mat, false)
	_blocker = Geo.blocker(self, Vector3(0, height * 0.5, 0), Vector3(width, height, 0.3))
	var face := 0.05
	if TripoProps.exists("baggage", "BAG_ShutterFrame"):
		face = _tripo_bays()
	else:
		Geo.box(self, Vector3(0, height + 0.25, 0), Vector3(width + 0.3, 0.5, 0.5), Mats.get_mat("metal_dark"), false)
	if label_text != "":
		for side in [0.0, PI]:
			var z := face if side == 0.0 else -face
			var plate := Node3D.new()
			_curtain.add_child(plate)
			plate.position = Vector3(0, -height * 0.5 + 1.6, z)
			plate.rotation.y = side
			Geo.box(plate, Vector3(0, 0, 0.005), Vector3(1.6, 0.42, 0.01), Mats.get_mat("yellow_paint"), false)
			Geo.label(plate, label_text, Vector3(0, 0, 0.012), 0.0, 36, Color(0.08, 0.06, 0.02), 0.0045, false, "print")


## Tripo shutter bays (about 3 m each) across the opening: static frames (housing + guides) and their slatted
## curtains, the curtains parented to the old curtain node (its box mesh dropped) so open/close move them all.
## Returns the curtain's half depth for the warning plates.
func _tripo_bays() -> float:
	_curtain.mesh = null
	var bays := maxi(1, int(round(width / 3.0)))
	var bay_w := width / bays
	var half := 0.05
	for i in bays:
		var x := -width * 0.5 + bay_w * (i + 0.5)
		var frame := TripoProps.spawn(self, "baggage", "BAG_ShutterFrame", Vector3(x, 0, 0), 0.0, false, null,
				Vector3(bay_w + 0.3 / bays, height + 0.45, 0.5))
		frame.position.y = 0.0
		var c := TripoProps.spawn(_curtain, "baggage", "BAG_ShutterCurtain", Vector3.ZERO, 0.0, false, null,
				Vector3(bay_w - 0.04, height, 0.0))
		TripoProps.centre_on(c, Vector3(x, 0, 0))
		half = maxf(half, TripoProps.bounds(c).size.z * 0.5 + 0.01)
	return half


func open(instant := false) -> void:
	if is_open:
		return
	is_open = true
	_blocker.process_mode = Node.PROCESS_MODE_DISABLED
	_blocker.collision_layer = 0
	if instant:
		_curtain.position.y = height * 1.5 - 0.1
		_curtain.scale.y = 0.04
		return
	Snd.play_at("shutter_roll", global_position + Vector3(0, height, 0), 0.0, 1.0, 10.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(_curtain, "position:y", height * 1.5 - 0.1, 2.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(_curtain, "scale:y", 0.04, 2.4).set_trans(Tween.TRANS_SINE)


func close(instant := false) -> void:
	if not is_open:
		return
	is_open = false
	_blocker.collision_layer = Geo.LAYER_WORLD
	_blocker.process_mode = Node.PROCESS_MODE_INHERIT
	if instant:
		_curtain.position.y = height * 0.5
		_curtain.scale.y = 1.0
		return
	Snd.play_at("shutter_roll", global_position + Vector3(0, height, 0), 0.0, 0.9, 10.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(_curtain, "position:y", height * 0.5, 2.0)
	t.tween_property(_curtain, "scale:y", 1.0, 2.0)
