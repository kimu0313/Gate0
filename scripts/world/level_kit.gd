class_name LevelKit
extends RefCounted
## Builders shared by levels made of Tripo props (Terminal): wall-mounted and ceiling-hung props, stanchion lines,
## Tripo sign bodies with text on top, number towers, staff and exit doors, walkway runs. Rotations in degrees
## about Y (0 = the prop's front looks +Z). Every builder falls back to a plain box when the model is missing.

const TEX := "res://assets/textures/level/"
const INK := Color(0.96, 0.96, 0.92)


## A Tripo prop with its pivot at `pos` (floor centre), turned `rot_deg`, optionally stretched to `size` and boxed in.
static func prop(parent: Node3D, zone: String, id: String, pos: Vector3, rot_deg := 0.0, collide := true,
		size := Vector3.ZERO) -> Node3D:
	if not TripoProps.exists(zone, id):
		var s := size if size != Vector3.ZERO else Vector3(0.6, 1.0, 0.6)
		var stub := Node3D.new()
		parent.add_child(stub)
		stub.position = pos
		stub.rotation.y = deg_to_rad(rot_deg)
		Geo.box(stub, Vector3(0, s.y * 0.5, 0), s, Mats.get_mat("plastic_grey"), collide)
		return stub
	return TripoProps.spawn(parent, zone, id, pos, deg_to_rad(rot_deg), collide, null, size)


## A prop whose back stands against a wall: `surface` = point on the wall face (at floor or mounting height),
## `facing` = the direction its front looks.
static func mount(parent: Node3D, zone: String, id: String, surface: Vector3, facing: float, collide := false,
		size := Vector3.ZERO) -> Node3D:
	var n := prop(parent, zone, id, surface, facing, false, size)
	var bb := TripoProps.bounds(n)
	n.position += n.basis.z * (-bb.position.z * n.scale.z + 0.005)
	if collide:
		Geo.blocker(parent, n.position + n.basis * (bb.get_center() * n.scale), bb.size * n.scale, n.rotation.y)
	return n


## A flat fixture modelled face-up, turned over onto a ceiling at `ceiling_y`, its face `drop` below it.
static func ceiling_prop(parent: Node3D, id: String, pos: Vector3, ceiling_y: float, rot_deg := 0.0, drop := 0.01) -> Node3D:
	var n := prop(parent, "common", id, Vector3(pos.x, 0, pos.z), rot_deg, false)
	n.rotate_object_local(Vector3.RIGHT, PI)
	n.position.y = ceiling_y + TripoProps.bounds(n).size.y - drop
	return n


## Walk-through metal detector: only its two pillars block.
static func metal_detector(parent: Node3D, pos: Vector3, rot_deg := 0.0) -> void:
	var r := Basis(Vector3.UP, deg_to_rad(rot_deg))
	if TripoProps.exists("security", "SEC_MetalDetector"):
		TripoProps.spawn(parent, "security", "SEC_MetalDetector", pos, deg_to_rad(rot_deg), false, null, Vector3(1.25, 2.31, 0.6))
	else:
		var m := Mats.get_mat("plastic_grey")
		for sx in [-0.55, 0.55]:
			Geo.box(parent, pos + r * Vector3(sx, 1.05, 0), Vector3(0.14, 2.1, 0.55), m, false, deg_to_rad(rot_deg))
		Geo.box(parent, pos + Vector3(0, 2.18, 0), Vector3(1.25, 0.18, 0.6), m, false, deg_to_rad(rot_deg))
	for sx in [-0.55, 0.55]:
		Geo.blocker(parent, pos + r * Vector3(sx, 1.05, 0), Vector3(0.14, 2.1, 0.55), deg_to_rad(rot_deg))


## A queue line: stanchion posts at `points` (floor), retractable belts between neighbours.
static func stanchions(parent: Node3D, points: Array) -> void:
	var belt := Mats.std(Color(0.08, 0.14, 0.38), 0.6)
	for p: Vector3 in points:
		if TripoProps.exists("security", "SEC_Stanchion"):
			TripoProps.spawn(parent, "security", "SEC_Stanchion", p)
		else:
			Geo.cyl(parent, p + Vector3(0, 0.5, 0), 0.035, 1.0, Mats.get_mat("metal"))
		Geo.blocker(parent, p + Vector3(0, 0.5, 0), Vector3(0.3, 1.0, 0.3))
	for k in points.size() - 1:
		var a: Vector3 = points[k]
		var b: Vector3 = points[k + 1]
		var d := b - a
		var length := Vector2(d.x, d.z).length() - 0.1
		Geo.box(parent, (a + b) * 0.5 + Vector3(0, 0.9, 0), Vector3(0.012, 0.05, length), belt, false, atan2(d.x, d.z))
		Geo.blocker(parent, (a + b) * 0.5 + Vector3(0, 0.5, 0), Vector3(0.1, 1.0, length), atan2(d.x, d.z))


