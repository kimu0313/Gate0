class_name WarpedTerminal
extends Node3D
## The main story's airport (chapter 1): the terminal the night began in, put back together wrong. Nothing in it is
## broken — things sit in the wrong place, sunk cleanly into walls, floor and ceiling as if built that way, with soft
## contact shading at each join (_shade). Applied to the built Terminal (Terminal.warp lists the props it moves):
##   gates     the boarding bridge stands on Gate 0 (its door opens straight into the lounge); half the seat rows hang
##             from the ceiling, two stand out of the east wall, an airliner's nose comes out of the west wall and dips
##             into the floor; outside the windows the control tower stands on its head on the apron
##   corridor  a second airliner, tail first out of the west wall, on its side: its fin across the corridor overhead,
##             its tailplanes down into the floor and up into the ceiling; outside the windows a third stands nose-down
##             in the apron
##   security  one X-ray machine half in the floor, the other upside down on the ceiling, a metal detector arch too
##   lobby     the self check-in kiosks and the broadcast desk (with the PA console) half in the floor, the benches on
##             the ceiling, the departures board upside down, the arrivals board half in the strip's floor
## Every facility goes dead to [E] except the security office's door (Terminal.sec_use), which the chapter uses.

const BRIDGE_AT := Vector3(0, 0, -126.55)    # JetBridge origin on Gate 0; turned PI its gate door faces the lounge
const DESK_C := Vector3(0.2, 0, 6.05)        # the broadcast desk's middle (Terminal.info_desk coordinates)

## Look-dev viewpoints for `--warped-shots`: [name, eye, look-at].
const SHOTS := [
	["g01_gates_in", Vector3(0.0, 1.6, -97.5), Vector3(0.0, 2.0, -80.0)],
	["g02_ceiling_seats", Vector3(-4.0, 1.6, -83.0), Vector3(-9.0, 5.2, -90.0)],
	["g03_plane_nose", Vector3(-6.0, 1.6, -84.0), Vector3(-22.0, 2.5, -90.5)],
	["g04_wall_seats", Vector3(12.0, 1.6, -84.0), Vector3(25.8, 3.0, -88.0)],
	["g05_tower", Vector3(-5.0, 1.6, -95.0), Vector3(-12.0, 8.0, -116.0)],
	["g06_bridge_door", Vector3(0.0, 1.6, -91.0), Vector3(0.0, 1.6, -100.0)],
	["g07_nose_side", Vector3(-12.0, 1.6, -80.5), Vector3(-21.0, 2.4, -90.0)],
	["c01_corridor_tail", Vector3(0.5, 1.6, -73.0), Vector3(-6.0, 2.4, -59.0)],
	["c02_window_plane", Vector3(5.0, 1.6, -44.0), Vector3(33.0, 7.0, -50.0)],
	["s01_security", Vector3(1.1, 1.6, -26.5), Vector3(0.0, 1.5, -15.0)],
	["l01_lobby", Vector3(1.1, 1.6, -7.5), Vector3(2.0, 1.0, 5.0)],
	["l02_kiosks", Vector3(2.5, 1.6, -0.5), Vector3(6.2, 0.6, 4.0)],
	["l03_fids", Vector3(0.0, 1.6, 3.0), Vector3(0.0, 5.4, -2.1)],
	["p01_office_door", Vector3(-11.2, 1.6, -10.5), Vector3(-12.3, 1.2, -16.0)],
]

var t: Terminal
var _rng := RandomNumberGenerator.new()
var _shade_m: StandardMaterial3D
var _flip := Basis(Vector3.BACK, PI)


func apply(terminal: Terminal, bridge: JetBridge) -> void:
	t = terminal
	_rng.seed = 20261028
	_shade_m = _shade_material()
	_gate0(bridge)
	_gates()
	_corridor()
	_security()
	_lobby()
	_outside()
	_lights()
	for it: Interactable in t.find_children("*", "Interactable", true, false):
		it.enabled = false
		if it != t.sec_use:
			it.collision_layer = 0          # dead to [E]: the ray goes through, no prompt
	for k in t.shutters.keys():
		(t.shutters[k] as Shutter).open(true)
	Geo.fit_labels(self)


func _pivot(pos: Vector3, b := Basis()) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	n.transform = Transform3D(b, pos)
	return n


