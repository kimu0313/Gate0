class_name ServiceHall
extends Node3D
## The service corridors round the security office (user: "보안실을 나서면 상가 1층마냥 문이 많은 복도, 1줄로 쭉 된
## 복도가 아니라 약간 미로처럼", with a dark office-corridor reference; this replaced the long straight locker
## corridor): narrow corridors that turn and branch with doors all down them — numbered rooms, a store, the plant
## room — under a dropped ceiling of square lights in a grey-green haze; dark wood doors, chairs along a wall, framed
## pictures; dead ends (one under an EXIT sign that is no way out). The way down to the lounge (1F; these corridors and
## the office are on 4F): the lift at the end of the last long run (Lift; the steel double doors under an EXIT sign that
## stood there went — user: "출구 문을 엘리베이터로 바꿔줘"), or the emergency stairs from the run's north end
## (StairCore). The walls are the user's concrete-over-blue-band tile (shaders/corridor_wall.gdshader). Nothing happens in here (the red ball and the dark figure that did were removed — user:
## "복도에서 공 나오고 … 이런거 다 빼, 완전히 다른 게임 로직을 넣을거야").
##
## Built far below the terminal (ORIGIN) like the jet bridge, and laid out in the terminal's own coordinates round
## the office's footprint (local = Terminal coordinates; nothing of the office itself is built here, only its outside
## faces): the office's big windows look out on it (Terminal.sec_view) and from here you look in at the office through
## the same windows (office_panes, Terminal.sec_inview). The story joins it to the office's west door — the key card
## door (entry_frame; it and the 관계자 외 출입금지 door swapped places, and that one was then removed) —
## with a PortalView; the lift and the stair lobby are built twice and swap you over while shut.
##
## The way through: out of the office's west door into W, north up W past the office's windows, west along N past the
## north arm's windows, then the T with V — north the stairs, south the long run to the lift. Off the way: W south to
## S (east along the rooms south of the office, round into E along the office's east wall, a dead
## end north), S2 south off S, B west off W turning south into B2 under that EXIT sign.

const ORIGIN := Vector3(-160, -320, 0)
const H := 3.25               # the dropped ceiling (over the office windows' heads, 3.05)
const T := 0.2                # its own walls (the office's outside faces are the office's 0.3)
const FAR_W := 1.7            # double_door's width (the lounge's 2F staff doors and the story's doors)
const FAR_H := 2.3
const LIGHT := Color(0.76, 0.92, 0.84)
## The corridors, in the terminal's coordinates (x, z): the office's outside faces are x -12.25 (east), z -14.85
## (south), x -22.55 (the south arm's west), z -25.85 (the north arm's south), x -30.55 (its west end).
const HALLS := {
	"e": Rect2(-12.25, -21.5, 2.2, 10.85),
	"s": Rect2(-22.55, -12.85, 10.3, 2.2),
	"w": Rect2(-24.75, -25.85, 2.2, 15.2),
	"n": Rect2(-35.0, -25.85, 10.25, 2.2),
	"v": Rect2(-37.2, -29.5, 2.2, 23.5),
	"s2": Rect2(-20.9, -10.65, 2.2, 6.15),
	"b": Rect2(-30.5, -20.5, 5.75, 2.2),
	"b2": Rect2(-32.7, -20.5, 2.2, 8.0),
}
const ENTRY := Vector3(-22.4, 0, Terminal.SEC_ENTRY_Z)   # the office's west door (the key card door), through = -X
const FAR := Vector3(-36.1, 0, -6.0)          # the lift's doorway in V's south end wall (its corridor face; the car lies +Z)
## Square fittings down the middle of every corridor: [x, z, lit].
const FITTINGS := [
	[-11.15, -19.8, true], [-11.15, -16.0, true], [-11.15, -11.75, true],
	[-15.0, -11.75, true], [-19.8, -11.75, true], [-23.65, -11.75, true],
	[-23.65, -15.9, true], [-23.65, -20.0, true], [-23.65, -24.75, true],
	[-28.4, -24.75, true], [-32.2, -24.75, true],
	[-36.1, -28.2, true], [-36.1, -24.75, true], [-36.1, -20.6, true], [-36.1, -16.4, false], [-36.1, -12.2, true],
	[-36.1, -8.4, true],
	[-19.8, -7.4, true], [-27.6, -19.4, true], [-31.6, -19.4, true], [-31.6, -14.4, false],
]

