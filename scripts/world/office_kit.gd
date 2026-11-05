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
	return Mats.weathered_steel(Color(0.5, 0.52, 0.52))      # worn grey painted steel (the user's locker photo)


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
## `live`, its drawers do not open. `look` "steel": the police-station concept art's desks — a grey linoleum top on a
## dark steel body, light grey drawers.
static func desk(parent: Node3D, pos: Vector3, rot_y: float, size: Vector3, side := 1.0, live := true, look := "") -> Array[Drawer]:
	var h := _holder(parent, pos, rot_y)
	var top := Mats.get_mat("wood")
	var body: Material = Mats.weathered_steel(Color(0.5, 0.51, 0.5))
	if look == "steel":
		top = _cached("lino_top", func(): return Mats.std(Color(0.4, 0.41, 0.38), 0.45))
		body = Mats.weathered_steel(Color(0.42, 0.44, 0.44))
	Geo.box(h, Vector3(0, size.y - 0.0175, 0), Vector3(size.x, 0.035, size.z), top, false)
	Geo.box(h, Vector3(0, size.y - 0.3, -size.z * 0.5 + 0.05), Vector3(size.x - 0.06, 0.45, 0.02), body, false)
	Geo.box(h, Vector3(-side * (size.x * 0.5 - 0.02), (size.y - 0.035) * 0.5, 0), Vector3(0.035, size.y - 0.035, size.z - 0.04), body, false)
	var pw := 0.42
	var cx := side * (size.x * 0.5 - pw * 0.5 - 0.01)
	var face := size.z * 0.5 - 0.03
	var drawers := _pedestal(h, cx, face, pw, size.y - 0.035, size.z - 0.08, [0.15, 0.2, 0.28], body, steel(), live)
	Geo.blocker(h, Vector3(0, size.y * 0.5, -0.06), Vector3(size.x, size.y, size.z - 0.12))
	return drawers


static var _mats := {}

static func _cached(key: String, make: Callable) -> Material:
	if not _mats.has(key):
		_mats[key] = make.call()
	return _mats[key]


