class_name TripoProps
extends RefCounted
## Tripo P2.0 prop meshes: assets/models/<zone>/<id>.glb (front = +Z, pivot = floor centre, mesh only) sharing one
## atlas material per zone (<zone>_albedo / _normal / _orm: AO, roughness, metallic). Built by blender_zone.py in
## the GATE0_Tripo_References folder; see assets/models/<zone>/<zone>_report.json for budgets.

const MODELS := "res://assets/models/"

static var _atlas := {}


## The shared atlas material of a zone.
static func atlas(zone: String) -> StandardMaterial3D:
	if _atlas.has(zone):
		return _atlas[zone]
	var dir := MODELS + zone + "/" + zone
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(dir + "_albedo.png")
	m.normal_enabled = true
	m.normal_texture = load(dir + "_normal.png")
	var orm: Texture2D = load(dir + "_orm.png")
	m.ao_enabled = true
	m.ao_texture = orm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness_texture = orm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.metallic = 1.0
	m.metallic_texture = orm
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	_atlas[zone] = m
	return m


## False with `-- --no-tripo` (every prop falls back to its code-built version, for before/after captures).
static func exists(zone: String, id: String) -> bool:
	if OS.get_cmdline_user_args().has("--no-tripo"):
		return false
	return ResourceLoader.exists(MODELS + zone + "/" + id + ".glb")


## Instances a prop under `parent` at `pos` turned `rot_y` (radians), every mesh using the zone atlas
## (or `material` when given, e.g. a tinted copy). `size` stretches it to those bounds (see fit), `collide`
## then adds a box blocker around it.
static func spawn(parent: Node, zone: String, id: String, pos := Vector3.ZERO, rot_y := 0.0, collide := false,
		material: Material = null, size := Vector3.ZERO) -> Node3D:
	var n: Node3D = (load(MODELS + zone + "/" + id + ".glb") as PackedScene).instantiate()
	parent.add_child(n)
	n.position = pos
	n.rotation.y = rot_y
	var mat: Material = material if material else atlas(zone)
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = mat
	if size != Vector3.ZERO:
		fit(n, size)
	if collide:
		var bb := bounds(n)
		Geo.blocker(parent, n.position + n.basis * bb.get_center(), bb.size * n.scale, rot_y)
	return n


## Local bounds of a prop's meshes (its own space, before the node's transform).
static func bounds(n: Node3D) -> AABB:
	var bb := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b := mi.transform * mi.get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	return bb


## Stretches a placed prop so its bounds become `size` (metres; 0 keeps that axis).
static func fit(n: Node3D, size: Vector3) -> void:
	var bb := bounds(n)
	n.scale = Vector3(size.x / bb.size.x if size.x > 0.0 else 1.0, size.y / bb.size.y if size.y > 0.0 else 1.0,
			size.z / bb.size.z if size.z > 0.0 else 1.0)


## Moves a placed (and fitted) prop so the centre of its bounds lands on `centre` (parent space).
static func centre_on(n: Node3D, centre: Vector3) -> void:
	n.position = centre - n.basis * bounds(n).get_center()


## Frontmost local z of the prop's vertices above local height `min_y` (e.g. a monitor's screen face, not its
## foot), for putting screens and labels flush on a Tripo body.
static func face_z(n: Node3D, min_y := -INF) -> float:
	var best := -INF
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var p := mi.transform * v
				if p.y >= min_y and p.z > best:
					best = p.z
	return best
