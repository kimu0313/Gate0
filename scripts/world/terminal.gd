class_name Terminal
extends Node3D
## Procedurally builds the SEOHAE International Airport terminal and exposes its systems.
##
## Layout (metres, Y up, -Z = north/airside):
##   OFFICE   x[-34,-22] z[-6,6]      HALL     x[-22,22] z[-14,14]   BAGGAGE x[22,46] z[-14,14]
##   SECURITY x[-12,12]  z[-28,-14]  CORRIDOR x[-5,5]    z[-76,-28]  GATES   x[-26,26] z[-100,-76]
##   STORAGE  x[36,46]   z[-22,-14]  MAINT    x[46,58]   z[6,12]     GATE 0 bridge x[-1.3,1.3] z[-128,-100]

const ZONE_RECTS := {
	"office": Rect2(-34, -6, 12, 12),
	"hall": Rect2(-22, -14, 44, 28),
	"baggage": Rect2(22, -14, 24, 28),
	"storage": Rect2(36, -22, 10, 8),
	"maint": Rect2(46, 6, 12, 6),
	"security": Rect2(-12, -28, 24, 14),
	"corridor": Rect2(-5, -76, 10, 48),
	"gates": Rect2(-26, -100, 52, 24),
	"bridge0": Rect2(-1.5, -130, 3, 30),
}
const ZONE_NAMES := {
	"office": "시설관리실", "hall": "체크인 홀", "baggage": "수하물 수취", "storage": "수하물 보관실",
	"maint": "정비 통로", "security": "보안검색", "corridor": "탑승동 통로", "gates": "탑승 게이트",
	"bridge0": "0번 탑승교", "outside": "외부",
}

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


func build() -> void:
	_build_zones()
	_build_office()
	_build_hall()
	_build_baggage()
	_build_security()
	_build_corridor()
	_build_gates()
	_build_service_rooms()
	_build_outside()
	_build_facility_systems()
	_ceiling_details()
	_define_spawns()
	var fitted := Geo.fit_labels(self, OS.get_cmdline_user_args().has("--tour"))
	if OS.get_cmdline_user_args().has("--tour"):
		print("fit_labels: shrank %d world labels to their signs" % fitted)


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