## `xforms` of one mesh in one draw (small repeated parts: blossom, papers on glass).
static func _multi(parent: Node3D, mesh: Mesh, mat: Material, xforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	parent.add_child(mi)
	return mi


## Dark green-grey painted steel: the window frames and the counter's glazing bars (the police-station concept art).
static func frame_steel() -> Material:
	return _cached("frame_steel", func(): return Mats.std(Color(0.15, 0.19, 0.17), 0.45, 0.5))


## A steel-framed window facing +Z, centred on `pos`, `size` its opening: a heavy frame, `cols` x `rows` panes,
## a sill. `see_through`: clear glass (an inner room's window); else dirty frosted wired glass on a dark backing
## (a window in an outer wall: nothing shows through). Papers, notices and photos taped on the inside of some panes.
## `max_papers` caps how many sheets are taped on it (-1: as the panes fall). Returns the pane's backing when `view`
## (clear glass on a surface a step behind it, for a PortalView's material to show
## what lies outside), else null.
static func steel_window(parent: Node3D, pos: Vector3, rot_y: float, size: Vector2, cols := 3, rows := 3,
		seed_n := 1, see_through := false, view := false, max_papers := -1) -> MeshInstance3D:
	var h := _holder(parent, pos, rot_y)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var fr := frame_steel()
	var t := 0.06
	var backing: MeshInstance3D = null
	if view:
		see_through = true
		backing = Geo.box(h, Vector3(0, 0, -0.004), Vector3(size.x, size.y, 0.002), Mats.get_mat("black"), false)
	if not see_through:
		Geo.box(h, Vector3(0, 0, 0.005), Vector3(size.x, size.y, 0.01), Mats.std(Color(0.035, 0.04, 0.04), 0.6), false)
		var frost := _cached("frost", func():
			var m := Mats.std(Color(0.5, 0.56, 0.52, 0.62), 0.35, 0.0)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.emission_enabled = true                      # a little light from beyond, as in the concept art
			m.emission = Color(0.05, 0.075, 0.06)
			return m)
		Geo.box(h, Vector3(0, 0, 0.03), Vector3(size.x, size.y, 0.006), frost, false)
	else:
		Geo.box(h, Vector3(0, 0, 0.0), Vector3(size.x, size.y, 0.008), Mats.get_mat("glass"), false)
	# the frame: outer, mullions, transoms
	for sy in [-1.0, 1.0]:
		Geo.box(h, Vector3(0, sy * (size.y * 0.5 + t * 0.5), 0.03), Vector3(size.x + t * 2.0, t, 0.08), fr, false)
	for sx in [-1.0, 1.0]:
		Geo.box(h, Vector3(sx * (size.x * 0.5 + t * 0.5), 0, 0.03), Vector3(t, size.y, 0.08), fr, false)
	for c in range(1, cols):
		Geo.box(h, Vector3(-size.x * 0.5 + size.x * c / cols, 0, 0.035), Vector3(0.035, size.y, 0.05), fr, false)
	for r in range(1, rows):
		Geo.box(h, Vector3(0, -size.y * 0.5 + size.y * r / rows, 0.035), Vector3(size.x, 0.035, 0.05), fr, false)
	Geo.box(h, Vector3(0, -size.y * 0.5 - t - 0.02, 0.07), Vector3(size.x + 0.2, 0.04, 0.16), fr, false)
	# what is taped on the panes
	var sheets := [Mats.get_mat("paper"), _cached("paper_y", func(): return Mats.std(Color(0.92, 0.88, 0.62), 0.9)),
			_cached("paper_g", func(): return Mats.std(Color(0.78, 0.85, 0.74), 0.9))]
	var ink := _cached("ink", func(): return Mats.std(Color(0.16, 0.16, 0.18), 0.9))
	var pw := size.x / cols
	var ph := size.y / rows
	var z := 0.045 if see_through else 0.036
	var taped := 0
	for c in cols:
		for r in rows:
			if rng.randf() > (0.15 if view else 0.55) or (max_papers >= 0 and taped >= max_papers):   # a window onto the outside keeps most clear
				continue
			for k in rng.randi_range(1, 3):
				if max_papers >= 0 and taped >= max_papers:
					break
				taped += 1
				var s := Vector2(rng.randf_range(0.14, 0.22), rng.randf_range(0.18, 0.28))
				var at := Vector3(-size.x * 0.5 + pw * (c + 0.5) + rng.randf_range(-pw * 0.3, pw * 0.3),
						-size.y * 0.5 + ph * (r + 0.5) + rng.randf_range(-ph * 0.25, ph * 0.25), z + k * 0.001)
				var p := Geo.box(h, at, Vector3(s.x, s.y, 0.001), sheets[rng.randi() % sheets.size()], false)
				p.rotation.z = rng.randf_range(-0.15, 0.15)
				if rng.randf() < 0.4:
					Geo.box(p, Vector3(0, s.y * 0.15, 0.0006), Vector3(s.x * 0.6, s.y * 0.4, 0.0005), ink, false)
				for l in rng.randi_range(2, 5):
					Geo.box(p, Vector3(0, -s.y * 0.15 - l * 0.02, 0.0006), Vector3(s.x * 0.7, 0.005, 0.0005), ink, false)
	return backing


## A reception counter `length` long facing +Z (the concept art's booth): a panelled wooden front, a worn top, and
## over it glazing in steel frames with notices and photos taped on it, the team's badge on its front.
static func counter_screen(parent: Node3D, pos: Vector3, rot_y: float, length: float, seed_n := 1, max_papers := -1) -> void:
	var h := _holder(parent, pos, rot_y)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var wood := _cached("counter_wood", func(): return Mats.std(Color(0.3, 0.28, 0.24), 0.55))
	var trim := _cached("counter_trim", func(): return Mats.std(Color(0.22, 0.21, 0.18), 0.5))
	var ht := 1.05
	var d := 0.5
	Geo.box(h, Vector3(0, ht * 0.5, 0), Vector3(length, ht, d), wood, false)
	Geo.box(h, Vector3(0, ht + 0.02, 0.03), Vector3(length + 0.06, 0.04, d + 0.1), trim, false)
	Geo.box(h, Vector3(0, 0.05, d * 0.5 + 0.005), Vector3(length, 0.1, 0.012), trim, false)
	var n := maxi(1, roundi(length / 0.9))
	for i in n:
		var cx := -length * 0.5 + length * (i + 0.5) / n
		Geo.box(h, Vector3(cx, 0.58, d * 0.5 + 0.006), Vector3(length / n - 0.14, 0.72, 0.012), trim, false)
		Geo.box(h, Vector3(cx, 0.58, d * 0.5 + 0.013), Vector3(length / n - 0.26, 0.6, 0.006), wood, false)
	var badge := Geo.cyl(h, Vector3(0, 0.62, d * 0.5 + 0.02), 0.11, 0.012, Mats.std(Color(0.7, 0.55, 0.22), 0.3, 0.85))
	badge.rotation.x = PI / 2
	Geo.cyl(h, Vector3(0, 0.62, d * 0.5 + 0.027), 0.075, 0.004, Mats.std(Color(0.12, 0.16, 0.3), 0.5)).rotation.x = PI / 2
	# the glazing on top
	var gh := 0.8
	var gy := ht + 0.04 + gh * 0.5
	Geo.box(h, Vector3(0, gy, 0), Vector3(length, gh, 0.008), Mats.get_mat("glass"), false)
	var fr := frame_steel()
	Geo.box(h, Vector3(0, gy + gh * 0.5, 0), Vector3(length + 0.04, 0.04, 0.05), fr, false)
	var m := maxi(2, roundi(length / 0.6))
	for i in m + 1:
		Geo.box(h, Vector3(-length * 0.5 + length * i / m, gy, 0), Vector3(0.035, gh, 0.045), fr, false)
	var sheets := [Mats.get_mat("paper"), _cached("paper_y", func(): return Mats.std(Color(0.92, 0.88, 0.62), 0.9))]
	var ink := _cached("ink", func(): return Mats.std(Color(0.16, 0.16, 0.18), 0.9))
	var taped := 0
	for i in m:
		if rng.randf() < 0.3:
			continue
		for k in rng.randi_range(1, 3):
			if max_papers >= 0 and taped >= max_papers:
				break
			taped += 1
			var s := Vector2(rng.randf_range(0.13, 0.2), rng.randf_range(0.16, 0.24))
			var at := Vector3(-length * 0.5 + length * (i + 0.5) / m + rng.randf_range(-0.12, 0.12), gy + rng.randf_range(-0.2, 0.2),
					0.006 + k * 0.001)
			var p := Geo.box(h, at, Vector3(s.x, s.y, 0.001), sheets[rng.randi() % sheets.size()], false)
			p.rotation.z = rng.randf_range(-0.12, 0.12)
			Geo.box(p, Vector3(0, s.y * 0.12, 0.0006), Vector3(s.x * 0.55, s.y * 0.45, 0.0005), ink, false)
	Geo.blocker(h, Vector3(0, (ht + gh + 0.04) * 0.5, 0), Vector3(length, ht + gh + 0.04, d))


## An old CRT television on a wall bracket facing +Z (the concept art's, over the corner), showing a camera: the
## wall plate, the arm out from it, a tray, the set.
static func tv_bracket(parent: Node3D, pos: Vector3, rot_y: float, seed_n := 1.0) -> void:
	var h := _holder(parent, pos, rot_y)
	var steel_d := Mats.get_mat("metal_dark")
	Geo.box(h, Vector3(0, 0.1, 0.01), Vector3(0.22, 0.32, 0.02), steel_d, false)
	Geo.box(h, Vector3(0, 0.0, 0.25), Vector3(0.05, 0.05, 0.48), steel_d, false)
	Geo.box(h, Vector3(0, -0.03, 0.5), Vector3(0.5, 0.02, 0.44), steel_d, false)
	var case_m := _cached("tv_case", func(): return Mats.std(Color(0.12, 0.12, 0.13), 0.4))
	Geo.box(h, Vector3(0, 0.2, 0.47), Vector3(0.48, 0.42, 0.4), case_m, false)
	Geo.box(h, Vector3(0, 0.2, 0.68), Vector3(0.5, 0.44, 0.03), case_m, false)
	crt_glass(h, Vector3(-0.03, 0.22, 0.698), Vector2(0.36, 0.28), "crt", seed_n)
	led(h, Vector3(0.19, 0.04, 0.697), Color(1.0, 0.25, 0.15))
	for k in 2:
		Geo.cyl(h, Vector3(0.19, 0.12 + k * 0.06, 0.698), 0.012, 0.01, Mats.get_mat("metal")).rotation.x = PI / 2


## A notice taped to a wall facing +Z: a photo and lines of print, a heading in red ("실종" / "수배" …) when given.
static func poster(parent: Node3D, pos: Vector3, rot_y: float, head := "", seed_n := 1, size := Vector2(0.3, 0.42)) -> void:
	var h := _holder(parent, pos, rot_y)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var sheet := Geo.box(h, Vector3(0, 0, 0.001), Vector3(size.x, size.y, 0.002), Mats.get_mat("paper"), false)
	sheet.rotation.z = rng.randf_range(-0.05, 0.05)
	var ink := _cached("ink", func(): return Mats.std(Color(0.16, 0.16, 0.18), 0.9))
	Geo.box(sheet, Vector3(0, size.y * 0.06, 0.0012), Vector3(size.x * 0.55, size.y * 0.38, 0.0005),
			_cached("photo", func(): return Mats.std(Color(0.32, 0.3, 0.28), 0.6)), false)
	for l in 4:
		Geo.box(sheet, Vector3(0, -size.y * 0.22 - l * 0.035, 0.0012), Vector3(size.x * 0.7, 0.008, 0.0005), ink, false)
	if head != "":
		var b := Geo.box(sheet, Vector3(0, size.y * 0.38, 0.0012), Vector3(size.x * 0.8, size.y * 0.12, 0.0005),
				_cached("poster_head", func(): return Mats.std(Color(0.97, 0.96, 0.92), 0.9)), false)
		Geo.fit(Geo.label(b, head, Vector3(0, 0, 0.0008), 0.0, 48, Color(0.7, 0.08, 0.06), 0.0016, false, "print"),
				size.x * 0.62, size.y * 0.08)


## A potted plant (the concept art's, by the water cooler): a clay pot, a fan of leaves.
static func potted_plant(parent: Node3D, pos: Vector3, s := 1.0, seed_n := 1) -> void:
	var h := _holder(parent, pos, float(seed_n) * 1.3)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	Geo.cyl(h, Vector3(0, 0.15 * s, 0), 0.15 * s, 0.3 * s, _cached("pot", func(): return Mats.std(Color(0.45, 0.28, 0.18), 0.7)))
	Geo.cyl(h, Vector3(0, 0.3 * s, 0), 0.135 * s, 0.01, Mats.std(Color(0.12, 0.09, 0.06), 0.95))
	var leaf := BoxMesh.new()
	leaf.size = Vector3(0.09, 0.006, 0.42)
	var xf: Array = []
	for i in 14:
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(0.5, 1.2))
		b = b.scaled(Vector3.ONE * s * rng.randf_range(0.7, 1.15))
		xf.append(Transform3D(b, Vector3(0, 0.32 * s, 0) + b * Vector3(0, 0, -0.18)))
	_multi(h, leaf, _cached("leaf", func(): return Mats.std(Color(0.18, 0.3, 0.14), 0.6)), xf)


