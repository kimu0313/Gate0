class_name Lift
extends Node
## The lift at the end of the service corridors (user: "출구 문을 엘리베이터로 바꿔줘" — the far steel doors were the
## way out to the lounge; "보안실은 4층이고 공항 라운지는 1층"). Call it at a landing ([E] on the call button), the
## doors slide open, step in and press the other floor on the panel: the doors shut, the car runs (a jolt, the motor,
## the floor display counting 4 3 2 1), and they open on the other landing. Both ways; an empty car can be called.
##
## The two landings are not in one building — the corridors are built far below the terminal (ServiceHall.ORIGIN) —
## so the car is built twice, once behind each landing, the same to the millimetre (car()), and the ride carries you
## from one copy to the other while every door is shut (carry()). The copies stand on Geo.VIS_SEALED and light only
## themselves, so nothing round either one can give the swap away; the landing side (frame, landing doors, hall
## lantern, call button) is ordinary world.
##
## car() frame: the doorway's middle on the landing-side face of its wall, floor level, local +Z out to the landing.
## The car stands behind the wall (-Z), its door plane GAP behind the wall's back face.

signal carried(to: int)          # the player was moved into car `to` (a ride arrived with them in it)

## (enlarged — user: "엘리베이터 너무 작아 크기 키워줘": was a 0.9 x 2.1 m door on a 1.6 x 1.4 x 2.3 m car)
const OPEN_W := 1.1
const OPEN_H := 2.3
const CAR_W := 2.0               # inside
const CAR_D := 1.9
const CAR_H := 2.65
const FRONT := 0.08              # the front returns: the inside starts this far behind the car's door plane
const GAP := 0.09                # car door plane to the landing wall's back face
const LEAF_W := 0.57
const SLIDE := 0.55
const DOOR_TIME := 1.4
const FLOOR_TIME := 1.6          # a floor's run on the ride
const IDLE_CLOSE := 9.0          # the doors shut by themselves after standing open this long
const LED := Color(1.0, 0.3, 0.12)

var cars: Array[Dictionary] = []
var floors: Array[int] = []
var at := 0                      # the landing the car stands at
var doors_open := false
var busy := false
var _shown := 0                  # the floor on the displays
var _idle := 0.0
var _inside := -1                # the car copy the player stands in (-1: neither)
var _motor: AudioStreamPlayer
var _door_tw: Array[Tween] = []
var locked := false              # the story keeps it shut: the call buttons only click


## Joins two car() builds (each landing's) into one lift: [floor of a, floor of b], the car standing at `start`.
static func link(parent: Node, a: Dictionary, b: Dictionary, floor_a: int, floor_b: int, start := 0) -> Lift:
	var l := Lift.new()
	l.name = "Lift"
	parent.add_child(l)
	l.cars = [a, b]
	l.floors = [floor_a, floor_b]
	l.at = start
	l._shown = l.floors[start]
	for i in 2:
		var k := i
		(l.cars[i].call as Interactable).callback = func(): l._call(k)
		(l.cars[i].go as Interactable).callback = func(): l._go()
		(l.cars[i].open as Interactable).callback = func(): l._open_pressed()
		(l.cars[i].go as Interactable).prompt = "%d층 누르기" % l.floors[1 - i]
	l._motor = AudioStreamPlayer.new()
	l._motor.bus = "SFX"
	l._motor.stream = Snd.stream("lift_motor_loop")
	l._motor.volume_db = -60.0
	l.add_child(l._motor)
	l._display()
	return l


