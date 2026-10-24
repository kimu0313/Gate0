class_name Terminal
extends Node3D
## Procedurally builds the SEOHAE International Airport terminal and exposes its systems.
##
## Layout from the level plan (Downloads/image (9).png, 2 m grid, drawn with the airside at the bottom) and the
## lobby sketch (일러스트.jpg). Metres, Y up, -Z = north/airside, +X = east:
##   HALL (lobby) x[-20,12] z[-2.5,14] (7.5 m, glass facade on the apron to the south) + its north strip
##                x[-12.2,12] z[-8.5,-2.5]; self check-in blocks x[-12.2,-6.9] / x[6.2,12] z[0,7.6] (sketch)
##   OFFICE   x[-20,-12.2] z[-2.5,7.6]    STORAGE x[12,22] z[-8.5,-2.5]    2F lounge (closed) x[12,24.5] z[-2.5,14]
##   SECURITY x[-10,10] z[-27.3,-8.5]     CORRIDOR x[-10,10] z[-76,-27.3] (walkways on its east side)
##   BAGGAGE  x[-36,-10] z[-64,-39.6] + staff passage x[-12.4,-10] z[-39.6,-8.5] from the strip (open from DAY 2,
##            before security; the public opening from the corridor opens with the corridor)
##   MAINT    x[-48,-36] z[-53,-47]       GATES x[-26,26] z[-100,-76]       GATE 0 bridge x[-1.3,1.3] z[-128,-100]

const HALL_H := 7.5          # lobby, double height
const MEZZ_Y := 4.2          # 2F lounge floor
const STRIP_H := 4.5
const SEC_H := 4.1
const COR_H := 4.5
const BAG_H := 3.6
const LANE_X := [-4.8, 3.25]  # X-ray tunnel centres (lane 1 west, lane 2 east), metal detector 3.6 m east of each
const LANE_Z := -18.0
const MD_DX := 3.6
const BELT_POS := Vector3(-25.5, 0, -59.0)

## Zone footprints (one Rect2 or an Array of them). Checked in this order by zone_at, so rooms inside the hall's
## rect (the office) come first.
const ZONE_RECTS := {
	"office": Rect2(-20, -2.5, 7.8, 10.1),
	"hall": [Rect2(-20, -2.5, 32, 16.5), Rect2(-12.2, -8.5, 24.2, 6)],
	"storage": Rect2(12, -8.5, 10, 6),
	"security": Rect2(-10, -27.3, 20, 18.8),
	"corridor": Rect2(-10, -76, 20, 48.7),
	"baggage": [Rect2(-36, -64, 26, 24.4), Rect2(-12.4, -39.6, 2.4, 31.1)],
	"maint": Rect2(-48, -53, 12, 6),
	"gates": Rect2(-26, -100, 52, 24),
	"bridge0": Rect2(-1.5, -130, 3, 30),
}
const ZONE_NAMES := {
	"office": "시설관리실", "hall": "체크인 홀", "baggage": "수하물 수취", "storage": "자재창고",
	"maint": "정비 통로", "security": "보안검색", "corridor": "탑승동 통로", "gates": "탑승 게이트",
	"bridge0": "0번 탑승교", "outside": "외부",
}

## Named floor points the story scripts, the NPC and the debug bots use instead of their own coordinates.
const SPOTS := {
	# documents and the furniture they lie on
	"doc_log1": Vector3(-14.6, 0.77, 6.9), "log1_desk": Vector3(-14.6, 0.38, 6.95),
	"doc_memo_worker": Vector3(-0.45, 1.01, 5.55),
	"locker": Vector3(9.55, 0.0, -24.6), "doc_log2": Vector3(9.18, 1.02, -24.6),
	"doc_newspaper": Vector3(8.4, 0.49, -87.2), "doc_log3": Vector3(20.8, 0.49, -94.6),
	"doc_timecard": Vector3(-14.6, 0.93, -2.05), "timecard_shelf": Vector3(-14.6, 0.9, -2.15),
	"plaque": Vector3(20.4, 0.0, -6.6),
	# evening-shift colleague posts (DAY 1–5)
	"npc_office": Vector3(-16.0, 0, 1.2), "npc_b03": Vector3(-33.2, 0, -55.4), "npc_xray": Vector3(-2.3, 0, -16.4),
	"npc_wing": Vector3(2.6, 0, -25.4), "npc_info": Vector3(2.5, 0, 7.4),
	# wing door card reader (DAY 4–5), passenger-lane metal detectors
	"wing_reader": Vector3(4.7, 1.25, -27.08),
	"md_west": Vector3(-1.2, 0, -18.0), "md_east": Vector3(6.85, 0, -18.0),
	# where a person stands to work each panel (feet) and what they look at
	"view_lights": Vector3(-18.4, 0.05, 8.9), "look_lights": Vector3(-19.78, 1.45, 8.9),
	"view_fids": Vector3(-2.0, 0.05, 4.2), "look_fids": Vector3(-2.45, 5.8, -2.3),
	"view_pa": Vector3(0.2, 0.05, 7.0), "look_pa": Vector3(0.2, 1.0, 5.85),
	"view_baggage": Vector3(-34.3, 0.05, -57.4), "look_baggage": Vector3(-25.5, 0.6, -59.0),
	"view_walkway": Vector3(1.2, 0.05, -28.4), "look_walkway": Vector3(3.4, 0.2, -40.0),
	"view_xray": Vector3(-2.35, 0.05, -18.0), "look_xray": Vector3(-3.4, 1.24, -18.0),
	"view_punch": Vector3(-15.3, 0.05, -1.0), "look_punch": Vector3(-15.3, 1.35, -2.3),
	"view_breaker": Vector3(-13.3, 0.05, -1.0), "look_breaker": Vector3(-13.3, 1.5, -2.3),
	"office_inside": Vector3(-16.0, 0.05, 2.5), "office_look": Vector3(-19.6, 1.0, 2.5),
	"entrance_out": Vector3(-7.8, 0, 16.8),
	"cut_arrivals": Vector3(2.6, 0.05, 2.4),
	"boarding_hold": Vector3(-1.5, 0.05, -62.0), "boarding_look": Vector3(-1.5, 1.6, -40.0),
	"exit_inside": Vector3(-17.0, 0.05, 11.5), "exit_look": Vector3(-17.0, 1.5, 14.0),
	"exit_outside": Vector3(-17.0, 0.05, 16.0), "exit_out_look": Vector3(-17.0, 1.5, 20.0),
}
## Views matching the sketches: [name, eye, yaw (deg, 0 = -Z), vanishing point (fraction of the image), vertical fov]
## (debug/level_shots.gd, `-- --level-shots <dir>` on the game scene; render at the sketch aspect, 1920x1259).
const SKETCH_SHOTS := [
	["sketch_lobby", Vector3(-0.4, 1.6, -4.3), 180.0, Vector2(0.5, 0.485), 69.0],
]
const SHOTS := []
## Walk graph for people crossing the terminal (straight segments clear of counters, pillars and carousels).
const NAV := {
	"office": [Vector3(-16.0, 0, 2.5), ["office_door_in"]],
	"office_door_in": [Vector3(-18.2, 0, 6.2), ["office", "office_door_out"]],
	"office_door_out": [Vector3(-18.2, 0, 9.2), ["office_door_in", "hall_sw"]],
	"hall_sw": [Vector3(-12.0, 0, 10.5), ["office_door_out", "entrance_in", "hall_s"]],
	"entrance_in": [Vector3(-7.8, 0, 12.4), ["hall_sw", "hall_s"]],
	"hall_s": [Vector3(-6.2, 0, 10.6), ["hall_sw", "entrance_in", "hall_c"]],
	"hall_c": [Vector3(-2.8, 0, 9.4), ["hall_s", "desk_s", "hall_w"]],
	"desk_s": [Vector3(2.5, 0, 7.4), ["hall_c", "hall_ne"]],
	"hall_w": [Vector3(-2.6, 0, 1.0), ["hall_c", "hall_n"]],
	"hall_ne": [Vector3(2.7, 0, 1.2), ["desk_s", "strip_c"]],
	"hall_n": [Vector3(-2.6, 0, -1.6), ["hall_w", "strip_c", "strip_w"]],
	"strip_c": [Vector3(1.1, 0, -5.5), ["hall_n", "hall_ne", "strip_w", "sec_in"]],
	"strip_w": [Vector3(-11.2, 0, -6.2), ["hall_n", "strip_c", "pass_in"]],
	"sec_in": [Vector3(1.1, 0, -10.0), ["strip_c", "sec_mid"]],
	"sec_mid": [Vector3(1.1, 0, -17.0), ["sec_in", "sec_out", "xray_post"]],
	"xray_post": [Vector3(-2.3, 0, -16.4), ["sec_mid"]],
	"sec_out": [Vector3(1.1, 0, -26.0), ["sec_mid", "cor_s"]],
	"cor_s": [Vector3(-1.5, 0, -29.0), ["sec_out", "cor_bag"]],
	"cor_bag": [Vector3(-1.5, 0, -49.0), ["cor_s", "cor_n", "bag_e"]],
	"cor_n": [Vector3(-1.5, 0, -66.0), ["cor_bag", "gates_in"]],
	"gates_in": [Vector3(0.0, 0, -78.5), ["cor_n"]],
	"pass_in": [Vector3(-11.2, 0, -10.0), ["strip_w", "pass_out"]],
	"pass_out": [Vector3(-11.2, 0, -40.5), ["pass_in", "bag_ne"]],
	"bag_ne": [Vector3(-14.0, 0, -43.0), ["pass_out", "bag_e", "bag_mid"]],
	"bag_e": [Vector3(-12.0, 0, -49.0), ["bag_ne", "cor_bag", "bag_mid"]],
	"bag_mid": [Vector3(-21.0, 0, -55.0), ["bag_ne", "bag_e", "bag_ped"]],
	"bag_ped": [Vector3(-33.2, 0, -55.4), ["bag_mid"]],
}

static var current: Terminal

var zones := {}            # name -> LightZone
var facilities := {}       # id -> Facility
var gates := {}            # "01".."04","0" -> BoardingGate
var shutters := {}         # name -> Shutter
var doors := {}            # name -> SlidingDoor
var readers := {}          # name -> CardReader
var signs := {}            # name -> Array[Label3D]
var pickups := {}          # id -> Pickup
var spawns := {}           # name -> Transform3D
var triggers := {}         # name -> Area3D
var lights_panel: LightPanel
var lights_panel_gates: LightPanel
var breaker: BreakerPanel
var punch_clock: Interactable
var keypad: Interactable
var main_power: Interactable
var exit_door_use: Interactable
var syslog_terminal: Interactable
var gate0_wall: Node3D
var gate0_parts: Node3D
var final_plane: Node3D
var outside_lights: Array[Light3D] = []
var exit_signs: Array[MeshInstance3D] = []
var arrivals: FidsBoard
var emergency_light_root: Node3D
var _ceilings: Array = []  # [Rect2, y] of every ceiling, for _ceiling_details()
var _kiosk_proto: Node3D
var _probes := {}          # zone -> ReflectionProbe (faded with the zone's lights)


func build() -> void:
	current = self
	_build_zones()
	_build_office()
	_build_hall()
	_build_lounge()
	_build_baggage()
	_build_security()
	_build_corridor()
	_build_gates()
	_build_service_rooms()
	_build_outside()
	_build_facility_systems()
	_ceiling_details()
	_build_probes()
	_build_reverb()
	_define_spawns()
	if _kiosk_proto:
		_kiosk_proto.free()
	var fitted := Geo.fit_labels(self, OS.get_cmdline_user_args().has("--tour"))
	if OS.get_cmdline_user_args().has("--tour"):
		print("fit_labels: shrank %d world labels to their signs" % fitted)


## Every footprint of a zone (ZONE_RECTS holds one Rect2 or several).
static func zone_rects(zn: String) -> Array:
	var r: Variant = ZONE_RECTS[zn]
	return r if r is Array else [r]


