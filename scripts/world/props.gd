class_name Props
extends RefCounted
## Prop builders. Facing convention: rot_y = 0 faces +Z, PI/2 faces +X, -PI/2 faces -X, PI faces -Z.


## Round push button on a panel. Returns the Interactable.
static func button(parent: Node3D, pos: Vector3, rot_y: float, mat_name: String, caption: String,
		prompt: String, cb: Callable, radius := 0.05) -> Interactable:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = pos
	holder.rotation.y = rot_y
	Geo.cyl(holder, Vector3(0, 0, 0.008), radius * 1.35, 0.016, Mats.get_mat("plastic_dark")).rotation.x = PI / 2
	var cap := Geo.cyl(holder, Vector3(0, 0, 0.03), radius, 0.03, Mats.get_mat(mat_name))
	cap.rotation.x = PI / 2
	if caption != "":
		Geo.label(holder, caption, Vector3(0, -radius - 0.045, 0.004), 0.0, 24, Color(0.9, 0.9, 0.9), 0.0024)
	var it := Interactable.create(holder, Vector3(0, 0, 0.03), Vector3(radius * 2.8, radius * 2.8, 0.1), prompt, cb)
	it.press_node = cap
	it.press_axis = Vector3(0, 0, 1)
	return it


## Wall-mounted control panel backing box. Returns holder Node3D (child space: +Z = panel normal).
static func panel_box(parent: Node3D, pos: Vector3, rot_y: float, size: Vector2, title := "", depth := 0.12) -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = pos
	holder.rotation.y = rot_y
	Geo.box(holder, Vector3(0, 0, -depth * 0.5), Vector3(size.x, size.y, depth), Mats.get_mat("plastic_grey"), true)
	Geo.box(holder, Vector3(0, 0, 0.001), Vector3(size.x - 0.04, size.y - 0.04, 0.004), Mats.get_mat("metal_dark"), false)
	if title != "":
		Geo.label(holder, title, Vector3(0, size.y * 0.5 - 0.07, 0.006), 0.0, 30, Color(0.95, 0.85, 0.3), 0.0025)
	return holder


static func pedestal(parent: Node3D, pos: Vector3, rot_y: float, title := "") -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = pos
	holder.rotation.y = rot_y
	Geo.box(holder, Vector3(0, 0.5, 0), Vector3(0.5, 1.0, 0.35), Mats.get_mat("metal_dark"), true)
	var top := Node3D.new()
	holder.add_child(top)
	top.position = Vector3(0, 1.08, 0.02)
	top.rotation.x = -0.6
	Geo.box(top, Vector3(0, 0, -0.03), Vector3(0.56, 0.36, 0.06), Mats.get_mat("plastic_grey"), false)
	if title != "":
		Geo.label(top, title, Vector3(0, 0.14, 0.004), 0.0, 26, Color(0.95, 0.85, 0.3), 0.0025)
	return top


static func seat_row(parent: Node3D, pos: Vector3, count: int, rot_y := 0.0, spacing := 0.62) -> Node3D:
	var row := Node3D.new()
	parent.add_child(row)
	row.position = pos
	row.rotation.y = rot_y
	var seat := Mats.get_mat("seat")
	var frame := Mats.get_mat("seat_frame")
	var width := spacing * count
	var x0 := -width * 0.5 + spacing * 0.5
	for i in count:
		var x := x0 + i * spacing
		Geo.box(row, Vector3(x, 0.44, 0.02), Vector3(spacing - 0.08, 0.07, 0.48), seat, false)
		var back := Geo.box(row, Vector3(x, 0.76, -0.23), Vector3(spacing - 0.08, 0.56, 0.06), seat, false)
		back.rotation.x = -0.12
	for i in count + 1:
		var x := -width * 0.5 + i * spacing
		Geo.box(row, Vector3(x, 0.6, 0.02), Vector3(0.04, 0.04, 0.42), frame, false)
		Geo.box(row, Vector3(x, 0.52, 0.18), Vector3(0.03, 0.16, 0.03), frame, false)
	Geo.box(row, Vector3(0, 0.3, -0.02), Vector3(width, 0.06, 0.08), frame, false)
	for x in [-width * 0.5 + 0.2, width * 0.5 - 0.2]:
		Geo.box(row, Vector3(x, 0.15, 0.05), Vector3(0.05, 0.3, 0.5), frame, false)
	Geo.blocker(row, Vector3(0, 0.45, 0), Vector3(width, 0.9, 0.62))
	return row