# --------------------------------------------------------------------------------------------
## The car and its landing, built into `parent` at `face_xf` (see the class notes) in a wall `wall_t` thick on floor
## `floor_no`. Returns {land, root (the car's frame node), leaves (car), land_leaves, block, call, go, open,
## lantern [digit, arrow], display [digit, arrow], call_lamp, go_lamps {floor: lamp}, floor_no, wall_t}.
static func car(parent: Node3D, face_xf: Transform3D, wall_t: float, floor_no: int, other_floor: int) -> Dictionary:
	var out := {"floor_no": floor_no, "wall_t": wall_t}
	# brushed steel without metalness: nothing near either landing gives it reflections to show (it read black)
	var steel := Mats.std(Color(0.66, 0.67, 0.66), 0.38, 0.12)
	var dark := Mats.std(Color(0.06, 0.06, 0.065), 0.25)
	# --- the landing: a stainless frame lining the opening, the landing doors behind the wall, sill, lantern, call
	var land := Node3D.new()
	land.name = "LiftLanding"
	parent.add_child(land)
	land.transform = face_xf
	out.land = land
	var hw := OPEN_W * 0.5
	for sx in [-1.0, 1.0]:
		Geo.box(land, Vector3(sx * (hw + 0.05), OPEN_H * 0.5 + 0.04, -wall_t * 0.5 + 0.01), Vector3(0.1, OPEN_H + 0.08, wall_t + 0.04), steel, false)
	Geo.box(land, Vector3(0, OPEN_H + 0.075, -wall_t * 0.5 + 0.01), Vector3(OPEN_W + 0.2, 0.15, wall_t + 0.04), steel, false)
	var sill := Geo.box(land, Vector3(0, -0.022, -(wall_t + GAP) * 0.5 + 0.03), Vector3(OPEN_W + 0.1, 0.05, wall_t + GAP + 0.06), Mats.std(Color(0.45, 0.46, 0.46), 0.4, 0.7))
	sill.position.y = -0.0225
	Geo.box(land, Vector3(0, 0.004, 0.0), Vector3(OPEN_W, 0.004, 0.012), dark, false)     # the sill's groove
	var land_leaves: Array[Node3D] = []
	for sx in [-1.0, 1.0]:
		var lf := Node3D.new()
		land.add_child(lf)
		lf.position = Vector3(sx * LEAF_W * 0.5, 0, -wall_t - 0.025)
		Geo.box(lf, Vector3(0, OPEN_H * 0.5 + 0.01, 0), Vector3(LEAF_W, OPEN_H + 0.02, 0.03), steel, false)
		land_leaves.append(lf)
	out.land_leaves = land_leaves
	# hoistway dark behind the opening's edges (never lit)
	for sx in [-1.0, 1.0]:
		Geo.box(land, Vector3(sx * (hw + 0.6), OPEN_H * 0.5, -wall_t - GAP * 0.5), Vector3(0.9, OPEN_H + 0.4, GAP), Mats.get_mat("void"), false)
	# hall lantern: the floor the car is at, an arrow while it runs
	var lan := Node3D.new()
	land.add_child(lan)
	lan.position = Vector3(0, OPEN_H + 0.36, 0.012)
	Geo.box(lan, Vector3.ZERO, Vector3(0.36, 0.16, 0.024), steel, false)
	Geo.box(lan, Vector3(0, 0, 0.013), Vector3(0.3, 0.12, 0.004), dark, false)
	var dl := Geo.label(lan, str(floor_no), Vector3(0.05, 0, 0.016), 0.0, 64, LED, 0.0016, true, "led")
	var al := Geo.label(lan, "", Vector3(-0.07, 0, 0.016), 0.0, 48, LED, 0.0016, false, "sign")
	for l: Label3D in [dl, al]:
		l.set_meta("no_fit", true)
	out.lantern = [dl, al]
	# call button, right of the door
	var cp := Node3D.new()
	land.add_child(cp)
	cp.position = Vector3(hw + 0.36, 1.1, 0.008)
	Geo.box(cp, Vector3.ZERO, Vector3(0.11, 0.2, 0.016), steel, false)
	var ring := Geo.cyl(cp, Vector3(0, 0, 0.012), 0.032, 0.012, dark)
	ring.rotation.x = PI / 2
	var lamp_m := Mats.emissive(LED, 0.0, Color(0.8, 0.8, 0.77))
	var lamp := Geo.cyl(cp, Vector3(0, 0, 0.02), 0.024, 0.008, lamp_m)
	lamp.rotation.x = PI / 2
	var arrow := Geo.label(cp, "▲" if other_floor > floor_no else "▼", Vector3(0, 0, 0.0255), 0.0, 40, Color(0.12, 0.12, 0.12), 0.0011, false, "sign")
	arrow.set_meta("no_fit", true)
	out.call_lamp = lamp_m
	out.call = Interactable.create(cp, Vector3(0, 0, 0.06), Vector3(0.28, 0.36, 0.14), "엘리베이터 부르기", Callable())
	(out.call as Interactable).press_sound = ""
	# --- the car (sealed)
	var root := Node3D.new()
	root.name = "LiftCar"
	parent.add_child(root)
	root.transform = face_xf * Transform3D(Basis(), Vector3(0, 0, -(wall_t + GAP)))
	out.root = root
	_build_car(root, out, floor_no, other_floor)
	Geo.seal(root)
	return out


