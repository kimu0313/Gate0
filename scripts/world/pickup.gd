class_name Pickup
extends Node3D
## A readable / collectable object (documents, binder, revision pages, plaque).

signal picked(pickup: Pickup)

var item_id := ""
var kind := "paper"     # paper | binder | folder | plaque
var interactable: Interactable
var keep_after_pick := false
var _glint: OmniLight3D


static func create(parent: Node3D, pos: Vector3, rot_y: float, id_text: String, prompt: String, kind_name := "paper") -> Pickup:
	var p := Pickup.new()
	p.item_id = id_text
	p.kind = kind_name
	parent.add_child(p)
	p.position = pos
	p.rotation.y = rot_y
	p._build(prompt)
	return p


func _build(prompt: String) -> void:
	match kind:
		"binder":
			Geo.box(self, Vector3(0, 0.035, 0), Vector3(0.26, 0.07, 0.32), Mats.std(Color(0.08, 0.12, 0.28), 0.5), false)
			Geo.box(self, Vector3(0.0, 0.072, 0.0), Vector3(0.2, 0.002, 0.08), Mats.get_mat("paper"), false)
			Geo.label(self, "근무 수칙", Vector3(0, 0.075, 0), 0.0, 22, Color(0.1, 0.1, 0.1), 0.0025, false, "print").rotation.x = -PI / 2
		"folder":
			Geo.box(self, Vector3(0, 0.01, 0), Vector3(0.24, 0.02, 0.32), Mats.std(Color(0.75, 0.6, 0.3), 0.7), false)
			Geo.box(self, Vector3(0.01, 0.022, 0.0), Vector3(0.21, 0.004, 0.29), Mats.get_mat("paper"), false)
		"plaque":
			var plate := Geo.box(self, Vector3(0, 0.3, 0), Vector3(0.7, 0.5, 0.04), Mats.std(Color(0.4, 0.28, 0.12), 0.35, 0.8), false)
			plate.rotation.x = -0.25
			var l := Geo.fit(Geo.label(plate, "추모\n1987. 11. 3.\n서해비행장 0편\n탑승객 41명을 기리며", Vector3(0, 0, 0.022), 0.0, 26, Color(0.15, 0.1, 0.03), 0.0035, false, "engrave"), 0.62, 0.42)
			l.name = "PlaqueText"
		_:
			var sheet := Geo.box(self, Vector3(0, 0.002, 0), Vector3(0.21, 0.003, 0.297), Mats.get_mat("paper"), false)
			sheet.rotation.y = randf_range(-0.2, 0.2)
			for i in 6:
				Geo.box(sheet, Vector3(-0.02, 0.0025, -0.1 + i * 0.03), Vector3(0.15, 0.001, 0.006), Mats.std(Color(0.3, 0.3, 0.32), 0.9), false)   # on the sheet, not buried in it
	interactable = Interactable.create(self, Vector3(0, 0.1, 0), Vector3(0.45, 0.3, 0.45) if kind != "plaque" else Vector3(0.8, 0.7, 0.3), prompt, _on_used)
	interactable.press_sound = "page_flip" if kind != "plaque" else ""
	_glint = Geo.omni(self, Vector3(0, 0.35, 0), Color(1.0, 0.95, 0.8), 0.12, 1.2)
	_glint.light_volumetric_fog_energy = 0.0


func _on_used() -> void:
	picked.emit(self)
	if not keep_after_pick:
		queue_free()
	else:
		_glint.light_energy = 0.0