var zone: LightZone
var entry: Dictionary         # the door you come in by (Terminal.steel_door: {root, leaf, block, use}), open out of it
var entry_closet: Array[MeshInstance3D] = []   # the dark box behind it (in the office's footprint): a view of the office
var lift_car: Dictionary      # Lift.car at the far end (4F); Terminal links it to the lounge's (1F)
var stair_lobby: Dictionary   # the stairwell's copy of the stair lobby (StairCore.lobby), at its foot
var stair_door: Dictionary    # {} — the stairs are open to the corridor (the steel door that stood there was removed)
var side_doors: Array[Dictionary] = []          # every locked door (they rattle)
var doors_by := {}            # plate -> door
var office_panes: Array[MeshInstance3D] = []    # the maze's side of the office's big windows (Terminal.sec_inview)
var wall_m: Material
var _frame_m: Material


func build() -> void:
	name = "ServiceHall"
	position = ORIGIN
	# the walls: the user's tile (concrete panels over a pale blue band with a dark foot), world space, one tile up
	# the wall's height (user: "복도 벽 텍스처 이걸로 해줘"; the floor and ceiling as they were)
	wall_m = Mats.shader_mat("res://shaders/corridor_wall.gdshader", {
		"albedo_tex": load("res://assets/textures/level/wall_corridor_concrete.png"), "base_height": ORIGIN.y,
		"wall_h": H, "tile_w": H})
	_frame_m = Mats.std(Color(0.07, 0.065, 0.06), 0.45, 0.2)
	var floor_m := Mats.shader_mat("res://shaders/floor_tile.gdshader", {
		"color_a": Color(0.3, 0.32, 0.31), "color_b": Color(0.27, 0.29, 0.28), "grout_color": Color(0.19, 0.2, 0.19),
		"tile_size": 0.6, "roughness_base": 0.08, "roughness_var": 0.28})
	var ceil_m := Mats.get_mat("ceiling_corridor_tile")       # the user's tile photo (was a plain grey grid)
	# the floor and the dropped ceiling over the whole maze (and over the rooms between, shut away behind their doors)
	# (not over the stair hall at W's south end, x -28.8..-21.8 z -10.45..-5.8: it has its own floors and ceiling)
	for r: Array in [[Vector3(-23.625, 0, -20.125), Vector2(27.75, 19.35)], [Vector3(-33.15, 0, -8.125), Vector2(8.7, 4.65)],
			[Vector3(-15.775, 0, -8.125), Vector2(12.05, 4.65)], [Vector3(-19.8, 0, -5.0), Vector2(2.8, 1.6)]]:
		Geo.box(self, r[0] + Vector3(0, -0.05, 0), Vector3(r[1].x, 0.1, r[1].y), floor_m)
		Geo.box(self, r[0] + Vector3(0, H + 0.1, 0), Vector3(r[1].x, 0.2, r[1].y), ceil_m, false)
	_build_walls()
	ArchiveRoom.build(self)        # the records room behind the door farthest from the lift (E's end)
	_build_entry()
	_build_lift_end()
	_build_office_side()
	_build_lights()
	_build_stairs()                # (after the lights: its lamps are on the corridors' zone)
	_build_details()
	_build_reverb()


## Inside the maze (or in the doorways at its ends, the lift's car, the stairwell and its lobby)?
func contains(p: Vector3) -> bool:
	var l := to_local(p)
	if l.x > -37.8 and l.x < -9.4 and l.z > -30.0 and l.z < -2.2 and absf(l.y) < 6.0:
		return true
	if ArchiveRoom.contains_local(l):
		return true
	return StairCore.contains_hall(l)