## A book trolley facing +Z: two shelves on castors, books lying and standing on them.
static func trolley(parent: Node3D, pos: Vector3, rot_y: float, seed_n := 3) -> void:
	var h := _holder(parent, pos, rot_y)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var frame := Mats.std(Color(0.5, 0.51, 0.5), 0.4, 0.6)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Geo.cyl(h, Vector3(sx * 0.36, 0.48, sz * 0.2), 0.012, 0.84, frame)
			Geo.cyl(h, Vector3(sx * 0.36, 0.03, sz * 0.2), 0.03, 0.03, Mats.get_mat("black")).rotation.z = PI / 2
	for y in [0.2, 0.86]:
		Geo.box(h, Vector3(0, y, 0), Vector3(0.78, 0.02, 0.46), frame, false)
		for k in 3:
			book_stack(h, Vector3(-0.24 + k * 0.24, y + 0.01, rng.randf_range(-0.05, 0.05)), rng.randf_range(-0.3, 0.3), rng)
	Geo.blocker(h, Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 0.5))


## Four-drawer vertical filing cabinet; `tint` paints it (the concept art's beige and olive ones); not `live`, its
## drawers are only fronts.
static func filing_cabinet(parent: Node3D, pos: Vector3, rot_y: float, n := 4, tint := Color.TRANSPARENT, live := true) -> Array[Drawer]:
	var h := _holder(parent, pos, rot_y)
	var size := Vector3(0.47, 1.32, 0.62)
	var body: Material = steel() if tint.a == 0.0 else Mats.weathered_steel(tint)
	Geo.box(h, Vector3(0, size.y - 0.01, 0), Vector3(size.x, 0.02, size.z), body, false)
	var hs: Array = []
	for i in n:
		hs.append((size.y - 0.1) / n - 0.008)
	var drawers := _pedestal(h, 0.0, size.z * 0.5, size.x, size.y - 0.02, size.z, hs, body, body, live)
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


## An old CRT monitor facing +Z (user, with a photo of an old beige PC: "컴퓨터 텍스처도 참고해줘"): yellowed, grimy
## beige plastic (Mats "plastic_aged") — a swivel base, a deep tube housing stepping in behind the bezel with vent slats
## down its sides, the bezel with a recessed screen and a power button under it. Returns its screen so the caller can
## light it.
static func crt(parent: Node3D, pos: Vector3, rot_y: float) -> MeshInstance3D:
	var h := _holder(parent, pos, rot_y)
	var case_m: Material = Mats.get_mat("plastic_aged")
	var dark: Material = Mats.get_mat("plastic_dark")
	Geo.cyl(h, Vector3(0, 0.008, -0.05), 0.13, 0.016, case_m, false, 24)                 # the swivel
	Geo.box(h, Vector3(0, 0.035, -0.05), Vector3(0.24, 0.04, 0.22), case_m, false)
	Geo.box(h, Vector3(0, 0.235, -0.07), Vector3(0.38, 0.32, 0.16), case_m, false)       # the housing, stepping in
	Geo.box(h, Vector3(0, 0.23, -0.2), Vector3(0.3, 0.24, 0.14), case_m, false)
	for sx in [-1.0, 1.0]:
		for k in 7:
			Geo.box(h, Vector3(sx * 0.1905, 0.17 + k * 0.022, -0.1), Vector3(0.002, 0.008, 0.11), dark, false)
	Geo.box(h, Vector3(0, 0.25, 0.04), Vector3(0.4, 0.34, 0.04), case_m, false)          # the bezel
	Geo.box(h, Vector3(0, 0.26, 0.058), Vector3(0.33, 0.255, 0.006), dark, false)         # the screen's recess
	Geo.cyl(h, Vector3(0.155, 0.1, 0.061), 0.009, 0.006, case_m, false, 10).rotation.x = PI / 2
	led(h, Vector3(0.13, 0.1, 0.061), Color(0.3, 1.0, 0.45))
	return Geo.box(h, Vector3(0, 0.26, 0.062), Vector3(0.31, 0.24, 0.004), Mats.get_mat("screen_off"), false)


