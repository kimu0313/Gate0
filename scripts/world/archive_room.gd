class_name ArchiveRoom
extends RefCounted
## The records room (자료실) behind the corridors' farthest door from the lift — the one at the north end of E, the dead
## end past the office's east wall (user, 2026-11-05: "복도에 문들 많잖아. 엘리베이터와 가장 멀리있는 문에 자료실을
## 만들어줘"). Its look follows the user's second photo (2026-11-06: "자료실 이런 느낌으로해줘 그리고 살짝 어둡고
## 안개끼게" — an old records cellar): tall wooden shelving with yellowed folded paper and ledgers stacked flat with their
## spines out, numbered plates on the shelves' cornices, dark green steel shelving among them, a worn concrete floor,
## stained whitewashed walls and ceiling, cold white batten fluorescents; a little dark, a haze in the air.
##
## Built by ServiceHall in its own space (local = the terminal's coordinates, like the corridors) north of E's end
## wall, where nothing else stands. Its door is the corridor's steel door there, which opens ([E] 문 열기 / 문 닫기)
## into the room; everything inside is on Geo.VIS_SEALED with its own lights (the corridors' lights do not reach in,
## and its lights do not leak out; nothing here casts shadows but its own aisle lights). The shelf contents' faces and
## the floor are cut out of the photo (tools/make_archive_tex.gd): archive_bundles.png (eight crops, BUNDLES: 0-3
## paper, 4-7 ledgers), archive_floor.png.

const ROOM := Rect2(-12.25, -33.0, 8.25, 11.3)     # x, z: from E's end wall (z -21.7) north
const HT := 3.0                                     # its ceiling
const DOOR_X := -11.15                              # the door, in E's end wall (ServiceHall builds it)
const DOOR_Z := -21.6
const BAY := 1.0
const DEPTH := 0.42
const BAYS := 8
const ROW_Z := -23.1                                # where the rows start (a cross aisle by the door before them)
const LEVELS := [0.1, 0.44, 0.78, 1.12, 1.46, 1.8, 2.14]
const TOP := 2.42                                   # the top board (stacked boxes on it, up toward the ceiling)
## The shelf runs: [front x, facing (+1: the front toward +X)]. Against the west wall, three rows back to back, against
## the east wall; the aisles between are ~1.15 m (the door opens into the first).
const RUNS := [[-11.81, 1.0], [-10.66, -1.0], [-9.8, 1.0], [-8.65, -1.0], [-7.79, 1.0], [-6.64, -1.0], [-5.78, 1.0],
	[-4.44, -1.0]]
const AISLES := [-11.235, -9.225, -7.215, -5.11]
## Each crop's width / height (tools/make_archive_tex.gd prints them): 0-3 folded paper, 4-7 ledger stacks.
const BUNDLES := [1.842, 0.848, 0.847, 2.395, 0.839, 0.867, 0.743, 0.667]
const PAPER := [0, 1, 2, 3]
const LEDGERS := [4, 5, 6, 7]
## Per run: wooden shelving (true) or dark green steel, and what fills it ("paper", "ledgers" or "mix").
const RUN_WOOD := [true, true, true, false, false, true, true, false]
const RUN_FILL := ["paper", "ledgers", "ledgers", "mix", "mix", "ledgers", "paper", "mix"]
## Where the guidelines folder stands (user: "자료실 선반에 이런 지참서 올려놔줘"): [run, bay, level] — the third
## aisle's east side, five bays in, at waist height; that board is kept clear for it (guide_xform).
const GUIDE := [4, 5, 3]


## The guidelines folder's frame, in the room's (ServiceHall's) space: standing on its board near the back, leaning
## back a little, its face (+Z) toward the aisle, its foot at y 0.
static func guide_xform() -> Transform3D:
	var front: float = RUNS[GUIDE[0]][0]
	var facing: float = RUNS[GUIDE[0]][1]
	var zc := ROW_Z - (GUIDE[1] + 0.5) * BAY
	var y: float = LEVELS[GUIDE[2]]
	var b := Basis(Vector3.UP, facing * PI / 2) * Basis(Vector3.RIGHT, -0.22)
	return Transform3D(b, Vector3(front - facing * 0.2, y + 0.002, zc + 0.08))
