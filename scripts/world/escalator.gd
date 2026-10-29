class_name Escalator
## Stopped escalator up to a mezzanine, built in code like a real unit: one continuous side profile (bottom landing →
## fillet → 30° incline → fillet → top landing) along which the truss body, glass balustrades and black handrails are
## swept, grooved aluminium steps (MultiMesh) that flatten out at the landings, floor and comb plates at both ends.
## It rises toward +X; `foot` is the lower working point (where the incline line meets the floor), so the top
## landing begins where the incline line, rounded, reaches `top_y`. Stopped, but walkable (a ramp under the steps,
## the balustrades closing its sides); the out-of-service belt at its foot is down and the sign stand pushed aside.

const ANGLE := 30.0
const FILLET := 2.0          # transition radius at both ends (m), so the offset handrail and truss stay smooth
const LAND_BOTTOM := 1.6     # flat run beyond the fillets (m)
const LAND_TOP := 1.4
const LIFT := 0.012          # step/landing line above the floors, so treads never share a plane with them
const PITCH := 0.4           # step chain pitch along the path
const PLATE := 0.95          # floor plate length at each end, the comb at its inner edge
const HALF_STEP := 0.5       # step half width
const SKIRT := 0.53          # skirt panel (inside face) half width
const OUTER := 0.82          # outer cladding half width
const DECK := 0.3            # deck height above the step line
const CHANNEL := -0.35       # step channel floor below the step line (under the treads' back edges on the incline)
const TRUSS := -1.0          # truss underside below the step line
const GLASS_Z := 0.61        # balustrade glass and handrail centre (half width)
const RAIL_N := 1.0          # handrail centre above the step line
const NEWEL := 0.3           # handrail turnaround radius

var _st: Array = []          # [s, Vector2 point, Vector2 tangent]
static var _groove: ImageTexture


static func build(parent: Node3D, foot: Vector3, top_y: float) -> void:
	var e := Escalator.new()
	e._make(parent, foot, top_y)


