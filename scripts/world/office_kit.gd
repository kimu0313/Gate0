class_name OfficeKit
## The security office's furniture (Terminal._build_security_office), from boxes: desks with a drawer pedestal, filing
## cabinets, a bookshelf of binders, a glass-front cabinet, an old CRT, desk lamps, cartons and paper, panel doors
## with a narrow light, windows with their vertical blinds drawn, an armchair, and the CCTV station's monitors (live
## camera feeds), server rack, control keyboard and PC tower. Every drawer is a Drawer ([E] opens it). Colliders stop
## short of the drawer fronts, so the [E] ray reaches them (the ray hits world colliders too).
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
## at local z `face`. Returns the drawers; not `live`, the fronts are only fronts (no [E]) and none are returned.
static func _pedestal(holder: Node3D, cx: float, face: float, w: float, top_y: float, depth: float, heights: Array,
		body: Material, front: Material, live := true) -> Array[Drawer]:
	var drawers: Array[Drawer] = []
	for sx in [-1.0, 1.0]:
		Geo.box(holder, Vector3(cx + sx * (w * 0.5 - 0.01), top_y * 0.5, face - depth * 0.5), Vector3(0.02, top_y, depth), body, false)
	Geo.box(holder, Vector3(cx, top_y * 0.5, face - depth + 0.01), Vector3(w, top_y, 0.02), body, false)
	Geo.box(holder, Vector3(cx, 0.03, face - depth * 0.5 - 0.02), Vector3(w - 0.04, 0.06, depth - 0.04), Mats.get_mat("metal_dark"), false)
	var y := top_y - 0.012
	for h: float in heights:
		y -= h
		var at := Vector3(cx, y + h * 0.5, face)
		if live:
			drawers.append(Drawer.create(holder, at, 0.0, Vector3(w - 0.02, h - 0.008, depth - 0.06), front))
		else:
			Geo.box(holder, at + Vector3(0, 0, -0.002), Vector3(w - 0.026, h - 0.014, 0.02), front, false)
			Geo.box(holder, at + Vector3(0, h * 0.5 - minf(0.05, h * 0.25), 0.018), Vector3(minf(0.22, w * 0.5), 0.018, 0.022),
					Mats.get_mat("metal"), false)
		y -= 0.008
	return drawers


## Office desk `size` (width, height, depth) with a pedestal of three drawers at one end (`side` +1 = local +X); not
## `live`, its drawers do not open.
static func desk(parent: Node3D, pos: Vector3, rot_y: float, size: Vector3, side := 1.0, live := true) -> Array[Drawer]:
	var h := _holder(parent, pos, rot_y)
	var top := Mats.get_mat("wood")
	var body := Mats.std(Color(0.52, 0.52, 0.5), 0.6, 0.25)
	Geo.box(h, Vector3(0, size.y - 0.0175, 0), Vector3(size.x, 0.035, size.z), top, false)
	Geo.box(h, Vector3(0, size.y - 0.3, -size.z * 0.5 + 0.05), Vector3(size.x - 0.06, 0.45, 0.02), body, false)
	Geo.box(h, Vector3(-side * (size.x * 0.5 - 0.02), (size.y - 0.035) * 0.5, 0), Vector3(0.035, size.y - 0.035, size.z - 0.04), body, false)
	var pw := 0.42
	var cx := side * (size.x * 0.5 - pw * 0.5 - 0.01)
	var face := size.z * 0.5 - 0.03
	var drawers := _pedestal(h, cx, face, pw, size.y - 0.035, size.z - 0.08, [0.15, 0.2, 0.28], body, steel(), live)
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


## A status LED (shaders/led_blink): steady when `rate` is 0, else blinking `rate` times a second; `size` across
## (a bar when `wide` is given).
static func led(parent: Node3D, pos: Vector3, color: Color, rate := 0.0, phase := 0.0, size := 0.007, wide := 0.0) -> void:
	var l := Geo.box(parent, pos, Vector3(maxf(size, wide), size, 0.004), Mats.get_mat("led_blink"), false)
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	l.set_instance_shader_parameter("led_color", Vector3(color.r, color.g, color.b))
	l.set_instance_shader_parameter("rate", rate)
	l.set_instance_shader_parameter("phase", phase)


## A CRT's glass (facing +Z) centred on `pos`, with a dark rim round it: a live camera (shaders/cctv_feed), static
## ("snow") or dead dark glass ("off").
static func crt_glass(parent: Node3D, pos: Vector3, size: Vector2, mode: String, seed_n: float) -> void:
	Geo.box(parent, pos + Vector3(0, 0, -0.006), Vector3(size.x + 0.035, size.y + 0.035, 0.01), Mats.std(Color(0.03, 0.035, 0.035), 0.3, 0.2), false)
	if mode == "off":
		Geo.box(parent, pos, Vector3(size.x, size.y, 0.004), Mats.std(Color(0.035, 0.045, 0.045), 0.08, 0.3), false)
		return
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = Mats.get_mat("cctv_feed")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos + Vector3(0, 0, 0.002)
	mi.set_instance_shader_parameter("seed", seed_n)
	mi.set_instance_shader_parameter("dead", 0.0 if mode == "snow" else -1.0)
	mi.set_instance_shader_parameter("snow", 1.0 if mode == "snow" else 0.0)


## A run of the CCTV room's console (the Evil Within reference), `length` along local X, its back on local z 0 and the
## operator on +Z: a steel cabinet base (open under the worktop where `knee`), a dark worktop with a bright metal
## nosing, an upright bay of `cells` — built-in CRTs ("crt", "snow", "off"), control panels ("panel"), a tape deck
## ("deck") — and odds and ends along its top. `lift` raises it a few millimetres where two runs meet.
static func console(parent: Node3D, pos: Vector3, rot_y: float, length: float, cells: Array, seed_n: int, knee := false,
		lift := 0.0) -> void:
	var h := _holder(parent, pos + Vector3(0, lift, 0), rot_y)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var depth := 0.78
	var body := Mats.std(Color(0.2, 0.22, 0.22), 0.55, 0.45)
	var seam := Mats.std(Color(0.07, 0.075, 0.075), 0.8)
	if knee:
		for sx in [-1.0, 1.0]:
			Geo.box(h, Vector3(sx * (length * 0.5 - 0.02), 0.37, depth * 0.45), Vector3(0.04, 0.74, depth * 0.9), body, false)
		Geo.box(h, Vector3(0, 0.37, 0.02), Vector3(length, 0.74, 0.04), body, false)
		Geo.box(h, Vector3(0, 0.66, depth - 0.16), Vector3(length - 0.08, 0.15, 0.025), body, false)
	else:
		Geo.box(h, Vector3(0, 0.4, (depth - 0.1) * 0.5), Vector3(length, 0.72, depth - 0.1), body, false)
		Geo.box(h, Vector3(0, 0.035, depth - 0.12), Vector3(length - 0.02, 0.07, 0.04), seam, false)
		var n := maxi(1, roundi(length / 0.45))
		for i in n:
			var dx := -length * 0.5 + length * (i + 0.5) / n
			Geo.box(h, Vector3(dx - length * 0.5 / n + 0.004, 0.42, depth - 0.098), Vector3(0.006, 0.6, 0.004), seam, false)
			Geo.box(h, Vector3(dx + length * 0.3 / n, 0.62, depth - 0.088), Vector3(0.02, 0.09, 0.02), Mats.get_mat("metal"), false)
	Geo.box(h, Vector3(0, 0.76, depth * 0.5), Vector3(length, 0.035, depth), Mats.std(Color(0.12, 0.13, 0.13), 0.35, 0.2), false)
	Geo.box(h, Vector3(0, 0.757, depth + 0.012), Vector3(length, 0.05, 0.025), Mats.std(Color(0.62, 0.55, 0.42), 0.3, 0.85), false)
	var bay_d := 0.34
	var bay_h := 0.56
	var by := 0.78 + bay_h * 0.5
	Geo.box(h, Vector3(0, by, bay_d * 0.5), Vector3(length, bay_h, bay_d), body, false)
	Geo.box(h, Vector3(0, 0.78 + bay_h + 0.012, bay_d * 0.5 + 0.02), Vector3(length + 0.01, 0.024, bay_d + 0.05), body, false)
	var plate := Mats.std(Color(0.33, 0.35, 0.35), 0.5, 0.5)
	var cw := length / cells.size()
	for i in cells.size():
		var c := Vector3(-length * 0.5 + cw * (i + 0.5), by, bay_d + 0.003)
		var kind: String = cells[i]
		Geo.box(h, c + Vector3(0, 0, -0.002), Vector3(cw - 0.04, bay_h - 0.06, 0.01), plate, false)
		match kind:
			"panel":
				_panel(h, c, Vector2(cw - 0.08, bay_h - 0.1), rng)
			"deck":
				_deck(h, c, Vector2(cw - 0.08, bay_h - 0.1), rng)
			_:
				crt_glass(h, c + Vector3(0, 0.045, 0.006), Vector2(minf(cw - 0.14, 0.4), 0.3), kind, float(seed_n) * 3.1 + i)
				for k in 6:
					Geo.box(h, c + Vector3(-0.13 + k * 0.045, -0.2, 0.008), Vector3(0.03, 0.018, 0.012), Mats.get_mat("plastic_dark"), false)
				led(h, c + Vector3(0.16, -0.2, 0.008), Color(0.3, 1.0, 0.45))
	# along the top: bottles, small boxes, a binder lying down, a reel of tape
	var x := -length * 0.5 + 0.12
	while x < length * 0.5 - 0.12:
		var top := Vector3(x, 0.78 + bay_h + 0.024, bay_d * 0.5)
		match rng.randi() % 5:
			0:
				for k in rng.randi_range(1, 3):
					Geo.cyl(h, top + Vector3(k * 0.06, 0.07, rng.randf_range(-0.05, 0.05)), 0.025, 0.14, Mats.std(Color(0.16, 0.1, 0.05), 0.2))
			1:
				carton(h, top, Vector3(0.18, 0.1, 0.2), rng.randf_range(-0.3, 0.3))
			2:
				Geo.box(h, top + Vector3(0, 0.02, 0), Vector3(0.3, 0.04, 0.24), Mats.std(Color(0.12, 0.2, 0.4), 0.7), false, rng.randf_range(-0.2, 0.2))
			3:
				Geo.cyl(h, top + Vector3(0, 0.01, 0), 0.11, 0.02, Mats.std(Color(0.3, 0.3, 0.32), 0.4, 0.6))
		x += rng.randf_range(0.28, 0.46)
	Geo.blocker(h, Vector3(0, 0.67, depth * 0.5), Vector3(length, 1.34, depth))


