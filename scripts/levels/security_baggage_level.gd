class_name SecurityBaggageLevel
extends Node3D
## Walkable level built from the two background sketches (Downloads/일러스트3.jpg, gateD.jpg):
## hall A = security checkpoint (two inspection lanes, coffered ceiling), behind it the gate concourse with
## the moving walkway; hall B = baggage claim (three carousels out of the west wall), joined by a connector.
## Every object is a Tripo P2.0 low-poly mesh; the props of a zone share one atlas material (albedo + normal
## + ORM), see assets/models/<zone>/<zone>_report.json. Only the shell (floor, walls, ceilings, beams, glass)
## and the sign text are built here.
## Debug: `-- --level-shots <dir>` captures SHOTS / SKETCH_SHOTS and quits, `-- --walk-test` checks the routes.

const TEX := "res://assets/textures/level/"
const HALL_A_H := 4.1
const HALL_B_H := 3.6
const LANES := [[0.5, -7.2], [4.9, -7.6]]        # (x, z) of each X-ray tunnel centre
const CAROUSELS := [-7.2, -14.4, -21.6]           # z of each baggage carousel centre
const CAROUSEL_X := 20.15                         # carousel centre x, its west end 0.9 m off the wall
const SPAWN := Vector3(0.0, 0.05, 1.0)
## [name, feet position, look-at point] for `--level-shots`
const SHOTS := [
	["lane", Vector3(-1.6, 0.05, -2.4), Vector3(1.5, 0.9, -8.0)],
	["concourse", Vector3(-0.8, 0.05, -12.5), Vector3(1.6, 1.0, -40.0)],
	["walkway", Vector3(-0.2, 0.05, -14.2), Vector3(1.9, 0.6, -18.5)],
	["carousel", Vector3(24.6, 0.05, -2.0), Vector3(18.5, 0.4, -8.0)],
	["seating", Vector3(23.2, 0.05, -15.5), Vector3(26.8, 0.5, -10.5)],
	["connector", Vector3(6.0, 0.05, 1.4), Vector3(22.0, 1.4, 1.4)],
	["mat_carousel", Vector3(24.1, 0.05, -4.2), Vector3(21.6, 0.3, -6.2)],
	["mat_seats", Vector3(24.7, 0.05, -1.9), Vector3(26.4, 0.5, -4.3)],
	["mat_bin", Vector3(25.3, 0.05, -5.2), Vector3(26.6, 0.45, -6.4)],
]
## Views matching the sketches: [name, eye position, yaw (deg, 0 = -Z), vanishing point (fraction of the image),
## vertical fov]. The sketches are one-point perspectives with the vanishing point off centre (a shifted lens),
## captured with a frustum camera at the sketch's aspect (render at 1920x1258).
const SKETCH_SHOTS := [
	["sketch_security", Vector3(0.0, 1.82, 0.0), 0.0, Vector2(0.3225, 0.4638), 53.5],
	["sketch_baggage", Vector3(25.0, 1.45, -0.2), 0.0, Vector2(0.86, 0.55), 52.0],
]

var atmosphere: Atmosphere
var player: Player
var zones := {}
var _mat := {}


func _ready() -> void:
	atmosphere = Atmosphere.new()
	add_child(atmosphere)
	atmosphere.setup("night")
	# windowless interior lit only by its fixtures: lift the night preset's near-black ambient so ceilings,
	# beams and the shadow sides of props read like the sketches (the probes below handle reflections)
	atmosphere.env.ambient_light_color = Color(0.6, 0.62, 0.65)
	atmosphere.env.ambient_light_energy = 0.5
	atmosphere.env.tonemap_exposure = 1.15
	_materials()
	_shell()
	_hall_a()
	_concourse()
	_hall_b()
	_lights()
	Geo.fit_labels(self)
	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.teleport(Transform3D(Basis(), SPAWN))
	player.look_at_point(Vector3(1.0, 1.6, -14.0), 0.01)
	var args := OS.get_cmdline_user_args()
	if args.has("--label-audit"):
		add_child(load("res://scripts/debug/label_audit.gd").new())
		return
	var debug := {"--level-shots": "level_shots", "--walk-test": "level_walk", "--level-plan": "level_plan"}
	var flag: String = debug.keys().filter(func(k): return args.has(k)).front() if debug.keys().any(func(k): return args.has(k)) else ""
	if flag != "":
		var dbg: Node = load("res://scripts/debug/%s.gd" % debug[flag]).new()
		dbg.level = self
		add_child(dbg)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# ------------------------------------------------------------------ materials

