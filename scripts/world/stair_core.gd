class_name StairCore
extends Node
## The emergency stairs from the service corridors (4F) down to the lounge (1F) (user: "엘리베이터로 이동할 수도 있지만
## 계단으로 이동하는 공간도 필요해"): the steel door at the north end of the corridors' last run (its old 비상계단
## plate) opens onto a stairwell built far below the terminal with the corridors (ServiceHall's space): landings at
## 4F, 3F, 2F and 1F with a half landing between each, two flights a floor round a narrow well, painted floor numbers,
## caged lamps. 3F and 2F have their doors locked. At 1F a door leads into the stair lobby (전실), a small room with a
## second door at its far end, which opens on the lounge's 1F east wall beside the lift. Every landing is barred off
## from its flights by iron bars with a padlocked gate (_gate, 2026-11-08), so the stairs go nowhere now.
##
## The lobby is built twice like the lift's car (lobby(): one at the stairwell's foot, one behind the lounge's wall,
## both on Geo.VIS_SEALED): in each copy one door is real — the stairs' copy's door A, the lounge's copy's door B —
## and the other leads nowhere. Pressing the door that leads nowhere closes the real one (if it is open and you are
## clear of it), carries you to the other copy, where that same door is the real one, and opens it. Fire doors shut
## behind you by themselves.
##
## The stair hall is built in its own frame — its inside x X0..X1, z ZN..ZS, the 4F landing at y 0 against the wall
## the corridor comes through (ZS), the flights running toward -Z — and XF sets that frame into ServiceHall's
## coordinates (the terminal's, less ServiceHall.ORIGIN): turned round onto the south end of W, the corridor past the
## office's west door (user, a screenshot of that dead end: "계단 여기다가 넓이 두세배로 늘려서 크게 해줘. 원래 위치는
## 그냥 벽으로 막아주고" — it stood behind the last run's north end, 2.6 m wide; now 6.6 m, flights 3.15 m wide).
## hall_of / local_of convert; contains_hall tells whether a point is in it.

signal carried(to: int)

const XF := Transform3D(Basis(Vector3.UP, PI), Vector3(-25.3, 0, -10.45))
const DOOR_X := 1.6               # the doors at 3F, 2F, 1F in the ZS wall
const FLOOR_NO_X := 0.35         # the painted floor numbers on the ZS wall (between the 4F opening and the doors)
const X0 := -3.3
const X1 := 3.3
const WELL := [-0.15, 0.15]       # the wall between the flights
const ZS := 0.0                   # the inside's corridor-side face (the corridor wall's back face at 4F)
const OPEN := [-2.75, -0.55]      # where the corridor (W, its full width) comes through that wall at 4F
const LAND := 2.0
const TREAD := 0.28
const RISE := 0.175
const MIDL := 2.0
const FLOOR_H := 4.2
const TOP := 3.25                 # the stairwell's ceiling over 4F (the corridors')
const LAND_N := ZS - LAND         # where the floor landings end and the flights begin
const MID_S := LAND_N - 11 * TREAD   # where the half landings begin
const ZN := MID_S - MIDL          # the far wall's face
const BOTTOM := -3.0 * FLOOR_H    # 1F, -12.6
## The lobby: inside W wide, D deep between its two doors, HT high.
const LW := 2.0
const LD := 2.4
const LHT := 2.6
const DOOR_W := 0.92
const DOOR_H := 2.1
const LIGHT := Color(0.85, 0.95, 0.9)

var twins: Array[Dictionary] = []   # [the stairs' copy, the lounge's copy]
const REAL := ["a", "b"]
var _clear_t := {}                  # door -> how long the player has been clear of it while it stands open
var _inside := -1
var _moving := false
var top_door: Dictionary            # the 4F door from the corridor


## A point in the stair hall's own frame → ServiceHall's space, and back.
static func hall_of(p: Vector3) -> Vector3:
	return XF * p


static func local_of(hall_p: Vector3) -> Vector3:
	return XF.affine_inverse() * hall_p


## Inside the stair hall (any floor) or its lobby at the foot — `hall_p` in ServiceHall's space.
static func contains_hall(hall_p: Vector3) -> bool:
	var l := local_of(hall_p)
	if l.y < BOTTOM - 1.0 or l.y > 4.0:
		return false
	if l.x > X0 - 0.3 and l.x < X1 + 0.3 and l.z > ZN - 0.3 and l.z < ZS + 0.3:
		return true
	return l.y < BOTTOM + 3.0 and absf(l.x - DOOR_X) < LW * 0.5 + 0.4 and l.z >= ZS and l.z < ZS + LD + 0.8