## A control panel's face (facing +Z) centred on `c`: VU meters, two rows of knobs, toggle switches with their lamps,
## a red time display.
static func _panel(h: Node3D, c: Vector3, size: Vector2, rng: RandomNumberGenerator) -> void:
	var knob := Mats.std(Color(0.08, 0.08, 0.085), 0.4, 0.3)
	var cap := Mats.std(Color(0.78, 0.77, 0.72), 0.4, 0.5)
	var meter := Mats.emissive(Color(0.55, 0.75, 0.45), 0.45, Color(0.6, 0.7, 0.5))
	var y := c.y + size.y * 0.5 - 0.05
	var nm := maxi(1, int(size.x / 0.13))
	for i in nm:
		var mx := c.x - size.x * 0.5 + size.x * (i + 0.5) / nm
		Geo.box(h, Vector3(mx, y, c.z + 0.004), Vector3(0.09, 0.05, 0.006), meter, false)
		var needle := Geo.box(h, Vector3(mx, y - 0.004, c.z + 0.008), Vector3(0.003, 0.04, 0.002), Mats.get_mat("black"), false)
		needle.rotation.z = rng.randf_range(-0.6, 0.4)
	var nk := maxi(2, int(size.x / 0.06))
	for row in 2:
		var ky := y - 0.085 - row * 0.075
		for i in nk:
			var kx := c.x - size.x * 0.5 + size.x * (i + 0.5) / nk
			var k := Geo.cyl(h, Vector3(kx, ky, c.z + 0.014), 0.017, 0.024, knob)
			k.rotation.x = PI / 2
			var a := rng.randf_range(-2.2, 2.2)
			var mark := Geo.box(h, Vector3(kx - sin(a) * 0.009, ky + cos(a) * 0.009, c.z + 0.027), Vector3(0.003, 0.012, 0.002), cap, false)
			mark.rotation.z = a
	var lamps := [Color(0.3, 1.0, 0.45), Color(1.0, 0.25, 0.15), Color(1.0, 0.65, 0.15)]
	var ns := maxi(2, int(size.x / 0.045))
	for i in ns:
		var sx := c.x - size.x * 0.5 + size.x * (i + 0.5) / ns
		var sw := Geo.box(h, Vector3(sx, y - 0.27, c.z + 0.014), Vector3(0.008, 0.026, 0.008), cap, false)
		sw.rotation.x = 0.5 if rng.randf() < 0.5 else -0.5
		if rng.randf() < 0.6:
			led(h, Vector3(sx, y - 0.24, c.z + 0.006), lamps[rng.randi() % lamps.size()],
					rng.randf_range(0.5, 2.0) if rng.randf() < 0.3 else 0.0, rng.randf(), 0.006)
	if size.y > 0.38:
		Geo.box(h, Vector3(c.x, c.y - size.y * 0.5 + 0.035, c.z + 0.004), Vector3(0.12, 0.032, 0.006), Mats.emissive(Color(1.0, 0.18, 0.1), 1.2), false)


## A reel-to-reel deck's face (facing +Z) centred on `c`: two reels over a smoked window, transport keys, a counter.
static func _deck(h: Node3D, c: Vector3, size: Vector2, rng: RandomNumberGenerator) -> void:
	Geo.box(h, Vector3(c.x, c.y + 0.06, c.z + 0.004), Vector3(size.x - 0.04, 0.22, 0.006), Mats.std(Color(0.05, 0.06, 0.06), 0.15, 0.3), false)
	for sx in [-1.0, 1.0]:
		var reel := Geo.cyl(h, Vector3(c.x + sx * size.x * 0.22, c.y + 0.06, c.z + 0.012), 0.075, 0.008, Mats.std(Color(0.55, 0.55, 0.56), 0.4, 0.7))
		reel.rotation.x = PI / 2
		var tape := Geo.cyl(h, Vector3(c.x + sx * size.x * 0.22, c.y + 0.06, c.z + 0.016), 0.05, 0.006, Mats.std(Color(0.12, 0.08, 0.05), 0.6))
		tape.rotation.x = PI / 2
		var hub := Geo.cyl(h, Vector3(c.x + sx * size.x * 0.22, c.y + 0.06, c.z + 0.021), 0.015, 0.008, Mats.get_mat("metal"))
		hub.rotation.x = PI / 2
	var key := Mats.std(Color(0.72, 0.72, 0.7), 0.5, 0.4)
	for i in 6:
		Geo.box(h, Vector3(c.x - 0.13 + i * 0.052, c.y - 0.11, c.z + 0.012), Vector3(0.04, 0.03, 0.02), key, false)
	Geo.box(h, Vector3(c.x + size.x * 0.3, c.y - 0.18, c.z + 0.005), Vector3(0.08, 0.025, 0.006), Mats.emissive(Color(0.4, 1.0, 0.5), 0.8), false)
	led(h, Vector3(c.x - size.x * 0.35, c.y - 0.18, c.z + 0.006), Color(1.0, 0.2, 0.1), 1.0, rng.randf(), 0.008)


## The bank of CCTV monitors over the console: two rows of CRTs in a steel cabinet (back on local z 0, the screens
## toward +Z) from `y0` up, closed above to `ceiling`. `modes` per CRT, top row first: "crt" (a camera), "snow",
## "off".
static func crt_bank(parent: Node3D, pos: Vector3, rot_y: float, length: float, modes: Array, seed_n: int, y0 := 1.55,
		ceiling := 2.85) -> void:
	var h := _holder(parent, pos, rot_y)
	var cols := int(modes.size() * 0.5)
	var depth := 0.46
	var cell_h := 0.42
	var body := Mats.std(Color(0.15, 0.16, 0.16), 0.5, 0.5)
	var top := y0 + 2.0 * cell_h + 0.04
	Geo.box(h, Vector3(0, y0 - 0.03, depth * 0.5), Vector3(length, 0.06, depth), body, false)
	Geo.box(h, Vector3(0, y0 + cell_h, depth * 0.5), Vector3(length, 0.025, depth), body, false)
	Geo.box(h, Vector3(0, (top + ceiling) * 0.5, depth * 0.5 - 0.03), Vector3(length, ceiling - top, depth - 0.06), body, false)
	Geo.box(h, Vector3(0, top - 0.01, depth * 0.5), Vector3(length + 0.01, 0.04, depth + 0.02), body, false)
	Geo.box(h, Vector3(0, (y0 + top) * 0.5, 0.02), Vector3(length, top - y0, 0.04), body, false)
	var cw := length / cols
	for i in cols + 1:
		Geo.box(h, Vector3(clampf(-length * 0.5 + i * cw, -length * 0.5 + 0.015, length * 0.5 - 0.015), (y0 + top) * 0.5, depth * 0.5),
				Vector3(0.03, top - y0, depth), body, false)
	var casing := Mats.std(Color(0.24, 0.25, 0.25), 0.45, 0.35)
	for r in 2:
		for c in cols:
			var mode: String = modes[r * cols + c]
			var cy := y0 + (1.5 - r) * cell_h
			var cx := -length * 0.5 + (c + 0.5) * cw
			Geo.box(h, Vector3(cx, cy, depth * 0.5 + 0.01), Vector3(cw - 0.06, cell_h - 0.05, depth - 0.06), casing, false)
			crt_glass(h, Vector3(cx, cy + 0.015, depth - 0.012), Vector2(cw - 0.15, cell_h - 0.14), mode, float(seed_n) * 7.0 + r * 3.0 + c)
			led(h, Vector3(cx + cw * 0.5 - 0.07, cy - cell_h * 0.5 + 0.045, depth - 0.016), Color(1.0, 0.25, 0.15) if mode == "off" else Color(0.3, 1.0, 0.45))


