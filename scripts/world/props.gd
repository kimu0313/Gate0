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
	# keeps you off the stand but stays under the tilted head: the buttons sit at ~0.99 m, and a blocker reaching over
	# them caught the [E] ray first (B-03 / MW-1 buttons could not be pressed)
	Geo.blocker(holder, Vector3(0, 0.42, 0), Vector3(0.66, 0.84, 0.44))
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
	# under the seats (still too high to step onto): a paper left on a seat (DAY 4 log3) sat inside a waist-high
	# blocker and could not be picked up
	Geo.blocker(row, Vector3(0, 0.21, 0), Vector3(width, 0.42, 0.62))
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


## A 1980s hard-sided leather suitcase: straps, brass corners, a paper tag on string. `wet`: soaked through
## (glossy and dark, sea water dripping off it).
static func old_suitcase(parent: Node3D, color: Color, tag_text := "", wet := false) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var size := Vector3(0.46, 0.2, 0.66)
	var leather := Mats.std(color.darkened(0.25) if wet else color, 0.12 if wet else 0.7)
	Geo.box(root, Vector3(0, size.y * 0.5, 0), size, leather, false)
	Geo.box(root, Vector3(0, size.y * 0.5, 0), Vector3(size.x + 0.006, 0.012, size.z + 0.006), Mats.std(color.darkened(0.5), 0.3), false)   # lid seam
	var strap := Mats.std(Color(0.1, 0.06, 0.03), 0.2 if wet else 0.6)
	var brass := Mats.std(Color(0.55, 0.42, 0.18), 0.35, 0.8)
	for z in [-0.17, 0.17]:
		Geo.box(root, Vector3(0, size.y * 0.5, z), Vector3(size.x + 0.012, size.y + 0.012, 0.04), strap, false)
		Geo.box(root, Vector3(0, size.y + 0.007, z), Vector3(0.05, 0.006, 0.045), brass, false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Geo.box(root, Vector3(sx * (size.x * 0.5 - 0.015), size.y * 0.5, sz * (size.z * 0.5 - 0.015)), Vector3(0.035, size.y + 0.006, 0.035), brass, false)
	Geo.box(root, Vector3(0, size.y * 0.5, size.z * 0.5 + 0.03), Vector3(0.14, 0.03, 0.03), strap, false)   # handle
	if tag_text != "":
		var tag := Node3D.new()
		root.add_child(tag)
		tag.position = Vector3(0.08, size.y + 0.006, size.z * 0.5 - 0.06)
		tag.rotation.y = 0.35
		Geo.box(tag, Vector3.ZERO, Vector3(0.1, 0.004, 0.06), Mats.std(Color(0.62, 0.55, 0.38) if wet else Color(0.85, 0.78, 0.6), 0.9), false)
		var l := Geo.label(tag, tag_text, Vector3(0, 0.003, 0), 0.0, 24, Color(0.12, 0.1, 0.08), 0.0016, false, "print")
		l.rotation.x = -PI / 2
		l.name = "TagLabel"
	if wet:
		var drip := CPUParticles3D.new()
		root.add_child(drip)
		drip.position = Vector3(0, 0.02, 0)
		drip.amount = 10
		drip.lifetime = 0.5
		drip.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		drip.emission_box_extents = Vector3(size.x * 0.5, 0.0, size.z * 0.5)
		drip.direction = Vector3.DOWN
		drip.spread = 5.0
		drip.gravity = Vector3(0, -9.8, 0)
		drip.initial_velocity_min = 0.1
		drip.initial_velocity_max = 0.3
		var dm := SphereMesh.new()
		dm.radius = 0.006
		dm.height = 0.014
		dm.radial_segments = 6
		dm.rings = 3
		drip.mesh = dm
		drip.material_override = Mats.std(Color(0.55, 0.62, 0.62), 0.02)
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


## Airport baggage trolley (local -Z = the push handle's side): wire basket deck, a back frame with the handle bar
## and a brake grip, four small castors. Bags go on its deck (y 0.36). Solid to walk into.
static func luggage_cart(parent: Node3D, pos: Vector3, rot_y := 0.0) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	root.rotation.y = rot_y
	var steel := Mats.std(Color(0.62, 0.64, 0.66), 0.35, 0.8)
	var dark := Mats.get_mat("plastic_dark")
	# deck: two side rails and cross slats
	for sx in [-0.27, 0.27]:
		Geo.box(root, Vector3(sx, 0.32, 0.0), Vector3(0.03, 0.03, 0.95), steel, false)
	for z in [-0.42, -0.21, 0.0, 0.21, 0.42]:
		Geo.box(root, Vector3(0, 0.33, z), Vector3(0.55, 0.012, 0.025), steel, false)
	Geo.box(root, Vector3(0, 0.36, 0.5), Vector3(0.6, 0.07, 0.02), steel, false)          # front lip
	# back frame up to the handle
	for sx in [-0.27, 0.27]:
		var post := Geo.box(root, Vector3(sx, 0.72, -0.5), Vector3(0.03, 0.82, 0.03), steel, false)
		post.rotation.x = -0.12
	Geo.box(root, Vector3(0, 1.1, -0.55), Vector3(0.6, 0.035, 0.035), steel, false)
	Geo.box(root, Vector3(0, 1.06, -0.6), Vector3(0.56, 0.03, 0.05), dark, false)       # brake grip
	for y in [0.55, 0.78]:
		Geo.box(root, Vector3(0, y, -0.51), Vector3(0.55, 0.02, 0.02), steel, false)
	var plate := Geo.box(root, Vector3(0, 0.88, -0.5), Vector3(0.4, 0.14, 0.006), Mats.std(Color(0.12, 0.25, 0.68), 0.5), false)
	plate.rotation.x = -0.12
	# castors
	for c in [Vector3(-0.24, 0.07, 0.4), Vector3(0.24, 0.07, 0.4), Vector3(-0.24, 0.07, -0.42), Vector3(0.24, 0.07, -0.42)]:
		var w := Geo.cyl(root, c, 0.07, 0.04, dark)
		w.rotation.z = PI / 2
		Geo.box(root, c + Vector3(0, 0.12, 0), Vector3(0.03, 0.16, 0.03), steel, false)
	Geo.blocker(root, Vector3(0, 0.55, 0), Vector3(0.65, 1.1, 1.1))
	return root


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


## Airliner, 61 m long at scale 1 (nose +Z, wheels on y 0). `length` scales it; `lights` = wingtip nav lights. The
## fuselage axis height and radius (unscaled) are kept in meta "fus" (Vector2), for fitting it through holes.
static func aircraft(parent: Node3D, pos: Vector3, rot_y: float, gate0: bool, length := 61.0, lights := true) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.scale = Vector3.ONE * (length / 61.0)
	root.position = pos
	root.rotation.y = rot_y
	if TripoProps.exists("apron", "APR_Aircraft"):
		return _tripo_aircraft(root, gate0, lights)
	var body := Mats.get_mat("plane_body")
	var dark := Mats.get_mat("plane_dark")
	root.set_meta("fus", Vector2(4.2, 2.6))
	var fus := Geo.cyl(root, Vector3(0, 4.2, 0), 2.6, 52.0, body, false, 24)
	fus.rotation.x = PI / 2
	var nose := Geo.sphere(root, Vector3(0, 4.2, 26.0), 2.6, body)
	nose.scale = Vector3(1.0, 1.0, 1.6)
	Geo.sphere(root, Vector3(0, 4.6, -26.0), 2.4, body).scale = Vector3(1.0, 0.9, 2.2)
	# cockpit windows
	for sx in [-0.9, 0.0, 0.9]:
		Geo.box(root, Vector3(sx, 5.6, 28.6), Vector3(0.7, 0.4, 0.4), dark, false)
	# wings
	var wing := Geo.box(root, Vector3(0, 3.3, 2.0), Vector3(58.0, 0.5, 7.0), body, false)
	wing.rotation.y = 0.0
	for sx in [-9.0, 9.0]:
		Geo.cyl(root, Vector3(sx, 2.3, 5.0), 1.3, 4.5, dark, false, 16).rotation.x = PI / 2
	# tail
	var fin := Geo.box(root, Vector3(0, 10.0, -27.0), Vector3(0.5, 10.0, 6.0), body, false)
	fin.rotation.x = -0.35
	Geo.box(root, Vector3(0, 5.5, -28.0), Vector3(18.0, 0.4, 4.0), body, false)
	# windows row
	for i in 30:
		for sx in [-2.58, 2.58]:
			Geo.box(root, Vector3(sx, 4.9, 20.0 - i * 1.4), Vector3(0.05, 0.35, 0.25), dark, false)
	# landing gear
	for p in [Vector3(0, 0.9, 22), Vector3(-3.5, 0.9, 0), Vector3(3.5, 0.9, 0)]:
		Geo.cyl(root, p, 0.55, 0.5, Mats.get_mat("rubber")).rotation.z = PI / 2
		Geo.cyl(root, p + Vector3(0, 1.4, 0), 0.12, 2.6, Mats.get_mat("metal"))
	# nav lights
	if lights:
		Geo.omni(root, Vector3(-29, 3.4, 2.0), Color(1, 0.1, 0.05), 1.0, 6.0).light_volumetric_fog_energy = 1.0
		Geo.omni(root, Vector3(29, 3.4, 2.0), Color(0.1, 1, 0.2), 1.0, 6.0).light_volumetric_fog_energy = 1.0
		Geo.box(root, Vector3(-29, 3.4, 2.0), Vector3(0.3, 0.3, 0.3), Mats.get_mat("lamp_red"), false)
		Geo.box(root, Vector3(29, 3.4, 2.0), Vector3(0.3, 0.3, 0.3), Mats.get_mat("lamp_green"), false)
	if gate0:
		var cabin := Geo.omni(root, Vector3(0, 4.6, 26.0), Color(1.0, 0.9, 0.7), 2.0, 10.0)
		cabin.light_volumetric_fog_energy = 2.0
		Geo.label(root, "SH 000", Vector3(2.62, 6.2, 12.0), PI / 2, 200, Color(0.1, 0.1, 0.12), 0.02, false, "print")
	else:
		Geo.label(root, "SEOHAE", Vector3(2.62, 6.2, 8.0), PI / 2, 200, Color(0.08, 0.2, 0.5), 0.02, false, "print")
	return root


## Tripo airliner 61 m long (nose +Z); nav lights on its wingtips, the registration on the fuselage's right side.
static func _tripo_aircraft(root: Node3D, gate0: bool, lights: bool) -> Node3D:
	root.set_meta("fus", Vector2(6.38, 3.68))
	var n := TripoProps.spawn(root, "apron", "APR_Aircraft")
	var bb := TripoProps.bounds(n)
	var k := 61.0 / bb.size.z
	n.scale = Vector3.ONE * k
	n.position = -Vector3(bb.get_center().x, bb.position.y, bb.get_center().z) * k
	# fuselage side: outermost vertex near mid-length, inboard of the wing roots
	var side := Vector3(2.6, 5.0, 0)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		for v: Vector3 in mi.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var p := n.position + mi.transform * v * k
			if absf(p.z - 12.0) < 1.5 and p.x > side.x and p.x < 4.5 and p.y > 3.0:
				side = Vector3(p.x, p.y, 0)
	if lights:
		var tip := bb.size.x * k * 0.5 - 0.3
		Geo.omni(root, Vector3(-tip, 3.4, 2.0), Color(1, 0.1, 0.05), 1.0, 6.0).light_volumetric_fog_energy = 1.0
		Geo.omni(root, Vector3(tip, 3.4, 2.0), Color(0.1, 1, 0.2), 1.0, 6.0).light_volumetric_fog_energy = 1.0
	if gate0:
		var cabin := Geo.omni(root, Vector3(0, side.y, 26.0), Color(1.0, 0.9, 0.7), 2.0, 10.0)
		cabin.light_volumetric_fog_energy = 2.0
		Geo.label(root, "SH 000", Vector3(side.x + 0.05, side.y + 0.6, 12.0), PI / 2, 200, Color(0.1, 0.1, 0.12), 0.02, false, "print")
	else:
		Geo.label(root, "SEOHAE", Vector3(side.x + 0.05, side.y + 0.6, 8.0), PI / 2, 200, Color(0.08, 0.2, 0.5), 0.02, false, "print")
	return root