# --------------------------------------------------------------------------------------------
## The stairwell, into ServiceHall `hall` (its own coordinates). Returns the stairs' copy of the lobby.
static func build(hall: ServiceHall) -> Dictionary:
	var root := Node3D.new()
	root.name = "StairCore"
	hall.add_child(root)
	root.transform = XF
	# (user, a photo of an old school stair hall: "난 비상구 계단이 아니라 이런 계단이 필요해 열려있는 공간. 벽 뚫려있는
	# 공간"): a painted dado with a rail line, a solid wall between the flights, no windows (user: "계단 공간에 창문
	# 없애고"), a floor number painted on every floor; no door at 4F — the corridor runs straight onto the landing. Its walls are the corridors' wall texture (user: "복도
	# 벽 텍스처를 계단 내려가는 곳 벽 텍스처로 넣어줘"): the concrete part repeating up all four floors (the band
	# belongs to one storey; the dado plays it, in its colour), lined up with the corridors' panels at 4F; its floors
	# and steps the corridors' concrete (user: "복도 바닥 텍스처를 계단에 넣어줘").
	var wall_m := Mats.shader_mat("res://shaders/corridor_wall.gdshader", {
		"albedo_tex": load("res://assets/textures/level/wall_corridor_concrete.png"), "with_band": false,
		"base_height": ServiceHall.ORIGIN.y, "wall_h": ServiceHall.H, "tile_w": ServiceHall.H})
	var conc := Mats.get_mat("floor_corridor_concrete")
	var soffit := Mats.std(Color(0.7, 0.7, 0.68), 0.9)
	var nosing := Mats.std(Color(0.07, 0.07, 0.07), 0.7)
	var rail := Mats.std(Color(0.1, 0.17, 0.14), 0.45, 0.3)
	var top_y := TOP + 0.15
	var low := BOTTOM - 0.3
	var cx := (X0 + X1) * 0.5
	var cz := (ZN + ZS) * 0.5
	# the shaft: west, east and north walls the whole height, its pit floor at 1F, its ceiling over 4F
	Geo.box(root, Vector3(X0 - 0.1, (top_y + low) * 0.5, cz), Vector3(0.2, top_y - low, ZS - ZN + 0.4), wall_m)
	Geo.box(root, Vector3(X1 + 0.1, (top_y + low) * 0.5, cz), Vector3(0.2, top_y - low, ZS - ZN + 0.4), wall_m)
	Geo.box(root, Vector3(cx, (top_y + low) * 0.5, ZN - 0.1), Vector3(X1 - X0, top_y - low, 0.2), wall_m)
	Geo.box(root, Vector3(cx, BOTTOM - 0.1, cz), Vector3(X1 - X0, 0.2, ZS - ZN), conc)
	# (its ceiling a centimetre under the corridors' dropped ceiling, which runs on over it: no shared face)
	Geo.box(root, Vector3(cx, TOP + 0.065, (ZN + ZS) * 0.5), Vector3(X1 - X0, 0.15, ZS - ZN), soffit, false)
	# at 4F the wall the corridor comes through: the corridor's own wall round its opening (ServiceHall), this hall's
	# own beyond it
	Geo.box(root, Vector3((OPEN[1] + 0.2 + X1 + 0.2) * 0.5, top_y * 0.5, ZS + 0.1), Vector3(X1 - OPEN[1], top_y, 0.2), wall_m)
	# the south wall under 4F, a door in it at every floor below
	for k in [1, 2, 3]:
		var y0: float = -k * FLOOR_H
		var y1: float = y0 + FLOOR_H
		var dl := DOOR_X - DOOR_W * 0.5 - 0.05
		var dr := DOOR_X + DOOR_W * 0.5 + 0.05
		var wz := ZS + 0.1
		var yb := y0 - (0.3 if k == 3 else 0.0)
		Geo.box(root, Vector3((X0 - 0.2 + dl) * 0.5, (yb + y1) * 0.5, wz), Vector3(dl - X0 + 0.2, y1 - yb, 0.2), wall_m)
		Geo.box(root, Vector3((dr + X1 + 0.2) * 0.5, (yb + y1) * 0.5, wz), Vector3(X1 + 0.2 - dr, y1 - yb, 0.2), wall_m)
		Geo.box(root, Vector3(DOOR_X, (y0 + DOOR_H + 0.05 + y1) * 0.5, wz), Vector3(dr - dl, y1 - y0 - DOOR_H - 0.05, 0.2), wall_m)
	# landings and flights, floor by floor
	for k in 3:
		var yf: float = -k * FLOOR_H
		var ym := yf - FLOOR_H * 0.5
		# (at 4F the corridors' floor runs up to ZS: the landing meets it)
		var ze := ZS
		Geo.box(root, Vector3(cx, yf - 0.1, (LAND_N + ze) * 0.5), Vector3(X1 - X0, 0.2, ze - LAND_N), conc)
		Geo.box(root, Vector3(cx, ym - 0.1, (ZN + MID_S) * 0.5), Vector3(X1 - X0, 0.2, MID_S - ZN), conc)
		Geo.box(root, Vector3(cx, yf - 0.2 - 0.004, (LAND_N + ze) * 0.5), Vector3(X1 - X0 - 0.01, 0.006, ze - LAND_N - 0.01), soffit, false)
		Geo.box(root, Vector3(cx, ym - 0.2 - 0.004, (ZN + MID_S) * 0.5), Vector3(X1 - X0 - 0.01, 0.006, MID_S - ZN - 0.01), soffit, false)
		_flight(root, (X0 + WELL[0]) * 0.5, WELL[0] - X0, LAND_N, yf, -1.0, conc, soffit, nosing)
		_flight(root, (WELL[1] + X1) * 0.5, X1 - WELL[1], MID_S, ym, 1.0, conc, soffit, nosing)
		# handrails on the outer walls, a painted dado along every wall the flights and landings pass
		_wall_rail(root, X0 + 0.065, LAND_N, yf, -1.0, rail)
		_wall_rail(root, X1 - 0.065, MID_S, ym, 1.0, rail)
		for f: Array in [[X0, 1.0, LAND_N, yf, -1.0], [WELL[0], -1.0, LAND_N, yf, -1.0], [X1, -1.0, MID_S, ym, 1.0], [WELL[1], 1.0, MID_S, ym, 1.0]]:
			_dado_slope(root, f[0], f[1], f[2], f[3], f[4])
		_dado_x(root, X0, 1.0, ZN, MID_S, ym)
		_dado_x(root, X1, -1.0, ZN, MID_S, ym)
		_dado_z(root, ZN, 1.0, X0, X1, ym)
	for k in 4:
		var yf: float = -k * FLOOR_H
		_dado_x(root, X0, 1.0, LAND_N, ZS, yf)
		_dado_x(root, X1, -1.0, LAND_N, ZS, yf)
	# the wall between the flights, floor to ceiling (the photo's closed well): you cannot drop down it or step across
	Geo.box(root, Vector3((WELL[0] + WELL[1]) * 0.5, (low + TOP) * 0.5, (MID_S + LAND_N) * 0.5),
		Vector3(WELL[1] - WELL[0], TOP - low, LAND_N - MID_S), wall_m)
	# 4F: a solid parapet over the east half, where the next flight drops away (no flight comes up into it from above)
	Geo.box(root, Vector3((WELL[1] + X1) * 0.5, 0.5, LAND_N - 0.075), Vector3(X1 - WELL[1], 1.0, 0.15), wall_m)
	Geo.box(root, Vector3((WELL[1] + X1) * 0.5, 1.015, LAND_N - 0.075), Vector3(X1 - WELL[1], 0.03, 0.19), Mats.std(Color(0.42, 0.43, 0.41), 0.5), false)
	_dado_z(root, LAND_N, 1.0, WELL[1], X1, 0.0)
	# 1F: the space under the stairs walled off
	var under_top := BOTTOM + FLOOR_H - 0.45
	Geo.box(root, Vector3((X0 + WELL[0]) * 0.5, (BOTTOM + under_top) * 0.5, LAND_N - 0.1), Vector3(WELL[0] - X0, under_top - BOTTOM, 0.2), wall_m)
	# a floor number on every floor (no windows in the hall any more)
	for k in 4:
		_floor_number(root, -k * FLOOR_H, 4 - k)
	# iron bars on every floor (user: "계단구역은 층마다 철창으로 막아줘"): each landing is shut off from the flights
	# that leave it, floor to ceiling, a padlocked gate in each — the way down at 4F, both ways at 3F and 2F, the way up
	# at 1F (4F's east half has its parapet, 1F's west half the wall under the stairs). They only rattle.
	for k in 4:
		var yf: float = -k * FLOOR_H
		var ytop := TOP - 0.012 if k == 0 else yf + FLOOR_H - 0.21     # (the ceiling over 4F, else the landing above)
		if k < 3:
			hall.stair_gates.append(_gate(root, X0, WELL[0], yf, ytop))
		if k > 0:
			hall.stair_gates.append(_gate(root, WELL[1], X1, yf, ytop))
	# the lamps
	var zone := hall.zone
	# (the hall is wide: a lamp on each side wall of every landing and half landing; one half landing's west lamp dead)
	for k in 4:
		var yf: float = -k * FLOOR_H
		var lz := (LAND_N + ZS) * 0.5
		_lamp(root, zone, Vector3(X0 + 0.07, yf + 2.45, lz), -PI / 2, true)
		_lamp(root, zone, Vector3(X1 - 0.07, yf + 2.45, lz), PI / 2, true)
		if k < 3:
			var ym := yf - FLOOR_H * 0.5
			var mz := (ZN + MID_S) * 0.5
			_lamp(root, zone, Vector3(X0 + 0.07, ym + 2.45, mz), -PI / 2, k != 1)
			_lamp(root, zone, Vector3(X1 - 0.07, ym + 2.45, mz), PI / 2, true)
	# the doors: 4F from the corridor (real, it shuts by itself), 3F and 2F locked, 1F into the lobby (lobby())
	for k in [1, 2]:
		var yf: float = -k * FLOOR_H
		var d := door(root, Transform3D(Basis(Vector3.UP, PI), Vector3(DOOR_X, yf, ZS + 0.1)), 0.2, false)
		d.use.callback = func(): Terminal.current.rattle(d)
		Geo.box(root, Vector3(DOOR_X, yf + 1.2, ZS + 0.9), Vector3(1.4, 2.6, 1.2), Mats.get_mat("void"), false)
	# haze and reverb
	var fm := FogMaterial.new()
	fm.density = 0.035
	fm.albedo = Color(0.5, 0.56, 0.53)
	fm.edge_fade = 0.1
	var fog := FogVolume.new()
	fog.size = Vector3(X1 - X0, TOP - BOTTOM, ZS - ZN)
	fog.material = fm
	root.add_child(fog)
	fog.position = Vector3(cx, (TOP + BOTTOM) * 0.5, cz)
	Lift._reverb(root, Vector3(cx, (TOP + BOTTOM) * 0.5, cz), Vector3(X1 - X0, TOP - BOTTOM, ZS - ZN), "RevLong", 0.36)
	# the stairs' copy of the lobby, south of the 1F door: door A in the stairwell's wall, door B at its far end
	return lobby(root, Transform3D(Basis(), Vector3(DOOR_X, BOTTOM, ZS + 0.2 + LD)), false, true)


