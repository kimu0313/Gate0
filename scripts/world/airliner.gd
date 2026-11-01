class_name Airliner
extends RefCounted
## A wide-body airliner built in code, whole (AirHall parks it in its hall), so that its door stands open and you can
## walk into its cabin: a lofted fuselage with the upper deck's hump over the front, swept wings with four engines
## under them, tailplanes and fin, the landing gear. The paint is a shader on the hull's own coordinates
## (shaders/airliner_paint.gdshader): white, a grey belly, a deep red cheatline with a gold pinstripe, dark windows.
## The cabin (the cabin reference, seen from its back looking forward: a long cream cabin in a green haze) runs from
## a bulkhead just forward of the open door aft into the fog: the left-hand seats are gone, so a wide carpeted aisle
## runs along the left wall under its windows and a row of square ceiling lights; two blocks of three seats to its
## right, overhead bins over them, deep window bezels, grilles along the foot of the walls. You come in on the right,
## across the cross aisle at the door. The cabin's inside is on its own render layer (VIS_CABIN): only its own lights
## reach it, not the hall's (no light here casts shadows, so the hall's would shine straight through the roof).
##
## Frame: the ground under the nose tip is the origin, the nose points -Z and the body runs back along +Z, +X is its
## right side, Y up. The open door is the right-hand door 2 (DOOR_Z).

const LENGTH := 54.0
const R := 3.1                # fuselage radius (the constant section)
const AXIS_Y := 5.2           # its axis over the ground
const FLOOR_Y := 4.0          # the cabin floor (1.2 under the axis)
const NOSE := 8.0             # the nose's length (the radius grows to R)
const TAIL_Z := 40.0          # where the tail cone begins
const TAIL_R := 0.38          # the radius at the tail end
const HUMP := 1.55            # how far the upper deck rises over the fuselage (steeply behind the cockpit)
const DOOR_Z := 14.0          # the open door (right side) and its size
const DOOR_W := 1.07
const DOOR_H := 1.93
const DOORS := [6.4, 14.0, 25.5, 34.0]   # the doors down each side (the paint's outlines)
const WIN_Z0 := 8.6           # windows every WIN_PITCH from here (the paint and the cabin agree), their centres
const WIN_PITCH := 1.0        # WIN_H over the cabin floor
const WIN_H := 1.18
# wings, engines, tail
const WING_LE := 20.0         # the wing's leading edge at the centreline
const WING_ROOT := 10.5       # root chord (at the centreline)
const WING_TIP := 3.1
const WING_SPAN := 24.6       # half span
const WING_SWEEP := 40.0      # leading edge sweep (deg)
const WING_DIHEDRAL := 5.5
const WING_Y := 3.3           # the wing root's mid-thickness over the ground
const ENGINES := [9.3, 16.2]  # engine stations along each wing
# the cabin: the right wall's profile (x, height over the floor) up to the ceiling, mirrored for the left
const CAB_Z0 := 12.4          # forward bulkhead (a metre ahead of the open door)
const CAB_Z1 := 39.4          # aft bulkhead
const CEIL_H := 2.36
const WALL := [Vector2(2.6, 0.0), Vector2(2.6, 0.34), Vector2(2.74, 0.66), Vector2(2.76, 0.8), Vector2(2.68, 1.56),
		Vector2(2.52, 1.86), Vector2(2.26, 2.12), Vector2(1.96, 2.37)]
const SEAT_Z0 := 15.9         # the first row; rows SEAT_PITCH apart (none at a door: cross aisles there)
const SEAT_PITCH := 0.82
const SEAT_W := 0.48
const BLOCKS := [-1.4, 0.74]  # the seat blocks' left edges (three seats each); the wide aisle runs left of the first
const VIS_CABIN := 1 << 18    # render layer of the cabin's inside
## Cabin cross-sections: the wall's profile (right side, x and height over the floor up to the ceiling, mirrored for
## the left; the windows sit on its 4th segment), the ceiling, the seat blocks' left edges (three seats each), the bins'
## outlines and their doors' joints (x, centre height), the light boxes over the wide aisle (x, size) and the small ones
## (x, none if NAN), the fills' x, the aft curtain's first fold, the EXIT light (x, height), the lavatory door, the
## forward door and screen (x); the fuselage round it (radius, its axis over the floor).
## WIDE is the parked wide-body's (two blocks of three, bins over both). NARROW is the cabin reference's (CabinWay): a
## single-aisle cabin (3.4 m across) whose left-hand seats are gone, so a 1.5 m aisle runs along the left windows, three
## seats a row to its right under the only bins, one row of light boxes down the ceiling over the aisle.
const WIDE := {
	"wall": WALL, "ceil_h": CEIL_H, "blocks": BLOCKS,
	"bins": [[Vector2(-1.36, 1.74), Vector2(-1.42, 1.92), Vector2(-1.4, 2.14), Vector2(-1.3, CEIL_H), Vector2(0.06, CEIL_H),
			Vector2(0.06, 1.74)], [Vector2(0.74, 1.74), Vector2(2.5, 1.74), Vector2(2.4, 1.98), Vector2(2.2, 2.2),
			Vector2(1.96, CEIL_H), Vector2(0.66, CEIL_H), Vector2(0.74, 2.12), Vector2(0.78, 1.92)]],
	"joints": [Vector2(-1.39, 2.03), Vector2(0.76, 2.03)],
	"lamp": Vector3(-1.69, 0.54, 0.5), "lamp2": 0.39, "fill_x": -0.6, "aft_x": -1.0,
	"curtain_x": -1.48, "exit": Vector2(-1.95, 2.22), "lav_x": 0.39, "fwd_door_x": -1.95, "screen_x": -0.35,
	"hull_r": R, "axis_h": AXIS_Y - FLOOR_Y,
}
const NARROW := {
	"wall": [Vector2(1.48, 0.0), Vector2(1.48, 0.3), Vector2(1.64, 0.56), Vector2(1.7, 0.78), Vector2(1.66, 1.52),
			Vector2(1.53, 1.76), Vector2(1.3, 1.98), Vector2(1.0, 2.12), Vector2(0.72, 2.18)],
	"ceil_h": 2.18, "blocks": [0.02],
	"bins": [[Vector2(-0.02, 1.72), Vector2(1.47, 1.72), Vector2(1.32, 1.9), Vector2(1.0, 2.08), Vector2(0.72, 2.18),
			Vector2(0.06, 2.18), Vector2(-0.04, 2.06), Vector2(-0.07, 1.88)]],
	"joints": [Vector2(-0.05, 1.95)],
	"lamp": Vector3(-0.42, 0.56, 0.5), "lamp2": NAN, "fill_x": -0.5, "aft_x": -0.6,
	"curtain_x": -0.2, "exit": Vector2(-0.75, 2.02), "lav_x": 0.75, "fwd_door_x": -0.75, "screen_x": 0.6,
	"hull_r": 1.98, "axis_h": 1.0,
}

