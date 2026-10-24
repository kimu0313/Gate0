extends Node
## Debug: `-- --zfight-audit` (game or level scene): finds visible box faces that lie in the same plane, face the same
## way and overlap (z-fighting), prints them biggest first and quits. Boxes turned by multiples of 90° about Y only.

const EPS := 0.002          # metres apart that still counts as the same plane
const MIN_AREA := 0.0004    # overlap (m²) worth reporting


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().create_timer(1.5).timeout
	var faces := {}        # "axis dir coord" -> Array of [rect Rect2, node, aabb]
	var boxes := 0
	for n in get_tree().root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree() or not (mi.mesh is BoxMesh):
			continue
		var b := mi.global_basis
		# only boxes aligned to the world axes (any 90° turn about Y, any scale)
		if absf(b.y.normalized().y) < 0.999:
			continue
		var bb := mi.global_transform * mi.get_aabb()
		boxes += 1
		for axis in 3:
			for dir in [-1, 1]:
				var coord: float = bb.position[axis] if dir < 0 else bb.end[axis]
				var u := (axis + 1) % 3
				var v := (axis + 2) % 3
				var r := Rect2(bb.position[u], bb.position[v], bb.size[u], bb.size[v])
				var key := "%d %d %d" % [axis, dir, int(round(coord / EPS))]
				if not faces.has(key):
					faces[key] = []
				faces[key].append([r, mi, coord])
	var found := []
	for key in faces:
		var list: Array = faces[key]
		if list.size() < 2:
			continue
		for i in list.size():
			for j in range(i + 1, list.size()):
				var a: Rect2 = list[i][0]
				var c: Rect2 = list[j][0]
				if not a.intersects(c):
					continue
				var o := a.intersection(c)
				if o.get_area() < MIN_AREA:
					continue
				found.append([o.get_area(), key, list[i][1], list[j][1], o])
	found.sort_custom(func(x, y): return x[0] > y[0])
	for f in found.slice(0, 400):
		var a: MeshInstance3D = f[2]
		var c: MeshInstance3D = f[3]
		var axis := int(String(f[1]).split(" ")[0])
		print("ZFIGHT %.3fm2 axis=%s  %s  <->  %s  at %s" % [f[0], "xyz"[axis], _desc(a), _desc(c), str((a.global_position).snapped(Vector3.ONE * 0.01))])
	print("ZFIGHT AUDIT boxes=%d pairs=%d" % [boxes, found.size()])
	get_tree().quit(0 if found.is_empty() else 1)


func _desc(mi: MeshInstance3D) -> String:
	var mat: Material = mi.material_override if mi.material_override else mi.get_active_material(0)
	var mname := ""
	if mat:
		mname = mat.resource_name if mat.resource_name != "" else mat.get_class()
	return "%s[%s %s]" % [mi.name, str((mi.mesh as BoxMesh).size.snapped(Vector3.ONE * 0.01)), mname]