## One flight: `w` wide on x `x`, from its top edge at (`z_top`, `y_top`) down 12 risers toward `dir` (-1: north,
## +1: south): steps with nosings, a soffit under them, a stringer on the well side, and a ramp to walk on.
static func _flight(root: Node3D, x: float, w: float, z_top: float, y_top: float, dir: float, conc: Material,
		soffit: Material, nosing: Material) -> void:
	for j in 11:
		var top := y_top - (j + 1) * RISE
		var zc := z_top + dir * (j + 0.5) * TREAD
		Geo.box(root, Vector3(x, top - 0.15, zc), Vector3(w, 0.3, TREAD), conc, false)
		Geo.box(root, Vector3(x, top + 0.002, zc + dir * (TREAD * 0.5 - 0.03)), Vector3(w - 0.02, 0.006, 0.05), nosing, false)
	var run := 12 * TREAD
	var drop := 12 * RISE
	var length := sqrt(run * run + drop * drop)
	var a := atan2(drop, run) * dir             # pitch about X (down toward `dir`)
	var n := Vector3(0, run, dir * drop) / length                # the slope's normal, up
	var mid := Vector3(x, y_top - drop * 0.5, z_top + dir * run * 0.5)
	# soffit: a slab parallel to the pitch line, its top 0.25 under it, 0.25 thick: the steps (0.3 deep) end inside it
	var s := Geo.box(root, mid - Vector3(0, 0.25, 0) - n * 0.125, Vector3(w, 0.25, length + 0.3), soffit, false)
	s.rotation.x = a
	# stringer on the well side
	var side := 1.0 if x < (WELL[0] + WELL[1]) * 0.5 else -1.0
	var st := Geo.box(root, mid + Vector3(side * (w * 0.5 - 0.015), -0.12, 0), Vector3(0.03, 0.42, length), soffit, false)
	st.rotation.x = a
	# the ramp you actually walk on: its top through the nosings, flush with both landings
	var ramp := Geo.blocker(root, mid - n * 0.1, Vector3(w, 0.2, length))
	ramp.rotation.x = a


