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
		# keep the caption within the button's own column so neighbours never overlap or spill off the panel
		Geo.fit(Geo.label(holder, caption, Vector3(0, -radius - 0.045, 0.004), 0.0, 24, Color(0.9, 0.9, 0.9), 0.0024, false, "print"), radius * 3.6)
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
	var body := Geo.box(holder, Vector3(0, 0, -depth * 0.5), Vector3(size.x, size.y, depth), Mats.get_mat("plastic_grey"), true)
	var plate := Geo.box(holder, Vector3(0, 0, 0.001), Vector3(size.x - 0.04, size.y - 0.04, 0.004), Mats.get_mat("metal_dark"), false)
	if TripoProps.exists("common", "CMN_WallSign"):
		# Tripo enclosure (framed box, dark face); the boxes stay hidden as collider and label backing
		body.visible = false
		plate.visible = false
		sign_body(holder, Vector3(0, 0, -depth * 0.5), size, depth)
	if title != "":
		Geo.fit(Geo.label(holder, title, Vector3(0, size.y * 0.5 - 0.09, 0.006), 0.0, 30, Geo.SIGN_BLUE, 0.0025, false, "print"), size.x - 0.08)
	return holder


## Free-standing control stand (belt and walkway controls): brushed stainless base, slim column and a sloped head
## whose dark face carries the buttons. Returns the face node (+Z = face normal; face 0.6 x 0.36, centred 0.03 below
## the origin so a button row at y -0.03 has room for its captions).
static func pedestal(parent: Node3D, pos: Vector3, rot_y: float, title := "") -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = pos
	holder.rotation.y = rot_y
	var steel := CarouselMesh.mat("steel")
	for part in [[Vector3(0.4, 0.02, 0.32), 0.04, 0.0], [Vector3(0.18, 0.86, 0.14), 0.03, 0.02]]:
		var mi := MeshInstance3D.new()
		mi.mesh = CarouselMesh.rounded_prism(part[0], part[1])
		mi.material_override = steel
		holder.add_child(mi)
		mi.position.y = part[2]
	Geo.box(holder, Vector3(0, 0.005, 0), Vector3(0.36, 0.01, 0.28), CarouselMesh.mat("kick"), false)
	Geo.blocker(holder, Vector3(0, 0.55, 0), Vector3(0.6, 1.1, 0.4))
	var top := Node3D.new()
	holder.add_child(top)
	top.position = Vector3(0, 1.0, 0.03)
	top.rotation.x = -0.5
	var head := MeshInstance3D.new()
	head.mesh = CarouselMesh.rounded_prism(Vector3(0.66, 0.08, 0.42), 0.03)
	head.material_override = steel
	top.add_child(head)
	head.rotation.x = PI / 2           # the prism's top becomes the face (+Z), its body behind it
	head.position = Vector3(0, -0.03, -0.085)
	Geo.box(top, Vector3(0, -0.03, -0.003), Vector3(0.6, 0.36, 0.004), CarouselMesh.mat("panel"), false)   # face 1 mm behind the captions
	if title != "":
		Geo.fit(Geo.label(top, title, Vector3(0, 0.1, 0.006), 0.0, 26, Geo.SIGN_BLUE, 0.0022, false, "print"), 0.44, 0.05)
	return top


static func seat_row(parent: Node3D, pos: Vector3, count: int, rot_y := 0.0, spacing := 0.62) -> Node3D:
	var row := Node3D.new()
	parent.add_child(row)
	row.position = pos
	row.rotation.y = rot_y
	var width := spacing * count
	if TripoProps.exists("baggage", "BAG_RowSeating"):
		# Tripo three-seat beam units; a row of 6 keeps the seat pitch (seat centres at 0.31, 0.93 ...), longer rows
		# squeeze whole units into the same length
		var units := int(ceil(count / 3.0))
		for i in units:
			var u := TripoProps.spawn(row, "baggage", "BAG_RowSeating", Vector3(-width * 0.5 + width * (i + 0.5) / units, 0, 0))
			TripoProps.fit(u, Vector3(width / units, 0, 0))
	else:
		var seat := Mats.get_mat("seat")
		var frame := Mats.get_mat("seat_frame")
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
	var plate := Geo.box(holder, Vector3.ZERO, Vector3(size.x, size.y, 0.14), Mats.get_mat("sign_back"), false)
	var tripo := TripoProps.exists("common", "CMN_WallSign")
	if tripo:
		# Tripo lightbox body; the box stays (hidden) as the label-fitting backing
		plate.visible = false
		sign_body(holder, Vector3.ZERO, size, 0.14)
	var labels: Array[Label3D] = []
	for side in [0.0, PI]:
		for line in lines:
			# line: [text, font_size, color, Vector2 offset]; ["@icon_departures", height m, color, offset] = pictogram
			var off: Vector2 = line[3] if line.size() > 3 else Vector2.ZERO
			var z := 0.075 if side == 0.0 else -0.075
			var x := off.x if side == 0.0 else -off.x
			if str(line[0]).begins_with("@"):
				var ic := LevelKit.icon_sprite(holder, str(line[0]).substr(1), Vector3(x, off.y, z * 1.02), float(line[1]), line[2])
				ic.rotation.y = side
				continue
			var l := Geo.fit(Geo.label(holder, str(line[0]), Vector3(x, off.y, z), side, int(line[1]), line[2], 0.006), size.x * 0.92)
			labels.append(l)
	if ceiling_y > pos.y:
		var rod_h := ceiling_y - pos.y - size.y * 0.5
		for sx in [-size.x * 0.35, size.x * 0.35]:
			if tripo:
				var rod := TripoProps.spawn(holder, "common", "CMN_SignRod", Vector3(sx, size.y * 0.5, 0))
				TripoProps.fit(rod, Vector3(0, rod_h, 0))
			else:
				Geo.cyl(holder, Vector3(sx, size.y * 0.5 + rod_h * 0.5, 0), 0.015, rod_h, Mats.get_mat("steel_frame"))
	return labels