func _make(parent: Node3D, foot: Vector3, top_y: float) -> void:
	var zc := foot.z
	var foot_x := foot.x
	var root := Node3D.new()
	root.name = "Escalator"
	parent.add_child(root)
	root.position = Vector3(0, 0, zc)
	_path(foot_x, top_y)
	var s_end: float = _st[_st.size() - 1][0]
	var steel := CarouselMesh.mat("steel")
	var deck := CarouselMesh.mat("steel_top")
	var dark := CarouselMesh.mat("kick")
	# truss body: outer cladding, deck, skirts, channel floor and underside, ending under the handrail newels and
	# capped there; cladding panel joints every 1.2 m
	var s_h0 := LAND_BOTTOM - 1.1
	var s_h1 := s_end - (LAND_TOP - 0.95)
	var b0 := s_h0 - NEWEL - 0.02
	var b1 := s_h1 + NEWEL + 0.02
	var body := [Vector2(TRUSS, -OUTER), Vector2(DECK, -OUTER), Vector2(DECK, -SKIRT), Vector2(CHANNEL, -SKIRT),
		Vector2(CHANNEL, SKIRT), Vector2(DECK, SKIRT), Vector2(DECK, OUTER), Vector2(TRUSS, OUTER)]
	_add(root, _sweep(body, [steel, deck, steel, dark, steel, deck, steel, steel], b0, b1, true))
	var seam := CarouselMesh.mat("seam")
	var sj := b0 + 1.2
	while sj < b1 - 0.6:
		for side in [-1.0, 1.0]:
			var zz: float = side * (OUTER + 0.0015)
			var ribbon := [Vector2(TRUSS, zz), Vector2(DECK - 0.002, zz)] if side < 0.0 else [Vector2(DECK - 0.002, zz), Vector2(TRUSS, zz)]
			_add(root, _sweep(ribbon, [seam], sj, sj + 0.006, false))
		sj += 1.2
	# balustrades: glass between deck and handrail, a stainless clamp strip on the deck
	var glass := Mats.get_mat("glass")
	for side in [-1.0, 1.0]:
		var gz: float = side * GLASS_Z
		_add(root, _sweep([Vector2(DECK + 0.002, gz), Vector2(RAIL_N - 0.03, gz)], [glass], s_h0, s_h1, false))
		var clamp := [Vector2(DECK, gz - 0.025), Vector2(DECK + 0.05, gz - 0.025), Vector2(DECK + 0.05, gz + 0.025), Vector2(DECK, gz + 0.025)]
		_add(root, _sweep(clamp, [steel, steel, steel, steel], s_h0, s_h1, true))
		_add(root, _newel_glass(gz, s_h0, -1.0, glass))
		_add(root, _newel_glass(gz, s_h1, 1.0, glass))
		_add(root, _handrail(gz, s_h0, s_h1))
		# handrail inlets: where the rail dives back into the balustrade at the bottom of each newel
		for k in 2:
			var A: Array = _at(s_h0 if k == 0 else s_h1)
			var pp: Vector2 = A[1]
			var tt: Vector2 = A[2]
			var nn := Vector2(-tt.y, tt.x)
			var c := pp + nn * ((RAIL_N - 2.0 * NEWEL + DECK) * 0.5) + tt * (0.07 if k == 0 else -0.07)
			Geo.box(root, Vector3(c.x, c.y, gz), Vector3(0.18, RAIL_N - 2.0 * NEWEL - DECK + 0.05, 0.12), steel, false)
	# steps between the combs, floor plates and combs at both ends
	_steps(root, PLATE + 0.05, s_end - PLATE - 0.05)
	for end in [[0.0, PLATE], [s_end - PLATE, s_end]]:
		var a: Array = _at(end[0])
		var b: Array = _at(end[1])
		var y: float = (a[1] as Vector2).y
		var x0: float = (a[1] as Vector2).x
		var x1: float = (b[1] as Vector2).x
		# the landing plate runs the full width, a hair proud of the cladding, beyond the balustrade ends
		Geo.box(root, Vector3((x0 + x1) * 0.5, y - 0.009, 0), Vector3(x1 - x0, 0.03, OUTER * 2.0 + 0.02), deck, false)
		var comb_x: float = x1 + 0.03 if end[0] == 0.0 else x0 - 0.03
		Geo.box(root, Vector3(comb_x, y - 0.004, 0), Vector3(0.06, 0.02, HALF_STEP * 2.0), Mats.get_mat("yellow_paint"), false)
	# stopped, but you can walk it: a ramp under the steps between the landings, the balustrades closing its sides,
	# the top landing out to the mezzanine's edge
	var a := deg_to_rad(ANGLE)
	var low := Vector2(foot_x, LIFT)
	var top := Vector2(foot_x + top_y / tan(a), top_y + LIFT)
	var mid := (low + top) * 0.5
	var run := low.distance_to(top)
	var ramp := Geo.blocker(parent, Vector3(mid.x + sin(a) * 0.15, mid.y - cos(a) * 0.15, zc), Vector3(run, 0.3, SKIRT * 2.0))
	ramp.rotation.z = a
	for side in [-1.0, 1.0]:
		var wall := Geo.blocker(parent, Vector3(mid.x - sin(a) * 0.9, mid.y + cos(a) * 0.9, zc + side * (GLASS_Z + 0.05)), Vector3(run + 2.4, 1.8, 0.1))
		wall.rotation.z = a
	var x_top: float = (_at(s_end)[1] as Vector2).x
	Geo.blocker(parent, Vector3((top.x + x_top) * 0.5, top.y - 0.15, zc), Vector3(x_top - top.x + 0.2, 0.3, SKIRT * 2.0))
	# out of service — but the belt across the foot is down: one post still standing, the other knocked over with the
	# belt slack on the floor, the sign stand pushed aside
	var post_a := Vector3(foot_x - 3.0, 0, zc - 1.0)
	LevelKit.stanchions(parent, [post_a])
	var fallen := Node3D.new()
	parent.add_child(fallen)
	fallen.position = Vector3(foot_x - 3.4, 0.05, zc + 0.9)
	fallen.rotation = Vector3(0, 0.6, PI / 2)
	if TripoProps.exists("security", "SEC_Stanchion"):
		TripoProps.spawn(fallen, "security", "SEC_Stanchion", Vector3(0, -0.05, 0))
	else:
		Geo.cyl(fallen, Vector3(0, 0.5, 0), 0.035, 1.0, Mats.get_mat("metal"))
	var belt := Mats.std(Color(0.08, 0.14, 0.38), 0.6)
	var hook := post_a + Vector3(0, 0.9, 0)
	var slack := Vector3(foot_x - 3.15, 0.012, zc + 0.1)
	var droop := Geo.box(parent, (hook + slack) * 0.5, Vector3(0.012, 0.05, hook.distance_to(slack)), belt, false)
	droop.look_at_from_position(droop.position, slack, Vector3.UP)
	Geo.box(parent, Vector3(foot_x - 3.3, 0.012, zc + 0.5), Vector3(0.05, 0.006, 0.8), belt, false, 0.5)
	var stand := Node3D.new()
	parent.add_child(stand)
	stand.position = Vector3(foot_x - 3.7, 0, zc - 1.9)
	stand.rotation.y = 0.5
	var plate := LevelKit.sign_body(stand, Vector3(0, 1.25, 0), -90.0, Vector2(0.9, 0.6))
	LevelKit.decal(plate, "sign_escalator_oos", Vector3(0, 0, plate.get_meta("face_z") + 0.003), 0.0, Vector2(0.87, 0.58))
	Geo.box(stand, Vector3(0, 0.5, 0), Vector3(0.05, 1.0, 0.05), Mats.get_mat("steel_frame"), false)


