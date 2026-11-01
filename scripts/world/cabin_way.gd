class_name CabinWay
extends Node3D
## The way into the aircraft hall (the user's two references, one after the other: an airliner cabin seen from its
## back looking forward — a wide carpeted aisle along the left windows, seats on the right, the far end lost in a pale
## green haze — and, through that haze, the hall: the escalator on the left, the airliner beyond the white parapet).
##
## The cabin (Airliner.NARROW: a single-aisle cabin 3.4 m across, as narrow as the reference) stands behind the
## lounge's 1F west wall, between it and the hall (x -23.7..-20.3; nothing round it, nobody sees its outside). Its door is in that wall at the west end of the lounge's south aisle, the white leaf swung back
## against the lounge's side: you step in onto the wide aisle and it runs south, rows of seats on your right, the haze
## thickening toward the far end. Walk on into it and there is nothing but haze — and you walk out of it at the hall's
## north end, out of the cut-off end of a cabin section standing out of the hall's north wall on the deck (the stub),
## the escalator on your left, the airliner beyond the parapet on your right. Back into the stub's haze and you are in
## the cabin again, walking back toward the door.
##
## The join: the cabin and the stub are the same section in the same heading (Airliner's frame turned to face south),
## so crossing is a straight shift by offset() at the join (join_z() in the cabin, JOIN_HALL in the hall). Before it
## the screen whites out — the world's depth fog thickening with how deep into the haze your eye stands on either
## side (FADE_IN in the cabin, FADE_OUT in the hall), then a card of the same colour on the camera — so the shift is
## never seen. Lit with the aircraft hall (zone "airhall"); inside, both are on Airliner.VIS_CABIN like the parked
## airliner's cabin (only their own lights).

const AXIS_X := -22.0        # the cabin's centreline (its left wall just inside the lounge's west wall at x -20)
const DOOR_Z := 27.5         # its door in the lounge's west wall (world z: the lounge's south aisle)
const STUB_X := -29.7        # the stub's centreline on its landing (its wide aisle comes out at the escalator's foot; its
                             # other side reaches out over the edge, the landing's parapet runs from it)
const STUB_LIFT := 0.006     # its floor over the deck's (they would share a plane)
const JOIN_HALL := -22.0     # where the stub's haze gives you back (world z, on its axis)
# the cabin's own frame (Airliner's, turned so that its nose points south, +Z): its ends, the door, the rows, the join
const Z_FWD := 14.4          # the forward end, closed, in the thickest haze (the stub's cut end is here too)
const Z_JOIN := 16.4
const Z_STUB := 18.4         # the stub's back, in the hall's north wall
const Z_SEATS := 17.5        # the forward-most row (the rows run aft from here to the door's cross aisle)
const Z_DOOR := 38.4
const Z_AFT := 40.0          # the aft bulkhead (the curtain, the EXIT light) behind the door
const LINING := 2.2          # the door's lining runs out through the lounge's wall to its face (x -19.8)
const HALF := 1.75           # the cabin's half-width, give or take (its walls bulge to 1.7)
const FADE_IN := 6.0         # how far before the join the white-out starts (in the cabin)
const FADE_OUT := 3.5        # and where it has cleared (in the hall, past the join)
const FOG_MAX := 4.0         # the depth fog's density at the join
const HAZE := Color(1.45, 1.75, 1.47)  # the haze's glow at full light (brighter than the hall's): the white-out's colour
const LAMP := Color(1.0, 0.97, 0.9)    # the cabins' ceiling lights (the reference's cream cabin; the green is the haze's)
const LAMP_GAIN := 1.7
const LEAF := Color(0.84, 0.85, 0.84)

static var way: CabinWay

var zone: LightZone
var _fogs: Array = []        # [FogMaterial, its glow at full light]
var _env: Environment
var _fog_ours := false
var _card: MeshInstance3D    # the white-out's last step, on the camera
var _card_mat: StandardMaterial3D
var _low_cards: Array[MeshInstance3D] = []   # the haze at the far end without volumetric fog (low quality)