## Standing where the office's big windows can be seen (W, N, B and the corners into them): the view in through them
## (Terminal.sec_inview) is live only here.
func sees_office(p: Vector3) -> bool:
	var l := to_local(p)
	return l.x > -35.0 and l.x < -22.4 and l.z > -26.0 and l.z < -10.6 and absf(l.y) < 6.0


## The door frame the story joins with a portal, global: on (-X) out of the office's west door, the key card door.
func entry_frame() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, -PI / 2), to_global(ENTRY))


# --------------------------------------------------------------------------------------------
## Every wall, by its corridor face: the office's outside faces (0.3, holed for its doors and big windows) and the
## maze's own (T), with the locked doors in them.
func _build_walls() -> void:
	var big := 0.3
	var hw := Terminal.SEC_VIEW_SIZE.x * 0.5
	var head := Terminal.SEC_VIEW_Y + Terminal.SEC_VIEW_SIZE.y * 0.5
	var sill := Terminal.SEC_VIEW_Y - Terminal.SEC_VIEW_SIZE.y * 0.5
	# E, out of the passage door: the office's east wall (and the rooms' south of it), a dead end north
	_wall_z(-12.25, -21.7, -12.85, -1.0, [], [], big)      # the office's east wall: no door (removed — user)
	_wall_z(-10.05, -21.7, -10.45, 1.0, [[-19.9, "관리사무소"], [-16.0, "회의실"], [-12.6, "전기실"]])
	_wall_x(-21.5, -12.55, -9.85, -1.0, [[ArchiveRoom.DOOR_X, "자료실"]])   # the records room (ArchiveRoom)
	# S, west along the rooms south of the office; S2 off it
	# (W's south end, x -24.75..-22.55, is open onto the stair hall — StairCore; its door 103 went with it)
	_wall_x(-10.65, -24.95, -9.85, 1.0, [[-12.9, "101"], [-16.2, "102"]], [[-20.9, -18.7, H], [-24.75, -22.55, H]])
	_wall_x(-12.85, -22.55, -12.55, -1.0, [[-21.2, "110"], [-16.8, "창고"]])
	# W, north past the office's west door and its windows; B off it
	var cuts_w := []
	for z: float in Terminal.SEC_VIEW_W:
		cuts_w.append([z - hw, z + hw, head, sill])
	_wall_z(-22.55, -25.85, -12.85, 1.0, [], cuts_w + [[ENTRY.z - 0.55, ENTRY.z + 0.55, 2.2]], big)   # the way in
	_wall_z(-24.75, -23.65, -10.45, -1.0, [[-22.1, "104"], [-15.0, "105"], [-11.75, "106"]], [[-20.5, -18.3, H]])
	# N, west along the north arm's windows
	var cuts_n := []
	for x: float in Terminal.SEC_VIEW_N:
		cuts_n.append([x - hw, x + hw, head, sill])
	_wall_x(-25.85, -35.0, -22.25, -1.0, [[-33.2, "207"]], cuts_n, big)
	_wall_x(-23.65, -35.0, -24.75, 1.0, [[-27.2, "201"], [-30.6, "202"], [-33.4, "203"]])
	# V: north a dead end, south the long run to the far doors
	_wall_z(-37.2, -29.7, -5.8, -1.0, [[-27.0, "방재센터"], [-18.0, "205"], [-11.5, "206"]])
	_wall_z(-35.0, -29.7, -25.85, 1.0)
	_wall_z(-35.0, -23.65, -5.8, 1.0, [[-21.8, "204"], [-15.5, "미화원 대기실"], [-9.6, "탈의실"]])
	# V's north end walled up again (the stairs moved to W's south end — user: "원래 위치는 그냥 벽으로 막아주고")
	_wall_x(-29.5, -37.4, -34.8, -1.0)
	_wall_x(-6.0, -37.4, -34.8, 1.0, [], [[FAR.x - Lift.OPEN_W * 0.5, FAR.x + Lift.OPEN_W * 0.5, Lift.OPEN_H]])
	# S2
	_wall_z(-20.9, -10.45, -4.3, -1.0, [[-8.0, "107"]])
	_wall_z(-18.7, -10.45, -4.3, 1.0, [[-6.8, "108"]])
	_wall_x(-4.5, -21.1, -18.5, 1.0, [[-19.8, "109"]])
	# B and B2, to the door under the EXIT sign
	_wall_x(-20.5, -32.9, -24.75, -1.0, [[-28.0, "111"]])
	_wall_x(-18.3, -30.5, -24.75, 1.0, [[-27.6, "112"]])
	_wall_z(-32.7, -20.7, -12.3, -1.0, [[-16.0, "113"]])
	_wall_z(-30.5, -18.3, -12.3, 1.0, [[-14.6, "114"]])
	_wall_x(-12.5, -32.9, -30.3, 1.0, [[-31.6, "출구"]])