## The step line in the side plane (x, y): flat, fillet, incline, fillet, flat, sampled densely with arc length.
func _path(foot_x: float, top_y: float) -> void:
	var a := deg_to_rad(ANGLE)
	var tan_len := FILLET * tan(a * 0.5)
	var wp_top := Vector2(foot_x + top_y / tan(a), top_y + LIFT)
	var p0 := Vector2(foot_x - tan_len - LAND_BOTTOM, LIFT)
	var c1 := Vector2(foot_x - tan_len, LIFT + FILLET)                  # bottom fillet centre (above)
	var c2 := Vector2(wp_top.x + tan_len, top_y + LIFT - FILLET)        # top fillet centre (below)
	var pts: Array = []        # [point, tangent]
	pts.append([p0, Vector2.RIGHT])
	pts.append([Vector2(foot_x - tan_len, LIFT), Vector2.RIGHT])
	var n := 24
	for i in range(1, n + 1):
		var th := a * i / n
		pts.append([c1 + Vector2(sin(th), -cos(th)) * FILLET, Vector2(cos(th), sin(th))])
	var inc_start: Vector2 = pts[pts.size() - 1][0]
	var inc_end := c2 + Vector2(-sin(a), cos(a)) * FILLET
	for i in range(1, 9):
		pts.append([inc_start.lerp(inc_end, float(i) / 8.0), Vector2(cos(a), sin(a))])
	for i in range(1, n + 1):
		var th := a * (1.0 - float(i) / n)
		pts.append([c2 + Vector2(-sin(th), cos(th)) * FILLET, Vector2(cos(th), sin(th))])
	var top0: Vector2 = pts[pts.size() - 1][0]
	for i in range(1, 5):
		pts.append([top0 + Vector2(LAND_TOP * i / 4.0, 0), Vector2.RIGHT])
	var s := 0.0
	_st.clear()
	for i in pts.size():
		if i > 0:
			s += (pts[i][0] as Vector2).distance_to(pts[i - 1][0])
			if (pts[i][0] as Vector2).distance_to(pts[i - 1][0]) < 1e-5:
				continue
		_st.append([s, pts[i][0], (pts[i][1] as Vector2).normalized()])


## Point and tangent at arc length `s` (clamped).
func _at(s: float) -> Array:
	if s <= _st[0][0]:
		return _st[0]
	for i in range(1, _st.size()):
		if s <= _st[i][0]:
			var k: float = (s - _st[i - 1][0]) / maxf(1e-6, _st[i][0] - _st[i - 1][0])
			return [s, (_st[i - 1][1] as Vector2).lerp(_st[i][1], k), (_st[i - 1][2] as Vector2).slerp(_st[i][2], k).normalized()]
	return _st[_st.size() - 1]


## Stations from s0 to s1: the path's own points in between plus both ends.
func _range(s0: float, s1: float) -> Array:
	var out: Array = [_at(s0)]
	for st in _st:
		if st[0] > s0 + 1e-4 and st[0] < s1 - 1e-4:
			out.append(st)
	out.append(_at(s1))
	return out


## Sweeps a cross-section along the path from s0 to s1. `prof` = points (n = along the path normal, z = across),
## counter-clockwise for a closed solid; `mats` = material per edge. Closed solids get end caps.
func _sweep(prof: Array, mats: Array, s0: float, s1: float, closed: bool) -> Array:
	var frames: Array = []
	for st in _range(s0, s1):
		var p: Vector2 = st[1]
		var t: Vector2 = st[2]
		frames.append([st[0], Vector3(p.x, p.y, 0), Vector3(-t.y, t.x, 0), Vector3(0, 0, 1), Vector3(t.x, t.y, 0)])
	return _sweep_frames(frames, prof, mats, closed, false)