## An old industrial twin-tube fluorescent fitting (user, with photos of one: "조명 이런 형태로 바꿔줘", "질감도
## 현실적으로"): a cast ballast housing with a knob on top, hung on two chains with its cable beside them; two bare tubes
## between ribbed bakelite lampholders on cast end brackets; round them a V trough of aged brushed steel — a spine over
## the tubes, two wings angled out and down past them — with slots along the wings' tops that the tubes shine through.
## `pos` = the tubes' level, the fitting lengthwise along X (`along_x`) or Z; the chains go up to `ceiling_y`.
## `tube_mat` lights the tubes and the slots (the zone's panel material, or a dead grey). Returns the two tubes.
static func tube_fitting(parent: Node3D, pos: Vector3, along_x: bool, ceiling_y: float, tube_mat: Material,
		slot_mat: Material) -> Array[MeshInstance3D]:
	var h := _holder(parent, pos, 0.0 if along_x else PI / 2)
	var cast: Material = Mats.get_mat("fixture_cast")
	var refl: Material = Mats.get_mat("fixture_reflector")
	var bakelite: Material = _cached("bakelite", func(): return Mats.std(Color(0.03, 0.028, 0.026), 0.38))
	var chain_m: Material = _cached("chain", func(): return Mats.std(Color(0.16, 0.15, 0.14), 0.5, 0.75))
	var cable_m: Material = _cached("cable", func(): return Mats.std(Color(0.05, 0.05, 0.05), 0.55))
	var l := 1.3
	var tubes: Array[MeshInstance3D] = []
	# the trough
	Geo.box(h, Vector3(0, 0.075, 0), Vector3(l, 0.012, 0.16), refl, false)
	for s in [-1.0, 1.0]:
		var wing := Node3D.new()
		h.add_child(wing)
		wing.position = Vector3(0, 0.075, s * 0.08)
		wing.rotation.x = s * deg_to_rad(59.0)
		Geo.box(wing, Vector3(0, 0, s * 0.0875), Vector3(l, 0.006, 0.175), refl, false)
		Geo.box(wing, Vector3(0, -0.002, s * 0.176), Vector3(l, 0.012, 0.008), refl, false)        # its rolled edge
		for k in 7:
			Geo.box(wing, Vector3(-0.48 + k * 0.16, 0.0035, s * 0.035), Vector3(0.075, 0.002, 0.022), slot_mat, false)
	# the tubes and their lampholders, the cast brackets at the ends
	for s in [-1.0, 1.0]:
		var tube := Geo.cyl(h, Vector3(0, 0, s * 0.045), 0.016, l - 0.2, tube_mat, false, 12)
		tube.rotation.z = PI / 2
		tubes.append(tube)
		for e in [-1.0, 1.0]:
			var lh := Geo.cyl(h, Vector3(e * (l * 0.5 - 0.075), 0, s * 0.045), 0.026, 0.055, bakelite, false, 12)
			lh.rotation.z = PI / 2
			for rib in 3:
				var rr := Geo.cyl(h, Vector3(e * (l * 0.5 - 0.055 - rib * 0.017), 0, s * 0.045), 0.03, 0.006, bakelite, false, 12)
				rr.rotation.z = PI / 2
	for e in [-1.0, 1.0]:
		Geo.box(h, Vector3(e * (l * 0.5 - 0.03), 0.025, 0), Vector3(0.03, 0.11, 0.15), cast, false)
	# the ballast housing on the spine, rounded at its ends, a knob on top
	var hy := 0.075 + 0.006 + 0.035
	Geo.box(h, Vector3(0, hy, 0), Vector3(0.4, 0.07, 0.12), cast, false)
	for e in [-1.0, 1.0]:
		Geo.cyl(h, Vector3(e * 0.2, hy, 0), 0.06, 0.07, cast, false, 16)
	Geo.cyl(h, Vector3(0, hy + 0.035 + 0.016, 0), 0.034, 0.032, cast, false, 16)
	Geo.cyl(h, Vector3(0, hy + 0.035 + 0.034, 0), 0.02, 0.006, bakelite, false, 12)
	# two chains and the cable up to the ceiling
	var top := hy + 0.035
	var up := ceiling_y - pos.y
	for e in [-1.0, 1.0]:
		var y := top + 0.02
		var k := 0
		while y < up - 0.01:
			Geo.box(h, Vector3(e * 0.16, y, 0), Vector3(0.012, 0.05, 0.026), chain_m, false, PI / 2 if k % 2 == 1 else 0.0)
			y += 0.042
			k += 1
		Geo.box(h, Vector3(e * 0.16, up - 0.01, 0), Vector3(0.05, 0.02, 0.05), cast, false)              # its ceiling hook plate
	Geo.cyl(h, Vector3(0.05, (top + up) * 0.5, 0.03), 0.006, up - top, cable_m, false, 6)
	return tubes


## Angled desk lamp facing +Z; lit, it throws a warm pool on the desk in front of it (a spot down out of the shade)
## and a little glow round itself.
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
		var pool := Geo.spot(h, Vector3(0, 0.36, 0.27), Vector3(0, 0.36, 0.27), Color(1.0, 0.8, 0.55), 2.2, 1.5, 52.0)
		pool.rotation.x = -PI / 2 - 0.4              # down and out toward +Z, where the shade faces
		pool.spot_attenuation = 0.9
		pool.spot_angle_attenuation = 1.4
		pool.light_specular = 0.4
		pool.light_volumetric_fog_energy = 0.15
		var l := Geo.omni(h, Vector3(0, 0.3, 0.28), Color(1.0, 0.82, 0.58), 0.25, 1.6)
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
static func door(parent: Node3D, pos: Vector3, rot_y: float, plate_text := "", wall := 0.3, look := "") -> Dictionary:
	var root := _holder(parent, pos, rot_y)
	var casing: Material
	var paint: Material
	if look == "wood":                          # the service corridor's: dark stained wood in a dark casing
		casing = _cached("door_casing_wood", func(): return Mats.std(Color(0.085, 0.075, 0.068), 0.5, 0.1))
		paint = _cached("door_wood", func(): return Mats.std(Color(0.16, 0.12, 0.09), 0.45, 0.05))
	else:
		casing = Mats.std(Color(0.42, 0.42, 0.4), 0.5, 0.3)
		paint = Mats.std(Color(0.66, 0.64, 0.58), 0.6, 0.1)
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


## The service corridors' doors (user, with a photo of a worn steel door: "문 모양이랑 텍스처 이거랑 똑같이 해줘"):
## pale blue-grey painted steel, scratched and grimy, a square wired-glass vision panel high in the middle, a chrome
## push bar across, a riveted brushed kick plate at the foot, a closer at the head, in a worn steel frame with rust at
## its edges. Same frame and leaf as door() (wall through local X, the doorway along Z, the leaf hung at z -0.475);
## its dressed face is +X (`face` +1) or -X. Returns {root, leaf, block, use}.
static func steel_door(parent: Node3D, pos: Vector3, rot_y: float, wall := 0.2, face := 1.0) -> Dictionary:
	var root := _holder(parent, pos, rot_y)
	var frame := steel_door_frame()
	# a thin frame lining the opening, 12 mm proud of both wall faces (user: "문틀 두께가 너무 두꺼워 라인이, 5분의1
	# 정도로": its line on the wall was 0.1 m, now 0.02)
	for sz in [-1.0, 1.0]:
		Geo.box(root, Vector3(0, 1.065, sz * 0.465), Vector3(wall + 0.024, 2.13, 0.02), frame, false)
	Geo.box(root, Vector3(0, 2.12, 0), Vector3(wall + 0.024, 0.02, 0.95), frame, false)
	var leaf := Node3D.new()
	root.add_child(leaf)
	leaf.position = Vector3(0, 0, -0.475)
	Geo.box(leaf, Vector3(0, 1.06, 0.465), Vector3(0.045, 2.09, 0.93), steel_door_paint(), false)
	# the dressed face (corridor side) and the plain back
	var w := 0.93
	var fx := Transform3D(Basis(Vector3(0, 0, -face), Vector3.UP, Vector3(face, 0, 0)), Vector3(face * 0.0225, 0, 0.465 + face * w * 0.5))
	door_face(leaf, fx, w, 2.09, face < 0.0, true)
	var bx := Transform3D(Basis(Vector3(0, 0, face), Vector3.UP, Vector3(-face, 0, 0)), Vector3(-face * 0.0225, 0, 0.465 - face * w * 0.5))
	door_face(leaf, bx, w, 2.09, face > 0.0, false)
	# hinge knuckles on the frame side
	for hy in [0.25, 1.05, 1.85]:
		Geo.cyl(leaf, Vector3(face * (wall * 0.5 + 0.02), hy, 0.01), 0.012, 0.11, steel_door_chrome())
	var block := Geo.blocker(root, Vector3(0, 1.065, 0), Vector3(wall, 2.13, 0.95))
	seed_weathered(root, pos * 0.37 + Vector3(rot_y, 0.0, 0.0))
	var use := Interactable.create(root, Vector3(0, 1.05, 0), Vector3(wall + 0.3, 2.0, 0.9), "문 열기", Callable())
	use.press_sound = ""
	return {"root": root, "leaf": leaf, "block": block, "use": use}


