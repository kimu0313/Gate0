class_name ToggleSwitch
extends Node3D
## Lever switch with status LED, used on breaker / lighting panels. Local +Z = panel normal.

signal toggled(on: bool)

var is_on := true
var caption := ""
var locked := false
var locked_message := ""
var on_prompt := "켜기"
var off_prompt := "끄기"
var _lever: Node3D
var _led: MeshInstance3D
var _led_on: Material
var _led_off: Material
var interactable: Interactable


static func create(parent: Node3D, pos: Vector3, caption_text: String, start_on := true) -> ToggleSwitch:
	var s := ToggleSwitch.new()
	s.caption = caption_text
	s.is_on = start_on
	parent.add_child(s)
	s.position = pos
	s._build()
	return s


func _build() -> void:
	Geo.box(self, Vector3(0, 0, 0.01), Vector3(0.11, 0.2, 0.02), Mats.get_mat("plastic_dark"), false)
	_lever = Node3D.new()
	add_child(_lever)
	_lever.position = Vector3(0, 0, 0.025)
	Geo.box(_lever, Vector3(0, 0.05, 0.02), Vector3(0.035, 0.1, 0.035), Mats.get_mat("metal"), false)
	Geo.box(_lever, Vector3(0, 0.1, 0.03), Vector3(0.05, 0.03, 0.05), Mats.get_mat("plastic_white"), false)
	_led_on = Mats.get_mat("lamp_green")
	_led_off = Mats.get_mat("lamp_red")
	_led = Geo.box(self, Vector3(0, 0.14, 0.02), Vector3(0.03, 0.02, 0.01), _led_on, false)
	Geo.label(self, caption, Vector3(0, -0.14, 0.022), 0.0, 22, Color(0.92, 0.92, 0.92), 0.0022, false, "print")
	interactable = Interactable.create(self, Vector3(0, 0, 0.05), Vector3(0.13, 0.24, 0.1), "", _on_used)
	interactable.press_sound = ""
	_refresh(true)


func set_on(on: bool, emit := false) -> void:
	if is_on == on:
		_refresh(false)
		return
	is_on = on
	_refresh(false)
	if emit:
		toggled.emit(on)


func _on_used() -> void:
	if locked:
		Snd.play_at("beep_error", global_position, -6.0)
		if locked_message != "":
			Events.notify.emit(locked_message, "bad")
		return
	Snd.play_at("switch_heavy", global_position, -3.0, randf_range(0.95, 1.05), 3.0)
	set_on(not is_on, true)


func _refresh(instant: bool) -> void:
	var angle := -0.6 if is_on else 0.6
	if _lever:
		if instant:
			_lever.rotation.x = angle
		else:
			create_tween().tween_property(_lever, "rotation:x", angle, 0.12)
	if _led:
		_led.material_override = _led_on if is_on else _led_off
	if interactable:
		interactable.prompt = "%s %s" % [tr(caption), tr(off_prompt if is_on else on_prompt)]
