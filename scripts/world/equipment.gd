class_name Equipment
## Office and service-room equipment the terminal places: the punch clock with its time-card rack, the fax machine,
## the main power isolator and the distribution boards (BreakerPanel / LightPanel). Code-built to look like the real
## things; each builder keeps its colliders and returns what gameplay needs. Wall-mounted builders take `pos` 2 cm
## in front of the wall face (local -Z = into the wall, +Z = out into the room).

const WALL := -0.02          # the wall face in a wall-mounted builder's local space

static var _mats := {}


static func _m(key: String) -> Material:
	if not _mats.has(key):
		var m: Material
		match key:
			"shell":         # off-white moulded ABS
				m = Mats.std(Color(0.86, 0.85, 0.81), 0.42)
			"shell_dark":
				m = Mats.std(Color(0.3, 0.31, 0.33), 0.5)
			"trim":
				m = Mats.std(Color(0.14, 0.15, 0.16), 0.45, 0.1)
			"lcd":
				m = Mats.emissive(Color(0.32, 0.42, 0.34), 0.35, Color(0.62, 0.7, 0.6))
			"powder":        # grey powder-coated steel
				m = Mats.std(Color(0.6, 0.62, 0.63), 0.55, 0.35)
			"powder_in":     # the board's inside: a shade darker, galvanised back
				m = Mats.std(Color(0.5, 0.52, 0.53), 0.6, 0.4)
			"deadfront":
				m = Mats.std(Color(0.7, 0.71, 0.72), 0.5, 0.3)
			"din":
				m = Mats.std(Color(0.08, 0.085, 0.09), 0.6)
			"plate_white":
				m = Mats.std(Color(0.94, 0.94, 0.92), 0.4)
			"sticker_yellow":
				m = Mats.std(Color(0.98, 0.8, 0.08), 0.5)
			"sticker_red":
				m = Mats.std(Color(0.78, 0.08, 0.07), 0.5)
			"isolator":      # heavy enclosure, blue-grey
				m = Mats.std(Color(0.34, 0.38, 0.42), 0.5, 0.45)
			"grip_red":
				m = Mats.std(Color(0.72, 0.06, 0.05), 0.45)
			"lock_red":
				m = Mats.std(Color(0.8, 0.12, 0.08), 0.35, 0.2)
			"rack":
				m = Mats.std(Color(0.68, 0.7, 0.71), 0.45, 0.5)
			"fax_body":
				m = Mats.std(Color(0.82, 0.82, 0.8), 0.45)
			"fax_top":
				m = Mats.std(Color(0.66, 0.67, 0.68), 0.45)
			_:
				m = Mats.get_mat(key)
		_mats[key] = m
	return _mats[key]