## One face of such a door, built in the face's own frame `xf` (in `leaf`'s space): x along the leaf's width from its
## u = 0 edge, y up, z out of the face (the surface at z 0); `hinge_at_0`: the hinged edge is at u = 0. `front`: the
## dressed side (vision panel frame, push bar, riveted kick plate, closer); else the plain side (vision panel frame and
## a pull handle). `layer` (non-zero) puts what it builds on that render layer.
static func door_face(leaf: Node3D, xf: Transform3D, w: float, h: float, hinge_at_0: bool, front: bool, layer := 0) -> Node3D:
	var f := Node3D.new()
	leaf.add_child(f)
	f.transform = xf
	var made: Array[MeshInstance3D] = []
	var hinge_u := 0.0 if hinge_at_0 else w
	var latch_u := w - hinge_u
	var toward_hinge := -1.0 if hinge_at_0 else 1.0     # sign of u from the latch side toward the hinge
	# vision panel: dark wired glass in a light steel frame, high in the middle
	var vc := Vector2(w * 0.5, 1.52)
	var vs := 0.3
	made.append(Geo.box(f, Vector3(vc.x, vc.y, 0.002), Vector3(vs, vs, 0.004), steel_door_glass(), false))
	var wire := _cached("door_wire", func(): return Mats.std(Color(0.1, 0.1, 0.11), 0.5))
	for k in 4:
		var o := -vs * 0.5 + vs * (k + 1) / 5.0
		made.append(Geo.box(f, Vector3(vc.x + o, vc.y, 0.0045), Vector3(0.0025, vs, 0.001), wire, false))
		made.append(Geo.box(f, Vector3(vc.x, vc.y + o, 0.0045), Vector3(vs, 0.0025, 0.001), wire, false))
	var trim := _cached("door_vision_trim", func(): return Mats.std(Color(0.03, 0.03, 0.035), 0.45))   # black (user)
	for s in [-1.0, 1.0]:
		made.append(Geo.box(f, Vector3(vc.x + s * (vs * 0.5 + 0.015), vc.y, 0.007), Vector3(0.03, vs + 0.06, 0.014), trim, false))
		made.append(Geo.box(f, Vector3(vc.x, vc.y + s * (vs * 0.5 + 0.015), 0.007), Vector3(vs + 0.06, 0.03, 0.014), trim, false))
	var chrome := steel_door_chrome()
	if front:
		# push bar: two end brackets, a chrome tube between them
		var u0 := latch_u + toward_hinge * 0.1
		var u1 := hinge_u - toward_hinge * 0.12
		for u in [u0, u1]:
			made.append(Geo.box(f, Vector3(u, 1.0, 0.035), Vector3(0.05, 0.075, 0.07), chrome, false))
		var bar := Geo.cyl(f, Vector3((u0 + u1) * 0.5, 1.0, 0.06), 0.014, absf(u1 - u0), chrome)
		bar.rotation.z = PI / 2
		made.append(bar)
		# kick plate, riveted round its edge
		var kw := w - 0.08
		var kh := 0.34
		var kv := 0.22
		made.append(Geo.box(f, Vector3(w * 0.5, kv, 0.002), Vector3(kw, kh, 0.004), steel_door_kick(), false))
		var rivets: Array = []
		var n := int(kw / 0.07)
		for i in n + 1:
			var u := w * 0.5 - kw * 0.5 + 0.025 + (kw - 0.05) * i / float(n)
			rivets.append(Transform3D(Basis(), Vector3(u, kv - kh * 0.5 + 0.022, 0.005)))
			rivets.append(Transform3D(Basis(), Vector3(u, kv + kh * 0.5 - 0.022, 0.005)))
		for j in 3:
			var v := kv - kh * 0.5 + 0.022 + (kh - 0.044) * (j + 1) / 4.0
			rivets.append(Transform3D(Basis(), Vector3(w * 0.5 - kw * 0.5 + 0.025, v, 0.005)))
			rivets.append(Transform3D(Basis(), Vector3(w * 0.5 + kw * 0.5 - 0.025, v, 0.005)))
		var rm := SphereMesh.new()
		rm.radius = 0.006
		rm.height = 0.008
		rm.radial_segments = 6
		rm.rings = 3
		var mm := _multi(f, rm, chrome, rivets)
		if layer != 0:
			mm.layers = layer
		# closer at the head, near the hinge, its arm up to the frame
		var cu := hinge_u - toward_hinge * 0.22
		made.append(Geo.box(f, Vector3(cu, h - 0.11, 0.035), Vector3(0.3, 0.065, 0.07), chrome, false))
		var arm := Geo.box(f, Vector3(cu - toward_hinge * 0.27, h - 0.07, 0.075), Vector3(0.3, 0.022, 0.022), chrome, false)
		arm.rotation.z = toward_hinge * 0.08
		made.append(arm)
	else:
		var hu := latch_u + toward_hinge * 0.08
		made.append(Geo.box(f, Vector3(hu, 1.02, 0.045), Vector3(0.025, 0.3, 0.025), chrome, false))
		for hv in [0.9, 1.14]:
			made.append(Geo.box(f, Vector3(hu, hv, 0.022), Vector3(0.025, 0.025, 0.045), chrome, false))
	if layer != 0:
		for m in made:
			m.layers = layer
	return f


## Gives every weathered mesh under `root` (its noise in local space) its own `seed`, so no two doors look alike.
static func seed_weathered(root: Node, seed: Vector3) -> void:
	for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var sm := m.material_override as ShaderMaterial
		if sm and sm.shader and sm.shader.resource_path.ends_with("weathered.gdshader"):
			m.set_instance_shader_parameter("noise_seed", seed)


## The worn pale blue-grey paint: scratched through to bright metal, grime in patches and down from the top, a little
## rust coming through (weathered.gdshader).
static func steel_door_paint() -> Material:
	return _cached("steel_door_paint", func(): return Mats.shader_mat("res://shaders/weathered.gdshader", {
		"base_color": Color(0.38, 0.43, 0.45), "rust_color": Color(0.32, 0.23, 0.15), "grime_color": Color(0.22, 0.24, 0.25),
		"metallic": 0.1, "roughness": 0.5, "rust": 0.06, "grime": 0.32, "scale": 5.0, "scratches": 1.0, "runs": 0.6,
		"scratch_color": Color(0.6, 0.62, 0.62), "local_space": true}))


