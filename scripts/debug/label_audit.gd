extends Node
## Debug: `-- --label-audit` (game or level scene) lists every world Label3D whose text runs past the panel it
## is printed on, then quits. A label's backing = the visible mesh whose bounds hold the point just behind the
## label's centre; the label fails when a corner of its text box (font metrics x pixel_size) falls outside it.
## Free-standing labels (no backing) are skipped; "no_fit" ones are flagged as such (some are meant to stand proud).

const DEPTH := 0.03        # how far behind the text the backing is looked for
const SLACK := 0.01        # metres a corner may overhang before it counts


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().create_timer(2.0).timeout
	var meshes: Array[MeshInstance3D] = []
	for n in get_tree().root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.is_visible_in_tree() and mi.mesh != null:
			meshes.append(mi)
	var checked := 0
	var bad := 0
	for n in get_tree().root.find_children("*", "Label3D", true, false):
		var l := n as Label3D
		if not l.is_visible_in_tree() or l.text.strip_edges() == "":
			continue
		var px := Geo._text_px(l) * l.pixel_size
		var b := l.global_basis
		var right := b.x
		var up := b.y
		var back := -b.z.normalized() * DEPTH
		var c := l.global_position
		var corners := [c + right * px.x * 0.5 + up * px.y * 0.5, c - right * px.x * 0.5 + up * px.y * 0.5,
				c + right * px.x * 0.5 - up * px.y * 0.5, c - right * px.x * 0.5 - up * px.y * 0.5]
		var backing: AABB
		var found := false
		var best := INF
		for mi in meshes:
			var bb := (mi.global_transform * mi.get_aabb()).grow(SLACK)
			if not bb.has_point(c + back):
				continue
			found = true
			var over := 0.0
			for p: Vector3 in corners:
				var q := p + back
				var d := Vector3(maxf(bb.position.x - q.x, q.x - bb.end.x), maxf(bb.position.y - q.y, q.y - bb.end.y),
						maxf(bb.position.z - q.z, q.z - bb.end.z))
				over = maxf(over, maxf(d.x, maxf(d.y, d.z)))
			if over < best:
				best = over
				backing = bb
		if not found:
			continue
		checked += 1
		if best > 0.0:
			bad += 1
			print("LABEL OVERFLOW %.2fm  %s  at %s  [%s]" % [best, l.text.replace("\n", " / ").left(40), str(c.snapped(Vector3.ONE * 0.01)), l.get_path()])
	print("LABEL AUDIT labels=%d meshes=%d checked=%d overflow=%d" % [get_tree().root.find_children("*", "Label3D", true, false).size(), meshes.size(), checked, bad])
	get_tree().quit(0 if bad == 0 else 1)