static func _prism(parent: Node3D, size: Vector3, r: float, pos: Vector3, mat: Material, closed := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = CarouselMesh.rounded_prism(size, r, closed)
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = pos
	return mi


## Printed text on a plate `size` (w, h) centred at `pos`, kept inside it with Geo.label_margin.
static func _print(parent: Node3D, text: String, pos: Vector3, size: Vector2, color: Color, px := 0.0024, font := 28) -> Label3D:
	var l := Geo.label(parent, text, pos, 0.0, font, color, px, false, "print")
	var pad := Geo.label_margin(size.x, size.y)
	Geo.fit(l, size.x - 2.0 * pad - 0.004, size.y - 2.0 * pad)
	l.set_meta("no_fit", true)
	return l


## Plate with printed text: a box 3 cm deep (most of it inside what it is stuck to) so the label audit finds it.
static func _plate(parent: Node3D, text: String, centre: Vector3, size: Vector2, plate: String, ink: Color, font := 28) -> void:
	Geo.box(parent, centre + Vector3(0, 0, -0.013), Vector3(size.x, size.y, 0.03), _m(plate), false)
	_print(parent, text, centre + Vector3(0, 0, 0.0035), size, ink, 0.0024, font)


# ------------------------------------------------------------------------------------------------- punch clock
## Wall time recorder at `pos` (facing +Z of `rot_y`): moulded off-white body, a backlit LCD that keeps the shift
## clock, IN/OUT mode keys, the card guide on top with a card in it, a ribbon door; a steel time-card rack to its
## left. Returns the Interactable the shift director hooks (callback set later).
static func punch_clock(parent: Node3D, pos: Vector3, rot_y := 0.0) -> Interactable:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = pos
	holder.rotation.y = rot_y
	var depth := 0.13
	var front := WALL + depth
	_prism(holder, Vector3(0.24, 0.3, depth), 0.025, Vector3(0, -0.17, WALL + depth * 0.5), _m("shell"))
	# display bezel with the LCD and the clock on it
	Geo.box(holder, Vector3(0, 0.055, front + 0.003), Vector3(0.2, 0.085, 0.006), _m("trim"), false)
	Geo.box(holder, Vector3(0, 0.06, front + 0.0065), Vector3(0.15, 0.045, 0.002), _m("lcd"), false)
	var clock := Geo.label(holder, Game.clock_text(), Vector3(0, 0.06, front + 0.0085), 0.0, 40, Color(0.06, 0.08, 0.07), 0.0016, true, "lcd")
	Geo.fit(clock, 0.13, 0.036)
	clock.set_meta("no_fit", true)
	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.autostart = true
	clock.add_child(tick)
	tick.timeout.connect(func(): Geo.set_text(clock, Game.clock_text()))
	# mode keys (출근 · 퇴근 · 외출 · 복귀) under the display
	var keys := [Color(0.16, 0.42, 0.85), Color(0.2, 0.62, 0.32), Color(0.92, 0.55, 0.12), Color(0.55, 0.57, 0.6)]
	for i in 4:
		Geo.box(holder, Vector3(-0.069 + i * 0.046, -0.005, front + 0.004), Vector3(0.036, 0.018, 0.008), Mats.std(keys[i], 0.4), false)
	# ribbon / printer door: a seam round a lower panel, a key lock
	Geo.box(holder, Vector3(0, -0.095, front + 0.001), Vector3(0.204, 0.104, 0.002), _m("trim"), false)
	Geo.box(holder, Vector3(0, -0.095, front + 0.0035), Vector3(0.2, 0.1, 0.002), _m("shell"), false)
	Geo.cyl(holder, Vector3(0.075, -0.06, front + 0.003), 0.007, 0.004, Mats.get_mat("metal")).rotation.x = PI / 2
	# card guide on top, a time card standing in it
	var top := 0.13
	Geo.box(holder, Vector3(0, top + 0.004, WALL + depth * 0.55), Vector3(0.16, 0.008, 0.03), _m("trim"), false)
	Geo.box(holder, Vector3(0.01, top + 0.05, WALL + depth * 0.55), Vector3(0.1, 0.1, 0.0025), Mats.get_mat("paper"), false)
	Geo.box(holder, Vector3(0.01, top + 0.09, WALL + depth * 0.55 + 0.0016), Vector3(0.1, 0.012, 0.0008), _m("sticker_red"), false)
	# name plate above
	_plate(holder, "근태 기록기  TIME CLOCK", Vector3(0, 0.29, WALL + 0.004), Vector2(0.3, 0.05), "plate_white", Color(0.12, 0.13, 0.15))
	_card_rack(holder, Vector3(-0.38, -0.02, 0.0))
	Geo.blocker(holder, Vector3(0, -0.02, WALL + depth * 0.5), Vector3(0.24, 0.3, depth))
	var it := Interactable.create(holder, Vector3(0, -0.02, 0.07), Vector3(0.3, 0.38, 0.16), "근무 기록 (출근·퇴근)", Callable())
	it.press_sound = "clock_punch"
	return it


## Steel time-card rack: ten slanted pockets, most holding a card. `at` = rack centre on the wall plane.
static func _card_rack(holder: Node3D, at: Vector3) -> void:
	var h := 0.6
	var w := 0.15
	Geo.box(holder, at + Vector3(0, 0, WALL + 0.005), Vector3(w, h, 0.01), _m("rack"), false)
	for sx in [-1.0, 1.0]:
		Geo.box(holder, at + Vector3(sx * (w * 0.5 - 0.004), 0, WALL + 0.02), Vector3(0.008, h, 0.03), _m("rack"), false)
	for i in 10:
		var y := h * 0.5 - 0.06 - i * 0.054
		var lip := Geo.box(holder, at + Vector3(0, y - 0.012, WALL + 0.028), Vector3(w - 0.016, 0.03, 0.004), _m("rack"), false)
		lip.rotation.x = -0.18
		if i in [2, 6]:
			continue
		var lift := 0.02 + (i % 3) * 0.006
		Geo.box(holder, at + Vector3((i % 2) * 0.006 - 0.003, y + lift, WALL + 0.018), Vector3(0.1, 0.07, 0.002), Mats.get_mat("paper"), false)
		Geo.box(holder, at + Vector3((i % 2) * 0.006 - 0.003, y + lift + 0.03, WALL + 0.0192), Vector3(0.1, 0.008, 0.0006), _m("sticker_red"), false)


# ------------------------------------------------------------------------------------------------ distribution board
## Wall distribution board `size` (w, h): powder-coated steel enclosure with its door(s) swung open, an inner
## dead-front cover with screws, a black DIN strip behind the breaker row, cable trunking with conduits above.
## Returns the dead-front node: switches go on its plane (local z 0), the title plate and notes too.
static func board(parent: Node3D, size: Vector2, title: String, note := "") -> Node3D:
	var w := size.x
	var h := size.y
	var d := 0.16
	var t := 0.014
	var zc := WALL + d * 0.5
	Geo.box(parent, Vector3(0, 0, WALL + 0.008), Vector3(w - 2.0 * t, h - 2.0 * t, 0.01), _m("powder_in"), false)   # back, inside the walls
	for sx in [-1.0, 1.0]:
		Geo.box(parent, Vector3(sx * (w * 0.5 - t * 0.5), 0, zc), Vector3(t, h, d), _m("powder"), false)
	for sy in [-1.0, 1.0]:
		Geo.box(parent, Vector3(0, sy * (h * 0.5 - t * 0.5), zc), Vector3(w - 2.0 * t, t, d), _m("powder"), false)
	# gasket lip round the opening
	var lip := Mats.get_mat("rubber")
	for sx in [-1.0, 1.0]:
		Geo.box(parent, Vector3(sx * (w * 0.5 - t - 0.004), 0, WALL + d - 0.003), Vector3(0.008, h - 2.0 * t, 0.006), lip, false)
	# dead front, 6 cm back from the rim
	var face := Node3D.new()
	parent.add_child(face)
	face.position = Vector3(0, 0, WALL + d - 0.06)
	var fw := w - 2.0 * t - 0.02
	var fh := h - 2.0 * t - 0.02
	Geo.box(face, Vector3(0, 0, -0.003), Vector3(fw, fh, 0.006), _m("deadfront"), false)
	for cx in [-1.0, 1.0]:
		for cy in [-1.0, 1.0]:
			Geo.cyl(face, Vector3(cx * (fw * 0.5 - 0.025), cy * (fh * 0.5 - 0.025), 0.002), 0.008, 0.004, Mats.get_mat("metal")).rotation.x = PI / 2
	Geo.box(face, Vector3(0, -0.02, 0.0008), Vector3(fw - 0.12, 0.15, 0.0016), _m("din"), false)
	_plate(face, title, Vector3(0, fh * 0.5 - 0.06, 0.0), Vector2(minf(fw - 0.12, 0.62), 0.055), "plate_white", Color(0.1, 0.11, 0.13))
	_plate(face, "감전 주의  DANGER", Vector3(fw * 0.5 - 0.1, -fh * 0.5 + 0.045, 0.0), Vector2(0.15, 0.04), "sticker_yellow", Color(0.08, 0.07, 0.05), 24)
	if note != "":
		_plate(face, note, Vector3(-0.07, -fh * 0.5 + 0.045, 0.0), Vector2(minf(fw - 0.36, 0.5), 0.034), "plate_white", Color(0.2, 0.21, 0.24), 22)
	# door(s) swung open on their hinges, the circuit chart inside the left one
	var doors := 2 if w > 0.8 else 1
	var dw := w / doors
	for k in doors:
		var left := k == 0
		var hinge := Node3D.new()
		parent.add_child(hinge)
		hinge.position = Vector3((-w * 0.5) if left else (w * 0.5), 0, WALL + d)
		hinge.rotation.y = deg_to_rad(-104.0 if left else 100.0)
		var s := 1.0 if left else -1.0
		Geo.box(hinge, Vector3(s * dw * 0.5, 0, -0.009), Vector3(dw, h, 0.018), _m("powder"), false)
		Geo.blocker(hinge, Vector3(s * dw * 0.5, 0, -0.009), Vector3(dw, h, 0.03))
		Geo.box(hinge, Vector3(s * (dw - 0.04), 0, 0.012), Vector3(0.024, 0.11, 0.024), _m("trim"), false)    # handle
		for hy in [-h * 0.32, h * 0.32]:
			Geo.cyl(hinge, Vector3(0, hy, -0.004), 0.008, 0.07, _m("trim"))
		if left:
			# circuit chart on the inside of the door
			Geo.box(hinge, Vector3(s * dw * 0.5, 0.02, -0.0186), Vector3(minf(dw - 0.12, 0.2), minf(h - 0.2, 0.28), 0.0012), Mats.get_mat("paper"), false)
			for li in 6:
				Geo.box(hinge, Vector3(s * dw * 0.5, 0.11 - li * 0.035, -0.0194), Vector3(minf(dw - 0.16, 0.16), 0.003, 0.0006), _m("trim"), false)
	# cable trunking along the wall above, conduits down into the top of the box
	Geo.box(parent, Vector3(0, h * 0.5 + 0.2, WALL + 0.045), Vector3(w + 0.16, 0.09, 0.09), _m("powder"), false)
	for cx in [-0.25, 0.0, 0.25]:
		Geo.cyl(parent, Vector3(cx * w, h * 0.5 + 0.0775, WALL + 0.05), 0.018, 0.155, Mats.get_mat("plastic_grey"))
	Geo.blocker(parent, Vector3(0, 0, zc), Vector3(w, h, d))
	return face


# --------------------------------------------------------------------------------------------------------- fax
## Office fax on its table: `table_pos` = foot of the table, `rot_y` turns the set (at PI / 2 against an east wall
## the machine faces -X, into the room). Base with paper cassette, flatbed with document feeder, handset, keypad
## panel with a small LCD, a received page in the output tray.
static func fax(parent: Node3D, table_pos: Vector3, rot_y := PI / 2) -> void:
	if TripoProps.exists("security", "SEC_InspectionTable"):
		TripoProps.spawn(parent, "security", "SEC_InspectionTable", table_pos, rot_y, true, null, Vector3(0.9, 0.8, 0.7))
	else:
		Geo.box(parent, table_pos + Vector3(0, 0.4, 0), Vector3(0.7, 0.8, 0.9), Mats.get_mat("wood"))
	var m := Node3D.new()
	parent.add_child(m)
	m.position = table_pos + Basis(Vector3.UP, rot_y) * Vector3(0, 0.8, 0.05)
	m.rotation.y = rot_y + PI
	# base (paper cassette) and flatbed unit
	_prism(m, Vector3(0.42, 0.13, 0.34), 0.025, Vector3(0, 0, 0), _m("fax_body"))
	Geo.box(m, Vector3(0, 0.045, 0.1705), Vector3(0.38, 0.003, 0.002), _m("trim"), false)          # cassette seam
	Geo.box(m, Vector3(0, 0.07, 0.1705), Vector3(0.1, 0.012, 0.002), _m("trim"), false)           # cassette grip
	Geo.box(m, Vector3(0, 0.14, -0.025), Vector3(0.4, 0.02, 0.3), _m("trim"), false)              # exit slot between
	_prism(m, Vector3(0.42, 0.075, 0.32), 0.025, Vector3(0, 0.15, -0.01), _m("fax_body"))
	# received page in the output tray, its printed lines
	var page := Node3D.new()
	m.add_child(page)
	page.position = Vector3(0.02, 0.142, 0.18)
	page.rotation.x = 0.05
	Geo.box(page, Vector3.ZERO, Vector3(0.21, 0.0016, 0.16), Mats.get_mat("paper"), false)
	for li in 5:
		Geo.box(page, Vector3(-0.01 * (li % 2), 0.0012, -0.04 + li * 0.022), Vector3(0.14 - (li % 2) * 0.04, 0.0008, 0.004), _m("trim"), false)
	# document feeder on top: roller cover, inclined input tray with a few sheets
	Geo.box(m, Vector3(0.02, 0.244, 0.05), Vector3(0.28, 0.038, 0.07), _m("fax_top"), false)
	var tray := Node3D.new()
	m.add_child(tray)
	tray.position = Vector3(0.02, 0.232, -0.0)
	tray.rotation.x = -0.32
	Geo.box(tray, Vector3(0, 0.006, -0.09), Vector3(0.26, 0.008, 0.17), _m("fax_top"), false)
	Geo.box(tray, Vector3(0, 0.012, -0.095), Vector3(0.21, 0.004, 0.15), Mats.get_mat("paper"), false)
	# control panel with LCD and keypad (front right), handset in its cradle (left)
	var panel := Node3D.new()
	m.add_child(panel)
	panel.position = Vector3(0.0, 0.228, 0.12)
	panel.rotation.x = 0.35
	Geo.box(panel, Vector3(0.08, 0.004, 0.0), Vector3(0.22, 0.008, 0.07), _m("shell_dark"), false)
	Geo.box(panel, Vector3(0.02, 0.0095, -0.005), Vector3(0.07, 0.003, 0.03), _m("lcd"), false)
	for r in 4:
		for c in 3:
			Geo.box(panel, Vector3(0.095 + c * 0.018, 0.009, -0.024 + r * 0.016), Vector3(0.012, 0.004, 0.011), _m("plate_white"), false)
	Geo.box(panel, Vector3(0.165, 0.009, 0.0), Vector3(0.018, 0.005, 0.028), Mats.std(Color(0.2, 0.62, 0.32), 0.4), false)
	_prism(m, Vector3(0.06, 0.035, 0.24), 0.022, Vector3(-0.175, 0.226, -0.01), _m("shell_dark"))
	for hz in [-0.1, 0.08]:
		_prism(m, Vector3(0.07, 0.03, 0.06), 0.025, Vector3(-0.175, 0.255, hz - 0.01), _m("shell_dark"))
	Geo.cyl(m, Vector3(-0.215, 0.12, -0.1), 0.005, 0.2, _m("trim"))                                    # cord
	Geo.blocker(m, Vector3(0, 0.12, 0), Vector3(0.44, 0.24, 0.36))


# -------------------------------------------------------------------------------------------------- main power
## Main power isolator on a wall at `pos`, facing +Z of `rot_y`: a heavy blue-grey enclosure with its door, the
## operating handle on the right side (node "Lever"), a red lockout padlock through the hasp, danger and name
## plates, pilot lamps. Returns the lever's Interactable.
static func main_power(parent: Node3D, pos: Vector3, rot_y: float) -> Interactable:
	var mp := Node3D.new()
	parent.add_child(mp)
	mp.position = pos
	mp.rotation.y = rot_y
	var w := 0.6
	var h := 0.82
	var d := 0.24
	var front := WALL + d
	_prism(mp, Vector3(w, h, d), 0.03, Vector3(0, -h * 0.5, WALL + d * 0.5), _m("isolator"))
	# door panel with hinges (left) and quarter-turn latches (right)
	Geo.box(mp, Vector3(0, 0, front + 0.006), Vector3(w - 0.06, h - 0.06, 0.012), _m("isolator"), false)
	for hy in [-0.26, 0.26]:
		Geo.cyl(mp, Vector3(-w * 0.5 + 0.03, hy, front + 0.008), 0.011, 0.09, _m("trim"))
		Geo.cyl(mp, Vector3(w * 0.5 - 0.07, hy, front + 0.015), 0.016, 0.012, _m("trim")).rotation.x = PI / 2
	_plate(mp, "MAIN POWER  주 전원", Vector3(0, 0.3, front + 0.014), Vector2(0.42, 0.07), "plate_white", Color(0.1, 0.11, 0.13), 30)
	_plate(mp, "위험 · 고압  DANGER", Vector3(0, 0.18, front + 0.014), Vector2(0.42, 0.08), "sticker_red", Color(1, 1, 1), 30)
	_plate(mp, "터미널 전체 전원 차단", Vector3(0, -0.3, front + 0.014), Vector2(0.4, 0.05), "sticker_yellow", Color(0.08, 0.07, 0.05), 26)
	# pilot lamps: supply on (green, lit), tripped (red, dark)
	Geo.cyl(mp, Vector3(-0.08, 0.04, front + 0.02), 0.022, 0.016, Mats.get_mat("lamp_green")).rotation.x = PI / 2
	Geo.cyl(mp, Vector3(0.08, 0.04, front + 0.02), 0.022, 0.016, Mats.std(Color(0.35, 0.06, 0.05), 0.3)).rotation.x = PI / 2
	for lx in [-0.08, 0.08]:
		Geo.cyl(mp, Vector3(lx, 0.04, front + 0.014), 0.03, 0.006, _m("trim")).rotation.x = PI / 2
	# operating handle on the right side: hub, arm up and forward, red grip
	var side_x := w * 0.5
	var hub := Vector3(side_x + 0.02, 0.05, WALL + d * 0.55)
	Geo.cyl(mp, hub, 0.055, 0.04, _m("trim")).rotation.z = PI / 2
	var lever := Node3D.new()
	lever.name = "Lever"
	mp.add_child(lever)
	lever.position = hub + Vector3(0.03, 0, 0)
	lever.rotation.x = -0.5
	Geo.box(lever, Vector3(0, 0.14, 0), Vector3(0.03, 0.28, 0.045), Mats.get_mat("metal"), false)
	Geo.box(lever, Vector3(0, 0.3, 0), Vector3(0.05, 0.12, 0.07), _m("grip_red"), false)
	# lockout hasp below the hub with a red padlock through it
	Geo.box(mp, Vector3(side_x + 0.025, -0.07, WALL + d * 0.55), Vector3(0.012, 0.07, 0.07), Mats.get_mat("metal"), false)
	Geo.box(mp, Vector3(side_x + 0.04, -0.15, WALL + d * 0.55), Vector3(0.03, 0.055, 0.045), _m("lock_red"), false)
	for sz in [-0.012, 0.012]:
		Geo.cyl(mp, Vector3(side_x + 0.04, -0.105, WALL + d * 0.55 + sz), 0.004, 0.04, Mats.get_mat("metal"))
	Geo.box(mp, Vector3(side_x + 0.04, -0.084, WALL + d * 0.55), Vector3(0.008, 0.006, 0.032), Mats.get_mat("metal"), false)
	# conduit into the top
	Geo.cyl(mp, Vector3(-0.15, h * 0.5 + 0.3, WALL + 0.06), 0.03, 0.6, Mats.get_mat("plastic_grey"))
	Geo.blocker(mp, Vector3(0, 0, WALL + d * 0.5), Vector3(w + 0.16, h, d))
	var it := Interactable.create(mp, Vector3(0.12, 0, 0.16), Vector3(0.9, 1.0, 0.3), "주 전원 레버", Callable())
	it.press_sound = ""
	return it
