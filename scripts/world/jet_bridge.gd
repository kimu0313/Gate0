class_name JetBridge
extends Node3D
## Where SCENE 03 ends up: the "security office" door opens onto a wide boarding-bridge connector that is not
## part of the terminal. Glass down both sides with nothing behind it, a few cold ceiling panels, and at the far
## end an airport gate door under a departure board that was not there a moment ago (FLIGHT 000 — GATE 0).
##
## Local frame: you come in at the south end (z = 0; the wall behind you is where the door was) and look north
## (-Z) down LENGTH metres to the gate door. Built far below the terminal (ORIGIN), so nothing of it shows through
## the windows: black boxes stand outside the glass. The gate door is a steel fire door (FireDoor), chained and
## padlocked through its push bars: nothing past it shows until it opens.

const ORIGIN := Vector3(0, -200, 320)
const W := 5.2              # inner width
const H := 3.4              # ceiling
const LENGTH := 26.0
const SILL := 0.9           # window sill and head
const HEAD := 2.45
const DOOR_W := 2.0         # gate door opening
const DOOR_H := 2.3
const BOARD_OFF := ["", ""]
const BOARD_BOARDING := ["FLIGHT 000  —  GATE 0", "BOARDING"]
const BOARD_NO_DEST := ["FLIGHT 000   ———   GATE 0", ""]

var zone: LightZone
var gate_door: Node3D            # the steel double fire door (leaves, push bars, chain and padlock)
var door_use: Interactable       # [E] on the padlock / door; the chapter decides what it does
var beyond: Area3D               # just past the door (where the main story continues)
var locked := true
var _leaves: Array[Node3D] = []
var _chain: Node3D
var _padlock: Node3D
var _door_block: StaticBody3D
var _detach: Array[Node3D] = []     # what only the far-below bridge has: the black outside, the vestibule
var south_wall: MeshInstance3D      # the blank wall where you came in (hidden while the prologue looks in through a door)
var vestibule: Array[MeshInstance3D] = []   # the dark space past the gate door (floor, ceiling, sides, back)
var _board_face: MeshInstance3D
var _board_lines: Array[Label3D] = []
var _board_glow: OmniLight3D
var _board_t := 0.0
var _board_mode := BOARD_OFF


func build() -> void:
	position = ORIGIN
	var wall_m := Mats.get_mat("wall")
	var panel_m := Mats.std(Color(0.62, 0.64, 0.66), 0.55)
	var frame := Mats.get_mat("steel_frame")
	var hw := W * 0.5
	var mid_z := -LENGTH * 0.5
	# floor, ceiling, south wall (no door on this side)
	Geo.box(self, Vector3(0, -0.05, mid_z), Vector3(W + 0.6, 0.1, LENGTH + 0.6), Mats.get_mat("carpet"))
	Geo.box(self, Vector3(0, H + 0.1, mid_z), Vector3(W + 0.6, 0.2, LENGTH + 0.6), Mats.get_mat("ceiling"), false)
	south_wall = Geo.box(self, Vector3(0, H * 0.5, 0.15), Vector3(W + 0.6, H, 0.3), wall_m)
	# side walls: solid below the sill and above the head, glass in between, mullions every 2.5 m
	for sx in [-1.0, 1.0]:
		var x: float = sx * (hw + 0.15)
		Geo.box(self, Vector3(x, SILL * 0.5, mid_z), Vector3(0.3, SILL, LENGTH), panel_m)
		Geo.box(self, Vector3(x, (HEAD + H) * 0.5, mid_z), Vector3(0.3, H - HEAD, LENGTH), panel_m, false)
		Geo.box(self, Vector3(x, (SILL + HEAD) * 0.5, mid_z), Vector3(0.03, HEAD - SILL, LENGTH), Mats.get_mat("glass"), false)
		Geo.blocker(self, Vector3(x, H * 0.5, mid_z), Vector3(0.3, H, LENGTH))
		var z := -1.25
		while z > -LENGTH:
			Geo.box(self, Vector3(x - sx * 0.02, (SILL + HEAD) * 0.5, z), Vector3(0.12, HEAD - SILL, 0.1), frame, false)
			z -= 2.5
		Geo.box(self, Vector3(x - sx * 0.17, SILL, mid_z), Vector3(0.06, 0.04, LENGTH), frame, false)      # sill
		Geo.cyl(self, Vector3(sx * (hw - 0.06), 0.95, mid_z), 0.022, LENGTH, Mats.get_mat("metal")).rotation.x = PI / 2   # handrail
		# nothing out there: a black box a few metres out, so the glass only ever shows the dark (and the room in it)
		_detach.append(Geo.box(self, Vector3(sx * (hw + 4.0), 1.5, mid_z), Vector3(0.2, 9.0, LENGTH + 12.0), Mats.get_mat("black"), false))
	# telescoping joints: steel floor plates across the carpet, the walls step a little there
	for jz in [-9.0, -18.0]:
		Geo.box(self, Vector3(0, 0.006, jz), Vector3(W, 0.012, 0.5), Mats.get_mat("metal_dark"), false)
		for sx in [-1.0, 1.0]:
			Geo.box(self, Vector3(sx * (hw - 0.02), H * 0.5, jz), Vector3(0.06, H, 0.14), frame, false)
		Geo.box(self, Vector3(0, H - 0.03, jz), Vector3(W, 0.06, 0.14), frame, false)
	# ceiling panels: cold, every 5 m, a few of them dead
	zone = LightZone.new()
	zone.name = "Zone_jetbridge"
	add_child(zone)
	zone.setup("jetbridge", "탑승교", Color(0.82, 0.9, 1.0), 2.2)
	var k := 0
	var z2 := -2.5
	while z2 > -LENGTH + 1.0:
		var dead := k in [2, 5]
		zone.add_panel(Vector3(0, H - 0.04, z2), Vector2(0.45, 1.8), not dead and k % 2 == 0, 0.75, 8.0)
		k += 1
		z2 -= 5.0
	zone.add_hum(Vector3(0, H - 0.3, -LENGTH * 0.5), -24.0)
	# a little spill on the blank south wall, so the place the door should be reads when you turn round to it
	var spill := Geo.omni(zone, Vector3(0, H - 0.7, -0.9), Color(0.8, 0.88, 1.0), 1.6, 5.0)
	spill.light_volumetric_fog_energy = 0.3
	zone.add_light(spill)
	zone.erratic = 0.25
	# PA speaker grille in the ceiling near the far end
	Geo.cyl(self, Vector3(1.2, H - 0.01, -LENGTH + 3.0), 0.16, 0.02, Mats.get_mat("plastic_white"))
	Geo.cyl(self, Vector3(1.2, H - 0.02, -LENGTH + 3.0), 0.12, 0.02, Mats.get_mat("plastic_grey"))
	_build_end(wall_m, frame)
	_build_reverb()
	Geo.fit_labels(self)