func _ceiling(rect: Rect2, y: float, mat_name := "ceiling") -> void:
	Geo.box(self, Vector3(rect.position.x + rect.size.x * 0.5, y + 0.1, rect.position.y + rect.size.y * 0.5),
		Vector3(rect.size.x + 0.4, 0.2, rect.size.y + 0.4), Mats.get_mat(mat_name), false)
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
func _build_office() -> void:
	var r: Rect2 = ZONE_RECTS.office
	_floor(r, "floor_office")
	_ceiling(r, 3.2, "ceiling")
	var wm := Mats.get_mat("wall_office")
	Geo.wall(self, Vector2(-34, -6), Vector2(-34, 6), 3.2, wm)
	Geo.wall(self, Vector2(-34, -6), Vector2(-22, -6), 3.2, wm)
	Geo.wall(self, Vector2(-34, 6), Vector2(-22, 6), 3.2, wm)
	var z: LightZone = zones.office
	z.add_panel(Vector3(-31.0, 3.17, -1.5), Vector2(2.4, 0.5), true, 1.3, 9.0, Color(1.0, 0.95, 0.85), true)
	z.add_panel(Vector3(-25.5, 3.17, 2), Vector2(2.4, 0.5), true, 1.1, 9.0, Color(1.0, 0.95, 0.85))
	z.add_hum(Vector3(-28, 3.0, 0), -24.0)
	# desk with PC + radio
	Props.desk(self, Vector3(-33.1, 0, 0.5), Vector3(2.4, 0.76, 0.9), PI / 2)
	var pc := Props.monitor(self, Vector3(-33.35, 0.86, -0.2), PI / 2, Vector2(0.5, 0.3))
	pc.material_override = Mats.emissive(Color(0.15, 0.3, 0.6), 0.8)
	Geo.box(self, Vector3(-33.2, 0.8, 1.4), Vector3(0.08, 0.12, 0.05), Mats.get_mat("plastic_dark"), false)
	Geo.box(self, Vector3(-33.2, 0.89, 1.4), Vector3(0.01, 0.1, 0.01), Mats.get_mat("plastic_dark"), false)
	# chair
	Geo.box(self, Vector3(-32.1, 0.45, 0.4), Vector3(0.5, 0.08, 0.5), Mats.get_mat("seat"))
	Geo.box(self, Vector3(-31.85, 0.8, 0.4), Vector3(0.06, 0.6, 0.5), Mats.get_mat("seat"), false)
	# lockers (south wall)
	for i in 6:
		var lx := -33.2 + i * 0.62
		Geo.box(self, Vector3(lx, 0.95, 5.55), Vector3(0.6, 1.9, 0.5), Mats.std(Color(0.42, 0.45, 0.48), 0.4, 0.6))
		Geo.box(self, Vector3(lx + 0.2, 1.2, 5.29), Vector3(0.03, 0.12, 0.02), Mats.get_mat("metal"), false)
		Geo.label(self, "%02d" % (i + 1), Vector3(lx, 1.7, 5.295), PI, 24, Color(0.1, 0.1, 0.1), 0.003, false, "print")
	# whiteboard
	var wb := Node3D.new()
	add_child(wb)
	wb.position = Vector3(-33.78, 1.6, -3.0)
	wb.rotation.y = PI / 2
	Geo.box(wb, Vector3.ZERO, Vector3(2.0, 1.1, 0.03), Mats.get_mat("plastic_white"), false)
	var note := Geo.fit(Geo.label(wb, "야간 점검 근무 — 반드시 수칙 준수!!\n점검 결과는 태블릿으로 즉시 보고\n0번 게이트 ✕  (존재하지 않음)\n— 소장", Vector3(-0.12, 0.05, 0.02), 0.0, 30, Color(0.1, 0.2, 0.6), 0.0035, false, "hand"), 1.55)
	note.rotation.z = -0.025
	# wall clock
	var clock := Node3D.new()
	add_child(clock)
	clock.position = Vector3(-31.5, 2.5, -5.78)
	Geo.cyl(clock, Vector3.ZERO, 0.18, 0.04, Mats.get_mat("plastic_white")).rotation.x = PI / 2
	Geo.label(clock, "3:00", Vector3(0, 0, 0.03), 0.0, 32, Color(0.1, 0.1, 0.1), 0.003, true, "lcd")
	# fax table for revision pages
	Geo.box(self, Vector3(-23.3, 0.4, -4.6), Vector3(0.9, 0.8, 0.7), Mats.get_mat("wood"))
	Geo.box(self, Vector3(-23.3, 0.9, -4.75), Vector3(0.45, 0.2, 0.35), Mats.get_mat("plastic_white"), false)
	Geo.label(self, "FAX", Vector3(-23.3, 0.95, -4.57), 0.0, 20, Color(0.2, 0.2, 0.2), 0.003, false, "print")
	# card reader door (office <-> hall)
	var d := SlidingDoor.create(self, Vector3(-22, 0, 0), PI / 2, 2.0, 2.4, false, false)
	doors["office"] = d
	readers["office_out"] = CardReader.create(self, Vector3(-21.78, 1.25, 1.55), PI / 2)
	readers["office_in"] = CardReader.create(self, Vector3(-22.22, 1.25, -1.55), -PI / 2)
	readers.office_in.interactable.prompt = "문 열기"
	Geo.label(self, "시설관리실\nFACILITY OFFICE\nSTAFF ONLY", Vector3(-21.78, 2.85, 0), PI / 2, 40, Color(0.92, 0.92, 0.92), 0.005, false, "print")
	# punch clock + breaker (north wall)
	var pc_holder := Props.panel_box(self, Vector3(-28.4, 1.35, -5.78), 0.0, Vector2(0.36, 0.5), "근태 기록기")
	Geo.box(pc_holder, Vector3(0, 0.02, 0.01), Vector3(0.22, 0.12, 0.02), Mats.get_mat("screen_off"), false)
	Geo.label(pc_holder, "TIME CARD", Vector3(0, 0.02, 0.022), 0.0, 18, Color(0.5, 1.0, 0.6), 0.002, true)
	Geo.box(pc_holder, Vector3(0, -0.14, 0.015), Vector3(0.14, 0.02, 0.03), Mats.get_mat("black"), false)
	punch_clock = Interactable.create(pc_holder, Vector3(0, -0.05, 0.05), Vector3(0.36, 0.5, 0.12), "근무 기록 (출근·퇴근)", Callable())
	punch_clock.press_sound = "clock_punch"
	for i in 8:
		Geo.box(self, Vector3(-27.7, 1.2 + i * 0.05, -5.86), Vector3(0.1, 0.004, 0.06), Mats.get_mat("paper"), false)


