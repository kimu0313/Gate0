class_name CardReader
extends Node3D
## Staff card reader next to a door. The director decides whether access is granted.

signal swiped(reader: CardReader)

var display: Label3D
var led: MeshInstance3D
var interactable: Interactable


static func create(parent: Node3D, pos: Vector3, rot_y: float) -> CardReader:
	var r := CardReader.new()
	parent.add_child(r)
	r.position = pos
	r.rotation.y = rot_y
	r._build()
	return r


func _build() -> void:
	Geo.box(self, Vector3(0, 0, 0.02), Vector3(0.12, 0.18, 0.04), Mats.get_mat("plastic_dark"), false)
	Geo.box(self, Vector3(0, 0.035, 0.041), Vector3(0.09, 0.05, 0.002), Mats.get_mat("screen_off"), false)
	display = Geo.label(self, "STAFF", Vector3(0, 0.035, 0.043), 0.0, 14, Color(0.4, 0.8, 1.0), 0.0018, true)
	led = Geo.box(self, Vector3(0, -0.05, 0.042), Vector3(0.03, 0.012, 0.004), Mats.get_mat("lamp_amber"), false)
	interactable = Interactable.create(self, Vector3(0, 0, 0.06), Vector3(0.2, 0.25, 0.1), "출입카드 태그", func(): swiped.emit(self))
	interactable.press_sound = "card_beep"


func show_result(granted: bool, text := "") -> void:
	if granted:
		Geo.set_text(display, text if text != "" else "OK")
		display.modulate = Color(0.4, 1.0, 0.5)
		led.material_override = Mats.get_mat("lamp_green")
		Snd.play_at("beep_ok", global_position, -6.0, 1.0, 4.0)
	else:
		Geo.set_text(display, text if text != "" else "DENIED")
		display.modulate = Color(1.0, 0.3, 0.25)
		led.material_override = Mats.get_mat("lamp_red")
		Snd.play_at("beep_error", global_position, -2.0, 1.0, 6.0)
	var t := create_tween()
	t.tween_interval(2.5)
	t.tween_callback(func():
		Geo.set_text(display, "STAFF")
		display.modulate = Color(0.4, 0.8, 1.0)
		led.material_override = Mats.get_mat("lamp_amber"))
