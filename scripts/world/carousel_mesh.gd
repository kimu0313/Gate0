class_name CarouselMesh
extends RefCounted
## Brushed-stainless kit (materials, rounded prisms) and the flat-plate baggage carousel, modelled the way the
## real ones are built: a racetrack loop of overlapping
## crescent rubber plates riding between a brushed stainless guard rim (rounded, just above the plates) and the
## centre island's stainless wall; the outer side is a stainless skirt with panel joints, a black rubber bumper
## near the floor and a recessed toe kick. Geometry is swept along the loop so the brushing follows it.
##
## Loop in local space: straights along X from -half to half at z = ±radius (the plate band's centre line),
## semicircle ends around (±half, 0). PLATE_Y is the plates' top; the island top sits at ISLAND_Y.

const PLATE_Y := 0.44
const ISLAND_Y := 0.62
const BAND := 0.46            # half width of the plate band
const PLATE_LEN := 0.36       # plate pitch along the loop (the leading edge overlaps the next plate)

static var _mats := {}
static var _plate: ArrayMesh


static func mat(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var m := StandardMaterial3D.new()
	match kind:
		"steel":          # brushed stainless: streaks along the sweep (U), anisotropic highlight
			m.albedo_color = Color(0.78, 0.79, 0.8)
			m.metallic = 0.75          # satin: a diffuse share keeps it light grey where the room is dark
			m.roughness = 0.3
			m.normal_enabled = true
			m.normal_texture = _brushed_normal()
			m.normal_scale = 0.18
			m.uv1_scale = Vector3(2.0, 20.0, 1.0)      # fine hairlines along U (the sweep), ~2 per mm across
			m.anisotropy_enabled = true
			m.anisotropy = 0.5
		"steel_top":      # island top: same steel, a little duller from foot traffic of bags
			m.albedo_color = Color(0.7, 0.71, 0.72)
			m.metallic = 0.7
			m.roughness = 0.38
			m.normal_enabled = true
			m.normal_texture = _brushed_normal()
			m.normal_scale = 0.15
			m.uv1_scale = Vector3(1.0, 20.0, 1.0)
		"rubber":         # plates: clean dark grey rubber, a soft sheen so the overlapping edges catch the light
			m.albedo_color = Color(0.25, 0.255, 0.26)
			m.roughness = 0.5
			m.vertex_color_use_as_albedo = true      # plate shading (contact shadow behind each leading edge)
		"panel":          # control panel faces: dark grey powder coat
			m.albedo_color = Color(0.17, 0.18, 0.19)
			m.metallic = 0.2
			m.roughness = 0.55
		"bumper":
			m.albedo_color = Color(0.06, 0.06, 0.065)
			m.roughness = 0.6
		"kick":
			m.albedo_color = Color(0.1, 0.1, 0.11)
			m.roughness = 0.8
		"shadow":         # the gap under the plates
			m.albedo_color = Color(0.03, 0.03, 0.035)
			m.roughness = 1.0
		"seam":
			m.albedo_color = Color(0.25, 0.26, 0.27)
			m.metallic = 1.0
			m.roughness = 0.5
	_mats[kind] = m
	return m


## Hairline brushing: random grey per row, constant along the row, as a normal map (lines run along U).
static func _brushed_normal() -> Texture2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := 256
	var img := Image.create(n, n, false, Image.FORMAT_RF)
	for y in n:
		var row := rng.randf()
		var phase := rng.randf() * TAU
		for x in n:
			img.set_pixel(x, y, Color(0.5 + 0.3 * (row - 0.5) + 0.04 * sin(TAU * 3.0 * x / n + phase), 0, 0))
	img.convert(Image.FORMAT_RGBA8)
	img.bump_map_to_normal_map(1.2)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Adds the quad a-b-c-d (in order round its edge) facing `n`, whatever order the corners came in; `col` = optional
## vertex colours per corner.
static func _quad(st: SurfaceTool, q: Array, n: Vector3, uv: Array, col: Array = []) -> void:
	var order := [0, 1, 2, 0, 2, 3]
	# Godot's front faces wind clockwise as seen from the front: (b-a)x(c-a) points away from the viewer
	if ((q[1] - q[0]) as Vector3).cross(q[2] - q[0]).dot(n) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for k in order:
		st.set_normal(n)
		st.set_uv(uv[k])
		st.set_color(col[k] if not col.is_empty() else Color.WHITE)
		st.add_vertex(q[k])


## Upright prism with rounded vertical edges (`size` = w, h, d; corner radius `r`), base at y = 0, centred on X/Z.
## Brushing runs up the sides (U = height) and across the top. `bottom` also closes the base (parts seen from below
## or, turned on their side, from behind).
static func rounded_prism(size: Vector3, r: float, bottom := false) -> ArrayMesh:
	var hw := size.x * 0.5 - r
	var hd := size.z * 0.5 - r
	var ring: Array[Vector3] = []
	var normals: Array[Vector3] = []
	var seg := 6
	for c in 4:
		var cx := hw if c == 0 or c == 1 else -hw
		var cz := hd if c == 0 or c == 3 else -hd
		var a0: float = [PI / 2, 0.0, -PI / 2, PI][c]      # each corner sweeps 90 degrees clockwise seen from above
		for i in seg + 1:
			var a: float = a0 - PI / 2 * i / seg
			var dir := Vector3(cos(a), 0, sin(a))
			ring.append(Vector3(cx, 0, cz) + dir * r)
			normals.append(dir)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var per := 0.0
	for i in ring.size():
		var j := (i + 1) % ring.size()
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[j]
		var l := a.distance_to(b)
		var n := (normals[i] + normals[j]).normalized()
		_quad(st, [a, b, b + Vector3.UP * size.y, a + Vector3.UP * size.y], n,
				[Vector2(0, per), Vector2(0, per + l), Vector2(size.y, per + l), Vector2(size.y, per)])
		per += l
		var top := Vector3.UP * size.y
		_quad(st, [top, a + top, b + top, top], Vector3.UP, [Vector2(0, 0), Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(0, 0)])
		if bottom:
			_quad(st, [Vector3.ZERO, b, a, Vector3.ZERO], Vector3.DOWN, [Vector2(0, 0), Vector2(b.x, b.z), Vector2(a.x, a.z), Vector2(0, 0)])
	st.generate_tangents()
	return st.commit()


## Points along the loop's centre line: [position (y = 0), outward normal, distance along], `seg` per semicircle.
static func _loop(half: float, radius: float, seg := 40) -> Array:
	var raw := []     # [position, outward normal]
	var nstr := maxi(2, int(ceil(half * 2.0 / 0.6)))
	for i in nstr:
		raw.append([Vector3(-half + 2.0 * half * i / nstr, 0, -radius), Vector3(0, 0, -1)])
	for i in seg:
		var a := -PI * 0.5 + PI * i / seg
		raw.append([Vector3(half + radius * cos(a), 0, radius * sin(a)), Vector3(cos(a), 0, sin(a))])
	for i in nstr:
		raw.append([Vector3(half - 2.0 * half * i / nstr, 0, radius), Vector3(0, 0, 1)])
	for i in seg + 1:
		var a := PI * 0.5 + PI * i / seg
		raw.append([Vector3(-half + radius * cos(a), 0, radius * sin(a)), Vector3(cos(a), 0, sin(a))])
	# distance along the loop (a plain loop: lambdas capture locals by value)
	var pts := []
	var s := 0.0
	for i in raw.size():
		if i > 0:
			s += (raw[i - 1][0] as Vector3).distance_to(raw[i][0])
		pts.append([raw[i][0], raw[i][1], s])
	return pts


## Sweeps a profile ([offset outward from the centre line, y], in order) round the loop as one surface.
## Profiles that run inward face up/outward as given; `flip` turns the faces of profiles that run outward.
static func _sweep(loop: Array, profile: Array, material: Material, flip := false, u_scale := 1.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vlen := 0.0
	for k in profile.size() - 1:
		var a: Vector2 = profile[k]
		var b: Vector2 = profile[k + 1]
		var seg_len := a.distance_to(b)
		for i in loop.size() - 1:
			var p0: Vector3 = loop[i][0]
			var p1: Vector3 = loop[i + 1][0]
			var n0: Vector3 = loop[i][1]
			var n1: Vector3 = loop[i + 1][1]
			var u0: float = loop[i][2] * u_scale
			var u1: float = loop[i + 1][2] * u_scale
			var q := [p0 + n0 * a.x + Vector3.UP * a.y, p1 + n1 * a.x + Vector3.UP * a.y,
					p1 + n1 * b.x + Vector3.UP * b.y, p0 + n0 * b.x + Vector3.UP * b.y]
			var uv := [Vector2(u0, vlen), Vector2(u1, vlen), Vector2(u1, vlen + seg_len), Vector2(u0, vlen + seg_len)]
			for idx in ([0, 2, 1, 0, 3, 2] if flip else [0, 1, 2, 0, 2, 3]):
				st.set_uv(uv[idx])
				st.add_vertex(q[idx])
		vlen += seg_len
	st.index()
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material
	return mi


## The fixed parts of a carousel: outer guard rim, skirt, bumper, toe kick, the dark gap under the plates and
## the centre island (wall + top). Returns a node to add under the carousel's root.
static func hull(half: float, radius: float) -> Node3D:
	var root := Node3D.new()
	root.name = "CarouselHull"
	var loop := _loop(half, radius)
	var r := BAND
	var py := PLATE_Y
	# outer side, from the plate edge over the rounded rim and down the skirt
	var rim := [Vector2(r - 0.02, py - 0.005), Vector2(r + 0.02, py + 0.035), Vector2(r + 0.06, py + 0.055),
			Vector2(r + 0.11, py + 0.055), Vector2(r + 0.145, py + 0.035), Vector2(r + 0.16, py)]
	root.add_child(_sweep(loop, rim, mat("steel"), true))
	var skirt := [Vector2(r + 0.16, py), Vector2(r + 0.16, 0.2)]
	root.add_child(_sweep(loop, skirt, mat("steel"), true))
	var bumper := [Vector2(r + 0.16, 0.2), Vector2(r + 0.2, 0.19), Vector2(r + 0.215, 0.16), Vector2(r + 0.215, 0.11),
			Vector2(r + 0.2, 0.085), Vector2(r + 0.16, 0.075)]
	root.add_child(_sweep(loop, bumper, mat("bumper"), true))
	var kick := [Vector2(r + 0.16, 0.075), Vector2(r + 0.1, 0.06), Vector2(r + 0.1, 0.0)]
	root.add_child(_sweep(loop, kick, mat("kick"), true))
	# dark gap under the plate band (seen between the plates and the rims)
	root.add_child(_sweep(loop, [Vector2(r - 0.01, py - 0.06), Vector2(-r + 0.01, py - 0.06)], mat("shadow")))
	# island: its own steel lip over the plates' inner edge, then the wall up to the top
	var island := [Vector2(-r + 0.02, py - 0.005), Vector2(-r - 0.01, py + 0.03), Vector2(-r - 0.05, py + 0.045),
			Vector2(-r - 0.08, py + 0.06), Vector2(-r - 0.08, ISLAND_Y - 0.03), Vector2(-r - 0.1, ISLAND_Y),
			Vector2(-r - 0.14, ISLAND_Y)]
	root.add_child(_sweep(loop, island, mat("steel")))
	root.add_child(_island_top(half, radius - BAND - 0.14))
	# skirt panel joints every ~1.2 m
	var total: float = loop[loop.size() - 1][2]
	var joints := int(total / 1.2)
	var jm := BoxMesh.new()
	jm.size = Vector3(0.006, py - 0.21, 0.008)
	for j in joints:
		var s := total * j / joints
		var p: Array = _at(loop, s)
		var mi := MeshInstance3D.new()
		mi.mesh = jm
		mi.material_override = mat("seam")
		root.add_child(mi)
		mi.position = p[0] + p[1] * (r + 0.163) + Vector3.UP * (0.21 + (py - 0.21) * 0.5)
		mi.rotation.y = atan2(p[1].x, p[1].z) + PI / 2
	return root


static func _at(loop: Array, s: float) -> Array:
	for i in loop.size() - 1:
		if loop[i + 1][2] >= s:
			var k: float = (s - loop[i][2]) / maxf(0.0001, loop[i + 1][2] - loop[i][2])
			return [(loop[i][0] as Vector3).lerp(loop[i + 1][0], k), (loop[i][1] as Vector3).lerp(loop[i + 1][1], k).normalized()]
	return [loop[0][0], loop[0][1]]


## Flat stadium-shaped island top at ISLAND_Y (straights ±half, end radius `ir`).
static func _island_top(half: float, ir: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline: Array[Vector3] = []
	var seg := 24
	for i in seg + 1:
		var a := -PI * 0.5 + PI * i / seg
		outline.append(Vector3(half + ir * cos(a), ISLAND_Y, ir * sin(a)))
	for i in seg + 1:
		var a := PI * 0.5 + PI * i / seg
		outline.append(Vector3(-half + ir * cos(a), ISLAND_Y, ir * sin(a)))
	var c := Vector3(0, ISLAND_Y, 0)
	for i in outline.size():
		var a: Vector3 = outline[i]
		var b: Vector3 = outline[(i + 1) % outline.size()]
		for p in [c, a, b]:
			st.set_uv(Vector2(p.x, p.z) * 0.5)
			st.set_normal(Vector3.UP)
			st.add_vertex(p)
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat("steel_top")
	return mi


## One plate (local +Z = travel direction, +X = outward across the band). Crescent: convex leading edge, the
## trailing edge the same curve so neighbours nest. Fan-shaped like the real ones: 0.38 m long at the island edge,
## 0.62 m at the outer rim, so on the curves (where the outer edge travels further) the plates still overlap and
## no gap opens. Tilted a little so each plate's leading edge rests on the next one (a few mm step).
static func plate() -> ArrayMesh:
	if _plate:
		return _plate
	var n := 12
	var tilt := 0.02
	var th := 0.014
	var lead: Array[Vector3] = []
	var trail: Array[Vector3] = []
	var rows := []          # per x: [z, shade] from the trailing edge to the leading edge
	var pitch := PLATE_LEN - 0.02
	for i in n + 1:
		var x := -BAND + 0.01 + (2.0 * BAND - 0.02) * i / n
		var length := lerpf(0.38, 0.62, (x + BAND) / (2.0 * BAND))
		var bulge := 0.05 * (1.0 - pow(x / BAND, 2.0))
		var zl := length * 0.5 + bulge
		var zt := -length * 0.5 + bulge
		lead.append(Vector3(x, zl * tilt - 0.008, zl))
		trail.append(Vector3(x, zt * tilt - 0.008, zt))
		# the part left visible in front of the plate behind it gets a soft contact shadow at its start, so each
		# plate reads as a plate without a gap opening between them
		var zb := maxf(zt + 0.01, zl - pitch)
		rows.append([[zt, 0.42], [zb, 0.42], [minf(zb + 0.07, zl - 0.01), 0.92], [zl, 1.06]])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var up := Vector3(0, 1, -tilt).normalized()
	var xs := lead.map(func(p: Vector3) -> float: return p.x)
	for i in n:
		for r in 3:
			var q := []
			var col := []
			for c in [[i, r], [i + 1, r], [i + 1, r + 1], [i, r + 1]]:
				var z: float = rows[c[0]][c[1]][0]
				q.append(Vector3(xs[c[0]], z * tilt - 0.008, z))
				var v: float = rows[c[0]][c[1]][1]
				col.append(Color(v, v, v))
			_quad(st, q, up, q.map(func(p: Vector3) -> Vector2: return Vector2(p.x, p.z)), col)
	# rim all round (leading, outer end, trailing, inner end), straight down to the underside
	var ring: Array[Vector3] = []
	ring.append_array(lead)
	for i in range(trail.size() - 1, -1, -1):
		ring.append(trail[i])
	var centre := Vector3(0, 0, 0.05)
	for i in ring.size():
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % ring.size()]
		var mid := (a + b) * 0.5
		var out := Vector3(mid.x - centre.x, 0, mid.z - centre.z)
		var edge := Vector3(b.x - a.x, 0, b.z - a.z)
		var nrm := Vector3(edge.z, 0, -edge.x).normalized()
		if nrm.dot(out) < 0.0:
			nrm = -nrm
		var q := [a, b, b + Vector3(0, -th, 0), a + Vector3(0, -th, 0)]
		_quad(st, q, nrm, [Vector2(0, 0), Vector2(1, 0), Vector2(1, 0.05), Vector2(0, 0.05)])
	st.generate_tangents()
	_plate = st.commit()
	return _plate


## Plates laid all round a loop that never moves (the decorative carousels), one MultiMesh.
static func plates_static(half: float, radius: float) -> MultiMeshInstance3D:
	var loop := _loop(half, radius)
	var total: float = loop[loop.size() - 1][2]
	var count := int(total / (PLATE_LEN - 0.02))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = plate()
	mm.instance_count = count
	for i in count:
		var p: Array = _at(loop, total * i / count)
		var out: Vector3 = p[1]
		var tan := Vector3(-out.z, 0, out.x)        # travel direction (clockwise seen from above)
		var b := Basis(Vector3.UP, atan2(tan.x, tan.z))
		mm.set_instance_transform(i, Transform3D(b, p[0] + Vector3.UP * PLATE_Y))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat("rubber")
	return mmi