## A named point from SPOTS.
func spot(name_text: String) -> Vector3:
	assert(SPOTS.has(name_text), "Terminal spot " + name_text)
	return SPOTS[name_text]


## Floor points from `from` to the NAV node `goal`: the nearest node first, then the shortest way along the graph.
func route(from: Vector3, goal: String) -> Array:
	var start := ""
	var best := INF
	for k in NAV.keys():
		var d := Vector2(from.x, from.z).distance_to(Vector2(NAV[k][0].x, NAV[k][0].z))
		if d < best:
			best = d
			start = k
	var dist := {start: 0.0}
	var prev := {}
	var open := [start]
	while not open.is_empty():
		var cur: String = open[0]
		for o in open:
			if dist[o] < dist[cur]:
				cur = o
		open.erase(cur)
		if cur == goal:
			break
		for nb: String in NAV[cur][1]:
			var nd: float = dist[cur] + (NAV[cur][0] as Vector3).distance_to(NAV[nb][0])
			if nd < dist.get(nb, INF):
				dist[nb] = nd
				prev[nb] = cur
				open.append(nb)
	var pts: Array = []
	var k: String = goal
	while true:
		pts.push_front(NAV[k][0])
		if k == start or not prev.has(k):
			break
		k = prev[k]
	return pts


# --------------------------------------------------------------------------------------------
func _build_zones() -> void:
	var defs := [
		["office", "사무실", 2.6],
		["hall", "홀", 3.4],
		["baggage", "수하물", 3.0],
		["security", "보안검색", 3.0],
		["corridor", "통로", 3.0],
		["gates", "게이트", 3.0],
		["service", "보관·정비", 2.0],
	]
	for d in defs:
		var z := LightZone.new()
		z.name = "Zone_" + d[0]
		add_child(z)
		z.setup(d[0], d[1], Color(0.9, 0.95, 1.0), d[2])
		zones[d[0]] = z


func _floor(rect: Rect2, mat_name: String) -> void:
	Geo.box(self, Vector3(rect.position.x + rect.size.x * 0.5, -0.05, rect.position.y + rect.size.y * 0.5),
		Vector3(rect.size.x, 0.1, rect.size.y), Mats.get_mat(mat_name))


## Ceiling slab over `rect` (its edges end inside the walls, which stand on the rect lines), lifted 3 mm so it never
## shares a plane with wall tops, lintels above openings or the walls' outer faces (z-fighting).
func _ceiling(rect: Rect2, y: float, mat_name := "ceiling") -> void:
	Geo.box(self, Vector3(rect.position.x + rect.size.x * 0.5, y + 0.103, rect.position.y + rect.size.y * 0.5),
		Vector3(rect.size.x, 0.2, rect.size.y), Mats.get_mat(mat_name), false)
	_ceilings.append([rect, y])


## Ceiling furniture (sprinkler heads, square air diffusers) on every ceiling, kept clear of the
## light fixtures. Runs after all zones are built so it can see where the panels went.
func _ceiling_details() -> void:
	var avoid: Array[AABB] = []
	for zn in zones:
		for p in (zones[zn] as LightZone).panels:
			avoid.append(AABB(p.position - (p.mesh as BoxMesh).size * 0.5, (p.mesh as BoxMesh).size).grow(0.7))
	var sprinklers: Array[Transform3D] = []
	var diffusers: Array[Transform3D] = []
	for c in _ceilings:
		var rect: Rect2 = c[0]
		var y: float = c[1]
		var x := rect.position.x + 1.5
		while x < rect.end.x - 0.5:
			var zz := rect.position.y + 1.5
			while zz < rect.end.y - 0.5:
				var at := Vector3(x, y, zz)
				var clear := true
				for a in avoid:
					if a.has_point(at - Vector3(0, 0.05, 0)):
						clear = false
						break
				if clear:
					var diffuser := int(roundf(x / 3.0) + roundf(zz / 3.0)) % 3 == 0
					(diffusers if diffuser else sprinklers).append(Transform3D(Basis(), at))
				zz += 3.0
			x += 3.0
	var sm := CylinderMesh.new()
	sm.top_radius = 0.03
	sm.bottom_radius = 0.045
	sm.height = 0.05
	sm.radial_segments = 10
	_multi(sm, Mats.get_mat("metal"), sprinklers, Vector3(0, -0.025, 0))
	var dm := BoxMesh.new()
	dm.size = Vector3(0.6, 0.03, 0.6)
	_multi(dm, Mats.get_mat("plastic_white"), diffusers, Vector3(0, -0.012, 0))
	var vm := BoxMesh.new()
	vm.size = Vector3(0.36, 0.01, 0.36)
	_multi(vm, Mats.get_mat("plastic_grey"), diffusers, Vector3(0, -0.03, 0))


func _multi(mesh: Mesh, mat: Material, xforms: Array[Transform3D], offset: Vector3) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i].translated(offset))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)


# --------------------------------------------------------------------------------------------
## Facility office, west end of the lobby; its door opens south into the lobby beside the lighting panel.
func _build_office() -> void:
	var r: Rect2 = ZONE_RECTS.office
	_floor(r, "floor_office")
	_ceiling(r, 3.2, "ceiling")
	var wm := Mats.get_mat("wall_office")
	var hw := Mats.get_mat("wall")
	# the office is a room inside the double-height hall: its walls rise to the hall ceiling
	Geo.wall(self, Vector2(-20, -2.5), Vector2(-20, 7.6), HALL_H, wm)
	Geo.wall(self, Vector2(-20, -2.5), Vector2(-12.2, -2.5), HALL_H, wm)
	Geo.wall(self, Vector2(-12.2, -2.5), Vector2(-12.2, 7.6), HALL_H, hw)
	Geo.wall(self, Vector2(-20, 7.6), Vector2(-12.2, 7.6), HALL_H, hw, 0.4, [[0.8, 2.8, 2.4]])
	var z: LightZone = zones.office
	z.add_panel(Vector3(-17.0, 3.17, 0.5), Vector2(2.4, 0.5), true, 1.3, 9.0, Color(1.0, 0.95, 0.85), true)
	z.add_panel(Vector3(-15.0, 3.17, 5.0), Vector2(2.4, 0.5), true, 1.1, 9.0, Color(1.0, 0.95, 0.85))
	z.add_hum(Vector3(-16, 3.0, 2.5), -24.0)
	# desk with PC + radio (west wall)
	Props.desk(self, Vector3(-19.1, 0, 2.5), Vector3(2.4, 0.76, 0.9), PI / 2)
	var pc := Props.monitor(self, Vector3(-19.35, 0.86, 1.8), PI / 2, Vector2(0.5, 0.3))
	pc.material_override = Mats.emissive(Color(0.15, 0.3, 0.6), 0.8)
	Geo.box(self, Vector3(-19.2, 0.8, 3.4), Vector3(0.08, 0.12, 0.05), Mats.get_mat("plastic_dark"), false)
	Geo.box(self, Vector3(-19.2, 0.89, 3.4), Vector3(0.01, 0.1, 0.01), Mats.get_mat("plastic_dark"), false)
	if TripoProps.exists("security", "SEC_OfficeChair"):
		TripoProps.spawn(self, "security", "SEC_OfficeChair", Vector3(-18.05, 0, 2.4), -PI / 2, true)
	else:
		Geo.box(self, Vector3(-18.1, 0.45, 2.4), Vector3(0.5, 0.08, 0.5), Mats.get_mat("seat"))
		Geo.box(self, Vector3(-17.85, 0.8, 2.4), Vector3(0.06, 0.6, 0.5), Mats.get_mat("seat"), false)
	# lockers (north wall), doors facing the room
	for i in 6:
		var lx := -19.45 + i * 0.62
		if TripoProps.exists("baggage", "BAG_NumberPillar"):
			# the Tripo pillar box (plinth, cap) stands in as a tall locker cabinet
			TripoProps.spawn(self, "baggage", "BAG_NumberPillar", Vector3(lx, 0, -2.05), 0.0, true, null, Vector3(0.6, 1.9, 0.5))
		else:
			Geo.box(self, Vector3(lx, 0.95, -2.05), Vector3(0.6, 1.9, 0.5), Mats.std(Color(0.42, 0.45, 0.48), 0.4, 0.6))
		Geo.box(self, Vector3(lx + 0.2, 1.2, -1.79), Vector3(0.03, 0.12, 0.02), Mats.get_mat("metal"), false)
		Geo.label(self, "%02d" % (i + 1), Vector3(lx, 1.7, -1.795), 0.0, 24, Color(0.1, 0.1, 0.1), 0.003, false, "print")
	# whiteboard (east wall)
	var wb := Node3D.new()
	add_child(wb)
	wb.position = Vector3(-12.42, 1.6, 2.6)
	wb.rotation.y = -PI / 2
	var board := Geo.box(wb, Vector3.ZERO, Vector3(2.0, 1.1, 0.03), Mats.get_mat("plastic_white"), false)
	if TripoProps.exists("common", "CMN_TrofferLight"):
		# the Tripo troffer's white frame and opal face read as a framed board on the wall
		board.visible = false
		var tb := TripoProps.spawn(wb, "common", "CMN_TrofferLight")
		tb.rotation.x = PI / 2          # face toward the room; scale is set after so it stays in the board's own axes
		TripoProps.fit(tb, Vector3(2.0, 0.03, 1.1))
		TripoProps.centre_on(tb, Vector3(0, 0, -0.0))
		tb.position.z = -0.015
	var note := Geo.fit(Geo.label(wb, "야간 점검 근무 — 반드시 수칙 준수!!\n점검 결과는 태블릿으로 즉시 보고\n0번 게이트 ✕  (존재하지 않음)\n— 소장", Vector3(-0.12, 0.05, 0.02), 0.0, 30, Color(0.1, 0.2, 0.6), 0.0035, false, "hand"), 1.55)
	note.rotation.z = -0.025
	# wall clock
	var clock := Node3D.new()
	add_child(clock)
	clock.position = Vector3(-16.4, 2.5, -2.28)
	Geo.cyl(clock, Vector3.ZERO, 0.18, 0.04, Mats.get_mat("plastic_white")).rotation.x = PI / 2
	Geo.label(clock, "3:00", Vector3(0, 0, 0.03), 0.0, 32, Color(0.1, 0.1, 0.1), 0.003, true, "lcd")
	# fax table for revision pages (east wall, by the door)
	Equipment.fax(self, Vector3(-12.85, 0, 6.2), PI / 2)
	# card reader door (office <-> hall), south wall
	var d := SlidingDoor.create(self, Vector3(-18.2, 0, 7.6), 0.0, 2.0, 2.4, false, false)
	doors["office"] = d
	readers["office_out"] = CardReader.create(self, Vector3(-16.85, 1.25, 7.82), 0.0)
	readers["office_in"] = CardReader.create(self, Vector3(-19.55, 1.25, 7.38), PI)
	readers.office_in.interactable.prompt = "문 열기"
	# room plate on the open side of the door, above the card reader (the west corner hides the other side), softly
	# lit so it reads in the dark
	LevelKit.plate(self, "plate_office", Vector3(-16.55, 1.72, 7.8), 0.0, Vector2(0.6, 0.4), 0.3)
	# punch clock, time cards and breaker (north wall)
	punch_clock = Equipment.punch_clock(self, Vector3(-15.3, 1.35, -2.28), 0.0)