## What build() leaves for the hall: the cabin's lights (to keep the hall's off it) and the plane's root.
var root: Node3D
var cabin: Node3D
## The cabin's layout, the plane's own unless build_cabin() is given others (by these names): its ends (z0 forward, z1
## aft) and what closes each ("bulkhead" with the plane's fittings — forward a door and a screen, aft the lavatory
## door, the curtain, the EXIT light —, "plain", or "open": cut off, nothing there); the open door (none if NAN), its
## side (+1 right, -1 left) and how far out its lining runs (0 = to the hull); the doors whose cross aisles and window
## gaps it keeps; the seat rows (from seat_z0 aft while under seat_z1) and the bins' run; where the ceiling lights'
## 2.4 m grid starts (two cabins sharing it light alike where they meet); its cross-section (WIDE or NARROW).
var sec: Dictionary = WIDE
var cz0 := CAB_Z0
var cz1 := CAB_Z1
var fwd_end := "bulkhead"
var aft_end := "bulkhead"
var door_z := DOOR_Z
var door_side := 1.0
var lining_x := 0.0
var doors: Array = DOORS
var seat_z0 := SEAT_Z0
var seat_z1 := CAB_Z1 - 0.7
var bins := Vector2(SEAT_Z0 - 0.62, CAB_Z1)
var light_z0 := CAB_Z0 + 1.1
var light_tint := Color(0, 0, 0, 0)   # the lights' colour (none: the zone's panels') and how strong they are
var light_gain := 1.0


## The airliner at `xf` (its frame, see the class notes) under `parent`; the cabin's lights go on `zone`. With
## `open_door` false its door 2 is shut like the rest and there is no cabin inside (a set piece seen from afar).
static func build(parent: Node3D, xf: Transform3D, zone: LightZone, open_door := true) -> Airliner:
	var a := Airliner.new()
	a.root = Node3D.new()
	a.root.name = "Airliner"
	parent.add_child(a.root)
	a.root.transform = xf
	a.door_z = DOOR_Z if open_door else NAN
	a._exterior()
	if open_door:
		a._cabin(zone)
	return a


## A cabin on its own, no airliner round it (CabinWay), at `xf` in the same frame; `spec` sets any of the layout
## fields above by name.
static func build_cabin(parent: Node3D, xf: Transform3D, zone: LightZone, spec: Dictionary, node_name := "Cabin") -> Airliner:
	var a := Airliner.new()
	for k: String in spec:
		a.set(k, spec[k])
	a.root = Node3D.new()
	a.root.name = node_name
	parent.add_child(a.root)
	a.root.transform = xf
	a._cabin(zone)
	return a


# --------------------------------------------------------------------------------------------
## Triangles with their normals: either smooth (each face adds its normal to its corners) or given per corner.
class Mesher:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	var smooth := true

	func add(p: Vector3, normal := Vector3.ZERO, t := Vector2.ZERO, t2 := Vector2.ZERO) -> int:
		v.append(p)
		n.append(normal)
		uv.append(t)
		uv2.append(t2)
		return v.size() - 1

	## A triangle turned to face `out` (Godot's front faces wind clockwise seen from the front).
	func tri(a: int, b: int, c: int, out: Vector3) -> void:
		var fn := (v[b] - v[a]).cross(v[c] - v[a])
		if fn.dot(out) > 0.0:
			var t := b
			b = c
			c = t
			fn = -fn
		idx.append(a)
		idx.append(b)
		idx.append(c)
		if smooth:
			n[a] -= fn
			n[b] -= fn
			n[c] -= fn

	## a, b, c, d round a quad.
	func quad(a: int, b: int, c: int, d: int, out: Vector3) -> void:
		tri(a, b, c, out)
		tri(a, c, d, out)

	## A box (flat faces) in the frame `xf`.
	func box(xf: Transform3D, size: Vector3) -> void:
		var h := size * 0.5
		for ax in 3:
			for sgn: float in [-1.0, 1.0]:
				var nl := Vector3.ZERO
				nl[ax] = sgn
				var u := Vector3.ZERO
				u[(ax + 1) % 3] = h[(ax + 1) % 3]
				var w := Vector3.ZERO
				w[(ax + 2) % 3] = h[(ax + 2) % 3]
				var c := nl * h[ax]
				var out := (xf.basis * nl).normalized()
				var q: Array[int] = []
				for k: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
					q.append(add(xf * (c + u * k.x + w * k.y), out))
				var keep := smooth
				smooth = false
				quad(q[0], q[1], q[2], q[3], out)
				smooth = keep

	func arrays() -> Array:
		for i in n.size():
			n[i] = n[i].normalized() if n[i].length() > 1e-9 else Vector3.UP
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_TEX_UV2] = uv2
		arr[Mesh.ARRAY_INDEX] = idx
		return arr

	func into(mesh: ArrayMesh, mat: Material) -> void:
		if idx.is_empty():
			return
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays())
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