## A wall along Z with its corridor face at x = `x` from z0 to z1 (z0 < z1), its body `t` thick on the `side` (+1:
## toward +X); `doors` = [[z, plate], …] (locked OfficeKit doors, plate on the corridor side) and `cuts` = more
## openings, [from z, to z, head(, sill)].
func _wall_z(x: float, z0: float, z1: float, side: float, doors := [], cuts := [], t := T) -> void:
	var cx := x + side * t * 0.5
	var offs := []
	for c: Array in cuts:
		offs.append([c[0] - z0, c[1] - z0, c[2], c[3] if c.size() > 3 else 0.0])
	for dd: Array in doors:
		var z: float = dd[0]
		offs.append([z - 0.475 - z0, z + 0.475 - z0, 2.13])
		_door(Vector3(cx, 0, z), PI if side > 0.0 else 0.0, dd[1], t)
	Geo.wall(self, Vector2(cx, z0), Vector2(cx, z1), H, wall_m, t, offs)


## The same along X (x0 < x1; `side` +1: the body toward +Z).
func _wall_x(z: float, x0: float, x1: float, side: float, doors := [], cuts := [], t := T) -> void:
	var cz := z + side * t * 0.5
	var offs := []
	for c: Array in cuts:
		offs.append([c[0] - x0, c[1] - x0, c[2], c[3] if c.size() > 3 else 0.0])
	for dd: Array in doors:
		var x: float = dd[0]
		offs.append([x - 0.475 - x0, x + 0.475 - x0, 2.13])
		_door(Vector3(x, 0, cz), PI / 2 if side > 0.0 else -PI / 2, dd[1], t)
	Geo.wall(self, Vector2(x0, cz), Vector2(x1, cz), H, wall_m, t, offs)


## A locked door (it rattles): the worn steel door of the user's photo (OfficeKit.steel_door), no plate on it (user:
## "문마다 무슨실 무슨 실 설명이랑 팻말 되어있는거 다 삭제해줘"): `plate` is only its name in doors_by (the office plan
## labels it).
func _door(at: Vector3, rot: float, plate: String, t: float) -> void:
	var door := OfficeKit.steel_door(self, at, rot, t)
	(door.use as Interactable).callback = func(): Terminal.current.rattle(door)
	side_doors.append(door)
	doors_by[plate] = door