static func steel_door_frame() -> Material:
	return _cached("steel_door_frame", func(): return Mats.shader_mat("res://shaders/weathered.gdshader", {
		"base_color": Color(0.3, 0.33, 0.35), "rust_color": Color(0.3, 0.2, 0.11), "grime_color": Color(0.14, 0.15, 0.15),
		"metallic": 0.15, "roughness": 0.55, "rust": 0.4, "grime": 0.65, "scale": 11.0, "scratches": 0.8, "runs": 0.8,
		"scratch_color": Color(0.7, 0.72, 0.72), "local_space": true}))


static func steel_door_kick() -> Material:
	return _cached("steel_door_kick", func(): return Mats.shader_mat("res://shaders/weathered.gdshader", {
		"base_color": Color(0.045, 0.045, 0.05), "rust_color": Color(0.12, 0.09, 0.06), "grime_color": Color(0.03, 0.03, 0.03),
		"metallic": 0.2, "roughness": 0.5, "rust": 0.05, "grime": 0.3, "scale": 9.0, "brushed": 1.0, "scratches": 0.4,
		"runs": 0.3, "scratch_color": Color(0.22, 0.22, 0.22), "local_space": true}))


## The hardware (push bar, handle, hinges, rivets): black (user: "문 하얀부분 다 검은색으로 바꿔줘 모든 문을").
static func steel_door_chrome() -> Material:
	return _cached("steel_door_chrome", func(): return Mats.std(Color(0.035, 0.035, 0.04), 0.4, 0.2))


static func steel_door_glass() -> Material:
	return _cached("steel_door_glass", func(): return Mats.std(Color(0.07, 0.08, 0.08), 0.18))


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
static func ceiling_fan(parent: Node3D, pos: Vector3, ceiling_y: float, brass := false, drop := 0.42) -> void:
	var h := _holder(parent, Vector3(pos.x, ceiling_y, pos.z), 0.0)
	var white: Material = Mats.std(Color(0.78, 0.77, 0.72), 0.45, 0.2)
	if brass:
		white = _cached("brass", func(): return Mats.std(Color(0.6, 0.47, 0.25), 0.3, 0.85))
	Geo.cyl(h, Vector3(0, -0.03, 0), 0.07, 0.06, white)
	Geo.cyl(h, Vector3(0, -(drop - 0.12) * 0.5 - 0.05, 0), 0.012, drop - 0.12, white if brass else Mats.get_mat("metal"))
	var rotor := Node3D.new()
	h.add_child(rotor)
	rotor.position.y = -drop
	Geo.cyl(rotor, Vector3.ZERO, 0.11, 0.12, white)
	Geo.cyl(rotor, Vector3(0, -0.085, 0), 0.06, 0.05, white)
	var blade: Material = Mats.std(Color(0.5, 0.38, 0.25), 0.6)
	var nb := 5 if brass else 4
	if brass:
		blade = _cached("fan_blade", func(): return Mats.std(Color(0.3, 0.2, 0.12), 0.5))
	for i in nb:
		var arm := Node3D.new()
		rotor.add_child(arm)
		arm.rotation.y = i * TAU / nb
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
## a name card (`names`) and a number; locker `ajar` stands a little open on a jacket; cartons on top. Locker `hollow`
## is a real compartment (back, sides, top, floor, a hat shelf, a hanging rail) whose door can be swung open: returns
## {holder, door (its hinge node; open = rotation.y about -1.9), hang (a node under the rail, for what hangs there),
## front (the compartment's front centre at y 0, holder space)}; otherwise {}.
static func lockers(parent: Node3D, pos: Vector3, rot_y: float, n: int, names: Array, ajar := -1, first := 1, hollow := -1, red := -1) -> Dictionary:
	var h := _holder(parent, pos, rot_y)
	var w := 0.4
	var ht := 1.8
	var d := 0.5
	var body: Material = Mats.weathered_steel(Color(0.47, 0.5, 0.5))
	var dark := Mats.std(Color(0.04, 0.04, 0.045), 0.9)
	var total := w * n
	var out := {}
	var zb := -0.02 - (d - 0.04) * 0.5                     # the body's back face
	var zf := d * 0.5 - 0.04                               # its front face (the doors close over it)
	if hollow < 0:
		Geo.box(h, Vector3(0, ht * 0.5, -0.02), Vector3(total, ht, d - 0.04), body, false)
		Geo.blocker(h, Vector3(0, ht * 0.5, 0), Vector3(total, ht, d))
	else:
		var x0 := -total * 0.5
		var c0 := x0 + w * hollow
		var c1 := c0 + w
		for seg: Vector2 in [Vector2(x0, c0), Vector2(c1, -x0)]:
			if seg.y - seg.x > 0.01:
				Geo.box(h, Vector3((seg.x + seg.y) * 0.5, ht * 0.5, -0.02), Vector3(seg.y - seg.x, ht, d - 0.04), body, false)
				Geo.blocker(h, Vector3((seg.x + seg.y) * 0.5, ht * 0.5, 0), Vector3(seg.y - seg.x, ht, d))
		var inner := Mats.std(Color(0.56, 0.58, 0.56), 0.6)        # pale: what hangs in it shows up
		var cx := (c0 + c1) * 0.5
		var mid := (zb + zf) * 0.5
		var depth := zf - zb
		Geo.box(h, Vector3(cx, ht * 0.5, zb + 0.01), Vector3(w, ht, 0.02), inner, false)                # back
		for sx: float in [c0 + 0.008, c1 - 0.008]:
			Geo.box(h, Vector3(sx, ht * 0.5, mid), Vector3(0.016, ht, depth), body, false)              # sides
			Geo.blocker(h, Vector3(sx, ht * 0.5, mid), Vector3(0.016, ht, depth))
		Geo.box(h, Vector3(cx, ht - 0.01, mid), Vector3(w, 0.02, depth), inner, false)                   # top
		Geo.box(h, Vector3(cx, 0.09, mid), Vector3(w, 0.02, depth), inner, false)                       # floor
		Geo.box(h, Vector3(cx, 1.52, mid), Vector3(w - 0.03, 0.014, depth - 0.02), inner, false)        # hat shelf
		var rail := Geo.cyl(h, Vector3(cx, 1.44, mid), 0.008, w - 0.03, Mats.get_mat("metal"))
		rail.rotation.z = PI / 2
		# only its back is solid: the clothes in it stay within reach, and nobody fits in a locker
		Geo.blocker(h, Vector3(cx, ht * 0.5, zb + 0.06), Vector3(w, ht, 0.12))
		var hang := Node3D.new()
		hang.name = "Hang"
		h.add_child(hang)
		hang.position = Vector3(cx, 1.44, mid + 0.02)
		out = {"holder": h, "hang": hang, "front": Vector3(cx, 0, zf)}
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
		var card_m: Material = Mats.std(Color(0.72, 0.08, 0.07), 0.55) if i == red else Mats.get_mat("paper")   # (`red`: a red name card)
		var card := Geo.box(door, Vector3(dw * 0.5, 1.42, 0.022), Vector3(0.14, 0.045, 0.003), card_m, false)
		if i < names.size() and names[i] != "":
			var ink := Color(0.97, 0.95, 0.9) if i == red else Color(0.1, 0.12, 0.3)
			Geo.fit(Geo.label(card, names[i], Vector3(0, 0, 0.002), 0.0, 40, ink, 0.0012, false, "hand"), 0.12, 0.035)
		var num := Geo.box(door, Vector3(dw * 0.5, 1.745, 0.022), Vector3(0.07, 0.03, 0.003), Mats.std(Color(0.85, 0.84, 0.78), 0.6), false)
		Geo.fit(Geo.label(num, "%02d" % (first + i), Vector3(0, 0, 0.002), 0.0, 32, Color(0.1, 0.1, 0.1), 0.0011, true), 0.06, 0.024)
		if i == hollow:
			out["door"] = door
			out["door_w"] = dw
	return out