## An open steel rack (facing +Z) of the VCRs that record the cameras: four shelves of decks, their clocks blinking,
## cassettes stacked beside and on top.
static func vcr_rack(parent: Node3D, pos: Vector3, rot_y: float, seed_n := 5) -> void:
	var h := _holder(parent, pos, rot_y)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var size := Vector3(0.95, 1.45, 0.45)
	var frame := Mats.std(Color(0.3, 0.32, 0.33), 0.45, 0.6)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Geo.box(h, Vector3(sx * (size.x * 0.5 - 0.015), size.y * 0.5, sz * (size.z * 0.5 - 0.015)), Vector3(0.03, size.y, 0.03), frame, false)
	var deck := Mats.std(Color(0.16, 0.165, 0.17), 0.4, 0.5)
	var silver := Mats.std(Color(0.55, 0.56, 0.57), 0.35, 0.7)
	var tape := Mats.std(Color(0.03, 0.03, 0.035), 0.5)
	for s in 5:
		var y := 0.06 + s * 0.345
		Geo.box(h, Vector3(0, y, 0), Vector3(size.x, 0.02, size.z), frame, false)
		if s == 4:
			break
		for k in 2:
			var cx := -0.22 + k * 0.45
			if s == 3 and k == 1:
				for t in rng.randi_range(4, 8):          # cassettes lying in a pile
					Geo.box(h, Vector3(cx, y + 0.025 + t * 0.026, rng.randf_range(-0.03, 0.03)), Vector3(0.19, 0.025, 0.105), tape, false, rng.randf_range(-0.2, 0.2))
				continue
			Geo.box(h, Vector3(cx, y + 0.055, 0), Vector3(0.42, 0.09, 0.34), deck if (s + k) % 2 == 0 else silver, false)
			Geo.box(h, Vector3(cx - 0.06, y + 0.065, 0.171), Vector3(0.2, 0.022, 0.004), Mats.get_mat("black"), false)
			led(h, Vector3(cx + 0.12, y + 0.07, 0.172), Color(0.35, 1.0, 0.5), 1.0, rng.randf(), 0.018, 0.06)
			for b in 4:
				Geo.box(h, Vector3(cx - 0.13 + b * 0.04, y + 0.03, 0.172), Vector3(0.028, 0.012, 0.006), Mats.get_mat("plastic_grey"), false)
	for t in rng.randi_range(3, 6):                     # tapes standing on top
		Geo.box(h, Vector3(-0.35 + t * 0.03, 1.45 + 0.055, 0), Vector3(0.025, 0.105, 0.19), tape, false)
	Geo.blocker(h, Vector3(0, size.y * 0.5, 0), size)


## An office partition from `a` to `b` (floor points) up to `ceiling`: a painted steel dado, wired glass over it, a
## solid band at the top, posts every metre or so; `gaps` ([from, to], metres from `a`) are open doorways under a 2.1 m
## head. Colliders the full height but for the doorways.
static func partition(parent: Node3D, a: Vector2, b: Vector2, ceiling: float, gaps := []) -> Node3D:
	var along := b - a
	var l := along.length()
	var dir := along / l
	var h := _holder(parent, Vector3(a.x, 0, a.y), atan2(-dir.y, dir.x))
	var paint := Mats.std(Color(0.43, 0.47, 0.44), 0.6, 0.25)
	var frame := Mats.std(Color(0.28, 0.3, 0.29), 0.45, 0.5)
	var wired := Mats.std(Color(0.55, 0.62, 0.62, 0.2), 0.06, 0.2)
	wired.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var wire := Mats.std(Color(0.2, 0.22, 0.22, 0.5), 0.5, 0.4)
	wire.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var t := 0.08
	var solid := []
	var cur := 0.0
	for g: Array in gaps:
		solid.append([cur, g[0]])
		cur = g[1]
	solid.append([cur, l])
	for s: Array in solid:
		var s0: float = s[0]
		var s1: float = s[1]
		var w := s1 - s0
		if w < 0.01:
			continue
		var m := (s0 + s1) * 0.5
		Geo.box(h, Vector3(m, 0.475, 0), Vector3(w, 0.95, t), paint, false)
		Geo.box(h, Vector3(m, 0.97, 0), Vector3(w, 0.04, t + 0.03), frame, false)
		Geo.box(h, Vector3(m, 1.56, 0), Vector3(w, 1.14, 0.008), wired, false)
		for k in 9:                                            # the wire in the glass
			Geo.box(h, Vector3(m, 1.0 + k * 0.13, 0.0045), Vector3(w, 0.002, 0.001), wire, false)
		var n := maxi(1, ceili(w / 1.1))
		for i in n + 1:
			Geo.box(h, Vector3(clampf(s0 + w * i / n, s0 + 0.025, s1 - 0.025), 1.07, 0), Vector3(0.05, 2.14, t + 0.02), frame, false)
		Geo.blocker(h, Vector3(m, ceiling * 0.5, 0), Vector3(w, ceiling, t))
	Geo.box(h, Vector3(l * 0.5, (2.14 + ceiling) * 0.5, 0), Vector3(l, ceiling - 2.14, t), paint, false)
	Geo.box(h, Vector3(l * 0.5, 2.15, 0), Vector3(l, 0.04, t + 0.03), frame, false)
	for g: Array in gaps:
		for e: float in [g[0], g[1]]:
			Geo.box(h, Vector3(e, 1.07, 0), Vector3(0.06, 2.14, t + 0.03), frame, false)
	return h


## A window on a wall face (facing +Z) with a roller blind pulled `down` (0..1) over it: casing, a dark pane, the
## roller's box at the head, the cloth (water-stained) and its bottom bar, the pull cord.
static func roller_window(parent: Node3D, center: Vector3, rot_y: float, size := Vector2(1.6, 1.3), down := 1.0) -> void:
	var h := _holder(parent, center, rot_y)
	var casing := Mats.std(Color(0.42, 0.42, 0.4), 0.5, 0.3)
	Geo.box(h, Vector3(0, 0, 0.005), Vector3(size.x, size.y, 0.01), Mats.std(Color(0.04, 0.05, 0.06), 0.15, 0.2), false)
	for sx in [-1.0, 1.0]:
		Geo.box(h, Vector3(sx * (size.x * 0.5 + 0.03), 0, 0.02), Vector3(0.06, size.y + 0.12, 0.04), casing, false)
	for sy in [-1.0, 1.0]:
		Geo.box(h, Vector3(0, sy * (size.y * 0.5 + 0.03), 0.02), Vector3(size.x + 0.12, 0.06, 0.04), casing, false)
	Geo.box(h, Vector3(0, -size.y * 0.5 - 0.05, 0.07), Vector3(size.x + 0.2, 0.025, 0.14), casing, false)       # sill
	Geo.box(h, Vector3(0, size.y * 0.5 + 0.07, 0.08), Vector3(size.x + 0.16, 0.12, 0.11), Mats.std(Color(0.8, 0.79, 0.75), 0.5), false)
	var drop := size.y * down
	var cloth := Mats.std(Color(0.7, 0.67, 0.58), 0.95)
	Geo.box(h, Vector3(0, size.y * 0.5 - drop * 0.5, 0.085), Vector3(size.x + 0.04, drop, 0.004), cloth, false)
	Geo.box(h, Vector3(size.x * 0.22, size.y * 0.5 - drop * 0.35, 0.0875), Vector3(size.x * 0.3, drop * 0.25, 0.001),
			Mats.std(Color(0.56, 0.5, 0.4), 0.95), false)
	Geo.box(h, Vector3(0, size.y * 0.5 - drop, 0.085), Vector3(size.x + 0.06, 0.025, 0.018), Mats.get_mat("metal"), false)
	Geo.cyl(h, Vector3(size.x * 0.5 - 0.06, size.y * 0.5 - drop - 0.18, 0.09), 0.003, 0.34, Mats.std(Color(0.8, 0.78, 0.7), 0.8))
	Geo.cyl(h, Vector3(size.x * 0.5 - 0.06, size.y * 0.5 - drop - 0.36, 0.09), 0.01, 0.03, Mats.get_mat("plastic_white"))