func _materials() -> void:
	_mat.floor = _tiled("floor_terrazzo", 1.6, 0.16)       # one texture = 2 x 2 tiles of 80 cm
	_mat.ceiling = _tiled("ceiling_tile", 1.2, 0.9)        # 2 x 2 tiles of 60 cm
	_mat.wall = _tiled("wall_panel", 2.4, 0.5)             # two 1.2 m panels
	_mat.beam = Mats.std(Color(0.8, 0.8, 0.78), 0.8)
	_mat.frame = Mats.std(Color(0.62, 0.63, 0.64), 0.35, 0.6)
	_mat.belt = Mats.std(Color(0.08, 0.14, 0.38), 0.6)
	_mat.glass = Mats.get_mat("glass")
	var lit := StandardMaterial3D.new()      # frosted backlit glazing (windows onto the lit apron / light wells)
	lit.albedo_color = Color(0.78, 0.82, 0.86)
	lit.emission_enabled = true
	lit.emission = Color(0.55, 0.62, 0.7)
	lit.emission_energy_multiplier = 0.35
	lit.roughness = 0.15
	_mat.window = lit


## World-space triplanar material from a tileable texture covering `metres` per repeat.
func _tiled(tex: String, metres: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + tex + ".png")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / metres
	m.roughness = roughness
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


# ------------------------------------------------------------------ props

## Places a Tripo prop (front = +Z when rot is 0, pivot = floor centre) and gives it a box collider from its bounds.
func _prop(zone: String, id: String, pos: Vector3, rot_deg := 0.0, collide := true) -> Node3D:
	return TripoProps.spawn(self, zone, id, pos, deg_to_rad(rot_deg), collide)


## A prop whose back stands against a wall: `surface` is the point on the wall face at floor (or `y`) level,
## `facing` the direction its front looks (deg about Y, 0 = +Z).
func _mount(zone: String, id: String, surface: Vector3, facing: float, collide := false) -> Node3D:
	var n := _prop(zone, id, surface, facing, false)
	var bb := TripoProps.bounds(n)
	n.position += n.basis.z * (-bb.position.z + 0.005)
	if collide:
		Geo.blocker(self, n.to_global(bb.get_center()), bb.size, n.rotation.y)
	return n


## A flat fixture modeled face-up, turned over onto the ceiling at height `ceiling_y`, its face `drop` below it.
func _ceiling_prop(id: String, pos: Vector3, ceiling_y: float, rot_deg := 0.0, drop := 0.01) -> Node3D:
	var n := _prop("common", id, Vector3(pos.x, 0, pos.z), rot_deg, false)
	n.rotate_object_local(Vector3.RIGHT, PI)
	n.position.y = ceiling_y + TripoProps.bounds(n).size.y - drop
	return n


func _metal_detector(pos: Vector3) -> void:
	var n := _prop("security", "SEC_MetalDetector", pos, 0.0, false)
	var bb := TripoProps.bounds(n)
	for side in [-1.0, 1.0]:
		# walk-through: only the two pillars block
		Geo.blocker(self, pos + Vector3(side * (bb.size.x * 0.5 - 0.07), 1.0, 0), Vector3(0.14, 2.0, bb.size.z))


