class_name Geo
extends RefCounted
## Primitive builders used by the procedural terminal (boxes, cylinders, labels, lights, walls).

## Sign lettering in the signal blue (UiKit.SIGNAL), lifted so it still reads on dark plates in a dark terminal.
const SIGN_BLUE := Color(0.36, 0.56, 1.0)
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_INTERACT := 4
const LAYER_AUDIO := 512        # reverb zones (Terminal) found by every AudioStreamPlayer3D's area_mask
const VIS_PORTAL_HIDDEN := 1 << 19   # render layer 20: seen by your eye, not by a PortalView (what stands behind its doorway)
## Render layer 17: small closed rooms lit only by their own lamps — the lift cars and the stair lobbies, built twice
## (one on each floor they join) and swapped while shut, so nothing from outside may light either copy (Terminal
## takes it out of every other light), and the night-duty room. seal() puts a node and its lights on it.
const VIS_SEALED := 1 << 16


static func seal(node: Node) -> void:
	var all: Array = [node]
	all.append_array(node.find_children("*", "VisualInstance3D", true, false))
	for n in all:
		if n is Light3D:
			(n as Light3D).light_cull_mask = VIS_SEALED
		elif n is VisualInstance3D:
			(n as VisualInstance3D).layers = VIS_SEALED

static var sign_font: Font      # wayfinding signs: DIN-style Bahnschrift, Hangul from Malgun Gothic Bold
static var led_font: Font       # LED / LCD displays: Bahnschrift with wider tracking
static var mono_font: Font      # computer screens (FIDS boot text, X-ray readout)
static var hand_font: Font      # marker / pen handwriting (bundled Nanum Pen Script)
static var engrave_font: Font   # cast or engraved plaques (bundled Nanum Myeongjo Bold)


## World-text fonts. All are MSDF so Label3D text stays crisp at any distance and angle.
static func fonts() -> void:
	if sign_font != null:
		return
	var kr := korean_font(700, true)
	sign_font = _din(1, kr)
	led_font = _din(2, kr)
	var m: Font = installed_font(["Consolas"], true)
	if m:
		(m as SystemFont).font_weight = 700
	else:
		m = font_file("res://assets/fonts/IBMPlexMono-Bold.ttf", true)
	m.fallbacks = [kr]
	mono_font = m
	hand_font = bundled_font("res://assets/fonts/NanumPenScript-Regular.ttf", ["Gungsuh", "Batang"], true)
	engrave_font = bundled_font("res://assets/fonts/NanumMyeongjo-Bold.ttf", ["Batang", "serif"], true)


static func _din(tracking: int, fallback: Font) -> Font:
	var fv := FontVariation.new()
	fv.base_font = sign_face(true)
	fv.spacing_glyph = tracking
	fv.fallbacks = [fallback]
	return fv


## The DIN-style sign face: Bahnschrift, or bundled Barlow Medium where it is missing. This is
## Bahnschrift's default instance on purpose — earlier {"wght", "wdth"} variation dictionaries used
## string keys, which Godot ignores, so the look that was signed off never had them.
static func sign_face(msdf := false) -> Font:
	var sys := installed_font(["Bahnschrift"], msdf)
	return sys if sys else font_file("res://assets/fonts/Barlow-Medium.ttf", msdf)


## The UI and sign faces are Windows fonts (Bahnschrift, Malgun Gothic, Consolas). This returns the
## installed one, or null where they are missing (Steam Deck, Proton, Linux) so callers switch to the
## bundled OFL stand-ins. `-- --bundled-fonts` forces null to preview the stand-ins on Windows.
static func installed_font(names: Array, msdf := false) -> SystemFont:
	if OS.get_cmdline_user_args().has("--bundled-fonts"):
		return null
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.multichannel_signed_distance_field = msdf
	return f if f.get_font_name() in names else null


## The UI face for the player's language: Malgun Gothic (Korean, English), or for Japanese a Japanese
## system face (Yu Gothic UI → Meiryo) with the Korean face behind it for Hangul (player names, signage
## words); without those, the bundled Noto Sans JP. World signage keeps korean_font() in every language.
static func ui_font(weight: int) -> Font:
	var kr := korean_font(weight)
	if not TranslationServer.get_locale().begins_with("ja"):
		return kr
	var jp: Font = installed_font(["Yu Gothic UI", "Yu Gothic", "Meiryo UI", "Meiryo"])
	if jp:
		(jp as SystemFont).font_weight = weight
	else:
		jp = font_file("res://assets/fonts/NotoSansJP-Variable.ttf", false, weight)
	jp.fallbacks = [kr]
	return jp