static func _build_car(root: Node3D, out: Dictionary, floor_no: int, other_floor: int) -> void:
	var panel := Mats.std(Color(0.72, 0.66, 0.55), 0.55)          # beige laminate
	var trim := Mats.std(Color(0.58, 0.59, 0.58), 0.35)           # stainless (no metal: no probe may tell the copies apart)
	var steel := Mats.std(Color(0.55, 0.56, 0.56), 0.32)
	var floor_m := Mats.std(Color(0.2, 0.2, 0.21), 0.7)
	var dark := Mats.std(Color(0.05, 0.05, 0.055), 0.25)
	var hw := CAR_W * 0.5
	var back := -FRONT - CAR_D
	var mid_z := (back - FRONT) * 0.5
	# floor (with its pattern of studs), walls, ceiling
	Geo.box(root, Vector3(0, -0.05, (back - 0.02) * 0.5), Vector3(CAR_W + 0.12, 0.1, -back + 0.02), floor_m)
	for i in 5:
		Geo.box(root, Vector3(0, 0.002, back + CAR_D * (i + 1) / 6.0), Vector3(CAR_W - 0.1, 0.003, 0.012), Mats.std(Color(0.14, 0.14, 0.15), 0.6), false)
	for sx in [-1.0, 1.0]:
		Geo.box(root, Vector3(sx * (hw + 0.03), CAR_H * 0.5, mid_z), Vector3(0.06, CAR_H, CAR_D), panel)
		Geo.box(root, Vector3(sx * (hw - 0.002), 0.06, mid_z), Vector3(0.006, 0.12, CAR_D), trim, false)       # kick
		Geo.box(root, Vector3(sx * (hw - 0.002), 1.0, mid_z), Vector3(0.006, 0.04, CAR_D), trim, false)        # chair rail
		Geo.box(root, Vector3(sx * (hw - 0.04), 0.9, mid_z), Vector3(0.035, 0.035, CAR_D - 0.3), steel, false)  # handrail
	Geo.box(root, Vector3(0, CAR_H * 0.5, back - 0.03), Vector3(CAR_W, CAR_H, 0.06), panel)
	Geo.box(root, Vector3(0, 0.06, back + 0.002), Vector3(CAR_W, 0.12, 0.006), trim, false)
	Geo.box(root, Vector3(0, 0.9, back + 0.04), Vector3(CAR_W - 0.3, 0.035, 0.035), steel, false)
	Geo.box(root, Vector3(0, 1.6, back + 0.004), Vector3(1.2, 1.0, 0.006), Mats.std(Color(0.12, 0.13, 0.14), 0.12), false)   # dark glass
	# front returns and header (the car's door slides behind them)
	var ow := OPEN_W * 0.5
	for sx in [-1.0, 1.0]:
		Geo.box(root, Vector3(sx * (ow + (hw + 0.06 - ow) * 0.5), CAR_H * 0.5, -0.045), Vector3(hw + 0.06 - ow, CAR_H, 0.07), steel)
	Geo.box(root, Vector3(0, (OPEN_H + CAR_H) * 0.5, -0.045), Vector3(OPEN_W, CAR_H - OPEN_H, 0.07), steel, false)
	# ceiling with its light panel and a camera dome
	Geo.box(root, Vector3(0, CAR_H + 0.04, (back - 0.02) * 0.5), Vector3(CAR_W + 0.12, 0.08, -back + 0.02), trim, false)
	var glow := Mats.emissive(Color(1.0, 0.95, 0.85), 1.6, Color(0.9, 0.88, 0.84))
	Geo.box(root, Vector3(0, CAR_H - 0.005, mid_z), Vector3(CAR_W - 0.5, 0.012, CAR_D - 0.5), glow, false)
	for k in 5:
		Geo.box(root, Vector3(-0.6 + k * 0.3, CAR_H - 0.013, mid_z), Vector3(0.012, 0.006, CAR_D - 0.5), trim, false)
	var dome := Geo.sphere(root, Vector3(hw - 0.12, CAR_H - 0.02, back + 0.12), 0.05, dark)
	dome.scale = Vector3(1, 0.6, 1)
	var lamp := Geo.omni(root, Vector3(0, CAR_H - 0.35, mid_z), Color(1.0, 0.93, 0.82), 1.3, 4.6)
	lamp.light_volumetric_fog_energy = 0.0
	lamp.light_specular = 0.4
	var low := Geo.omni(root, Vector3(0, 0.6, mid_z + 0.2), Color(1.0, 0.93, 0.82), 0.25, 2.2)
	low.light_volumetric_fog_energy = 0.0
	low.light_specular = 0.0
	# no haze in the car (it would be lit by whatever stands round each copy), its own small room's reverb
	var clear := FogVolume.new()
	clear.size = Vector3(CAR_W, CAR_H, CAR_D)
	var fm := FogMaterial.new()
	fm.density = -1.0
	clear.material = fm
	root.add_child(clear)
	clear.position = Vector3(0, CAR_H * 0.5, mid_z)
	_reverb(root, Vector3(0, CAR_H * 0.5, mid_z), Vector3(CAR_W, CAR_H, CAR_D), "RevTight", 0.22)
	# the car's door
	var leaves: Array[Node3D] = []
	for sx in [-1.0, 1.0]:
		var lf := Node3D.new()
		root.add_child(lf)
		lf.position = Vector3(sx * LEAF_W * 0.5, 0, 0.02)
		Geo.box(lf, Vector3(0, OPEN_H * 0.5, 0), Vector3(LEAF_W, OPEN_H, 0.03), steel, false)
		Geo.box(lf, Vector3(-sx * (LEAF_W * 0.5 - 0.004), OPEN_H * 0.5, -0.017), Vector3(0.008, OPEN_H - 0.1, 0.004), Mats.std(Color(0.2, 0.2, 0.2), 0.8), false)
		leaves.append(lf)
	out.leaves = leaves
	out.block = Geo.blocker(root, Vector3(0, OPEN_H * 0.5, 0.04), Vector3(OPEN_W, OPEN_H, 0.12))
	# the panel on the return beside the door: floor display, floor buttons, open / close, alarm
	var cop := Node3D.new()
	root.add_child(cop)
	cop.position = Vector3(-(ow + 0.19), 1.2, -0.081)
	cop.rotation.y = PI
	Geo.box(cop, Vector3.ZERO, Vector3(0.2, 0.74, 0.008), steel, false)
	Geo.box(cop, Vector3(0, 0.28, 0.006), Vector3(0.15, 0.1, 0.004), dark, false)
	var dd := Geo.label(cop, str(floor_no), Vector3(0.035, 0.28, 0.009), 0.0, 64, LED, 0.0014, true, "led")
	var da := Geo.label(cop, "", Vector3(-0.04, 0.28, 0.009), 0.0, 44, LED, 0.0013, false, "sign")
	for l: Label3D in [dd, da]:
		l.set_meta("no_fit", true)
	out.display = [dd, da]
	var lamps := {}
	var btn_m := Mats.std(Color(0.78, 0.78, 0.76), 0.35)
	for f: int in [4, 3, 2, 1]:
		var y := 0.14 - (4 - f) * 0.085
		var lm := Mats.emissive(LED, 0.0, Color(0.8, 0.8, 0.77))
		var r := Geo.cyl(cop, Vector3(0, y, 0.008), 0.03, 0.01, btn_m)
		r.rotation.x = PI / 2
		var c := Geo.cyl(cop, Vector3(0, y, 0.012), 0.024, 0.006, lm)
		c.rotation.x = PI / 2
		var lb := Geo.label(cop, str(f), Vector3(0, y, 0.0155), 0.0, 40, Color(0.1, 0.1, 0.1), 0.0011, false, "sign")
		lb.set_meta("no_fit", true)
		lamps[f] = lm
	out.go_lamps = lamps
	for b: Array in [[-0.04, -0.23, "◀▶"], [0.04, -0.23, "▶◀"]]:
		var r := Geo.cyl(cop, Vector3(b[0], b[1], 0.008), 0.026, 0.01, btn_m)
		r.rotation.x = PI / 2
		var lb := Geo.label(cop, b[2], Vector3(b[0], b[1], 0.0135), 0.0, 32, Color(0.1, 0.1, 0.1), 0.0009, false, "sign")
		lb.set_meta("no_fit", true)
	var bell := Geo.cyl(cop, Vector3(0, -0.31, 0.008), 0.024, 0.01, Mats.std(Color(0.85, 0.65, 0.1), 0.4))
	bell.rotation.x = PI / 2
	# the destination and the open button ([E]; the panel faces into the car)
	out.go = Interactable.create(cop, Vector3(0, 0.02, 0.06), Vector3(0.22, 0.42, 0.12), "", Callable())
	(out.go as Interactable).press_sound = ""
	out.open = Interactable.create(cop, Vector3(0, -0.27, 0.06), Vector3(0.22, 0.16, 0.12), "문 열기", Callable())
	(out.open as Interactable).press_sound = ""
	# plates: capacity, inspection
	var plate := Geo.label(root, "정원 15인  1000kg", Vector3(-(ow + 0.19), 2.0, -0.087), PI, 28, Color(0.15, 0.15, 0.15), 0.0012, false, "print")
	plate.set_meta("no_fit", true)
	Geo.box(root, Vector3(-hw + 0.003, 1.55, back + 0.35), Vector3(0.004, 0.24, 0.17), Mats.get_mat("paper"), false)
	var cert := Geo.label(root, "승강기 안전검사\n합 격", Vector3(-hw + 0.006, 1.6, back + 0.35), PI / 2, 26, Color(0.15, 0.15, 0.3), 0.0012, false, "print")
	cert.set_meta("no_fit", true)