# --------------------------------------------------------------------------------------------
## The way in: the office's own passage door seen from outside (Terminal.steel_door, on the same spot), hung open into
## a dark closet in the office's footprint (out of every portal's view); its leaf only shows once you are through
## (the office's real leaf stands in front of it until then). No plate beside it.
func _build_entry() -> void:
	entry = Terminal.steel_door(self, ENTRY, PI)
	(entry.leaf as Node3D).rotation.y = deg_to_rad(84.0)
	(entry.leaf as Node3D).visible = false
	(entry.block as StaticBody3D).collision_layer = 0
	(entry.use as Interactable).enabled = false
	var black := Mats.get_mat("void")
	var cx := ENTRY.x + 0.95                # (in the office's footprint, east of its west door)
	for b: Array in [[Vector3(cx, 0.002, ENTRY.z), Vector3(1.6, 0.004, 1.6), false],
			[Vector3(cx, 2.25, ENTRY.z), Vector3(1.6, 0.05, 1.6), false],
			[Vector3(cx, 1.15, ENTRY.z - 0.82), Vector3(1.6, 2.3, 0.04), true],
			[Vector3(cx, 1.15, ENTRY.z + 0.82), Vector3(1.6, 2.3, 0.04), true],
			[Vector3(cx + 0.8, 1.15, ENTRY.z), Vector3(0.04, 2.3, 1.6), true]]:
		var m := Geo.box(self, b[0], b[1], black, b[2])
		m.layers = Geo.VIS_PORTAL_HIDDEN
		entry_closet.append(m)


## The far end: the lift (user: "출구 문을 엘리베이터로 바꿔줘") in the end wall of the last run, down to the lounge
## on 1F (Lift: its car is built behind this wall and again behind the lounge's; Terminal links the two). And the
## stairs: the steel door at the run's north end onto the stairwell (StairCore), whose
## foot at 1F leads through the stair lobby to the lounge too.
func _build_lift_end() -> void:
	lift_car = Lift.car(self, Transform3D(Basis(Vector3.UP, PI), FAR), T, 4, 1)


func _build_stairs() -> void:
	stair_lobby = StairCore.build(self)
	stair_door = {}                # (no door at 4F any more: the corridor runs onto the landing)


## The maze's side of the office's big windows: a dark frame and sill on each, the pane that shows the office through
## it (office_panes: Terminal.sec_inview's surface, to your eye only), the blind half down on one.
func _build_office_side() -> void:
	for i in Terminal.SEC_VIEW_W.size():
		_office_window(Vector3(-22.55, Terminal.SEC_VIEW_Y, Terminal.SEC_VIEW_W[i]), -PI / 2, 0.4 if i == 1 else 0.0)
	for x: float in Terminal.SEC_VIEW_N:
		_office_window(Vector3(x, Terminal.SEC_VIEW_Y, -25.85), 0.0)
	# (the office's east wall's frosted window with papers taped on it was taken off this side — user: "이거 없애")


## One window at `at` on a wall face, the corridor toward its local +Z; `blinds` = how far its venetian blind is down.
func _office_window(at: Vector3, rot: float, blinds := 0.0) -> void:
	var h := Node3D.new()
	add_child(h)
	h.position = at
	h.rotation.y = rot
	var size := Terminal.SEC_VIEW_SIZE
	var t := 0.07
	for sy in [-1.0, 1.0]:
		Geo.box(h, Vector3(0, sy * (size.y * 0.5 + t * 0.5), 0.025), Vector3(size.x + t * 2.0, t, 0.05), _frame_m, false)
	for sx in [-1.0, 1.0]:
		Geo.box(h, Vector3(sx * (size.x * 0.5 + t * 0.5), 0, 0.025), Vector3(t, size.y, 0.05), _frame_m, false)
	Geo.box(h, Vector3(0, -size.y * 0.5 - t - 0.015, 0.06), Vector3(size.x + 0.24, 0.03, 0.12), _frame_m, false)
	var pane := Geo.box(h, Vector3(0, 0, 0.003), Vector3(size.x, size.y, 0.002), Mats.get_mat("black"), false)
	pane.layers = Geo.VIS_PORTAL_HIDDEN
	office_panes.append(pane)
	if blinds <= 0.0:
		return
	var slat := Mats.std(Color(0.62, 0.62, 0.58), 0.7)
	Geo.box(h, Vector3(0, size.y * 0.5 - 0.025, 0.08), Vector3(size.x - 0.04, 0.05, 0.06), slat, false)    # head rail
	var n := int(size.y * blinds / 0.045)
	for i in n:
		var s := Geo.box(h, Vector3(0, size.y * 0.5 - 0.07 - i * 0.045, 0.08), Vector3(size.x - 0.06, 0.003, 0.046), slat, false)
		s.rotation.x = 0.5
	Geo.box(h, Vector3(0, size.y * 0.5 - 0.07 - n * 0.045, 0.08), Vector3(size.x - 0.05, 0.022, 0.05), slat, false)