## Malgun Gothic, or the bundled Noto Sans KR (variable) at the same weight.
static func korean_font(weight: int, msdf := false) -> Font:
	var sys := installed_font(["Malgun Gothic"], msdf)
	if sys:
		sys.font_weight = weight
		return sys
	return font_file("res://assets/fonts/NotoSansKR-Variable.ttf", msdf, weight)


## A bundled font file; `weight` > 0 picks that weight of a variable font (axis keys must be
## TextServer tags — string keys like "wght" are silently ignored).
static func font_file(path: String, msdf := false, weight := 0) -> Font:
	var f := (load(path) as FontFile).duplicate() as FontFile
	f.multichannel_signed_distance_field = msdf
	if weight <= 0:
		return f
	var fv := FontVariation.new()
	fv.base_font = f
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return fv


## A font shipped in assets/fonts (so it looks the same on every PC), falling back to system fonts.
static func bundled_font(path: String, system_names: Array, msdf := false) -> Font:
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(system_names)
	sys.multichannel_signed_distance_field = msdf
	if not ResourceLoader.exists(path):
		return sys
	var f := (load(path) as FontFile).duplicate() as FontFile
	f.multichannel_signed_distance_field = msdf
	f.fallbacks = [sys]
	return f


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


## World text. `style` follows the material the text sits on:
##   sign    — backlit sign or lightbox (unlit, DIN face)            [default]
##   print   — printed / painted on a surface (lit by the scene)
##   led     — LED / LCD display (unlit, wide tracking, slightly HDR) [default when mono]
##   lcd     — passive LCD with dark digits (lit by the scene, wide tracking)
##   hand    — marker or pen handwriting (lit)
##   engrave — cast or engraved plaque (lit, serif)
static func label(parent: Node, text: String, pos: Vector3, rot_y := 0.0, font_size := 64, color := Color.WHITE,
		pixel_size := 0.01, mono := false, style := "") -> Label3D:
	fonts()
	if style == "":
		style = "led" if mono else "sign"
	var l := Label3D.new()
	# world signage is physical Korean airport signage and stays as built in every language
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = text
	l.font_size = font_size
	l.pixel_size = pixel_size
	l.modulate = color
	match style:
		"led":
			l.font = led_font
			l.modulate = Color(color.r * 1.4, color.g * 1.4, color.b * 1.4, color.a)
		"lcd":
			l.font = led_font
		"hand":
			l.font = hand_font
			l.font_size = int(font_size * 1.3)
		"engrave":
			l.font = engrave_font
		_:
			l.font = sign_font
	l.outline_size = 0
	l.shaded = style in ["print", "lcd", "hand", "engrave"]
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(l)
	l.position = pos
	l.rotation.y = rot_y
	return l


## Shrinks a Label3D so its widest line fits `max_width` metres (signs, boards, plates) and, when given, all of
## its lines fit `max_height`.
static func fit(l: Label3D, max_width: float, max_height := INF) -> Label3D:
	# remembered, so text changed later through set_text() is fitted to the same space
	if not l.has_meta("fit_px"):
		l.set_meta("fit_px", l.pixel_size)
	l.set_meta("fit_space", Vector2(max_width, max_height if is_finite(max_height) else 1000.0))
	var w := l.font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x * l.pixel_size
	if w > max_width and w > 0.0:
		l.pixel_size *= max_width / w
	var h := _text_px(l).y * l.pixel_size
	if h > max_height and h > 0.0:
		l.pixel_size *= max_height / h
	return l


## Text size of a Label3D at pixel_size 1 (font pixels).
static func _text_px(l: Label3D) -> Vector2:
	if l.text == "":
		return Vector2.ZERO
	var lines := l.text.count("\n") + 1
	var w := l.font.get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x
	var h := lines * l.font.get_height(l.font_size) + (lines - 1) * l.line_spacing
	return Vector2(w, h)


## Clear face kept round printed text on a w x h panel (metres, each side): 8 % of its smaller side, at most 7 cm,
## so signs and plates never print edge to edge or under their frame.
static func label_margin(w: float, h: float) -> float:
	return clampf(minf(w, h) * 0.08, 0.004, 0.07)