const PAINT := Color(0.6, 0.6, 0.58)                # whitewashed walls, stained (the plaster photo's grain on them)
const CEIL := Color(0.68, 0.68, 0.66)
const WOOD := Color(0.34, 0.22, 0.13)               # old varnished shelving
const STEEL := Color(0.09, 0.14, 0.11)              # the dark green steel shelving on the photo's right
const LAMP := Color(0.93, 0.96, 1.0)                # cold-white fluorescent
const HAZE := 0.055                                 # the room's own fog

static var _fronts: Array = []                      # per bundle variant: Array of Transform3D (then the box fronts)
static var _bodies: Array = []                      # [Transform3D, Color]


## Builds the room into `hall` (ServiceHall) and makes its door open. Returns the room's root.
static func build(hall: ServiceHall) -> Node3D:
	var room := Node3D.new()
	room.name = "ArchiveRoom"
	hall.add_child(room)
	_shell(room)
	_shelving(room)
	_lights(room)
	_haze(room)
	_reverb(room)
	Geo.seal(room)
	_door(hall)
	return room


static func contains_local(l: Vector3) -> bool:
	return ROOM.grow(0.05).has_point(Vector2(l.x, l.z)) and l.y > -1.0 and l.y < HT + 1.0


# --------------------------------------------------------------------------------------------
## Floor (the photo's speckled floor), yellow-ochre walls with a dark skirting, white ceiling; the corridor's end wall
## lined on this side round the door.
static func _shell(room: Node3D) -> void:
	var x0 := ROOM.position.x
	var x1 := ROOM.end.x
	var z0 := ROOM.position.y
	var z1 := ROOM.end.y
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var floor_m := StandardMaterial3D.new()
	floor_m.albedo_texture = load("res://assets/textures/level/archive_floor.png")
	floor_m.uv1_triplanar = true
	floor_m.uv1_world_triplanar = true
	floor_m.uv1_scale = Vector3.ONE / 1.4
	floor_m.roughness = 0.62
	floor_m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var paint := _plaster(PAINT)
	var ceil_m := _plaster(CEIL)
	var skirt := Mats.std(Color(0.13, 0.13, 0.12), 0.6)
	Geo.box(room, Vector3(cx, -0.046, cz), Vector3(x1 - x0, 0.1, z1 - z0), floor_m)       # 4 mm over the corridors' floor
	Geo.box(room, Vector3(cx, HT + 0.05, cz), Vector3(x1 - x0 + 0.4, 0.1, z1 - z0 + 0.4), ceil_m, false)
	Geo.box(room, Vector3(x0 - 0.1, HT * 0.5, cz), Vector3(0.2, HT, z1 - z0), paint)
	Geo.box(room, Vector3(x1 + 0.1, HT * 0.5, cz), Vector3(0.2, HT, z1 - z0), paint)
	Geo.box(room, Vector3(cx, HT * 0.5, z0 - 0.1), Vector3(x1 - x0 + 0.4, HT, 0.2), paint)
	# the south wall: E's end wall (the corridors') up to x -9.85 with the door in it, then its own
	Geo.box(room, Vector3((-9.85 + x1 + 0.2) * 0.5, HT * 0.5, z1 + 0.1), Vector3(x1 + 0.2 + 9.85, HT, 0.2), paint)
	var dl := DOOR_X - 0.475 - 0.025
	var dr := DOOR_X + 0.475 + 0.025
	Geo.box(room, Vector3((x0 + dl) * 0.5, HT * 0.5, z1 - 0.006), Vector3(dl - x0, HT, 0.012), paint, false)
	Geo.box(room, Vector3((dr + x1) * 0.5, HT * 0.5, z1 - 0.006), Vector3(x1 - dr, HT, 0.012), paint, false)
	Geo.box(room, Vector3(DOOR_X, (2.155 + HT) * 0.5, z1 - 0.006), Vector3(dr - dl, HT - 2.155, 0.012), paint, false)
	# skirting all round (not across the door)
	Geo.box(room, Vector3(x0 + 0.008, 0.05, cz), Vector3(0.016, 0.1, z1 - z0), skirt, false)
	Geo.box(room, Vector3(x1 - 0.008, 0.05, cz), Vector3(0.016, 0.1, z1 - z0), skirt, false)
	Geo.box(room, Vector3(cx, 0.05, z0 + 0.008), Vector3(x1 - x0, 0.1, 0.016), skirt, false)
	Geo.box(room, Vector3((x0 + dl) * 0.5, 0.05, z1 - 0.016), Vector3(dl - x0, 0.1, 0.016), skirt, false)
	Geo.box(room, Vector3((dr + x1) * 0.5, 0.05, z1 - 0.016), Vector3(x1 - dr, 0.1, 0.016), skirt, false)