static func build(t: Terminal) -> CabinWay:
	var w := CabinWay.new()
	w.name = "CabinWay"
	t.add_child(w)
	way = w
	w._build(t)
	return w


## The cabin's frame (Airliner's: the ground under the nose tip; here the floor sits on the lounge's).
static func cabin_xf() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI), Vector3(AXIS_X, -Airliner.FLOOR_Y, DOOR_Z + Z_DOOR))


static func stub_xf() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI), Vector3(STUB_X, -Airliner.FLOOR_Y + STUB_LIFT, JOIN_HALL + Z_JOIN))


## The shift from the cabin to the stub (back is minus it).
static func offset() -> Vector3:
	return stub_xf().origin - cabin_xf().origin


## World z in the cabin of its frame's z (the stub's: + offset().z).
static func cabin_z(z: float) -> float:
	return DOOR_Z + Z_DOOR - z


static func join_z() -> float:
	return cabin_z(Z_JOIN)


## The cabin's floor footprint and the stub's (world), for the zone map.
static func cabin_rect() -> Rect2:
	return Rect2(AXIS_X - 1.7, cabin_z(Z_AFT), 3.4, Z_AFT - Z_FWD)


static func stub_rect() -> Rect2:
	return Rect2(STUB_X - 1.7, cabin_z(Z_STUB) + offset().z, 3.4, Z_STUB - Z_FWD)


## How white the haze is at the eye `p`: 0 clear, 1 nothing but haze (both sides of the join).
static func haze_at(p: Vector3) -> float:
	if p.y < -1.0 or p.y > 3.2:
		return 0.0
	if absf(p.x - AXIS_X) < HALF + 0.25 and p.z > cabin_z(Z_AFT) - 0.5 and p.z < cabin_z(Z_FWD) + 0.5:
		return smoothstep(-FADE_IN, -0.25, p.z - join_z())
	if absf(p.x - STUB_X) < HALF + 0.45 and p.z > JOIN_HALL - 3.0 and p.z < JOIN_HALL + FADE_OUT:
		return 1.0 - smoothstep(0.25, FADE_OUT, p.z - JOIN_HALL)
	return 0.0


func _build(t: Terminal) -> void:
	zone = t.zones.airhall
	# the cabin: forward end closed (in the haze), the door on its left (east, the lounge's side), rows from the door's
	# cross aisle forward into the haze; the ceiling lights on the grid the stub shares
	var spec := {"sec": Airliner.NARROW, "cz0": Z_FWD, "cz1": Z_AFT, "fwd_end": "plain", "door_z": Z_DOOR,
			"door_side": -1.0, "lining_x": LINING, "doors": [Z_DOOR], "seat_z0": Z_SEATS, "seat_z1": Z_DOOR - 1.0,
			"bins": Vector2(Z_FWD, Z_DOOR - 0.85), "light_z0": Airliner.CAB_Z0 + 1.1, "light_tint": LAMP,
			"light_gain": LAMP_GAIN}
	Airliner.build_cabin(self, cabin_xf(), zone, spec, "Cabin")
	# the stub: the same section from the hall's north wall to its cut end, no seats
	Airliner.build_cabin(self, stub_xf(), zone, {"sec": Airliner.NARROW, "cz0": Z_FWD, "cz1": Z_STUB, "fwd_end": "open",
			"aft_end": "plain", "door_z": NAN, "doors": [], "seat_z0": 0.0, "seat_z1": 0.0, "bins": Vector2(Z_FWD, Z_STUB),
			"light_z0": Airliner.CAB_Z0 + 1.1, "light_tint": LAMP, "light_gain": LAMP_GAIN}, "Stub")
	_stub_shell()
	_door_front()
	_haze()