static func _reverb(parent: Node3D, center: Vector3, size: Vector3, bus: String, amount: float) -> void:
	var a := Area3D.new()
	a.collision_layer = Geo.LAYER_AUDIO
	a.collision_mask = 0
	a.monitoring = false
	a.reverb_bus_enabled = true
	a.reverb_bus_name = bus
	a.reverb_bus_amount = amount
	a.reverb_bus_uniformity = 0.5
	a.priority = 5.0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	a.add_child(cs)
	parent.add_child(a)
	a.position = center


## Moves the player from one copy of a room to the other (`from` / `to`: the same frame in each, global): the same
## spot, heading, pitch and pace relative to the room.
static func carry(p: Player, from: Transform3D, to: Transform3D) -> void:
	var m := to * from.affine_inverse()
	var fwd := m.basis * (-p.camera.global_basis.z)
	var v := p.velocity
	var mv := p.move_vel
	var fl: Basis = p._fl_target
	p.teleport(Transform3D(Basis(), m * p.global_position))
	p.set_look(atan2(-fwd.x, -fwd.z), asin(clampf(fwd.y, -1.0, 1.0)))
	p.velocity = m.basis * v
	p.move_vel = m.basis * mv
	p._fl_target = m.basis * fl
	p.flashlight.global_basis = p._fl_target