# --------------------------------------------------------------------------------------------
## Check-in lobby (lobby sketch, matched with SKETCH_SHOTS["sketch_lobby"]): glass facade on the apron, a
## self check-in block on each side (kiosks against its face under a fascia sign), the U-shaped broadcast desk in
## the middle, two benches in front, a stopped escalator up to the closed 2F lounge, and the strip to the north
## that leads on to security, the staff passage (baggage) and the storage room.
func _build_hall() -> void:
	_floor(Rect2(-12.2, -2.5, 24.2, 16.5), "floor")
	_floor(Rect2(-20, 7.6, 7.8, 6.4), "floor")
	_floor(Rect2(-12.2, -8.5, 24.2, 6), "floor")
	_ceiling(Rect2(-20, -2.5, 32, 16.5), HALL_H)
	_ceiling(Rect2(-12.2, -8.5, 24.2, 6), STRIP_H)
	var wm := Mats.get_mat("wall")
	# facade on the apron (south): mullions every 3.5 m, transom at 5 m, head at 6.2 m under a deep beam (sketch);
	# main entrance west of the pillar, emergency exit at the west end
	_glass_facade(Vector2(-20, 14), Vector2(12, 14), HALL_H, [[-9.7, -5.9, 2.7], [-17.8, -16.2, 2.4]], -19.4, 3.5, [0.1, 5.0, 6.2])
	Geo.box(self, Vector3(-4, 6.85, 13.6), Vector3(32, 1.3, 0.8), wm, false)      # deep beam over the glazing
	Geo.box(self, Vector3(-4, HALL_H - 0.3, 8.3), Vector3(32, 0.6, 0.7), wm, false)   # beam on the pillar line
	Geo.wall(self, Vector2(-20, 7.6), Vector2(-20, 14), HALL_H, wm)
	# east: solid up to the lounge floor, the lounge's glass front above (see _build_lounge)
	Geo.wall(self, Vector2(12, -2.5), Vector2(12, 14), MEZZ_Y - 0.3, wm)      # tops out under the lounge slab
	# north: wall pieces carry the FIDS boards, the middle opens into the strip under a bulkhead
	Geo.wall(self, Vector2(-12.2, -2.5), Vector2(12, -2.5), HALL_H, wm, 0.4, [[7.2, 17.2, STRIP_H]])
	# strip: west end, storage door east, security + staff passage north
	Geo.wall(self, Vector2(-12.2, -8.5), Vector2(-12.2, -2.5), STRIP_H, wm)
	Geo.wall(self, Vector2(12, -8.5), Vector2(12, -2.5), STRIP_H, wm, 0.4, [[2.1, 3.9, 2.4]])
	Geo.wall(self, Vector2(-12.4, -8.5), Vector2(12, -8.5), STRIP_H, wm, 0.4, [[0.45, 1.95, 2.4], [6.4, 18.4, SEC_H]])
	# main entrance doors (locked at night)
	doors["entrance"] = SlidingDoor.create(self, Vector3(-7.8, 0, 14), 0.0, 3.6, 2.6, true, false)
	Geo.label(self, "출구  EXIT", Vector3(-7.8, 3.2, 13.75), PI, 60, Color(0.95, 0.95, 0.95), 0.006)
	# emergency exit door (chained until main power is cut)
	doors["emergency"] = SlidingDoor.create(self, Vector3(-17, 0, 14), 0.0, 1.6, 2.4, false, false)
	var es := Props.exit_sign(self, Vector3(-17, 2.75, 13.7), PI, "비상구  EXIT ▶")
	exit_signs.append(es)
	for i in 3:
		var ch := Geo.box(self, Vector3(-17, 1.0 + i * 0.12, 13.82), Vector3(1.5, 0.04, 0.04), Mats.get_mat("metal"), false)
		ch.rotation.z = 0.25 * (1 if i % 2 == 0 else -1)
		ch.name = "Chain%d" % i
	exit_door_use = Interactable.create(self, Vector3(-17, 1.2, 13.7), Vector3(1.6, 2.4, 0.3), "비상구 — 체인으로 잠겨 있다", Callable())
	exit_door_use.press_sound = "door_heavy"
	# lights: four rows of long troffers along the depth (sketch), small ones under the fascias, the strip
	var z: LightZone = zones.hall
	var k := 0
	for x in [-5.2, -1.5, 1.6, 5.0]:
		for zz in [-0.5, 3.5, 8.0, 12.0]:
			z.add_panel(Vector3(x, HALL_H - 0.08, zz), Vector2(0.45, 1.8), k % 2 == 0, 2.0, 15.0)
			k += 1
	z.add_panel(Vector3(-16.1, HALL_H - 0.08, 10.8), Vector2(0.5, 2.4), true, 1.6, 12.0)
	for x in [5.3, -6.0]:
		for zz in [2.2, 5.4]:
			z.add_panel(Vector3(x, 2.97, zz), Vector2(0.9, 0.45), zz < 3.0, 0.9, 6.0)
	for x in [-6.0, 0.0, 6.0]:
		z.add_panel(Vector3(x, STRIP_H - 0.08, -5.5), Vector2(0.5, 2.4), x == 0.0, 1.4, 10.0)
	z.add_hum(Vector3(-4, 6, 4), -18.0)
	z.add_hum(Vector3(0, 4, -5.5), -20.0)
	# the pillar west of the desk on the beam line, a backlit check-in sign on its north face
	Props.pillar(self, Vector3(-4.9, 0, 8.3), HALL_H, 1.2)
	var ps := LevelKit.sign_body(self, Vector3(-4.9, 1.85, 7.69), 180.0, Vector2(0.66, 1.0), true)
	LevelKit.decal(ps, "sign_pillar", Vector3(0, 0, ps.get_meta("face_z") + 0.003), 0.0, Vector2(0.62, 0.93), 0.3)
	_checkin_block(1.0)
	_checkin_block(-1.0)
	_escalator()
	_info_desk()
	# two benches in front of the desk, turned at an angle like the sketch's foreground
	Props.seat_row(self, Vector3(0.2, 0, 0.1), 3, -1.87)
	Props.seat_row(self, Vector3(0.55, 0, -2.1), 3, -1.87)
	# bins against walls, out of the walking lines: the corners beside the security opening, the west block's end
	for p in [Vector3(5.85, 0, -1.95), Vector3(-6.6, 0, -1.95), Vector3(-8.2, 0, 7.6)]:
		Props.trash_bin(self, p)
	for p in [Vector3(-19.2, 0, 13.2), Vector3(-11.6, 0, 13.2)]:
		Props.planter(self, p)
	# signage
	signs["hall_departures"] = Props.hanging_sign(self, Vector3(0, 3.55, -5.0), 0.0, Vector2(6.0, 0.9), [
		["↑  출국 · 보안검색", 60, Color(1, 1, 1), Vector2(-0.6, 0.18)],
		["DEPARTURES · SECURITY", 40, Color(0.85, 0.88, 0.95), Vector2(-0.6, -0.24)],
		["@icon_departures", 0.66, Color(1, 1, 1), Vector2(2.3, 0.0)],     # airport departures pictogram
	], STRIP_H)
	signs["hall_baggage"] = Props.hanging_sign(self, Vector3(-7.4, 3.6, -6.2), 0.0, Vector2(4.6, 0.8), [
		["◀  수하물 수취  BAGGAGE CLAIM", 44, Color(1, 1, 1), Vector2(0, 0.0)],
	], STRIP_H)
	signs["hall_staff"] = Props.hanging_sign(self, Vector3(-13.0, 4.4, 10.8), PI / 2, Vector2(4.4, 0.8), [
		["◀  시설관리실  STAFF ONLY", 44, Color(1, 1, 1), Vector2(0, 0.0)],
	], HALL_H)
	LevelKit.wall_sign(self, Vector3(-11.05, 2.95, -8.28), 0.0, "직원 통로 · 수하물 수취\nSTAFF · BAGGAGE CLAIM", Vector2(1.7, 0.5))   # clear of the west wall
	var banner := Node3D.new()
	add_child(banner)
	banner.position = Vector3(-4, 6.85, 13.18)
	banner.rotation.y = PI
	Geo.box(banner, Vector3.ZERO, Vector3(12, 1.2, 0.05), Mats.std(Color(0.08, 0.2, 0.45), 0.8), false)
	Geo.label(banner, "GRAND OPENING  2026. 10. 23", Vector3(0, 0.19, 0.03), 0.0, 76, Color(1, 1, 1), 0.008, false, "print")
	Geo.label(banner, "서해국제공항 정식 개장", Vector3(0, -0.3, 0.03), 0.0, 52, Color(0.78, 0.86, 1.0), 0.008, false, "print")


## A self check-in block (`side` +1 east, -1 west): a solid volume whose face carries five kiosks under a
## 1.8 m fascia overhang printed with the Self Check-in sign, a queue belt in front, a wall closing the bay's far
## end. The east block's upper face announces the closed 2F lounge; the west one has a staff door at its near end.
func _checkin_block(side: float) -> void:
	var face_x := 6.2 if side > 0 else -6.9      # kiosk wall
	var outer := 12.0 if side > 0 else -12.2
	var fx := face_x - 1.8 * side                 # fascia front line
	var z0 := 0.0
	var z1 := 7.3
	var zc := (z0 + z1) * 0.5
	var face := -90.0 if side > 0 else 90.0       # kiosks and signs look back into the hall
	var wm := Mats.get_mat("wall")
	# the block runs right up to the north wall (face z -2.3), so there is no dead-end alcove behind it
	var zn := -2.3
	Geo.box(self, Vector3((face_x + outer) * 0.5, HALL_H * 0.5, (zn + z1) * 0.5), Vector3(absf(outer - face_x), HALL_H, z1 - zn), wm)
	# fascia overhang (3.0 .. 4.25 m), its underside a ceiling, a steel edge along the front
	Geo.box(self, Vector3((fx + face_x) * 0.5, 3.625, zc), Vector3(1.8, 1.25, z1 - z0), wm, false)
	Geo.box(self, Vector3((fx + face_x) * 0.5, 2.995, zc), Vector3(1.8, 0.01, z1 - z0), Mats.get_mat("ceiling"), false)
	Geo.box(self, Vector3(fx, 3.0, zc), Vector3(0.05, 0.05, z1 - z0 + 0.02), Mats.get_mat("steel_frame"), false)
	LevelKit.decal(self, "fascia_selfcheckin_" + ("e" if side > 0 else "w"), Vector3(fx - 0.004 * side, 3.625, zc), face,
			Vector2(z1 - z0, 1.25))
	# wall closing the bay's far (south) end
	Geo.box(self, Vector3((fx + face_x) * 0.5, 2.12, z1 - 0.13), Vector3(1.78, 4.24, 0.24), wm)    # 1 cm inside the fascia's outline
	# kiosks along the face, 1.125 m apart
	var zk := 1.4 if side > 0 else 2.1
	for i in 5:
		_kiosk(Vector3(face_x - 0.24 * side, 0, zk + i * 1.125), face)
	# queue belt in front of the kiosks
	var bx := 3.7 if side > 0 else -3.9
	var bz := 1.2 if side > 0 else 0.4
	LevelKit.stanchions(self, [Vector3(bx, 0, bz), Vector3(bx, 0, bz + 1.4), Vector3(bx, 0, bz + 2.8), Vector3(bx, 0, bz + 4.2)])
	if side > 0:
		LevelKit.decal(self, "sign_lounge", Vector3(face_x - 0.01, 5.9, zc), face, Vector2(2.4, 1.6))
	else:
		LevelKit.staff_door(self, Vector3(face_x, 0, 0.9), 90.0)


