class_name PowerRoom
extends Node3D
## The power room (전력실) off the east corridor E, behind what was its 전기실 door (user, 2026-11-08: "플레이어가 엘베
## 버튼을 누르면 … 엘리베이터 전력이 꺼진 듯 하다. 전력실에서 확인을 해 봐야겠다 … '전력실 찾기' '엘리베이터 전력
## 작동 시키기'"). A small switchgear room: three floor-standing cabinets on the far wall facing the door — the middle
## one, straight ahead as the door opens, is the lift's power panel (승강기 동력반) with its operating handle, a red
## 정지 and a green 운전 lamp — a distribution board and a danger sign on the north wall, a ladder cable tray along the
## top with conduits down into the cabinets, a rubber mat and a yellow line on the painted floor, one batten.
##
## Built by ServiceHall in its own space (the terminal's coordinates) east of E's east wall, where nothing else stands.
## The door opens ([E] 문 열기 / 문 닫기) into the room and stays as left (ArchiveRoom.set_open); a plate over it on
## the corridor side reads 전력실. Everything inside is on Geo.VIS_SEALED with its own lights, like the records room.
## The lift panel: on by default (the handle up, 운전 lit, the cabinets humming); a story turns it off (set_on(false))
## and [E] 승강기 전원 올리기 on the handle throws it back up — switched_on, which the Terminal passes to the lift
## (Lift.set_powered).

signal door_opened                # its door opened (first or any time)
signal switched_on                # the lift panel's handle thrown up

const ROOM := Rect2(-9.85, -14.5, 3.4, 3.8)     # x, z: east of E's east wall (its corridor face x -10.05)
const HT := 2.9
const DOOR_Z := -12.6                          # the door, in E's east wall (ServiceHall builds it)
const WALL_X := -10.05                         # that wall's corridor face
const CAB_Z := [-13.55, -12.6, -11.65]         # the three cabinets along the east wall; the middle one is the lift's
const CAB_W := 0.9
const CAB_H := 2.0
const CAB_D := 0.5
const LAMP := Color(0.92, 0.97, 0.94)
const ON_ANGLE := 0.5                          # the handle: up (on) / down (off), about its pivot's X
const OFF_ANGLE := PI - 0.5

var on := true
var door: Dictionary
var lever_use: Interactable
var _lever: Node3D
var _lamp_red: StandardMaterial3D
var _lamp_green: StandardMaterial3D
var _hum: AudioStreamPlayer3D


static func build(hall: ServiceHall) -> PowerRoom:
	var r := PowerRoom.new()
	r.name = "PowerRoom"
	hall.add_child(r)
	r._shell()
	r._cabinets()
	r._fittings()
	r._lights()
	Geo.seal(r)
	r._door(hall)
	r.set_on(true, true)
	return r


static func contains_local(l: Vector3) -> bool:
	return ROOM.grow(0.05).has_point(Vector2(l.x, l.z)) and l.y > -1.0 and l.y < HT + 1.0


