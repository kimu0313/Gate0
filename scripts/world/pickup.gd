class_name Pickup
extends Node3D
## A readable / collectable object (documents, binder, revision pages, plaque).

signal picked(pickup: Pickup)

var item_id := ""
var kind := "paper"     # paper | wallpage (a page clipped to a wall) | binder | folder | plaque | tape
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
			# a rusted bronze memorial on a short post, left standing in a corner
			var iron := Mats.std(Color(0.2, 0.13, 0.08), 0.9, 0.3)
			Geo.box(self, Vector3(0, 0.03, 0), Vector3(0.44, 0.06, 0.32), Mats.std(Color(0.42, 0.41, 0.38), 0.95), false)
			Geo.box(self, Vector3(0, 0.5, 0), Vector3(0.07, 0.9, 0.07), iron, false)
			var plate := Geo.box(self, Vector3(0, 1.02, 0.02), Vector3(0.62, 0.44, 0.035), Mats.std(Color(0.2, 0.13, 0.07), 0.85, 0.4), false)
			plate.rotation.x = -0.32
			plate.rotation.z = 0.04          # sagged a little on its bolts
			for r in [[-0.22, 0.15, 0.1, 0.06, Color(0.28, 0.38, 0.3)], [0.2, -0.13, 0.14, 0.07, Color(0.48, 0.22, 0.07)],
					[0.24, 0.16, 0.06, 0.08, Color(0.44, 0.2, 0.06)], [-0.18, -0.16, 0.12, 0.05, Color(0.26, 0.35, 0.28)]]:
				Geo.box(plate, Vector3(r[0], r[1], 0.0182), Vector3(r[2], r[3], 0.001), Mats.std(r[4], 1.0), false)   # rust and verdigris
			# raised letters, the only part still rubbed bright
			var l := Geo.fit(Geo.label(plate, "추　모\n1987. 11.\n서해비행장 A0편\n탑승객 41명", Vector3(0, 0.02, 0.019), 0.0, 26, Color(0.78, 0.62, 0.38), 0.0035, false, "engrave"), 0.5, 0.34)
			l.name = "PlaqueText"
		"wallpage":
			# a rule page clipped to the wall beside the facility (facing local +Z)
			Geo.box(self, Vector3(0, 0, 0.002), Vector3(0.21, 0.297, 0.003), Mats.get_mat("paper"), false)
			for i in 7:
				Geo.box(self, Vector3(-0.015, 0.08 - i * 0.025, 0.0038), Vector3(0.15, 0.006, 0.001), Mats.std(Color(0.3, 0.3, 0.32), 0.9), false)
			Geo.box(self, Vector3(0.06, -0.11, 0.0038), Vector3(0.04, 0.04, 0.001), Mats.std(Color(0.7, 0.12, 0.1), 0.7), false)   # red stamp
			Geo.box(self, Vector3(0, 0.15, 0.008), Vector3(0.07, 0.03, 0.012), Mats.get_mat("metal_dark"), false)              # clip
		"tape":
			Geo.box(self, Vector3(0, 0.008, 0), Vector3(0.1, 0.016, 0.064), Mats.std(Color(0.08, 0.08, 0.09), 0.4), false)
			Geo.box(self, Vector3(0, 0.0165, 0.004), Vector3(0.088, 0.001, 0.034), Mats.std(Color(0.88, 0.84, 0.7), 0.9), false)
			var tl := Geo.label(self, "A0 / 87.11.03", Vector3(0, 0.0172, 0.004), 0.0, 20, Color(0.1, 0.1, 0.12), 0.0011, false, "hand")
			tl.rotation.x = -PI / 2
		_:
			var sheet := Geo.box(self, Vector3(0, 0.002, 0), Vector3(0.21, 0.003, 0.297), Mats.get_mat("paper"), false)
			sheet.rotation.y = randf_range(-0.2, 0.2)
			for i in 6:
				Geo.box(sheet, Vector3(-0.02, 0.0025, -0.1 + i * 0.03), Vector3(0.15, 0.001, 0.006), Mats.std(Color(0.3, 0.3, 0.32), 0.9), false)   # on the sheet, not buried in it
	match kind:
		"plaque":
			interactable = Interactable.create(self, Vector3(0, 0.8, 0.05), Vector3(0.75, 1.0, 0.5), prompt, _on_used)
		"wallpage":
			interactable = Interactable.create(self, Vector3(0, 0, 0.1), Vector3(0.4, 0.45, 0.25), prompt, _on_used)
		_:
			interactable = Interactable.create(self, Vector3(0, 0.1, 0), Vector3(0.45, 0.3, 0.45), prompt, _on_used)
	interactable.press_sound = "page_flip" if kind != "plaque" and kind != "tape" else ""
	_glint = Geo.omni(self, Vector3(0, 0.35, 0) if kind != "wallpage" else Vector3(0, 0, 0.35), Color(1.0, 0.95, 0.8), 0.12, 1.2)
	_glint.light_volumetric_fog_energy = 0.0


func _on_used() -> void:
	picked.emit(self)
	if not keep_after_pick:
		queue_free()
	else:
		_glint.light_energy = 0.0
