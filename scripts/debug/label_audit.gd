extends Node
## Debug: `-- --label-audit` (game or level scene) lists every world Label3D whose text runs past the panel it
## is printed on, then quits. A label's backing = the visible mesh whose bounds hold the point just behind the
## label's centre; the label fails when a corner of its text box (font metrics x pixel_size) falls outside it.
## Free-standing labels (no backing) are skipped; "no_fit" ones are flagged as such (some are meant to stand proud).

const DEPTH := 0.03        # how far behind the text the backing is looked for
const SLACK := 0.01        # metres a corner may overhang before it counts
const MARGIN_SLACK := 0.004   # the audit allows this much under Geo.label_margin before a label counts as tight


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
	var clipped := 0
	var tight := 0
	var solid: Array = []      # [world AABB, mesh] of everything chunky enough to bury text
	for mi in meshes:
		var wb := mi.global_transform * mi.get_aabb()
		if wb.size.x >= 0.05 and wb.size.y >= 0.05 and wb.size.z >= 0.05:
			solid.append([wb, mi])
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
		# the text box's centre: a left-aligned label's text starts at its origin, a right-aligned one ends there
		if l.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT:
			c += right * px.x * 0.5
		elif l.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
			c -= right * px.x * 0.5
		var corners := [c + right * px.x * 0.5 + up * px.y * 0.5, c - right * px.x * 0.5 + up * px.y * 0.5,
				c + right * px.x * 0.5 - up * px.y * 0.5, c - right * px.x * 0.5 - up * px.y * 0.5]
		var backing: AABB
		var found := false
		var best := INF
		var gap := INF          # smallest distance from the text box to the backing's edge (in the face plane)
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
				gap = INF
				# measured along the text's own left-right and up-down directions (world axis they lie closest to)
				var axes := [_major(right), _major(up)]
				for p: Vector3 in corners:
					var q := p + back
					for ax: int in axes:
						gap = minf(gap, minf(q[ax] - bb.position[ax], bb.end[ax] - q[ax]))
		if not found:
			continue
		checked += 1
		var want := Geo.label_margin(backing.size[_major(right)], backing.size[_major(up)]) - MARGIN_SLACK
		if best <= 0.0 and gap < want and not l.has_meta("tight_ok"):
			tight += 1
			print("LABEL TIGHT %.3fm  %s  at %s  [%s]" % [gap, l.text.replace("
", " / ").left(40), str(c.snapped(Vector3.ONE * 0.01)), l.get_path()])
		if best > 0.0:
			bad += 1
			print("LABEL OVERFLOW %.2fm  %s  at %s  [%s]" % [best, l.text.replace("\n", " / ").left(40), str(c.snapped(Vector3.ONE * 0.01)), l.get_path()])
		# text running into other geometry (a sign pushed into a side wall or a column)
		var text_box := AABB(c, Vector3.ZERO)
		for p: Vector3 in corners:
			text_box = text_box.expand(p)
		for e in solid:
			var ob: AABB = e[0]
			var mi: MeshInstance3D = e[1]
			if not ob.intersects(text_box.grow(0.01)) or ob.grow(SLACK).has_point(c + back):
				continue          # far away, or the backing / something the label sits on
			var inner := ob.grow(-0.03)
			if inner.size.x <= 0.0 or inner.size.y <= 0.0 or inner.size.z <= 0.0:
				continue          # a sheet thinner than the slack (stickers, plates) cannot swallow text
			for p: Vector3 in corners:
				if inner.has_point(p):
					clipped += 1
					print("LABEL CLIP  %s  into %s  at %s" % [l.text.replace("\n", " / ").left(40), _name(mi), str(p.snapped(Vector3.ONE * 0.01))])
					break
	print("LABEL AUDIT labels=%d meshes=%d checked=%d overflow=%d clipped=%d tight=%d" % [get_tree().root.find_children("*", "Label3D", true, false).size(), meshes.size(), checked, bad, clipped, tight])
	get_tree().quit(0 if bad == 0 else 1)


func _major(v: Vector3) -> int:
	var a := v.abs()
	return 0 if a.x >= a.y and a.x >= a.z else (1 if a.y >= a.z else 2)


func _name(mi: MeshInstance3D) -> String:
	var size := mi.get_aabb().size
	return "%s(%s)" % [mi.get_parent().name if mi.get_parent() else mi.name, str(size.snapped(Vector3.ONE * 0.01))]
