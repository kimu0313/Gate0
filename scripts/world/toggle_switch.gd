class_name ToggleSwitch
extends Node3D
## Breaker module (DIN-rail MCB) with its toggle and a status flag, used on breaker / lighting panels, its circuit
## name on a label strip below. Local +Z = panel normal, origin on the dead-front plane.

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


static var _mats := {}


static func _mat(key: String) -> Material:
	if not _mats.has(key):
		match key:
			"module":
				_mats[key] = Mats.std(Color(0.9, 0.9, 0.88), 0.45)
			"shoulder":
				_mats[key] = Mats.std(Color(0.8, 0.8, 0.78), 0.45)
			"toggle":
				_mats[key] = Mats.std(Color(0.12, 0.2, 0.42), 0.4)
			"strip":
				_mats[key] = Mats.std(Color(0.95, 0.95, 0.93), 0.5)
	return _mats[key]


func _build() -> void:
	# the module body through the dead front, its raised toggle shoulder
	Geo.box(self, Vector3(0, 0, 0.012), Vector3(0.1, 0.13, 0.044), _mat("module"), false)
	Geo.box(self, Vector3(0, 0, 0.039), Vector3(0.1, 0.05, 0.01), _mat("shoulder"), false)
	_lever = Node3D.new()
	add_child(_lever)
	_lever.position = Vector3(0, 0, 0.044)
	Geo.box(_lever, Vector3(0, 0, 0.017), Vector3(0.034, 0.022, 0.034), _mat("toggle"), false)
	# status flag window above the toggle (green on, red tripped)
	_led_on = Mats.get_mat("lamp_green")
	_led_off = Mats.get_mat("lamp_red")
	_led = Geo.box(self, Vector3(0, 0.047, 0.0355), Vector3(0.034, 0.01, 0.003), _led_on, false)
	# circuit name on a label strip under the module (the strip runs back into the panel so audits see its face)
	Geo.box(self, Vector3(0, -0.1, -0.013), Vector3(0.13, 0.034, 0.03), _mat("strip"), false)
	var l := Geo.label(self, caption, Vector3(0, -0.1, 0.0035), 0.0, 24, Color(0.1, 0.1, 0.12), 0.0022, false, "print")
	var pad := Geo.label_margin(0.13, 0.034)
	Geo.fit(l, 0.13 - 2.0 * pad - 0.004, 0.034 - 2.0 * pad)
	l.set_meta("no_fit", true)
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
	var angle := -0.5 if is_on else 0.5        # toggle up = on
	if _lever:
		if instant:
			_lever.rotation.x = angle
		else:
			create_tween().tween_property(_lever, "rotation:x", angle, 0.12)
	if _led:
		_led.material_override = _led_on if is_on else _led_off
	if interactable:
		interactable.prompt = "%s %s" % [tr(caption), tr(off_prompt if is_on else on_prompt)]