## A flight's pitch: [run, drop, length, angle about X for `dir`].
static func _pitch(dir: float) -> Array:
	var run := 12 * TREAD
	var drop := 12 * RISE
	return [run, drop, sqrt(run * run + drop * drop), atan2(drop, run) * dir]


## A pipe handrail on brackets along a wall at `x`, over the flight from (`z_top`, `y_top`) down toward `dir`.
static func _wall_rail(root: Node3D, x: float, z_top: float, y_top: float, dir: float, rail: Material) -> void:
	var p := _pitch(dir)
	var mid := Vector3(x, y_top - p[1] * 0.5 + 0.88, z_top + dir * p[0] * 0.5)
	var hr := Geo.cyl(root, mid, 0.022, p[2] + 0.2, rail)
	hr.rotation.x = PI / 2 + p[3]
	var wall_side := -1.0 if x < (WELL[0] + WELL[1]) * 0.5 else 1.0
	for i in 3:
		var t := (i + 0.5) / 3.0
		Geo.box(root, Vector3(x + wall_side * 0.035, y_top - p[1] * t + 0.86, z_top + dir * p[0] * t), Vector3(0.07, 0.016, 0.016), rail, false)


## The dado's band (the corridors' wall band colour, sampled from their texture: 0.496, 0.529, 0.516), its rail line
## and the skirting (the band's dark foot).
static func _dado_mats() -> Array:
	return [Mats.std(Color(0.496, 0.529, 0.516), 0.55), Mats.std(Color(0.36, 0.39, 0.38), 0.5), Mats.std(Color(0.26, 0.25, 0.23), 0.6)]


## The painted dado (lower wall, its rail line, a dark skirting) on a wall face along Z at `x`, facing `face` (±X),
## from z0 to z1 on a floor at `y`.
static func _dado_x(root: Node3D, x: float, face: float, z0: float, z1: float, y: float) -> void:
	var m := _dado_mats()
	var mz := (z0 + z1) * 0.5
	var l := z1 - z0
	Geo.box(root, Vector3(x + face * 0.003, y + 0.45, mz), Vector3(0.006, 0.9, l), m[0], false)
	Geo.box(root, Vector3(x + face * 0.007, y + 0.91, mz), Vector3(0.014, 0.026, l), m[1], false)
	Geo.box(root, Vector3(x + face * 0.008, y + 0.05, mz), Vector3(0.016, 0.1, l), m[2], false)


## The same on a wall face along X at `z`, facing `face` (±Z), from x0 to x1.
static func _dado_z(root: Node3D, z: float, face: float, x0: float, x1: float, y: float) -> void:
	var m := _dado_mats()
	var mx := (x0 + x1) * 0.5
	var l := x1 - x0
	Geo.box(root, Vector3(mx, y + 0.45, z + face * 0.003), Vector3(l, 0.9, 0.006), m[0], false)
	Geo.box(root, Vector3(mx, y + 0.91, z + face * 0.007), Vector3(l, 0.026, 0.014), m[1], false)
	Geo.box(root, Vector3(mx, y + 0.05, z + face * 0.008), Vector3(l, 0.1, 0.016), m[2], false)


## The dado up a flight on the wall face at `x` (facing `face`), from (`z_top`, `y_top`) down toward `dir`: the band
## and its rail line run with the pitch, sheared boxes with plumb ends so they meet the landings' bands square (the
## band reaches down under the treads, so no paint shows between it and the steps).
static func _dado_slope(root: Node3D, x: float, face: float, z_top: float, y_top: float, dir: float) -> void:
	var m := _dado_mats()
	var p := _pitch(dir)
	var slope := Vector3(0, -float(p[1]), dir * float(p[0]))       # along the flight, top to bottom
	var mid := Vector3(x, y_top - float(p[1]) * 0.5, z_top + dir * float(p[0]) * 0.5)
	for part: Array in [[0.006, -0.2, 0.9, m[0], 0.003], [0.014, 0.897, 0.923, m[1], 0.007]]:
		var lo: float = part[1]
		var hi: float = part[2]
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		var mi := MeshInstance3D.new()
		mi.mesh = bm
		mi.material_override = part[3]
		root.add_child(mi)
		mi.transform = Transform3D(Basis(Vector3(float(part[0]), 0, 0), Vector3(0, hi - lo, 0), slope),
			mid + Vector3(face * float(part[4]), (lo + hi) * 0.5, 0))


