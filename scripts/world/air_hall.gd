class_name AirHall
extends RefCounted
## The aircraft hall west of the main lounge (the user's references: a vast hall in a pale green haze, a white
## airliner parked in it seen over a white parapet from beside an escalator, long rows of strip lights in the sloping
## roof; and its cabin). The way in is a cabin (CabinWay) behind the lounge's 1F west wall: through its haze you come
## out of a cabin section standing out of the hall's north wall (no passage joins the two), onto a landing at the
## lounge's level: the escalator straight ahead rising south to a 2F deck, the white solid parapet right beside it,
## turning away to the right a step ahead of you at a post. The hall's floor (PIT_Y) lies far below the landing, so you
## look down on the airliner (Airliner, door shut, a set piece) close beside the escalator: its back just under your
## eye, nose toward you and a little to your right, its right wing passing in under the deck. The deck runs on
## south along the hall's east side, narrow (the escalator against its parapet, a walkway beside it), under the 2F
## deck; a ledge higher up on the same wall (out of reach) with its own row of lights. Its own light zone "airhall"
## (ch1 turns it on with the lounge), cold green-white; strip lights all over the sloping roof, spots down through the
## haze.

const RECT := Rect2(-74.0, -24.0, 48.0, 86.0)   # x -74..-26 (the east wall), z -24..62 (the airliner's tail)
const PIT_Y := -12.15        # the hall's floor, so deep that the airliner's back is just under your eye on the landing
                             # (the reference); its right wing passes under the deck
const DECK_X := -30.2        # the deck (the lounge's level) from its parapet to the east wall: narrow, the escalator
                             # against the parapet, a walkway beside it (the hall reference)
const LANDING_X := -31.9     # a little wider at its north end (z ..LANDING_Z), where CabinWay's cabin section stands
const LANDING_Z := -17.2
const UPPER_X := -30.2       # the 2F deck (Terminal.MEZZ_Y) from here to the east wall, UPPER_Z0..UPPER_Z1
const UPPER_Z0 := -6.7
const UPPER_Z1 := 32.0
const LEDGE_X := -29.0       # the ledge higher up (out of reach)
const LEDGE_Y := 8.4
const ROOF_E := 13.0         # the roof over the east wall, rising to ROOF_W over the west wall
const ROOF_W := 22.0
const PLANE_AT := Vector3(-36.7, PIT_Y, -10.3)  # the airliner's frame: the ground under its nose tip, 11 m ahead of
                                                 # the landing, its side a few metres past the escalator's
const PLANE_YAW := 0.0                           # nose north, toward you; the right wing and tailplane run on in under
                                                 # the deck
const PLANE_SCALE := 1.3                         # a 747's own size (Airliner is built at 54 m)
                                                 # and the hall's east wall, out of sight below the floor there
const ESC_FOOT := Vector3(-29.03, 0.0, -15.0)     # the escalator's lower working point; it rises south to the 2F deck
                                                  # beside the parapet, its foot just out of CabinWay's cabin section
const LIGHT := Color(0.86, 1.0, 0.86)
const FILL := Color(0.68, 0.88, 0.74)
const HAZE_GLOW := Color(1.15, 1.42, 1.12)

static var plane: Airliner


## The roof's height over `x`.
static func roof_y(x: float) -> float:
	return ROOF_E + (RECT.end.x - x) / RECT.size.x * (ROOF_W - ROOF_E)


## The airliner's frame (Airliner's: the ground under its nose tip, nose -Z).
static func plane_xf() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(PLANE_YAW)) * Basis.from_scale(Vector3.ONE * PLANE_SCALE), PLANE_AT)



