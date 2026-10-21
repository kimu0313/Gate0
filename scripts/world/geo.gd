class_name Geo
extends RefCounted
## Primitive builders used by the procedural terminal (boxes, cylinders, labels, lights, walls).

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_INTERACT := 4

static var sign_font: Font
static var mono_font: Font


static func fonts() -> void:
	if sign_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Malgun Gothic", "Segoe UI", "Noto Sans CJK KR", "sans-serif"])
		f.font_weight = 700
		sign_font = f
		var m := SystemFont.new()
		m.font_names = PackedStringArray(["Consolas", "Lucida Console", "DejaVu Sans Mono", "monospace"])
		m.font_weight = 700
		mono_font = m


static func box(parent: Node, pos: Vector3, size: Vector3, mat: Material, collide := true, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = pos
	mi.rotation.y = rot_y
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = LAYER_WORLD
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		mi.add_child(body)
	return mi


## Invisible collider only.
static func blocker(parent: Node, pos: Vector3, size: Vector3, rot_y := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	body.position = pos
	body.rotation.y = rot_y
	return body


static func cyl(parent: Node, pos: Vector3, radius: float, height: float, mat: Material, collide := false, sides := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = pos
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = LAYER_WORLD
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		cs.shape = shape
		body.add_child(cs)
		mi.add_child(body)
	return mi


static func sphere(parent: Node, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = pos
	return mi


static func capsule(parent: Node, pos: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = height
	mi.mesh = cm
	mi.material_override = mat
	parent.add_child(mi)
	mi.position = pos
	return mi


static func label(parent: Node, text: String, pos: Vector3, rot_y := 0.0, font_size := 64, color := Color.WHITE,
		pixel_size := 0.01, mono := false) -> Label3D:
	fonts()
	var l := Label3D.new()
	l.text = text
	l.font = mono_font if mono else sign_font
	l.font_size = font_size
	l.pixel_size = pixel_size
	l.modulate = color
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(l)
	l.position = pos
	l.rotation.y = rot_y
	return l


static func omni(parent: Node, pos: Vector3, color: Color, energy: float, light_range: float, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.omni_attenuation = 1.2
	l.shadow_enabled = shadow
	l.light_volumetric_fog_energy = 0.6
	l.light_specular = 0.6
	parent.add_child(l)
	l.position = pos
	return l


static func spot(parent: Node, pos: Vector3, target: Vector3, color: Color, energy: float, light_range: float, angle := 40.0, shadow := false) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.spot_range = light_range
	l.spot_angle = angle
	l.shadow_enabled = shadow
	parent.add_child(l)
	l.position = pos
	if not pos.is_equal_approx(target):
		var up := Vector3.UP if absf((target - pos).normalized().y) < 0.99 else Vector3.FORWARD
		l.look_at(target, up)
	return l


## Axis-aligned wall from a to b (on the XZ plane) with optional openings.
## openings: Array of [from_offset, to_offset, opening_top] measured along the wall from `a`.
static func wall(parent: Node, a: Vector2, b: Vector2, height: float, mat: Material, thickness := 0.4,
		openings: Array = [], base_y := 0.0) -> void:
	var along_x := absf(b.x - a.x) > absf(b.y - a.y)
	var length := absf(b.x - a.x) if along_x else absf(b.y - a.y)
	var dir := signf(b.x - a.x) if along_x else signf(b.y - a.y)
	var cuts := openings.duplicate()
	cuts.sort_custom(func(p, q): return p[0] < q[0])
	var cursor := 0.0
	for o in cuts:
		var s: float = o[0]
		var e: float = o[1]
		var top: float = o[2]
		if s > cursor + 0.01:
			_wall_piece(parent, a, along_x, dir, cursor, s, base_y, base_y + height, thickness, mat)
		if top < height - 0.01:
			_wall_piece(parent, a, along_x, dir, s, e, base_y + top, base_y + height, thickness, mat)
		cursor = e
	if cursor < length - 0.01:
		_wall_piece(parent, a, along_x, dir, cursor, length, base_y, base_y + height, thickness, mat)


static func _wall_piece(parent: Node, a: Vector2, along_x: bool, dir: float, s: float, e: float,
		y0: float, y1: float, thickness: float, mat: Material) -> void:
	var mid := (s + e) * 0.5 * dir
	var seg_len := e - s
	var h := y1 - y0
	if along_x:
		box(parent, Vector3(a.x + mid, (y0 + y1) * 0.5, a.y), Vector3(seg_len, h, thickness), mat)
	else:
		box(parent, Vector3(a.x, (y0 + y1) * 0.5, a.y + mid), Vector3(thickness, h, seg_len), mat)


static func area(parent: Node, pos: Vector3, size: Vector3, mask := LAYER_PLAYER) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = mask
	a.monitorable = false
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	a.add_child(cs)
	parent.add_child(a)
	a.position = pos
	return a