## Generic sweep along frames [u, origin, axis_n, axis_z, tangent]: one SurfaceTool per material.
func _sweep_frames(frames: Array, prof: Array, mats: Array, closed: bool, smooth: bool) -> Array:
	var tools := {}
	var edges := prof.size() if closed else prof.size() - 1
	var vnorm: Array = []
	if smooth:
		for i in prof.size():
			var a: Vector2 = prof[(i - 1 + prof.size()) % prof.size()]
			var b: Vector2 = prof[i]
			var c: Vector2 = prof[(i + 1) % prof.size()]
			var n1 := Vector2((b - a).y, -(b - a).x).normalized()
			var n2 := Vector2((c - b).y, -(c - b).x).normalized()
			vnorm.append((n1 + n2).normalized())
	var perim := 0.0
	for e in edges:
		var i: int = e
		var j: int = (e + 1) % prof.size()
		var pa: Vector2 = prof[i]
		var pb: Vector2 = prof[j]
		var en := Vector2((pb - pa).y, -(pb - pa).x).normalized()     # open profiles face by their point order too
		var m: Material = mats[mini(e, mats.size() - 1)]
		if not tools.has(m):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[m] = st
		var st2: SurfaceTool = tools[m]
		var el := pa.distance_to(pb)
		for f in range(frames.size() - 1):
			var A: Array = frames[f]
			var B: Array = frames[f + 1]
			var q := [_pt(A, pa), _pt(B, pa), _pt(B, pb), _pt(A, pb)]
			var na: Vector3 = _nrm(A, vnorm[i] if smooth else en)
			var nb: Vector3 = _nrm(B, vnorm[i] if smooth else en)
			var nc: Vector3 = _nrm(B, vnorm[j] if smooth else en)
			var nd: Vector3 = _nrm(A, vnorm[j] if smooth else en)
			var uv := [Vector2(A[0], perim), Vector2(B[0], perim), Vector2(B[0], perim + el), Vector2(A[0], perim + el)]
			_tri(st2, q, [na, nb, nc, nd], uv, [0, 1, 2])
			_tri(st2, q, [na, nb, nc, nd], uv, [0, 2, 3])
		perim += el
	var meshes: Array = []
	if closed:
		# end caps: the section triangulated, facing back along the path at the start and forward at the end
		var tri := Geometry2D.triangulate_polygon(PackedVector2Array(prof))
		for k in 2:
			var F: Array = frames[0] if k == 0 else frames[frames.size() - 1]
			var nn: Vector3 = -(F[4] as Vector3) if k == 0 else F[4]
			var m: Material = mats[0]
			var st3: SurfaceTool = tools[m]
			for i in range(0, tri.size(), 3):
				var q := [_pt(F, prof[tri[i]]), _pt(F, prof[tri[i + 1]]), _pt(F, prof[tri[i + 2]])]
				var uv := [prof[tri[i]], prof[tri[i + 1]], prof[tri[i + 2]]]
				_tri(st3, q, [nn, nn, nn], uv, [0, 1, 2])
	for m: Material in tools:
		var stf: SurfaceTool = tools[m]
		stf.generate_tangents()
		meshes.append([stf.commit(), m])
	return meshes


func _pt(F: Array, p: Vector2) -> Vector3:
	return (F[1] as Vector3) + (F[2] as Vector3) * p.x + (F[3] as Vector3) * p.y


func _nrm(F: Array, n: Vector2) -> Vector3:
	return ((F[2] as Vector3) * n.x + (F[3] as Vector3) * n.y).normalized()


## One triangle of quad `q` (indices `ix`), wound so its front faces along the vertex normals (Godot: clockwise).
func _tri(st: SurfaceTool, q: Array, nrm: Array, uv: Array, ix: Array) -> void:
	var a: Vector3 = q[ix[0]]
	var b: Vector3 = q[ix[1]]
	var c: Vector3 = q[ix[2]]
	var fn: Vector3 = (nrm[ix[0]] as Vector3) + (nrm[ix[1]] as Vector3) + (nrm[ix[2]] as Vector3)
	var order := ix
	if (b - a).cross(c - a).dot(fn) > 0.0:
		order = [ix[0], ix[2], ix[1]]
	for k: int in order:
		st.set_normal(nrm[k])
		st.set_uv(uv[k])
		st.add_vertex(q[k])