## The stub's outside: the hull in the airliner's paint from the hall's north wall to the cut end, down into the
## deck's slab; the cut face across the end between the hull and the cabin's lining; colliders either side of it.
func _stub_shell() -> void:
	var root := Node3D.new()
	root.name = "StubShell"
	add_child(root)
	root.transform = stub_xf()
	var sec := Airliner.NARROW
	var r: float = sec.hull_r
	var cy: float = Airliner.FLOOR_Y + sec.axis_h
	var low := Airliner.FLOOR_Y - 0.3
	var th0 := asin((low - cy) / r)
	var hull := Airliner.Mesher.new()
	hull.smooth = false
	var n := 64
	var rows := []
	for zz: float in [Z_FWD, Z_STUB + 0.2]:
		var row: Array[int] = []
		for j in n + 1:
			var th := lerpf(th0, PI - th0, float(j) / n)
			var p := Vector3(r * cos(th), cy + r * sin(th), zz)
			# the paint measures heights from the wide-body's axis: the windows land at the cabin's
			row.append(hull.add(p, Vector3(cos(th), sin(th), 0), Vector2(zz, th), Vector2(p.y - Airliner.AXIS_Y, p.y)))
		rows.append(row)
	for j in n:
		var thm := lerpf(th0, PI - th0, (j + 0.5) / n)
		hull.quad(rows[0][j], rows[0][j + 1], rows[1][j + 1], rows[1][j], Vector3(cos(thm), sin(thm), 0))
	var mesh := ArrayMesh.new()
	hull.into(mesh, Airliner.paint_mat())
	# the cut: a ring from the cabin's outline (floor, walls, ceiling) out to the hull and the slab's line under it,
	# sampled round the section's centre (both outlines are star-shaped about it)
	var wall: Array = sec.wall
	var inner := PackedVector2Array()
	for p: Vector2 in wall:
		inner.append(Vector2(p.x, Airliner.FLOOR_Y + p.y))
	for k in range(wall.size() - 1, -1, -1):
		inner.append(Vector2(-wall[k].x, Airliner.FLOOR_Y + wall[k].y))
	var c := Vector2(0, cy)
	var angs: Array[float] = []
	for k in 160:
		angs.append(TAU * k / 160.0)
	for p in inner:
		angs.append(fposmod((p - c).angle(), TAU))
	for a: float in [th0, PI - th0]:
		angs.append(fposmod(a, TAU))
	angs.sort()
	var cut := Airliner.Mesher.new()
	cut.smooth = false
	var face := Vector3(0, 0, -1)
	var ring: Array = []
	for a in angs:
		var d := Vector2(cos(a), sin(a))
		var t_out := r
		if d.y < -1e-4:
			t_out = minf(t_out, (low - cy) / d.y)
		var p_in := c + d * _ray_poly(c, d, inner)
		var p_out := c + d * t_out
		ring.append([cut.add(Vector3(p_in.x, p_in.y, Z_FWD), face), cut.add(Vector3(p_out.x, p_out.y, Z_FWD), face)])
	for k in ring.size():
		var r0: Array = ring[k]
		var r1: Array = ring[(k + 1) % ring.size()]
		cut.quad(r0[0], r0[1], r1[1], r1[0], face)
	cut.into(mesh, Mats.std(Color(0.5, 0.51, 0.5), 0.62, 0.15))
	var mi := MeshInstance3D.new()
	mi.name = "Hull"
	mi.mesh = mesh
	root.add_child(mi)
	# a spot from the roof so it reads white against the wall
	var top := Vector3(STUB_X, AirHall.roof_y(STUB_X) - 0.4, JOIN_HALL + 7.0)
	var s := Geo.spot(self, top, Vector3(STUB_X, 2.6, JOIN_HALL - 0.5), AirHall.LIGHT, 6.0, 22.0, 26.0)
	s.light_volumetric_fog_energy = 0.3
	zone.add_light(s)
	# nobody squeezes round it: the corner to the east wall, the deck's edge to the west
	var z0 := JOIN_HALL + Z_JOIN - Z_STUB
	var z1 := JOIN_HALL + Z_JOIN - Z_FWD
	var e0 := STUB_X + 1.78
	Geo.blocker(self, Vector3((e0 + AirHall.RECT.end.x) * 0.5, 1.25, (z0 + z1) * 0.5), Vector3(AirHall.RECT.end.x - e0, 2.5, z1 - z0))
	Geo.blocker(self, Vector3(STUB_X - 2.1, 1.25, (z0 + z1) * 0.5), Vector3(0.64, 2.5, z1 - z0))