## Broadcast desk: a solid-surface counter (worktop 1.0 m, the PA console on it) between two raised returns
## (1.18 m), open to the south where the operator stands: dark recessed plinth, blue accent line on the public face,
## quartz tops overhanging 3 cm, a drawer pedestal and a knee space under the worktop. Built from closed rounded
## volumes (the stretched Tripo desk showed open, paper-thin panels).
func _info_desk() -> void:
	var body := Mats.std(Color(0.88, 0.88, 0.86), 0.35)
	var top := Mats.std(Color(0.74, 0.75, 0.74), 0.22, 0.05)
	var blue := Mats.std(Color(0.07, 0.25, 0.56), 0.4)
	var dark := Mats.std(Color(0.09, 0.095, 0.1), 0.6)
	var kick := CarouselMesh.mat("kick")
	var x0 := -0.75                         # worktop between the returns
	var x1 := 1.15
	var z_front := 5.3                      # public face (north)
	var z_back := 6.2                       # operator side (south) of the worktop
	var parts: Array = [
		# [centre-bottom, size, corner radius, material, closed base]
		[Vector3((x0 + x1) * 0.5, 0.0, z_front + 0.05), Vector3(x1 - x0, 0.1, 0.06), 0.01, kick, false],
		[Vector3((x0 + x1) * 0.5, 0.1, z_front + 0.04), Vector3(x1 - x0, 0.86, 0.08), 0.01, body, false],      # modesty panel
		[Vector3((x0 + x1) * 0.5, 0.96, (z_front + z_back) * 0.5), Vector3(x1 - x0 + 0.04, 0.04, z_back - z_front + 0.06), 0.015, top, true],
		[Vector3(x1 - 0.26, 0.0, 5.76), Vector3(0.46, 0.96, 0.82), 0.015, body, false],                        # drawer pedestal (floor to worktop)
	]
	for rx in [-1.0, 1.4]:
		parts.append([Vector3(rx, 0.0, 6.05), Vector3(0.42, 0.1, 1.42), 0.03, kick, false])
		parts.append([Vector3(rx, 0.1, 6.05), Vector3(0.5, 1.04, 1.5), 0.04, body, false])
		parts.append([Vector3(rx, 1.14, 6.05), Vector3(0.56, 0.04, 1.56), 0.04, top, true])
	for pt in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = CarouselMesh.rounded_prism(pt[1], pt[2], pt[4])
		mi.material_override = pt[3]
		add_child(mi)
		mi.position = pt[0]
	# knee space: a dark back under the worktop between the modesty panel and the pedestal
	Geo.box(self, Vector3((x0 + x1 - 0.52) * 0.5, 0.53, z_front + 0.085), Vector3(x1 - x0 - 0.52, 0.86, 0.01), dark, false)
	# blue accent line wrapping the public face and the returns' outer faces
	Geo.box(self, Vector3((x0 + x1) * 0.5, 0.82, z_front - 0.003), Vector3(x1 - x0, 0.035, 0.008), blue, false)
	for rx in [-1.0, 1.4]:
		Geo.box(self, Vector3(rx, 0.82, 5.3 - 0.003), Vector3(0.42, 0.035, 0.008), blue, false)
	# drawer fronts: dark seams and finger pulls on the pedestal's operator face
	for i in 3:
		var dy := 0.24 + i * 0.25
		Geo.box(self, Vector3(x1 - 0.26, dy + 0.11, 6.172), Vector3(0.4, 0.006, 0.006), dark, false)
		Geo.box(self, Vector3(x1 - 0.26, dy + 0.06, 6.175), Vector3(0.14, 0.012, 0.012), CarouselMesh.mat("steel"), false)
	# colliders
	Geo.blocker(self, Vector3((x0 + x1) * 0.5, 0.5, (z_front + z_back) * 0.5), Vector3(x1 - x0, 1.0, z_back - z_front))
	for rx in [-1.0, 1.4]:
		Geo.blocker(self, Vector3(rx, 0.59, 6.05), Vector3(0.5, 1.18, 1.5))


## Self check-in kiosk: an off-white cabinet on a dark plinth with a blue band, a service door, boarding-pass and
## bag-tag printer slots, a reader ledge (passport glass, card reader) and a portrait touch screen tilted back on a
## steel neck. `facing` = direction the screen looks (deg). Built once, then copied (shared meshes and materials).
func _kiosk(pos: Vector3, facing: float) -> void:
	if _kiosk_proto == null:
		_kiosk_proto = _build_kiosk()
	var k := _kiosk_proto.duplicate() as Node3D
	add_child(k)
	k.position = pos
	k.rotation.y = deg_to_rad(facing)


func _build_kiosk() -> Node3D:
	var k := Node3D.new()
	var body := Mats.std(Color(0.84, 0.85, 0.84), 0.35)
	var dark := Mats.std(Color(0.14, 0.15, 0.17), 0.45, 0.2)
	var blue := Mats.std(Color(0.07, 0.25, 0.56), 0.4)
	var steel := CarouselMesh.mat("steel")
	# [size, corner radius, position, material, closed base]
	for part in [
		[Vector3(0.46, 0.06, 0.38), 0.03, Vector3(0, 0, 0), CarouselMesh.mat("kick"), false],
		[Vector3(0.5, 1.0, 0.42), 0.05, Vector3(0, 0.06, 0), body, true],
		[Vector3(0.508, 0.04, 0.428), 0.054, Vector3(0, 0.94, 0), blue, false],      # band, 4 mm proud
		[Vector3(0.51, 0.03, 0.2), 0.03, Vector3(0, 1.035, 0.16), body, true],        # reader ledge, 5 mm over the top
		[Vector3(0.14, 0.14, 0.08), 0.02, Vector3(0, 1.06, -0.04), steel, false],     # neck
	]:
		var mi := MeshInstance3D.new()
		mi.mesh = CarouselMesh.rounded_prism(part[0], part[1], part[4])
		mi.material_override = part[3]
		k.add_child(mi)
		mi.position = part[2]
	# service door: a dark seam around a panel standing 3 mm proud of it
	Geo.box(k, Vector3(0, 0.45, 0.2115), Vector3(0.372, 0.612, 0.004), dark, false)
	Geo.box(k, Vector3(0, 0.45, 0.2145), Vector3(0.36, 0.6, 0.004), body, false)
	Geo.box(k, Vector3(0.14, 0.45, 0.218), Vector3(0.02, 0.06, 0.002), steel, false)    # key lock
	# printer slots: boarding pass above, bag tag below, each in a dark bezel
	for sy in [0.87, 0.81]:
		Geo.box(k, Vector3(0, sy, 0.2125), Vector3(0.24, 0.036, 0.005), dark, false)
		Geo.box(k, Vector3(0, sy, 0.215), Vector3(0.19, 0.006, 0.002), Mats.get_mat("black"), false)
	# ledge: passport reader glass (left), card reader with its slot (right)
	Geo.box(k, Vector3(-0.1, 1.067, 0.17), Vector3(0.17, 0.003, 0.12), Mats.std(Color(0.04, 0.05, 0.06), 0.1, 0.0), false)
	Geo.box(k, Vector3(0.15, 1.09, 0.18), Vector3(0.09, 0.05, 0.08), dark, false)
	Geo.box(k, Vector3(0.15, 1.1, 0.2205), Vector3(0.06, 0.004, 0.002), Mats.get_mat("black"), false)
	# portrait screen head: dark rounded bezel tilted back, the welcome screen set into it
	var head := Node3D.new()
	k.add_child(head)
	head.position = Vector3(0, 1.16, -0.02)
	head.rotation.x = -0.26
	var bezel := MeshInstance3D.new()
	bezel.mesh = CarouselMesh.rounded_prism(Vector3(0.46, 0.06, 0.6), 0.03, true)
	bezel.material_override = dark
	head.add_child(bezel)
	bezel.rotation.x = PI / 2          # prism top = the screen face (+Z), its body behind
	bezel.position = Vector3(0, 0.3, -0.03)
	var scr := LevelKit.decal(head, "kiosk_screen", Vector3(0, 0.31, 0.032), 0.0, Vector2(0.38, 0.5), 0.7)
	scr.name = "KioskScreen"
	Geo.blocker(k, Vector3(0, 0.87, 0), Vector3(0.5, 1.74, 0.42))
	return k


## Stopped escalator from the hall floor up to the closed 2F lounge (east), belted off at the foot (Escalator).
func _escalator() -> void:
	Escalator.build(self, Vector3(4.2, 0, 12.3), MEZZ_Y)


## The 2F lounge behind its glass front (the plan crosses it out): closed for the opening, never reachable.
func _build_lounge() -> void:
	var r := Rect2(12, -2.5, 12.5, 16.5)
	var c := Vector3(18.25, 0, 5.75)
	Geo.box(self, Vector3(c.x, MEZZ_Y - 0.15, c.z), Vector3(r.size.x, 0.3, r.size.y), Mats.get_mat("carpet"))
	Geo.box(self, Vector3(c.x, HALL_H + 0.1, c.z), Vector3(r.size.x, 0.2, r.size.y), Mats.get_mat("ceiling_dark"), false)
	var wm := Mats.get_mat("wall")
	Geo.wall(self, Vector2(12, -2.5), Vector2(24.5, -2.5), HALL_H - MEZZ_Y, wm, 0.4, [], MEZZ_Y)
	Geo.wall(self, Vector2(12, 14), Vector2(24.5, 14), HALL_H - MEZZ_Y, wm, 0.4, [], MEZZ_Y)
	Geo.wall(self, Vector2(24.5, -2.5), Vector2(24.5, 14), HALL_H - MEZZ_Y, wm, 0.4, [], MEZZ_Y)
	# glass front over the hall, open where the escalator arrives
	var frame := Mats.get_mat("steel_frame")
	for seg in [[-2.5, 11.4], [13.2, 14.0]]:
		var a: float = seg[0]
		var b: float = seg[1]
		Geo.box(self, Vector3(12, (MEZZ_Y + HALL_H) * 0.5, (a + b) * 0.5), Vector3(0.04, HALL_H - MEZZ_Y, b - a), Mats.get_mat("glass"), false)
		Geo.box(self, Vector3(12, MEZZ_Y + 1.05, (a + b) * 0.5), Vector3(0.08, 0.05, b - a), frame, false)
		var mz := a
		while mz <= b + 0.01:
			Geo.box(self, Vector3(12, (MEZZ_Y + HALL_H) * 0.5, mz), Vector3(0.1, HALL_H - MEZZ_Y, 0.08), frame, false)
			mz += 2.5
	for seg in [[-2.5, 11.4], [13.2, 14.0]]:          # the base frame stops at the escalator's arrival
		Geo.box(self, Vector3(12, MEZZ_Y + 0.05, (seg[0] + seg[1]) * 0.5), Vector3(0.3, 0.1, seg[1] - seg[0]), frame, false)
	Geo.blocker(self, Vector3(12.6, MEZZ_Y + 1.5, 12.3), Vector3(0.3, 3.0, 2.0))
	# seats under dust sheets, an opening-soon sign on the glass, one dim emergency light
	for zz in [1.0, 4.0, 7.0]:
		Props.seat_row(self, Vector3(18.0, MEZZ_Y, zz), 4, PI / 2)
	var glow := Geo.omni(self, Vector3(20.0, MEZZ_Y + 2.6, 5.0), Color(0.3, 0.9, 0.5), 0.25, 8.0)
	glow.light_volumetric_fog_energy = 0.4
	Props.exit_sign(self, Vector3(24.28, MEZZ_Y + 2.4, 5.0), -PI / 2, "비상구  EXIT")


func _glass_facade(a: Vector2, b: Vector2, height: float, gaps: Array, mullion_x := 0.0, step := 4.0,
		transoms := [0.1, 4.6]) -> void:
	# glass wall along X at z = a.y. gaps: [[x0, x1, top], ...] (door openings); mullions every `step` from
	# `mullion_x` (none inside a door opening), horizontal bars at `transoms` and the head
	var z := a.y
	var x := mullion_x - step * ceilf((mullion_x - a.x) / step)
	var frame := Mats.get_mat("steel_frame")
	var glass := Mats.get_mat("glass")
	var segs := []
	var cursor := a.x
	var sorted := gaps.duplicate()
	sorted.sort_custom(func(p, q): return p[0] < q[0])
	for g in sorted:
		segs.append([cursor, g[0]])
		cursor = g[1]
	segs.append([cursor, b.x])
	for s in segs:
		var w: float = s[1] - s[0]
		if w <= 0.01:
			continue
		Geo.box(self, Vector3((s[0] + s[1]) * 0.5, height * 0.5, z), Vector3(w, height, 0.04), glass, false)
		Geo.blocker(self, Vector3((s[0] + s[1]) * 0.5, height * 0.5, z), Vector3(w, height, 0.4))
	for g in sorted:
		var w2: float = g[1] - g[0]
		var top: float = g[2]
		Geo.box(self, Vector3((g[0] + g[1]) * 0.5, (height + top) * 0.5, z), Vector3(w2, height - top, 0.04), glass, false)
		Geo.box(self, Vector3((g[0] + g[1]) * 0.5, top + 0.1, z), Vector3(w2 + 0.2, 0.2, 0.25), frame, false)
		Geo.blocker(self, Vector3((g[0] + g[1]) * 0.5, (height + top) * 0.5, z), Vector3(w2, height - top, 0.4))
	while x <= b.x + 0.01:
		var in_gap := false
		for g in sorted:
			if x > g[0] - 0.1 and x < g[1] + 0.1:
				in_gap = true
		if x >= a.x - 0.01 and not in_gap:
			Geo.box(self, Vector3(x, height * 0.5, z), Vector3(0.14, height, 0.22), frame, false)
		x += step
	for y in transoms + [height - 0.1]:
		for s in segs:
			var w3: float = s[1] - s[0]
			if w3 > 0.01:
				Geo.box(self, Vector3((s[0] + s[1]) * 0.5, y, z), Vector3(w3, 0.12, 0.18), frame, false)