func _add(root: Node3D, meshes: Array) -> void:
	for mm in meshes:
		var mi := MeshInstance3D.new()
		mi.mesh = mm[0]
		mi.material_override = mm[1]
		root.add_child(mi)


## Rubber handrail: up from the deck round the newel at the bottom, along the balustrade, round the top newel.
func _handrail(gz: float, s0: float, s1: float) -> Array:
	var frames: Array = []
	var z := Vector3(0, 0, 1)
	var a0: Array = _at(s0)
	var a1: Array = _at(s1)
	for k in 2:
		var A: Array = a0 if k == 0 else a1
		var p: Vector2 = A[1]
		var t: Vector2 = A[2]
		var n := Vector2(-t.y, t.x)
		var c := p + n * (RAIL_N - NEWEL)
		var arc: Array = []
		for i in 13:
			# bottom of the newel → outward → top (start); top → outward → bottom (end)
			var th: float = lerpf(-PI * 0.5, -PI * 1.5, i / 12.0) if k == 0 else lerpf(PI * 0.5, -PI * 0.5, i / 12.0)
			var r := t * cos(th) + n * sin(th)
			var tang := -(t * -sin(th) + n * cos(th))      # both arcs run with th decreasing
			arc.append([0.0, Vector3(c.x + r.x * NEWEL, c.y + r.y * NEWEL, gz), Vector3(r.x, r.y, 0), z, Vector3(tang.x, tang.y, 0)])
		if k == 0:
			frames.append_array(arc)
			for st in _range(s0, s1).slice(1, -1):
				var pp: Vector2 = st[1]
				var tt: Vector2 = st[2]
				var nn := Vector2(-tt.y, tt.x)
				frames.append([0.0, Vector3(pp.x + nn.x * RAIL_N, pp.y + nn.y * RAIL_N, gz), Vector3(nn.x, nn.y, 0), z, Vector3(tt.x, tt.y, 0)])
		else:
			frames.append_array(arc)
	var u := 0.0
	for i in frames.size():
		if i > 0:
			u += (frames[i][1] as Vector3).distance_to(frames[i - 1][1])
		frames[i][0] = u
	# rounded handrail section, 85 x 55 mm
	var prof: Array = []
	for i in 16:
		var th := TAU * i / 16.0
		var v := Vector2(cos(th), sin(th))
		var sq := Vector2(signf(v.x) * pow(absf(v.x), 0.6), signf(v.y) * pow(absf(v.y), 0.6))
		prof.append(Vector2(sq.x * 0.0275, sq.y * 0.0425))
	var rail := Mats.std(Color(0.045, 0.045, 0.05), 0.42)
	var meshes := _sweep_frames(frames, prof, [rail], true, true)
	return meshes


## Glass half-disc under the handrail turnaround at one end (`dir` -1 = start, +1 = end).
func _newel_glass(gz: float, s: float, dir: float, glass: Material) -> Array:
	var A: Array = _at(s)
	var p: Vector2 = A[1]
	var t: Vector2 = A[2]
	var n := Vector2(-t.y, t.x)
	var c := p + n * (RAIL_N - NEWEL)
	var r := NEWEL - 0.035
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cv := Vector3(c.x, c.y, gz)
	for i in 12:
		var th0 := -PI * 0.5 + PI * i / 12.0
		var th1 := -PI * 0.5 + PI * (i + 1) / 12.0
		var d0 := t * cos(th0) * dir + n * sin(th0)
		var d1 := t * cos(th1) * dir + n * sin(th1)
		var q := [cv, Vector3(c.x + d0.x * r, c.y + d0.y * r, gz), Vector3(c.x + d1.x * r, c.y + d1.y * r, gz)]
		var zn := Vector3(0, 0, 1)
		_tri(st, q, [zn, zn, zn], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], [0, 1, 2])
	return [[st.commit(), glass]]