## The floor's number painted big on the wall you face as you come up or down onto the landing at `yf` (the ZS wall,
## west of the doors; at 4F east of the corridor's opening): "4F" … "1F" in a dark stencil paint (user: "계단 공간에
## 창문 없애고 그냥 각 층에 층수만 표기해줘").
static func _floor_number(root: Node3D, yf: float, n: int) -> void:
	var l := Geo.label(root, "%dF" % n, Vector3(FLOOR_NO_X, yf + 1.62, ZS - 0.004), PI, 220, Color(0.13, 0.17, 0.16), 0.004,
		false, "print")
	Geo.fit(l, 1.25, 0.82)


## A wall of iron bars across the stairs at a landing's edge (z GATE_Z, x `x0`..`x1`, from the landing at `yf` up to
## `ytop`): a frame of square tube, round bars every BAR_STEP, a gate GATE_W wide in the middle hung on its left post
## with a chain and a padlock through it at the latch. Solid; [E] rattles the gate. Returns {root, leaf, use, block}
## (root = the leaf, for Terminal.rattle).
const GATE_Z := LAND_N + 0.12      # (clear of the handrails' ends)
const GATE_W := 0.95
const BAR_STEP := 0.11


static func _gate(root: Node3D, x0: float, x1: float, yf: float, ytop: float) -> Dictionary:
	var g := Node3D.new()
	g.name = "StairGate"
	root.add_child(g)
	g.position = Vector3(0, yf, GATE_Z)
	var h := ytop - yf
	var iron := Mats.std(Color(0.15, 0.16, 0.16), 0.45, 0.25)
	var cx := (x0 + x1) * 0.5
	var lx0 := cx - GATE_W * 0.5
	var lx1 := cx + GATE_W * 0.5
	var transom := 2.2
	# the frame: end posts, a foot rail, a top rail, a mid rail either side of the gate, its jambs and transom
	for x: float in [x0 + 0.025, x1 - 0.025]:
		Geo.box(g, Vector3(x, h * 0.5, 0), Vector3(0.05, h, 0.05), iron, false)
	Geo.box(g, Vector3(cx, 0.025, 0), Vector3(x1 - x0, 0.05, 0.05), iron, false)
	Geo.box(g, Vector3(cx, h - 0.025, 0), Vector3(x1 - x0, 0.05, 0.05), iron, false)
	Geo.box(g, Vector3(cx, transom, 0), Vector3(x1 - x0, 0.05, 0.05), iron, false)
	for side: Array in [[x0, lx0 - 0.05], [lx1 + 0.05, x1]]:
		Geo.box(g, Vector3((side[0] + side[1]) * 0.5, 1.05, 0), Vector3(side[1] - side[0], 0.04, 0.03), iron, false)
	for x: float in [lx0 - 0.025, lx1 + 0.025]:
		Geo.box(g, Vector3(x, transom * 0.5, 0), Vector3(0.05, transom, 0.05), iron, false)
	# the fixed bars (over the gate only above its transom)
	var bar := CylinderMesh.new()
	bar.top_radius = 0.009
	bar.bottom_radius = 0.009
	bar.height = 1.0
	bar.radial_segments = 8
	bar.rings = 1
	var fixed: Array = []
	var x := x0 + 0.08
	while x < x1 - 0.06:
		if x > lx0 - 0.07 and x < lx1 + 0.07:
			fixed.append(Transform3D(Basis().scaled(Vector3(1, h - transom, 1)), Vector3(x, (transom + h) * 0.5, 0)))
		else:
			fixed.append(Transform3D(Basis().scaled(Vector3(1, h, 1)), Vector3(x, h * 0.5, 0)))
		x += BAR_STEP
	OfficeKit._multi(g, bar, iron, fixed)
	# the gate: its own frame and bars, hung at its left jamb
	var leaf := Node3D.new()
	g.add_child(leaf)
	leaf.position = Vector3(lx0, 0, 0)
	var gh := transom - 0.06
	for sx: float in [0.02, GATE_W - 0.02]:
		Geo.box(leaf, Vector3(sx, 0.05 + gh * 0.5, 0), Vector3(0.04, gh, 0.04), iron, false)
	for y: float in [0.08, 1.05, gh + 0.02]:
		Geo.box(leaf, Vector3(GATE_W * 0.5, y, 0), Vector3(GATE_W - 0.04, 0.035, 0.03), iron, false)
	var inner: Array = []
	var n := int((GATE_W - 0.1) / BAR_STEP)
	for k in n + 1:
		var bx := 0.05 + (GATE_W - 0.1) * k / float(n)
		inner.append(Transform3D(Basis().scaled(Vector3(1, gh - 0.06, 1)), Vector3(bx, 0.08 + (gh - 0.06) * 0.5, 0)))
	OfficeKit._multi(leaf, bar, iron, inner)
	for hy: float in [0.3, 1.8]:
		Geo.cyl(leaf, Vector3(-0.01, hy, 0.0), 0.014, 0.1, iron)               # hinge knuckles
	# a chain round the latch stile and the jamb, a padlock hanging from it (on the landing's side)
	var steel := Mats.std(Color(0.42, 0.43, 0.43), 0.4, 0.5)
	var link := TorusMesh.new()
	link.inner_radius = 0.006
	link.outer_radius = 0.014
	link.rings = 8
	link.ring_segments = 6
	var lc := Vector3(GATE_W + 0.005, 1.0, 0.0)
	var links: Array = []
	for k in 10:
		var a := TAU * k / 10.0
		var p := lc + Vector3(cos(a) * 0.055, sin(a * 2.0) * 0.006, sin(a) * 0.045)
		var b := Basis(Vector3.UP, -a) * (Basis(Vector3.RIGHT, PI / 2) if k % 2 == 0 else Basis())
		links.append(Transform3D(b, p))
	for k in 3:
		links.append(Transform3D(Basis(Vector3.RIGHT, PI / 2) if k % 2 == 0 else Basis(), lc + Vector3(0.0, -0.025 - k * 0.022, 0.05)))
	OfficeKit._multi(leaf, link, steel, links)
	var lock := Node3D.new()
	leaf.add_child(lock)
	lock.position = lc + Vector3(0, -0.12, 0.05)
	Geo.box(lock, Vector3(0, -0.03, 0), Vector3(0.05, 0.055, 0.022), Mats.std(Color(0.55, 0.45, 0.2), 0.35, 0.6), false)
	var shackle := MeshInstance3D.new()
	var sm := TorusMesh.new()
	sm.inner_radius = 0.014
	sm.outer_radius = 0.02
	shackle.mesh = sm
	shackle.material_override = steel
	lock.add_child(shackle)
	shackle.rotation.x = PI / 2
	Geo.cyl(lock, Vector3(0, -0.035, 0.012), 0.005, 0.003, Mats.std(Color(0.1, 0.1, 0.1), 0.5)).rotation.x = PI / 2   # keyhole
	var block := Geo.blocker(g, Vector3(cx, h * 0.5, 0), Vector3(x1 - x0, h, 0.06))
	var use := Interactable.create(g, Vector3(cx, 1.05, 0.13), Vector3(GATE_W + 0.2, 2.0, 0.26), "문 열기", Callable())
	use.press_sound = ""
	var d := {"root": leaf, "leaf": leaf, "use": use, "block": block}
	use.callback = func(): Terminal.current.rattle(d)
	return d