# --------------------------------------------------------------------------------------------
## Baggage claim (baggage sketch): carousels out of the west wall with number towers, B-03 the working loop,
## the staff passage from the strip arriving at its north-east corner, the corridor opening in its east wall.
func _build_baggage() -> void:
	var r := Rect2(-36, -64, 26, 24.4)
	_floor(r, "floor")
	_ceiling(r, BAG_H)
	var wm := Mats.get_mat("wall")
	Geo.wall(self, Vector2(-36, -39.6), Vector2(-12.4, -39.6), BAG_H + 0.2, wm)
	Geo.wall(self, Vector2(-36, -64), Vector2(-36, -39.6), BAG_H + 0.2, wm, 0.4, [[13.0, 15.0, 2.4]])
	Geo.wall(self, Vector2(-36, -64), Vector2(-10, -64), BAG_H + 0.2, wm)
	# staff passage (strip -> hall), part of the baggage zone
	var pr := Rect2(-12.4, -39.6, 2.4, 31.1)
	_floor(pr, "floor_service")
	_ceiling(pr, 3.0, "ceiling_dark")
	Geo.wall(self, Vector2(-12.4, -39.6), Vector2(-12.4, -8.5), 3.0, Mats.get_mat("wall_service"), 0.3)
	# beams across the hall every 6 m, pilasters on the west wall under them
	for zz in [-45.6, -51.6, -57.6]:
		Geo.box(self, Vector3(-23, BAG_H - 0.175, zz), Vector3(26, 0.35, 0.5), wm, false)
		Geo.box(self, Vector3(-35.72, BAG_H * 0.5, zz), Vector3(0.16, BAG_H, 0.46), wm)      # a hair thinner than the beam
	var z: LightZone = zones.baggage
	var k := 0
	for x in [-31.0, -24.0, -17.0]:
		for zz in [-42.6, -48.6, -54.6, -60.6]:
			z.add_panel(Vector3(x, BAG_H - 0.04, zz), Vector2(1.6, 0.16), k % 3 != 1, 1.5, 10.0)
			k += 1
	for x in [-27.5, -20.5, -13.5]:
		for zz in [-45.6, -57.6]:
			if TripoProps.exists("common", "CMN_ACCassette"):
				LevelKit.ceiling_prop(self, "CMN_ACCassette", Vector3(x, 0, zz + 3.0), BAG_H, 0.0, 0.045)
	for zz in [-14.0, -22.0, -30.0, -37.0]:
		z.add_panel(Vector3(-11.2, 2.96, zz), Vector2(0.3, 1.2), true, 0.6, 6.0)
	z.add_hum(Vector3(-23, 3.2, -52), -18.0)
	# decorative carousels B-01 / B-02 fed through the west wall
	var bays := [[-45.2, 1], [-52.0, 2]]
	for b in bays:
		var cz: float = b[0]
		var car := Node3D.new()
		add_child(car)
		car.position = Vector3(-30.4, 0, cz)
		car.add_child(CarouselMesh.hull(3.4, 1.25))
		car.add_child(CarouselMesh.plates_static(3.4, 1.25))
		Geo.blocker(car, Vector3(0, 0.45, 0), Vector3(10.7, 0.9, 3.9))
		var cap := Geo.label(car, tr("B-%02d  운영 준비 중") % b[1], Vector3(0.6, CarouselMesh.ISLAND_Y + 0.004, 0), 0.0, 40, Color(0.25, 0.27, 0.3), 0.005, false, "print")
		cap.rotation.x = -PI / 2
		Geo.fit(cap, 5.0, 1.1)
		cap.set_meta("no_fit", true)
		LevelKit.number_pillar(self, Vector3(-33.7, 0, cz), b[1], 90.0)
		if TripoProps.exists("baggage", "BAG_FeedPortal"):
			LevelKit.mount(self, "baggage", "BAG_FeedPortal", Vector3(-35.8, 0.35, cz - 1.4), 90.0)
	LevelKit.number_pillar(self, Vector3(-33.6, 0, BELT_POS.z - 1.6), 3, 90.0)
	signs["baggage_main"] = Props.hanging_sign(self, Vector3(-25.5, 2.5, -55.4), 0.0, Vector2(4.4, 0.8), [
		["수하물 수취대  B-03", 52, Color(1, 1, 1), Vector2(0, 0)],
	], BAG_H)
	LevelKit.hanging_sign(self, Vector3(-20.0, BAG_H, -42.4), 0.0, "수하물 수취\nBaggage Claim")
	# waiting seats along the east side, bins, and the (locked) arrivals exit in the far (north) wall
	for zz in [-55.0, -57.2, -59.4, -61.6]:
		LevelKit.prop(self, "baggage", "BAG_RowSeating", Vector3(-11.6, 0, zz), -90.0)
	for p in [Vector3(-11.6, 0, -53.6), Vector3(-11.6, 0, -63.2), Vector3(-34.9, 0, -41.0)]:
		LevelKit.prop(self, "baggage", "BAG_TrashBin", p)
	LevelKit.double_door(self, Vector3(-18.0, 0, -63.8), 0.0, "출구  EXIT")
	LevelKit.wall_sign(self, Vector3(-24.0, 2.3, -63.78), 0.0, "도착 출구  ARRIVALS EXIT", Vector2(2.4, 0.45), "icon_arrow")
	# maintenance door (keypad) in the west wall
	doors["maint"] = SlidingDoor.create(self, Vector3(-36, 0, -50), PI / 2, 1.8, 2.4, false, false)
	LevelKit.plate(self, "plate_maint", Vector3(-35.8, 1.72, -48.55), 90.0, Vector2(0.6, 0.4), 0.3)
	LevelKit.plate(self, "plate_staffonly", Vector3(-35.8, 1.24, -48.55), 90.0, Vector2(0.42, 0.28), 0.15)
	var kp := Props.panel_box(self, Vector3(-35.8, 1.3, -51.4), PI / 2, Vector2(0.2, 0.28), "")
	for i in 9:
		Geo.box(kp, Vector3(-0.05 + (i % 3) * 0.05, 0.05 - (i / 3) * 0.05, 0.006), Vector3(0.035, 0.035, 0.01), Mats.get_mat("plastic_white"), false)
	Geo.box(kp, Vector3(0, 0.11, 0.006), Vector3(0.14, 0.03, 0.01), Mats.get_mat("lamp_red"), false)
	keypad = Interactable.create(kp, Vector3(0, 0, 0.05), Vector3(0.25, 0.32, 0.1), "도어락 비밀번호 입력", Callable())
	keypad.press_sound = "keypad_beep"
	# the staff passage is closed until DAY 2 (zones open one per day)
	shutters["baggage"] = Shutter.create(self, Vector3(-11.2, 0, -8.5), 0.0, 1.5, 2.4, "점검 구역 외 · 통제")


# --------------------------------------------------------------------------------------------
func _build_security() -> void:
	var r: Rect2 = ZONE_RECTS.security
	_floor(r, "floor")
	_ceiling(r, SEC_H)
	var wm := Mats.get_mat("wall")
	Geo.wall(self, Vector2(-10, -27.3), Vector2(-10, -8.5), SEC_H + 0.2, wm)
	Geo.wall(self, Vector2(10, -27.3), Vector2(10, -8.5), SEC_H + 0.2, wm)
	Geo.wall(self, Vector2(-10, -27.3), Vector2(10, -27.3), SEC_H + 0.2, wm, 0.4, [[6.0, 14.0, 3.4]])
	shutters["security"] = Shutter.create(self, Vector3(0, 0, -8.5), 0.0, 12.0, SEC_H, "점검 구역 외 · 통제")
	shutters["corridor"] = Shutter.create(self, Vector3(0, 0, -27.3), 0.0, 8.0, 3.4, "점검 구역 외 · 통제")
	# coffered ceiling: beams on a 3 m grid, a troffer in every coffer (some lit)
	var bm := Mats.std(Color(0.8, 0.8, 0.78), 0.8)
	for zz in [-11.5, -14.5, -17.5, -20.5, -23.5]:
		Geo.box(self, Vector3(0, SEC_H - 0.225, zz), Vector3(20, 0.45, 0.4), bm, false)
	for x in [-7.0, -4.0, -1.0, 2.0, 5.0, 8.0]:     # 1 cm shallower than the cross beams so the crossings never fight
		Geo.box(self, Vector3(x, SEC_H - 0.22, -17.9), Vector3(0.38, 0.44, 18.8), bm, false)
	var z: LightZone = zones.security
	for x in [-8.5, -5.5, -2.5, 0.5, 3.5, 6.5, 9.0]:
		for zz in [-10.0, -13.0, -16.0, -19.0, -22.0, -25.4]:
			var lit: bool = x in [-5.5, 0.5, 6.5] and zz in [-10.0, -16.0, -22.0]
			z.add_panel(Vector3(x, SEC_H - 0.04, zz), Vector2(1.1, 0.5), lit, 1.3, 9.0)
	z.add_hum(Vector3(0, 3.8, -18), -20.0)
	for x: float in LANE_X:
		LevelKit.metal_detector(self, Vector3(x + MD_DX, 0, LANE_Z))
		# queue line beside the detector approach
		LevelKit.stanchions(self, [Vector3(x + MD_DX + 0.8, 0, -12.6), Vector3(x + MD_DX + 0.8, 0, -14.4), Vector3(x + MD_DX + 0.8, 0, -16.2)])
	for i in LANE_X.size():
		LevelKit.hanging_sign(self, Vector3(LANE_X[i] + 1.2, SEC_H, -13.0), 0.0, tr("수하물 검색 %d\nBAGGAGE INSPECTION %d") % [i + 1, i + 1])
	# repacking benches along both side walls
	for zz in [-14.85, -16.95, -19.05, -21.15]:
		LevelKit.prop(self, "security", "SEC_InspectionTable", Vector3(-9.45, 0, zz), 90.0)
		LevelKit.prop(self, "security", "SEC_InspectionTable", Vector3(9.45, 0, zz), -90.0)
	signs["security_main"] = Props.hanging_sign(self, Vector3(0, 3.2, -26.0), 0.0, Vector2(6.0, 0.9), [
		["@icon_departures", 0.62, Color(1, 1, 1), Vector2(-2.45, 0.0)],
		["↑  탑승동  GATES 01 — 04", 52, Color(1, 1, 1), Vector2(0.35, 0.12)],
		["무빙워크 MW-1", 34, Color(0.8, 0.85, 0.95), Vector2(0.35, -0.24)],
	], SEC_H)
	Props.lightbox(self, Vector3(-9.78, 2.2, -11.2), PI / 2, Vector2(2.6, 1.2), "액체류 100ml 제한", "LIQUIDS LIMIT 100ml")
	Props.lightbox(self, Vector3(9.78, 2.2, -11.2), -PI / 2, Vector2(2.6, 1.2), "보안검색  SECURITY", "탑승권을 준비해 주세요")
	# tray stack at the lane entry
	LevelKit.prop(self, "security", "SEC_InspectionTable", Vector3(-7.6, 0, -10.4), 0.0)
	for i in 5:
		Geo.box(self, Vector3(-7.6, 0.82 + i * 0.07, -10.4), Vector3(0.6, 0.06, 0.45), Mats.std(Color(0.3, 0.32, 0.36), 0.5), false)