func _build_hall() -> void:
	var r: Rect2 = ZONE_RECTS.hall
	_floor(r, "floor_accent")
	_ceiling(r, 9.0)
	var wm := Mats.get_mat("wall")
	Geo.wall(self, Vector2(-22, -14), Vector2(-22, 14), 9.0, wm, 0.4, [[13.0, 15.0, 2.4]])
	Geo.wall(self, Vector2(-22, -14), Vector2(22, -14), 9.0, wm, 0.4, [[16.0, 28.0, 5.0]])
	Geo.wall(self, Vector2(22, -14), Vector2(22, 14), 9.0, wm, 0.4, [[9.0, 19.0, 6.0]])
	_glass_facade(Vector2(-22, 14), Vector2(22, 14), 9.0, [[-2.0, 2.0, 2.7], [16.2, 17.8, 2.4]])
	# main entrance doors (locked at night)
	doors["entrance"] = SlidingDoor.create(self, Vector3(0, 0, 14), 0.0, 4.0, 2.6, true, false)
	Geo.label(self, "출구  EXIT", Vector3(0, 3.2, 13.75), PI, 60, Color(0.95, 0.95, 0.95), 0.006)
	# emergency exit door (chained until main power is cut)
	doors["emergency"] = SlidingDoor.create(self, Vector3(17, 0, 14), 0.0, 1.6, 2.4, false, false)
	var es := Props.exit_sign(self, Vector3(17, 2.75, 13.7), PI, "비상구  EXIT ▶")
	exit_signs.append(es)
	for i in 3:
		var ch := Geo.box(self, Vector3(17, 1.0 + i * 0.12, 13.82), Vector3(1.5, 0.04, 0.04), Mats.get_mat("metal"), false)
		ch.rotation.z = 0.25 * (1 if i % 2 == 0 else -1)
		ch.name = "Chain%d" % i
	exit_door_use = Interactable.create(self, Vector3(17, 1.2, 13.7), Vector3(1.6, 2.4, 0.3), "비상구 — 체인으로 잠겨 있다", Callable())
	exit_door_use.press_sound = "door_heavy"
	# lights
	var z: LightZone = zones.hall
	for x in [-15.0, -5.0, 5.0, 15.0]:
		for zz in [-8.0, 0.0, 8.0]:
			z.add_panel(Vector3(x, 8.9, zz), Vector2(5.0, 1.0), true, 2.1, 17.0)
	for x in [-10.0, 10.0]:
		z.add_panel(Vector3(x, 8.9, -12.0), Vector2(8.0, 0.4), false)
	z.add_hum(Vector3(-10, 7, 0), -18.0)
	z.add_hum(Vector3(10, 7, 0), -18.0)
	# pillars
	for p in [Vector3(-19, 0, -9), Vector3(19, 0, -9), Vector3(-19, 0, 9), Vector3(19, 0, 9)]:
		Props.pillar(self, p, 9.0, 1.1)
	# check-in islands
	_checkin_island(Vector3(-10, 0, 1.6), "A")
	_checkin_island(Vector3(10, 0, 1.6), "B")
	# info desk (PA console sits on it)
	Geo.box(self, Vector3(0, 0.55, 6.4), Vector3(3.6, 1.1, 1.0), Mats.get_mat("counter_front"))
	Geo.box(self, Vector3(0, 1.12, 6.45), Vector3(3.8, 0.05, 1.15), Mats.get_mat("counter"), false)
	Geo.box(self, Vector3(0, 2.6, 5.9), Vector3(1.6, 0.5, 0.1), Mats.get_mat("sign_back"), false)
	Geo.label(self, "i  안내 INFORMATION", Vector3(0, 2.6, 5.96), 0.0, 44, Geo.SIGN_BLUE, 0.005)
	Geo.cyl(self, Vector3(0, 4.0, 5.9), 0.02, 2.5, Mats.get_mat("steel_frame"))
	# benches + bins + plants
	for x in [-14.0, -5.0, 5.0, 14.0]:
		Props.seat_row(self, Vector3(x, 0, 11.4), 6, PI)
	for p in [Vector3(-8.5, 0, 11.2), Vector3(8.5, 0, 11.2), Vector3(-19, 0, 0), Vector3(19, 0, 2)]:
		Props.trash_bin(self, p)
	for p in [Vector3(-20.5, 0, 12.5), Vector3(20.5, 0, 12.5)]:
		Props.planter(self, p)
	# signage
	signs["hall_departures"] = Props.hanging_sign(self, Vector3(0, 6.2, -11.0), 0.0, Vector2(7.0, 1.0), [
		["↑  출국 · 보안검색", 60, Color(1, 1, 1), Vector2(-0.9, 0.18)],
		["DEPARTURES · SECURITY", 40, Color(0.85, 0.88, 0.95), Vector2(-0.9, -0.24)],
		["✈", 120, Geo.SIGN_BLUE, Vector2(2.7, 0.0)],
	], 9.0)
	signs["hall_baggage"] = Props.hanging_sign(self, Vector3(17.0, 5.6, 0.0), -PI / 2, Vector2(5.4, 0.9), [
		["↑  수하물 수취  BAGGAGE CLAIM", 50, Color(1, 1, 1), Vector2(0, 0.0)],
	], 9.0)
	signs["hall_staff"] = Props.hanging_sign(self, Vector3(-17.0, 5.6, 0.0), PI / 2, Vector2(5.0, 0.9), [
		["↑  시설관리실  STAFF ONLY", 50, Color(1, 1, 1), Vector2(0, 0.0)],
	], 9.0)
	var banner := Node3D.new()
	add_child(banner)
	banner.position = Vector3(0, 7.2, 13.5)
	banner.rotation.y = PI
	Geo.box(banner, Vector3.ZERO, Vector3(12, 1.4, 0.05), Mats.std(Color(0.08, 0.2, 0.45), 0.8), false)
	Geo.label(banner, "GRAND OPENING  2026. 10. 23", Vector3(0, 0.22, 0.03), 0.0, 80, Color(1, 1, 1), 0.008, false, "print")
	Geo.label(banner, "서해국제공항 정식 개장", Vector3(0, -0.35, 0.03), 0.0, 56, Color(0.78, 0.86, 1.0), 0.008, false, "print")


func _checkin_island(c: Vector3, letter: String) -> void:
	var back := Geo.box(self, c + Vector3(0, 1.6, -0.5), Vector3(10.4, 3.2, 0.3), Mats.get_mat("counter_front"))
	back.name = "Backdrop" + letter
	Geo.box(self, c + Vector3(0, 2.95, -0.33), Vector3(10.0, 0.42, 0.04), Mats.get_mat("lightbox"), false)
	Geo.label(self, "CHECK-IN   %s 01 — 08      탑승 수속" % letter, c + Vector3(0, 2.95, -0.3), 0.0, 52, Color(0.05, 0.1, 0.25), 0.006)
	Geo.box(self, c + Vector3(0, 0.3, 0.1), Vector3(10.0, 0.6, 0.5), Mats.get_mat("rubber"))
	Geo.box(self, c + Vector3(0, 0.525, 0.85), Vector3(10.0, 1.05, 0.7), Mats.get_mat("counter_front"))
	Geo.box(self, c + Vector3(0, 1.07, 0.85), Vector3(10.1, 0.04, 0.8), Mats.get_mat("counter"), false)
	for i in 6:
		var x := c.x - 4.2 + i * 1.68
		Props.monitor(self, Vector3(x, 1.2, c.z + 0.7), 0.0, Vector2(0.36, 0.22))
		Geo.box(self, Vector3(x + 0.75, 0.12, c.z + 1.45), Vector3(0.6, 0.24, 0.6), Mats.get_mat("steel_frame"))
		Geo.label(self, "%s%02d" % [letter, i + 1], Vector3(x, 1.75, c.z + 0.52), 0.0, 40, Geo.SIGN_BLUE, 0.005)
	for i in 6:
		var px := c.x - 5.0 + i * 2.0
		Geo.cyl(self, Vector3(px, 0.5, c.z + 3.2), 0.035, 1.0, Mats.get_mat("metal"))
		if i < 5:
			Geo.box(self, Vector3(px + 1.0, 0.92, c.z + 3.2), Vector3(2.0, 0.06, 0.02), Mats.std(Color(0.1, 0.15, 0.4), 0.6), false)