static func _lamp(root: Node3D, zone: LightZone, at: Vector3, rot: float, lit: bool) -> void:
	var h := Node3D.new()
	root.add_child(h)
	h.position = at
	h.rotation.y = rot
	var base := Mats.std(Color(0.2, 0.22, 0.21), 0.5, 0.3)
	Geo.box(h, Vector3(0, 0, -0.03), Vector3(0.26, 0.16, 0.06), base, false)
	var glass := Geo.capsule(h, Vector3(0, 0, -0.05), 0.055, 0.22, zone.panel_mat if lit else Mats.std(Color(0.4, 0.42, 0.4), 0.3))
	glass.rotation.z = PI / 2
	for i in 3:
		Geo.box(h, Vector3(-0.07 + i * 0.07, 0, -0.1), Vector3(0.008, 0.13, 0.008), base, false)
	if lit:
		var l := Geo.omni(h, Vector3(0, -0.05, -0.25), LIGHT, 1.05, 7.5)
		l.light_volumetric_fog_energy = 0.5
		zone.add_light(l)


# --------------------------------------------------------------------------------------------
## A steel fire door (dressed like the corridors' doors, OfficeKit.door_face) in a doorway at `xf` (in `parent`'s
## space): the doorway centred on x 0, floor y 0, the leaf's middle in the z 0 plane; it swings to -Z (positive hinge
## angle). Casings `wall_t` apart on the two faces. `seal_side` (+1 / -1, 0 none): the leaf's skin, its dressing and
## the casing on that side go on Geo.VIS_SEALED (a lobby copy's inside). Returns {root, leaf (hinge), block, use, open}.
static func door(parent: Node3D, xf: Transform3D, wall_t: float, push_from_plus := true, seal_side := 0.0) -> Dictionary:
	var root := Node3D.new()
	parent.add_child(root)
	root.transform = xf
	# the corridors' door (OfficeKit.steel_door — the user's photo of a worn steel door): pale blue-grey scratched
	# paint, a wired-glass vision panel, a chrome push bar and a riveted kick plate on the push side, a closer, a worn
	# frame; no metalness in the paint (with nothing to reflect it would read black in the dark stairwell)
	var paint := OfficeKit.steel_door_paint()
	var casing := OfficeKit.steel_door_frame()
	var hw := DOOR_W * 0.5
	for side: float in [-1.0, 1.0]:
		var face: Array[MeshInstance3D] = []
		var z := side * (wall_t * 0.5 + 0.015)
		for sx in [-1.0, 1.0]:
			# (a thin line on the wall: 16 mm, was 80 — user: "문틀 두께가 너무 두꺼워, 5분의1 정도로")
			face.append(Geo.box(root, Vector3(sx * (hw + 0.008), DOOR_H * 0.5 + 0.008, z), Vector3(0.016, DOOR_H + 0.016, 0.03), casing, false))
		face.append(Geo.box(root, Vector3(0, DOOR_H + 0.008, z), Vector3(DOOR_W + 0.032, 0.016, 0.03), casing, false))
		if side == seal_side:
			for m in face:
				m.layers = Geo.VIS_SEALED
	var hinge := Node3D.new()
	root.add_child(hinge)
	hinge.position = Vector3(-hw, 0, 0)
	var lw := DOOR_W - 0.01
	var c := lw * 0.5 + 0.005
	for side: float in [-1.0, 1.0]:
		var skin := Geo.box(hinge, Vector3(c, DOOR_H * 0.5, side * 0.0125), Vector3(lw, DOOR_H - 0.01, 0.025), paint, false)
		var layer := Geo.VIS_SEALED if side == seal_side else 0
		if layer != 0:
			skin.layers = layer
		# the face's own frame: x along the leaf (from the hinge on +Z, from the latch on -Z), z out of it
		var fxf := Transform3D(Basis(), Vector3(0.005, 0, 0.025)) if side > 0.0 \
				else Transform3D(Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, -1)), Vector3(0.005 + lw, 0, -0.025))
		OfficeKit.door_face(hinge, fxf, lw, DOOR_H - 0.01, side > 0.0, (side > 0.0) == push_from_plus, layer)
	OfficeKit.seed_weathered(root, xf.origin * 0.37)       # (the lobby's two copies: the same xf in each, the same look)
	var block := Geo.blocker(root, Vector3(0, DOOR_H * 0.5, 0), Vector3(DOOR_W, DOOR_H, maxf(wall_t, 0.2)))
	var use := Interactable.create(root, Vector3(0, 1.05, 0), Vector3(DOOR_W, 2.0, wall_t + 0.5), "문 열기", Callable())
	use.press_sound = ""
	return {"root": root, "leaf": hinge, "block": block, "use": use, "open": false}