# --------------------------------------------------------------------------------------------
func _build_corridor() -> void:
	var r: Rect2 = ZONE_RECTS.corridor
	_floor(r, "floor")
	_ceiling(r, COR_H)
	var wm := Mats.get_mat("wall")
	# west: glazed white tile, the public opening into baggage claim (opens with the corridor)
	Geo.wall(self, Vector2(-10, -76), Vector2(-10, -27.3), COR_H, Mats.get_mat("wall_tile"), 0.4, [[24.0, 30.0, 3.0]])
	var bs := Shutter.create(self, Vector3(-10, 0, -49), PI / 2, 6.0, 3.0, "점검 구역 외 · 통제")
	shutters["corridor_baggage"] = bs
	# east windows onto the apron
	var frame := Mats.get_mat("steel_frame")
	var len_z := 48.7
	var cz := -51.65
	Geo.box(self, Vector3(10, 0.4, cz), Vector3(0.4, 0.8, len_z), wm)
	Geo.box(self, Vector3(10, 4.25, cz), Vector3(0.4, 0.5, len_z), wm, false)
	Geo.box(self, Vector3(10, 2.4, cz), Vector3(0.04, 3.2, len_z), Mats.get_mat("glass"), false)
	Geo.blocker(self, Vector3(10, 2.25, cz), Vector3(0.4, 4.5, len_z))
	var zz := -27.3
	while zz >= -76.0:
		Geo.box(self, Vector3(10, 2.4, zz), Vector3(0.22, 3.2, 0.14), frame, false)
		zz -= 4.0
	Geo.box(self, Vector3(9.7, 0.82, cz), Vector3(0.3, 0.05, len_z), frame, false)
	var z: LightZone = zones.corridor
	var lz := -31.0
	var k := 0
	while lz >= -73.0:
		z.add_panel(Vector3(-3.6, COR_H - 0.06, lz), Vector2(0.5, 4.0), true, 1.2, 9.0)
		z.add_panel(Vector3(5.0, COR_H - 0.06, lz - 3.0), Vector2(0.5, 4.0), k % 2 == 0, 1.0, 8.0)
		lz -= 6.0
		k += 1
	z.add_hum(Vector3(0, 4, -40), -22.0)
	z.add_hum(Vector3(0, 4, -64), -22.0)
	# lightbox ads on the west wall
	var ads := [
		["서해국제공항", "바다 위의 첫 관문  SEOHAE INT'L AIRPORT", -31.4],
		["집으로 가는 가장 빠른 길", "The fastest way HOME", -36.2],
		["GRAND OPENING", "2026. 10. 23", -67.0],
		["어디로 떠나시나요?", "Where are you going?", -71.8],
	]
	for a in ads:
		var lb := Props.lightbox(self, Vector3(-9.78, 2.1, a[2]), PI / 2, Vector2(3.2, 1.6), a[0], a[1])
		zones.corridor.add_light(Geo.omni(lb, Vector3(0, 0, 1.0), Color(0.8, 0.88, 1.0), 0.4, 4.0))
	LevelKit.wall_sign(self, Vector3(-9.78, 3.6, -49.0), 90.0, "◀  수하물 수취  BAGGAGE CLAIM", Vector2(3.2, 0.55), "icon_luggage")
	signs["corridor_mid"] = Props.hanging_sign(self, Vector3(-3.0, 3.3, -54.0), 0.0, Vector2(4.6, 0.8), [
		["@icon_departures", 0.56, Color(1, 1, 1), Vector2(-1.75, 0.0)],
		["↑  GATES 01 — 04", 56, Color(1, 1, 1), Vector2(0.35, 0)],
	], COR_H)
	# second walkway (MW-2) beside MW-1, not commissioned yet
	var mw2 := Vector3(6.7, 0, -31.3)
	var run := LevelKit.walkway_run(self, mw2, 8)
	var plate := LevelKit.sign_body(self, mw2 + Vector3(0, 1.25, 0.4), 0.0, Vector2(1.2, 0.42))
	Geo.fit(Geo.label(plate, "MW-2  운행 준비 중\nNOT IN SERVICE", Vector3(0, 0, plate.get_meta("face_z") + 0.004), 0.0, 44, LevelKit.INK, 0.004), 1.1, 0.36).set_meta("no_fit", true)
	Geo.box(self, mw2 + Vector3(0, 0.6, 0.4), Vector3(0.05, 1.2, 0.05), frame, false)
	Geo.blocker(self, mw2 + Vector3(0, 0.6, -run * 0.5), Vector3(1.6, 1.2, run))
	shutters["gates"] = Shutter.create(self, Vector3(0, 0, -76.0), 0.0, 20.0, 4.5, "점검 구역 외 · 통제")
	shutters.corridor.linked.append(bs)


# --------------------------------------------------------------------------------------------
func _build_gates() -> void:
	var r: Rect2 = ZONE_RECTS.gates
	_floor(r, "carpet")
	Geo.box(self, Vector3(0, 0.003, -88), Vector3(6.0, 0.01, 24.0), Mats.get_mat("floor"), false)
	_ceiling(r, 5.5)
	var wm := Mats.get_mat("wall")
	Geo.wall(self, Vector2(-26, -76), Vector2(26, -76), 5.5, wm, 0.4, [[16.0, 36.0, 4.5]])
	Geo.wall(self, Vector2(-26, -100), Vector2(-26, -76), 5.5, wm, 0.4, [[4.7, 7.3, 3.0], [16.7, 19.3, 3.0]])
	Geo.wall(self, Vector2(26, -100), Vector2(26, -76), 5.5, wm, 0.4, [[4.7, 7.3, 3.0], [16.7, 19.3, 3.0]])
	# north window wall (Gate 0 hides in the centre section)
	var frame := Mats.get_mat("steel_frame")
	Geo.box(self, Vector3(-24, 2.75, -100), Vector3(4.0, 5.5, 0.4), wm)
	Geo.box(self, Vector3(24, 2.75, -100), Vector3(4.0, 5.5, 0.4), wm)
	for s in [[-22.0, -1.5], [1.5, 22.0]]:
		var cx: float = (s[0] + s[1]) * 0.5
		var w: float = s[1] - s[0]
		Geo.box(self, Vector3(cx, 0.25, -100), Vector3(w, 0.5, 0.4), wm)
		Geo.box(self, Vector3(cx, 2.75, -100), Vector3(w, 4.5, 0.04), Mats.get_mat("glass"), false)
		Geo.blocker(self, Vector3(cx, 2.75, -100), Vector3(w, 5.5, 0.4))
		Geo.box(self, Vector3(cx, 5.25, -100), Vector3(w, 0.5, 0.4), wm, false)
		var mx: float = s[0]
		while mx <= s[1] + 0.01:
			Geo.box(self, Vector3(mx, 2.75, -100), Vector3(0.14, 4.5, 0.22), frame, false)
			mx += 3.0
	gate0_wall = Node3D.new()
	add_child(gate0_wall)
	Geo.box(gate0_wall, Vector3(0, 2.75, -100), Vector3(3.0, 5.5, 0.6), wm)
	var plaque := Geo.label(gate0_wall, "", Vector3(0, 1.6, -99.68), 0.0, 30, Color(0.4, 0.4, 0.4), 0.004, false, "engrave")
	plaque.name = "Gate0Hint"
	# lights
	var z: LightZone = zones.gates
	# continuous linear slot lights, as in a real gate lounge
	for x in [-18.0, -6.0, 6.0, 18.0]:
		for zz in [-81.0, -88.0, -95.0]:
			z.add_panel(Vector3(x, 5.42, zz), Vector2(10.0, 0.35), true, 2.0, 14.0)
	z.add_hum(Vector3(0, 5, -88), -20.0)
	# central seating facing the windows
	for x in [-9.0, 9.0]:
		for zz in [-85.0, -87.2, -91.5, -93.7]:
			Props.seat_row(self, Vector3(x, 0, zz), 8, PI)
	signs["gates_main"] = Props.hanging_sign(self, Vector3(0, 4.2, -79.0), 0.0, Vector2(9.0, 0.9), [
		["◀  GATE 01 · 02", 52, Color(1, 1, 1), Vector2(-2.3, 0)],
		["@icon_departures", 0.62, Color(1, 1, 1), Vector2(0, 0)],
		["GATE 03 · 04  ▶", 52, Color(1, 1, 1), Vector2(2.3, 0)],
	], 5.5)
	for p in [Vector3(-20, 0, -76.5), Vector3(20, 0, -76.5)]:     # against the gate hall's north wall
		Props.trash_bin(self, p)
	for p in [Vector3(-24.5, 0, -98.5), Vector3(24.5, 0, -98.5)]:
		Props.planter(self, p)
	# gate ID wall plates near the corridor
	Props.exit_sign(self, Vector3(-25.75, 2.8, -88), PI / 2, "비상구  EXIT")


# --------------------------------------------------------------------------------------------
func _build_service_rooms() -> void:
	var sm := Mats.get_mat("wall_service")
	# storage room east of the strip (자재창고)
	var sr: Rect2 = ZONE_RECTS.storage
	_floor(sr, "floor_service")
	_ceiling(sr, 3.2, "ceiling_dark")
	Geo.wall(self, Vector2(12, -8.5), Vector2(22, -8.5), 3.2, sm)
	Geo.wall(self, Vector2(22, -8.5), Vector2(22, -2.5), 3.2, sm)
	Geo.wall(self, Vector2(12, -2.5), Vector2(22, -2.5), 3.2, sm)
	var svc: LightZone = zones.service
	svc.add_panel(Vector3(17, 3.15, -5.5), Vector2(1.2, 0.3), true, 0.6, 7.0, Color(1.0, 0.92, 0.75), true)
	for i in 4:
		Geo.box(self, Vector3(16.0, 0.4 + i * 0.6, -8.0), Vector3(6.0, 0.05, 0.6), Mats.get_mat("metal_dark"), false)
	Geo.blocker(self, Vector3(16.0, 1.2, -8.0), Vector3(6.0, 2.4, 0.7))
	for p in [Vector3(14.0, 0.65, -8.0), Vector3(17.0, 1.25, -8.0), Vector3(18.0, 0.65, -8.0)]:
		Geo.box(self, p, Vector3(0.7, 0.4, 0.5), Mats.std(Color(0.45, 0.35, 0.22), 0.8), false)
	for p in [Vector3(20.5, 0.4, -4.0), Vector3(21.0, 0.4, -3.2), Vector3(20.7, 1.1, -3.7)]:
		Geo.box(self, p, Vector3(0.8, 0.8, 0.8), Mats.std(Color(0.5, 0.4, 0.26), 0.85))
	doors["storage"] = SlidingDoor.create(self, Vector3(12, 0, -5.5), PI / 2, 1.8, 2.4, false, true)
	LevelKit.plate(self, "plate_storage", Vector3(11.8, 1.72, -4.05), -90.0, Vector2(0.6, 0.4), 0.3)
	# maintenance passage west of baggage claim
	var mr: Rect2 = ZONE_RECTS.maint
	_floor(mr, "floor_service")
	_ceiling(mr, 3.0, "ceiling_dark")
	Geo.wall(self, Vector2(-48, -53), Vector2(-36, -53), 3.0, sm)
	Geo.wall(self, Vector2(-48, -47), Vector2(-36, -47), 3.0, sm)
	Geo.wall(self, Vector2(-48, -53), Vector2(-48, -47), 3.0, sm)
	svc.add_panel(Vector3(-42, 2.95, -50), Vector2(1.2, 0.3), true, 0.5, 7.0, Color(1.0, 0.92, 0.75))
	for i in 4:
		Geo.cyl(self, Vector3(-46.5 + i * 3.0, 2.6, -47.4), 0.08, 0.1, Mats.get_mat("metal"))
	Geo.box(self, Vector3(-42, 2.6, -47.35), Vector3(12, 0.12, 0.12), Mats.get_mat("metal_dark"), false)
	# main power lever (west end)
	main_power = Equipment.main_power(self, Vector3(-47.78, 1.4, -50), PI / 2)
	# system log terminal (north wall)
	var term := Node3D.new()
	add_child(term)
	term.position = Vector3(-42, 0, -52.5)
	if TripoProps.exists("terminal", "TRM_InfoDesk"):
		TripoProps.spawn(term, "terminal", "TRM_InfoDesk", Vector3.ZERO, PI, false, null, Vector3(1.2, 0.9, 0.6))
		Geo.blocker(term, Vector3(0, 0.45, 0), Vector3(1.2, 0.9, 0.6))
	else:
		Geo.box(term, Vector3(0, 0.45, 0), Vector3(1.2, 0.9, 0.6), Mats.get_mat("metal_dark"))
	var scr := Props.monitor(term, Vector3(0, 0.95, 0.05), 0.0, Vector2(0.5, 0.32))
	scr.material_override = Mats.emissive(Color(0.25, 0.9, 0.4), 0.7)
	syslog_terminal = Interactable.create(term, Vector3(0, 1.0, 0.3), Vector3(0.8, 0.6, 0.4), "시스템 로그 확인", Callable())