## A louvred vent grille (facing +Z, or down with `tilt_x` PI / 2) `size`, centred on `pos`: frame, the dark duct
## behind, slats.
static func vent_grille(parent: Node3D, pos: Vector3, rot_y: float, size: Vector2, tilt_x := 0.0) -> void:
	var h := _holder(parent, pos, rot_y)
	h.rotation.x = tilt_x
	var frame := Mats.std(Color(0.7, 0.71, 0.7), 0.5, 0.4)
	Geo.box(h, Vector3(0, 0, -0.008), Vector3(size.x, size.y, 0.01), Mats.get_mat("black"), false)
	for sy in [-1.0, 1.0]:
		Geo.box(h, Vector3(0, sy * (size.y * 0.5 - 0.015), 0.006), Vector3(size.x, 0.03, 0.02), frame, false)
	for sx in [-1.0, 1.0]:
		Geo.box(h, Vector3(sx * (size.x * 0.5 - 0.015), 0, 0.006), Vector3(0.03, size.y, 0.02), frame, false)
	var n := maxi(2, int(size.y / 0.045))
	for i in n:
		var s := Geo.box(h, Vector3(0, -size.y * 0.5 + 0.04 + i * (size.y - 0.08) / (n - 1), 0.0), Vector3(size.x - 0.05, 0.004, 0.026), frame, false)
		s.rotation.x = 0.6


## A ceiling fan hung from `ceiling_y` over the floor point `pos`: canopy, down-rod, motor, four wooden blades going
## round slowly.
static func ceiling_fan(parent: Node3D, pos: Vector3, ceiling_y: float) -> void:
	var h := _holder(parent, Vector3(pos.x, ceiling_y, pos.z), 0.0)
	var white := Mats.std(Color(0.78, 0.77, 0.72), 0.45, 0.2)
	Geo.cyl(h, Vector3(0, -0.03, 0), 0.07, 0.06, white)
	Geo.cyl(h, Vector3(0, -0.2, 0), 0.012, 0.3, Mats.get_mat("metal"))
	var rotor := Node3D.new()
	h.add_child(rotor)
	rotor.position.y = -0.42
	Geo.cyl(rotor, Vector3.ZERO, 0.11, 0.12, white)
	Geo.cyl(rotor, Vector3(0, -0.085, 0), 0.06, 0.05, white)
	var blade := Mats.std(Color(0.5, 0.38, 0.25), 0.6)
	for i in 4:
		var arm := Node3D.new()
		rotor.add_child(arm)
		arm.rotation.y = i * PI / 2
		Geo.box(arm, Vector3(0.17, -0.01, 0), Vector3(0.14, 0.012, 0.035), Mats.get_mat("metal_dark"), false)
		Geo.box(arm, Vector3(0.48, -0.01, 0), Vector3(0.52, 0.008, 0.13), blade, false).rotation.x = 0.14
	var tw := rotor.create_tween().set_loops()
	tw.tween_property(rotor, "rotation:y", TAU, 2.8).from(0.0)


## A fan facing +Z: a round wire guard, three blades, the motor behind, on a wall bracket (`wall`) or on a desk base.
static func fan(parent: Node3D, pos: Vector3, rot_y: float, wall := true) -> void:
	var h := _holder(parent, pos, rot_y)
	var head := Node3D.new()
	h.add_child(head)
	head.position = Vector3(0, 0.0 if wall else 0.3, 0.0)
	head.rotation.x = 0.35 if wall else 0.05
	var blue := Mats.std(Color(0.16, 0.3, 0.52), 0.45, 0.25)
	for k in 2:
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.17
		tm.outer_radius = 0.182
		ring.mesh = tm
		ring.material_override = blue
		head.add_child(ring)
		ring.rotation.x = PI / 2
		ring.position.z = 0.02 - k * 0.07
	for i in 6:
		var spoke := Geo.box(head, Vector3(0, 0, 0.02), Vector3(0.35, 0.004, 0.004), blue, false)
		spoke.rotation.z = i * PI / 6
	for i in 3:
		var b := Node3D.new()
		head.add_child(b)
		b.rotation.z = i * TAU / 3
		Geo.box(b, Vector3(0, 0.08, -0.025), Vector3(0.08, 0.13, 0.004), Mats.std(Color(0.35, 0.55, 0.78), 0.4), false).rotation.y = 0.35
	Geo.cyl(head, Vector3(0, 0, -0.01), 0.03, 0.03, blue).rotation.x = PI / 2
	Geo.cyl(head, Vector3(0, 0, -0.11), 0.065, 0.12, Mats.std(Color(0.7, 0.7, 0.68), 0.4, 0.3)).rotation.x = PI / 2
	if wall:
		Geo.box(h, Vector3(0, -0.06, -0.2), Vector3(0.05, 0.04, 0.22), Mats.get_mat("metal_dark"), false)
		Geo.box(h, Vector3(0, -0.06, -0.31), Vector3(0.12, 0.16, 0.012), Mats.get_mat("metal_dark"), false)
	else:
		Geo.cyl(h, Vector3(0, 0.012, 0), 0.09, 0.024, blue)
		Geo.cyl(h, Vector3(0, 0.15, -0.02), 0.012, 0.28, Mats.get_mat("metal"))


## A bank of `n` steel lockers (0.4 x 1.8 x 0.5 m each) facing +Z, centred on `pos`: louvres top and bottom, a pull,
## a name card (`names`) and a number; locker `ajar` stands a little open on a jacket; cartons on top.
static func lockers(parent: Node3D, pos: Vector3, rot_y: float, n: int, names: Array, ajar := -1, first := 1) -> void:
	var h := _holder(parent, pos, rot_y)
	var w := 0.4
	var ht := 1.8
	var d := 0.5
	var body := Mats.std(Color(0.4, 0.45, 0.42), 0.55, 0.35)
	var dark := Mats.std(Color(0.04, 0.04, 0.045), 0.9)
	var total := w * n
	Geo.box(h, Vector3(0, ht * 0.5, -0.02), Vector3(total, ht, d - 0.04), body, false)
	Geo.box(h, Vector3(0, 0.04, d * 0.5 - 0.03), Vector3(total, 0.08, 0.02), Mats.get_mat("metal_dark"), false)
	for i in n:
		var cx := -total * 0.5 + w * (i + 0.5)
		var door := Node3D.new()
		h.add_child(door)
		door.position = Vector3(cx - w * 0.5 + 0.015, 0, d * 0.5 - 0.02)
		if i == ajar:
			door.rotation.y = -0.75
			Geo.box(h, Vector3(cx, ht * 0.5 + 0.04, d * 0.5 - 0.035), Vector3(w - 0.04, ht - 0.13, 0.008), dark, false)
			Geo.box(h, Vector3(cx, 1.22, d * 0.5 - 0.11), Vector3(0.3, 0.62, 0.1), Mats.std(Color(0.18, 0.21, 0.2), 0.95), false)
			Geo.box(h, Vector3(cx + 0.02, 1.55, d * 0.5 - 0.11), Vector3(0.24, 0.03, 0.012), Mats.get_mat("metal"), false)
		var dw := w - 0.03
		Geo.box(door, Vector3(dw * 0.5, ht * 0.5 + 0.04, 0.01), Vector3(dw, ht - 0.12, 0.02), body, false)
		for k in 4:
			Geo.box(door, Vector3(dw * 0.5, 1.6 + k * 0.035, 0.021), Vector3(dw * 0.55, 0.012, 0.004), dark, false)
			Geo.box(door, Vector3(dw * 0.5, 0.22 + k * 0.035, 0.021), Vector3(dw * 0.55, 0.012, 0.004), dark, false)
		Geo.box(door, Vector3(dw - 0.05, 1.02, 0.03), Vector3(0.02, 0.14, 0.022), Mats.get_mat("metal"), false)
		var card := Geo.box(door, Vector3(dw * 0.5, 1.42, 0.022), Vector3(0.14, 0.045, 0.003), Mats.get_mat("paper"), false)
		if i < names.size() and names[i] != "":
			Geo.fit(Geo.label(card, names[i], Vector3(0, 0, 0.002), 0.0, 40, Color(0.1, 0.12, 0.3), 0.0012, false, "hand"), 0.12, 0.035)
		var num := Geo.box(door, Vector3(dw * 0.5, 1.745, 0.022), Vector3(0.07, 0.03, 0.003), Mats.std(Color(0.85, 0.84, 0.78), 0.6), false)
		Geo.fit(Geo.label(num, "%02d" % (first + i), Vector3(0, 0, 0.002), 0.0, 32, Color(0.1, 0.1, 0.1), 0.0011, true), 0.06, 0.024)
	Geo.blocker(h, Vector3(0, ht * 0.5, 0), Vector3(total, ht, d))