## The lift panel on or off; `quiet`: at once, no sound (the story's starting state).
func set_on(value: bool, quiet := false) -> void:
	on = value
	if lever_use:
		lever_use.enabled = not value
	var want := ON_ANGLE if value else OFF_ANGLE
	if quiet or not is_inside_tree():
		_lever.rotation.x = want
	else:
		var tw := _lever.create_tween()
		tw.tween_property(_lever, "rotation:x", want, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lamp(_lamp_green, value)
	_lamp(_lamp_red, not value)
	if _hum:
		if value and is_inside_tree():
			if not _hum.playing:
				_hum.play()
		else:
			_hum.autoplay = value
			_hum.stop()


func _throw() -> void:
	if on:
		return
	var at := _lever.global_position
	Snd.play_at("switch_heavy", at, -4.0, 0.95, 4.0)
	set_on(true)
	await get_tree().create_timer(0.35).timeout
	Snd.play_at("power_up", at + Vector3(0, 0.6, 0), -10.0, 1.0, 5.0)
	switched_on.emit()


static func _lamp(m: StandardMaterial3D, lit: bool) -> void:
	m.emission_energy_multiplier = 2.6 if lit else 0.0


# --------------------------------------------------------------------------------------------
## Floor (grey-green painted, 4 mm over the corridors' floor where they meet), pale painted walls over a dark dado,
## a plain ceiling; the corridor's wall lined on this side round the door.
func _shell() -> void:
	var x0 := ROOM.position.x
	var x1 := ROOM.end.x
	var z0 := ROOM.position.y
	var z1 := ROOM.end.y
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var floor_m := Mats.std(Color(0.3, 0.34, 0.31), 0.55)
	var paint := Mats.std(Color(0.6, 0.63, 0.59), 0.9)
	var dado := Mats.std(Color(0.22, 0.28, 0.26), 0.6)
	var ceil_m := Mats.std(Color(0.62, 0.63, 0.61), 0.92)
	var skirt := Mats.std(Color(0.12, 0.12, 0.11), 0.6)
	Geo.box(self, Vector3(cx, -0.046, cz), Vector3(x1 - x0, 0.1, z1 - z0), floor_m)
	Geo.box(self, Vector3(cx, HT + 0.05, cz), Vector3(x1 - x0 + 0.4, 0.1, z1 - z0 + 0.4), ceil_m, false)
	Geo.box(self, Vector3(x1 + 0.1, HT * 0.5, cz), Vector3(0.2, HT, z1 - z0 + 0.4), paint)
	Geo.box(self, Vector3(cx, HT * 0.5, z0 - 0.1), Vector3(x1 - x0, HT, 0.2), paint)
	Geo.box(self, Vector3(cx, HT * 0.5, z1 + 0.1), Vector3(x1 - x0, HT, 0.2), paint)
	# the corridor's wall (x -10.05..-9.85) lined on this side round the door
	var dl := DOOR_Z - 0.475 - 0.025
	var dr := DOOR_Z + 0.475 + 0.025
	Geo.box(self, Vector3(x0 + 0.006, HT * 0.5, (z0 + dl) * 0.5), Vector3(0.012, HT, dl - z0), paint, false)
	Geo.box(self, Vector3(x0 + 0.006, HT * 0.5, (dr + z1) * 0.5), Vector3(0.012, HT, z1 - dr), paint, false)
	Geo.box(self, Vector3(x0 + 0.006, (2.155 + HT) * 0.5, DOOR_Z), Vector3(0.012, HT - 2.155, dr - dl), paint, false)
	# the dado (1.1 m) and skirting round every wall but across the door
	var walls := [[Vector3(x1 - 0.004, 0, cz), Vector3(0.008, 0, z1 - z0)], [Vector3(cx, 0, z0 + 0.004), Vector3(x1 - x0, 0, 0.008)],
		[Vector3(cx, 0, z1 - 0.004), Vector3(x1 - x0, 0, 0.008)],
		[Vector3(x0 + 0.016, 0, (z0 + dl) * 0.5), Vector3(0.008, 0, dl - z0)], [Vector3(x0 + 0.016, 0, (dr + z1) * 0.5), Vector3(0.008, 0, z1 - dr)]]
	for w: Array in walls:
		var p: Vector3 = w[0]
		var s: Vector3 = w[1]
		Geo.box(self, p + Vector3(0, 0.55, 0), s + Vector3(0, 1.1, 0), dado, false)
		Geo.box(self, p + Vector3(0, 0.05, 0), (s + Vector3(0, 0.1, 0)) * Vector3(1.6 if s.x < 0.1 else 1.0, 1.0, 1.6 if s.z < 0.1 else 1.0), skirt, false)
	# a yellow line on the floor in front of the cabinets, and the black rubber mat inside it
	var line_x := x1 - CAB_D - 1.0
	Geo.box(self, Vector3(line_x, 0.0055, cz), Vector3(0.06, 0.003, z1 - z0 - 0.3), Mats.std(Color(0.85, 0.66, 0.08), 0.6), false)
	Geo.box(self, Vector3(x1 - CAB_D - 0.47, 0.009, cz), Vector3(0.86, 0.01, 2.9), Mats.std(Color(0.035, 0.035, 0.035), 0.85), false)


# --------------------------------------------------------------------------------------------
## The three cabinets on the east wall, each in its own frame (+Z out into the room): the middle one the lift's.
func _cabinets() -> void:
	var names := [["저압반  LV-4", "LOW VOLTAGE PANEL"], ["승강기 동력반", "ELEV. POWER  EL-1"], ["동력반  MCC-4", "MOTOR CONTROL"]]
	for i in 3:
		var h := Node3D.new()
		add_child(h)
		h.position = Vector3(ROOM.end.x, 0, CAB_Z[i])
		h.rotation.y = -PI / 2
		_cabinet(h, names[i], i == 1)


func _cabinet(h: Node3D, plate: Array, lift: bool) -> void:
	var body := _steel()
	var dark := Mats.std(Color(0.08, 0.085, 0.09), 0.55)
	var chrome := Mats.std(Color(0.7, 0.71, 0.7), 0.3, 0.6)
	var w := CAB_W - 0.02
	var front := CAB_D
	Geo.box(h, Vector3(0, CAB_H * 0.5 + 0.05, CAB_D * 0.5), Vector3(w, CAB_H - 0.1, CAB_D), body, false)
	Geo.box(h, Vector3(0, 0.05, CAB_D * 0.5 - 0.02), Vector3(w - 0.02, 0.1, CAB_D - 0.04), dark, false)        # plinth
	# two doors: seams round them and between them, a handle on each
	for s: float in [-1.0, 1.0]:
		Geo.box(h, Vector3(s * (w * 0.5 - 0.035), 1.05, front + 0.002), Vector3(0.004, 1.84, 0.004), dark, false)
	Geo.box(h, Vector3(0, 1.05, front + 0.002), Vector3(0.004, 1.84, 0.004), dark, false)
	for y: float in [0.13, 1.97]:
		Geo.box(h, Vector3(0, y, front + 0.002), Vector3(w - 0.07, 0.004, 0.004), dark, false)
	for s: float in [-1.0, 1.0]:
		Geo.box(h, Vector3(s * 0.06, 1.0, front + 0.025), Vector3(0.025, 0.14, 0.03), chrome, false)
		Geo.box(h, Vector3(s * 0.06, 1.0, front + 0.008), Vector3(0.04, 0.17, 0.012), dark, false)
		# louvres low on each door
		for k in 5:
			var lv := Geo.box(h, Vector3(s * w * 0.25, 0.28 + k * 0.045, front + 0.006), Vector3(w * 0.36, 0.012, 0.012), dark, false)
			lv.rotation.x = 0.5
	Geo.blocker(h, Vector3(0, CAB_H * 0.5, CAB_D * 0.5), Vector3(CAB_W, CAB_H, CAB_D))
	# name plate high on the left door (two lines), a meter on the right
	Equipment._plate(h, "%s\n%s" % plate, Vector3(-w * 0.22, 1.78, front + 0.014), Vector2(0.3, 0.12), "plate_white", Color(0.1, 0.11, 0.13), 30)
	var meter := Node3D.new()
	h.add_child(meter)
	meter.position = Vector3(w * 0.25, 1.74, front)
	Geo.box(meter, Vector3(0, 0, 0.012), Vector3(0.13, 0.13, 0.024), dark, false)
	var face := Geo.cyl(meter, Vector3(0, 0, 0.025), 0.05, 0.004, Mats.std(Color(0.9, 0.89, 0.84), 0.5))
	face.rotation.x = PI / 2
	var needle := Geo.box(meter, Vector3(0, 0, 0.028), Vector3(0.003, 0.05, 0.002), Mats.std(Color(0.1, 0.1, 0.1), 0.5), false)
	needle.rotation.z = randf_range(-0.6, 0.6) if not lift else 0.9
	if not lift:
		# pilot lamps (lit: these boards have power)
		for k in 2:
			var l := Geo.cyl(h, Vector3(w * 0.25 - 0.04 + k * 0.08, 1.5, front + 0.012), 0.018, 0.014,
				Mats.emissive(Color(0.25, 0.95, 0.35) if k == 0 else Color(1.0, 0.75, 0.2), 1.6 if k == 0 else 0.0, Color(0.3, 0.4, 0.3)))
			l.rotation.x = PI / 2
		return
	# the lift's panel: a warning sticker, the 정지 / 운전 lamps, the operating handle in its escutcheon
	Equipment._plate(h, "4F–1F 승강기 #1", Vector3(-w * 0.25, 1.6, front + 0.014), Vector2(0.3, 0.06), "sticker_yellow", Color(0.08, 0.07, 0.05), 26)
	_lamp_red = Mats.emissive(Color(1.0, 0.18, 0.12), 0.0, Color(0.45, 0.1, 0.08))
	_lamp_green = Mats.emissive(Color(0.25, 1.0, 0.4), 0.0, Color(0.12, 0.38, 0.16))
	for k in 2:
		var x := w * 0.25 - 0.05 + k * 0.1
		var lamp := Geo.cyl(h, Vector3(x, 1.52, front + 0.014), 0.02, 0.016, _lamp_red if k == 0 else _lamp_green)
		lamp.rotation.x = PI / 2
		var bezel := Geo.cyl(h, Vector3(x, 1.52, front + 0.006), 0.028, 0.008, dark)
		bezel.rotation.x = PI / 2
		Equipment._plate(h, "정지" if k == 0 else "운전", Vector3(x, 1.455, front + 0.014), Vector2(0.075, 0.032), "plate_white", Color(0.1, 0.11, 0.13), 22)
	var esc := Vector3(w * 0.25, 1.15, front)
	Equipment._plate(h, "ON", esc + Vector3(0, 0.24, 0.014), Vector2(0.08, 0.04), "plate_white", Color(0.1, 0.11, 0.13), 22)
	Equipment._plate(h, "OFF", esc + Vector3(0, -0.24, 0.014), Vector2(0.08, 0.04), "plate_white", Color(0.1, 0.11, 0.13), 22)
	Geo.box(h, esc + Vector3(0, 0, 0.01), Vector3(0.1, 0.38, 0.02), dark, false)
	Geo.box(h, esc + Vector3(0, 0, 0.021), Vector3(0.016, 0.3, 0.003), Mats.std(Color(0.02, 0.02, 0.02), 0.5), false)   # slot
	var hub := Geo.cyl(h, esc + Vector3(0, 0, 0.035), 0.032, 0.03, chrome)
	hub.rotation.x = PI / 2
	_lever = Node3D.new()
	_lever.name = "Lever"
	h.add_child(_lever)
	_lever.position = esc + Vector3(0, 0, 0.05)
	Geo.box(_lever, Vector3(0, 0.1, 0), Vector3(0.026, 0.2, 0.026), chrome, false)
	Geo.box(_lever, Vector3(0, 0.22, 0), Vector3(0.042, 0.09, 0.05), Mats.std(Color(0.72, 0.07, 0.05), 0.45), false)
	lever_use = Interactable.create(h, esc + Vector3(0, 0, 0.16), Vector3(0.36, 0.6, 0.28), "승강기 전원 올리기", Callable())
	lever_use.press_sound = ""
	lever_use.callback = _throw
	_hum = Snd.make_loop("machine_hum_loop", h, -24.0, 2.0, 12.0)
	_hum.position = Vector3(0, 1.4, CAB_D)


## The cabinets' paint: worn grey-green switchgear enamel (weathered.gdshader in each mesh's own space — its world
## noise shows blocks at the corridors' far-off coordinates).
static func _steel() -> Material:
	return Mats.shader_mat("res://shaders/weathered.gdshader", {
		"base_color": Color(0.55, 0.59, 0.56), "rust_color": Color(0.32, 0.23, 0.15), "grime_color": Color(0.3, 0.32, 0.31),
		"metallic": 0.1, "roughness": 0.55, "rust": 0.04, "grime": 0.3, "scale": 4.0, "scratches": 0.6, "runs": 0.5,
		"scratch_color": Color(0.7, 0.72, 0.7), "local_space": true})


# --------------------------------------------------------------------------------------------
## The distribution board and the danger sign on the north wall, the cable tray and conduits, an extinguisher.
func _fittings() -> void:
	var x1 := ROOM.end.x
	var z0 := ROOM.position.y
	var z1 := ROOM.end.y
	var steel := Mats.std(Color(0.5, 0.52, 0.52), 0.5, 0.2)
	var conduit := Mats.std(Color(0.55, 0.56, 0.55), 0.45, 0.3)
	# the distribution board (분전반), wall-mounted, its frame +Z into the room
	var db := Node3D.new()
	add_child(db)
	db.position = Vector3(-8.45, 1.45, z0)
	Geo.box(db, Vector3(0, 0, 0.075), Vector3(0.6, 0.8, 0.15), _steel(), false)
	Geo.box(db, Vector3(0, 0, 0.152), Vector3(0.54, 0.74, 0.004), Mats.std(Color(0.08, 0.085, 0.09), 0.55), false)
	Geo.box(db, Vector3(0, 0, 0.155), Vector3(0.53, 0.73, 0.004), _steel(), false)
	Geo.box(db, Vector3(0.22, 0, 0.17), Vector3(0.02, 0.1, 0.025), Mats.std(Color(0.7, 0.71, 0.7), 0.3, 0.6), false)
	Equipment._plate(db, "분전반  DP-4F", Vector3(0, 0.3, 0.171), Vector2(0.3, 0.06), "plate_white", Color(0.1, 0.11, 0.13), 26)
	Geo.cyl(db, Vector3(-0.15, 0.4 + (HT - 1.85) * 0.5, 0.06), 0.022, HT - 1.85, conduit)
	Geo.cyl(db, Vector3(0.1, 0.4 + (HT - 1.85) * 0.5, 0.06), 0.016, HT - 1.85, conduit)
	var sign := Node3D.new()
	add_child(sign)
	sign.position = Vector3(-7.55, 1.62, z0)
	Equipment._plate(sign, "고압 위험\nDANGER", Vector3(0, 0, 0.016), Vector2(0.3, 0.2), "sticker_red", Color(1, 1, 1), 34)
	# a ladder cable tray along the east wall's top, a conduit from it down into each cabinet
	var tx := x1 - 0.3
	var ty := HT - 0.3
	for s: float in [-1.0, 1.0]:
		Geo.box(self, Vector3(tx + s * 0.15, ty, (z0 + z1) * 0.5), Vector3(0.012, 0.07, z1 - z0), steel, false)
	var n := int((z1 - z0) / 0.3)
	for k in n:
		Geo.box(self, Vector3(tx, ty - 0.03, z0 + 0.15 + k * 0.3), Vector3(0.3, 0.012, 0.03), steel, false)
	for k in 6:
		Geo.box(self, Vector3(tx - 0.1 + k * 0.04, ty - 0.005, (z0 + z1) * 0.5), Vector3(0.028, 0.03, z1 - z0 - 0.05), Mats.std(Color(0.06, 0.06, 0.06), 0.7), false)
	for z: float in CAB_Z:
		Geo.cyl(self, Vector3(x1 - 0.25, (CAB_H + ty) * 0.5, z), 0.03, ty - CAB_H, conduit)
	# hangers for the tray from the ceiling
	for z: float in [z0 + 0.5, z1 - 0.5]:
		Geo.box(self, Vector3(tx, (ty + HT) * 0.5, z), Vector3(0.012, HT - ty, 0.012), steel, false)
	# a fire extinguisher in the south-west corner (clear of the door's swing)
	var ext := Node3D.new()
	add_child(ext)
	ext.position = Vector3(ROOM.position.x + 0.22, 0.0, z1 - 0.22)
	Geo.cyl(ext, Vector3(0, 0.3, 0), 0.08, 0.5, Mats.std(Color(0.7, 0.08, 0.06), 0.4))
	Geo.cyl(ext, Vector3(0, 0.6, 0), 0.025, 0.1, Mats.get_mat("metal_dark"))
	Geo.blocker(ext, Vector3(0, 0.33, 0), Vector3(0.18, 0.66, 0.18))


## One batten across the middle (its tubes lit), a lamp under it, a dim fill; a little haze; a small room's sound.
func _lights() -> void:
	var cx := ROOM.get_center().x
	var cz := ROOM.get_center().y
	var tube := Mats.emissive(LAMP, 2.2, Color(0.85, 0.88, 0.86))
	OfficeKit.batten(self, Vector3(cx, HT, cz), false, tube)
	var l := Geo.omni(self, Vector3(cx, HT - 0.45, cz), LAMP, 1.25, 6.0)
	l.light_volumetric_fog_energy = 0.6
	var f := Geo.omni(self, Vector3(cx + 0.6, 0.9, cz), LAMP, 0.22, 4.0)
	f.light_specular = 0.0
	f.light_volumetric_fog_energy = 0.0
	var fm := FogMaterial.new()
	fm.density = 0.035
	fm.albedo = Color(0.55, 0.6, 0.57)
	fm.edge_fade = 0.1
	var fog := FogVolume.new()
	fog.size = Vector3(ROOM.size.x, HT, ROOM.size.y)
	fog.material = fm
	add_child(fog)
	fog.position = Vector3(cx, HT * 0.5, cz)
	Lift._reverb(self, Vector3(cx, HT * 0.5, cz), Vector3(ROOM.size.x, HT, ROOM.size.y), "RevTight", 0.28)


# --------------------------------------------------------------------------------------------
## Its door (the corridor's steel door in E's east wall): opens into the room and stays as you leave it; a plate over
## it on the corridor side.
func _door(hall: ServiceHall) -> void:
	door = hall.doors_by["전력실"]
	hall.side_doors.erase(door)
	for v: VisualInstance3D in (door.root as Node).find_children("*", "VisualInstance3D", true, false):
		v.layers |= Geo.VIS_SEALED
	door["open"] = false
	var use := door.use as Interactable
	use.prompt = "문 열기"
	use.callback = func():
		var opening: bool = not door.open
		ArchiveRoom.set_open(door, opening)
		if opening and door.open:
			door_opened.emit()
	# its name over the door, like the records room's (the only two named doors out there)
	var plate := Geo.box(hall, Vector3(WALL_X - 0.008, 2.44, DOOR_Z), Vector3(0.016, 0.17, 0.62), Mats.std(Color(0.13, 0.14, 0.15), 0.4, 0.3), false)
	Geo.box(hall, Vector3(WALL_X, 2.44, DOOR_Z), Vector3(0.004, 0.19, 0.64), Mats.std(Color(0.55, 0.57, 0.57), 0.35, 0.6), false)
	Geo.fit(Geo.label(plate, "전력실", Vector3(-0.0085, 0, 0), -PI / 2, 96, Color(0.93, 0.93, 0.9), 0.0016, false, "sign"), 0.5, 0.12)