# --------------------------------------------------------------------------------------------
func _build_outside() -> void:
	Geo.box(self, Vector3(0, -0.2, -60), Vector3(500, 0.2, 480), Mats.get_mat("asphalt"), false)
	Geo.blocker(self, Vector3(0, -0.15, -60), Vector3(500, 0.1, 480))
	var paint := Mats.get_mat("yellow_paint")
	# apron markings (east of the corridor, and south of the lobby glass)
	for i in 12:
		Geo.box(self, Vector3(30.0, -0.09, -40.0 - i * 5.0), Vector3(0.25, 0.01, 3.0), paint, false)
	Geo.box(self, Vector3(0, -0.09, -150), Vector3(0.3, 0.01, 60), paint, false)
	for i in 16:
		Geo.box(self, Vector3(-60.0 + i * 6.0, -0.09, 46.0), Vector3(3.0, 0.01, 0.25), paint, false)
	Geo.box(self, Vector3(-14.0, -0.09, 98.0), Vector3(120.0, 0.01, 0.3), paint, false)
	# taxiway / runway lights
	var amber := Mats.get_mat("runway_light")
	var blue := Mats.get_mat("runway_blue")
	for i in 60:
		var x := -150.0 + i * 5.0
		Geo.box(self, Vector3(x, 0.0, -190.0), Vector3(0.25, 0.15, 0.25), amber, false)
		Geo.box(self, Vector3(x, 0.0, -230.0), Vector3(0.25, 0.15, 0.25), amber, false)
		Geo.box(self, Vector3(x, 0.0, 160.0), Vector3(0.25, 0.15, 0.25), amber, false)
		if i % 2 == 0:
			Geo.box(self, Vector3(x, 0.0, -170.0), Vector3(0.2, 0.12, 0.2), blue, false)
			Geo.box(self, Vector3(x, 0.0, 130.0), Vector3(0.2, 0.12, 0.2), blue, false)
	for i in 20:
		Geo.box(self, Vector3(60.0, 0.0, -20.0 - i * 8.0), Vector3(0.2, 0.12, 0.2), blue, false)
	# apron floodlight masts (east of the corridor, north at the gates, south in front of the lobby)
	for p in [Vector3(40, 0, -45), Vector3(40, 0, -70), Vector3(-30, 0, -130), Vector3(30, 0, -130),
			Vector3(-46, 0, 62), Vector3(26, 0, 92)]:
		Geo.cyl(self, p + Vector3(0, 12, 0), 0.25, 24, Mats.get_mat("steel_frame"))
		Geo.box(self, p + Vector3(0, 24, 0), Vector3(2.0, 0.6, 0.6), Mats.get_mat("lamp_white"), false)
		var sl := Geo.spot(self, p + Vector3(0, 23.5, 0), p + Vector3(-6, 0, 0), Color(1.0, 0.85, 0.6), 6.0, 60.0, 50.0)
		sl.spot_attenuation = 1.0
		sl.light_volumetric_fog_energy = 0.3
		outside_lights.append(sl)
	# control tower far out on the airfield, seen through the lobby glass
	var tower := Node3D.new()
	add_child(tower)
	tower.position = Vector3(48, 0, 260)
	Geo.cyl(tower, Vector3(0, 22, 0), 2.2, 44, Mats.get_mat("concrete"), false, 16)
	Geo.cyl(tower, Vector3(0, 46.5, 0), 5.2, 5.0, Mats.get_mat("glass"), false, 8)
	Geo.cyl(tower, Vector3(0, 49.5, 0), 5.8, 1.0, Mats.get_mat("steel_frame"), false, 8)
	Geo.cyl(tower, Vector3(0, 44.0, 0), 4.6, 0.6, Mats.get_mat("steel_frame"), false, 8)
	var cab := Geo.omni(tower, Vector3(0, 46.5, 0), Color(0.55, 0.85, 0.7), 1.5, 14.0)
	cab.light_volumetric_fog_energy = 0.6
	outside_lights.append(cab)
	Geo.box(tower, Vector3(0, 51.0, 0), Vector3(0.3, 0.3, 0.3), Mats.get_mat("lamp_red"), false)
	# parked aircraft: one off the corridor windows, one on the apron south of the lobby glass
	_aircraft(Vector3(45, 0, -58), PI, false)
	_aircraft(Vector3(18, 0, 104), PI / 2, false)
	# the impossible aircraft at Gate 0 (finale only)
	final_plane = _aircraft(Vector3(0, 0, -168), 0.0, true)
	final_plane.visible = false


func _aircraft(pos: Vector3, rot_y: float, gate0: bool) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	root.rotation.y = rot_y
	if TripoProps.exists("apron", "APR_Aircraft"):
		return _tripo_aircraft(root, gate0)
	var body := Mats.get_mat("plane_body")
	var dark := Mats.get_mat("plane_dark")
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
	var red := Geo.omni(root, Vector3(-29, 3.4, 2.0), Color(1, 0.1, 0.05), 1.0, 6.0)
	var green := Geo.omni(root, Vector3(29, 3.4, 2.0), Color(0.1, 1, 0.2), 1.0, 6.0)
	Geo.box(root, Vector3(-29, 3.4, 2.0), Vector3(0.3, 0.3, 0.3), Mats.get_mat("lamp_red"), false)
	Geo.box(root, Vector3(29, 3.4, 2.0), Vector3(0.3, 0.3, 0.3), Mats.get_mat("lamp_green"), false)
	if gate0:
		var cabin := Geo.omni(root, Vector3(0, 4.6, 26.0), Color(1.0, 0.9, 0.7), 2.0, 10.0)
		cabin.light_volumetric_fog_energy = 2.0
		Geo.label(root, "SH 000", Vector3(2.62, 6.2, 12.0), PI / 2, 200, Color(0.1, 0.1, 0.12), 0.02, false, "print")
	else:
		Geo.label(root, "SEOHAE", Vector3(2.62, 6.2, 8.0), PI / 2, 200, Color(0.08, 0.2, 0.5), 0.02, false, "print")
	red.light_volumetric_fog_energy = 1.0
	green.light_volumetric_fog_energy = 1.0
	return root


## Tripo airliner 61 m long (nose +Z); nav lights on its wingtips, the registration on the fuselage's right side.
func _tripo_aircraft(root: Node3D, gate0: bool) -> Node3D:
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
	var tip := bb.size.x * k * 0.5 - 0.3
	var red := Geo.omni(root, Vector3(-tip, 3.4, 2.0), Color(1, 0.1, 0.05), 1.0, 6.0)
	var green := Geo.omni(root, Vector3(tip, 3.4, 2.0), Color(0.1, 1, 0.2), 1.0, 6.0)
	red.light_volumetric_fog_energy = 1.0
	green.light_volumetric_fog_energy = 1.0
	if gate0:
		var cabin := Geo.omni(root, Vector3(0, side.y, 26.0), Color(1.0, 0.9, 0.7), 2.0, 10.0)
		cabin.light_volumetric_fog_energy = 2.0
		Geo.label(root, "SH 000", Vector3(side.x + 0.05, side.y + 0.6, 12.0), PI / 2, 200, Color(0.1, 0.1, 0.12), 0.02, false, "print")
	else:
		Geo.label(root, "SEOHAE", Vector3(side.x + 0.05, side.y + 0.6, 8.0), PI / 2, 200, Color(0.08, 0.2, 0.5), 0.02, false, "print")
	return root