func _glass_facade(a: Vector2, b: Vector2, height: float, gaps: Array) -> void:
	# glass wall along X at z = a.y. gaps: [[x0, x1, top], ...] (door openings)
	var z := a.y
	var x := a.x
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
		Geo.box(self, Vector3(x, height * 0.5, z), Vector3(0.14, height, 0.22), frame, false)
		x += 3.0
	for y in [0.1, 3.0, 6.0, height - 0.1]:
		for s in segs:
			var w3: float = s[1] - s[0]
			if w3 > 0.01:
				Geo.box(self, Vector3((s[0] + s[1]) * 0.5, y, z), Vector3(w3, 0.12, 0.18), frame, false)


# --------------------------------------------------------------------------------------------
func _build_baggage() -> void:
	var r: Rect2 = ZONE_RECTS.baggage
	_floor(r, "floor")
	_ceiling(r, 6.0)
	var wm := Mats.get_mat("wall")
	Geo.wall(self, Vector2(22, -14), Vector2(46, -14), 6.0, wm, 0.4, [[18.0, 20.0, 2.4]])
	Geo.wall(self, Vector2(22, 14), Vector2(46, 14), 6.0, wm)
	Geo.wall(self, Vector2(46, -14), Vector2(46, 14), 6.0, wm, 0.4, [[22.0, 24.0, 2.4]])
	var z: LightZone = zones.baggage
	for x in [27.0, 35.0, 43.0]:
		for zz in [-7.0, 6.0]:
			z.add_panel(Vector3(x, 5.92, zz), Vector2(4.0, 0.8), true, 1.6, 13.0)
	z.add_hum(Vector3(35, 5, 0), -18.0)
	# decorative carousel B-02
	var deco := Node3D.new()
	add_child(deco)
	deco.position = Vector3(32, 0, -9)
	Geo.box(deco, Vector3(0, 0.22, 0), Vector3(6.0, 0.44, 3.4), Mats.get_mat("metal_dark"))
	for sx in [-3.0, 3.0]:
		Geo.cyl(deco, Vector3(sx, 0.22, 0), 1.7, 0.44, Mats.get_mat("metal_dark"), true, 24)
	Geo.box(deco, Vector3(0, 0.5, 0), Vector3(6.0, 0.6, 1.6), Mats.get_mat("steel_frame"), false)
	Geo.label(deco, "B-02  운영 준비 중", Vector3(0, 1.0, 0.82), 0.0, 40, Color(0.9, 0.9, 0.9), 0.006, false, "print")
	# luggage carts
	for i in 4:
		var cart := Node3D.new()
		add_child(cart)
		cart.position = Vector3(24.5, 0, -12 + i * 0.5)
		cart.rotation.y = PI / 2
		Geo.box(cart, Vector3(0, 0.25, 0), Vector3(0.6, 0.04, 1.0), Mats.get_mat("metal"), false)
		Geo.box(cart, Vector3(0, 0.6, -0.48), Vector3(0.6, 0.7, 0.04), Mats.get_mat("metal"), false)
	Geo.blocker(self, Vector3(24.5, 0.5, -11.25), Vector3(1.2, 1.0, 2.2))
	signs["baggage_main"] = Props.hanging_sign(self, Vector3(35, 4.2, -2.2), 0.0, Vector2(4.4, 0.8), [
		["수하물 수취대  B-03", 52, Color(1, 1, 1), Vector2(0, 0)],
	], 6.0)
	# storage door
	# hall -> baggage opening is shuttered until Day 2 (zones open one per day)
	shutters["baggage"] = Shutter.create(self, Vector3(22, 0, 0), PI / 2, 10.0, 6.0, "점검 구역 외 · 통제")
	doors["storage"] = SlidingDoor.create(self, Vector3(41, 0, -14), 0.0, 1.8, 2.4, false, true)
	Geo.label(self, "수하물 보관실\nBAGGAGE STORAGE", Vector3(41, 2.85, -13.78), 0.0, 32, Color(0.9, 0.9, 0.9), 0.005, false, "print")
	# maintenance door (keypad)
	doors["maint"] = SlidingDoor.create(self, Vector3(46, 0, 9), PI / 2, 1.8, 2.4, false, false)
	Geo.label(self, "정비 통로\nMAINTENANCE\n관계자 외 출입금지", Vector3(45.78, 2.9, 9), -PI / 2, 30, Geo.SIGN_BLUE, 0.005, false, "print")
	var kp := Props.panel_box(self, Vector3(45.8, 1.3, 10.4), -PI / 2, Vector2(0.2, 0.28), "")
	for i in 9:
		Geo.box(kp, Vector3(-0.05 + (i % 3) * 0.05, 0.05 - (i / 3) * 0.05, 0.006), Vector3(0.035, 0.035, 0.01), Mats.get_mat("plastic_white"), false)
	Geo.box(kp, Vector3(0, 0.11, 0.006), Vector3(0.14, 0.03, 0.01), Mats.get_mat("lamp_red"), false)
	keypad = Interactable.create(kp, Vector3(0, 0, 0.05), Vector3(0.25, 0.32, 0.1), "도어락 비밀번호 입력", Callable())
	keypad.press_sound = "keypad_beep"