## Moving walkway built from the Tripo entry/straight units along -Z from `start` (entry at `start`, exit turned
## round at the far end). The tread is walkable; only the balustrades block. Returns the run's length.
static func walkway_run(parent: Node3D, start: Vector3, mids: int) -> float:
	var z := start.z
	var units: Array = [["SEC_WalkwayEnd", 0.0]]
	for i in mids:
		units.append(["SEC_WalkwayMid", 0.0])
	units.append(["SEC_WalkwayEnd", 180.0])
	for u in units:
		var n := prop(parent, "walkway", u[0], Vector3(start.x, 0, z), u[1], false)
		var bb := TripoProps.bounds(n)
		var len_z := bb.size.z * n.scale.z
		n.position.z = z - len_z * 0.5          # pivot = floor centre of the unit
		for side in [-1.0, 1.0]:
			Geo.blocker(parent, Vector3(start.x + side * (bb.size.x * 0.5 - 0.07), 0.55, z - len_z * 0.5), Vector3(0.14, 1.1, len_z))
		z -= len_z
	return start.z - z


# ------------------------------------------------------------------ signage (Tripo sign bodies, text on top)

## CMN_WallSign stretched to `size` (w x h; turned upright when `vertical`) on a wall; returns an unscaled root at the
## wall point, its +Z out of the wall (meta "face_z" = distance of the sign face from the wall).
static func sign_body(parent: Node3D, surface: Vector3, facing: float, size: Vector2, vertical := false) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = surface
	root.rotation.y = deg_to_rad(facing)
	if not TripoProps.exists("common", "CMN_WallSign"):
		Geo.box(root, Vector3(0, 0, 0.05), Vector3(size.x, size.y, 0.1), Mats.get_mat("sign_back"), false)
		root.set_meta("face_z", 0.1)
		return root
	var n := TripoProps.spawn(root, "common", "CMN_WallSign")
	var bb := TripoProps.bounds(n)
	var long := size.y if vertical else size.x
	var short := size.x if vertical else size.y
	n.scale = Vector3(long / bb.size.x, short / bb.size.y, 1.0)
	if vertical:
		n.rotation.z = PI / 2
	n.position = (n.basis * -bb.get_center()) + Vector3(0, 0, bb.size.z * 0.5 + 0.005)
	root.set_meta("face_z", bb.size.z + 0.005)
	return root


## Flat wall lightbox with one block of text (multi-line allowed), fitted inside its face.
static func wall_sign(parent: Node3D, surface: Vector3, facing: float, text: String, size: Vector2, icon := "") -> Node3D:
	var root := sign_body(parent, surface, facing, size)
	var z: float = root.get_meta("face_z") + 0.004
	var x0 := 0.0
	if icon != "":
		icon_sprite(root, icon, Vector3(-size.x * 0.5 + size.y * 0.55, 0, z), size.y * 0.6)
		x0 = size.y * 0.45
	var l := Geo.label(root, text, Vector3(x0, 0, z), 0.0, 64, INK, 0.005)
	Geo.fit(l, size.x - 0.2 - x0 * 2.0, size.y - 0.12)
	l.set_meta("no_fit", true)
	return root


## Ceiling-hung lightbox: `top` = point on the ceiling above its centre; text (and an optional pictogram) on both faces.
static func hanging_sign(parent: Node3D, top: Vector3, rot_deg: float, text: String, width := 2.8, icon := "icon_luggage") -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.rotation.y = deg_to_rad(rot_deg)
	var face_z := 0.06
	var h := 0.9
	if TripoProps.exists("common", "CMN_HangingSign"):
		var n := TripoProps.spawn(root, "common", "CMN_HangingSign", Vector3.ZERO, 0.0, false, null, Vector3(width, 0, 0))
		var bb := TripoProps.bounds(n)
		h = bb.size.y
		face_z = bb.end.z
	else:
		Geo.box(root, Vector3(0, 0.25, 0), Vector3(width, 0.5, 0.12), Mats.get_mat("sign_back"), false)
	root.position = Vector3(top.x, top.y - h, top.z)
	var size := Vector2(width, 0.5)
	for side in [1.0, -1.0]:
		var f := Node3D.new()
		root.add_child(f)
		f.rotation.y = 0.0 if side > 0 else PI
		var at := Vector3(0, 0.25, face_z + 0.004)
		var x0 := 0.0
		if icon != "":
			icon_sprite(f, icon, at + Vector3(-size.x * 0.5 + size.y * 0.55, 0, 0), size.y * 0.62)
			x0 = size.y * 0.45
		var l := Geo.label(f, text, at + Vector3(x0, 0, 0), 0.0, 64, INK, 0.0042)
		Geo.fit(l, size.x - size.y * 0.5 - x0 * 2.0, size.y - 0.1)
		l.set_meta("no_fit", true)
	return root