## Point the PA comes from (the ceiling speaker by the gate).
func pa_point() -> Vector3:
	return to_global(Vector3(1.2, H - 0.2, -LENGTH + 3.0))


## Where you come in (just in front of the south wall) and the floor point in front of the gate door, global.
func entry_point() -> Vector3:
	return to_global(Vector3(0, 0.05, -0.75))


func door_front() -> Vector3:
	return to_global(Vector3(0, 0.05, -LENGTH + 1.6))


## Inside the corridor (rect in local x/z)?
func contains(p: Vector3) -> bool:
	var l := to_local(p)
	return absf(l.x) < W * 0.5 + 0.3 and l.z < 0.4 and l.z > -LENGTH - 3.5 and absf(l.y) < 6.0


# --------------------------------------------------------------------------------------------
## North end: wall with the gate door, the departure board above it, a short dark vestibule behind.
func _build_end(wall_m: Material, frame: Material) -> void:
	var ez := -LENGTH - 0.15
	var side_w := (W + 0.6 - DOOR_W) * 0.5
	for sx in [-1.0, 1.0]:
		Geo.box(self, Vector3(sx * (DOOR_W * 0.5 + side_w * 0.5), H * 0.5, ez), Vector3(side_w, H, 0.3), wall_m)
	Geo.box(self, Vector3(0, (DOOR_H + H) * 0.5, ez), Vector3(DOOR_W, H - DOOR_H, 0.3), wall_m)
	# door frame
	for sx in [-1.0, 1.0]:
		Geo.box(self, Vector3(sx * (DOOR_W * 0.5 + 0.04), DOOR_H * 0.5, ez + 0.02), Vector3(0.08, DOOR_H, 0.36), frame, false)
	Geo.box(self, Vector3(0, DOOR_H + 0.04, ez + 0.02), Vector3(DOOR_W + 0.16, 0.08, 0.36), frame, false)
	gate_door = Node3D.new()
	gate_door.name = "GateDoor"
	add_child(gate_door)
	gate_door.position = Vector3(0, 0, ez)
	# a steel double fire door (FireDoor), pushed from your side and swinging away from you (-Z): nothing past it shows
	for sx in [-1.0, 1.0]:
		_leaves.append(FireDoor.leaf(gate_door, sx, 1.0, sx * DOOR_W * 0.5, DOOR_W * 0.5 - 0.005, DOOR_H - 0.04))
	# a chain wound round both push bars where they meet, a padlock hanging off it
	_chain = Node3D.new()
	gate_door.add_child(_chain)
	var path: Array[Vector3] = []
	for i in 7:                                          # round the left bar
		var a := TAU * i / 6.0
		path.append(Vector3(-0.2 + 0.012 * sin(a * 0.5), 1.0 + 0.035 * sin(a), 0.0615 + 0.0285 * cos(a)))
	for i in range(1, 10):                               # across the front, sagging
		var u := i / 10.0
		path.append(Vector3(lerpf(-0.2, 0.2, u), 1.0 - 0.06 * sin(u * PI), 0.095))
	for i in 7:                                          # round the right bar
		var a := TAU * i / 6.0
		path.append(Vector3(0.2 - 0.012 * sin(a * 0.5), 1.0 + 0.035 * sin(a), 0.0615 + 0.0285 * cos(a)))
	var link_m := Mats.std(Color(0.42, 0.42, 0.43), 0.35, 0.8)
	for i in path.size() - 1:
		var seg := path[i + 1] - path[i]
		var up := Vector3.RIGHT if absf(seg.normalized().x) < 0.7 else Vector3.UP
		var l := Geo.box(_chain, (path[i] + path[i + 1]) * 0.5, Vector3(0.022, 0.007, seg.length() + 0.014), link_m, false)
		l.basis = Basis.looking_at(seg, up) * Basis(Vector3.BACK, PI / 2 if i % 2 else 0.0)
	_padlock = Node3D.new()
	gate_door.add_child(_padlock)
	_padlock.position = Vector3(0.01, 0.915, 0.1)
	var brass := Mats.std(Color(0.62, 0.48, 0.2), 0.35, 0.85)
	Geo.box(_padlock, Vector3(0, -0.05, 0), Vector3(0.075, 0.065, 0.028), brass, false)
	Geo.box(_padlock, Vector3(0, -0.06, 0.0145), Vector3(0.012, 0.02, 0.002), Mats.get_mat("black"), false)    # keyhole
	for sx in [-1.0, 1.0]:
		Geo.box(_padlock, Vector3(sx * 0.024, 0.0, 0), Vector3(0.011, 0.05, 0.011), Mats.get_mat("metal"), false)
	Geo.box(_padlock, Vector3(0, 0.027, 0), Vector3(0.059, 0.011, 0.011), Mats.get_mat("metal"), false)
	_door_block = Geo.blocker(gate_door, Vector3(0, DOOR_H * 0.5, 0), Vector3(DOOR_W, DOOR_H, 0.2))
	door_use = Interactable.create(gate_door, Vector3(0, 1.05, 0.3), Vector3(DOOR_W - 0.2, 1.4, 0.3), "문 열기", Callable())
	door_use.press_sound = ""
	# a dark vestibule behind it, then a wall (what lies past it is the next part of the story): unlit black, so the
	# gaps round the shut leaves show nothing (the board's glow reaches through the wall and turned a carpet purple)
	var vz := ez - 1.8
	var void_m := Mats.get_mat("void")
	vestibule.append(Geo.box(self, Vector3(0, -0.05, vz), Vector3(DOOR_W + 1.2, 0.1, 3.6), void_m))
	vestibule.append(Geo.box(self, Vector3(0, DOOR_H + 0.4, vz), Vector3(DOOR_W + 1.2, 0.2, 3.6), void_m, false))
	for sx in [-1.0, 1.0]:
		vestibule.append(Geo.box(self, Vector3(sx * (DOOR_W * 0.5 + 0.45), DOOR_H * 0.5 + 0.2, vz), Vector3(0.3, DOOR_H + 0.4, 3.6), void_m))
	vestibule.append(Geo.box(self, Vector3(0, DOOR_H * 0.5 + 0.2, vz - 1.95), Vector3(DOOR_W + 1.2, DOOR_H + 0.4, 0.3), void_m))
	for v in vestibule:
		_detach.append(v)
	beyond = Geo.area(self, Vector3(0, 1.0, ez - 1.3), Vector3(DOOR_W, 2.0, 1.4))
	# departure board over the door
	var board := Node3D.new()
	add_child(board)
	board.position = Vector3(0, DOOR_H + 0.55, ez + 0.17)
	Geo.box(board, Vector3(0, 0, -0.02), Vector3(3.7, 0.9, 0.08), Mats.get_mat("metal_dark"), false)
	_board_face = Geo.box(board, Vector3(0, 0, 0.022), Vector3(3.56, 0.78, 0.006), Mats.get_mat("screen_off"), false)
	for i in 2:
		var l := Geo.label(board, "", Vector3(0, 0.1 if i == 0 else -0.24, 0.03), 0.0, 96, Geo.SIGN_BLUE, 0.006, true, "led")
		l.set_meta("no_fit", true)
		_board_lines.append(l)
	_board_glow = Geo.omni(board, Vector3(0, -0.3, 0.7), Color(0.45, 0.6, 1.0), 0.0, 6.0)
	_board_glow.light_volumetric_fog_energy = 1.2
	# a cold downlight on the door, so the chain and the padlock read from down the corridor
	var dl := Geo.spot(self, Vector3(0, H - 0.1, ez + 1.6), Vector3(0, 1.0, ez), Color(0.85, 0.9, 1.0), 1.4, 6.0, 38.0)
	dl.light_volumetric_fog_energy = 0.8