## One copy of the stair lobby at `frame` (in `parent`'s space): origin on the floor at the middle of door B's inside
## face, local +Z out through door B (to the lounge), the room at -Z with door A at its far end (to the stairs).
## `own_a` / `own_b`: build that door's wall (else the wall it stands in is someone else's: the stairwell's, the
## lounge's). Returns {root, doors {a, b}}.
static func lobby(parent: Node3D, frame: Transform3D, own_a: bool, own_b: bool, b_wall := 0.2) -> Dictionary:
	var root := Node3D.new()
	root.name = "StairLobby"
	parent.add_child(root)
	root.transform = frame
	var sealed := Node3D.new()
	root.add_child(sealed)
	var paint := Mats.std(Color(0.66, 0.68, 0.64), 0.85)
	var dado := Mats.std(Color(0.28, 0.42, 0.44), 0.55)
	var floor_m := Mats.std(Color(0.38, 0.38, 0.36), 0.8)
	var hw := LW * 0.5
	var mz := -LD * 0.5
	Geo.box(sealed, Vector3(0, -0.05, mz), Vector3(LW, 0.1, LD), floor_m)
	Geo.box(sealed, Vector3(0, LHT + 0.05, mz), Vector3(LW, 0.1, LD), paint, false)
	for sx in [-1.0, 1.0]:
		Geo.box(sealed, Vector3(sx * (hw + 0.1), LHT * 0.5, mz), Vector3(0.2, LHT, LD), paint)
		Geo.box(sealed, Vector3(sx * (hw - 0.003), 0.55, mz), Vector3(0.006, 1.1, LD), dado, false)
	# the two door walls' inside faces (whoever's wall stands there), lined; their own walls where asked
	var dw := DOOR_W * 0.5 + 0.02
	for e: Array in [[0.0, own_b, 1.0, b_wall], [-LD, own_a, -1.0, 0.2]]:
		var z: float = e[0]
		var dz: float = e[2]
		for sx in [-1.0, 1.0]:
			Geo.box(sealed, Vector3(sx * (dw + (hw - dw) * 0.5), LHT * 0.5, z - dz * 0.006), Vector3(hw - dw, LHT, 0.012), paint, false)
			Geo.box(sealed, Vector3(sx * (dw + (hw - dw) * 0.5), 0.55, z - dz * 0.013), Vector3(hw - dw, 1.1, 0.004), dado, false)
		Geo.box(sealed, Vector3(0, (DOOR_H + 0.06 + LHT) * 0.5, z - dz * 0.006), Vector3(dw * 2.0, LHT - DOOR_H - 0.06, 0.012), paint, false)
		if e[1]:
			for sx in [-1.0, 1.0]:
				Geo.box(root, Vector3(sx * (dw + (hw + 0.2 - dw) * 0.5), LHT * 0.5, z + dz * 0.1), Vector3(hw + 0.2 - dw, LHT, 0.2), paint)
			Geo.box(root, Vector3(0, (DOOR_H + 0.06 + LHT) * 0.5, z + dz * 0.1), Vector3(dw * 2.0, LHT - DOOR_H - 0.06, 0.2), paint)
			# nothing past a door that leads nowhere
			Geo.box(root, Vector3(0, 1.2, z + dz * 0.8), Vector3(1.6, 2.6, 1.0), Mats.get_mat("void"), false)
		# a sill through the wall (2 mm low: where it runs on under the next floor it must not fight it)
		var wt: float = e[3]
		Geo.box(root, Vector3(0, -0.022, z + dz * wt * 0.5), Vector3(DOOR_W, 0.04, wt), Mats.std(Color(0.3, 0.3, 0.3), 0.6))
	# a lamp, a fire extinguisher, no haze, its own small room's sound (no signs over its doors)
	var lamp_m := Mats.emissive(LIGHT, 1.4, Color(0.85, 0.88, 0.86))
	Geo.box(sealed, Vector3(0, LHT - 0.03, mz), Vector3(0.6, 0.05, 0.16), lamp_m, false)
	Geo.box(sealed, Vector3(0, LHT - 0.01, mz), Vector3(0.66, 0.02, 0.22), Mats.std(Color(0.3, 0.32, 0.31), 0.5), false)
	var l := Geo.omni(sealed, Vector3(0, LHT - 0.45, mz), LIGHT, 0.95, 4.5)
	l.light_volumetric_fog_energy = 0.0
	var f := Geo.omni(sealed, Vector3(0, 0.7, mz), LIGHT, 0.2, 2.5)
	f.light_volumetric_fog_energy = 0.0
	f.light_specular = 0.0
	var ext := Node3D.new()
	sealed.add_child(ext)
	ext.position = Vector3(hw - 0.18, 0.0, -LD + 0.25)
	Geo.cyl(ext, Vector3(0, 0.3, 0), 0.08, 0.5, Mats.std(Color(0.7, 0.08, 0.06), 0.4))
	Geo.cyl(ext, Vector3(0, 0.6, 0), 0.025, 0.1, Mats.get_mat("metal_dark"))
	var clear := FogVolume.new()
	clear.size = Vector3(LW, LHT, LD)
	var fm := FogMaterial.new()
	fm.density = -1.0
	clear.material = fm
	sealed.add_child(clear)
	clear.position = Vector3(0, LHT * 0.5, mz)
	Lift._reverb(sealed, Vector3(0, LHT * 0.5, mz), Vector3(LW, LHT, LD), "RevTight", 0.25)
	Geo.seal(sealed)
	# the doors: B in the near wall, pushed from outside (+Z) into the room; A in the far wall, pushed from inside
	# toward the stairs. Their inside skins sealed.
	var b := door(root, Transform3D(Basis(), Vector3(0, 0, 0.0325)), 0.06, true, -1.0)
	var a := door(root, Transform3D(Basis(), Vector3(0, 0, -LD - 0.0325)), 0.06, true, 1.0)
	return {"root": root, "doors": {"a": a, "b": b}}