# --------------------------------------------------------------------------------------------
func _build_security() -> void:
	var r: Rect2 = ZONE_RECTS.security
	_floor(r, "floor")
	_ceiling(r, 5.0)
	var wm := Mats.get_mat("wall")
	Geo.wall(self, Vector2(-12, -28), Vector2(-12, -14), 5.0, wm)
	Geo.wall(self, Vector2(12, -28), Vector2(12, -14), 5.0, wm)
	Geo.wall(self, Vector2(-12, -28), Vector2(12, -28), 5.0, wm, 0.4, [[8.0, 16.0, 4.0]])
	shutters["security"] = Shutter.create(self, Vector3(0, 0, -14.0), 0.0, 12.0, 5.0, "점검 구역 외 · 통제")
	shutters["corridor"] = Shutter.create(self, Vector3(0, 0, -28.0), 0.0, 8.0, 4.0, "점검 구역 외 · 통제")
	var z: LightZone = zones.security
	for x in [-6.0, 6.0]:
		for zz in [-18.0, -24.0]:
			z.add_panel(Vector3(x, 4.92, zz), Vector2(3.6, 0.8), true, 1.5, 11.0)
	z.add_hum(Vector3(0, 4.5, -21), -20.0)
	for p in [Vector3(-8.0, 0, -21.0), Vector3(2.0, 0, -21.0)]:
		_metal_detector(p)
	signs["security_main"] = Props.hanging_sign(self, Vector3(0, 3.6, -26.4), 0.0, Vector2(6.0, 0.9), [
		["↑  탑승동  GATES 01 — 04", 52, Color(1, 1, 1), Vector2(0, 0.12)],
		["무빙워크 MW-1", 34, Color(0.8, 0.85, 0.95), Vector2(0, -0.24)],
	], 5.0)
	Props.lightbox(self, Vector3(-11.78, 2.2, -17.5), PI / 2, Vector2(2.6, 1.2), "액체류 100ml 제한", "LIQUIDS LIMIT 100ml")
	Props.lightbox(self, Vector3(11.78, 2.2, -17.5), -PI / 2, Vector2(2.6, 1.2), "보안검색  SECURITY", "탑승권을 준비해 주세요")
	for i in 5:
		Geo.box(self, Vector3(-9.0, 0.82 + i * 0.07, -16.2), Vector3(0.6, 0.06, 0.45), Mats.std(Color(0.3, 0.32, 0.36), 0.5), false)
	Geo.box(self, Vector3(-9.0, 0.4, -16.2), Vector3(0.7, 0.8, 0.5), Mats.get_mat("metal_dark"))


func _metal_detector(p: Vector3) -> void:
	var m := Mats.get_mat("plastic_grey")
	for sx in [-0.55, 0.55]:
		Geo.box(self, p + Vector3(sx, 1.05, 0), Vector3(0.14, 2.1, 0.55), m)
	Geo.box(self, p + Vector3(0, 2.18, 0), Vector3(1.25, 0.18, 0.6), m, false)
	Geo.box(self, p + Vector3(0, 2.28, 0.31), Vector3(0.3, 0.06, 0.01), Mats.get_mat("lamp_green"), false)


# --------------------------------------------------------------------------------------------
func _build_corridor() -> void:
	var r: Rect2 = ZONE_RECTS.corridor
	_floor(r, "floor")
	_ceiling(r, 4.5)
	var wm := Mats.get_mat("wall")
	Geo.wall(self, Vector2(-5, -76), Vector2(-5, -28), 4.5, Mats.get_mat("wall_tile"))
	# east windows
	var frame := Mats.get_mat("steel_frame")
	Geo.box(self, Vector3(5, 0.4, -52), Vector3(0.4, 0.8, 48), wm)
	Geo.box(self, Vector3(5, 4.25, -52), Vector3(0.4, 0.5, 48), wm, false)
	Geo.box(self, Vector3(5, 2.4, -52), Vector3(0.04, 3.2, 48), Mats.get_mat("glass"), false)
	Geo.blocker(self, Vector3(5, 2.25, -52), Vector3(0.4, 4.5, 48))
	var zz := -28.0
	while zz >= -76.0:
		Geo.box(self, Vector3(5, 2.4, zz), Vector3(0.22, 3.2, 0.14), frame, false)
		zz -= 4.0
	Geo.box(self, Vector3(4.7, 0.82, -52), Vector3(0.3, 0.05, 48), Mats.get_mat("steel_frame"), false)
	var z: LightZone = zones.corridor
	var lz := -32.0
	while lz >= -73.0:
		z.add_panel(Vector3(1.0, 4.44, lz), Vector2(0.5, 4.0), true, 1.2, 9.0)
		lz -= 6.0
	z.add_hum(Vector3(0, 4, -40), -22.0)
	z.add_hum(Vector3(0, 4, -64), -22.0)
	# lightbox ads on the west wall
	var ads := [
		["서해국제공항", "바다 위의 첫 관문  SEOHAE INT'L AIRPORT"],
		["집으로 가는 가장 빠른 길", "The fastest way HOME"],
		["GRAND OPENING", "2026. 10. 23"],
		["어디로 떠나시나요?", "Where are you going?"],
	]
	for i in ads.size():
		var lb := Props.lightbox(self, Vector3(-4.78, 2.1, -36.0 - i * 10.0), PI / 2, Vector2(3.2, 1.6), ads[i][0], ads[i][1])
		zones.corridor.add_light(Geo.omni(lb, Vector3(0, 0, 1.0), Color(0.8, 0.88, 1.0), 0.4, 4.0))
	signs["corridor_mid"] = Props.hanging_sign(self, Vector3(1.5, 3.3, -52.0), 0.0, Vector2(4.6, 0.8), [
		["↑  GATES 01 — 04", 56, Color(1, 1, 1), Vector2(0, 0)],
	], 4.5)
	shutters["gates"] = Shutter.create(self, Vector3(0, 0, -76.0), 0.0, 10.0, 4.5, "점검 구역 외 · 통제")