## Tripo lightbox body (CMN_WallSign) stretched to w x h x depth, centred on `centre` in `parent` space.
static func sign_body(parent: Node3D, centre: Vector3, size: Vector2, depth: float) -> Node3D:
	var n := TripoProps.spawn(parent, "common", "CMN_WallSign")
	var bb := TripoProps.bounds(n)
	TripoProps.fit(n, Vector3(size.x, size.y, depth))
	n.position = centre - n.basis * bb.get_center()
	return n


static func pillar(parent: Node3D, pos: Vector3, height: float, size := 1.0) -> void:
	Geo.box(parent, pos + Vector3(0, height * 0.5, 0), Vector3(size, height, size), Mats.get_mat("wall"))
	Geo.box(parent, pos + Vector3(0, 0.06, 0), Vector3(size + 0.04, 0.12, size + 0.04), Mats.get_mat("metal_dark"), false)


static func trash_bin(parent: Node3D, pos: Vector3) -> void:
	if TripoProps.exists("baggage", "BAG_TrashBin"):
		TripoProps.spawn(parent, "baggage", "BAG_TrashBin", pos, 0.0, true, null, Vector3(0.48, 0.92, 0.48))
		return
	Geo.cyl(parent, pos + Vector3(0, 0.45, 0), 0.24, 0.9, Mats.get_mat("steel_frame"), true)
	Geo.cyl(parent, pos + Vector3(0, 0.91, 0), 0.25, 0.03, Mats.get_mat("plastic_dark"))


static func planter(parent: Node3D, pos: Vector3) -> void:
	if TripoProps.exists("terminal", "TRM_Planter"):
		TripoProps.spawn(parent, "terminal", "TRM_Planter", pos, 0.0, true)
		return
	Geo.box(parent, pos + Vector3(0, 0.35, 0), Vector3(0.9, 0.7, 0.9), Mats.get_mat("plastic_dark"))
	var leaf := Mats.std(Color(0.06, 0.12, 0.07), 0.8)
	Geo.sphere(parent, pos + Vector3(0, 1.1, 0), 0.5, leaf)
	Geo.sphere(parent, pos + Vector3(0.2, 1.5, 0.1), 0.35, leaf)


static func exit_sign(parent: Node3D, pos: Vector3, rot_y: float, text := "비상구  EXIT") -> MeshInstance3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = pos
	holder.rotation.y = rot_y
	var m: MeshInstance3D
	if TripoProps.exists("common", "CMN_WallSign"):
		# Tripo lightbox body with the glowing green face in front of it
		sign_body(holder, Vector3.ZERO, Vector2(0.9, 0.3), 0.08)
		m = Geo.box(holder, Vector3(0, 0, 0.041), Vector3(0.84, 0.25, 0.002), Mats.get_mat("exit_green"), false)
	else:
		m = Geo.box(holder, Vector3.ZERO, Vector3(0.9, 0.3, 0.08), Mats.get_mat("exit_green"), false)
	Geo.fit(Geo.label(holder, text, Vector3(0, 0, 0.045), 0.0, 40, Color(0.02, 0.15, 0.04), 0.004), 0.82)
	var l := Geo.omni(holder, Vector3(0, -0.1, 0.3), Color(0.2, 1.0, 0.4), 0.35, 3.0)
	l.light_volumetric_fog_energy = 1.0
	return m