# --------------------------------------------------------------------------------------------
func _player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player


## The player in car `i`'s own space (its frame), or INF far away when there is no player.
func _local(i: int) -> Vector3:
	var p := _player()
	if p == null:
		return Vector3.INF
	return (cars[i].root as Node3D).global_transform.affine_inverse() * p.global_position


func is_inside(i: int) -> bool:
	var q := _local(i)
	return absf(q.x) < CAR_W * 0.5 and q.z < -0.3 and q.z > -FRONT - CAR_D - 0.1 and q.y > -0.5 and q.y < CAR_H


## Someone standing in car `i`'s doorway (between the car and the landing): its doors will not shut on them.
func _in_doorway(i: int) -> bool:
	var q := _local(i)
	var wt: float = cars[i].wall_t
	return absf(q.x) < OPEN_W * 0.5 + 0.3 and q.z > -0.4 and q.z < wt + GAP + 0.38 and q.y > -0.5 and q.y < 2.5


func _physics_process(delta: float) -> void:
	# inside a car the player is in neither floor's zone (the copies would differ): the lift is its own place
	var now := -1
	for i in 2:
		if is_inside(i):
			now = i
	if now != _inside:
		var p := _player()
		if p:
			if now >= 0:
				p.zone_override = "lift"
			elif p.zone_override == "lift":
				p.zone_override = "servicehall" if _inside == 0 else ""
		_inside = now
	if doors_open and not busy:
		_idle += delta
		if _idle > IDLE_CLOSE and not _in_doorway(at):
			_idle = 0.0
			_close_idle()