## A tall two-door steel cabinet `size` facing +Z, for documents: doors with long pulls, a key lock, and a card on a
## door for each of `tags`.
static func steel_cabinet(parent: Node3D, pos: Vector3, rot_y: float, size := Vector3(0.9, 1.8, 0.45), tags := []) -> void:
	var h := _holder(parent, pos, rot_y)
	var body := Mats.std(Color(0.42, 0.46, 0.44), 0.55, 0.35)
	Geo.box(h, Vector3(0, size.y * 0.5, -0.01), Vector3(size.x, size.y, size.z - 0.02), body, false)
	for sx in [-1.0, 1.0]:
		Geo.box(h, Vector3(sx * size.x * 0.25, size.y * 0.5 + 0.03, size.z * 0.5 - 0.005), Vector3(size.x * 0.5 - 0.012, size.y - 0.1, 0.012), body, false)
		Geo.box(h, Vector3(sx * 0.035, size.y * 0.53, size.z * 0.5 + 0.012), Vector3(0.02, 0.24, 0.02), Mats.get_mat("metal"), false)
	Geo.cyl(h, Vector3(0.07, size.y * 0.62, size.z * 0.5 + 0.004), 0.012, 0.01, Mats.get_mat("metal")).rotation.x = PI / 2
	Geo.box(h, Vector3(0, 0.03, size.z * 0.5 - 0.02), Vector3(size.x, 0.06, 0.02), Mats.get_mat("metal_dark"), false)
	for i in tags.size():
		var sx := -1.0 if i % 2 == 0 else 1.0
		tag(h, Vector3(sx * size.x * 0.25, size.y * 0.8 - floorf(i * 0.5) * 0.09, size.z * 0.5 + 0.001), 0.0, tags[i], Vector2(size.x * 0.4, 0.065))
	Geo.blocker(h, Vector3(0, size.y * 0.5, 0), size)


## A low two-door cabinet `size` facing +Z (a sideboard under a shelf), its top free for things.
static func low_cabinet(parent: Node3D, pos: Vector3, rot_y: float, size := Vector3(1.2, 0.85, 0.42)) -> void:
	var h := _holder(parent, pos, rot_y)
	var body := Mats.std(Color(0.5, 0.5, 0.47), 0.55, 0.25)
	Geo.box(h, Vector3(0, size.y * 0.5, 0), size, body, false)
	for sx in [-1.0, 1.0]:
		Geo.box(h, Vector3(sx * size.x * 0.25, size.y * 0.5 + 0.02, size.z * 0.5 + 0.004), Vector3(size.x * 0.5 - 0.02, size.y - 0.1, 0.008), body, false)
		Geo.box(h, Vector3(sx * 0.05, size.y * 0.65, size.z * 0.5 + 0.015), Vector3(0.015, 0.1, 0.02), Mats.get_mat("metal"), false)
	Geo.blocker(h, Vector3(0, size.y * 0.5, 0), size)