## Printed artwork (assets/textures/level/<tex>.png) on a quad `size` metres, its face looking `facing` (deg);
## `glow` > 0 lights it from behind (lightboxes, screens).
static func decal(parent: Node3D, tex: String, pos: Vector3, facing: float, size: Vector2, glow := 0.0) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + tex + ".png")
	m.roughness = 0.55
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = Color.BLACK            # emission op ADD: the texture alone, not texture + colour
		m.emission_texture = m.albedo_texture
		m.emission_energy_multiplier = glow
	mi.material_override = m
	parent.add_child(mi)
	mi.position = pos
	mi.rotation.y = deg_to_rad(facing)
	return mi


## Unshaded pictogram (assets/textures/level/<tex>.png) `height` metres tall.
static func icon_sprite(parent: Node3D, tex: String, pos: Vector3, height: float, tint := INK) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = load(TEX + tex + ".png")
	s.pixel_size = height / s.texture.get_height()
	s.shaded = false
	s.double_sided = false
	s.modulate = tint
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(s)
	s.position = pos
	return s


## Carousel number tower: number, pictogram and caption on its front (+Z of the tower), pictogram on its +X side.
static func number_pillar(parent: Node3D, pos: Vector3, n: int, rot_deg := 0.0) -> void:
	var p := prop(parent, "baggage", "BAG_NumberPillar", pos, rot_deg)
	var bb := TripoProps.bounds(p)
	var ink := Color(0.12, 0.13, 0.16)
	var front := Node3D.new()
	p.add_child(front)
	front.position = Vector3(0, 0, bb.end.z + 0.003)
	Geo.fit(Geo.label(front, str(n), Vector3(0, 2.05, 0), 0.0, 220, ink, 0.004, false, "print"), bb.size.x - 0.12, 0.85).set_meta("no_fit", true)
	icon_sprite(front, "icon_luggage", Vector3(0, 1.45, 0), 0.26, ink)
	Geo.fit(Geo.label(front, "수하물 수취\nBaggage Claim", Vector3(0, 1.08, 0), 0.0, 40, ink, 0.0035, false, "print"),
			bb.size.x - 0.12, 0.32).set_meta("no_fit", true)
	var side := Node3D.new()
	p.add_child(side)
	side.position = Vector3(bb.end.x + 0.003, 0, 0)
	side.rotation.y = PI / 2
	icon_sprite(side, "icon_luggage", Vector3(0, 1.45, 0), 0.26, ink)


## Staff door on a wall (not openable) with its printed plate.
static func staff_door(parent: Node3D, surface: Vector3, facing: float, text := "직원 전용  STAFF ONLY") -> Node3D:
	var d := mount(parent, "common", "CMN_Door", surface, facing, true)
	var bb := TripoProps.bounds(d)
	var l := Geo.label(d, text, Vector3(0, bb.size.y - 0.16, bb.end.z - 0.075), 0.0, 40, Color(0.95, 0.95, 0.9), 0.003)
	Geo.fit(l, 0.62, 0.14)
	l.set_meta("no_fit", true)
	return d


## Double door (not openable) with a lit sign above the leaves.
static func double_door(parent: Node3D, surface: Vector3, facing: float, text := "출구  EXIT") -> Node3D:
	var d := mount(parent, "common", "CMN_DoubleDoor", surface, facing, true)
	var bb := TripoProps.bounds(d)
	var l := Geo.label(d, text, Vector3(0, bb.size.y - 0.2, bb.end.z + 0.004), 0.0, 48, Color(1, 1, 1), 0.003)
	Geo.fit(l, 0.44, 0.15)
	l.set_meta("no_fit", true)
	return d