# --------------------------------------------------------------------------------------------
## Joins the stairs' copy of the lobby (`a`, from build()) and the lounge's (`b`), and the 4F door.
static func link(parent: Node, stairs: Dictionary, lounge: Dictionary, top: Dictionary) -> StairCore:
	var s := StairCore.new()
	s.name = "StairLobby"
	parent.add_child(s)
	s.twins = [stairs, lounge]
	s.top_door = top
	for i in 2:
		for key: String in ["a", "b"]:
			var k := key
			var ii := i
			var d: Dictionary = s.twins[i].doors[key]
			(d.use as Interactable).callback = func(): s._press(ii, k)
	if not top.is_empty():                       # (none since the stairs opened onto the corridor)
		(top.use as Interactable).callback = func(): s._toggle(top)
	return s


func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


func _local(i: int) -> Vector3:
	var p := _player()
	if p == null:
		return Vector3.INF
	return (twins[i].root as Node3D).global_transform.affine_inverse() * p.global_position


func is_inside(i: int) -> bool:
	var q := _local(i)
	return absf(q.x) < LW * 0.5 and q.z < -0.05 and q.z > -LD + 0.05 and q.y > -0.5 and q.y < LHT


func _press(i: int, key: String) -> void:
	if _moving:
		return
	var d: Dictionary = twins[i].doors[key]
	if key == REAL[i]:
		_toggle(d)
		return
	# the door that leads nowhere from here: shut the real one, carry the player over, open this one there
	var real: Dictionary = twins[i].doors[REAL[i]]
	var p := _player()
	if p == null or not is_inside(i):
		return
	if real.open and _in_swing(real):
		Terminal.current.rattle(d)
		return
	_moving = true
	if real.open and not await _swing(real, false, 0.3):
		_moving = false
		return
	var j := 1 - i
	Lift.carry(p, (twins[i].root as Node3D).global_transform, (twins[j].root as Node3D).global_transform)
	_inside = j
	carried.emit(j)
	await _swing(twins[j].doors[key], true, 0.55)
	_moving = false


func _toggle(d: Dictionary) -> void:
	if d.open:
		if not _in_swing(d):
			_swing(d, false, 0.55)
	else:
		_swing(d, true, 0.55)


## Standing where door `d`'s leaf sweeps (a quarter circle round its hinge on the side it opens to) or in its doorway:
## it will not shut on you.
func _in_swing(d: Dictionary) -> bool:
	var p := _player()
	if p == null:
		return false
	var q := (d.root as Node3D).global_transform.affine_inverse() * p.global_position
	if q.y < -0.5 or q.y > 2.5:
		return false
	if absf(q.x) < DOOR_W * 0.5 + 0.3 and absf(q.z) < 0.45:
		return true
	return q.z < 0.0 and Vector2(q.x + DOOR_W * 0.5, q.z).length() < DOOR_W + 0.35


## Swings door `d` open or shut over `time` s. Shutting, it stops and swings back open if you step into it: returns
## whether it got where it was going.
func _swing(d: Dictionary, open: bool, time: float) -> bool:
	d.open = open
	_clear_t.erase(d.leaf)
	var leaf: Node3D = d.leaf
	var pos := (d.root as Node3D).global_transform * Vector3(0, 1.0, 0)
	if leaf.has_meta("tw"):
		var old: Tween = leaf.get_meta("tw")
		if old and old.is_valid():
			old.kill()
	if open:
		(d.block as StaticBody3D).collision_layer = 0
		Snd.play_at("door_heavy", pos, -10.0, 1.08, 5.0)
	var tw := leaf.create_tween()
	leaf.set_meta("tw", tw)
	tw.tween_property(leaf, "rotation:y", deg_to_rad(88.0) if open else 0.0, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	if open:
		await tw.finished
		return true
	while tw.is_valid() and tw.is_running():
		if _in_swing(d):
			_swing(d, true, 0.35)
			return false
		await get_tree().physics_frame
	(d.block as StaticBody3D).collision_layer = Geo.LAYER_WORLD
	Snd.play_at("door_slam", pos, -12.0, 1.15, 5.0)
	return true


func _physics_process(delta: float) -> void:
	# fire doors shut by themselves once you are clear of them
	var doors: Array = [top_door, twins[0].doors.a, twins[1].doors.b]
	for d: Dictionary in doors:
		if d.is_empty() or not d.open or _moving:
			continue
		if _in_swing(d):
			_clear_t[d.leaf] = 0.0
			continue
		_clear_t[d.leaf] = float(_clear_t.get(d.leaf, 0.0)) + delta
		if _clear_t[d.leaf] > 2.2:
			_swing(d, false, 0.9)
	# in the lobby the player is in neither floor's zone
	var now := -1
	for i in 2:
		if is_inside(i):
			now = i
	if now != _inside:
		var p := _player()
		if p:
			if now >= 0:
				p.zone_override = "stairs"
			elif p.zone_override == "stairs":
				p.zone_override = "servicehall" if _inside == 0 else ""
		_inside = now
