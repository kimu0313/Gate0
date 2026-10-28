class_name FireDoor
## The leaves of a steel double fire door (방화문), from boxes: baked-enamel panels on hinge nodes at the jambs, a narrow
## wired-glass light you cannot see through, a push bar across the side it is pushed from, kick plates, a closer at the
## head and the red 방화문 plate. The staff passage's GATE 0 door (Prologue) and the boarding bridge's padlocked gate
## door (JetBridge) are both built from it.
##
## Local frame of `root`: the doorway is centred on x 0, the floor at y 0, the leaves in the z 0 plane. `face` is the
## side (-1 / +1 in z) the push bars are on: the leaves are pushed from there and swing away from it (open_angle).

const PAINT := Color(0.5, 0.49, 0.45)


static func paint() -> Material:
	return Mats.std(PAINT, 0.55, 0.35)


static func wired() -> Material:
	return Mats.std(Color(0.035, 0.04, 0.045), 0.15, 0.3)


## One leaf on a hinge node at `hinge_x` (side -1 = hung on the -X jamb, +1 = on the +X jamb), `w` wide and `h` tall,
## its push bar on the `face` side. Returns the hinge node: turn its rotation.y to open_angle(side, face, deg).
static func leaf(root: Node3D, side: float, face: float, hinge_x: float, w: float, h: float) -> Node3D:
	var metal := Mats.get_mat("metal")
	var hinge := Node3D.new()
	root.add_child(hinge)
	hinge.position = Vector3(hinge_x, 0, 0)
	var c := -side * w * 0.5                             # the leaf's middle, from its hinge
	Geo.box(hinge, Vector3(c, 0.02 + h * 0.5, 0), Vector3(w, h, 0.05), paint(), false)
	Geo.box(hinge, Vector3(c + side * 0.08, h - 0.31, 0), Vector3(0.15, 0.36, 0.054), wired(), false)
	Geo.box(hinge, Vector3(c, 1.0, face * 0.06), Vector3(w - 0.16, 0.04, 0.035), metal, false)
	for bx in [-1.0, 1.0]:
		Geo.box(hinge, Vector3(c + bx * (w * 0.5 - 0.09), 1.0, face * 0.04), Vector3(0.06, 0.09, 0.04), metal, false)
	for fz in [-1.0, 1.0]:
		Geo.box(hinge, Vector3(c, 0.14, fz * 0.0265), Vector3(w - 0.04, 0.24, 0.003), metal, false)
	Geo.box(hinge, Vector3(c + side * 0.12, h - 0.08, face * 0.05), Vector3(0.3, 0.06, 0.05), metal, false)     # closer
	Geo.box(hinge, Vector3(c + side * 0.2, h - 0.02, face * 0.06), Vector3(0.24, 0.02, 0.02), metal, false)     # its arm
	var plate := Node3D.new()
	hinge.add_child(plate)
	plate.position = Vector3(c, 0.62, face * 0.027)
	Geo.box(plate, Vector3.ZERO, Vector3(0.2, 0.07, 0.003), Mats.std(Color(0.72, 0.1, 0.08), 0.5), false)
	var l := Geo.label(plate, "방화문", Vector3(0, 0, face * 0.002), label_yaw(face), 40, Color(1, 1, 1), 0.0016, false, "print")
	Geo.fit(l, 0.17, 0.05)
	l.set_meta("no_fit", true)
	return hinge


## The hinge rotation that swings a leaf `deg` degrees open, away from its push side.
static func open_angle(side: float, face: float, deg: float) -> float:
	return -face * side * deg_to_rad(deg)


## A Label3D's yaw so it reads from the `face` side.
static func label_yaw(face: float) -> float:
	return 0.0 if face > 0.0 else PI


## The leaves knock against the latch (locked): a few small jiggles, the push bars going down.
static func jiggle(leaves: Array, face: float) -> void:
	for i in leaves.size():
		var hinge: Node3D = leaves[i]
		var side := -1.0 if i == 0 else 1.0
		var tw := hinge.create_tween()
		for k in 3:
			tw.tween_property(hinge, "rotation:y", open_angle(side, face, randf_range(0.8, 1.4)), 0.05)
			tw.tween_property(hinge, "rotation:y", 0.0, 0.07)
			tw.tween_interval(randf_range(0.1, 0.16))