func _close_idle() -> void:
	busy = true
	var ok := await _doors(at, false)
	busy = false
	if not ok:
		_idle = IDLE_CLOSE - 3.0


## The car standing at landing `i` with its doors open, at once (a story that starts as you step out of it).
func open_now(i: int) -> void:
	at = i
	_shown = floors[i]
	_display()
	var c := cars[i]
	for g: Array in [c.leaves, c.land_leaves]:
		for k in g.size():
			(g[k] as Node3D).position.x = (-1.0 if k == 0 else 1.0) * (LEAF_W * 0.5 + SLIDE)
	(c.block as StaticBody3D).collision_layer = 0
	doors_open = true
	_idle = 0.0


## Shuts the doors where the car stands (they reopen if someone is in the way).
func shut() -> void:
	if busy or not doors_open:
		return
	busy = true
	await _doors(at, false)
	busy = false


## The call button at landing `i`.
func _call(i: int) -> void:
	if locked:
		Snd.play_at("button_press", (cars[i].call as Node3D).global_position, -6.0, 0.95, 3.0)
		Snd.play_at("beep_error", (cars[i].call as Node3D).global_position, -14.0, 1.0, 3.0)
		return
	_lamp(cars[i].call_lamp, true)
	Snd.play_at("button_press", (cars[i].call as Node3D).global_position, -6.0, 1.05, 3.0)
	if busy:
		return
	if at == i:
		if not doors_open:
			busy = true
			await _doors(i, true)
			busy = false
		_lamp(cars[i].call_lamp, false)
		_idle = 0.0
		return
	busy = true
	await _run(i, false)
	busy = false


## The destination button inside: off to the other landing (with whoever is in the car).
func _go() -> void:
	var to := 1 - at
	var p := _player()
	Snd.play_at("button_press", (cars[at].go as Node3D).global_position, -6.0, 1.1, 3.0)
	if busy:
		return
	_go_lamps(floors[to], true)
	busy = true
	if doors_open and not await _doors(at, false):
		busy = false
		_go_lamps(floors[to], false)
		return
	await _run(to, p != null and is_inside(at))
	busy = false


func _open_pressed() -> void:
	Snd.play_at("button_press", (cars[at].open as Node3D).global_position, -6.0, 1.0, 3.0)
	if busy or doors_open:
		_idle = 0.0
		return
	busy = true
	await _doors(at, true)
	busy = false