## A tall two-door steel cabinet `size` facing +Z, for documents: doors with long pulls, a key lock, and a card on a
## door for each of `tags`.
static func steel_cabinet(parent: Node3D, pos: Vector3, rot_y: float, size := Vector3(0.9, 1.8, 0.45), tags := []) -> void:
	var h := _holder(parent, pos, rot_y)
	var body: Material = Mats.weathered_steel(Color(0.42, 0.46, 0.44))
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
	var body: Material = Mats.weathered_steel(Color(0.5, 0.5, 0.47))
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


## A cork board facing +Z `size`, centred on `pos`: a dark frame and bare cork (the user's cork photo, Mats
## "cork_board"; the papers pinned on it were taken off — user: "보드판 메모지 다 떼고 이 텍스처로 바꿔줘").
static func notice_board(parent: Node3D, pos: Vector3, rot_y: float, size: Vector2, _seed_n := 0) -> void:
	var h := _holder(parent, pos, rot_y)
	Geo.box(h, Vector3(0, 0, 0.01), Vector3(size.x + 0.05, size.y + 0.05, 0.02), Mats.std(Color(0.36, 0.26, 0.17), 0.6), false)
	# the cork: the photo once across the board, cropped to its shape (not stretched, no seams)
	var q := QuadMesh.new()
	q.size = size
	var cork := MeshInstance3D.new()
	cork.mesh = q
	var m := (Mats.get_mat("cork_board") as StandardMaterial3D).duplicate() as StandardMaterial3D
	m.uv1_scale = Vector3(1.0, size.y / size.x, 1.0) if size.x >= size.y else Vector3(size.x / size.y, 1.0, 1.0)
	cork.material_override = m
	h.add_child(cork)
	cork.position = Vector3(0, 0, 0.0215)


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
static func steel_chair(parent: Node3D, pos: Vector3, rot_y: float, vinyl_color := Color(0.3, 0.2, 0.14)) -> void:
	var h := _holder(parent, pos, rot_y)
	var tube := Mats.std(Color(0.6, 0.61, 0.6), 0.3, 0.8)
	var vinyl := Mats.std(vinyl_color, 0.45)
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


## A late-80s desktop PC facing +Z (the old beige PC of the user's photo): a yellowed, grimy beige case (Mats
## "plastic_aged") with a seam round its lid, a floppy slot, a drive bay with its tray and button, the power button
## and its lamp; the CRT on top showing `screen` ("dos", "form" or "off"); a beige keyboard and mouse in front.
static func old_pc(parent: Node3D, pos: Vector3, rot_y: float, screen := "dos") -> void:
	var h := _holder(parent, pos, rot_y)
	var beige: Material = Mats.get_mat("plastic_aged")
	var dark: Material = Mats.get_mat("plastic_dark")
	Geo.box(h, Vector3(0, 0.07, -0.05), Vector3(0.44, 0.14, 0.4), beige, false)
	Geo.box(h, Vector3(0, 0.112, 0.1505), Vector3(0.44, 0.003, 0.003), dark, false)            # the lid's seam
	Geo.box(h, Vector3(-0.1, 0.085, 0.151), Vector3(0.1, 0.006, 0.003), dark, false)            # the floppy slot
	Geo.box(h, Vector3(-0.07, 0.085, 0.1505), Vector3(0.012, 0.01, 0.004), beige, false)
	Geo.box(h, Vector3(0.09, 0.075, 0.151), Vector3(0.15, 0.04, 0.004), beige, false)           # the drive bay
	Geo.box(h, Vector3(0.09, 0.072, 0.1535), Vector3(0.13, 0.002, 0.002), dark, false)
	Geo.box(h, Vector3(0.09, 0.03, 0.151), Vector3(0.15, 0.03, 0.003), beige, false)            # a blank bay under it
	Geo.cyl(h, Vector3(0.19, 0.095, 0.152), 0.01, 0.006, beige, false, 10).rotation.x = PI / 2
	led(h, Vector3(0.19, 0.07, 0.152), Color(0.3, 1.0, 0.45))
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
	keyboard(h, Vector3(0, 0, 0.255), 0.0)
	mouse(h, Vector3(0.3, 0, 0.25), 0.0)