## Steps from s0 to s1: a grooved aluminium tread at every chain pitch with yellow side and nose lines, and a riser
## under each nose as tall as the climb from the step below (none on the flat landings).
func _steps(root: Node3D, s0: float, s1: float) -> void:
	var noses: Array[Vector2] = []
	var s := s0
	while s <= s1 + 1e-4:
		noses.append(_at(s)[1])
		s += PITCH
	var groove := _groove_tex()
	var tread_mat := StandardMaterial3D.new()
	tread_mat.albedo_texture = groove
	tread_mat.vertex_color_use_as_albedo = true
	tread_mat.metallic = 0.55
	tread_mat.roughness = 0.42
	tread_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var treads := MultiMesh.new()
	treads.transform_format = MultiMesh.TRANSFORM_3D
	treads.mesh = _tread_mesh()
	treads.instance_count = noses.size()
	var risers := MultiMesh.new()
	risers.transform_format = MultiMesh.TRANSFORM_3D
	risers.mesh = _riser_mesh()
	var rise_list: Array = []
	for i in noses.size():
		var depth := (noses[i + 1].x - noses[i].x) if i + 1 < noses.size() else PITCH
		treads.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(depth, 1, 1)), Vector3(noses[i].x, noses[i].y, 0)))
		if i > 0 and noses[i].y - noses[i - 1].y > 0.004:
			rise_list.append([noses[i], noses[i].y - noses[i - 1].y])
	risers.instance_count = rise_list.size()
	for i in rise_list.size():
		var nose: Vector2 = rise_list[i][0]
		risers.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1, rise_list[i][1], 1)), Vector3(nose.x, nose.y, 0)))
	for mm in [treads, risers]:
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = tread_mat
		root.add_child(mi)


## Unit tread: top at y 0 from x 0 (nose) to x 1 (scaled to the step depth), 1 m wide, 30 mm thick; vertex colours
## paint the yellow demarcation along both sides and the nose.
func _tread_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var alu := Color(0.66, 0.67, 0.68)
	var yel := Color(0.95, 0.72, 0.08)
	var w := HALF_STEP
	var side := 0.045
	var nose := 0.11            # of the unit depth (≈ 40 mm on a 0.35-0.4 m tread)
	# top face in strips: [x0, x1, z0, z1, colour]
	var strips := [[0.0, nose, -w, w, yel], [nose, 1.0, -w, -w + side, yel], [nose, 1.0, w - side, w, yel],
		[nose, 1.0, -w + side, w - side, alu]]
	for r in strips:
		var q := [Vector3(r[0], 0, r[2]), Vector3(r[1], 0, r[2]), Vector3(r[1], 0, r[3]), Vector3(r[0], 0, r[3])]
		var uv := [Vector2(r[2] * 118.0, 0), Vector2(r[2] * 118.0, 1), Vector2(r[3] * 118.0, 1), Vector2(r[3] * 118.0, 0)]
		_quad_col(st, q, Vector3.UP, uv, r[4])
	# nose edge (facing -X, down to the tread's underside)
	_quad_col(st, [Vector3(0, 0, -w), Vector3(0, -0.03, -w), Vector3(0, -0.03, w), Vector3(0, 0, w)], Vector3.LEFT,
		[Vector2(-w * 118.0, 0), Vector2(-w * 118.0, 1), Vector2(w * 118.0, 1), Vector2(w * 118.0, 0)], yel)
	st.generate_tangents()
	return st.commit()


## Unit riser: a cleated plate facing -X at x 0, from y -1 (scaled to the climb) up to the nose.
func _riser_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := HALF_STEP
	_quad_col(st, [Vector3(0, -1, -w), Vector3(0, 0, -w), Vector3(0, 0, w), Vector3(0, -1, w)], Vector3.LEFT,
		[Vector2(-w * 118.0, 1), Vector2(-w * 118.0, 0), Vector2(w * 118.0, 0), Vector2(w * 118.0, 1)], Color(0.5, 0.51, 0.52))
	st.generate_tangents()
	return st.commit()


func _quad_col(st: SurfaceTool, q: Array, n: Vector3, uv: Array, col: Color) -> void:
	var order := [0, 1, 2, 0, 2, 3]
	if ((q[1] - q[0]) as Vector3).cross(q[2] - q[0]).dot(n) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for k in order:
		st.set_normal(n)
		st.set_uv(uv[k])
		st.set_color(col)
		st.add_vertex(q[k])


## Cleat grooves across a step: a light rib and a dark groove per texture repeat (u runs across the step).
static func _groove_tex() -> ImageTexture:
	if _groove:
		return _groove
	var img := Image.create(8, 2, false, Image.FORMAT_RGB8)
	for x in 8:
		var v := 1.0 if x < 5 else 0.45
		for y in 2:
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	_groove = ImageTexture.create_from_image(img)
	return _groove