## The whitewashed plaster of the walls and ceiling: a flat colour broken by the plaster photo's stains and cracks.
static func _plaster(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = load("res://assets/textures/level/wall_office_plaster.png")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 2.4
	m.roughness = 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


# --------------------------------------------------------------------------------------------
## The runs of shelving (RUN_WOOD: tall wooden bookcases — a post at every bay line front and back, thick boards, end
## panels, a back, a cornice with a numbered plate over every bay — or dark green slotted-angle steel), every bay
## filled from the photo's crops (RUN_FILL: folded paper, ledgers stacked spines out, or both), now and then a gap.
static func _shelving(room: Node3D) -> void:
	_fronts = []
	for i in BUNDLES.size():
		_fronts.append([])
	_bodies = []
	var uprights: Array = []
	var boards: Array = []
	var lips: Array = []
	var braces: Array = []
	var w_posts: Array = []
	var w_boards: Array = []
	var w_panels: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 19871103
	var z_end := ROW_Z - BAYS * BAY
	var plate_m := Mats.std(Color(0.86, 0.84, 0.78), 0.7)
	for r in RUNS.size():
		var front: float = RUNS[r][0]
		var facing: float = RUNS[r][1]
		var cx := front - facing * DEPTH * 0.5
		var mid_z := (ROW_Z + z_end) * 0.5
		if RUN_WOOD[r]:
			# posts at every bay line, front and back; boards a run long; end panels; a back; the cornice and its plates
			for i in BAYS + 1:
				var z := ROW_Z - i * BAY
				for x: float in [front - facing * 0.024, front - facing * (DEPTH - 0.024)]:
					w_posts.append(Transform3D(Basis.from_scale(Vector3(0.048, TOP + 0.16, 0.048)), Vector3(x, (TOP + 0.16) * 0.5, z)))
			for y: float in LEVELS + [TOP]:
				w_boards.append(Transform3D(Basis.from_scale(Vector3(DEPTH, 0.026, BAYS * BAY)), Vector3(cx, y - 0.013, mid_z)))
			for z: float in [ROW_Z + 0.012, z_end - 0.012]:
				w_panels.append(Transform3D(Basis.from_scale(Vector3(DEPTH, TOP + 0.16, 0.024)), Vector3(cx, (TOP + 0.16) * 0.5, z)))
			w_panels.append(Transform3D(Basis.from_scale(Vector3(0.012, TOP + 0.16, BAYS * BAY)), Vector3(front - facing * (DEPTH - 0.006), (TOP + 0.16) * 0.5, mid_z)))
			w_panels.append(Transform3D(Basis.from_scale(Vector3(0.03, 0.12, BAYS * BAY + 0.03)), Vector3(front - facing * 0.015, TOP + 0.1, mid_z)))
			for i in BAYS:
				var plate := Geo.box(room, Vector3(front + facing * 0.002, TOP + 0.1, ROW_Z - (i + 0.5) * BAY), Vector3(0.12, 0.06, 0.004), plate_m, false)
				plate.rotation.y = facing * PI / 2
				Geo.fit(Geo.label(plate, str(1571 + r * BAYS + i), Vector3(0, 0, 0.003), 0.0, 40, Color(0.1, 0.1, 0.12), 0.0011, false, "print"), 0.1, 0.045)
		else:
			# uprights at every bay line, front and back (an L of angle: two thin flanges); boards with a turned-down lip
			for i in BAYS + 1:
				var z := ROW_Z - i * BAY
				for x: float in [front - facing * 0.018, front - facing * (DEPTH - 0.018)]:
					uprights.append(Transform3D(Basis.from_scale(Vector3(0.036, TOP + 0.04, 0.004)), Vector3(x, (TOP + 0.04) * 0.5, z)))
					uprights.append(Transform3D(Basis.from_scale(Vector3(0.004, TOP + 0.04, 0.036)), Vector3(x, (TOP + 0.04) * 0.5, z)))
			for y: float in LEVELS + [TOP]:
				boards.append(Transform3D(Basis.from_scale(Vector3(DEPTH, 0.016, BAYS * BAY)), Vector3(cx, y - 0.008, mid_z)))
				lips.append(Transform3D(Basis.from_scale(Vector3(0.01, 0.04, BAYS * BAY)), Vector3(front - facing * 0.005, y - 0.02, mid_z)))
			# an X brace on the back of a wall run
			if r == 0 or r == RUNS.size() - 1:
				var back := front - facing * (DEPTH - 0.004)
				var span := Vector2(BAY * 3.0, TOP * 0.5)
				for k in 3:
					for s: float in [-1.0, 1.0]:
						var b := Basis(Vector3(1, 0, 0), s * atan2(span.x, span.y)) * Basis.from_scale(Vector3(0.004, span.length(), 0.012))
						braces.append(Transform3D(b, Vector3(back, TOP * 0.5, ROW_Z - (k + 0.5) * BAY * 3.0)))
		# solid — but the run with the guidelines leaves their slot open (the [E] ray stops at blockers; the slot is far
		# too small to step into)
		if r != GUIDE[0]:
			Geo.blocker(room, Vector3(cx, TOP * 0.5 + 0.1, mid_z), Vector3(DEPTH, TOP + 0.2, BAYS * BAY + 0.04))
		else:
			var gz := ROW_Z - (GUIDE[1] + 0.5) * BAY
			var y0: float = LEVELS[GUIDE[2]]
			var y1: float = LEVELS[GUIDE[2] + 1] - 0.02
			var ztop := ROW_Z + 0.02
			var zbot := z_end - 0.02
			for seg: Vector2 in [Vector2(gz + BAY * 0.5, ztop), Vector2(zbot, gz - BAY * 0.5)]:
				if seg.y - seg.x > 0.01:
					Geo.blocker(room, Vector3(cx, TOP * 0.5 + 0.1, (seg.x + seg.y) * 0.5), Vector3(DEPTH, TOP + 0.2, seg.y - seg.x))
			Geo.blocker(room, Vector3(cx, y0 * 0.5, gz), Vector3(DEPTH, y0, BAY))
			Geo.blocker(room, Vector3(cx, (y1 + TOP + 0.2) * 0.5, gz), Vector3(DEPTH, TOP + 0.2 - y1, BAY))
		# what is on the boards
		var fill: String = RUN_FILL[r]
		for i in BAYS:
			var zc := ROW_Z - (i + 0.5) * BAY
			for l in LEVELS.size():
				var y: float = LEVELS[l]
				var clear: float = (LEVELS[l + 1] if l + 1 < LEVELS.size() else TOP) - y - (0.045 if RUN_WOOD[r] else 0.03)
				if r == GUIDE[0] and i == GUIDE[1] and l == GUIDE[2]:
					continue                                     # kept clear: the guidelines stand there (Shift1)
				if rng.randf() < 0.07:
					continue                                     # an empty shelf
				var ledgers := fill == "ledgers" or (fill == "mix" and rng.randf() < 0.5)
				_bundles(front, facing, y, zc, clear, rng, ledgers)
			# on top: a pile of paper (none above the wooden cornices' plates)
			if not RUN_WOOD[r] and rng.randf() < 0.7:
				_bundles(front, facing, TOP, zc, 0.3, rng, false)
	var steel := Mats.std(STEEL, 0.55, 0.2)
	_multi(room, BoxMesh.new(), steel, uprights)
	_multi(room, BoxMesh.new(), steel, boards)
	_multi(room, BoxMesh.new(), steel, lips)
	_multi(room, BoxMesh.new(), steel, braces)
	var wood := Mats.std(WOOD, 0.62)
	_multi(room, BoxMesh.new(), wood, w_posts)
	_multi(room, BoxMesh.new(), wood, w_boards)
	_multi(room, BoxMesh.new(), Mats.std(WOOD * 0.85, 0.66), w_panels)
	# the contents: bodies (one box mesh, a colour each), faces (a quad per crop)
	var body_m := StandardMaterial3D.new()
	body_m.vertex_color_use_as_albedo = true
	body_m.vertex_color_is_srgb = true                   # (the colours below are sRGB: read as linear they washed out to grey-white)
	body_m.roughness = 0.92
	var xf: Array = []
	var cols: Array = []
	for b: Array in _bodies:
		xf.append(b[0])
		cols.append(b[1])
	_multi(room, BoxMesh.new(), body_m, xf, cols)
	var atlas: Texture2D = load("res://assets/textures/level/archive_bundles.png")
	for v in BUNDLES.size():
		var m := StandardMaterial3D.new()
		m.albedo_texture = atlas
		m.uv1_scale = Vector3(0.25, 0.5, 1.0)
		m.uv1_offset = Vector3((v % 4) * 0.25, (v / 4) * 0.5, 0.0)
		m.roughness = 0.9
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_multi(room, QuadMesh.new(), m, _fronts[v])


## One bay's board at `y` (front `front`, facing ±X), at most `clear` high, filled across: bundles of yellowed folded
## paper (a little askew) or stacks of ledgers lying flat, spines out (tight and square) — each a block with one of
## the photo's crops on its face.
static func _bundles(front: float, facing: float, y: float, zc: float, clear: float, rng: RandomNumberGenerator,
		ledgers := false) -> void:
	var u := -BAY * 0.5 + 0.03 + rng.randf_range(0.0, 0.04)
	var kinds: Array = LEDGERS if ledgers else PAPER
	var paper_c := [Color(0.46, 0.4, 0.3), Color(0.4, 0.34, 0.25), Color(0.5, 0.44, 0.33), Color(0.36, 0.31, 0.23)]   # (dark: their lit tops read as paper, not slabs)
	var ledger_c := [Color(0.24, 0.16, 0.13), Color(0.3, 0.22, 0.17), Color(0.27, 0.25, 0.23), Color(0.22, 0.13, 0.11)]
	while u < BAY * 0.5 - (0.18 if ledgers else 0.22):
		var w := minf(rng.randf_range(0.22, 0.3) if ledgers else rng.randf_range(0.28, 0.45), BAY * 0.5 - 0.03 - u)
		if w < 0.15:
			break
		var v: int = kinds[rng.randi_range(0, kinds.size() - 1)]
		var h := clampf(w / BUNDLES[v] * rng.randf_range(0.88, 1.08), 0.06, clear - 0.02)
		var d := rng.randf_range(0.32, 0.38) if ledgers else rng.randf_range(0.3, 0.39)
		var col: Color = (ledger_c if ledgers else paper_c)[rng.randi_range(0, 3)]
		_item(front, facing, y, zc + _along(facing, u + w * 0.5), w, h, d,
			rng.randf_range(-0.02, 0.02) if ledgers else rng.randf_range(-0.08, 0.08),
			rng.randf_range(0.0, 0.02) if ledgers else rng.randf_range(0.0, 0.04), col, v)
		u += w + (rng.randf_range(0.004, 0.02) if ledgers else rng.randf_range(0.01, 0.06))


## Position along the run (u from the bay's middle) in z: the runs go north, and a run facing -X sees them mirrored.
static func _along(facing: float, u: float) -> float:
	return -u * facing


## One block on a board: its body and its face (`variant`'s crop, or the box front).
static func _item(front: float, facing: float, y: float, z: float, w: float, h: float, d: float, yaw: float, back: float,
		col: Color, variant: int) -> void:
	var n := Vector3(facing, 0, 0)
	var t := Vector3(0, 0, -facing)
	var rot := Basis(Vector3.UP, yaw)
	var c := Vector3(front - facing * (d * 0.5 + 0.01 + back), y + h * 0.5 + 0.001, z)
	_bodies.append([Transform3D(rot * Basis(Vector3(d, 0, 0), Vector3(0, h, 0), Vector3(0, 0, w)), c), col])
	var face := c + rot * (n * (d * 0.5 + 0.002))
	_fronts[variant].append(Transform3D(rot * Basis(t * w, Vector3(0, h, 0), n), face))


static func _multi(parent: Node3D, mesh: Mesh, mat: Material, xf: Array, colors := []) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	parent.add_child(mi)
	return mi


# --------------------------------------------------------------------------------------------
## White batten fittings down every aisle (and across the cross aisles), each its own shadowed light down the aisle;
## a faint fill for the dark between.
static func _lights(room: Node3D) -> void:
	var housing := Mats.get_mat("plastic_white")
	var tube := Mats.emissive(LAMP, 2.6, Color(0.95, 0.96, 1.0))
	var z_end := ROW_Z - BAYS * BAY
	for x: float in AISLES:
		for z: float in [-24.3, -27.6, -30.9]:
			_fitting(room, Vector3(x, HT, z), 0.0, housing, tube)
			var s := SpotLight3D.new()
			room.add_child(s)
			s.position = Vector3(x, HT - 0.1, z)
			s.rotation.x = -PI / 2
			s.light_color = LAMP
			s.light_energy = 1.8
			s.spot_range = 4.6
			s.spot_angle = 72.0
			s.spot_angle_attenuation = 0.9
			s.shadow_enabled = true
			s.shadow_blur = 1.5
			s.light_volumetric_fog_energy = 0.5          # (its cone shows in the haze, like the photo's tubes)
			# the tube also lights the white ceiling round it and the walls' tops (as in the photo)
			var o := OmniLight3D.new()
			room.add_child(o)
			o.position = Vector3(x, HT - 0.32, z)
			o.light_color = LAMP
			o.light_energy = 0.45
			o.omni_range = 3.4
			o.light_specular = 0.0
			o.light_volumetric_fog_energy = 0.0
	# across the aisle by the door and the one along the north wall (no shadows: open floor)
	for f: Array in [[-9.8, -22.4], [-6.2, -22.4], [-9.8, (z_end + ROOM.position.y) * 0.5], [-6.2, (z_end + ROOM.position.y) * 0.5]]:
		_fitting(room, Vector3(f[0], HT, f[1]), PI / 2, housing, tube)
		var o := OmniLight3D.new()
		room.add_child(o)
		o.position = Vector3(f[0], HT - 0.25, f[1])
		o.light_color = LAMP
		o.light_energy = 0.5
		o.omni_range = 4.0
		o.light_volumetric_fog_energy = 0.0
	var fill := OmniLight3D.new()
	room.add_child(fill)
	fill.position = Vector3(ROOM.get_center().x, HT - 0.4, ROOM.get_center().y)
	fill.light_color = Color(0.7, 0.76, 0.82)
	fill.light_energy = 0.26
	fill.omni_range = 9.5
	fill.light_specular = 0.0
	fill.light_volumetric_fog_energy = 0.0


## A surface-mounted batten under the ceiling at `at` (its top), along Z (yaw 0) or X (PI/2): white housing, opal tube.
static func _fitting(room: Node3D, at: Vector3, yaw: float, housing: Material, tube: Material) -> void:
	var f := Node3D.new()
	room.add_child(f)
	f.position = at
	f.rotation.y = yaw
	Geo.box(f, Vector3(0, -0.035, 0), Vector3(0.13, 0.07, 1.52), housing, false)
	Geo.box(f, Vector3(0, -0.078, 0), Vector3(0.095, 0.03, 1.46), tube, false)
	for s: float in [-1.0, 1.0]:
		Geo.box(f, Vector3(0, -0.06, s * 0.745), Vector3(0.12, 0.05, 0.03), housing, false)   # end caps


## The haze in the air (user: "살짝 어둡고 안개끼게"): a fog volume the size of the room, pale grey, thickening a little
## toward the floor; the aisle lights' cones show in it.
static func _haze(room: Node3D) -> void:
	var fm := FogMaterial.new()
	fm.density = HAZE
	fm.albedo = Color(0.7, 0.73, 0.76)
	fm.height_falloff = 0.15
	fm.edge_fade = 0.06
	var fog := FogVolume.new()
	fog.name = "Haze"
	fog.size = Vector3(ROOM.size.x, HT, ROOM.size.y)
	fog.material = fm
	room.add_child(fog)
	fog.position = Vector3(ROOM.get_center().x, HT * 0.5, ROOM.get_center().y)


static func _reverb(room: Node3D) -> void:
	var a := Area3D.new()
	a.name = "Reverb_archive"
	a.collision_layer = Geo.LAYER_AUDIO
	a.collision_mask = 0
	a.monitoring = false
	a.priority = 2
	a.reverb_bus_enabled = true
	a.reverb_bus_name = "RevTight"
	a.reverb_bus_amount = 0.22
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ROOM.size.x, HT, ROOM.size.y)
	cs.shape = box
	a.add_child(cs)
	room.add_child(a)
	a.position = Vector3(ROOM.get_center().x, HT * 0.5, ROOM.get_center().y)


