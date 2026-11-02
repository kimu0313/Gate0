class_name RepeatRoom
extends Node3D
## B, the repeating room: one room, built far below the terminal, that you walk through again and again. It is the
## size of a shop unit, empty but for a desk, a chair and a door at each end. Local frame: you come in at the south door
## (z 0) and leave by the north door (z -LENGTH); a black vestibule stands behind each, the same depth, so stepping into
## the north one and being put in the south one (`step` metres back) cannot be seen.

const ORIGIN := Vector3(640, -420, 0)
const W := 7.0
const LENGTH := 5.5
const H := 3.0
const STEP := LENGTH + 2.4       # north vestibule to south vestibule
const DOOR_Z := -LENGTH

var entry: Dictionary            # OfficeKit.door: {root, leaf, block, use}
var exit_door: Dictionary
var beyond: Area3D               # in the north vestibule
var desk_drawers: Array[Drawer] = []
var badge_name: Label3D
var badge_role: Label3D
var badge_photo: MeshInstance3D
var card_node: Node3D
var chair: Node3D
var switches: Array[Node3D] = []   # the wall switches, each with an Interactable
var switch_uses: Array[Interactable] = []
var _lamps: Array[Array] = []    # [panel, light]
var _bags: Array[Node3D] = []


func build(terminal: Terminal) -> void:
	name = "RepeatRoom"
	position = ORIGIN
	var wall := Mats.shader_mat("res://shaders/wall_panel.gdshader", {"color": Color(0.7, 0.71, 0.68),
			"seam_color": Color(0.52, 0.53, 0.5), "panel_w": 1.2, "panel_h": 3.0, "base_height": ORIGIN.y})
	var floor_m := Mats.shader_mat("res://shaders/floor_tile.gdshader", {"color_a": Color(0.5, 0.5, 0.48),
			"color_b": Color(0.46, 0.46, 0.44), "grout_color": Color(0.34, 0.34, 0.33), "tile_size": 0.6,
			"roughness_base": 0.25, "roughness_var": 0.2})
	var hw := W * 0.5
	var mid := -LENGTH * 0.5
	Geo.box(self, Vector3(0, -0.05, mid), Vector3(W + 0.6, 0.1, LENGTH + 6.0), floor_m)
	Geo.box(self, Vector3(0, H + 0.1, mid), Vector3(W + 0.6, 0.2, LENGTH + 0.6), Mats.get_mat("ceiling"), false)
	for sx in [-1.0, 1.0]:
		Geo.box(self, Vector3(sx * (hw + 0.15), H * 0.5, mid), Vector3(0.3, H, LENGTH + 0.6), wall)
	for z: float in [0.0, DOOR_Z]:
		Geo.wall(self, Vector2(-hw, z), Vector2(hw, z), H, wall, 0.3, [[hw - 0.475, hw + 0.475, 2.13]])
	entry = OfficeKit.door(self, Vector3(0, 0, 0), PI / 2)
	exit_door = OfficeKit.door(self, Vector3(0, 0, DOOR_Z), -PI / 2)
	# black behind both doors
	var black := Mats.get_mat("void")
	for z: float in [1.2, DOOR_Z - 1.2]:
		Geo.box(self, Vector3(0, 2.3, z), Vector3(1.8, 0.1, 2.4), black)
		for sx in [-1.0, 1.0]:
			Geo.box(self, Vector3(sx * 0.9, 1.15, z), Vector3(0.1, 2.4, 2.4), black)
	Geo.box(self, Vector3(0, 1.15, 2.45), Vector3(1.8, 2.4, 0.1), black)
	Geo.box(self, Vector3(0, 1.15, DOOR_Z - 2.45), Vector3(1.8, 2.4, 0.1), black)
	beyond = Geo.area(self, Vector3(0, 1.0, DOOR_Z - 1.2), Vector3(1.6, 2.0, 0.5))
	for at: Vector3 in [Vector3(-1.6, H - 0.03, -1.4), Vector3(1.6, H - 0.03, -1.4), Vector3(-1.6, H - 0.03, -4.1), Vector3(1.6, H - 0.03, -4.1)]:
		var panel := Geo.box(self, at, Vector3(1.2, 0.05, 0.4), Mats.emissive(Color(0.92, 0.96, 0.9), 2.4), false)
		var l := Geo.omni(self, at + Vector3(0, -0.5, 0), Color(0.9, 0.96, 0.88), 1.5, 8.0)
		l.light_specular = 0.2
		l.light_volumetric_fog_energy = 0.0
		_lamps.append([panel, l])
	# the desk: its drawers, the staff badge on it
	desk_drawers = OfficeKit.desk(self, Vector3(-1.6, 0, -2.9), PI / 2, Vector3(1.5, 0.76, 0.75), 1.0, true)
	chair = Node3D.new()
	add_child(chair)
	chair.position = Vector3(-0.8, 0, -2.9)
	Geo.box(chair, Vector3(0, 0.45, 0), Vector3(0.46, 0.05, 0.46), Mats.std(Color(0.2, 0.21, 0.23), 0.7), false)
	Geo.box(chair, Vector3(0.22, 0.72, 0), Vector3(0.05, 0.5, 0.44), Mats.std(Color(0.2, 0.21, 0.23), 0.7), false)
	Geo.cyl(chair, Vector3(0, 0.22, 0), 0.03, 0.44, Mats.get_mat("metal"), false, 10)
	var badge := Node3D.new()
	add_child(badge)
	badge.position = Vector3(-1.6, 0.765, -2.9)
	badge.rotation.y = -PI / 2 + 0.15
	Geo.box(badge, Vector3.ZERO, Vector3(0.2, 0.006, 0.13), Mats.get_mat("plastic_white"), false)
	badge_photo = Geo.box(badge, Vector3(-0.06, 0.004, 0), Vector3(0.06, 0.002, 0.08), Mats.std(Color(0.35, 0.38, 0.42), 0.7), false)
	badge_name = Geo.label(badge, "", Vector3(0.04, 0.0045, -0.018), 0.0, 40, Color(0.08, 0.09, 0.12), 0.0013, false, "print")
	badge_name.rotation.x = -PI / 2
	badge_name.set_meta("no_fit", true)
	badge_role = Geo.label(badge, "", Vector3(0.04, 0.0045, 0.024), 0.0, 26, Color(0.1, 0.2, 0.5), 0.0012, false, "print")
	badge_role.rotation.x = -PI / 2
	badge_role.set_meta("no_fit", true)
	# the card you take in the last room, beside the badge
	card_node = Node3D.new()
	add_child(card_node)
	card_node.position = Vector3(-1.45, 0.765, -3.25)
	card_node.visible = false
	Geo.box(card_node, Vector3.ZERO, Vector3(0.09, 0.004, 0.056), Mats.std(Color(0.12, 0.25, 0.65), 0.5), false)
	# wall switches, one shown at a time
	for s: Array in [[Vector3(hw - 0.02, 1.25, -1.2), -PI / 2], [Vector3(-hw + 0.02, 1.25, -4.6), PI / 2], [Vector3(hw - 0.02, 1.25, -4.3), -PI / 2]]:
		var sw := Node3D.new()
		add_child(sw)
		sw.position = s[0]
		sw.rotation.y = s[1]
		Geo.box(sw, Vector3(0, 0, 0.02), Vector3(0.12, 0.18, 0.04), Mats.get_mat("plastic_white"), false)
		Geo.box(sw, Vector3(0, 0.03, 0.05), Vector3(0.05, 0.08, 0.03), Mats.get_mat("lamp_red"), false)
		switches.append(sw)
		var use := Interactable.create(sw, Vector3(0, 0, 0.08), Vector3(0.3, 0.35, 0.18), "스위치 올리기", Callable())
		switch_uses.append(use)
	for i in 5:
		var bag := Props.suitcase(self, Color.from_hsv(0.08 + i * 0.1, 0.25, 0.3))
		bag.position = Vector3(1.0 + (i % 2) * 0.7, 0.0, -0.9 - i * 0.75)
		bag.rotation.y = i * 1.1
		bag.visible = false
		_bags.append(bag)


## How the room stands the `k`-th time you walk in: a light fewer, a bag more, the chair turned further from the desk,
## the badge a little further from being yours.
func dress(k: int, player_name: String) -> void:
	for i in _lamps.size():
		var on := i < _lamps.size() - k / 2
		(_lamps[i][0] as MeshInstance3D).visible = on
		(_lamps[i][1] as OmniLight3D).visible = on
	for i in _bags.size():
		_bags[i].visible = i < k
	chair.rotation.y = k * 0.5
	var names := [player_name, player_name, player_name.substr(0, 1) + "··", "승객", "승객"]
	var roles := ["STAFF", "STAFF", "STA···", "PASS···", "PASSENGER"]
	var photo := [Color(0.35, 0.38, 0.42), Color(0.3, 0.3, 0.33), Color(0.22, 0.22, 0.24), Color(0.14, 0.14, 0.15), Color(0.04, 0.04, 0.045)]
	Geo.set_text(badge_name, names[mini(k, 4)])
	Geo.set_text(badge_role, roles[mini(k, 4)])
	badge_photo.material_override = Mats.std(photo[mini(k, 4)], 0.7)