static func hanging_sign(parent: Node3D, pos: Vector3, rot_y: float, size: Vector2, lines: Array,
		ceiling_y := -1.0) -> Array[Label3D]:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = pos
	holder.rotation.y = rot_y
	Geo.box(holder, Vector3.ZERO, Vector3(size.x, size.y, 0.14), Mats.get_mat("sign_back"), false)
	var labels: Array[Label3D] = []
	for side in [0.0, PI]:
		for line in lines:
			# line: [text, font_size, color, Vector2 offset]
			var off: Vector2 = line[3] if line.size() > 3 else Vector2.ZERO
			var z := 0.075 if side == 0.0 else -0.075
			var x := off.x if side == 0.0 else -off.x
			var l := Geo.label(holder, str(line[0]), Vector3(x, off.y, z), side, int(line[1]), line[2], 0.006)
			labels.append(l)
	if ceiling_y > pos.y:
		var rod_h := ceiling_y - pos.y - size.y * 0.5
		for sx in [-size.x * 0.35, size.x * 0.35]:
			Geo.cyl(holder, Vector3(sx, size.y * 0.5 + rod_h * 0.5, 0), 0.015, rod_h, Mats.get_mat("steel_frame"))
	return labels


static func pillar(parent: Node3D, pos: Vector3, height: float, size := 1.0) -> void:
	Geo.box(parent, pos + Vector3(0, height * 0.5, 0), Vector3(size, height, size), Mats.get_mat("wall"))
	Geo.box(parent, pos + Vector3(0, 0.06, 0), Vector3(size + 0.04, 0.12, size + 0.04), Mats.get_mat("metal_dark"), false)


static func trash_bin(parent: Node3D, pos: Vector3) -> void:
	Geo.cyl(parent, pos + Vector3(0, 0.45, 0), 0.24, 0.9, Mats.get_mat("steel_frame"), true)
	Geo.cyl(parent, pos + Vector3(0, 0.91, 0), 0.25, 0.03, Mats.get_mat("plastic_dark"))


static func planter(parent: Node3D, pos: Vector3) -> void:
	Geo.box(parent, pos + Vector3(0, 0.35, 0), Vector3(0.9, 0.7, 0.9), Mats.get_mat("plastic_dark"))
	var leaf := Mats.std(Color(0.06, 0.12, 0.07), 0.8)
	Geo.sphere(parent, pos + Vector3(0, 1.1, 0), 0.5, leaf)
	Geo.sphere(parent, pos + Vector3(0.2, 1.5, 0.1), 0.35, leaf)


static func exit_sign(parent: Node3D, pos: Vector3, rot_y: float, text := "비상구  EXIT") -> MeshInstance3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = pos
	holder.rotation.y = rot_y
	var m := Geo.box(holder, Vector3.ZERO, Vector3(0.9, 0.3, 0.08), Mats.get_mat("exit_green"), false)
	Geo.label(holder, text, Vector3(0, 0, 0.045), 0.0, 40, Color(0.02, 0.15, 0.04), 0.004)
	var l := Geo.omni(holder, Vector3(0, -0.1, 0.3), Color(0.2, 1.0, 0.4), 0.35, 3.0)
	l.light_volumetric_fog_energy = 1.0
	return m


static func lightbox(parent: Node3D, pos: Vector3, rot_y: float, size: Vector2, text: String, sub := "") -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = pos
	holder.rotation.y = rot_y
	Geo.box(holder, Vector3(0, 0, -0.06), Vector3(size.x + 0.1, size.y + 0.1, 0.12), Mats.get_mat("metal_dark"), false)
	Geo.box(holder, Vector3.ZERO, Vector3(size.x, size.y, 0.02), Mats.get_mat("lightbox"), false)
	Geo.label(holder, text, Vector3(0, 0.15, 0.015), 0.0, 60, Color(0.05, 0.1, 0.22), 0.006)
	if sub != "":
		Geo.label(holder, sub, Vector3(0, -0.25, 0.015), 0.0, 26, Color(0.1, 0.15, 0.3), 0.006)
	return holder