static func _instance(parent: Node3D, mesh: Mesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _multi(parent: Node3D, mesh: Mesh, xforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
	return mmi


static func _one(m: Mesher, mat: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	m.into(mesh, mat)
	return mesh


# --------------------------------------------------------------------------------------------
## The fuselage's section at `z`: x = its centre's height, y = its radius, z = how far the hump rises over its top.
static func section(z: float) -> Vector3:
	var r := R
	var cy := AXIS_Y
	if z < NOSE:
		var t := clampf(z / NOSE, 0.0, 1.0)
		r = R * sqrt(maxf(0.0, 1.0 - pow(1.0 - t, 2.0)))
		cy = AXIS_Y - 0.75 * pow(1.0 - t, 2.0)
	elif z > TAIL_Z:
		var t := clampf((z - TAIL_Z) / (LENGTH - TAIL_Z), 0.0, 1.0)
		r = lerpf(R, TAIL_R, pow(t, 1.15))
		cy = AXIS_Y + R - 0.6 * t - r            # the top runs on nearly level, the belly sweeps up
	var hump := HUMP * smoothstep(1.2, 6.0, z) * (1.0 - smoothstep(16.0, 27.0, z))
	return Vector3(cy, r, hump)


## A point of the hull at `z`, `th` round it (0 = its right side, PI/2 = its top).
static func hull_point(z: float, th: float) -> Vector3:
	var s := section(z)
	var sn := sin(th)
	return Vector3(s.y * cos(th), s.x + s.y * sn + s.z * pow(maxf(sn, 0.0), 4.0), z)


static func _hull_normal(z: float, th: float) -> Vector3:
	var e := 0.01
	var dth := hull_point(z, th + e) - hull_point(z, th - e)
	var dz := hull_point(minf(z + e, LENGTH), th) - hull_point(maxf(z - e, 0.0), th)
	var nrm := dth.cross(dz)
	return nrm.normalized() if nrm.length() > 1e-8 else Vector3(0, 0, -1)


## Half the cabin's width at `h` over its floor, on the hull (the constant section).
static func hull_half(h: float) -> float:
	return sqrt(maxf(0.0, R * R - pow(h - (AXIS_Y - FLOOR_Y), 2.0)))


## The right wall's x at `h` over the floor on the profile `pts` (piecewise straight).
static func profile_x(pts: Array, h: float) -> float:
	for k in pts.size() - 1:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		if h <= b.y or k == pts.size() - 2:
			return lerpf(a.x, b.x, clampf((h - a.y) / maxf(b.y - a.y, 1e-4), 0.0, 1.0))
	return pts[0].x


## This cabin's right wall at `h` over the floor.
func _wx(h: float) -> float:
	return profile_x(sec.wall, h)


# --------------------------------------------------------------------------------------------
## The hull's paint (shaders/airliner_paint.gdshader) set up for this airliner: its doors and windows.
static func paint_mat() -> Material:
	return Mats.shader_mat("res://shaders/airliner_paint.gdshader", {"doors": Vector4(DOORS[0], DOORS[1], DOORS[2],
			DOORS[3]), "win_z0": WIN_Z0, "win_pitch": WIN_PITCH, "win_h": WIN_H - (AXIS_Y - FLOOR_Y),
			"door_h0": FLOOR_Y - AXIS_Y, "door_h1": FLOOR_Y + DOOR_H - AXIS_Y, "door_w": DOOR_W, "length_z": LENGTH,
			"band": Color(0.66, 0.04, 0.05), "gold": Color(0.9, 0.66, 0.2)})   # deep enough to read through the green haze


func _exterior() -> void:
	var paint := paint_mat()
	var hull := _instance(root, _hull_mesh(paint))
	hull.name = "Hull"
	var white := Mats.std(Color(0.84, 0.85, 0.84), 0.3, 0.05)
	var grey := Mats.std(Color(0.7, 0.71, 0.72), 0.38, 0.12)
	var lip := Mats.get_mat("metal")
	var dark := Mats.std(Color(0.05, 0.05, 0.055), 0.5, 0.3)
	# wings and tailplanes (grey), fin (white)
	var wings := Mesher.new()
	var tails := Mesher.new()
	for side: float in [-1.0, 1.0]:
		var sw := tan(deg_to_rad(WING_SWEEP))
		var dh := tan(deg_to_rad(WING_DIHEDRAL))
		_airfoil(wings, [[Vector3(0, WING_Y, WING_LE), WING_ROOT, 0.12],
				[Vector3(side * WING_SPAN, WING_Y + WING_SPAN * dh, WING_LE + WING_SPAN * sw), WING_TIP, 0.08]],
				Vector3(0, 0, 1), Vector3.UP)
		var tz := 44.0
		var ty := section(46.0).x
		_airfoil(wings, [[Vector3(0, ty, tz), 5.6, 0.1],
				[Vector3(side * 8.5, ty + 8.5 * tan(deg_to_rad(7.0)), tz + 8.5 * sw), 1.9, 0.08]], Vector3(0, 0, 1), Vector3.UP)
	_airfoil(tails, [[Vector3(0, 7.7, 40.6), 9.4, 0.1], [Vector3(0, 15.3, 48.2), 3.4, 0.08]], Vector3(0, 0, 1), Vector3.RIGHT)
	var parts := ArrayMesh.new()
	wings.into(parts, grey)
	tails.into(parts, white)
	# engines: nacelles on pylons under the wings, a polished intake lip, a dark fan face, the core's exhaust cone
	var cowl := Mesher.new()
	var lips := Mesher.new()
	var fans := Mesher.new()
	for side: float in [-1.0, 1.0]:
		for e: float in ENGINES:
			var u := e / WING_SPAN
			var chord := lerpf(WING_ROOT, WING_TIP, u)
			var half := 0.5 * lerpf(0.12, 0.08, u) * chord
			var le := Vector3(side * e, WING_Y + e * tan(deg_to_rad(WING_DIHEDRAL)), WING_LE + e * tan(deg_to_rad(WING_SWEEP)))
			var axis := Vector3(le.x, le.y - half - 1.28, le.z - 2.4)
			_lathe(cowl, axis, [Vector2(0.12, 0.97), Vector2(0.45, 1.03), Vector2(2.2, 1.0), Vector2(3.8, 0.84),
					Vector2(4.5, 0.62)])
			_lathe(lips, axis, [Vector2(0.0, 0.84), Vector2(0.12, 0.97)])
			_lathe(lips, axis, [Vector2(0.0, 0.84), Vector2(0.4, 0.8)], true)
			_lathe(lips, axis, [Vector2(4.4, 0.56), Vector2(5.3, 0.16)])
			_lathe(fans, axis, [Vector2(0.4, 0.8), Vector2(0.4, 0.14), Vector2(0.15, 0.0)])
			# pylon from the cowl's top up into the wing
			var top := axis.y + 0.95
			var bottom := le.y - half + 0.15
			cowl.box(Transform3D(Basis(), Vector3(axis.x, (top + bottom) * 0.5, axis.z + 2.6)), Vector3(0.32, bottom - top, 3.6))
	cowl.into(parts, white)
	lips.into(parts, lip)
	fans.into(parts, dark)
	_instance(root, parts).name = "Wings"
	_gear(dark, lip)
	# the open door's leaf, swung out and forward along the body
	if is_nan(door_z):
		return
	var leaf := Mesher.new()
	var lx := hull_half(DOOR_H * 0.5) + 0.32
	leaf.box(Transform3D(Basis(), Vector3(lx, FLOOR_Y + DOOR_H * 0.5, DOOR_Z - 1.75)), Vector3(0.14, DOOR_H, DOOR_W))
	var lw := Mesher.new()
	lw.box(Transform3D(Basis(), Vector3(lx + 0.072, FLOOR_Y + WIN_H, DOOR_Z - 1.75)), Vector3(0.01, 0.34, 0.22))
	var lm := ArrayMesh.new()
	leaf.into(lm, white)
	lw.into(lm, dark)
	_instance(root, lm).name = "DoorLeaf"


## The hull, lofted ring by ring (dense at the nose and the tail), with the open door's hole cut out; UVs for the
## paint: (z, angle), (height over the section's centre, height over the ground). The seam runs along the belly.
func _hull_mesh(mat: Material) -> ArrayMesh:
	var shut := is_nan(door_z)                       # no hole: the door's only painted on
	var dz0 := DOOR_Z - DOOR_W * 0.5 if not shut else -100.0
	var dz1 := DOOR_Z + DOOR_W * 0.5 if not shut else -100.0
	var zs: Array[float] = []
	for i in 30:
		zs.append(NOSE * pow(float(i) / 30.0, 1.6))
	var z := NOSE
	while z < TAIL_Z - 0.01:
		if absf(z - dz0) > 0.15 and absf(z - dz1) > 0.15:
			zs.append(z)
		z += 0.8
	for i in 29:
		zs.append(TAIL_Z + (LENGTH - TAIL_Z) * i / 28.0)
	if not shut:
		zs.append(dz0)
		zs.append(dz1)
	zs.sort()
	var tb := asin((FLOOR_Y - AXIS_Y) / R)
	var tt := asin((FLOOR_Y + DOOR_H - AXIS_Y) / R)
	var ths: Array[float] = []
	var segs := 76
	for j in segs + 1:
		var th := -PI * 0.5 + TAU * j / segs
		if absf(th - tb) > 0.03 and absf(th - tt) > 0.03:
			ths.append(th)
	ths.append(tb)
	ths.append(tt)
	ths.sort()
	var m := Mesher.new()
	m.smooth = false
	var rows := []
	for zz: float in zs:
		var s := section(zz)
		var row: Array[int] = []
		for th: float in ths:
			var p := hull_point(zz, th)
			row.append(m.add(p, _hull_normal(zz, th), Vector2(zz, th), Vector2(p.y - s.x, p.y)))
		rows.append(row)
	for i in zs.size() - 1:
		var door_ring := zs[i] >= dz0 - 1e-4 and zs[i + 1] <= dz1 + 1e-4
		for j in ths.size() - 1:
			if door_ring and ths[j] >= tb - 1e-4 and ths[j + 1] <= tt + 1e-4:
				continue
			var a: int = rows[i][j]
			var b: int = rows[i][j + 1]
			var c: int = rows[i + 1][j + 1]
			var d: int = rows[i + 1][j]
			m.quad(a, b, c, d, m.n[a] + m.n[c])
	# the tail's exhaust closed off
	var last := section(LENGTH)
	var centre := m.add(Vector3(0, last.x, LENGTH), Vector3(0, 0, 1), Vector2(LENGTH, 0), Vector2(0, last.x))
	var ring: Array[int] = []
	for th: float in ths:
		var p := hull_point(LENGTH, th)
		ring.append(m.add(p, Vector3(0, 0, 1), Vector2(LENGTH, th), Vector2(p.y - last.x, p.y)))
	for j in ring.size() - 1:
		m.tri(centre, ring[j], ring[j + 1], Vector3(0, 0, 1))
	return _one(m, mat)


## Lofted airfoil (NACA 4-digit thickness) through `secs` ([leading edge, chord, thickness ratio] each), chords along
## `chord_dir`, thickness along `thick_dir`; the last section is capped (the first lies inside the body).
static func _airfoil(m: Mesher, secs: Array, chord_dir: Vector3, thick_dir: Vector3) -> void:
	var f := [0.0, 0.012, 0.04, 0.09, 0.16, 0.26, 0.38, 0.52, 0.66, 0.8, 0.92, 1.0]
	var rows := []
	var inner := []
	for s: Array in secs:
		var le: Vector3 = s[0]
		var c: float = s[1]
		var t: float = s[2]
		var row: Array[int] = []
		for k in range(f.size() - 1, -1, -1):
			row.append(m.add(le + chord_dir * f[k] * c + thick_dir * _naca(f[k], t) * c))
		for k in range(1, f.size()):
			row.append(m.add(le + chord_dir * f[k] * c - thick_dir * _naca(f[k], t) * c))
		rows.append(row)
		inner.append(le + chord_dir * 0.3 * c)
	for i in rows.size() - 1:
		for k in rows[i].size() - 1:
			var a: int = rows[i][k]
			var b: int = rows[i][k + 1]
			var c: int = rows[i + 1][k + 1]
			var d: int = rows[i + 1][k]
			var mid := (m.v[a] + m.v[c]) * 0.5
			var core: Vector3 = (inner[i] + inner[i + 1]) * 0.5
			m.quad(a, b, c, d, mid - core)
	var tip: Array = rows[rows.size() - 1]
	var span_out: Vector3 = (inner[inner.size() - 1] - inner[inner.size() - 2]).normalized()
	var tc := m.add(inner[inner.size() - 1])
	for k in tip.size() - 1:
		m.tri(tc, tip[k], tip[k + 1], span_out)


static func _naca(x: float, t: float) -> float:
	return 5.0 * t * (0.2969 * sqrt(x) - 0.126 * x - 0.3516 * x * x + 0.2843 * x * x * x - 0.1015 * x * x * x * x)


## A body of revolution round an axis along +Z from `at`: `prof` = (distance back, radius) points; faces outward (or
## inward, `inward`); a flat ring (no length) faces forward.
static func _lathe(m: Mesher, at: Vector3, prof: Array, inward := false) -> void:
	var segs := 28
	var rows := []
	for p: Vector2 in prof:
		var row: Array[int] = []
		for j in segs:
			var a := TAU * j / segs
			row.append(m.add(at + Vector3(cos(a) * p.y, sin(a) * p.y, p.x)))
		rows.append(row)
	for i in prof.size() - 1:
		var p0: Vector2 = prof[i]
		var p1: Vector2 = prof[i + 1]
		for j in segs:
			var j1 := (j + 1) % segs
			var ang := TAU * (j + 0.5) / segs
			var out := Vector3(cos(ang), sin(ang), 0.0)
			if absf(p1.x - p0.x) < 1e-4:
				out = Vector3(0, 0, -1)
			elif inward:
				out = -out
			m.quad(rows[i][j], rows[i][j1], rows[i + 1][j1], rows[i + 1][j], out)


## Landing gear: the nose gear (two wheels) and four main bogies of four, struts up into the body and the wings.
func _gear(tyre_mat: Material, metal: Material) -> void:
	var tyres := Mesher.new()
	var hubs := Mesher.new()
	var struts := Mesher.new()
	var wheel := func(c: Vector3, r: float, w: float) -> void:
		_lathe_x(tyres, c, r, w)
		_lathe_x(hubs, c, r * 0.55, w + 0.02)
	for sx: float in [-0.3, 0.3]:
		wheel.call(Vector3(sx, 0.48, 6.6), 0.48, 0.3)
	struts.box(Transform3D(Basis(), Vector3(0, 1.3, 6.6)), Vector3(0.22, 1.7, 0.22))
	for g: Vector2 in [Vector2(1.8, 29.0), Vector2(-1.8, 29.0), Vector2(4.6, 27.2), Vector2(-4.6, 27.2)]:
		for dz: float in [-0.75, 0.75]:
			for dx: float in [-0.36, 0.36]:
				wheel.call(Vector3(g.x + dx, 0.62, g.y + dz), 0.62, 0.36)
		struts.box(Transform3D(Basis(), Vector3(g.x, 0.66, g.y)), Vector3(0.16, 0.16, 1.9))
		var top := section(g.y).x - section(g.y).y + 0.3 if absf(g.x) < 3.0 else WING_Y + 0.1
		struts.box(Transform3D(Basis(), Vector3(g.x, (0.66 + top) * 0.5, g.y)), Vector3(0.26, top - 0.66, 0.26))
	var mesh := ArrayMesh.new()
	tyres.into(mesh, tyre_mat)
	hubs.into(mesh, metal)
	struts.into(mesh, metal)
	_instance(root, mesh).name = "Gear"


## A closed cylinder along X (a wheel) centred on `c`.
static func _lathe_x(m: Mesher, c: Vector3, r: float, w: float) -> void:
	var segs := 20
	var rings := []
	for sx: float in [-w * 0.5, w * 0.5]:
		var row: Array[int] = []
		for j in segs:
			var a := TAU * j / segs
			row.append(m.add(c + Vector3(sx, cos(a) * r, sin(a) * r)))
		rings.append(row)
	for j in segs:
		var a := TAU * (j + 0.5) / segs
		var j1 := (j + 1) % segs
		m.quad(rings[0][j], rings[0][j1], rings[1][j1], rings[1][j], Vector3(0, cos(a), sin(a)))
	var keep := m.smooth
	m.smooth = false
	for k in 2:
		var sx := -w * 0.5 if k == 0 else w * 0.5
		var out := Vector3(signf(sx), 0, 0)
		var cc := m.add(c + Vector3(sx, 0, 0), out)
		var row: Array[int] = []
		for j in segs + 1:
			var a := TAU * j / segs
			row.append(m.add(c + Vector3(sx, cos(a) * r, sin(a) * r), out))
		for j in segs:
			m.tri(cc, row[j], row[j + 1], out)
	m.smooth = keep


# --------------------------------------------------------------------------------------------
## The cabin (see the class notes), its lights on `zone`.
func _cabin(zone: LightZone) -> void:
	cabin = Node3D.new()
	cabin.name = "Cabin"
	root.add_child(cabin)
	var liner := Mats.std(Color(0.8, 0.79, 0.75), 0.6)
	var bin_m := Mats.std(Color(0.84, 0.83, 0.79), 0.42)
	var carpet := Mats.shader_mat("res://shaders/carpet.gdshader", {"base_color": Color(0.23, 0.205, 0.18),
			"pattern_color": Color(0.255, 0.23, 0.2), "pattern_scale": 1.6})
	var dark := Mats.std(Color(0.08, 0.085, 0.085), 0.7)
	var seam_m := Mats.std(Color(0.6, 0.6, 0.57), 0.6)
	var wall: Array = sec.wall
	var ch: float = sec.ceil_h
	var foot: float = wall[0].x
	var ds := door_side
	var has_door := not is_nan(door_z)
	var dz0 := door_z - DOOR_W * 0.5 if has_door else INF
	var dz1 := door_z + DOOR_W * 0.5 if has_door else INF
	var len_z := cz1 - cz0
	var mid_z := (cz0 + cz1) * 0.5
	# floor (carpet), the door's sill
	Geo.box(cabin, Vector3(0, FLOOR_Y - 0.05, mid_z), Vector3(foot * 2.0 + 0.04, 0.1, len_z), carpet)
	if has_door:
		var out0 := _lining_out(0.0)
		Geo.box(cabin, Vector3(ds * ((foot + out0) * 0.5 + 0.01), FLOOR_Y - 0.045, door_z), Vector3(out0 - foot + 0.04, 0.11, DOOR_W),
				Mats.get_mat("metal"))
	# walls: the door's with the door cut out of it, the other whole; the ceiling over both
	var walls := Mesher.new()
	walls.smooth = false
	if has_door:
		_sweep(walls, wall, ds, cz0, dz0)
		_sweep(walls, wall, ds, dz1, cz1)
		var above: Array = [Vector2(_wx(DOOR_H), DOOR_H)]
		for p: Vector2 in wall:
			if p.y > DOOR_H:
				above.append(p)
		_sweep(walls, above, ds, dz0, dz1)
		_door_lining(walls, dz0, dz1)
	else:
		_sweep(walls, wall, ds, cz0, cz1)
	_sweep(walls, wall, -ds, cz0, cz1)
	var top: Vector2 = wall[wall.size() - 1]
	walls.box(Transform3D(Basis(), Vector3(0, FLOOR_Y + ch + 0.03, mid_z)), Vector3(top.x * 2.0 + 0.08, 0.06, len_z))
	# bulkheads: forward (a closed door, a dark screen) and aft (a curtain over the wide aisle, a lavatory door)
	if fwd_end != "open":
		_bulkhead(walls, cz0, 1.0)
	if aft_end != "open":
		_bulkhead(walls, cz1, -1.0)
	var mesh := ArrayMesh.new()
	walls.into(mesh, liner)
	var bin_mesh := Mesher.new()
	bin_mesh.smooth = false
	for poly: Array in sec.bins:
		_prism(bin_mesh, poly, bins.x, bins.y)
	bin_mesh.into(mesh, bin_m)
	var details := Mesher.new()
	details.smooth = false
	# the forward bulkhead's door (at the end of the wide aisle) and screen, the aft one's lavatory door
	if fwd_end == "bulkhead":
		details.box(Transform3D(Basis(), Vector3(sec.fwd_door_x, FLOOR_Y + 0.98, cz0 + 0.02)), Vector3(0.84, 1.96, 0.04))
		details.box(Transform3D(Basis(), Vector3(sec.screen_x, FLOOR_Y + minf(1.92, ch - 0.3), cz0 + 0.03)), Vector3(0.72, 0.42, 0.05))
	if aft_end == "bulkhead":
		details.box(Transform3D(Basis(), Vector3(sec.lav_x, FLOOR_Y + 0.98, cz1 - 0.02)), Vector3(0.62, 1.96, 0.04))
	# bin door joints every two rows
	var bz := bins.x + 1.64
	while bz < bins.y - 0.5:
		for j: Vector2 in sec.joints:
			details.box(Transform3D(Basis(), Vector3(j.x, FLOOR_Y + j.y, bz)), Vector3(0.08, 0.46, 0.012))
		bz += 1.64
	details.into(mesh, Mats.std(Color(0.42, 0.42, 0.41), 0.5))
	if aft_end == "bulkhead":
		var curtain := Mesher.new()
		curtain.smooth = false
		for i in 7:
			var cx: float = sec.curtain_x - i * 0.155
			curtain.box(Transform3D(Basis(), Vector3(cx, FLOOR_Y + ch * 0.5 + 0.01, cz1 - 0.12 - (i % 2) * 0.05)),
					Vector3(0.17, ch - 0.02, 0.05))
		curtain.into(mesh, Mats.std(Color(0.2, 0.25, 0.24), 0.9))
	_instance(cabin, mesh).name = "Liner"
	# the green EXIT light over the curtain, in the fog at the far end
	if aft_end == "bulkhead":
		var ex: Vector2 = sec.exit
		Geo.box(cabin, Vector3(ex.x, FLOOR_Y + ex.y, cz1 - 0.08), Vector3(0.36, 0.12, 0.05), Mats.get_mat("exit_green"), false)
	# windows (deep bezels, pale blinds drawn), seams between the wall panels, grilles at the foot of the walls
	_windows(dz0, dz1, dark, seam_m)
	_seats()
	_ceiling_lights(zone)
	_blockers(dz0, dz1)
	for gi: GeometryInstance3D in cabin.find_children("*", "GeometryInstance3D", true, false):
		gi.layers = VIS_CABIN


## The profile `pts` (x, height over the floor; mirrored for `side` -1) swept from z0 to z1, facing into the cabin;
## gentle joints are smooth, sharp ones (over ~40°) stay hard.
static func _sweep(m: Mesher, pts: Array, side: float, z0: float, z1: float) -> void:
	var nrm: Array[Vector2] = []
	for k in pts.size() - 1:
		var d: Vector2 = pts[k + 1] - pts[k]
		nrm.append(Vector2(-d.y, d.x).normalized())          # the right wall going up: its normal points in (-X)
	for k in pts.size() - 1:
		var na := nrm[k]
		var nb := nrm[k]
		if k > 0 and nrm[k - 1].dot(nrm[k]) > 0.77:
			na = (nrm[k - 1] + nrm[k]).normalized()
		if k < nrm.size() - 1 and nrm[k + 1].dot(nrm[k]) > 0.77:
			nb = (nrm[k + 1] + nrm[k]).normalized()
		var p0: Vector2 = pts[k]
		var p1: Vector2 = pts[k + 1]
		var n0 := Vector3(side * na.x, na.y, 0)
		var n1 := Vector3(side * nb.x, nb.y, 0)
		var a := m.add(Vector3(side * p0.x, FLOOR_Y + p0.y, z0), n0)
		var b := m.add(Vector3(side * p0.x, FLOOR_Y + p0.y, z1), n0)
		var c := m.add(Vector3(side * p1.x, FLOOR_Y + p1.y, z1), n1)
		var d := m.add(Vector3(side * p1.x, FLOOR_Y + p1.y, z0), n1)
		m.quad(a, b, c, d, Vector3(side * nrm[k].x, nrm[k].y, 0))


## How far out the open door's lining runs at `h` over the floor: to the hull, or to lining_x.
func _lining_out(h: float) -> float:
	return lining_x if lining_x > 0.0 else hull_half(h) + 0.02


## The open door's lining, from the cabin's wall out to the hull: the two jambs and the head.
func _door_lining(m: Mesher, dz0: float, dz1: float) -> void:
	var ds := door_side
	var hs: Array[float] = []
	for p: Vector2 in sec.wall:
		if p.y < DOOR_H:
			hs.append(p.y)
	hs.append(DOOR_H)
	for zz: float in [dz0, dz1]:
		var out := Vector3(0, 0, 1.0 if zz == dz0 else -1.0)
		for k in hs.size() - 1:
			var a := m.add(Vector3(ds * _wx(hs[k]), FLOOR_Y + hs[k], zz), out)
			var b := m.add(Vector3(ds * _lining_out(hs[k]), FLOOR_Y + hs[k], zz), out)
			var c := m.add(Vector3(ds * _lining_out(hs[k + 1]), FLOOR_Y + hs[k + 1], zz), out)
			var d := m.add(Vector3(ds * _wx(hs[k + 1]), FLOOR_Y + hs[k + 1], zz), out)
			m.quad(a, b, c, d, out)
	var down := Vector3.DOWN
	var y := FLOOR_Y + DOOR_H
	var a2 := m.add(Vector3(ds * _wx(DOOR_H), y, dz0), down)
	var b2 := m.add(Vector3(ds * _lining_out(DOOR_H), y, dz0), down)
	var c2 := m.add(Vector3(ds * _lining_out(DOOR_H), y, dz1), down)
	var d2 := m.add(Vector3(ds * _wx(DOOR_H), y, dz1), down)
	m.quad(a2, b2, c2, d2, down)


## A bulkhead across the cabin at `z`, its face toward `dir` (+1 aft, -1 forward): the walls' and ceiling's outline.
func _bulkhead(m: Mesher, z: float, dir: float) -> void:
	var wall: Array = sec.wall
	var poly := PackedVector2Array()
	for p: Vector2 in wall:
		poly.append(p)
	for k in range(wall.size() - 1, -1, -1):
		poly.append(Vector2(-wall[k].x, wall[k].y))
	var out := Vector3(0, 0, dir)
	var ids: Array[int] = []
	for p in poly:
		ids.append(m.add(Vector3(p.x, FLOOR_Y + p.y, z), out))
	var tris := _triangulate(poly)
	for t in range(0, tris.size(), 3):
		m.tri(ids[tris[t]], ids[tris[t + 1]], ids[tris[t + 2]], out)


## Geometry2D.triangulate_polygon either way round.
static func _triangulate(poly: PackedVector2Array) -> PackedInt32Array:
	var tris := Geometry2D.triangulate_polygon(poly)
	if tris.is_empty():
		var rev := poly.duplicate()
		rev.reverse()
		tris = Geometry2D.triangulate_polygon(rev)
		for i in tris.size():
			tris[i] = poly.size() - 1 - tris[i]
	return tris


## A prism of the outline `poly` (x, height over the floor) from z0 to z1, its ends capped.
static func _prism(m: Mesher, poly: Array, z0: float, z1: float) -> void:
	var cen := Vector2.ZERO
	for p: Vector2 in poly:
		cen += p
	cen /= poly.size()
	for k in poly.size():
		var p0: Vector2 = poly[k]
		var p1: Vector2 = poly[(k + 1) % poly.size()]
		var mid := (p0 + p1) * 0.5 - cen
		var e := p1 - p0
		var en := Vector2(-e.y, e.x).normalized()
		if en.dot(mid) < 0.0:
			en = -en
		var out := Vector3(en.x, en.y, 0)
		var a := m.add(Vector3(p0.x, FLOOR_Y + p0.y, z0), out)
		var b := m.add(Vector3(p1.x, FLOOR_Y + p1.y, z0), out)
		var c := m.add(Vector3(p1.x, FLOOR_Y + p1.y, z1), out)
		var d := m.add(Vector3(p0.x, FLOOR_Y + p0.y, z1), out)
		m.quad(a, b, c, d, out)
	var pv := PackedVector2Array(poly)
	var tris := _triangulate(pv)
	for zz: float in [z0, z1]:
		var out := Vector3(0, 0, -1.0 if zz == z0 else 1.0)
		var ids: Array[int] = []
		for p in pv:
			ids.append(m.add(Vector3(p.x, FLOOR_Y + p.y, zz), out))
		for t in range(0, tris.size(), 3):
			m.tri(ids[tris[t]], ids[tris[t + 1]], ids[tris[t + 2]], out)


## Windows down both walls (none at a door), each a deep moulded bezel round a pale drawn blind; a seam between the
## wall panels and a grille at the foot of the wall between each pair.
func _windows(dz0: float, dz1: float, dark: Material, seam_m: Material) -> void:
	var bez := Mesher.new()
	var a := _rrect(0.46, 0.68, 0.21)
	var b := _rrect(0.38, 0.58, 0.17)
	var c := _rrect(0.25, 0.38, 0.11)
	var rings := []
	for r: Array in [[a, 0.004], [b, 0.06], [c, 0.024]]:
		var row: Array[int] = []
		for p: Vector2 in r[0]:
			row.append(bez.add(Vector3(p.x, p.y, r[1])))
		rings.append(row)
	for i in 2:
		for k in a.size():
			var k1 := (k + 1) % a.size()
			bez.quad(rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k], Vector3(0, 0, 1))
	var pane := Mesher.new()
	pane.smooth = false
	var pc := pane.add(Vector3(0, 0, 0.022), Vector3(0, 0, 1))
	var pr: Array[int] = []
	for p: Vector2 in c:
		pr.append(pane.add(Vector3(p.x, p.y, 0.022), Vector3(0, 0, 1)))
	for k in pr.size():
		pane.tri(pc, pr[k], pr[(k + 1) % pr.size()], Vector3(0, 0, 1))
	var wm := ArrayMesh.new()
	bez.into(wm, Mats.std(Color(0.87, 0.86, 0.82), 0.4))
	var blind := Mats.std(Color(0.74, 0.77, 0.74), 0.5)
	blind.emission_enabled = true
	blind.emission = Color(0.55, 0.62, 0.56)
	blind.emission_energy_multiplier = 0.35
	pane.into(wm, blind)
	# the window panel (the wall's 4th segment) and its frame for each side
	var wall: Array = sec.wall
	var p3: Vector2 = wall[3]
	var p4: Vector2 = wall[4]
	var up2 := (p4 - p3).normalized()
	var t := (WIN_H - p3.y) / (p4.y - p3.y)
	var at := p3.lerp(p4, t)
	var in2 := Vector2(-up2.y, up2.x)          # the right wall's inward normal (as in _sweep)
	var wins: Array[Transform3D] = []
	var seams_r: Array[Transform3D] = []
	var seams_l: Array[Transform3D] = []
	var grilles: Array[Transform3D] = []
	for side: float in [1.0, -1.0]:
		var up := Vector3(side * up2.x, up2.y, 0)
		var inward := Vector3(side * in2.x, in2.y, 0)
		var basis := Basis(up.cross(inward).normalized(), up, inward)
		var k := 0
		while true:
			var z := WIN_Z0 + (k + 0.5) * WIN_PITCH
			k += 1
			if z > cz1 - 0.45:
				break
			if z < cz0 + 0.45:
				continue
			var at_door := false
			for dz: float in doors:
				at_door = at_door or absf(z - dz) < DOOR_W * 0.5 + 0.3
			if not at_door:
				wins.append(Transform3D(basis, Vector3(side * at.x, FLOOR_Y + at.y, z) + inward * 0.002))
			var sz := z + WIN_PITCH * 0.5
			if sz < cz1 - 0.1 and sz > cz0 + 0.1 and not (side == door_side and sz > dz0 - 0.05 and sz < dz1 + 0.05):
				(seams_r if side > 0.0 else seams_l).append(Transform3D(Basis(), Vector3(0, 0, sz)))
				if not at_door:
					grilles.append(Transform3D(Basis(), Vector3(side * (wall[0].x - 0.006), FLOOR_Y + 0.18, sz)))
	_multi(cabin, wm, wins).name = "Windows"
	var sp: Array = []
	for p: Vector2 in wall:
		if p.y >= 0.34:
			sp.append(p - Vector2(0.004, 0))
	for side: float in [1.0, -1.0]:
		var seam := Mesher.new()
		seam.smooth = false
		_sweep(seam, sp, side, -0.007, 0.007)
		_multi(cabin, _one(seam, seam_m), seams_r if side > 0.0 else seams_l).name = "Seams"
	var grille := Mesher.new()
	grille.smooth = false
	grille.box(Transform3D(), Vector3(0.012, 0.16, 0.5))
	_multi(cabin, _one(grille, dark), grilles).name = "Grilles"


## A rounded rectangle's outline (w x h, corner radius r), counter-clockwise from the right.
static func _rrect(w: float, h: float, r: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var steps := 6
	var cs := [Vector2(w * 0.5 - r, h * 0.5 - r), Vector2(-w * 0.5 + r, h * 0.5 - r), Vector2(-w * 0.5 + r, -h * 0.5 + r),
			Vector2(w * 0.5 - r, -h * 0.5 + r)]
	for q in 4:
		for i in steps + 1:
			var ang := (q + float(i) / steps) * PI * 0.5
			out.append(cs[q] + Vector2(cos(ang), sin(ang)) * r)
	return out


## Two blocks of three seats a row (facing forward: their white backs toward you as you look forward from the back);
## none at the doors, where cross aisles run.
func _seats() -> void:
	var fabric := Mesher.new()
	var cover := Mesher.new()
	var shell := Mesher.new()
	var frame := Mesher.new()
	for m: Mesher in [fabric, cover, shell, frame]:
		m.smooth = false
	frame.box(Transform3D(Basis(), Vector3(0, 0.33, 0.0)), Vector3(0.46, 0.05, 0.42))
	for lx: float in [-0.2, 0.2]:
		for lz: float in [-0.15, 0.18]:
			frame.box(Transform3D(Basis(), Vector3(lx, 0.165, lz)), Vector3(0.035, 0.33, 0.05))
	fabric.box(Transform3D(Basis(), Vector3(0, 0.43, -0.02)), Vector3(0.44, 0.12, 0.46))
	var back := Transform3D(Basis(Vector3.RIGHT, 0.17), Vector3(0, 0.45, 0.22))
	# the back: fabric, a white shell over its lower part behind (the tray in it), a cover over the headrest both sides
	fabric.box(back * Transform3D(Basis(), Vector3(0, 0.36, 0)), Vector3(0.44, 0.68, 0.09))
	shell.box(back * Transform3D(Basis(), Vector3(0, 0.27, 0.06)), Vector3(0.46, 0.5, 0.035))
	shell.box(back * Transform3D(Basis(), Vector3(0, 0.3, 0.083)), Vector3(0.34, 0.22, 0.012))
	for cz: float in [-0.052, 0.052]:
		cover.box(back * Transform3D(Basis(), Vector3(0, 0.6, cz)), Vector3(0.42, 0.2, 0.012))
	for ax: float in [-0.222, 0.222]:
		shell.box(Transform3D(Basis(), Vector3(ax, 0.63, 0.02)), Vector3(0.035, 0.06, 0.4))
		frame.box(Transform3D(Basis(), Vector3(ax, 0.5, 0.17)), Vector3(0.03, 0.2, 0.05))
	var mesh := ArrayMesh.new()
	fabric.into(mesh, Mats.std(Color(0.66, 0.59, 0.48), 0.92))
	cover.into(mesh, Mats.std(Color(0.8, 0.75, 0.66), 0.9))
	shell.into(mesh, Mats.std(Color(0.86, 0.85, 0.81), 0.38))
	frame.into(mesh, Mats.std(Color(0.42, 0.43, 0.44), 0.35, 0.6))
	var xfs: Array[Transform3D] = []
	for z: float in seat_rows():
		for left: float in sec.blocks:
			for i in 3:
				xfs.append(Transform3D(Basis(), Vector3(left + SEAT_W * (i + 0.5), FLOOR_Y, z)))
	if not xfs.is_empty():
		_multi(cabin, mesh, xfs).name = "Seats"


## The rows' z (the cabin's own frame).
func seat_rows() -> Array[float]:
	var out: Array[float] = []
	var z := seat_z0
	while z < seat_z1:
		var at_door := false
		for dz: float in doors:
			at_door = at_door or absf(z - dz) < 0.75
		if not at_door:
			out.append(z)
		z += SEAT_PITCH
	return out


## Square light boxes down the ceiling over the wide aisle (the zone's panel material, so they go with its lights)
## and small ones over the narrow aisle; an area light under every other big one and a few dim fills, all on the
## cabin's own layer.
func _ceiling_lights(zone: LightZone) -> void:
	var lights: Array[Light3D] = []
	var col: Color = light_tint if light_tint.a > 0.0 else zone.panel_mat.emission
	var lamp: Vector3 = sec.lamp
	var ch: float = sec.ceil_h
	var k := 0
	var z := light_z0
	while z < cz1 - 0.6:
		if z > cz0 + 0.4:
			var box := Geo.box(cabin, Vector3(lamp.x, FLOOR_Y + ch - 0.012, z), Vector3(lamp.y, 0.03, lamp.z), zone.panel_mat, false)
			box.name = "CabinLight"
			if z + 1.2 < cz1 - 0.3 and not is_nan(sec.lamp2):
				Geo.box(cabin, Vector3(sec.lamp2, FLOOR_Y + ch - 0.012, z + 1.2), Vector3(0.26, 0.03, 0.26), zone.panel_mat, false)
			if k % 2 == 0:
				var l := Geo.area_light(cabin, Vector3(lamp.x, FLOOR_Y + ch - 0.04, z), Vector2(lamp.y, lamp.z), col,
						2.4 * light_gain, 5.5)
				lights.append(l)
		k += 1
		z += 2.4
	z = cz0 + 2.5
	while z < cz1:
		var f := Geo.omni(cabin, Vector3(sec.fill_x, FLOOR_Y + 1.6, z), col, 0.32 * light_gain, 7.0)
		f.light_specular = 0.0
		f.light_volumetric_fog_energy = 0.0
		lights.append(f)
		z += 7.0
	# and one at the back, on the last rows' backs
	if aft_end == "bulkhead":
		var aft := Geo.omni(cabin, Vector3(sec.aft_x, FLOOR_Y + minf(1.9, ch - 0.3), cz1 - 0.4), col, 0.5 * light_gain, 5.0)
		aft.light_specular = 0.0
		aft.light_volumetric_fog_energy = 0.0
		lights.append(aft)
	for l in lights:
		l.light_cull_mask = VIS_CABIN
		zone.add_light(l)


## Colliders: the walls (the door's open at the door), bulkheads, the ceiling, the seat blocks between the cross
## aisles.
func _blockers(dz0: float, dz1: float) -> void:
	var y := FLOOR_Y + 1.25
	var mid := (cz0 + cz1) * 0.5
	var ds := door_side
	var wall: Array = sec.wall
	var wx: float = wall[0].x + 0.15
	var span := 0.0
	for p: Vector2 in wall:
		span = maxf(span, p.x * 2.0 + 0.3)
	if is_nan(door_z):
		Geo.blocker(cabin, Vector3(ds * wx, y, mid), Vector3(0.3, 2.5, cz1 - cz0))
	else:
		Geo.blocker(cabin, Vector3(ds * wx, y, (cz0 + dz0) * 0.5), Vector3(0.3, 2.5, dz0 - cz0))
		Geo.blocker(cabin, Vector3(ds * wx, y, (dz1 + cz1) * 0.5), Vector3(0.3, 2.5, cz1 - dz1))
	Geo.blocker(cabin, Vector3(-ds * wx, y, mid), Vector3(0.3, 2.5, cz1 - cz0))
	if fwd_end != "open":
		Geo.blocker(cabin, Vector3(0, y, cz0 - 0.1), Vector3(span, 2.5, 0.2))
	if aft_end != "open":
		Geo.blocker(cabin, Vector3(0, y, cz1 + 0.1), Vector3(span, 2.5, 0.2))
	Geo.blocker(cabin, Vector3(0, FLOOR_Y + float(sec.ceil_h) + 0.1, mid), Vector3(span, 0.2, cz1 - cz0))
	var rows := seat_rows()
	var run: Array[float] = []
	for i in rows.size():
		run.append(rows[i])
		if i == rows.size() - 1 or rows[i + 1] - rows[i] > SEAT_PITCH * 1.5:
			var z0 := run[0] - 0.36
			var z1 := run[run.size() - 1] + 0.42
			for left: float in sec.blocks:
				Geo.blocker(cabin, Vector3(left + SEAT_W * 1.5, FLOOR_Y + 0.6, (z0 + z1) * 0.5), Vector3(SEAT_W * 3.0, 1.2, z1 - z0))
			run.clear()