# --------------------------------------------------------------------------------------------
## The door (the corridor's steel door in E's end wall): it opens into the room and stays as you leave it.
static func _door(hall: ServiceHall) -> void:
	var door: Dictionary = hall.doors_by["자료실"]
	hall.side_doors.erase(door)
	# lit from both sides: the corridors' lights and the room's own (its inside face was black)
	for v: VisualInstance3D in (door.root as Node).find_children("*", "VisualInstance3D", true, false):
		v.layers |= Geo.VIS_SEALED
	door["open"] = false
	var use := door.use as Interactable
	use.prompt = "문 열기"
	use.callback = func(): set_open(door, not door.open)
	# its name over the door, on the corridor side (user: "자료실은 문 위에 자료실이라고 표기해줘" — the only door out
	# here with a name: the others' plates were all taken off)
	var plate := Geo.box(hall, Vector3(DOOR_X, 2.44, DOOR_Z + 0.108), Vector3(0.62, 0.17, 0.016), Mats.std(Color(0.13, 0.14, 0.15), 0.4, 0.3), false)
	Geo.box(hall, Vector3(DOOR_X, 2.44, DOOR_Z + 0.1), Vector3(0.64, 0.19, 0.004), Mats.std(Color(0.55, 0.57, 0.57), 0.35, 0.6), false)
	Geo.fit(Geo.label(plate, "자료실", Vector3(0, 0, 0.0085), 0.0, 96, Color(0.93, 0.93, 0.9), 0.0016, false, "sign"), 0.5, 0.12)


static func set_open(door: Dictionary, open: bool) -> void:
	var root := door.root as Node3D
	if not open:
		# not on whoever stands in the doorway
		var p := root.get_tree().get_first_node_in_group("player") as Node3D
		if p:
			var q := root.global_transform.affine_inverse() * p.global_position
			if absf(q.x) < 0.55 and absf(q.z) < 0.6:
				return
	door.open = open
	(door.use as Interactable).prompt = "문 닫기" if open else "문 열기"
	(door.block as StaticBody3D).collision_layer = 0 if open else Geo.LAYER_WORLD
	var leaf: Node3D = door.leaf
	var tw := leaf.create_tween()
	tw.tween_property(leaf, "rotation:y", deg_to_rad(-88.0) if open else 0.0, 0.9 if open else 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	Snd.play_at("door_heavy" if open else "door_slam", root.global_position + Vector3(0, 1.0, 0), -11.0 if open else -14.0, 1.1, 5.0)