## A spot at `pos` aimed at `target` (both in terminal space).
func _spot(pos: Vector3, target: Vector3, color: Color, energy: float, reach: float, angle: float) -> SpotLight3D:
	var l := Geo.spot(self, pos, pos, color, energy, reach, angle)
	var d := (target - pos).normalized()
	l.look_at(to_global(target), Vector3.FORWARD if absf(d.y) > 0.98 else Vector3.UP)
	return l


## Soft dark falloff round the middle of a quad: the shading where something goes into a surface (nothing breaks;
## it just sits in it the way a thing that was built in would).
static func _shade_material() -> StandardMaterial3D:
	const N := 64
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var d := Vector2(x + 0.5 - N * 0.5, y + 0.5 - N * 0.5).length() / (N * 0.5)
			img.set_pixel(x, y, Color(0, 0, 0, 1.0 - smoothstep(0.55, 1.0, d)))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.albedo_color = Color(1, 1, 1, 0.72)
	return m


## Contact shading round where something goes into a surface: `footprint` = the size of its cut through the surface
## (x, y across it; on a floor or ceiling x runs along world X before the turn), centred on `pos`, the surface facing
## `n`, turned `roll` round it. Darkest at the edge of the footprint, gone a little way out.
func _shade(pos: Vector3, n: Vector3, footprint: Vector2, roll := 0.0) -> void:
	var q := QuadMesh.new()
	q.size = footprint * 1.6 + Vector2(0.6, 0.6)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _shade_m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var b: Basis
	if absf(n.y) > 0.9:
		b = Basis(Vector3.UP, roll) * Basis(Vector3.RIGHT, -PI / 2 * signf(n.y))
	else:
		b = Basis.looking_at(-n, Vector3.UP) * Basis(Vector3.BACK, roll)
	mi.transform = Transform3D(b, pos + n * 0.008)


## Puts one of the terminal's airliners (Props.aircraft) through a surface: its axis crosses `c` heading `f` (the nose
## direction), rolled `roll`, scaled to `length` m; `inside` m of it on the near side — the nose end when `nose_in`,
## else the tail end. Returns the crossing's local z (scaled) along the fuselage.
func _plane_through(plane: Node3D, length: float, c: Vector3, f: Vector3, roll: float, inside: float, nose_in: bool) -> float:
	var s := length / 61.0
	var b := Basis(f, roll) * Basis.looking_at(-f, Vector3.UP)
	var fus: Vector2 = plane.get_meta("fus")
	var zc := (30.4 * s - inside) if nose_in else (-31.0 * s + inside)
	plane.transform = Transform3D(b.scaled(Vector3.ONE * s), c - b * Vector3(0, fus.x * s, zc))
	plane.visible = true
	return zc


# --------------------------------------------------------------------------------------------
## The boarding bridge on Gate 0: its door fills the opening in the lounge's window wall (the Gate 0 panel is gone),
## a lintel over it, a steel threshold plate under it, the gate's name above.
func _gate0(bridge: JetBridge) -> void:
	bridge.attach(BRIDGE_AT, PI)
	if t.gate0_wall:
		t.gate0_wall.queue_free()
		t.gate0_wall = null
	Geo.box(self, Vector3(0, (2.6 + 5.5) * 0.5, -100.0), Vector3(3.0, 2.9, 0.4), Mats.get_mat("wall"))
	Geo.box(self, Vector3(0, 0.006, -100.1), Vector3(2.4, 0.012, 0.5), Mats.get_mat("metal_dark"), false)
	LevelKit.wall_sign(self, Vector3(0, 3.35, -99.79), 0.0, "GATE  0", Vector2(2.2, 0.55), "icon_departures")