# --------------------------------------------------------------------------------------------
func _build_gates() -> void:
	var r: Rect2 = ZONE_RECTS.gates
	_floor(r, "carpet")
	Geo.box(self, Vector3(0, 0.003, -88), Vector3(6.0, 0.01, 24.0), Mats.get_mat("floor"), false)
	_ceiling(r, 5.5)
	var wm := Mats.get_mat("wall")
	Geo.wall(self, Vector2(-26, -76), Vector2(26, -76), 5.5, wm, 0.4, [[21.0, 31.0, 4.5]])
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
		["GATE 03 · 04  ▶", 52, Color(1, 1, 1), Vector2(2.3, 0)],
	], 5.5)
	for p in [Vector3(-20, 0, -78), Vector3(20, 0, -78)]:
		Props.trash_bin(self, p)
	for p in [Vector3(-24.5, 0, -98.5), Vector3(24.5, 0, -98.5)]:
		Props.planter(self, p)
	# gate ID wall plates near the corridor
	Props.exit_sign(self, Vector3(-25.75, 2.8, -88), PI / 2, "비상구  EXIT")


# --------------------------------------------------------------------------------------------
func _build_service_rooms() -> void:
	var sm := Mats.get_mat("wall_service")
	# storage room
	var sr: Rect2 = ZONE_RECTS.storage
	_floor(sr, "floor_service")
	_ceiling(sr, 3.2, "ceiling_dark")
	Geo.wall(self, Vector2(36, -22), Vector2(36, -14), 3.2, sm)
	Geo.wall(self, Vector2(46, -22), Vector2(46, -14), 3.2, sm)
	Geo.wall(self, Vector2(36, -22), Vector2(46, -22), 3.2, sm)
	var svc: LightZone = zones.service
	svc.add_panel(Vector3(41, 3.15, -18), Vector2(1.2, 0.3), true, 0.6, 7.0, Color(1.0, 0.92, 0.75), true)
	for i in 4:
		Geo.box(self, Vector3(37.0, 0.4 + i * 0.6, -18), Vector3(0.6, 0.05, 6.0), Mats.get_mat("metal_dark"), false)
	Geo.blocker(self, Vector3(37.0, 1.2, -18), Vector3(0.7, 2.4, 6.0))
	for p in [Vector3(37.0, 0.65, -20), Vector3(37.0, 1.25, -17), Vector3(37.0, 0.65, -16)]:
		Geo.box(self, p, Vector3(0.5, 0.4, 0.7), Mats.std(Color(0.45, 0.35, 0.22), 0.8), false)
	for p in [Vector3(44, 0.4, -20.5), Vector3(44.6, 0.4, -19.6), Vector3(44.2, 1.1, -20.2)]:
		Geo.box(self, p, Vector3(0.8, 0.8, 0.8), Mats.std(Color(0.5, 0.4, 0.26), 0.85))
	# maintenance passage
	var mr: Rect2 = ZONE_RECTS.maint
	_floor(mr, "floor_service")
	_ceiling(mr, 3.0, "ceiling_dark")
	Geo.wall(self, Vector2(46, 6), Vector2(58, 6), 3.0, sm)
	Geo.wall(self, Vector2(46, 12), Vector2(58, 12), 3.0, sm)
	Geo.wall(self, Vector2(58, 6), Vector2(58, 12), 3.0, sm)
	svc.add_panel(Vector3(52, 2.95, 9), Vector2(1.2, 0.3), true, 0.5, 7.0, Color(1.0, 0.92, 0.75))
	for i in 4:
		Geo.cyl(self, Vector3(47 + i * 3.0, 2.6, 6.4), 0.08, 0.1, Mats.get_mat("metal"))
	Geo.box(self, Vector3(52, 2.6, 6.35), Vector3(12, 0.12, 0.12), Mats.get_mat("metal_dark"), false)
	# main power lever
	var mp := Props.panel_box(self, Vector3(57.78, 1.4, 9), -PI / 2, Vector2(1.0, 1.2), "MAIN POWER  주 전원")
	Geo.box(mp, Vector3(0, -0.1, 0.05), Vector3(0.12, 0.5, 0.08), Mats.get_mat("metal"), false).name = "Lever"
	Geo.box(mp, Vector3(0, 0.18, 0.08), Vector3(0.3, 0.08, 0.12), Mats.get_mat("button_red"), false)
	Geo.label(mp, "⚠ 터미널 전체 전원 차단", Vector3(0, -0.45, 0.006), 0.0, 26, Geo.SIGN_BLUE, 0.003, false, "print")
	main_power = Interactable.create(mp, Vector3(0, 0, 0.1), Vector3(0.8, 1.0, 0.2), "주 전원 레버", Callable())
	main_power.press_sound = ""
	# system log terminal
	var term := Node3D.new()
	add_child(term)
	term.position = Vector3(52, 0, 11.5)
	term.rotation.y = PI
	Geo.box(term, Vector3(0, 0.45, 0), Vector3(1.2, 0.9, 0.6), Mats.get_mat("metal_dark"))
	var scr := Props.monitor(term, Vector3(0, 0.95, 0.05), 0.0, Vector2(0.5, 0.32))
	scr.material_override = Mats.emissive(Color(0.25, 0.9, 0.4), 0.7)
	syslog_terminal = Interactable.create(term, Vector3(0, 1.0, 0.3), Vector3(0.8, 0.6, 0.4), "시스템 로그 확인", Callable())