## Hard-shell suitcase lying flat (as on a carousel). Returns the root node.
static func suitcase(parent: Node3D, color: Color, tag_text := "", soft := false) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var body_mat := Mats.std(color, 0.55 if soft else 0.3, 0.0 if soft else 0.15)
	var size := Vector3(0.48, 0.24 if not soft else 0.28, 0.7)
	Geo.box(root, Vector3(0, size.y * 0.5, 0), size, body_mat, false)
	if not soft:
		for z in [-0.18, 0.0, 0.18]:
			Geo.box(root, Vector3(0, size.y + 0.002, z), Vector3(size.x - 0.06, 0.004, 0.02), Mats.std(color.darkened(0.25), 0.4), false)
	Geo.box(root, Vector3(0, size.y * 0.5, 0.36), Vector3(0.2, 0.04, 0.03), Mats.get_mat("plastic_dark"), false)
	if tag_text != "":
		var tag := Node3D.new()
		root.add_child(tag)
		tag.position = Vector3(0.1, size.y + 0.012, 0.25)
		Geo.box(tag, Vector3.ZERO, Vector3(0.14, 0.005, 0.09), Mats.std(Color(0.95, 0.8, 0.1), 0.6), false)
		var l := Geo.label(tag, tag_text, Vector3(0, 0.004, 0), 0.0, 28, Color(0.05, 0.05, 0.05), 0.0018)
		l.rotation.x = -PI / 2
		l.name = "TagLabel"
	return root


## Featureless dark passenger silhouette.
static func figure(parent: Node3D, pos: Vector3, rot_y := 0.0, seated := true) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	root.rotation.y = rot_y
	var m := Mats.get_mat("figure")
	if seated:
		Geo.capsule(root, Vector3(0, 0.88, -0.05), 0.2, 0.75, m)
		var head := Geo.sphere(root, Vector3(0, 1.4, -0.02), 0.13, m)
		head.name = "Head"
		for x in [-0.1, 0.1]:
			Geo.box(root, Vector3(x, 0.52, 0.18), Vector3(0.14, 0.13, 0.45), m, false)
			Geo.box(root, Vector3(x, 0.24, 0.4), Vector3(0.12, 0.48, 0.12), m, false)
			Geo.box(root, Vector3(x * 2.4, 0.86, 0.05), Vector3(0.09, 0.5, 0.1), m, false).rotation.x = -0.3
	else:
		Geo.capsule(root, Vector3(0, 1.25, 0), 0.21, 0.8, m)
		var head2 := Geo.sphere(root, Vector3(0, 1.78, 0), 0.13, m)
		head2.name = "Head"
		for x in [-0.1, 0.1]:
			Geo.box(root, Vector3(x, 0.45, 0), Vector3(0.13, 0.9, 0.14), m, false)
			Geo.box(root, Vector3(x * 2.5, 1.15, 0), Vector3(0.09, 0.62, 0.1), m, false)
	return root


static func desk(parent: Node3D, pos: Vector3, size: Vector3, rot_y := 0.0) -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = pos
	holder.rotation.y = rot_y
	Geo.box(holder, Vector3(0, size.y - 0.02, 0), Vector3(size.x, 0.04, size.z), Mats.get_mat("wood"), false)
	for sx in [-1, 1]:
		Geo.box(holder, Vector3(sx * (size.x * 0.5 - 0.03), (size.y - 0.04) * 0.5, 0), Vector3(0.04, size.y - 0.04, size.z - 0.05), Mats.get_mat("metal_dark"), false)
	Geo.blocker(holder, Vector3(0, size.y * 0.5, 0), size)
	return holder


static func monitor(parent: Node3D, pos: Vector3, rot_y: float, size := Vector2(0.5, 0.3)) -> MeshInstance3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = pos
	holder.rotation.y = rot_y
	Geo.box(holder, Vector3(0, -0.1, -0.05), Vector3(0.06, 0.2, 0.06), Mats.get_mat("plastic_dark"), false)
	Geo.box(holder, Vector3(0, size.y * 0.5, -0.03), Vector3(size.x + 0.04, size.y + 0.04, 0.04), Mats.get_mat("plastic_dark"), false)
	var screen := Geo.box(holder, Vector3(0, size.y * 0.5, -0.008), Vector3(size.x, size.y, 0.004), Mats.get_mat("screen_off"), false)
	return screen
