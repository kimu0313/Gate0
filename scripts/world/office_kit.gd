class_name OfficeKit
## The security office's furniture (Terminal._build_security_office), from boxes: desks with a drawer pedestal, filing
## cabinets, a bookshelf of binders, a glass-front cabinet, an old CRT, desk lamps, cartons and paper, panel doors
## with a narrow light, windows with their vertical blinds drawn, an armchair. Every drawer is a Drawer ([E] opens
## it). Colliders stop short of the drawer fronts, so the [E] ray reaches them (the ray hits world colliders too).
##
## Local frames: a desk or cabinet's front (the sitter's side, the drawers) faces +Z; it stands on y 0.

const DESK_H := 0.76


static func steel() -> Material:
	return Mats.std(Color(0.6, 0.61, 0.6), 0.5, 0.35)


static func _holder(parent: Node3D, pos: Vector3, rot_y: float) -> Node3D:
	var h := Node3D.new()
	parent.add_child(h)
	h.position = pos
	h.rotation.y = rot_y
	return h


## A pedestal shell (sides, back, plinth; the drawer fronts close it) with `heights` drawers top to bottom, its face
## at local z `face`. Returns the drawers.
static func _pedestal(holder: Node3D, cx: float, face: float, w: float, top_y: float, depth: float, heights: Array,
		body: Material, front: Material) -> Array[Drawer]:
	var drawers: Array[Drawer] = []
	for sx in [-1.0, 1.0]:
		Geo.box(holder, Vector3(cx + sx * (w * 0.5 - 0.01), top_y * 0.5, face - depth * 0.5), Vector3(0.02, top_y, depth), body, false)
	Geo.box(holder, Vector3(cx, top_y * 0.5, face - depth + 0.01), Vector3(w, top_y, 0.02), body, false)
	Geo.box(holder, Vector3(cx, 0.03, face - depth * 0.5 - 0.02), Vector3(w - 0.04, 0.06, depth - 0.04), Mats.get_mat("metal_dark"), false)
	var y := top_y - 0.012
	for h: float in heights:
		y -= h
		drawers.append(Drawer.create(holder, Vector3(cx, y + h * 0.5, face), 0.0, Vector3(w - 0.02, h - 0.008, depth - 0.06), front))
		y -= 0.008
	return drawers


## Office desk `size` (width, height, depth) with a pedestal of three drawers at one end (`side` +1 = local +X).
static func desk(parent: Node3D, pos: Vector3, rot_y: float, size: Vector3, side := 1.0) -> Array[Drawer]:
	var h := _holder(parent, pos, rot_y)
	var top := Mats.get_mat("wood")
	var body := Mats.std(Color(0.52, 0.52, 0.5), 0.6, 0.25)
	Geo.box(h, Vector3(0, size.y - 0.0175, 0), Vector3(size.x, 0.035, size.z), top, false)
	Geo.box(h, Vector3(0, size.y - 0.3, -size.z * 0.5 + 0.05), Vector3(size.x - 0.06, 0.45, 0.02), body, false)
	Geo.box(h, Vector3(-side * (size.x * 0.5 - 0.02), (size.y - 0.035) * 0.5, 0), Vector3(0.035, size.y - 0.035, size.z - 0.04), body, false)
	var pw := 0.42
	var cx := side * (size.x * 0.5 - pw * 0.5 - 0.01)
	var face := size.z * 0.5 - 0.03
	var drawers := _pedestal(h, cx, face, pw, size.y - 0.035, size.z - 0.08, [0.15, 0.2, 0.28], body, steel())
	Geo.blocker(h, Vector3(0, size.y * 0.5, -0.06), Vector3(size.x, size.y, size.z - 0.12))
	return drawers


## Four-drawer vertical filing cabinet.
static func filing_cabinet(parent: Node3D, pos: Vector3, rot_y: float, n := 4) -> Array[Drawer]:
	var h := _holder(parent, pos, rot_y)
	var size := Vector3(0.47, 1.32, 0.62)
	var body := steel()
	Geo.box(h, Vector3(0, size.y - 0.01, 0), Vector3(size.x, 0.02, size.z), body, false)
	var hs: Array = []
	for i in n:
		hs.append((size.y - 0.1) / n - 0.008)
	var drawers := _pedestal(h, 0.0, size.z * 0.5, size.x, size.y - 0.02, size.z, hs, body, body)
	Geo.blocker(h, Vector3(0, size.y * 0.5, -0.05), Vector3(size.x, size.y, size.z - 0.1))
	return drawers