# --------------------------------------------------------------------------------------------
func _build_facility_systems() -> void:
	# lighting panels
	lights_panel = LightPanel.new()
	lights_panel.id = "lights"
	lights_panel.title = "조명 분전반"
	lights_panel.short_name = "LP-1"
	lights_panel.zone = "hall"
	add_child(lights_panel)
	lights_panel.position = spot("look_lights")
	lights_panel.rotation.y = PI / 2
	lights_panel.build(zones, ["hall", "baggage", "security", "corridor", "gates"])
	facilities["lights"] = lights_panel
	lights_panel_gates = LightPanel.new()
	lights_panel_gates.id = "lights_gates"
	lights_panel_gates.title = "게이트 조명 스위치"
	lights_panel_gates.zone = "gates"
	add_child(lights_panel_gates)
	lights_panel_gates.position = Vector3(-11.5, 1.45, -76.22)
	lights_panel_gates.rotation.y = PI
	lights_panel_gates.build(zones, ["corridor", "gates"], "구역 조명  LIGHTING")
	for zn in lights_panel.switches.keys():
		lights_panel.switches[zn].toggled.connect(func(on): _sync_switch(zn, on))
	for zn in lights_panel_gates.switches.keys():
		lights_panel_gates.switches[zn].toggled.connect(func(on): _sync_switch(zn, on))
	# FIDS side by side on the hall's north wall right above the opening into security (face z -2.3), where the
	# whole lobby sees them (they used to sit in the alcoves behind the check-in blocks); the RESET box is on the
	# wall left of the opening at hand height
	var fids := FidsBoard.new()
	fids.id = "fids"
	fids.title = "FIDS 출발 전광판"
	fids.short_name = "FIDS-01"
	fids.zone = "hall"
	add_child(fids)
	fids.position = Vector3(-2.45, 5.8, -2.07)
	fids.build(4.4, 2.05, true)
	fids.control_box.position = Vector3(-5.95, 1.45, -2.23) - fids.position
	facilities["fids"] = fids
	arrivals = FidsBoard.new()
	arrivals.id = "fids_arr"
	arrivals.zone = "hall"
	add_child(arrivals)
	arrivals.position = Vector3(2.45, 5.8, -2.07)
	arrivals.build(4.4, 2.05, false)
	arrivals.screen.title = "도착  ARRIVALS"
	arrivals.screen.icon = load("res://assets/textures/level/icon_arrivals.png")
	arrivals.set_story("message", ["운영 준비 중", "NOT IN SERVICE"])
	# PA console on the broadcast desk
	var pa := PaConsole.new()
	pa.id = "pa"
	pa.title = "안내방송 콘솔"
	pa.short_name = "PA-01"
	pa.zone = "hall"
	add_child(pa)
	pa.position = Vector3(0.2, 1.0, 5.85)
	pa.build()
	facilities["pa"] = pa
	# baggage
	var belt := BaggageBelt.new()
	belt.id = "baggage"
	belt.title = "수하물 수취대 B-03"
	belt.short_name = "B-03"
	belt.zone = "baggage"
	add_child(belt)
	belt.position = BELT_POS
	belt.build()
	facilities["baggage"] = belt
	var bp := Props.pedestal(self, Vector3(-33.6, 0, -57.4), -PI / 2, "B-03 제어")
	Props.button(bp, Vector3(-0.18, -0.03, 0), 0.0, "button_green", "가동", "벨트 가동", belt.press_start)
	Props.button(bp, Vector3(0.0, -0.03, 0), 0.0, "button_white", "정지", "벨트 정지", belt.press_stop)
	Props.button(bp, Vector3(0.18, -0.03, 0), 0.0, "button_red", "비상정지", "벨트 비상정지", belt.press_estop, 0.06)
	# moving walkway
	var mw := MovingWalkway.new()
	mw.id = "walkway"
	mw.title = "무빙워크 MW-1"
	mw.short_name = "MW-1"
	mw.zone = "corridor"
	add_child(mw)
	mw.position = Vector3(3.4, 0, -31.3)
	mw.build(40.0)
	facilities["walkway"] = mw
	var wp := Props.pedestal(self, Vector3(1.2, 0, -29.6), 0.0, "MW-1 제어")
	Props.button(wp, Vector3(-0.18, -0.03, 0), 0.0, "button_green", "가동", "무빙워크 가동", mw.press_start)
	Props.button(wp, Vector3(0.0, -0.03, 0), 0.0, "button_white", "정지", "무빙워크 정지", mw.press_stop)
	Props.button(wp, Vector3(0.18, -0.03, 0), 0.0, "button_red", "비상정지", "무빙워크 비상정지", mw.press_estop, 0.06)
	# X-ray lanes
	var xr := XrayMachine.new()
	xr.id = "xray"
	xr.title = "보안검색 X-ray 1번"
	xr.short_name = "X-1"
	xr.zone = "security"
	add_child(xr)
	xr.position = Vector3(LANE_X[0], 0, LANE_Z)
	xr.build()
	facilities["xray"] = xr
	var xr2 := XrayMachine.new()
	xr2.id = "xray2"
	xr2.zone = "security"
	add_child(xr2)
	xr2.position = Vector3(LANE_X[1], 0, LANE_Z)
	xr2.build()
	# boarding gates
	var gate_defs := [["01", Vector3(-26, 0, -82), PI / 2], ["02", Vector3(-26, 0, -94), PI / 2],
		["03", Vector3(26, 0, -82), -PI / 2], ["04", Vector3(26, 0, -94), -PI / 2]]
	for g in gate_defs:
		var gate := BoardingGate.new()
		gate.id = "gate" + g[0]
		gate.title = tr("탑승구 GATE ") + g[0]
		gate.short_name = "GATE " + g[0]
		gate.zone = "gates"
		add_child(gate)
		gate.position = g[1]
		gate.rotation.y = g[2]
		gate.build(g[0])
		facilities[gate.id] = gate
		gates[g[0]] = gate
		var gp: Vector3 = g[1] + Basis(Vector3.UP, g[2]) * Vector3(0, 0, 3.5)
		zones.gates.add_panel(Vector3(gp.x, 5.42, gp.z), Vector2(1.2, 1.2), true, 1.6, 10.0, Color(1.0, 0.93, 0.8))
	# breaker panel in the office
	breaker = BreakerPanel.new()
	add_child(breaker)
	breaker.position = Vector3(-13.3, 1.5, -2.28)
	breaker.build([
		["fids", "FIDS", [fids]],
		["pa", "PA", [pa]],
		["baggage", "B-03", [belt]],
		["walkway", "MW-1", [mw]],
		["xray", "X-RAY", [xr]],
		["gates", "GATES", [gates["01"], gates["02"], gates["03"], gates["04"]]],
	])
	# emergency lighting (only after main power is cut)
	emergency_light_root = Node3D.new()
	add_child(emergency_light_root)
	emergency_light_root.visible = false
	for p in [Vector3(-17, 2.4, 12.5), Vector3(-2, 3, 6), Vector3(-24, 3, -50), Vector3(-42, 2.5, -50)]:
		var el := Geo.omni(emergency_light_root, p, Color(0.2, 1.0, 0.35), 0.6, 9.0)
		el.light_volumetric_fog_energy = 1.5


func _build_gate0() -> void:
	gate0_parts = Node3D.new()
	add_child(gate0_parts)
	var g0 := BoardingGate.new()
	g0.id = "gate0"
	g0.title = "GATE 0"
	g0.short_name = "GATE 0"
	g0.zone = "gates"
	gate0_parts.add_child(g0)
	g0.position = Vector3(0, 0, -100)
	g0.build("0", false, false)
	gates["0"] = g0
	facilities["gate0"] = g0
	# long jet bridge to the impossible aircraft
	var br := Node3D.new()
	gate0_parts.add_child(br)
	var carpet := Mats.get_mat("carpet_red")
	var wallm := Mats.get_mat("wall_service")
	Geo.box(br, Vector3(0, -0.05, -120), Vector3(2.6, 0.1, 32), carpet, true)
	Geo.box(br, Vector3(0, 2.75, -120), Vector3(2.6, 0.1, 32), Mats.get_mat("ceiling_dark"), false)
	for sx in [-1.35, 1.35]:
		Geo.box(br, Vector3(sx, 1.35, -120), Vector3(0.1, 2.7, 32), wallm, true)
	for i in 6:
		var l := Geo.omni(br, Vector3(0, 2.4, -106 - i * 5.0), Color(1.0, 0.85, 0.6), 0.5, 4.5)
		l.light_volumetric_fog_energy = 1.5
		Geo.box(br, Vector3(0, 2.69, -106 - i * 5.0), Vector3(0.8, 0.02, 0.3), Mats.get_mat("lamp_white"), false)
	# aircraft door at the end of the bridge
	var door := Node3D.new()
	br.add_child(door)
	door.position = Vector3(0, 0, -135.6)
	Geo.box(door, Vector3(0, 1.35, -0.1), Vector3(2.6, 2.7, 0.2), Mats.get_mat("plane_body"), true)
	Geo.box(door, Vector3(0, 1.05, 0.01), Vector3(0.9, 1.9, 0.04), Mats.get_mat("plane_dark"), false)
	Geo.label(door, "HOME", Vector3(0, 2.2, 0.04), 0.0, 40, Color(0.9, 0.9, 0.9), 0.005, false, "print")
	Geo.blocker(br, Vector3(0, 1.35, -136), Vector3(2.6, 2.7, 0.4))
	triggers["board_door"] = Geo.area(br, Vector3(0, 1.0, -134.5), Vector3(2.4, 2.0, 1.6))
	Props.exit_sign(gate0_parts, Vector3(0, 4.3, -99.6), 0.0, "GATE 0  탑승")
	Geo.fit_labels(gate0_parts)


func _sync_switch(zone_name: String, on: bool) -> void:
	for panel in [lights_panel, lights_panel_gates]:
		if panel.switches.has(zone_name):
			panel.switches[zone_name].set_on(on)


func set_zone_light(zone_name: String, on: bool, instant := false) -> void:
	if zones.has(zone_name):
		zones[zone_name].set_on(on, instant)
	_sync_switch(zone_name, on)


func reveal_gate0() -> void:
	if gate0_parts != null:
		return
	_build_gate0()
	gate0_wall.visible = false
	for c in gate0_wall.get_children():
		if c is MeshInstance3D:
			for b in c.get_children():
				if b is StaticBody3D:
					b.collision_layer = 0
	gate0_parts.visible = true
	final_plane.visible = true


# --------------------------------------------------------------------------------------------
## Box-projected interior reflection probes so brushed steel (carousels, X-ray tunnels, stanchions, rails) and
## the glossy floors reflect the halls instead of nothing. Captured once with every zone lit; each probe then
## fades with its zone's lights so a dark hall does not keep shining.
func _build_probes() -> void:
	var defs := {
		"hall": [Vector3(-4, 3.75, 5.75), Vector3(32, 7.5, 16.5)],
		"security": [Vector3(0, 2.05, -17.9), Vector3(20, 4.1, 18.8)],
		"corridor": [Vector3(0, 2.25, -51.6), Vector3(20, 4.5, 48.7)],
		"baggage": [Vector3(-23, 1.8, -51.8), Vector3(26, 3.6, 24.4)],
		"gates": [Vector3(0, 2.75, -88), Vector3(52, 5.5, 24)],
	}
	for zn in defs:
		var probe := ReflectionProbe.new()
		probe.size = defs[zn][1]
		probe.box_projection = true
		probe.interior = true
		probe.update_mode = ReflectionProbe.UPDATE_ONCE
		probe.max_distance = 60.0
		probe.position = defs[zn][0]
		probe.intensity = 0.0
		_probes[zn] = probe
	# capture once the zones' lights have come up
	get_tree().create_timer(0.8).timeout.connect(func():
		for zn in _probes:
			add_child(_probes[zn]))


func _process(delta: float) -> void:
	for zn in _probes:
		var z: LightZone = zones[zn]
		var want := 0.7 if z.is_on and z.powered else 0.0
		var p: ReflectionProbe = _probes[zn]
		if p.is_inside_tree():
			p.intensity = move_toward(p.intensity, want, delta * 2.0)


## Reverb zones: every 3D sound (doors, machines, the colleague's voice) sends into the hall or room reverb of
## the zone it is played in, so the big halls ring and the small rooms stay dry. Rooms inside a hall win (priority).
func _build_reverb() -> void:
	var defs := {
		"hall": ["RevHall", 0.32, HALL_H], "security": ["RevMid", 0.28, SEC_H], "corridor": ["RevLong", 0.32, COR_H],
		"baggage": ["RevMid", 0.28, BAG_H], "gates": ["RevLong", 0.3, 5.5],
		"office": ["RevRoom", 0.22, 3.2], "storage": ["RevRoom", 0.24, 3.2], "maint": ["RevRoom", 0.26, 3.0],
		"bridge0": ["RevTight", 0.3, 2.8],
	}
	for zn in defs:
		var d: Array = defs[zn]
		for r: Rect2 in zone_rects(zn):
			var a := Area3D.new()
			a.name = "Reverb_" + zn
			a.collision_layer = Geo.LAYER_AUDIO
			a.collision_mask = 0
			a.monitoring = false
			a.reverb_bus_enabled = true
			a.reverb_bus_name = d[0]
			a.reverb_bus_amount = d[1]
			a.reverb_bus_uniformity = 0.4
			a.priority = 1 if d[0] in ["RevRoom", "RevTight"] else 0
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(r.size.x, d[2], r.size.y)
			cs.shape = box
			a.add_child(cs)
			add_child(a)
			a.position = Vector3(r.get_center().x, d[2] * 0.5, r.get_center().y)


# --------------------------------------------------------------------------------------------
func _define_spawns() -> void:
	spawns["office"] = Transform3D(Basis(Vector3.UP, PI), Vector3(-15.8, 0.05, 2.2))
	spawns["corridor_south"] = Transform3D(Basis(), Vector3(-1.5, 0.05, -29.0))
	spawns["corridor_mid"] = Transform3D(Basis(), Vector3(-1.5, 0.05, -50.0))
	spawns["gates_entry"] = Transform3D(Basis(), Vector3(0, 0.05, -78.5))
	spawns["hall"] = Transform3D(Basis(Vector3.UP, PI), Vector3(0.2, 0.05, 7.6))
	spawns["hall_entrance"] = Transform3D(Basis(), Vector3(-7.8, 0.05, 12.0))
	spawns["baggage"] = Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-14.0, 0.05, -44.0))
	triggers["entrance_out"] = Geo.area(self, Vector3(-7.8, 1.0, 16.2), Vector3(4.0, 2.0, 1.6))
	triggers["emergency_out"] = Geo.area(self, Vector3(-17, 1.0, 16.0), Vector3(1.6, 2.0, 1.6))


func zone_at(p: Vector3) -> String:
	for zn in ZONE_RECTS.keys():
		for r: Rect2 in zone_rects(zn):
			if r.has_point(Vector2(p.x, p.z)):
				return zn
	return "outside"


func facility(id_text: String) -> Facility:
	return facilities.get(id_text)