## The box face a label is printed on: returns the largest text size (metres) that stays inside it with a
## margin, or Vector2.ZERO when the label isn't on a box (free-standing wall text).
static func _backing_space(l: Label3D) -> Vector2:
	var p := l.get_parent()
	if p == null:
		return Vector2.ZERO
	var boxes: Array = []
	if p is MeshInstance3D and (p as MeshInstance3D).mesh is BoxMesh:
		boxes.append([Transform3D.IDENTITY, ((p as MeshInstance3D).mesh as BoxMesh).size])
	for c in p.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh is BoxMesh:
			boxes.append([(c as MeshInstance3D).transform, ((c as MeshInstance3D).mesh as BoxMesh).size])
	var best := Vector2.ZERO
	var best_area := INF
	for b in boxes:
		var inv: Transform3D = (b[0] as Transform3D).affine_inverse()
		var s: Vector3 = b[1]
		var d := inv * l.position
		var right := (inv.basis * l.transform.basis.x).normalized()
		var up := (inv.basis * l.transform.basis.y).normalized()
		var nrm := (inv.basis * l.transform.basis.z).normalized()
		var half := s * 0.5
		var ext_r := absf(right.x) * half.x + absf(right.y) * half.y + absf(right.z) * half.z
		var ext_u := absf(up.x) * half.x + absf(up.y) * half.y + absf(up.z) * half.z
		var ext_n := absf(nrm.x) * half.x + absf(nrm.y) * half.y + absf(nrm.z) * half.z
		var off_r := absf(d.dot(right))
		var off_u := absf(d.dot(up))
		var off_n := absf(d.dot(nrm))
		# the label must sit on (just in front of) the face, inside its outline
		if off_n < ext_n - 0.03 or off_n > ext_n + 0.12 or off_r > ext_r or off_u > ext_u:
			continue
		var area := ext_r * ext_u
		if area >= best_area:
			continue
		var pad := label_margin(2.0 * ext_r, 2.0 * ext_u)
		best_area = area
		best = Vector2(maxf(0.01, 2.0 * (ext_r - off_r) - 2.0 * pad), maxf(0.01, 2.0 * (ext_u - off_u) - 2.0 * pad))
	return best


## Shrinks every Label3D under `root` that would spill off the sign/plate/panel it is printed on, and
## remembers the space so text set later through set_text() keeps fitting. Returns the number shrunk.
static func fit_labels(root: Node, verbose := false) -> int:
	var n := 0
	for node in root.find_children("*", "Label3D", true, false):
		var l := node as Label3D
		if l.has_meta("no_fit"):
			continue
		var space := _backing_space(l)
		if space == Vector2.ZERO:
			continue
		var t := _text_px(l)
		# needing to halve the text means the box found isn't really its sign (belt surface, post...)
		if t.x > 0.0 and minf(space.x / t.x, space.y / t.y) < l.pixel_size * 0.5:
			continue
		l.set_meta("fit_space", space)
		l.set_meta("fit_px", l.pixel_size)
		if _refit(l):
			n += 1
			if verbose:
				print("  fit %3d%%  %s" % [int(l.pixel_size / float(l.get_meta("fit_px")) * 100.0), l.text.replace("\n", " / ")])
	return n


static func _refit(l: Label3D) -> bool:
	var space: Vector2 = l.get_meta("fit_space")
	var base: float = l.get_meta("fit_px")
	var t := _text_px(l)
	var px := base
	if t.x > 0.0:
		px = minf(px, space.x / t.x)
	if t.y > 0.0:
		px = minf(px, space.y / t.y)
	l.pixel_size = px
	return px < base * 0.995


## Changes a world label's text and keeps it inside its sign.
static func set_text(l: Label3D, text: String) -> void:
	l.text = text
	if l.has_meta("fit_space"):
		_refit(l)


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


## Rectangular ceiling fixture (fluorescent troffer): lights straight down from a size.x × size.y
## rectangle, so glossy floors show its long soft reflection instead of a point hotspot.
static func area_light(parent: Node, pos: Vector3, size: Vector2, color: Color, energy: float, light_range: float, shadow := false) -> AreaLight3D:
	var l := AreaLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.area_size = size
	l.area_range = light_range
	l.shadow_enabled = shadow
	l.light_volumetric_fog_energy = 0.6
	parent.add_child(l)
	l.position = pos
	l.rotation.x = -PI / 2
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
## openings: Array of [from_offset, to_offset, opening_top] measured along the wall from `a`; a 4th value, the sill
## height, makes it a window (the wall stays under it).
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
		if o.size() > 3 and float(o[3]) > 0.01:       # a window: [from, to, head, sill] keeps the wall under its sill
			_wall_piece(parent, a, along_x, dir, s, e, base_y, base_y + float(o[3]), thickness, mat)
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