# --------------------------------------------------------------------------------------------
func _build_outside() -> void:
	Geo.box(self, Vector3(0, -0.2, -60), Vector3(500, 0.2, 480), Mats.get_mat("asphalt"), false)
	Geo.blocker(self, Vector3(0, -0.15, -60), Vector3(500, 0.1, 480))
	var paint := Mats.get_mat("yellow_paint")
	# apron markings
	for i in 12:
		Geo.box(self, Vector3(30.0 + i * 0.0, -0.09, -40.0 - i * 5.0), Vector3(0.25, 0.01, 3.0), paint, false)
	Geo.box(self, Vector3(0, -0.09, -150), Vector3(0.3, 0.01, 60), paint, false)
	# taxiway / runway lights
	var amber := Mats.get_mat("runway_light")
	var blue := Mats.get_mat("runway_blue")
	for i in 60:
		var x := -150.0 + i * 5.0
		Geo.box(self, Vector3(x, 0.0, -190.0), Vector3(0.25, 0.15, 0.25), amber, false)
		Geo.box(self, Vector3(x, 0.0, -230.0), Vector3(0.25, 0.15, 0.25), amber, false)
		if i % 2 == 0:
			Geo.box(self, Vector3(x, 0.0, -170.0), Vector3(0.2, 0.12, 0.2), blue, false)
	for i in 20:
		Geo.box(self, Vector3(60.0, 0.0, -20.0 - i * 8.0), Vector3(0.2, 0.12, 0.2), blue, false)
	# apron floodlight masts
	for p in [Vector3(40, 0, -45), Vector3(40, 0, -70), Vector3(-30, 0, -130), Vector3(30, 0, -130)]:
		Geo.cyl(self, p + Vector3(0, 12, 0), 0.25, 24, Mats.get_mat("steel_frame"))
		Geo.box(self, p + Vector3(0, 24, 0), Vector3(2.0, 0.6, 0.6), Mats.get_mat("lamp_white"), false)
		var sl := Geo.spot(self, p + Vector3(0, 23.5, 0), p + Vector3(-6, 0, 0), Color(1.0, 0.85, 0.6), 6.0, 60.0, 50.0)
		sl.spot_attenuation = 1.0
		sl.light_volumetric_fog_energy = 0.3
		outside_lights.append(sl)
	# parked aircraft (seen from the corridor)
	_aircraft(Vector3(45, 0, -58), PI, false)
	# parking lot lights south
	for i in 6:
		var p := Vector3(-30.0 + i * 12.0, 0, 40.0)
		Geo.cyl(self, p + Vector3(0, 5, 0), 0.12, 10, Mats.get_mat("steel_frame"))
		var l := Geo.omni(self, p + Vector3(0, 9.6, 0), Color(1.0, 0.6, 0.25), 3.0, 22.0)
		l.light_volumetric_fog_energy = 1.2
		outside_lights.append(l)
		Geo.box(self, p + Vector3(0, 9.9, 0), Vector3(0.8, 0.15, 0.4), Mats.get_mat("lamp_amber"), false)
	# curb + road in front of the entrance
	Geo.box(self, Vector3(0, -0.05, 22), Vector3(80, 0.1, 14), Mats.get_mat("concrete"), false)
	for i in 10:
		Geo.box(self, Vector3(-36 + i * 8, -0.09, 31), Vector3(4, 0.01, 0.2), Mats.get_mat("white_paint"), false)
	# the impossible aircraft at Gate 0 (finale only)
	final_plane = _aircraft(Vector3(0, 0, -168), 0.0, true)
	final_plane.visible = false


func _aircraft(pos: Vector3, rot_y: float, gate0: bool) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	root.rotation.y = rot_y
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