static func build(t: Terminal) -> void:
	var root := Node3D.new()
	root.name = "AirHall"
	t.add_child(root)
	var zone: LightZone = t.zones.airhall
	var wall_m := Mats.shader_mat("res://shaders/wall_panel.gdshader", {"color": Color(0.76, 0.78, 0.74),
			"seam_color": Color(0.6, 0.62, 0.58), "panel_w": 1.5, "panel_h": 3.0, "base_height": PIT_Y, "skirting": 0.0})
	var white := Mats.std(Color(0.84, 0.85, 0.82), 0.55)
	var deck_m := Mats.shader_mat("res://shaders/floor_tile.gdshader", {"color_a": Color(0.62, 0.63, 0.6),
			"color_b": Color(0.58, 0.59, 0.56), "grout_color": Color(0.44, 0.45, 0.42), "tile_size": 1.2,
			"roughness_base": 0.1, "roughness_var": 0.12})
	_shell(root, wall_m, white, zone)
	_decks(root, white, deck_m)
	Escalator.build(root, ESC_FOOT, Terminal.MEZZ_Y, -PI / 2, true, 0.0)
	plane = Airliner.build(root, plane_xf(), zone, false)
	_lights(root, zone)
	# the haze glows of itself, pale green (the reference's white-out), on top of what the lights put into it
	t.air_haze = t._smoke(AABB(Vector3(RECT.position.x, PIT_Y, RECT.position.y), Vector3(RECT.size.x, ROOF_W - PIT_Y, RECT.size.y)), 77,
			0.085, Color(0.86, 0.94, 0.84), HAZE_GLOW)
	# the hall's lights stop at the airliner's skin: only the cabin's own reach in there
	for l: Light3D in zone.lights:
		if l.light_cull_mask != Airliner.VIS_CABIN:
			l.light_cull_mask &= ~Airliner.VIS_CABIN