## A pair of steel doors with wired-glass lights and push bars in a frame on the wall plane at `xf` (in `parent`'s
## space); they swing to local +Z (swing). Returns {root, leaf, leaves, block, use}; the use is "문 열기" with no
## callback. The lounge's staff doors are the same pair.
static func double_door(parent: Node3D, xf: Transform3D) -> Dictionary:
	var root := Node3D.new()
	parent.add_child(root)
	root.transform = xf
	var frame := Mats.std(Color(0.3, 0.32, 0.35), 0.4, 0.6)
	var steel := Mats.std(Color(0.4, 0.43, 0.46), 0.5, 0.45)
	var wired := Mats.std(Color(0.05, 0.06, 0.07), 0.15, 0.3)
	var metal := Mats.get_mat("metal")
	var hw := FAR_W * 0.5
	for sx in [-1.0, 1.0]:
		Geo.box(root, Vector3(sx * (hw + 0.04), FAR_H * 0.5, 0), Vector3(0.08, FAR_H, 0.34), frame, false)
	Geo.box(root, Vector3(0, FAR_H + 0.04, 0), Vector3(FAR_W + 0.16, 0.08, 0.34), frame, false)
	var leaves: Array[Node3D] = []
	for sx in [-1.0, 1.0]:
		var hinge := Node3D.new()
		root.add_child(hinge)
		hinge.position = Vector3(sx * hw, 0, 0)
		var lw := hw - 0.008
		var cx: float = -sx * lw * 0.5                # the leaf runs from its hinge to the middle
		Geo.box(hinge, Vector3(cx, FAR_H * 0.5, 0), Vector3(lw, FAR_H - 0.03, 0.05), steel, false)
		Geo.box(hinge, Vector3(cx, 1.6, 0), Vector3(0.24, 0.62, 0.056), wired, false)
		for sz in [-1.0, 1.0]:
			Geo.box(hinge, Vector3(cx, 1.0, sz * 0.055), Vector3(lw * 0.78, 0.045, 0.045), metal, false)
		Geo.box(hinge, Vector3(cx, 0.12, 0), Vector3(lw - 0.02, 0.2, 0.056), metal, false)    # kick plates
		leaves.append(hinge)
	var block := Geo.blocker(root, Vector3(0, FAR_H * 0.5, 0), Vector3(FAR_W, FAR_H, 0.3))
	var use := Interactable.create(root, Vector3(0, 1.1, 0), Vector3(FAR_W, 2.1, 0.5), "문 열기", Callable())
	use.press_sound = ""
	return {"root": root, "leaf": leaves[0], "leaves": leaves, "block": block, "use": use}