## The car runs from where it stands to landing `to`, the floor displays counting; `with_player`: they are in it
## and are carried over halfway, while every door is shut.
func _run(to: int, with_player: bool) -> void:
	var from := at
	var f0 := floors[from]
	var f1 := floors[to]
	var step := 1 if f1 > f0 else -1
	var n := absi(f1 - f0)
	var arrow := "▲" if step > 0 else "▼"
	if with_player:
		Snd.play("lift_jolt", -6.0, 1.0, "SFX")
		_player().add_shake(0.08)
		var tw := create_tween()
		_motor.play()
		tw.tween_property(_motor, "volume_db", -10.0, 0.8)
	else:
		await get_tree().create_timer(0.6).timeout
	_display(arrow)
	for k in n:
		await get_tree().create_timer(FLOOR_TIME).timeout
		_shown = f0 + step * (k + 1)
		_display(arrow)
		if with_player and k == 0:
			var p := _player()
			if p and is_inside(from):
				Lift.carry(p, (cars[from].root as Node3D).global_transform, (cars[to].root as Node3D).global_transform)
				_inside = to
				carried.emit(to)
	at = to
	if with_player:
		var tw := create_tween()
		tw.tween_property(_motor, "volume_db", -60.0, 0.7)
		tw.tween_callback(_motor.stop)
		await get_tree().create_timer(0.5).timeout
		Snd.play("lift_jolt", -9.0, 0.9, "SFX")
		_player().add_shake(0.05)
		await get_tree().create_timer(0.4).timeout
	_display()
	_go_lamps(f1, false)
	_lamp(cars[to].call_lamp, false)
	Snd.play_at("lift_ding", (cars[to].land as Node3D).global_transform * Vector3(0, OPEN_H + 0.3, 0.2), -4.0, 1.0, 6.0)
	await get_tree().create_timer(0.35).timeout
	await _doors(to, true)


## Slides car `i`'s doors (its car door and its landing door together). Returns false when the doors were closing and
## someone stood in the way (they open again).
func _doors(i: int, open: bool) -> bool:
	for tw in _door_tw:
		if tw and tw.is_valid():
			tw.kill()
	_door_tw.clear()
	var c := cars[i]
	var at_pos := (c.land as Node3D).global_transform * Vector3(0, 1.2, 0)
	Snd.play_at("lift_door", at_pos, -5.0, 1.0 if open else 0.94, 5.0)
	var tw := create_tween().set_parallel(true)
	_door_tw.append(tw)
	var groups: Array = [c.leaves, c.land_leaves]
	for g: Array in groups:
		for k in g.size():
			var lf: Node3D = g[k]
			var sx := -1.0 if k == 0 else 1.0
			var x := sx * (LEAF_W * 0.5 + (SLIDE if open else 0.0))
			tw.tween_property(lf, "position:x", x, DOOR_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if open:
		(c.block as StaticBody3D).collision_layer = 0
		doors_open = true
		_idle = 0.0
		await tw.finished
		return true
	# closing: back open if anyone is in the doorway
	(c.block as StaticBody3D).collision_layer = 0
	var t := 0.0
	while t < DOOR_TIME:
		if _in_doorway(i):
			tw.kill()
			await _doors(i, true)
			return false
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	(c.block as StaticBody3D).collision_layer = Geo.LAYER_WORLD
	doors_open = false
	return true


func _display(arrow := "") -> void:
	for c: Dictionary in cars:
		for pair: Array in [c.lantern, c.display]:
			Geo.set_text(pair[0], str(_shown))
			Geo.set_text(pair[1], arrow)


func _go_lamps(f: int, on: bool) -> void:
	for c: Dictionary in cars:
		if c.go_lamps.has(f):
			_lamp(c.go_lamps[f], on)


static func _lamp(m: StandardMaterial3D, on: bool) -> void:
	m.emission_energy_multiplier = 2.2 if on else 0.0
	m.albedo_color = Color(0.9, 0.5, 0.3) if on else Color(0.8, 0.8, 0.77)