## The gate lounge: the west half of the seating on the ceiling (a passenger sitting in it head down), two rows out of
## the east wall, the rest where it was; an airliner's nose out of the west wall, down into the floor.
func _gates() -> void:
	var gh := 5.5
	var east := Basis(Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(0, -1, 0))
	var on_wall := 0
	for row: Node3D in t.warp.gate_seats:
		var p := row.position
		if p.x < 0.0:
			row.transform = Transform3D(_flip * row.basis, Vector3(p.x, gh, p.z))
			if is_equal_approx(p.z, -87.2):
				Props.figure(row, Vector3(0.31, 0.0, 0.05), 0.0, true)
		elif p.z > -88.0:
			row.transform = Transform3D(east, Vector3(25.8, 2.1 + on_wall * 1.7, -88.0))
			on_wall += 1
	_shade(Vector3(-9.0, gh, -89.4), Vector3.DOWN, Vector2(5.4, 9.2))
	_shade(Vector3(25.8, 2.95, -88.0), Vector3.LEFT, Vector2(5.0, 3.0))
	# the nose, out of the west wall (inner face x -25.8) between the gate doors
	var c := Vector3(-25.8, 2.4, -90.5)
	var pitch := deg_to_rad(12.0)
	var yaw := deg_to_rad(14.0)
	var f := Vector3(cos(pitch) * cos(yaw), -sin(pitch), cos(pitch) * sin(yaw))
	_plane_through(t.final_plane, 30.0, c, f, deg_to_rad(-8.0), 9.0, true)
	var r := 3.68 * 30.0 / 61.0
	var b := Basis(f, deg_to_rad(-8.0)) * Basis.looking_at(-f, Vector3.UP)
	var blk := Geo.blocker(self, Vector3.ZERO, Vector3(r * 2.0, r * 2.0, 9.0))
	blk.transform = Transform3D(b, c + b * Vector3(0, 0, 4.5))
	_shade(c, Vector3.RIGHT, Vector2(r / cos(yaw), r / cos(pitch)) * 2.0)
	var dip := c + f * 6.5
	_shade(Vector3(dip.x, 0, dip.z), Vector3.UP, Vector2(4.6, 1.8), -yaw)


## The corridor: a second airliner tail first out of the west wall (inner face x -9.8) on its side — the fin across
## the corridor overhead, the tailplanes into the floor and the ceiling.
func _corridor() -> void:
	var plane: Node3D = t.warp.aircraft[1]
	var c := Vector3(-9.8, 2.4, -59.5)
	var f := Vector3(-cos(deg_to_rad(5.0)), -sin(deg_to_rad(5.0)), 0.0)      # the nose, beyond the wall
	_plane_through(plane, 30.0, c, f, PI / 2, 6.0, false)
	var r := 3.37 * 30.0 / 61.0
	var b := Basis(f, PI / 2) * Basis.looking_at(-f, Vector3.UP)
	var blk := Geo.blocker(self, Vector3.ZERO, Vector3(r * 2.0, r * 2.0, 6.0))
	blk.transform = Transform3D(b, c - b * Vector3(0, 0, 3.0))
	_shade(c, Vector3.RIGHT, Vector2(r, r) * 2.0)
	# the tailplanes, now upright: where they go into the floor and the ceiling, and a collider for the lower one
	var tp := plane.to_global(Vector3(0, 9.3, -27.5))
	var tl := to_local(tp)
	_shade(Vector3(tl.x, 0, tl.z), Vector3.UP, Vector2(2.2, 0.4))
	_shade(Vector3(tl.x, Terminal.COR_H, tl.z), Vector3.DOWN, Vector2(2.2, 0.4))
	Geo.blocker(self, Vector3(tl.x, 1.2, tl.z), Vector3(2.4, 2.4, 0.5))


## Security: lane 1's X-ray machine half in the floor, lane 2's upside down under the ceiling beams, a metal
## detector arch hanging off the ceiling.
func _security() -> void:
	var xr: Node3D = t.facilities.get("xray")
	if xr:
		xr.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(4), 0, deg_to_rad(-6))), xr.position + Vector3(0, -0.7, 0))
		_shade(Vector3(xr.position.x, 0, xr.position.z), Vector3.UP, Vector2(1.2, 3.4))
	var xr2: Node3D = null
	for n in t.get_children():
		if n is XrayMachine and (n as XrayMachine).id == "xray2":
			xr2 = n
	if xr2:
		xr2.transform = Transform3D(_flip, Vector3(xr2.position.x, Terminal.SEC_H - 0.45, xr2.position.z))
	LevelKit.metal_detector(_pivot(Vector3(-2.2, Terminal.SEC_H - 0.45, -24.2), _flip), Vector3.ZERO)