## The main story: the bridge stands at a real gate (`pos`, turned `yaw`; its gate door at local z -LENGTH faces the
## gate lounge) with its door opening straight into the lounge: no vestibule behind the door, and the airport outside
## the glass instead of black.
func attach(pos: Vector3, yaw: float) -> void:
	position = pos
	rotation.y = yaw
	for n in _detach:
		n.queue_free()
	_detach.clear()


## Departure board: BOARD_OFF, BOARD_BOARDING or BOARD_NO_DEST. `flicker` brings it on like a failing tube.
func set_board(lines: Array, flicker := true) -> void:
	_board_mode = lines
	var on: bool = str(lines[0]) != ""
	for i in _board_lines.size():
		Geo.set_text(_board_lines[i], str(lines[i]) if i < lines.size() else "")
		Geo.fit(_board_lines[i], 3.3, 0.38 if i == 0 else 0.2)
	_board_face.material_override = Mats.emissive(Color(0.02, 0.03, 0.06), 0.4) if on else Mats.get_mat("screen_off")
	_board_glow.light_energy = 0.0
	for l in _board_lines:
		l.visible = on
	if on and flicker:
		var tw := create_tween()
		for a in [1.0, 0.0, 0.6, 0.0, 1.0, 0.2, 1.0]:
			tw.tween_callback(func():
				for l in _board_lines:
					l.modulate.a = a
				_board_glow.light_energy = 0.9 * a)
			tw.tween_interval(randf_range(0.04, 0.12))
		Snd.play_at("power_up", _board_face.global_position, -12.0, 1.3, 5.0)
		Snd.play_at("flicker_zap", _board_face.global_position, -10.0, 1.0, 5.0)
	elif on:
		_board_glow.light_energy = 0.9