## Swings a double_door's leaves to `deg` toward its +Z side (0 = shut) over `time` s; the collider goes once open.
static func swing(door: Dictionary, deg: float, time: float) -> Tween:
	var tw := (door.root as Node3D).create_tween().set_parallel(true)
	var leaves: Array[Node3D] = door.leaves
	for i in leaves.size():
		var sx := -1.0 if i == 0 else 1.0
		tw.tween_property(leaves[i], "rotation:y", sx * deg_to_rad(deg), time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	(door.block as StaticBody3D).collision_layer = 0 if deg > 1.0 else Geo.LAYER_WORLD
	return tw


# --------------------------------------------------------------------------------------------
## Square fittings down the corridors (FITTINGS; two dead), cold green-white; the zone flickers now and then; the
## haze they hang in, a volume per corridor (none over the office's footprint, where its windows' view looks from).
func _build_lights() -> void:
	zone = LightZone.new()
	zone.name = "Zone_servicehall"
	add_child(zone)
	zone.setup("servicehall", "관리동 복도", LIGHT, 3.0)
	var dead := Mats.std(Color(0.3, 0.32, 0.3), 0.5)
	for f: Array in FITTINGS:
		var at := Vector3(f[0], H - 0.035, f[1])
		if f[2]:
			zone.add_panel(at, Vector2(0.6, 0.6), true, 0.8, 6.5, LIGHT)
		else:
			Geo.box(zone, at, Vector3(0.6, 0.06, 0.6), dead, false)
			Geo.box(zone, at + Vector3(0, 0.02, 0), Vector3(0.7, 0.05, 0.7), Mats.get_mat("plastic_white"), false)
	for p: Vector3 in [Vector3(-11.15, H - 0.3, -16.0), Vector3(-23.65, H - 0.3, -18.0), Vector3(-36.1, H - 0.3, -15.0)]:
		zone.add_hum(p, -24.0)
	zone.erratic = 0.12
	zone.night_dim = 0.85
	var fm := FogMaterial.new()
	fm.density = 0.05
	fm.albedo = Color(0.48, 0.56, 0.52)
	fm.edge_fade = 0.1
	for r: Rect2 in HALLS.values():
		var fog := FogVolume.new()
		fog.size = Vector3(r.size.x, H, r.size.y)
		fog.material = fm
		add_child(fog)
		fog.position = Vector3(r.get_center().x, H * 0.5, r.get_center().y)


## Air grilles in the ceiling between the lights, wet patches on the floor. (No clock, floor sign, bin, framed
## pictures, fire hose cabinet or chairs out here any more — user: "원통형 쓰레기통 다 삭제", "시계랑 ㅇㅇ층
## 이렇게 표시되어 있는 간판도 삭제해줘", "소화전이랑 액자도 삭제해줘", "복도에 의자 삭제해주고".)
func _build_details() -> void:
	for g: Array in [[-11.15, -17.9, 0.0], [-17.4, -11.75, PI / 2], [-23.65, -18.0, 0.0], [-23.65, -22.4, 0.0],
			[-30.3, -24.75, PI / 2], [-36.1, -18.5, 0.0], [-36.1, -10.3, 0.0], [-29.6, -19.4, PI / 2]]:
		OfficeKit.vent_grille(self, Vector3(g[0], H - 0.006, g[1]), g[2], Vector2(0.3, 0.9), PI / 2)
	Props.exit_sign(self, Vector3(-31.6, 2.62, -12.55), PI)          # over B2's dead end: no way out
	var wet := Mats.std(Color(0.2, 0.22, 0.2), 0.0, 0.0)
	wet.metallic_specular = 0.9
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.albedo_color.a = 0.55
	for p: Array in [[Vector3(-23.4, 0.002, -14.2), Vector2(0.9, 1.4)], [Vector3(-36.3, 0.002, -11.0), Vector2(1.0, 1.8)],
			[Vector3(-30.0, 0.002, -24.6), Vector2(1.3, 0.7)]]:
		var q := QuadMesh.new()
		q.size = p[1]
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = wet
		add_child(mi)
		mi.position = p[0]
		mi.rotation.x = -PI / 2


func _build_reverb() -> void:
	var a := Area3D.new()
	a.name = "Reverb_servicehall"
	a.collision_layer = Geo.LAYER_AUDIO
	a.collision_mask = 0
	a.monitoring = false
	a.reverb_bus_enabled = true
	a.reverb_bus_name = "RevMid"
	a.reverb_bus_amount = 0.32
	a.reverb_bus_uniformity = 0.4
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(27.8, H, 24.0)
	cs.shape = box
	a.add_child(cs)
	add_child(a)
	a.position = Vector3(-23.6, H * 0.5, -17.8)