## Retractable belt between two stanchion posts.
func _belt(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := Vector2(d.x, d.z).length() - 0.1
	Geo.box(self, (a + b) * 0.5 + Vector3(0, 0.9, 0), Vector3(0.012, 0.05, length), _mat.belt, true, atan2(d.x, d.z))


## A queue line of stanchions joined by belts along z at `x`.
func _stanchions(x: float, zs: Array) -> void:
	var posts: Array[Vector3] = []
	for z: float in zs:
		var p := Vector3(x, 0, z)
		_prop("security", "SEC_Stanchion", p, 0.0, false)
		Geo.blocker(self, p + Vector3(0, 0.5, 0), Vector3(0.3, 1.0, 0.3))
		posts.append(p)
	for k in posts.size() - 1:
		_belt(posts[k], posts[k + 1])


# ------------------------------------------------------------------ architecture

func _shell() -> void:
	Geo.box(self, Vector3(10.0, -0.1, -21.0), Vector3(36.0, 0.2, 52.0), _mat.floor)
	# ceilings: hall A + concourse share one slab, hall B and the connector are lower
	Geo.box(self, Vector3(3.0, HALL_A_H + 0.1, -21.5), Vector3(18.0, 0.2, 49.0), _mat.ceiling, false)
	Geo.box(self, Vector3(21.5, HALL_B_H + 0.1, -16.0), Vector3(11.0, 0.2, 40.0), _mat.ceiling, false)
	Geo.box(self, Vector3(14.0, 2.9, 1.4), Vector3(4.0, 0.2, 2.4), _mat.ceiling, false)
	var w: StandardMaterial3D = _mat.wall
	var ha := HALL_A_H + 0.2
	# hall A: x -3.6..12, z 3..-18 (west wall ends at -11.4 where the concourse opens)
	Geo.wall(self, Vector2(-3.6, 3), Vector2(12, 3), ha, w, 0.3)
	Geo.wall(self, Vector2(-3.6, 3), Vector2(-3.6, -11.4), ha, w, 0.3)
	Geo.wall(self, Vector2(-3.6, -11.4), Vector2(-6.0, -11.4), ha, w, 0.3)
	Geo.wall(self, Vector2(12, 3), Vector2(12, -18), ha, w, 0.3, [[0.4, 2.8, 2.8]])
	# "Security Check" partition across the east part; behind it the back of the hall up to the windows
	Geo.wall(self, Vector2(7.1, -9), Vector2(12, -9), ha, w, 0.3)
	Geo.wall(self, Vector2(3.4, -18), Vector2(12, -18), ha, w, 0.3)
	_window(Vector3(4.45, 0, -17.85), 0.0, 1.5)
	_window(Vector3(8.85, 0, -17.85), 0.0, 5.5)
	Geo.box(self, Vector3(5.65, ha * 0.5, -17.5), Vector3(0.7, ha, 0.7), w)   # column between the windows
	# connector: x 12..16, z 0.2..2.6
	Geo.wall(self, Vector2(12, 0.2), Vector2(16, 0.2), 3.0, w, 0.2)
	Geo.wall(self, Vector2(12, 2.6), Vector2(16, 2.6), 3.0, w, 0.2)
	# concourse: x -6..3.4, z -11.4..-46; glass screen on the east side, gate windows at the north end
	Geo.wall(self, Vector2(-6, -11.4), Vector2(-6, -46), ha, w, 0.3)
	Geo.wall(self, Vector2(-6, -46), Vector2(3.4, -46), ha, w, 0.3)
	_window(Vector3(-1.3, 0, -45.85), 0.0, 8.0)
	Geo.wall(self, Vector2(4.8, -18), Vector2(4.8, -46), ha, w, 0.3)
	Geo.wall(self, Vector2(3.4, -46), Vector2(4.8, -46), ha, w, 0.3)
	_glass_screen(3.4, -18.0, -46.0, HALL_A_H)
	# hall B: x 16..27, z 4..-36; the connector enters the west wall near the south end
	Geo.wall(self, Vector2(16, 4), Vector2(16, -36), HALL_B_H + 0.2, w, 0.3, [[1.4, 3.8, 2.8]])
	Geo.wall(self, Vector2(16, 4), Vector2(27, 4), HALL_B_H + 0.2, w, 0.3)
	Geo.wall(self, Vector2(27, 4), Vector2(27, -36), HALL_B_H + 0.2, w, 0.3)
	Geo.wall(self, Vector2(16, -36), Vector2(27, -36), HALL_B_H + 0.2, w, 0.3)
	# skirting where the floor meets the main walls
	for s in [[Vector3(4.2, 0.06, 2.84), Vector3(15.6, 0.12, 0.02)], [Vector3(-3.44, 0.06, -4.2), Vector3(0.02, 0.12, 14.4)],
			[Vector3(-5.84, 0.06, -28.7), Vector3(0.02, 0.12, 34.6)], [Vector3(26.84, 0.06, -16), Vector3(0.02, 0.12, 40)],
			[Vector3(16.16, 0.06, -17.6), Vector3(0.02, 0.12, 36.8)]]:
		Geo.box(self, s[0], s[1], _mat.frame, false)


## Backlit window band on a wall face (`at` = floor point on the face): glowing glazing between mullions.
func _window(at: Vector3, facing: float, width: float) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = at
	root.rotation.y = deg_to_rad(facing)
	Geo.box(root, Vector3(0, 1.95, 0.01), Vector3(width, 3.1, 0.02), _mat.window, false)
	var n := maxi(1, int(round(width / 1.25)))
	for i in n + 1:
		Geo.box(root, Vector3(-width * 0.5 + width * i / n, 1.95, 0.04), Vector3(0.07, 3.1, 0.06), _mat.frame, false)
	for y in [0.4, 3.5]:
		Geo.box(root, Vector3(0, y, 0.04), Vector3(width + 0.07, 0.08, 0.06), _mat.frame, false)


## Floor-to-ceiling glazed screen along x = `x` from z0 to z1: aluminium mullions every 1.5 m, glass panes.
func _glass_screen(x: float, z0: float, z1: float, h: float) -> void:
	var n := int(round(absf(z1 - z0) / 1.5))
	var step := (z1 - z0) / n
	for i in n + 1:
		Geo.box(self, Vector3(x, h * 0.5, z0 + step * i), Vector3(0.08, h, 0.08), _mat.frame)
	for i in n:
		Geo.box(self, Vector3(x, h * 0.5, z0 + step * (i + 0.5)), Vector3(0.02, h, absf(step) - 0.08), _mat.glass)
	Geo.box(self, Vector3(x, 0.05, (z0 + z1) * 0.5), Vector3(0.12, 0.1, absf(z1 - z0)), _mat.frame, false)


func _hall_a() -> void:
	# coffered ceiling: deep beams on a 3 m grid, a troffer in every coffer (see _lights)
	for z in [0.0, -3.0, -6.0, -9.0, -12.0, -15.0]:
		Geo.box(self, Vector3(4.2, HALL_A_H - 0.225, z), Vector3(15.6, 0.45, 0.4), _mat.beam, false)
	for x in [-0.6, 2.4, 5.4, 8.4]:
		Geo.box(self, Vector3(x, HALL_A_H - 0.225, -7.5), Vector3(0.4, 0.45, 21.0), _mat.beam, false)
	for i in LANES.size():
		var x0: float = LANES[i][0]
		var zx: float = LANES[i][1]
		_prop("security", "SEC_XrayScanner", Vector3(x0, 0, zx))
		_prop("security", "SEC_RollerConveyor", Vector3(x0, 0, zx + 2.15))
		_prop("security", "SEC_RollerConveyor", Vector3(x0, 0, zx - 2.15))
		_metal_detector(Vector3(x0 - 1.15, 0, zx))
		_prop("security", "SEC_OperatorDesk", Vector3(x0 + 1.35, 0, zx - 0.2), 90.0)
		_prop("security", "SEC_OfficeChair", Vector3(x0 + 2.0, 0, zx - 0.2), -90.0)
		# queue line beside the metal detector approach (sketch: one belt line per lane)
		_stanchions(x0 - 0.65 if i == 0 else x0 - 2.15, [zx + 1.2, zx + 2.4, zx + 3.6])
		_hanging_sign(Vector3(x0 - 0.4, HALL_A_H, zx - 1.6), 0.0, "수하물 검색 %d\nBAGGAGE INSPECTION %d" % [i + 1, i + 1])
	# repacking benches along the west wall and in front of the partition
	for z in [-5.9, -7.75, -9.6]:
		_prop("security", "SEC_InspectionTable", Vector3(-3.1, 0, z), 90.0)
	_prop("security", "SEC_InspectionTable", Vector3(8.6, 0, -8.5))
	_wall_sign(Vector3(-3.45, 3.0, -8.7), 90.0, "탑승구 →\nTO GATE", Vector2(1.5, 0.6))
	_wall_sign(Vector3(8.1, 2.9, -8.85), 0.0, "보안검색\nSECURITY CHECK", Vector2(1.5, 0.5))
	_wall_sign(Vector3(11.85, 2.5, -1.6), -90.0, "수하물 수취\nBAGGAGE CLAIM  →", Vector2(1.8, 0.7))


func _concourse() -> void:
	# moving walkway along the glass screen: entry unit, four straight sections, exit unit (turned round)
	var x := 1.9
	_walkway("SEC_WalkwayEnd", Vector3(x, 0, -17.5), 0.0)
	for z in [-21.0, -25.0, -29.0, -33.0]:
		_walkway("SEC_WalkwayMid", Vector3(x, 0, z), 0.0)
	_walkway("SEC_WalkwayEnd", Vector3(x, 0, -36.5), 180.0)
	# gate lounge at the far end
	for z in [-41.5, -44.0]:
		for sx in [-4.4, -2.4]:
			_prop("baggage", "BAG_RowSeating", Vector3(sx, 0, z), 0.0)
	_hanging_sign(Vector3(-1.8, HALL_A_H, -39.0), 0.0, "탑승구 1 – 12\nGATES 1 – 12")


## Walkway unit: the tread is walkable (6 cm, the capsule rides over it), only the balustrades block.
func _walkway(id: String, pos: Vector3, rot_deg: float) -> void:
	var n := _prop("walkway", id, pos, rot_deg, false)
	var bb := TripoProps.bounds(n)
	for side in [-1.0, 1.0]:
		Geo.blocker(self, pos + Vector3(side * (bb.size.x * 0.5 - 0.07), 0.55, 0), Vector3(0.14, 1.1, bb.size.z))


func _hall_b() -> void:
	# beams across the hall every 6 m, pilasters on the east wall under them
	for z in [-1.0, -7.0, -13.0, -19.0, -25.0, -31.0]:
		Geo.box(self, Vector3(21.5, HALL_B_H - 0.175, z), Vector3(11.0, 0.35, 0.5), _mat.beam, false)
		Geo.box(self, Vector3(26.78, HALL_B_H * 0.5, z), Vector3(0.14, HALL_B_H, 0.5), _mat.wall)
	for i in CAROUSELS.size():
		var cz: float = CAROUSELS[i]
		_prop("baggage", "BAG_Carousel2", Vector3(CAROUSEL_X, 0, cz), 90.0)
		_number_pillar(Vector3(18.3, 0, cz), i + 1)    # stands on the island, as in the sketch
		_mount("baggage", "BAG_FeedPortal", Vector3(16.15, 0.35, cz - 1.4), 90.0)
	_hanging_sign(Vector3(18.3, HALL_B_H, -9.0), 90.0, "수하물 수취\nBaggage Claim")
	_hanging_sign(Vector3(18.3, HALL_B_H, -16.4), 90.0, "수하물 수취\nBaggage Claim")
	# west wall: staff doors and a roller shutter between the carousels
	for dz in [-2.2, -10.8, -27.0]:
		_door(Vector3(16.15, 0, dz), 90.0)
	_mount("baggage", "BAG_RollerShutter", Vector3(16.15, 0, -18.0), 90.0)
	_exit_door(Vector3(25.0, 0, -35.85))
	# waiting area along the east wall
	for z in [-3.1, -5.0, -9.1, -11.0, -15.1, -17.0, -21.1, -23.0]:
		_prop("baggage", "BAG_RowSeating", Vector3(26.5, 0, z), -90.0)
	for z in [-6.4, -12.4, -18.4, -24.4]:
		_prop("baggage", "BAG_TrashBin", Vector3(26.62, 0, z))
	_icon_sign(Vector3(26.85, 1.9, -7.9), -90.0)


func _lights() -> void:
	var a := _zone("security", "보안검색")
	for ix in 5:
		for iz in 7:
			var x: float = [-2.1, 0.9, 3.9, 6.9, 10.2][ix]
			var z: float = [1.5, -1.5, -4.5, -7.5, -10.5, -13.5, -16.5][iz]
			if x > 7.0 and z < -9.0:
				continue          # behind the partition
			_fixture(a, "CMN_TrofferLight", Vector3(x, 0, z), HALL_A_H, 0.0, Vector2(1.1, 0.5), (ix + iz) % 2 == 0)
	a.add_hum(Vector3(3, 3.8, -7.0), -22.0)
	var c := _zone("corridor", "탑승구 통로")
	for z in [-20.0, -24.0, -28.0, -32.0, -36.0, -40.0, -44.0]:
		_fixture(c, "CMN_TrofferLight", Vector3(-1.5, 0, z), HALL_A_H, 90.0, Vector2(1.1, 0.5), true)
		_fixture(c, "CMN_TrofferLight", Vector3(-4.5, 0, z), HALL_A_H, 90.0, Vector2(1.1, 0.5), int(z) % 8 == 0)
	_fixture(c, "CMN_TrofferLight", Vector3(14.0, 0, 1.4), 2.8, 0.0, Vector2(1.1, 0.5), true, 0.9, 6.0)
	var b := _zone("baggage", "수하물 수취")
	for z in [2.0, -4.0, -10.0, -16.0, -22.0, -28.0, -33.6]:
		for x in [18.4, 24.8]:
			_fixture(b, "CMN_LinearLight", Vector3(x, 0, z), HALL_B_H, 90.0, Vector2(1.5, 0.14), true, 1.1, 9.0)
		_ceiling_prop("CMN_ACCassette", Vector3(22.4, 0, z), HALL_B_H, 0.0, 0.045)
	b.add_hum(Vector3(21.5, 3.3, -16.0), -22.0)
	for z: LightZone in zones.values():
		z.set_on(true, true)
	# box-projected interior probes: brushed steel and the glossy floor reflect the lit halls, not the night sky
	for p in [[Vector3(4.2, 2.05, -7.5), Vector3(15.6, 4.1, 21.0)], [Vector3(-1.3, 2.05, -32.0), Vector3(9.4, 4.1, 28.0)],
			[Vector3(21.5, 1.8, -16.0), Vector3(11.0, 3.6, 40.0)], [Vector3(14.0, 1.4, 1.4), Vector3(4.0, 2.8, 2.4)]]:
		var probe := ReflectionProbe.new()
		probe.size = p[1]
		probe.box_projection = true
		probe.interior = true
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		add_child(probe)
		probe.position = p[0]


func _zone(zname: String, dname: String) -> LightZone:
	var z := LightZone.new()
	z.name = "Zone_" + zname
	add_child(z)
	z.setup(zname, dname)
	zones[zname] = z
	return z


## Tripo ceiling fixture with the zone's glowing diffuser just under its face; `lit` adds the area light and
## the bounce omni the same way LightZone.add_panel does.
func _fixture(z: LightZone, id: String, pos: Vector3, ceiling_y: float, rot_deg: float, diffuser: Vector2,
		lit: bool, energy := 1.0, light_range := 9.0) -> void:
	_ceiling_prop(id, pos, ceiling_y, rot_deg)
	var size := diffuser.rotated(deg_to_rad(rot_deg)).abs()
	var mi := Geo.box(z, Vector3(pos.x, ceiling_y - 0.012, pos.z), Vector3(size.x, 0.004, size.y), z.panel_mat, false)
	z.panels.append(mi)
	if not lit:
		return
	var col := Color(0.88, 0.93, 1.0)
	z.add_light(Geo.area_light(z, Vector3(pos.x, ceiling_y - 0.05, pos.z), size, col, energy * LightZone.AREA_GAIN, light_range))
	var share := LightZone.GI_DIRECT if Atmosphere.gi_enabled else LightZone.NO_GI_DIRECT
	var gi := Geo.omni(z, Vector3(pos.x, ceiling_y - 0.6, pos.z), col, energy * share, light_range)
	gi.light_indirect_energy = 1.0 / share
	gi.light_specular = 0.0
	gi.light_volumetric_fog_energy = 0.0
	z.add_light(gi)


# ------------------------------------------------------------------ signage (Tripo sign bodies, text on top)

## Ceiling-hung lightbox at `top` (point on the ceiling above its centre), text on both faces.
func _hanging_sign(top: Vector3, rot_deg: float, text: String, width := 2.8) -> void:
	var root := Node3D.new()
	add_child(root)
	root.rotation.y = deg_to_rad(rot_deg)
	var n := TripoProps.spawn(root, "common", "CMN_HangingSign", Vector3.ZERO, 0.0, false, null, Vector3(width, 0, 0))
	var bb := TripoProps.bounds(n)
	root.position = Vector3(top.x, top.y - bb.size.y, top.z)
	# text on an unscaled sibling so the stretched body does not stretch the letters
	_sign_faces(root, Vector3(0, 0.25, bb.end.z), Vector2(width, 0.5), text, true)


## Text (and a luggage pictogram) on a sign face: `face` = centre of the front face in the sign's space.
func _sign_faces(sign: Node3D, face: Vector3, size: Vector2, text: String, both_sides: bool) -> void:
	for side in ([1.0, -1.0] if both_sides else [1.0]):
		var f := Node3D.new()
		sign.add_child(f)
		f.rotation.y = 0.0 if side > 0 else PI
		var at := Vector3(face.x, face.y, face.z + 0.004)
		var icon := _icon(f, "icon_luggage", at + Vector3(-size.x * 0.5 + size.y * 0.55, 0, 0), size.y * 0.62)
		icon.modulate = Color(0.96, 0.96, 0.92)
		var l := Geo.label(f, text, at + Vector3(size.y * 0.45, 0, 0), 0.0, 64, Color(0.96, 0.96, 0.92), 0.0042)
		Geo.fit(l, size.x - size.y * 1.4, size.y - 0.1)
		l.set_meta("no_fit", true)


## Flat wall lightbox (the hanging sign body without its rods), `surface` = wall point at its centre height.
func _wall_sign(surface: Vector3, facing: float, text: String, size: Vector2) -> void:
	var root := _sign_body(surface, facing, size, false)
	var l := Geo.label(root, text, Vector3(0, 0, root.get_meta("face_z") + 0.004), 0.0, 64, Color(0.96, 0.96, 0.92), 0.005)
	Geo.fit(l, size.x - 0.2, size.y - 0.12)
	l.set_meta("no_fit", true)


## Vertical wall lightbox with a luggage pictogram over an arrow (baggage hall east wall).
func _icon_sign(surface: Vector3, facing: float) -> void:
	var root := _sign_body(surface, facing, Vector2(0.6, 1.5), true)
	var z: float = root.get_meta("face_z") + 0.004
	_icon(root, "icon_luggage", Vector3(0, 0.3, z), 0.36).modulate = Color(0.96, 0.96, 0.92)
	_icon(root, "icon_arrow", Vector3(0, -0.32, z), 0.36).modulate = Color(0.96, 0.96, 0.92)


## CMN_WallSign scaled to `size` (w x h, or h x w when vertical) on a wall; returns an unscaled root at the wall
## point, its +Z out of the wall (meta "face_z" = distance of the sign face from the wall).
func _sign_body(surface: Vector3, facing: float, size: Vector2, vertical: bool) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.position = surface
	root.rotation.y = deg_to_rad(facing)
	var n := TripoProps.spawn(root, "common", "CMN_WallSign")
	var bb := TripoProps.bounds(n)
	var long := size.y if vertical else size.x
	var short := size.x if vertical else size.y
	n.scale = Vector3(long / bb.size.x, short / bb.size.y, 1.0)
	if vertical:
		n.rotation.z = PI / 2
	# body centred on the root, back against the wall
	n.position = (n.basis * -bb.get_center()) + Vector3(0, 0, bb.size.z * 0.5 + 0.005)
	root.set_meta("face_z", bb.size.z + 0.005)
	return root


func _icon(parent: Node3D, tex: String, pos: Vector3, height: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = load(TEX + tex + ".png")
	s.pixel_size = height / s.texture.get_height()
	s.shaded = false
	s.double_sided = false
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(s)
	s.position = pos
	return s


## Carousel number tower at the wall end of the belt: number, pictogram and caption on the face toward the
## arrivals end (+Z), the pictogram alone on the side facing the hall.
func _number_pillar(pos: Vector3, n: int) -> void:
	var p := _prop("baggage", "BAG_NumberPillar", pos, 0.0)
	var bb := TripoProps.bounds(p)
	var ink := Color(0.12, 0.13, 0.16)
	var front := Node3D.new()
	p.add_child(front)
	front.position = Vector3(0, 0, bb.end.z + 0.003)
	Geo.fit(Geo.label(front, str(n), Vector3(0, 2.05, 0), 0.0, 220, ink, 0.004, false, "print"), bb.size.x - 0.12, 0.85).set_meta("no_fit", true)
	_icon(front, "icon_luggage", Vector3(0, 1.45, 0), 0.26).modulate = ink
	var cap := Geo.fit(Geo.label(front, "수하물 수취\nBaggage Claim", Vector3(0, 1.08, 0), 0.0, 40, ink, 0.0035, false, "print"), bb.size.x - 0.12, 0.32)
	cap.set_meta("no_fit", true)
	var side := Node3D.new()
	p.add_child(side)
	side.position = Vector3(bb.end.x + 0.003, 0, 0)
	side.rotation.y = PI / 2
	_icon(side, "icon_luggage", Vector3(0, 1.45, 0), 0.26).modulate = ink


## Staff door on a wall (not openable), its sign plate printed.
func _door(surface: Vector3, facing: float) -> void:
	var d := _mount("common", "CMN_Door", surface, facing)
	var bb := TripoProps.bounds(d)
	var l := Geo.label(d, "직원 전용  STAFF ONLY", Vector3(0, bb.size.y - 0.16, bb.end.z - 0.075), 0.0, 40, Color(0.95, 0.95, 0.9), 0.003)
	Geo.fit(l, 0.62, 0.14)
	l.set_meta("no_fit", true)


## Double exit door on the north wall of hall B with the exit sign lit.
func _exit_door(surface: Vector3) -> void:
	var d := _mount("common", "CMN_DoubleDoor", surface, 0.0)
	var bb := TripoProps.bounds(d)
	var l := Geo.label(d, "출구  EXIT", Vector3(0, bb.size.y - 0.2, bb.end.z + 0.004), 0.0, 48, Color(1, 1, 1), 0.003)
	Geo.fit(l, 0.44, 0.15)
	l.set_meta("no_fit", true)
