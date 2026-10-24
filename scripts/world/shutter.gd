class_name Shutter
extends Node3D
## Glass sliding partition that closes off unopened zones: frameless panels hung from a brushed steel track, a
## frosted band printed with the closure notice. Opening slides the panels sideways through a steel-lined slot in
## each jamb into the wall pocket behind it (a single panel goes to the +X side). Partitions in `linked` open and
## close with this one.

var width := 4.0
var height := 4.0
var is_open := false
var linked: Array = []
var _panels: Array[Node3D] = []
var _closed_x: Array[float] = []
var _open_x: Array[float] = []
var _blocker: StaticBody3D


static func create(parent: Node3D, pos: Vector3, rot_y: float, w: float, h: float, label_text := "") -> Shutter:
	var s := Shutter.new()
	s.width = w
	s.height = h
	parent.add_child(s)
	s.position = pos
	s.rotation.y = rot_y
	s._build(label_text)
	return s


func _build(label_text: String) -> void:
	var steel := Mats.get_mat("steel_frame")
	var glass := Mats.get_mat("glass")
	var frost := StandardMaterial3D.new()
	frost.albedo_color = Color(0.9, 0.93, 0.95, 0.78)
	frost.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	frost.roughness = 0.55
	var red := Mats.std(Color(0.75, 0.12, 0.1), 0.5)
	var ink := Color(0.16, 0.18, 0.22)
	# track along the head of the opening, a flush guide in the floor
	Geo.box(self, Vector3(0, height - 0.08, 0), Vector3(width + 0.1, 0.16, 0.2), steel, false)
	Geo.box(self, Vector3(0, 0.004, 0), Vector3(width, 0.008, 0.1), steel, false)
	_blocker = Geo.blocker(self, Vector3(0, height * 0.5, 0), Vector3(width, height, 0.3))
	var n := maxi(1, int(round(width / 1.5)))
	var pw := width / n
	var gh := height - 0.2
	# pocket mouths: a dark slot in each jamb the panels slide into, lined with steel trim on both faces of the wall
	# (without it they slid through the wall's solid end face)
	var dark := Mats.std(Color(0.03, 0.032, 0.036), 0.95)
	var slot_h := height - 0.17
	for side in ([1.0] if n == 1 or OS.get_cmdline_user_args().has("--no-pocket") else [-1.0, 1.0]):
		if OS.get_cmdline_user_args().has("--no-pocket"):
			break                          # debug: the old look, for before/after captures
		var jx: float = side * width * 0.5
		Geo.box(self, Vector3(jx + side * 0.148, 0.01 + slot_h * 0.5, 0.005), Vector3(0.304, slot_h, 0.14), dark, false)
		for tz in [-1.0, 1.0]:
			Geo.box(self, Vector3(jx - side * 0.0125, 0.01 + slot_h * 0.5, 0.005 + tz * 0.0875), Vector3(0.025, slot_h, 0.035), steel, false)
	for i in n:
		var p := Node3D.new()
		add_child(p)
		var x := -width * 0.5 + pw * (i + 0.5)
		# alternate tracks so the panels can stack; a hair of depth per panel so stacked panes never share a plane
		var z := (0.035 if i % 2 == 0 else -0.035) + i * 0.0015
		p.position = Vector3(x, 0, z)
		Geo.box(p, Vector3(0, 0.02 + gh * 0.5, 0), Vector3(pw - 0.02, gh, 0.02), glass, false)
		Geo.box(p, Vector3(0, 0.05, 0), Vector3(pw - 0.02, 0.06, 0.04), steel, false)
		for sx in [-1.0, 1.0]:
			Geo.box(p, Vector3(sx * (pw * 0.5 - 0.08), gh - 0.03, 0), Vector3(0.1, 0.08, 0.045), steel, false)
		# frosted manifestation band with the notice on both faces, a red rule above and below
		Geo.box(p, Vector3(0, 1.32, 0), Vector3(pw - 0.02, 0.4, 0.026), frost, false)
		for y in [1.1, 1.54]:
			Geo.box(p, Vector3(0, y, 0), Vector3(pw - 0.02, 0.025, 0.028), red, false)
		if label_text != "":
			for side in [0.0, PI]:
				var l := Geo.label(p, label_text + "\nAREA CLOSED", Vector3(0, 1.32, 0.0), side, 40, ink, 0.0032, false, "print")
				l.position += Basis(Vector3.UP, side) * Vector3(0, 0, 0.015)
				Geo.fit(l, pw - 0.16, 0.34)
				l.set_meta("no_fit", true)
		# pull handles on the meeting panels
		if n > 1 and (i == n / 2 - 1 or i == n / 2):
			var hx := (pw * 0.5 - 0.12) * (1.0 if i == n / 2 - 1 else -1.0)
			for side in [-1.0, 1.0]:
				Geo.box(p, Vector3(hx, 1.0, side * 0.04), Vector3(0.025, 0.7, 0.025), steel, false)
		_panels.append(p)
		_closed_x.append(x)
		# open: into the pocket beyond the nearer jamb (one panel: the +X side)
		var right := x > 0.0 or n == 1
		var k := (n - 1 - i) if right else i                  # how deep in the stack
		_open_x.append((width * 0.5 + pw * 0.5 + 0.03 + k * 0.02) * (1.0 if right else -1.0))


func _set_panels(opened: bool) -> void:
	for i in _panels.size():
		_panels[i].position.x = _open_x[i] if opened else _closed_x[i]


func _slide(opened: bool, secs: float) -> void:
	var t := create_tween().set_parallel(true)
	for i in _panels.size():
		t.tween_property(_panels[i], "position:x", _open_x[i] if opened else _closed_x[i], secs) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func open(instant := false) -> void:
	for s in linked:
		s.open(instant)
	if is_open:
		return
	is_open = true
	_blocker.process_mode = Node.PROCESS_MODE_DISABLED
	_blocker.collision_layer = 0
	if instant:
		_set_panels(true)
		return
	Snd.play_at("partition_slide", global_position + Vector3(0, 2.0, 0), -2.0, 1.0, 10.0)
	_slide(true, 2.4)


func close(instant := false) -> void:
	for s in linked:
		s.close(instant)
	if not is_open:
		return
	is_open = false
	_blocker.collision_layer = Geo.LAYER_WORLD
	_blocker.process_mode = Node.PROCESS_MODE_INHERIT
	if instant:
		_set_panels(false)
		return
	Snd.play_at("partition_slide", global_position + Vector3(0, 2.0, 0), -3.0, 0.92, 10.0)
	_slide(false, 2.0)