## The office keyboard (user, with a photo of one: "텍스처랑 모양 그대로"): a full-size off-white board of the late 80s
## facing +Z — the case wedged up at the back, the keys in its layout (function row in blocks of four, the main block,
## the arrow and editing keys, the numpad, the lamp panel) in off-white with the modifiers, the function blocks, the
## editing keys and the numpad's operators in grey, its cable going back. 0.46 x 0.19 m. The keys are one MultiMesh
## shared by every keyboard.
static func keyboard(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var h := _holder(parent, pos, rot_y)
	var tilt := Node3D.new()
	h.add_child(tilt)
	tilt.rotation.x = 0.07                                                       # the back higher
	var case_m: Material = Mats.get_mat("plastic_peripheral")
	Geo.box(tilt, Vector3(0, 0.016, 0), Vector3(0.46, 0.03, 0.19), case_m, false)
	Geo.box(tilt, Vector3(0.18, 0.0325, -0.046), Vector3(0.074, 0.004, 0.016), _cached("kb_lamps",
			func(): return Mats.std(Color(0.42, 0.42, 0.41), 0.5)), false)                         # the lamp panel
	for k in 3:
		led(tilt, Vector3(0.155 + k * 0.025, 0.0348, -0.046), Color(0.3, 1.0, 0.45) if k == 0 else Color(0.08, 0.1, 0.08))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _keys_multimesh()
	mmi.material_override = _cached("kb_keys", _make_key_mat)
	tilt.add_child(mmi)
	mmi.position = Vector3(0, 0.031, 0.006)
	Geo.cyl(h, Vector3(-0.12, 0.012, -0.13), 0.004, 0.08, _cached("kb_cable", func(): return Mats.std(Color(0.7, 0.69, 0.65), 0.6)),
			false, 6).rotation.x = PI / 2


static var _key_mm: MultiMesh


static func _make_key_mat() -> Material:
	var m := Mats.std(Color.WHITE, 0.52)
	m.vertex_color_use_as_albedo = true
	return m


## The keyboard's keys, built once: [x in units, row, width in units, grey?] in the layout of the user's photo (a unit
## = 19 mm; row 0 is the function row at the back, rows 1..5 the main rows toward the front).
static func _keys_multimesh() -> MultiMesh:
	if _key_mm:
		return _key_mm
	var keys := []
	keys.append([0.0, 0, 1.0, true])
	for i in 4:
		keys.append([2.0 + i, 0, 1.0, false])
		keys.append([6.5 + i, 0, 1.0, true])
		keys.append([11.0 + i, 0, 1.0, false])
	for i in 3:
		keys.append([15.5 + i, 0, 1.0, true])                                   # print screen, scroll lock, pause
	for i in 13:
		keys.append([float(i), 1, 1.0, false])
	keys.append([13.0, 1, 2.0, true])                                         # backspace
	keys.append([0.0, 2, 1.5, true])                                          # tab
	for i in 12:
		keys.append([1.5 + i, 2, 1.0, false])
	keys.append([13.5, 2, 1.5, false])
	keys.append([0.0, 3, 1.75, true])                                         # caps lock
	for i in 11:
		keys.append([1.75 + i, 3, 1.0, false])
	keys.append([12.75, 3, 2.25, true])                                       # enter
	keys.append([0.0, 4, 2.25, true])
	for i in 10:
		keys.append([2.25 + i, 4, 1.0, false])
	keys.append([12.25, 4, 2.75, true])
	keys.append([0.0, 5, 1.5, true])
	keys.append([2.5, 5, 1.5, true])
	keys.append([4.0, 5, 7.0, false])                                         # space
	keys.append([11.0, 5, 1.5, true])
	keys.append([13.5, 5, 1.5, true])
	for r in [1, 2]:
		for i in 3:
			keys.append([15.5 + i, r, 1.0, true])                               # the editing keys
	keys.append([16.5, 4, 1.0, true])
	for i in 3:
		keys.append([15.5 + i, 5, 1.0, true])                                   # the arrows
	for i in 4:
		keys.append([19.0 + i, 1, 1.0, true])                                   # num lock, / * -
	for r in [2, 3, 4]:
		for i in 3:
			keys.append([19.0 + i, r, 1.0, false])
	keys.append([19.0, 5, 2.0, false])
	keys.append([21.0, 5, 1.0, false])
	var u := 0.019
	var light := Color(0.86, 0.85, 0.8)
	var grey := Color(0.57, 0.57, 0.55)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	mm.mesh = bm
	var tall := [[22.0, 2, true], [22.0, 4, true]]                                # numpad + and enter, two rows high
	mm.instance_count = keys.size() + tall.size()
	var x0 := -23.0 * u * 0.5
	var z_of := func(row: int) -> float: return (-3.25 + 0.5 + (0.0 if row == 0 else 1.5 + row - 1)) * u
	for i in keys.size():
		var k: Array = keys[i]
		var w: float = k[2]
		var c := Vector3(x0 + (float(k[0]) + w * 0.5) * u, 0.006, z_of.call(k[1]))
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(w * u - 0.003, 0.012, u - 0.003)), c))
		mm.set_instance_color(i, grey if k[3] else light)
	for j in tall.size():
		var t: Array = tall[j]
		var c := Vector3(x0 + (float(t[0]) + 0.5) * u, 0.006, z_of.call(t[1]) + u * 0.5)
		mm.set_instance_transform(keys.size() + j, Transform3D(Basis.from_scale(Vector3(u - 0.003, 0.012, 2.0 * u - 0.003)), c))
		mm.set_instance_color(keys.size() + j, grey)
	_key_mm = mm
	return mm


## The office mouse (user, with a photo of one: "텍스처랑 모양 그대로"): a light grey two-button wheel mouse, egg-shaped,
## its buttons toward -Z (the computer), the wheel between them, the cable out of its nose. 0.062 x 0.115 m.
static func mouse(parent: Node3D, pos: Vector3, rot_y: float) -> void:
	var h := _holder(parent, pos, rot_y)
	var body: Material = Mats.get_mat("plastic_peripheral")
	var dark: Material = _cached("mouse_wheel", func(): return Mats.std(Color(0.38, 0.38, 0.37), 0.5))
	var shell := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 20
	sm.rings = 12
	shell.mesh = sm
	shell.material_override = body
	h.add_child(shell)
	shell.scale = Vector3(0.062, 0.072, 0.115)                                  # half of it under the desk top
	shell.position = Vector3(0, 0.0, 0.004)
	Geo.box(h, Vector3(0, 0.031, -0.03), Vector3(0.0015, 0.004, 0.05), dark, false)          # the split between the buttons
	Geo.box(h, Vector3(0, 0.0355, 0.002), Vector3(0.036, 0.0015, 0.0015), dark, false)               # where they end
	var wheel := Geo.cyl(h, Vector3(0, 0.033, -0.026), 0.008, 0.007, dark, false, 14)
	wheel.rotation.z = PI / 2
	Geo.cyl(h, Vector3(0, 0.003, -0.1), 0.0025, 0.09, _cached("kb_cable", func(): return Mats.std(Color(0.7, 0.69, 0.65), 0.6)),
			false, 6).rotation.x = PI / 2


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


## A pile of `n` manila folders, a little askew, paper edges showing (the concept art's desks are buried in them).
static func folders(parent: Node3D, pos: Vector3, rot_y: float, n: int, rng: RandomNumberGenerator) -> void:
	var manila := _cached("manila", func(): return Mats.std(Color(0.7, 0.56, 0.34), 0.8))
	var dark := _cached("manila_d", func(): return Mats.std(Color(0.55, 0.4, 0.22), 0.8))
	for i in n:
		var f := Geo.box(parent, pos + Vector3(rng.randf_range(-0.02, 0.02), 0.006 + i * 0.013, rng.randf_range(-0.02, 0.02)),
				Vector3(0.25, 0.011, 0.33), manila if i % 3 != 1 else dark, false, rot_y + rng.randf_range(-0.12, 0.12))
		if i % 2 == 0:
			Geo.box(f, Vector3(0.015, 0.0, 0.01), Vector3(0.21, 0.008, 0.3), Mats.get_mat("paper"), false)


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
## "typewriter", "books", "fan", "radio", "blotter", "ledger", "plant", "folders", "photos".
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
			"plant":
				potted_plant(h, p, 0.45, rng.randi_range(1, 99))
			"folders":
				folders(h, p, r, rng.randi_range(6, 16), rng)
			"photos":
				for k in rng.randi_range(3, 6):
					var ph := Geo.box(h, p + Vector3(rng.randf_range(-0.15, 0.15), 0.002 + k * 0.001, rng.randf_range(-0.1, 0.1)),
							Vector3(0.1, 0.001, 0.075), Mats.get_mat("paper"), false, rng.randf() * TAU)
					Geo.box(ph, Vector3(0, 0.0006, 0), Vector3(0.085, 0.0005, 0.06), _cached("photo", func(): return Mats.std(Color(0.32, 0.3, 0.28), 0.6)), false)
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