## A small key cabinet on a wall (facing +Z): a steel box with a narrow window, hooks and tags showing through.
static func key_box(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var h := _holder(parent, pos, rot_y)
	var body := Mats.std(Color(0.5, 0.52, 0.5), 0.5, 0.4)
	Geo.box(h, Vector3(0, 0, 0.05), Vector3(0.4, 0.5, 0.1), body, false)
	Geo.box(h, Vector3(0, 0, 0.101), Vector3(0.3, 0.38, 0.004), Mats.std(Color(0.1, 0.12, 0.13), 0.1, 0.3), false)
	for r in 3:
		for c in 4:
			Geo.box(h, Vector3(-0.1 + c * 0.065, 0.12 - r * 0.12, 0.096), Vector3(0.03, 0.045, 0.003),
					Mats.std([Color(0.8, 0.2, 0.15), Color(0.9, 0.85, 0.3), Color(0.2, 0.4, 0.8)][(r + c) % 3], 0.6), false)
	tag(h, Vector3(0, 0.215, 0.101), 0.0, "열쇠함", Vector2(0.14, 0.04))


## A card label facing +Z with `text` printed on it, fitted to the card.
static func tag(parent: Node3D, pos: Vector3, rot_y: float, text: String, size := Vector2(0.16, 0.05),
		card := Color(0.92, 0.9, 0.82)) -> void:
	var h := _holder(parent, pos, rot_y)
	var b := Geo.box(h, Vector3(0, 0, 0.002), Vector3(size.x, size.y, 0.003), Mats.std(card, 0.7), false)
	Geo.fit(Geo.label(b, text, Vector3(0, 0, 0.002), 0.0, 40, Color(0.08, 0.08, 0.1), 0.0015, false, "print"), size.x * 0.8, size.y * 0.6)


## A cork board facing +Z `size`, centred on `pos`, with papers pinned on it at odd angles (lines of print on them).
static func notice_board(parent: Node3D, pos: Vector3, rot_y: float, size: Vector2, seed_n: int) -> void:
	var h := _holder(parent, pos, rot_y)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	Geo.box(h, Vector3(0, 0, 0.01), Vector3(size.x + 0.05, size.y + 0.05, 0.02), Mats.std(Color(0.36, 0.26, 0.17), 0.6), false)
	Geo.box(h, Vector3(0, 0, 0.022), Vector3(size.x, size.y, 0.006), Mats.std(Color(0.6, 0.45, 0.3), 0.95), false)
	var sheets := [Mats.get_mat("paper"), Mats.std(Color(0.95, 0.9, 0.62), 0.9), Mats.std(Color(0.95, 0.8, 0.78), 0.9), Mats.std(Color(0.82, 0.88, 0.95), 0.9)]
	var ink := Mats.std(Color(0.18, 0.18, 0.2), 0.9)
	var pins := [Color(0.85, 0.15, 0.1), Color(0.15, 0.4, 0.85), Color(0.95, 0.8, 0.2)]
	var n := int(size.x * size.y * 16.0) + 3
	for i in n:
		var s := Vector2(rng.randf_range(0.12, 0.21), rng.randf_range(0.15, 0.3))
		var at := Vector3(rng.randf_range(-size.x * 0.5 + s.x * 0.5, size.x * 0.5 - s.x * 0.5),
				rng.randf_range(-size.y * 0.5 + s.y * 0.5, size.y * 0.5 - s.y * 0.5), 0.027 + i * 0.0008)
		var p := Geo.box(h, at, Vector3(s.x, s.y, 0.001), sheets[rng.randi() % sheets.size()], false)
		p.rotation.z = rng.randf_range(-0.12, 0.12)
		for k in rng.randi_range(3, 7):
			Geo.box(p, Vector3(rng.randf_range(-0.01, 0.01), s.y * 0.5 - 0.03 - k * 0.022, 0.0006), Vector3(s.x * rng.randf_range(0.5, 0.8), 0.006, 0.0005), ink, false)
		Geo.box(p, Vector3(0, s.y * 0.5 - 0.012, 0.004), Vector3(0.012, 0.012, 0.008), Mats.std(pins[rng.randi() % pins.size()], 0.4), false)


## A wall calendar facing +Z: a picture over the month's grid, hung on a nail.
static func wall_calendar(parent: Node3D, pos: Vector3, rot_y: float, month := "11") -> void:
	var h := _holder(parent, pos, rot_y)
	var sheet := Geo.box(h, Vector3(0, 0, 0.003), Vector3(0.32, 0.48, 0.004), Mats.get_mat("paper"), false)
	Geo.box(sheet, Vector3(0, 0.12, 0.0025), Vector3(0.29, 0.2, 0.001), Mats.std(Color(0.3, 0.42, 0.36), 0.8), false)
	var head := Geo.box(sheet, Vector3(-0.1, -0.015, 0.0025), Vector3(0.08, 0.05, 0.001), Mats.get_mat("paper"), false)
	Geo.fit(Geo.label(head, month, Vector3(0, 0, 0.001), 0.0, 48, Color(0.7, 0.1, 0.08), 0.0016, false, "print"), 0.07, 0.045)
	var grid := Mats.std(Color(0.45, 0.45, 0.47), 0.9)
	for r in 6:
		Geo.box(sheet, Vector3(0, -0.06 - r * 0.028, 0.0025), Vector3(0.28, 0.0015, 0.001), grid, false)
	for c in 8:
		Geo.box(sheet, Vector3(-0.14 + c * 0.04, -0.13, 0.0025), Vector3(0.0015, 0.14, 0.001), grid, false)
	Geo.cyl(h, Vector3(0, 0.26, 0.004), 0.004, 0.02, Mats.get_mat("metal")).rotation.x = PI / 2


## A rolling AV cart facing +Z: three shelves on castors, a CRT television on top showing a camera, a VCR with its
## clock blinking and tapes underneath.
static func av_cart(parent: Node3D, pos: Vector3, rot_y: float, seed_n := 2.0) -> void:
	var h := _holder(parent, pos, rot_y)
	var frame := Mats.std(Color(0.22, 0.23, 0.24), 0.45, 0.5)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Geo.cyl(h, Vector3(sx * 0.24, 0.43, sz * 0.19), 0.012, 0.76, frame)
			Geo.cyl(h, Vector3(sx * 0.24, 0.03, sz * 0.19), 0.03, 0.03, Mats.get_mat("black")).rotation.z = PI / 2
	for y in [0.12, 0.46, 0.8]:
		Geo.box(h, Vector3(0, y, 0), Vector3(0.52, 0.025, 0.42), frame, false)
	Geo.box(h, Vector3(0, 1.0, -0.04), Vector3(0.46, 0.38, 0.36), Mats.std(Color(0.12, 0.12, 0.13), 0.4), false)
	crt_glass(h, Vector3(0, 1.02, 0.143), Vector2(0.34, 0.25), "crt", seed_n)
	Geo.box(h, Vector3(0, 0.52, 0), Vector3(0.43, 0.09, 0.33), Mats.std(Color(0.16, 0.165, 0.17), 0.4, 0.5), false)
	Geo.box(h, Vector3(-0.06, 0.53, 0.166), Vector3(0.2, 0.022, 0.004), Mats.get_mat("black"), false)
	led(h, Vector3(0.12, 0.535, 0.167), Color(0.35, 1.0, 0.5), 1.0, 0.3, 0.018, 0.06)
	var tape := Mats.std(Color(0.03, 0.03, 0.035), 0.5)
	for t in 5:
		Geo.box(h, Vector3(-0.15 + t * 0.028, 0.19, 0.0), Vector3(0.025, 0.105, 0.19), tape, false)
	Geo.box(h, Vector3(0.12, 0.145, 0.0), Vector3(0.19, 0.025, 0.105), tape, false, 0.3)
	Geo.cyl(h, Vector3(0.2, 0.45, -0.2), 0.008, 0.7, Mats.get_mat("black"))
	Geo.blocker(h, Vector3(0, 0.6, 0), Vector3(0.52, 1.2, 0.42))


## A small round waste bin, tapered, with screwed-up paper in it.
static func trash_can(parent: Node3D, pos: Vector3, color := Color(0.15, 0.33, 0.7)) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.15
	cm.bottom_radius = 0.12
	cm.height = 0.36
	mi.mesh = cm
	mi.material_override = Mats.std(color, 0.5)
	parent.add_child(mi)
	mi.position = pos + Vector3(0, 0.18, 0)
	for i in 3:
		Geo.box(parent, pos + Vector3(-0.04 + i * 0.04, 0.36, 0.02 * (i - 1)), Vector3(0.07, 0.06, 0.06), Mats.get_mat("paper"), false, i * 0.8)
	Geo.blocker(parent, pos + Vector3(0, 0.18, 0), Vector3(0.3, 0.36, 0.3))


## A steel folding chair facing +Z (its seat's front edge toward +Z).
static func folding_chair(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var h := _holder(parent, pos, rot_y)
	var tube := Mats.std(Color(0.55, 0.56, 0.56), 0.35, 0.8)
	for sx in [-1.0, 1.0]:
		Geo.cyl(h, Vector3(sx * 0.2, 0.47, 0.01), 0.011, 0.96, tube).rotation.x = -0.46
		Geo.cyl(h, Vector3(sx * 0.18, 0.24, -0.02), 0.011, 0.55, tube).rotation.x = 0.62
	Geo.box(h, Vector3(0, 0.45, 0.04), Vector3(0.4, 0.02, 0.38), Mats.std(Color(0.3, 0.31, 0.31), 0.5, 0.6), false)
	Geo.box(h, Vector3(0, 0.79, -0.2), Vector3(0.38, 0.15, 0.02), Mats.std(Color(0.3, 0.31, 0.31), 0.5, 0.6), false).rotation.x = -0.46
	Geo.blocker(h, Vector3(0, 0.45, 0), Vector3(0.45, 0.9, 0.45))


## A tubular steel office chair facing +Z with a brown vinyl seat and back (the old police-office kind).
static func steel_chair(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var h := _holder(parent, pos, rot_y)
	var tube := Mats.std(Color(0.6, 0.61, 0.6), 0.3, 0.8)
	var vinyl := Mats.std(Color(0.3, 0.2, 0.14), 0.45)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Geo.cyl(h, Vector3(sx * 0.19, 0.22, sz * 0.19), 0.011, 0.44, tube)
		Geo.cyl(h, Vector3(sx * 0.18, 0.66, -0.2), 0.011, 0.44, tube)
	Geo.box(h, Vector3(0, 0.46, 0), Vector3(0.44, 0.05, 0.42), vinyl, false)
	Geo.box(h, Vector3(0, 0.75, -0.21), Vector3(0.4, 0.2, 0.035), vinyl, false)
	Geo.blocker(h, Vector3(0, 0.45, 0), Vector3(0.45, 0.9, 0.45))


## A water cooler facing +Z: white body, the two taps over a drip tray, the blue bottle upside down on top, cups.
static func water_cooler(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var h := _holder(parent, pos, rot_y)
	Geo.box(h, Vector3(0, 0.48, 0), Vector3(0.32, 0.96, 0.32), Mats.std(Color(0.85, 0.84, 0.8), 0.45), false)
	Geo.box(h, Vector3(0, 0.82, 0.13), Vector3(0.26, 0.12, 0.08), Mats.std(Color(0.7, 0.7, 0.68), 0.4), false)
	for sx in [-1.0, 1.0]:
		Geo.box(h, Vector3(sx * 0.06, 0.8, 0.18), Vector3(0.03, 0.04, 0.03), Mats.std(Color(0.8, 0.15, 0.1) if sx < 0 else Color(0.15, 0.3, 0.8), 0.4), false)
	Geo.box(h, Vector3(0, 0.62, 0.15), Vector3(0.2, 0.02, 0.06), Mats.get_mat("plastic_dark"), false)
	var bottle := Mats.std(Color(0.45, 0.65, 0.85, 0.55), 0.1, 0.1)
	bottle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	Geo.cyl(h, Vector3(0, 1.2, 0), 0.13, 0.44, bottle)
	Geo.cyl(h, Vector3(0.2, 0.75, 0), 0.035, 0.2, Mats.get_mat("plastic_white"))
	Geo.blocker(h, Vector3(0, 0.7, 0), Vector3(0.34, 1.4, 0.34))


## A standing coat rack with a jacket and a cap on its hooks.
static func coat_rack(parent: Node3D, pos: Vector3, rot_y := 0.0) -> void:
	var h := _holder(parent, pos, rot_y)
	var wood := Mats.std(Color(0.32, 0.22, 0.14), 0.55)
	for i in 4:
		var f := Geo.box(h, Vector3(0, 0.02, 0), Vector3(0.5, 0.03, 0.05), wood, false)
		f.rotation.y = i * PI / 4
	Geo.cyl(h, Vector3(0, 0.9, 0), 0.02, 1.76, wood)
	for i in 4:
		var hook := Geo.box(h, Vector3(0, 1.72, 0), Vector3(0.24, 0.02, 0.02), wood, false)
		hook.rotation = Vector3(0, i * PI / 2, 0.4)
	var jacket := Geo.box(h, Vector3(0.12, 1.3, 0.0), Vector3(0.42, 0.72, 0.16), Mats.std(Color(0.22, 0.26, 0.2), 0.95), false)
	jacket.rotation.z = 0.08
	Geo.cyl(h, Vector3(-0.12, 1.76, 0), 0.1, 0.08, Mats.std(Color(0.12, 0.14, 0.2), 0.8))
	Geo.box(h, Vector3(-0.12, 1.73, 0.1), Vector3(0.16, 0.01, 0.1), Mats.std(Color(0.12, 0.14, 0.2), 0.8), false)
	Geo.blocker(h, Vector3(0, 0.9, 0), Vector3(0.4, 1.8, 0.4))


## A late-80s desktop PC facing +Z: a beige case with its floppy drives, the CRT on top showing `screen` ("dos",
## "form" or "off"), a beige keyboard in front.
static func old_pc(parent: Node3D, pos: Vector3, rot_y: float, screen := "dos") -> void:
	var h := _holder(parent, pos, rot_y)
	var beige := Mats.std(Color(0.74, 0.7, 0.6), 0.6)
	Geo.box(h, Vector3(0, 0.07, -0.05), Vector3(0.44, 0.14, 0.4), beige, false)
	for i in 2:
		Geo.box(h, Vector3(0.1, 0.105 - i * 0.045, 0.151), Vector3(0.14, 0.012, 0.004), Mats.get_mat("plastic_dark"), false)
	led(h, Vector3(-0.17, 0.05, 0.152), Color(0.3, 1.0, 0.45))
	var scr := crt(h, Vector3(0, 0.14, -0.06), 0.0)
	match screen:
		"dos":
			scr.material_override = Mats.emissive(Color(0.02, 0.06, 0.03), 0.7)
			Geo.fit(Geo.label(scr, "C:\\>DIR\n BACKUP   DAT\n LOG8711  TXT\nC:\\>_", Vector3(0, 0, 0.003), 0.0, 24,
					Color(0.45, 1.0, 0.5), 0.0012, true), 0.26, 0.19)
		"form":
			scr.material_override = Mats.emissive(Color(0.05, 0.1, 0.42), 0.7)
			Geo.fit(Geo.label(scr, "출입 기록 조회\n────────────\n카드 번호 :\n조회 결과 : 없음", Vector3(0, 0, 0.003), 0.0, 24,
					Color(0.92, 0.94, 1.0), 0.0012, true), 0.26, 0.19)
	var kb := Geo.box(h, Vector3(0, 0.018, 0.27), Vector3(0.44, 0.03, 0.16), beige, false)
	kb.rotation.x = 0.06
	var keys := Mats.std(Color(0.55, 0.52, 0.45), 0.6)
	for r in 4:
		Geo.box(kb, Vector3(-0.02, 0.016, -0.05 + r * 0.032), Vector3(0.34, 0.006, 0.024), keys, false)
	Geo.box(h, Vector3(0.3, 0.012, 0.25), Vector3(0.06, 0.024, 0.1), beige, false)


## A desk telephone facing +Z: the black rotary kind or the beige push-button kind, its handset on the cradle, the
## coiled cord.
static func phone(parent: Node3D, pos: Vector3, rot_y: float, rotary := true) -> void:
	var h := _holder(parent, pos, rot_y)
	var m: Material = Mats.std(Color(0.035, 0.035, 0.04), 0.25, 0.1) if rotary else Mats.std(Color(0.74, 0.68, 0.54), 0.45)
	Geo.box(h, Vector3(0, 0.04, -0.01), Vector3(0.21, 0.08, 0.21), m, false)
	var slope := Geo.box(h, Vector3(0, 0.08, 0.05), Vector3(0.19, 0.02, 0.12), m, false)
	slope.rotation.x = 0.35
	if rotary:
		Geo.cyl(slope, Vector3(0, 0.012, 0), 0.055, 0.008, Mats.std(Color(0.85, 0.84, 0.8), 0.3))
		Geo.cyl(slope, Vector3(0, 0.017, 0), 0.022, 0.006, m)
	else:
		var key := Mats.std(Color(0.88, 0.85, 0.76), 0.5)
		for r in 4:
			for c in 3:
				Geo.box(slope, Vector3(-0.03 + c * 0.03, 0.012, -0.035 + r * 0.023), Vector3(0.022, 0.008, 0.016), key, false)
	Geo.box(h, Vector3(0, 0.112, -0.05), Vector3(0.22, 0.03, 0.05), m, false)
	for sx in [-1.0, 1.0]:
		Geo.box(h, Vector3(sx * 0.095, 0.1, -0.05), Vector3(0.06, 0.05, 0.07), m, false)
	for i in 5:
		Geo.cyl(h, Vector3(-0.13, 0.075 - i * 0.012, -0.03 + i * 0.022), 0.012, 0.008, m).rotation.z = PI / 2


## A row of `n` ring binders standing from `pos` along +X (spines toward +Z, labelled), held by bookends.
static func binders(parent: Node3D, pos: Vector3, rot_y: float, n: int, seed_n: int) -> void:
	var h := _holder(parent, pos, rot_y)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var cols := [Mats.std(Color(0.12, 0.2, 0.42), 0.7), Mats.std(Color(0.08, 0.08, 0.09), 0.7), Mats.std(Color(0.45, 0.12, 0.1), 0.7),
			Mats.std(Color(0.5, 0.5, 0.48), 0.7), Mats.std(Color(0.2, 0.32, 0.2), 0.7)]
	var metal := Mats.get_mat("metal_dark")
	Geo.box(h, Vector3(-0.004, 0.09, 0), Vector3(0.004, 0.18, 0.14), metal, false)
	var x := 0.0
	for i in n:
		var w := rng.randf_range(0.045, 0.075)
		var b := Geo.box(h, Vector3(x + w * 0.5, 0.155, 0), Vector3(w - 0.003, 0.31, 0.26), cols[rng.randi() % cols.size()], false)
		Geo.box(b, Vector3(0, 0.07, 0.1305), Vector3(w * 0.6, 0.08, 0.002), Mats.get_mat("paper"), false)
		x += w
	Geo.box(h, Vector3(x + 0.004, 0.09, 0), Vector3(0.004, 0.18, 0.14), metal, false)


## A stack of `n` letter trays (facing +Z), papers in each.
static func trays(parent: Node3D, pos: Vector3, rot_y: float, n := 2) -> void:
	var h := _holder(parent, pos, rot_y)
	var m := Mats.std(Color(0.12, 0.13, 0.14), 0.5, 0.4)
	for i in n:
		var y := i * 0.075
		Geo.box(h, Vector3(0, y + 0.005, 0), Vector3(0.26, 0.01, 0.34), m, false)
		for sx in [-1.0, 1.0]:
			Geo.box(h, Vector3(sx * 0.125, y + 0.03, 0), Vector3(0.01, 0.05, 0.34), m, false)
		Geo.box(h, Vector3(0, y + 0.03, -0.165), Vector3(0.26, 0.05, 0.01), m, false)
		Geo.box(h, Vector3(0, y + 0.012 + 0.008 * (i % 2), 0.01), Vector3(0.21, 0.012 + 0.012 * (i % 2), 0.29), Mats.get_mat("paper"), false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Geo.cyl(h, Vector3(sx * 0.12, n * 0.0375, sz * 0.16), 0.004, n * 0.075, m)


## A bundle of old documents tied crosswise with string.
static func bundle(parent: Node3D, pos: Vector3, rot_y: float, size := Vector3(0.24, 0.08, 0.32)) -> void:
	var h := _holder(parent, pos, rot_y)
	Geo.box(h, Vector3(0, size.y * 0.5, 0), size, Mats.std(Color(0.72, 0.66, 0.5), 0.9), false)
	Geo.box(h, Vector3(0.01, size.y + 0.002, 0), Vector3(size.x - 0.01, 0.004, size.z - 0.012), Mats.std(Color(0.8, 0.77, 0.66), 0.9), false)
	var s := Mats.std(Color(0.85, 0.82, 0.72), 0.9)
	Geo.box(h, Vector3(0, size.y * 0.5, 0), Vector3(0.008, size.y + 0.01, size.z + 0.006), s, false)
	Geo.box(h, Vector3(0, size.y * 0.5, 0), Vector3(size.x + 0.006, size.y + 0.01, 0.008), s, false)


## An old manual typewriter facing +Z, a sheet in it.
static func typewriter(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var h := _holder(parent, pos, rot_y)
	var m := Mats.std(Color(0.28, 0.32, 0.3), 0.45, 0.3)
	Geo.box(h, Vector3(0, 0.05, -0.02), Vector3(0.44, 0.1, 0.32), m, false)
	var kb := Geo.box(h, Vector3(0, 0.07, 0.15), Vector3(0.4, 0.03, 0.14), m, false)
	kb.rotation.x = 0.3
	var keys := Mats.std(Color(0.08, 0.08, 0.08), 0.4)
	for r in 4:
		Geo.box(kb, Vector3(0, 0.018, -0.05 + r * 0.033), Vector3(0.34, 0.01, 0.018), keys, false)
	Geo.cyl(h, Vector3(0, 0.13, -0.09), 0.03, 0.42, Mats.get_mat("black")).rotation.z = PI / 2
	for sx in [-1.0, 1.0]:
		Geo.cyl(h, Vector3(sx * 0.23, 0.13, -0.09), 0.025, 0.03, m).rotation.z = PI / 2
	Geo.box(h, Vector3(-0.25, 0.16, -0.06), Vector3(0.08, 0.012, 0.012), Mats.get_mat("metal"), false)
	var sheet := Geo.box(h, Vector3(0, 0.25, -0.11), Vector3(0.21, 0.22, 0.002), Mats.get_mat("paper"), false)
	sheet.rotation.x = -0.25


## A pen pot with pens, a ruler and scissors in it.
static func pen_cup(parent: Node3D, pos: Vector3, rng: RandomNumberGenerator) -> void:
	Geo.cyl(parent, pos + Vector3(0, 0.05, 0), 0.035, 0.1, Mats.std(Color(0.2, 0.22, 0.3), 0.5))
	var inks := [Color(0.1, 0.2, 0.7), Color(0.8, 0.1, 0.1), Color(0.1, 0.1, 0.1), Color(0.9, 0.85, 0.2)]
	for i in 4:
		var p := Geo.cyl(parent, pos + Vector3(rng.randf_range(-0.015, 0.015), 0.12, rng.randf_range(-0.015, 0.015)), 0.004, 0.15,
				Mats.std(inks[i % inks.size()], 0.4))
		p.rotation = Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
	Geo.box(parent, pos + Vector3(0.01, 0.13, 0), Vector3(0.025, 0.2, 0.003), Mats.std(Color(0.85, 0.85, 0.8), 0.4), false).rotation.z = 0.15


static func mug(parent: Node3D, pos: Vector3, color := Color(0.85, 0.84, 0.8)) -> void:
	var m := Mats.std(color, 0.4)
	Geo.cyl(parent, pos + Vector3(0, 0.05, 0), 0.04, 0.1, m)
	Geo.box(parent, pos + Vector3(0.045, 0.05, 0), Vector3(0.015, 0.06, 0.012), m, false)
	Geo.cyl(parent, pos + Vector3(0, 0.092, 0), 0.034, 0.004, Mats.std(Color(0.12, 0.07, 0.03), 0.2))


static func ashtray(parent: Node3D, pos: Vector3) -> void:
	Geo.cyl(parent, pos + Vector3(0, 0.015, 0), 0.07, 0.03, Mats.std(Color(0.3, 0.32, 0.33), 0.3, 0.7))
	Geo.cyl(parent, pos + Vector3(0, 0.028, 0), 0.055, 0.006, Mats.std(Color(0.2, 0.2, 0.2), 0.95))
	for i in 3:
		Geo.cyl(parent, pos + Vector3(-0.02 + i * 0.02, 0.035, 0.01 * i), 0.005, 0.035, Mats.std(Color(0.85, 0.75, 0.55), 0.8)).rotation = Vector3(PI / 2, i * 1.1, 0)


## A few books lying in a pile.
static func book_stack(parent: Node3D, pos: Vector3, rot_y: float, rng: RandomNumberGenerator) -> void:
	var y := 0.0
	for i in rng.randi_range(2, 5):
		var t := rng.randf_range(0.025, 0.05)
		Geo.box(parent, pos + Vector3(0, y + t * 0.5, 0), Vector3(rng.randf_range(0.17, 0.24), t, rng.randf_range(0.22, 0.3)),
				Mats.std(Color(rng.randf_range(0.1, 0.5), rng.randf_range(0.1, 0.3), rng.randf_range(0.1, 0.3)), 0.8), false,
				rot_y + rng.randf_range(-0.2, 0.2))
		y += t


## A radio base station facing +Z: a box with a handset microphone, an antenna, a lamp.
static func radio_base(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var h := _holder(parent, pos, rot_y)
	Geo.box(h, Vector3(0, 0.05, 0), Vector3(0.3, 0.1, 0.24), Mats.get_mat("plastic_dark"), false)
	Geo.box(h, Vector3(-0.05, 0.06, 0.121), Vector3(0.12, 0.04, 0.003), Mats.emissive(Color(0.9, 0.55, 0.15), 0.6), false)
	for i in 3:
		Geo.cyl(h, Vector3(0.05 + i * 0.035, 0.05, 0.125), 0.011, 0.012, Mats.get_mat("metal")).rotation.x = PI / 2
	Geo.cyl(h, Vector3(0.12, 0.3, -0.08), 0.004, 0.42, Mats.get_mat("metal"))
	Geo.box(h, Vector3(-0.17, 0.05, 0.05), Vector3(0.05, 0.09, 0.03), Mats.get_mat("plastic_dark"), false)
	led(h, Vector3(0.12, 0.085, 0.121), Color(0.3, 1.0, 0.45), 0.7)


## Odds and ends on a desk at `pos` (floor, its middle) turned `rot_y`, `size` its top (width along local X, depth;
## the sitter on +Z): `items` [kind, x, z (-1..1 of the half sizes), turn, lift] — "phone" / "phone_beige", "pc" /
## "pc_form" / "pc_off", "pile", "bundle", "binders", "trays", "pens", "mug", "ashtray", "lamp" / "lamp_off",
## "typewriter", "books", "fan", "radio", "blotter", "ledger".
static func dress(parent: Node3D, pos: Vector3, rot_y: float, size: Vector2, items: Array, seed_n := 1) -> void:
	var h := _holder(parent, pos, rot_y)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	for it: Array in items:
		var kind: String = it[0]
		var p := Vector3(float(it[1]) * size.x * 0.5, DESK_H + (float(it[4]) if it.size() > 4 else 0.0), float(it[2]) * size.y * 0.5)
		var r: float = float(it[3]) if it.size() > 3 else 0.0
		match kind:
			"phone":
				phone(h, p, r, true)
			"phone_beige":
				phone(h, p, r, false)
			"pc":
				old_pc(h, p, r, "dos")
			"pc_form":
				old_pc(h, p, r, "form")
			"pc_off":
				old_pc(h, p, r, "off")
			"pile":
				paper_stack(h, p, rng.randi_range(6, 14), r)
			"bundle":
				bundle(h, p, r)
			"binders":
				binders(h, p, r, rng.randi_range(4, 8), rng.randi())
			"trays":
				trays(h, p, r, rng.randi_range(2, 3))
			"pens":
				pen_cup(h, p, rng)
			"mug":
				mug(h, p)
			"ashtray":
				ashtray(h, p)
			"lamp":
				desk_lamp(h, p, r)
			"lamp_off":
				desk_lamp(h, p, r, false)
			"typewriter":
				typewriter(h, p, r)
			"books":
				book_stack(h, p, r, rng)
			"fan":
				fan(h, p, r, false)
			"radio":
				radio_base(h, p, r)
			"blotter":
				Geo.box(h, p + Vector3(0, 0.003, 0), Vector3(0.62, 0.006, 0.42), Mats.std(Color(0.2, 0.33, 0.27), 0.9), false, r)
			"ledger":
				var book := Geo.box(h, p + Vector3(0, 0.012, 0), Vector3(0.42, 0.024, 0.3), Mats.std(Color(0.25, 0.12, 0.1), 0.7), false, r)
				Geo.box(book, Vector3(0, 0.0125, 0), Vector3(0.4, 0.002, 0.28), Mats.get_mat("paper"), false)
				for k in 8:
					Geo.box(book, Vector3(-0.1 + 0.2 * (k % 2), 0.0137, -0.1 + floorf(k * 0.5) * 0.06), Vector3(0.15, 0.0005, 0.004), Mats.std(Color(0.2, 0.2, 0.3), 0.9), false)


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