## The floor, the walls, the roof sloping up toward the west on
## deep beams, rows of strip lights along it.
static func _shell(root: Node3D, wall_m: Material, white: Material, zone: LightZone) -> void:
	var c := RECT.get_center()
	var floor_m := Mats.shader_mat("res://shaders/floor_tile.gdshader", {"color_a": Color(0.5, 0.52, 0.49),
			"color_b": Color(0.47, 0.49, 0.46), "grout_color": Color(0.38, 0.4, 0.37), "tile_size": 3.0,
			"roughness_base": 0.12, "roughness_var": 0.15})
	Geo.box(root, Vector3(c.x, PIT_Y - 0.05, c.y), Vector3(RECT.size.x, 0.1, RECT.size.y), floor_m)
	# the airliner's lead-in line and its stop bar
	var paint := Mats.get_mat("yellow_paint")
	var yaw := deg_to_rad(PLANE_YAW)
	Geo.box(root, plane_xf() * Vector3(0, 0.004, 22.0), Vector3(0.18, 0.008, Airliner.LENGTH * PLANE_SCALE), paint, false, yaw)
	Geo.box(root, plane_xf() * Vector3(0, 0.004, 5.6), Vector3(3.2, 0.008, 0.22), paint, false, yaw)
	var x0 := RECT.position.x
	var x1 := RECT.end.x
	var z0 := RECT.position.y
	var z1 := RECT.end.y
	var tall := ROOF_E + 0.4 - PIT_Y
	Geo.wall(root, Vector2(x0, z0), Vector2(x1, z0), tall, wall_m, 0.4, [], PIT_Y)
	Geo.wall(root, Vector2(x0, z1), Vector2(x1, z1), tall, wall_m, 0.4, [], PIT_Y)
	Geo.wall(root, Vector2(x0, z0), Vector2(x0, z1), ROOF_W + 0.4 - PIT_Y, wall_m, 0.4, [], PIT_Y)
	for z: float in [z0, z1]:
		_gable(root, z, wall_m)
	Geo.wall(root, Vector2(x1, z0), Vector2(x1, z1), tall, wall_m, 0.4, [], PIT_Y)
	# the roof: one sloping slab, beams under it along the hall, strip lights in rows between them
	var a := atan2(ROOF_W - ROOF_E, RECT.size.x)
	var roof := Geo.box(root, Vector3.ZERO, Vector3(RECT.size.x / cos(a) + 0.6, 0.3, RECT.size.y + 0.4),
			Mats.shader_mat("res://shaders/ceiling.gdshader", {"color": Color(0.66, 0.68, 0.64),
			"grid_color": Color(0.52, 0.54, 0.5), "tile": 1.5}), false)
	roof.rotation.z = -a
	roof.position = Vector3(c.x, (ROOF_E + ROOF_W) * 0.5, c.y) + Vector3(sin(a), cos(a), 0) * 0.15
	var beams := [-36.0, -46.0, -56.0, -66.0]
	for bx: float in beams:
		var b := Geo.box(root, Vector3(bx, roof_y(bx) - 0.55, c.y), Vector3(0.55, 1.1, RECT.size.y), white, false)
		b.rotation.z = -a
	# ribs across between every third strip, so the roof reads as coffers of light
	var rz := z0 + 2.5
	while rz < z1 - 1.0:
		var rib := Geo.box(root, Vector3(c.x, (ROOF_E + ROOF_W) * 0.5 - 0.25, rz), Vector3(RECT.size.x / cos(a), 0.5, 0.22),
				white, false)
		rib.rotation.z = -a
		rz += 6.6
	var strips: Array[Transform3D] = []
	var x := x1 - 2.5
	while x > x0 + 1.0:
		var clear := true
		for bx: float in beams:
			clear = clear and absf(x - bx) > 1.0
		if clear:
			# a bundle of tubes side by side, every few metres along the roof, so they read as blocks of light
			var z := z0 + 1.6
			while z < z1 - 1.0:
				for off: float in [-0.5, 0.0, 0.5]:
					strips.append(Transform3D(Basis(Vector3.BACK, -a), Vector3(x + off, roof_y(x + off) - 0.03, z)))
				z += 4.4
		x -= 3.6
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sm := BoxMesh.new()
	sm.size = Vector3(0.3, 0.05, 3.2)
	mm.mesh = sm
	mm.instance_count = strips.size()
	for i in strips.size():
		mm.set_instance_transform(i, strips[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "RoofStrips"
	mmi.multimesh = mm
	mmi.material_override = zone.panel_mat
	root.add_child(mmi)


## The triangle of end wall (at `z`) between the flat top of the wall and the sloping roof.
static func _gable(root: Node3D, z: float, mat: Material) -> void:
	var x0 := RECT.position.x
	var x1 := RECT.end.x
	var tri := [Vector2(x1 + 0.2, ROOF_E + 0.35), Vector2(x0 - 0.2, ROOF_E + 0.35), Vector2(x0 - 0.2, ROOF_W + 0.4)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s: float in [-1.0, 1.0]:
		var n := Vector3(0, 0, s)
		var v: Array = tri.map(func(p: Vector2): return Vector3(p.x, p.y, z + s * 0.2))
		if (v[1] - v[0]).cross(v[2] - v[0]).dot(n) > 0.0:
			v = [v[0], v[2], v[1]]
		for p: Vector3 in v:
			st.set_normal(n)
			st.add_vertex(p)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	root.add_child(mi)


## The decks at the lounge's level: the landing where the cabin section stands, the escalator's foot, from there only
## a walkway along the escalator's other side (the escalator itself rises out over the drop, its white side toward the
## airliner, as in the reference), then the deck under the 2F deck; the 2F deck, the ledge higher up; columns under
## them (clear of the wing reaching in under them); white solid parapets along their edges.
static func _decks(root: Node3D, white: Material, deck_m: Material) -> void:
	var under := Mats.get_mat("ceiling_lounge")
	var x1 := RECT.end.x
	var z0 := RECT.position.y
	var z1 := RECT.end.y
	var esc_w := ESC_FOOT.x - Escalator.OUTER       # the escalator's sides
	var esc_e := ESC_FOOT.x + Escalator.OUTER + 0.02
	for d: Array in [[LANDING_X, z0, LANDING_Z, 0.0, 0.4], [esc_w, LANDING_Z, ESC_FOOT.z, 0.0, 0.4],
			[esc_e, ESC_FOOT.z, UPPER_Z0, 0.0, 0.4], [DECK_X, UPPER_Z0, z1, 0.0, 0.4],
			[UPPER_X, UPPER_Z0, UPPER_Z1, Terminal.MEZZ_Y, 0.35],
			[LEDGE_X, z0, z1, LEDGE_Y, 0.35]]:
		var cx: float = (d[0] + x1) * 0.5
		var cz: float = (d[1] + d[2]) * 0.5
		var w: float = x1 - d[0]
		var l: float = d[2] - d[1]
		Geo.box(root, Vector3(cx, d[3] - 0.01, cz), Vector3(w, 0.02, l), deck_m)
		Geo.box(root, Vector3(cx, d[3] - d[4] * 0.5 - 0.01, cz), Vector3(w, d[4] - 0.02, l), under, false)
	for cz: float in [-21.0, -3.0, 10.0, 50.0]:      # (clear of the escalator and the wing and engine under the deck)
		Geo.cyl(root, Vector3(DECK_X + 2.0, (PIT_Y - 0.4) * 0.5, cz), 0.35, -0.4 - PIT_Y, white, true, 20)
	var stub_end := CabinWay.JOIN_HALL + CabinWay.Z_JOIN - CabinWay.Z_FWD       # the cabin section's cut end
	# the landing's: from the cabin section's cut end, turning toward the escalator a step ahead (a post at the corner)
	_glass_rail(root, Vector2(LANDING_X, stub_end), Vector2(LANDING_X, LANDING_Z - 0.08), 1.0)
	_glass_rail(root, Vector2(LANDING_X, LANDING_Z), Vector2(esc_w - 0.03, LANDING_Z), -1.0)
	# the walkway's edge where you could pass under the escalator (before that the escalator itself is in the way)
	_parapet(root, Vector2(esc_e, ESC_FOOT.z + 3.2), Vector2(esc_e, UPPER_Z0 + 0.3), 0.0, 0.4, white, [], 1.0)
	# the deck under the 2F deck: its north edge west of the walkway, its edge on along the hall
	_parapet(root, Vector2(DECK_X, UPPER_Z0), Vector2(esc_e + 0.3, UPPER_Z0), 0.0, 0.4, white, [], 1.0)
	_parapet(root, Vector2(DECK_X, UPPER_Z0 + 0.3), Vector2(DECK_X, z1), 0.0, 0.4, white, [], 1.0)
	_parapet(root, Vector2(UPPER_X, UPPER_Z0), Vector2(UPPER_X, UPPER_Z1), Terminal.MEZZ_Y, 0.35, white, [], 1.0)
	var esc := [ESC_FOOT.x - Escalator.OUTER - 0.04, ESC_FOOT.x + Escalator.OUTER + 0.04]
	_parapet(root, Vector2(UPPER_X, UPPER_Z0), Vector2(x1, UPPER_Z0), Terminal.MEZZ_Y, 0.35, white, [esc], 1.0)
	_parapet(root, Vector2(UPPER_X, UPPER_Z1), Vector2(x1, UPPER_Z1), Terminal.MEZZ_Y, 0.35, white, [], -1.0)
	_parapet(root, Vector2(LEDGE_X, z0), Vector2(LEDGE_X, z1), LEDGE_Y, 0.35, white, [], 1.0)


## A glass balustrade (frameless panes in a steel shoe, a steel handrail, like the lounge's) along a slab edge from
## `a` to `b` (axis-aligned) at the lounge's level, set in toward the slab (`inward` +1 = toward +X or +Z); it stops you.
static func _glass_rail(root: Node3D, a: Vector2, b: Vector2, inward: float) -> void:
	var along_x := absf(b.x - a.x) > absf(b.y - a.y)
	var lo := minf(a.x, b.x) if along_x else minf(a.y, b.y)
	var hi := maxf(a.x, b.x) if along_x else maxf(a.y, b.y)
	var line := (a.y if along_x else a.x) + inward * 0.06
	var mid := (lo + hi) * 0.5
	var l := hi - lo
	var p := Vector3(mid, 0, line) if along_x else Vector3(line, 0, mid)
	var dims := func(thick: float, h: float) -> Vector3: return Vector3(l, h, thick) if along_x else Vector3(thick, h, l)
	var steel := CarouselMesh.mat("steel")
	Geo.box(root, p + Vector3(0, 0.56, 0), dims.call(0.02, 0.98), Mats.get_mat("glass"), false)
	Geo.box(root, p + Vector3(0, 1.08, 0), dims.call(0.07, 0.05), steel, false)
	Geo.box(root, p + Vector3(0, 0.04, 0), dims.call(0.06, 0.08), steel, false)
	Geo.blocker(root, p + Vector3(0, 0.7, 0), dims.call(0.12, 1.4))
	var edge := (a.y if along_x else a.x) - inward * 0.006
	Geo.box(root, Vector3(mid, -0.2, edge) if along_x else Vector3(edge, -0.2, mid),
			Vector3(l, 0.42, 0.012) if along_x else Vector3(0.012, 0.42, l), steel, false)

## A white solid parapet (1.1 m, a 0.3 m thick upstand carried down over the slab's edge, a cap on top) along a slab
## edge from `a` to `b` (axis-aligned) at floor height `y`, set in toward the slab (`inward` +1 = toward +X or +Z),
## left open over `gaps` ([from, to] along it); it stops you.
static func _parapet(root: Node3D, a: Vector2, b: Vector2, y: float, slab: float, mat: Material, gaps: Array,
		inward: float) -> void:
	var along_x := absf(b.x - a.x) > absf(b.y - a.y)
	var lo := minf(a.x, b.x) if along_x else minf(a.y, b.y)
	var hi := maxf(a.x, b.x) if along_x else maxf(a.y, b.y)
	var line := (a.y if along_x else a.x) + inward * 0.15
	var runs := []
	var cur := lo
	for g: Array in gaps:
		runs.append([cur, g[0]])
		cur = g[1]
	runs.append([cur, hi])
	for r: Array in runs:
		var l: float = r[1] - r[0]
		if l < 0.05:
			continue
		var mid: float = (r[0] + r[1]) * 0.5
		var h := 1.1 + slab + 0.05
		var p := Vector3(mid, y - slab - 0.05 + h * 0.5, line) if along_x else Vector3(line, y - slab - 0.05 + h * 0.5, mid)
		Geo.box(root, p, Vector3(l, h, 0.3) if along_x else Vector3(0.3, h, l), mat, false)
		var cp := Vector3(p.x, y + 1.1 + 0.02, p.z)
		Geo.box(root, cp, Vector3(l, 0.05, 0.36) if along_x else Vector3(0.36, 0.05, l), mat, false)
		var bp := Vector3(p.x, y + 0.75, p.z)
		Geo.blocker(root, bp, Vector3(l, 1.5, 0.3) if along_x else Vector3(0.3, 1.5, l))


## Spots down through the haze from the roof over the floor and the deck, dim fills for the bounce, troffers under the
## 2F deck and the ledge, a light on the escalator.
static func _lights(root: Node3D, zone: LightZone) -> void:
	for x: float in [-38.0, -50.0, -62.0]:
		for z: float in [-14.0, 2.0, 18.0, 34.0, 48.0]:
			var p := Vector3(x, roof_y(x) - 0.4, z)
			var s := Geo.spot(root, p, p + Vector3(0, -10, 0), LIGHT, 14.0, roof_y(x) - PIT_Y + 6.0, 58.0)
			s.spot_attenuation = 0.8
			s.light_volumetric_fog_energy = 0.55
			s.light_specular = 0.4
			zone.add_light(s)
	for z: float in [-18.0, -6.0, 6.0, 18.0, 30.0, 42.0, 50.0]:
		var dx := (DECK_X + RECT.end.x) * 0.5
		var p := Vector3(dx, roof_y(dx) - 0.4, z)
		var s := Geo.spot(root, p, p + Vector3(0, -10, 0), LIGHT, 8.0, 18.0, 40.0)
		s.light_volumetric_fog_energy = 0.45
		zone.add_light(s)
	for f: Array in [[Vector3(-52, 0.0, -10.0), 2.4, 30.0], [Vector3(-52, 0.0, 16.0), 2.4, 30.0],
			[Vector3(-52, 0.0, 42.0), 2.4, 30.0]]:
		var o := Geo.omni(root, f[0], FILL, f[1], f[2])
		o.light_specular = 0.0
		o.light_volumetric_fog_energy = 0.0
		zone.add_light(o)
	# along the deck, so the parapet's white faces read
	var row_z := UPPER_Z0 + 1.7               # (the deck under the 2F deck: north of it is the escalator over the drop)
	while row_z < RECT.end.y:
		var o := Geo.omni(root, Vector3(-29.0, 1.4, row_z), FILL, 2.4, 7.5)
		o.omni_attenuation = 0.7
		o.light_specular = 0.0
		o.light_volumetric_fog_energy = 0.0
		zone.add_light(o)
		row_z += 12.0
	var k := 0
	var z := UPPER_Z0 + 1.5
	while z < UPPER_Z1 - 0.8:
		zone.add_panel(Vector3(-28.3, Terminal.MEZZ_Y - 0.35 - 0.04, z), Vector2(0.3, 1.2), k % 3 == 0, 1.0, 6.0)
		k += 1
		z += 3.0
	z = RECT.position.y + 2.0
	while z < RECT.end.y - 1.0:
		zone.add_panel(Vector3(-27.5, LEDGE_Y - 0.35 - 0.04, z), Vector2(0.3, 1.2), k % 4 == 0, 1.2, 7.0)
		k += 1
		z += 3.0
	# floods from high over the deck on the airliner's side, so it stands out white against the haze
	for fz: float in [-4.0, 14.0, 34.0]:
		var p := Vector3(-31.0, roof_y(-31.0) - 0.6, fz)
		var fl := Geo.spot(root, p, plane_xf() * Vector3(2.0, 4.5, fz + 5.0), LIGHT, 22.0, 46.0, 30.0)
		fl.light_volumetric_fog_energy = 0.35
		zone.add_light(fl)
	# and from under the deck's edge across at its flank, so its whole side reads white (the windows, the cheatline)
	for lz: float in [2.0, 14.0, 26.0, 38.0]:
		var aim := plane_xf() * Vector3(Airliner.R, Airliner.AXIS_Y - 0.6, lz)
		var sp := Geo.spot(root, Vector3(DECK_X - 0.6, -1.2, aim.z - 3.0), aim, FILL, 7.0, 26.0, 34.0)
		sp.light_volumetric_fog_energy = 0.1
		sp.light_specular = 0.2
		zone.add_light(sp)
	var under := Geo.omni(root, plane_xf() * Vector3(6.0, 1.5, 18.0), FILL, 1.6, 22.0)
	under.light_specular = 0.0
	under.light_volumetric_fog_energy = 0.0
	zone.add_light(under)
	# the landing at the cabin section's cut end: the parapet's faces toward you (nothing else reaches them)
	var lf := Geo.omni(root, Vector3((LANDING_X + DECK_X) * 0.5 + 0.4, 2.2, LANDING_Z - 2.6), FILL, 2.2, 7.0)
	lf.omni_attenuation = 0.8
	lf.light_specular = 0.0
	lf.light_volumetric_fog_energy = 0.0
	zone.add_light(lf)
	var esc_mid := ESC_FOOT + Vector3(0, 2.0, 3.6)
	var es := Geo.spot(root, Vector3(ESC_FOOT.x - 1.5, roof_y(ESC_FOOT.x) - 0.4, ESC_FOOT.z + 2.0), esc_mid, LIGHT, 4.0, 18.0, 42.0)
	es.light_volumetric_fog_energy = 0.3
	zone.add_light(es)
	for h: Vector3 in [Vector3(-40, 6, -10), Vector3(-40, 6, 30), Vector3(-29, 3.2, 12)]:
		zone.add_hum(h, -20.0)