## Distance from `c` along `d` to the closed outline `poly`.
static func _ray_poly(c: Vector2, d: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		var e := b - a
		var den := d.cross(e)
		if absf(den) < 1e-9:
			continue
		var t := (a - c).cross(e) / den
		var u := (a - c).cross(d) / den
		if t > 0.0 and u >= -1e-4 and u <= 1.0 + 1e-4:
			best = minf(best, t)
	return best


## The door from the lounge's side: a steel surround on the wall round the opening, the white leaf swung back flat
## against the wall forward of it (south), its little window.
func _door_front() -> void:
	var face := -19.8
	var w := Airliner.DOOR_W     # the frame's inner edge is the lining's (the wall's opening is 2 cm wider round it)
	var h := Airliner.DOOR_H
	var steel := Mats.std(Color(0.62, 0.63, 0.63), 0.32, 0.6)
	for s: float in [-1.0, 1.0]:
		Geo.box(self, Vector3(face + 0.015, (h + 0.09) * 0.5, DOOR_Z + s * (w * 0.5 + 0.045)), Vector3(0.03, h + 0.09, 0.09), steel, false)
	Geo.box(self, Vector3(face + 0.015, h + 0.045, DOOR_Z), Vector3(0.03, 0.09, w + 0.18), steel, false)
	var lz := DOOR_Z + w * 0.5 + 0.16 + Airliner.DOOR_W * 0.5
	Geo.box(self, Vector3(face + 0.09, Airliner.DOOR_H * 0.5 + 0.02, lz), Vector3(0.14, Airliner.DOOR_H, Airliner.DOOR_W),
			Mats.std(LEAF, 0.3, 0.05))
	Geo.box(self, Vector3(face + 0.162, Airliner.WIN_H, lz), Vector3(0.01, 0.34, 0.22), Mats.std(Color(0.05, 0.05, 0.055), 0.2), false)
	Geo.box(self, Vector3(face + 0.17, 1.0, lz - 0.32), Vector3(0.03, 0.06, 0.22), steel, false)


## The haze: in the cabin faint by the door and thickening toward the far end; in the stub thick, spilling out of
## its cut end onto the deck. Both glow with the zone like the hall's (Terminal.air_haze).
func _haze() -> void:
	var cz0 := cabin_z(Z_AFT)
	var cz1 := cabin_z(Z_FWD)
	var jz := join_z()
	_fog(AABB(Vector3(AXIS_X - 1.72, 0.0, cz0), Vector3(3.44, 2.25, cz1 - cz0)),
			func(z: float) -> float: return 0.03 + 2.6 * exp(minf(z - jz, 0.6) / 2.2), 3.4)
	var sz0 := JOIN_HALL + Z_JOIN - Z_STUB
	var sz1 := JOIN_HALL + 2.9
	_fog(AABB(Vector3(STUB_X - 1.6, 0.0, sz0), Vector3(3.2, 2.25, sz1 - sz0)),
			func(z: float) -> float: return 0.02 + 2.6 * exp(-maxf(z - JOIN_HALL, 0.0) / 1.1), 2.7, 0.35)
	if Game.settings.quality != "high":
		# no volumetric fog: sheets of haze at the far end so it still ends in white
		for k in 5:
			var z := jz - 4.0 + k * 1.2
			_low_cards.append(_sheet(Vector3(AXIS_X, 1.15, z), 0.25 + 0.15 * k))


## A box of haze whose density runs along z by `curve` (per metre, world z), up to `top`; `edge` = how soft its sides.
func _fog(box: AABB, curve: Callable, top: float, edge := 0.06) -> void:
	var vol := FogVolume.new()
	vol.size = box.size
	var fm := FogMaterial.new()
	fm.density = top
	fm.albedo = Color(0.82, 0.9, 0.82)
	fm.edge_fade = edge
	var slices: Array[Image] = []
	var depth := 64
	for k in depth:
		var z := box.position.z + box.size.z * (k + 0.5) / depth
		var img := Image.create(2, 2, false, Image.FORMAT_RF)
		img.fill(Color(clampf(curve.call(z) / top, 0.0, 1.0), 0, 0))
		slices.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RF, 2, 2, depth, false, slices)
	fm.density_texture = tex
	vol.material = fm
	add_child(vol)
	vol.position = box.get_center()
	_fogs.append([fm, HAZE])