func _process(delta: float) -> void:
	_board_t += delta
	# BOARDING blinks under the flight line
	if _board_lines.size() > 1 and str(_board_mode[1]) != "":
		_board_lines[1].modulate.a = 0.35 + 0.65 * float(fmod(_board_t, 1.2) < 0.75)


## The key turns: the padlock drops, the chain slides off and both leaves swing open.
func unlock() -> void:
	if not locked:
		return
	locked = false
	door_use.enabled = false
	Snd.play_at("padlock_open", _padlock.global_position, -2.0, 1.0, 4.0)
	var tw := create_tween()
	tw.tween_property(_padlock, "rotation:z", 0.6, 0.12)
	tw.tween_property(_padlock, "position", Vector3(0.1, 0.03, 0.32), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_padlock, "rotation", Vector3(1.2, 0.4, 1.4), 0.38)
	tw.tween_callback(func(): Snd.play_at("chain_drop", _chain.global_position, -2.0, 1.0, 4.0))
	tw.tween_property(_chain, "position", Vector3(0, -0.96, 0.12), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_chain, "rotation:z", 0.25, 0.32)
	tw.tween_interval(0.5)
	tw.tween_callback(func(): Snd.play_at("door_heavy", gate_door.global_position, -4.0, 0.85, 6.0))
	for i in _leaves.size():
		var sx := -1.0 if i == 0 else 1.0
		tw.parallel().tween_property(_leaves[i], "rotation:y", FireDoor.open_angle(sx, 1.0, 80.0), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _door_block.collision_layer = 0)


## Locked: the push bars go down, the leaves knock against the latch and the chain, and stay shut.
func rattle() -> void:
	Snd.play_at(Snd.variant("door_rattle"), gate_door.global_position + Vector3(0, 1.0, 0.1), -2.0, randf_range(0.95, 1.05), 5.0)
	Snd.play_at("chain_drop", _chain.global_position + Vector3(0, 1.0, 0.1), -18.0, 1.6, 4.0)
	FireDoor.jiggle(_leaves, 1.0)


func _build_reverb() -> void:
	var a := Area3D.new()
	a.name = "Reverb_jetbridge"
	a.collision_layer = Geo.LAYER_AUDIO
	a.collision_mask = 0
	a.monitoring = false
	a.reverb_bus_enabled = true
	a.reverb_bus_name = "RevLong"
	a.reverb_bus_amount = 0.34
	a.reverb_bus_uniformity = 0.4
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(W, H, LENGTH + 4.0)
	cs.shape = box
	a.add_child(cs)
	add_child(a)
	a.position = Vector3(0, H * 0.5, -LENGTH * 0.5 - 1.0)