## The lobby and its strip: kiosks and the broadcast desk half in the floor, the benches on the ceiling, the
## departures board upside down, the arrivals board half in the floor.
func _lobby() -> void:
	for k: Node3D in t.warp.kiosks:
		var yaw := k.rotation.y
		var sink := _rng.randf_range(0.35, 1.15)
		var tilt := Vector3(deg_to_rad(_rng.randf_range(-24.0, 28.0)), 0, deg_to_rad(_rng.randf_range(-18.0, 18.0)))
		k.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_euler(tilt), Vector3(k.position.x, -sink, k.position.z))
		_shade(Vector3(k.position.x, 0, k.position.z), Vector3.UP, Vector2(0.65, 0.6), yaw)
	# the desk and the PA console on it, tipped and sunk round the desk's middle
	var m := Transform3D(Basis.from_euler(Vector3(deg_to_rad(9), 0, deg_to_rad(-12))), DESK_C + Vector3(0, -0.62, 0)) \
			* Transform3D(Basis(), -DESK_C)
	var desk: Node3D = t.warp.desk
	desk.transform = m * desk.transform
	var pa: Node3D = t.facilities.get("pa")
	if pa:
		pa.transform = m * pa.transform
	_shade(DESK_C, Vector3.UP, Vector2(3.0, 1.6))
	var lamp := Geo.omni(self, DESK_C + Vector3(0, 3.2, -0.4), Color(0.8, 0.88, 1.0), 1.6, 7.0)
	lamp.light_volumetric_fog_energy = 0.6
	for row: Node3D in t.warp.benches:
		var p := row.position
		row.transform = Transform3D(_flip * row.basis, Vector3(p.x, Terminal.HALL_H, p.z))
	var bag := Props.suitcase(self, Color(0.22, 0.24, 0.28))
	bag.transform = Transform3D(_flip * Basis(Vector3.UP, 0.4), Vector3(-1.6, Terminal.HALL_H, 1.0))
	var fids: Node3D = t.facilities.get("fids")
	if fids:
		fids.basis = _flip
	if t.arrivals:
		t.arrivals.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-15)) * Basis(Vector3.RIGHT, deg_to_rad(-25)), Vector3(7.4, 0.35, -5.6))
		_shade(Vector3(7.4, 0, -5.6), Vector3.UP, Vector2(4.5, 0.4), deg_to_rad(-15))


## Outside the glass: the control tower on its head on the apron beyond the gate lounge's windows, and an airliner
## standing nose-down in the apron off the corridor's windows.
func _outside() -> void:
	var tower: Node3D = t.warp.tower
	if tower:
		var k := 0.55
		tower.transform = Transform3D(Basis(Vector3.RIGHT, PI).scaled(Vector3.ONE * k), Vector3(-12.0, 51.0 * k - 1.6, -116.0))
		_shade(Vector3(-12.0, -0.1, -116.0), Vector3.UP, Vector2(5.8, 5.8))
		_mast(Vector3(-24.0, 0, -108.0), Vector3(-12.0, 8.0, -116.0), 40.0)
		_mast(Vector3(-2.0, 0, -112.0), Vector3(-12.0, 1.5, -116.0), 22.0)
	var plane: Node3D = t.warp.aircraft[0]
	var f := Vector3(-0.15, -0.97, 0.2).normalized()
	var b := Basis.looking_at(-f, Vector3.RIGHT)
	var fus: Vector2 = plane.get_meta("fus")
	var tip := Vector3(33.0, -6.0, -50.0)
	plane.transform = Transform3D(b, tip - b * Vector3(0, fus.x, 30.4))
	var ground := tip - f * ((-0.1 - tip.y) / -f.y)
	_shade(Vector3(ground.x, -0.1, ground.z), Vector3.UP, Vector2(7.6, 7.6))
	_mast(Vector3(22.0, 0, -40.0), ground + Vector3(0, 9.0, 0))


## An apron floodlight mast at `base` (a pole, a lamp head), its beam on `target`.
func _mast(base: Vector3, target: Vector3, energy := 18.0) -> void:
	Geo.cyl(self, base + Vector3(0, 9.0, 0), 0.2, 18.0, Mats.get_mat("steel_frame"))
	Geo.box(self, base + Vector3(0, 18.1, 0), Vector3(1.4, 0.5, 0.5), Mats.get_mat("lamp_white"), false)
	var sl := _spot(base + Vector3(0, 17.6, 0), target, Color(1.0, 0.9, 0.75), energy, 60.0, 26.0)
	sl.spot_attenuation = 0.8
	sl.light_volumetric_fog_energy = 0.3


## Night lights in the halls on the way, flickering; the closed side (baggage, the staff passage, the service rooms)
## and both offices dark.
func _lights() -> void:
	for zn: String in t.zones.keys():
		var on := zn in ["gates", "corridor", "security", "hall"]
		t.set_zone_light(zn, on, true)
		var z: LightZone = t.zones[zn]
		z.night_dim = 0.6
		z.erratic = 0.14 if on else 0.0
	# the dark staff passage: only the office's door plate and a dim light by it
	var l := Geo.omni(self, Vector3(-11.0, 2.4, -15.2), Color(0.7, 0.78, 0.95), 0.7, 5.0)
	l.light_volumetric_fog_energy = 0.5