func _sheet(at: Vector3, alpha: float) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(3.4, 2.3)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(HAZE, alpha)
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = at
	return mi


## The zone's light now (0 off .. 1 full), as the hall's haze follows it.
func _light() -> float:
	return zone.panel_mat.emission_energy_multiplier / zone.panel_energy if zone.panel_energy > 0.0 else 0.0


func _process(_delta: float) -> void:
	var k := _light()
	for f: Array in _fogs:
		(f[0] as FogMaterial).emission = (f[1] as Color) * k
	for card in _low_cards:
		var m := (card.mesh as QuadMesh).material as StandardMaterial3D
		m.albedo_color = Color(HAZE.r * k, HAZE.g * k, HAZE.b * k, m.albedo_color.a)
	var cam := get_viewport().get_camera_3d()
	_whiteout(haze_at(cam.global_position) if cam else 0.0, k, cam)


## The world's depth fog at `a` (0 off .. 1 nothing but haze) in the haze's colour, and over the last of it the card
## on the camera that makes it exactly that colour everywhere (the volumetric fog lags a few frames after a shift).
func _whiteout(a: float, k: float, cam: Camera3D) -> void:
	if _env == null:
		for we: WorldEnvironment in get_tree().root.find_children("*", "WorldEnvironment", true, false):
			_env = we.environment
			break
	var col := Color(HAZE.r * k, HAZE.g * k, HAZE.b * k)
	if _env:
		if a > 0.001:
			_env.fog_enabled = true
			_fog_ours = true
			_env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
			_env.fog_light_color = col
			_env.fog_light_energy = 1.0
			_env.fog_sun_scatter = 0.0
			_env.fog_aerial_perspective = 0.0
			_env.fog_sky_affect = 1.0
			_env.fog_height_density = 0.0
			_env.fog_density = FOG_MAX * a * a
		elif _fog_ours:
			_env.fog_enabled = false
			_fog_ours = false
	var ca := smoothstep(0.72, 0.98, a)
	if _card != null and not is_instance_valid(_card):
		_card = null                                 # went with a camera that was freed
	if ca <= 0.0 or cam == null:
		if _card:
			_card.visible = false
		return
	if _card == null:
		_card_mat = StandardMaterial3D.new()
		_card_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_card_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_card_mat.no_depth_test = true
		_card_mat.disable_fog = true
		_card_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_card_mat.render_priority = Material.RENDER_PRIORITY_MAX
		var q := QuadMesh.new()
		q.size = Vector2(2.0, 2.0)
		q.material = _card_mat
		_card = MeshInstance3D.new()
		_card.name = "HazeCard"
		_card.mesh = q
		_card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_card.extra_cull_margin = 16.0
	if _card.get_parent() != cam:
		if _card.get_parent():
			_card.get_parent().remove_child(_card)
		cam.add_child(_card)
		_card.position = Vector3(0, 0, -0.12)
	_card.visible = true
	_card_mat.albedo_color = Color(col, ca)


func _physics_process(_delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Player
	if p == null:
		return
	var at := p.global_position
	if at.y < -1.0 or at.y > 2.5:
		return
	if absf(at.x - AXIS_X) < HALF + 0.15 and at.z > join_z() and at.z < cabin_z(Z_FWD) + 0.5:
		_shift(p, offset())
	elif absf(at.x - STUB_X) < HALF + 0.15 and at.z > JOIN_HALL - 3.0 and at.z < JOIN_HALL:
		_shift(p, -offset())


## Through the join: the same place in the other section, heading, pitch and pace kept.
func _shift(p: Player, by: Vector3) -> void:
	var yaw: float = p._yaw
	var pitch: float = p._pitch
	var mv := p.move_vel
	var vel := p.velocity
	p.teleport(Transform3D(Basis(), p.global_position + by))
	p.set_look(yaw, pitch)
	p.move_vel = mv
	p.velocity = vel