# --------------------------------------------------------------------------------------------
func _build_facility_systems() -> void:
	# lighting panels
	lights_panel = LightPanel.new()
	lights_panel.id = "lights"
	lights_panel.title = "조명 분전반"
	lights_panel.short_name = "LP-1"
	lights_panel.zone = "hall"
	add_child(lights_panel)
	lights_panel.position = Vector3(-21.78, 1.45, 4.6)
	lights_panel.rotation.y = PI / 2
	lights_panel.build(zones, ["hall", "baggage", "security", "corridor", "gates"])
	facilities["lights"] = lights_panel
	lights_panel_gates = LightPanel.new()
	lights_panel_gates.id = "lights_gates"
	lights_panel_gates.title = "게이트 조명 스위치"
	lights_panel_gates.zone = "gates"
	add_child(lights_panel_gates)
	lights_panel_gates.position = Vector3(-6.5, 1.45, -76.22)
	lights_panel_gates.rotation.y = PI
	lights_panel_gates.build(zones, ["corridor", "gates"], "구역 조명  LIGHTING")
	for zn in lights_panel.switches.keys():
		lights_panel.switches[zn].toggled.connect(func(on): _sync_switch(zn, on))
	for zn in lights_panel_gates.switches.keys():
		lights_panel_gates.switches[zn].toggled.connect(func(on): _sync_switch(zn, on))
	# FIDS
	var fids := FidsBoard.new()
	fids.id = "fids"
	fids.title = "FIDS 출발 전광판"
	fids.short_name = "FIDS-01"
	fids.zone = "hall"
	add_child(fids)
	fids.position = Vector3(-11, 4.6, -13.78)
	fids.build(8.0, 3.2, true)
	facilities["fids"] = fids
	arrivals = FidsBoard.new()
	arrivals.id = "fids_arr"
	arrivals.zone = "hall"
	add_child(arrivals)
	arrivals.position = Vector3(11, 4.6, -13.78)
	arrivals.build(8.0, 3.2, false)
	arrivals.screen.title = "도착  ARRIVALS"
	arrivals.set_story("message", ["운영 준비 중", "NOT IN SERVICE"])
	# PA console
	var pa := PaConsole.new()
	pa.id = "pa"
	pa.title = "안내방송 콘솔"
	pa.short_name = "PA-01"
	pa.zone = "hall"
	add_child(pa)
	pa.position = Vector3(0, 1.14, 6.62)
	pa.build()
	facilities["pa"] = pa
	# baggage
	var belt := BaggageBelt.new()
	belt.id = "baggage"
	belt.title = "수하물 수취대 B-03"
	belt.short_name = "B-03"
	belt.zone = "baggage"
	add_child(belt)
	belt.position = Vector3(35, 0, 2.5)
	belt.build()
	facilities["baggage"] = belt
	var bp := Props.pedestal(self, Vector3(27.0, 0, -1.6), -PI / 2, "B-03 제어")
	Props.button(bp, Vector3(-0.17, -0.03, 0), 0.0, "button_green", "가동", "벨트 가동", belt.press_start)
	Props.button(bp, Vector3(0.0, -0.03, 0), 0.0, "button_grey", "정지", "벨트 정지", belt.press_stop)
	Props.button(bp, Vector3(0.17, -0.03, 0), 0.0, "button_red", "비상정지", "벨트 비상정지", belt.press_estop, 0.06)
	# moving walkway
	var mw := MovingWalkway.new()
	mw.id = "walkway"
	mw.title = "무빙워크 MW-1"
	mw.short_name = "MW-1"
	mw.zone = "corridor"
	add_child(mw)
	mw.position = Vector3(-2.8, 0, -31.0)
	mw.build(42.0)
	facilities["walkway"] = mw
	var wp := Props.pedestal(self, Vector3(-0.8, 0, -29.6), 0.0, "MW-1 제어")
	Props.button(wp, Vector3(-0.17, -0.03, 0), 0.0, "button_green", "가동", "무빙워크 가동", mw.press_start)
	Props.button(wp, Vector3(0.0, -0.03, 0), 0.0, "button_grey", "정지", "무빙워크 정지", mw.press_stop)
	Props.button(wp, Vector3(0.17, -0.03, 0), 0.0, "button_red", "비상정지", "무빙워크 비상정지", mw.press_estop, 0.06)
	# X-ray lanes
	var xr := XrayMachine.new()
	xr.id = "xray"
	xr.title = "보안검색 X-ray 1번"
	xr.short_name = "X-1"
	xr.zone = "security"
	add_child(xr)
	xr.position = Vector3(-5.0, 0, -21.0)
	xr.build()
	facilities["xray"] = xr
	var xr2 := XrayMachine.new()
	xr2.id = "xray2"
	xr2.zone = "security"
	add_child(xr2)
	xr2.position = Vector3(5.0, 0, -21.0)
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
	breaker.position = Vector3(-25.2, 1.5, -5.78)
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
	for p in [Vector3(17, 2.4, 12.5), Vector3(0, 3, 0), Vector3(30, 3, 9), Vector3(52, 2.5, 9)]:
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
func _define_spawns() -> void:
	spawns["office"] = Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(-29.0, 0.05, 1.0))
	spawns["corridor_south"] = Transform3D(Basis(), Vector3(0, 0.05, -29.5))
	spawns["corridor_mid"] = Transform3D(Basis(), Vector3(2.0, 0.05, -50.0))
	spawns["gates_entry"] = Transform3D(Basis(), Vector3(0, 0.05, -78.5))
	spawns["hall"] = Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0.05, 9.0))
	spawns["hall_entrance"] = Transform3D(Basis(), Vector3(0, 0.05, 12.0))
	spawns["baggage"] = Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(25.0, 0.05, 0.0))
	triggers["entrance_out"] = Geo.area(self, Vector3(0, 1.0, 16.2), Vector3(4.0, 2.0, 1.6))
	triggers["emergency_out"] = Geo.area(self, Vector3(17, 1.0, 16.0), Vector3(1.6, 2.0, 1.6))


func zone_at(p: Vector3) -> String:
	for zn in ZONE_RECTS.keys():
		var r: Rect2 = ZONE_RECTS[zn]
		if r.has_point(Vector2(p.x, p.z)):
			return zn
	return "outside"


func facility(id_text: String) -> Facility:
	return facilities.get(id_text)