static func lightbox(parent: Node3D, pos: Vector3, rot_y: float, size: Vector2, text: String, sub := "") -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = pos
	holder.rotation.y = rot_y
	if TripoProps.exists("common", "CMN_WallSign"):
		sign_body(holder, Vector3(0, 0, -0.06), size + Vector2(0.1, 0.1), 0.12)
	else:
		Geo.box(holder, Vector3(0, 0, -0.06), Vector3(size.x + 0.1, size.y + 0.1, 0.12), Mats.get_mat("metal_dark"), false)
	Geo.box(holder, Vector3.ZERO, Vector3(size.x, size.y, 0.02), Mats.get_mat("lightbox"), false)
	Geo.fit(Geo.label(holder, text, Vector3(0, 0.15, 0.015), 0.0, 60, Color(0.05, 0.1, 0.22), 0.006), size.x * 0.88)
	if sub != "":
		Geo.fit(Geo.label(holder, sub, Vector3(0, -0.25, 0.015), 0.0, 26, Color(0.1, 0.15, 0.3), 0.006), size.x * 0.88)
	return holder


## Hard-shell suitcase lying flat (as on a carousel). Returns the root node.
static func suitcase(parent: Node3D, color: Color, tag_text := "", soft := false) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var size := Vector3(0.48, 0.24 if not soft else 0.28, 0.7)
	if TripoProps.exists("terminal", "TRM_Suitcase"):
		# Tripo shell (neutral grey) tinted with the bag's colour; the colour carries meaning (extra = red, name = brown)
		var n := TripoProps.spawn(root, "terminal", "TRM_Suitcase", Vector3.ZERO, 0.0, false, _bag_mat(color, soft))
		TripoProps.fit(n, size)
	else:
		var body_mat := Mats.std(color, 0.55 if soft else 0.3, 0.0 if soft else 0.15)
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
		var l := Geo.label(tag, tag_text, Vector3(0, 0.004, 0), 0.0, 28, Color(0.05, 0.05, 0.05), 0.0018, false, "print")
		l.rotation.x = -PI / 2
		l.name = "TagLabel"
	return root


static var _bag_mats := {}


## The terminal atlas tinted for one bag colour (soft bags a little rougher), shared by every bag of that colour.
static func _bag_mat(color: Color, soft: bool) -> StandardMaterial3D:
	var key := "%s/%s" % [color.to_html(), soft]
	if not _bag_mats.has(key):
		var m := TripoProps.atlas("terminal").duplicate() as StandardMaterial3D
		m.albedo_color = color.lightened(0.15)
		m.roughness = 1.25 if soft else 1.0
		_bag_mats[key] = m
	return _bag_mats[key]


## Featureless dark passenger silhouette.
static func figure(parent: Node3D, pos: Vector3, rot_y := 0.0, seated := true) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	root.rotation.y = rot_y
	var id := "FIG_PassengerSeated" if seated else "FIG_PassengerStanding"
	if TripoProps.exists("figure", id):
		# Tripo mannequin passenger; its head is a separate mesh pivoting at the neck (boarding_gate turns "Head")
		var n := TripoProps.spawn(root, "figure", id)
		for mi: MeshInstance3D in n.find_children("*Head*", "MeshInstance3D", true, false):
			var t := mi.global_transform
			mi.get_parent().remove_child(mi)
			root.add_child(mi)
			mi.global_transform = t
			mi.name = "Head"
		return root
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
	if TripoProps.exists("terminal", "TRM_InfoDesk"):
		# Tripo counter, its open staff side toward the sitter (+Z)
		TripoProps.spawn(holder, "terminal", "TRM_InfoDesk", Vector3.ZERO, PI, false, null, size)
	else:
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
	var screen_z := -0.008
	if TripoProps.exists("terminal", "TRM_Monitor"):
		# Tripo monitor scaled to the bezel width, its panel top level with the screen's top edge; the returned
		# screen box (material swapped by callers) sits on its face
		var n := TripoProps.spawn(holder, "terminal", "TRM_Monitor")
		var bb := TripoProps.bounds(n)
		var k := (size.x + 0.04) / bb.size.x
		n.scale = Vector3.ONE * k
		n.position = Vector3(-bb.get_center().x * k, size.y + 0.02 - bb.end.y * k, -0.05 - bb.get_center().z * k)
		screen_z = n.position.z + TripoProps.face_z(n, bb.end.y - bb.size.y * 0.6) * k + 0.003
	else:
		Geo.box(holder, Vector3(0, -0.1, -0.05), Vector3(0.06, 0.2, 0.06), Mats.get_mat("plastic_dark"), false)
		Geo.box(holder, Vector3(0, size.y * 0.5, -0.03), Vector3(size.x + 0.04, size.y + 0.04, 0.04), Mats.get_mat("plastic_dark"), false)
	var screen := Geo.box(holder, Vector3(0, size.y * 0.5, screen_z), Vector3(size.x, size.y, 0.004), Mats.get_mat("screen_off"), false)
	return screen
