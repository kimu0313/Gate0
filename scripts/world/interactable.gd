class_name Interactable
extends StaticBody3D
## Something the player can aim at and press [E] on. Collision layer 3 (value 4).

signal used

var prompt := "사용"
var enabled := true
var callback: Callable
## Optional node that visually "presses" (moves along -press_axis) when used.
var press_node: Node3D
var press_axis := Vector3.FORWARD
var press_sound := "button_press"


static func create(parent: Node, pos: Vector3, size: Vector3, prompt_text: String, cb: Callable, rot_y := 0.0) -> Interactable:
	var it := Interactable.new()
	it.prompt = prompt_text
	it.callback = cb
	it.collision_layer = Geo.LAYER_INTERACT
	it.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	it.add_child(cs)
	parent.add_child(it)
	it.position = pos
	it.rotation.y = rot_y
	return it


func get_prompt() -> String:
	return prompt


func interact() -> void:
	if not enabled:
		return
	if press_node:
		var base := press_node.position
		var t := press_node.create_tween()
		t.tween_property(press_node, "position", base - press_axis * 0.012, 0.06)
		t.tween_property(press_node, "position", base, 0.12)
	if press_sound != "":
		Snd.play_at(press_sound, global_position, -4.0, randf_range(0.95, 1.05), 3.0)
	used.emit()
	if callback.is_valid():
		callback.call()