## Low lateral cabinet, `w` wide, two wide drawers.
static func lateral_cabinet(parent: Node3D, pos: Vector3, rot_y: float, w := 0.9, height := 0.74) -> Array[Drawer]:
	var h := _holder(parent, pos, rot_y)
	var depth := 0.46
	var body := steel()
	Geo.box(h, Vector3(0, height - 0.01, 0), Vector3(w, 0.02, depth), body, false)
	var hs := [(height - 0.1) * 0.5 - 0.008, (height - 0.1) * 0.5 - 0.008]
	var drawers := _pedestal(h, 0.0, depth * 0.5, w, height - 0.02, depth, hs, body, body)
	Geo.blocker(h, Vector3(0, height * 0.5, -0.05), Vector3(w, height, depth - 0.1))
	return drawers


## Open bookshelf, binders and box files on four shelves.
static func bookshelf(parent: Node3D, pos: Vector3, rot_y: float, size := Vector3(1.0, 2.0, 0.38), seed_n := 7) -> void:
	var h := _holder(parent, pos, rot_y)
	var body := Mats.std(Color(0.46, 0.45, 0.42), 0.7)
	for sx in [-1.0, 1.0]:
		Geo.box(h, Vector3(sx * (size.x * 0.5 - 0.01), size.y * 0.5, 0), Vector3(0.02, size.y, size.z), body, false)
	Geo.box(h, Vector3(0, size.y * 0.5, -size.z * 0.5 + 0.005), Vector3(size.x, size.y, 0.01), body, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var cols := [Color(0.12, 0.2, 0.42), Color(0.08, 0.08, 0.09), Color(0.45, 0.46, 0.48), Color(0.5, 0.12, 0.1), Color(0.75, 0.72, 0.62)]
	var shelf_h := (size.y - 0.08) / 4.0
	for i in 5:
		Geo.box(h, Vector3(0, 0.04 + i * shelf_h, 0), Vector3(size.x - 0.04, 0.02, size.z - 0.02), body, false)
		if i == 4:
			break
		var x := -size.x * 0.5 + 0.04
		var y0 := 0.05 + i * shelf_h
		while x < size.x * 0.5 - 0.1:
			var bw := rng.randf_range(0.045, 0.08)
			var bh := minf(shelf_h - 0.04, rng.randf_range(0.26, 0.33))
			if rng.randf() < 0.12:
				x += rng.randf_range(0.05, 0.12)           # a gap
				continue
			var b := Geo.box(h, Vector3(x + bw * 0.5, y0 + bh * 0.5, 0.0), Vector3(bw - 0.004, bh, size.z - 0.08),
				Mats.std(cols[rng.randi() % cols.size()], 0.75), false)
			if rng.randf() < 0.1:
				b.rotation.z = rng.randf_range(0.08, 0.2)
			x += bw
	Geo.blocker(h, Vector3(0, size.y * 0.5, 0), size)


## Glass-front cabinet with box files behind the glass.
static func glass_cabinet(parent: Node3D, pos: Vector3, rot_y: float, size := Vector3(1.0, 1.85, 0.42)) -> void:
	var h := _holder(parent, pos, rot_y)
	var body := Mats.std(Color(0.5, 0.49, 0.46), 0.6, 0.2)
	Geo.box(h, Vector3(0, size.y * 0.5, -0.02), Vector3(size.x, size.y, size.z - 0.04), body, false)
	Geo.box(h, Vector3(0, size.y * 0.5 + 0.1, size.z * 0.5 - 0.02), Vector3(size.x - 0.08, size.y - 0.4, 0.01), Mats.std(Color(0.08, 0.09, 0.1), 0.4), false)
	for sx in [-1.0, 1.0]:
		var c := Vector3(sx * size.x * 0.25, size.y * 0.5 + 0.1, size.z * 0.5)
		Geo.box(h, c, Vector3(size.x * 0.5 - 0.02, size.y - 0.4, 0.012), Mats.get_mat("glass"), false)
		Geo.box(h, c + Vector3(-sx * (size.x * 0.25 - 0.06), -0.05, 0.015), Vector3(0.015, 0.12, 0.02), Mats.get_mat("metal"), false)
	for i in 3:
		Geo.box(h, Vector3(0, 0.75 + i * 0.4, size.z * 0.5 - 0.06), Vector3(size.x - 0.12, 0.3, 0.012), Mats.std(Color(0.2, 0.24, 0.36), 0.8), false)
	Geo.blocker(h, Vector3(0, size.y * 0.5, 0), size)


## An old CRT monitor (deep beige case) facing +Z; returns its screen so the caller can light it.
static func crt(parent: Node3D, pos: Vector3, rot_y: float) -> MeshInstance3D:
	var h := _holder(parent, pos, rot_y)
	var case_m := Mats.std(Color(0.72, 0.69, 0.6), 0.6)
	Geo.box(h, Vector3(0, 0.03, -0.05), Vector3(0.26, 0.06, 0.24), case_m, false)
	Geo.box(h, Vector3(0, 0.24, -0.12), Vector3(0.36, 0.3, 0.3), case_m, false)
	Geo.box(h, Vector3(0, 0.25, 0.04), Vector3(0.4, 0.34, 0.04), case_m, false)
	return Geo.box(h, Vector3(0, 0.26, 0.062), Vector3(0.31, 0.24, 0.004), Mats.get_mat("screen_off"), false)


## Angled desk lamp facing +Z; lit, it throws a small warm pool.
static func desk_lamp(parent: Node3D, pos: Vector3, rot_y: float, lit := true) -> void:
	var h := _holder(parent, pos, rot_y)
	var m := Mats.std(Color(0.18, 0.19, 0.2), 0.45, 0.4)
	Geo.cyl(h, Vector3(0, 0.01, 0), 0.08, 0.02, m)
	var arm := Geo.cyl(h, Vector3(0, 0.2, -0.04), 0.012, 0.42, m)
	arm.rotation.x = -0.25
	var arm2 := Geo.cyl(h, Vector3(0, 0.42, 0.06), 0.012, 0.3, m)
	arm2.rotation.x = 1.0
	var shade := Geo.cyl(h, Vector3(0, 0.42, 0.2), 0.07, 0.14, m)
	shade.rotation.x = 0.9
	if lit:
		Geo.cyl(h, Vector3(0, 0.38, 0.25), 0.05, 0.01, Mats.emissive(Color(1.0, 0.86, 0.6), 2.0)).rotation.x = 0.9
		var l := Geo.omni(h, Vector3(0, 0.3, 0.28), Color(1.0, 0.82, 0.58), 0.45, 2.4)
		l.light_volumetric_fog_energy = 0.2


static func carton(parent: Node3D, pos: Vector3, size: Vector3, rot_y := 0.0) -> void:
	var b := Geo.box(parent, pos + Vector3(0, size.y * 0.5, 0), size, Mats.std(Color(0.55, 0.42, 0.28), 0.9), false, rot_y)
	Geo.box(b, Vector3(0, size.y * 0.5 + 0.001, 0), Vector3(0.05, 0.002, size.z + 0.002), Mats.std(Color(0.62, 0.55, 0.42), 0.4), false)


static func paper_stack(parent: Node3D, pos: Vector3, n := 6, rot_y := 0.0) -> void:
	var paper := Mats.get_mat("paper")
	for i in n:
		Geo.box(parent, pos + Vector3(0, 0.004 + i * 0.008, 0), Vector3(0.21, 0.007, 0.297), paper, false, rot_y + randf_range(-0.08, 0.08))


## A panel door in a wall along local Z (the wall's centre line at local x 0, the room on +X): casing on both faces,
## the leaf on a hinge at -Z opening into the room (+rotation), a narrow wired light, a lever each side, a plate over
## it. Returns {root, leaf, block, use}; the use is "문 열기" with no callback.
static func door(parent: Node3D, pos: Vector3, rot_y: float, plate_text := "", wall := 0.3) -> Dictionary:
	var root := _holder(parent, pos, rot_y)
	var casing := Mats.std(Color(0.42, 0.42, 0.4), 0.5, 0.3)
	var paint := Mats.std(Color(0.66, 0.64, 0.58), 0.6, 0.1)
	for sz in [-1.0, 1.0]:
		Geo.box(root, Vector3(0, 1.065, sz * 0.505), Vector3(wall + 0.04, 2.13, 0.06), casing, false)
	Geo.box(root, Vector3(0, 2.16, 0), Vector3(wall + 0.04, 0.06, 1.07), casing, false)
	var leaf := Node3D.new()
	root.add_child(leaf)
	leaf.position = Vector3(0, 0, -0.475)
	Geo.box(leaf, Vector3(0, 1.055, 0.47), Vector3(0.045, 2.08, 0.93), paint, false)
	Geo.box(leaf, Vector3(0, 1.45, 0.68), Vector3(0.05, 0.5, 0.13), Mats.std(Color(0.05, 0.06, 0.07), 0.15, 0.3), false)
	for sx in [-1.0, 1.0]:
		Geo.box(leaf, Vector3(sx * 0.045, 1.0, 0.82), Vector3(0.025, 0.025, 0.13), Mats.get_mat("metal"), false)
		Geo.box(leaf, Vector3(sx * 0.03, 1.0, 0.86), Vector3(0.015, 0.06, 0.04), Mats.get_mat("metal"), false)
	var block := Geo.blocker(root, Vector3(0, 1.065, 0), Vector3(wall, 2.13, 0.95))
	var use := Interactable.create(root, Vector3(0, 1.05, 0), Vector3(wall + 0.3, 2.0, 0.9), "문 열기", Callable())
	use.press_sound = ""
	if plate_text != "":
		var plate := Node3D.new()
		root.add_child(plate)
		plate.position = Vector3(wall * 0.5 + 0.012, 2.36, 0)
		plate.rotation.y = PI / 2
		Geo.box(plate, Vector3.ZERO, Vector3(0.44, 0.13, 0.012), Mats.std(Color(0.16, 0.17, 0.19), 0.45, 0.3), false)
		var l := Geo.label(plate, plate_text, Vector3(0, 0, 0.008), 0.0, 36, Color(0.95, 0.95, 0.92), 0.0026)
		Geo.fit(l, 0.38, 0.09)
		l.set_meta("no_fit", true)
	return {"root": root, "leaf": leaf, "block": block, "use": use}


## A window on a wall face (facing +Z) with its vertical blinds drawn: casing, a dark pane behind, slats turned a little.
static func blinds_window(parent: Node3D, center: Vector3, rot_y: float, size := Vector2(1.6, 1.3)) -> void:
	var h := _holder(parent, center, rot_y)
	var casing := Mats.std(Color(0.42, 0.42, 0.4), 0.5, 0.3)
	Geo.box(h, Vector3(0, 0, 0.005), Vector3(size.x, size.y, 0.01), Mats.std(Color(0.04, 0.05, 0.06), 0.15, 0.2), false)
	for sx in [-1.0, 1.0]:
		Geo.box(h, Vector3(sx * (size.x * 0.5 + 0.03), 0, 0.02), Vector3(0.06, size.y + 0.12, 0.04), casing, false)
	for sy in [-1.0, 1.0]:
		Geo.box(h, Vector3(0, sy * (size.y * 0.5 + 0.03), 0.02), Vector3(size.x + 0.12, 0.06, 0.04), casing, false)
	Geo.box(h, Vector3(0, size.y * 0.5 - 0.03, 0.07), Vector3(size.x, 0.04, 0.05), Mats.get_mat("plastic_white"), false)
	var slat := Mats.std(Color(0.82, 0.8, 0.74), 0.8)
	var n := int(size.x / 0.085)
	for i in n:
		var s := Geo.box(h, Vector3(-size.x * 0.5 + 0.04 + i * 0.085, -0.02, 0.07), Vector3(0.08, size.y - 0.06, 0.003), slat, false)
		s.rotation.y = 0.35


static func armchair(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var h := _holder(parent, pos, rot_y)
	var fabric := Mats.std(Color(0.2, 0.22, 0.26), 0.9)
	Geo.box(h, Vector3(0, 0.22, 0), Vector3(0.62, 0.3, 0.62), fabric, false)
	Geo.box(h, Vector3(0, 0.62, -0.27), Vector3(0.62, 0.62, 0.12), fabric, false)
	for sx in [-1.0, 1.0]:
		Geo.box(h, Vector3(sx * 0.33, 0.45, 0.0), Vector3(0.1, 0.22, 0.62), fabric, false)
	Geo.blocker(h, Vector3(0, 0.4, 0), Vector3(0.75, 0.8, 0.7))


## What lies about in a drawer of `w` x `d`: papers, pens, a stapler, tape, a torch, batteries — or nothing much.
static func clutter(inside: Node3D, rng: RandomNumberGenerator, w: float, d: float) -> void:
	var n := rng.randi_range(0, 4)
	for i in n:
		var p := Vector3(rng.randf_range(-w * 0.3, w * 0.3), 0.0, rng.randf_range(-d * 0.3, d * 0.3))
		var r := rng.randf() * TAU
		match rng.randi() % 6:
			0:
				paper_stack(inside, p, rng.randi_range(2, 6), r)
			1:
				var pen := Geo.cyl(inside, p + Vector3(0, 0.006, 0), 0.005, 0.14, Mats.std(Color(0.1, 0.2, 0.6), 0.5))
				pen.rotation = Vector3(PI / 2, r, 0)
			2:
				Geo.box(inside, p + Vector3(0, 0.02, 0), Vector3(0.04, 0.04, 0.14), Mats.std(Color(0.12, 0.12, 0.13), 0.4, 0.4), false, r)
			3:
				var tape := Geo.cyl(inside, p + Vector3(0, 0.012, 0), 0.04, 0.024, Mats.std(Color(0.75, 0.72, 0.6), 0.4))
				tape.rotation.y = r
			4:
				var torch := Geo.cyl(inside, p + Vector3(0, 0.02, 0), 0.018, 0.18, Mats.std(Color(0.15, 0.15, 0.16), 0.4, 0.5))
				torch.rotation = Vector3(PI / 2, r, 0)
			_:
				for k in 2:
					var bat := Geo.cyl(inside, p + Vector3(k * 0.025, 0.007, 0), 0.007, 0.05, Mats.std(Color(0.7, 0.55, 0.1), 0.4, 0.5))
					bat.rotation = Vector3(PI / 2, r, 0)
