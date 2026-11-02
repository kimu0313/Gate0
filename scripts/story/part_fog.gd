class_name PartFog
extends StoryPart
## A, the fog branch: nothing to fight. Through the airliner door at the west end of the lounge's south aisle, it shuts
## behind you and the cabin goes on and on (CabinWay.looping), row after row. After a long while one reading light is
## on over one seat: a boarding pass lying there, your name on it. Pick it up and the aisle lets you go, into the haze
## and out onto the aircraft hall's landing. Up its escalator, along the 2F deck, a pair of steel doors: past them you
## are standing in one of the lounge's empty 2F units.

const ENTRY_SOUND := "door_heavy"
const TURNS := 14                                 # how many times the aisle comes round before the light is on
const SEAT := Vector3(-22.26, 0.5, 18.7)          # the aisle seat in the row the light picks out (1.2 m short of LOOP_Z)
const DECK_DOOR := Vector3(-26.08, Terminal.MEZZ_Y, 26.0)   # in the hall's east wall, off its 2F deck
const OUT_AT := Vector3(-22.3, Terminal.MEZZ_Y + 0.05, 22.25)   # in unit w2, in front of the door you came out of

var taken := false
var _lamp: SpotLight3D
var _bulb: MeshInstance3D
var _pass: Node3D
var _use: Interactable
var _left := false


func setup() -> void:
	CabinWay.way.seal()
	_build_seat()
	var t := d.terminal
	var door := ServiceHall.double_door(t, Transform3D(Basis(Vector3.UP, -PI / 2), DECK_DOOR))
	(door.use as Interactable).prompt = "문 열기"
	(door.use as Interactable).callback = _leave_hall
	# and its other side, in the back wall of unit w2
	var back := ServiceHall.double_door(t, Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-23.42, Terminal.MEZZ_Y, OUT_AT.z)))
	(back.use as Interactable).enabled = false
	(back.use as Interactable).collision_layer = 0


func entry_pos() -> Vector3:
	return Vector3(-19.8, 1.2, CabinWay.DOOR_Z)


func open_entry() -> void:
	CabinWay.way.unseal()


func entered() -> bool:
	var q := d.player.global_position
	return q.y < 2.0 and q.x < -20.6 and q.x > -24.0 and q.z > CabinWay.DOOR_Z - 2.0 and q.z < CabinWay.DOOR_Z + 2.0


func run() -> void:
	var way := CabinWay.way
	way.turns = 0
	way.looping = true
	d.objective("앞으로 나아가기")
	await d.wait(1.0)
	way.seal()                                       # it shuts behind you
	Snd.play_at("door_slam", entry_pos(), -2.0, 1.0, 8.0)
	await d.until(func(): return way.turns >= TURNS)
	# somewhere ahead, one light has come on
	_lamp.visible = true
	_bulb.visible = true
	_pass.visible = true
	_use.enabled = true
	_use.collision_layer = Geo.LAYER_INTERACT
	Snd.play_at("button_press", SEAT + Vector3(0, 1.2, 0), -10.0, 0.8, 6.0)
	d.objective("독서등 켜진 좌석")
	await d.until(func(): return taken)
	way.looping = false
	d.objective("앞으로 나아가기")
	await d.until(func(): return d.player.global_position.x < -26.0)
	d.objective("문 열기")
	await d.until(func(): return _left)


func _build_seat() -> void:
	var t := d.terminal
	_lamp = SpotLight3D.new()
	t.add_child(_lamp)
	_lamp.position = Vector3(SEAT.x, 1.66, SEAT.z)
	_lamp.rotation.x = -PI / 2
	_lamp.light_color = Color(1.0, 0.9, 0.72)
	_lamp.light_energy = 7.0
	_lamp.spot_range = 3.0
	_lamp.spot_angle = 24.0
	_lamp.light_cull_mask = Airliner.VIS_CABIN
	_lamp.light_volumetric_fog_energy = 1.4
	_lamp.visible = false
	_bulb = Geo.box(t, Vector3(SEAT.x, 1.694, SEAT.z), Vector3(0.07, 0.008, 0.07), Mats.emissive(Color(1.0, 0.92, 0.75), 5.0), false)
	_bulb.layers = Airliner.VIS_CABIN
	_bulb.visible = false
	_pass = Node3D.new()
	_pass.name = "BoardingPass"
	t.add_child(_pass)
	_pass.position = SEAT
	_pass.rotation.y = 0.5
	var card := Geo.box(_pass, Vector3.ZERO, Vector3(0.09, 0.003, 0.2), Mats.get_mat("plastic_white"), false)
	card.layers = Airliner.VIS_CABIN
	var band := Geo.box(_pass, Vector3(0, 0.002, -0.07), Vector3(0.09, 0.001, 0.05), Mats.std(Color(0.12, 0.25, 0.65), 0.5), false)
	band.layers = Airliner.VIS_CABIN
	_pass.visible = false
	# (the seats' collider stands round the pass: the [E] box reaches out over the aisle)
	_use = Interactable.create(t, Vector3(-21.92, 0.75, SEAT.z), Vector3(0.3, 1.0, 0.7), "탑승권 줍기", _take)
	_use.press_sound = ""
	_use.enabled = false
	_use.collision_layer = 0


func _take() -> void:
	if taken:
		return
	taken = true
	Snd.play("page_flip", -6.0, 1.1)
	Game.add_item("boarding_pass")
	Events.notify.emit("탑승권 — FLIGHT 000 · GATE 0, 내 이름이 찍혀 있다.", "info")
	_pass.visible = false
	_use.enabled = false
	_use.collision_layer = 0
	_lamp.visible = false
	_bulb.visible = false


func _leave_hall() -> void:
	if _left:
		return
	Snd.play_at("door_heavy", DECK_DOOR + Vector3(-0.3, 1.0, 0), -2.0, 1.0, 7.0)
	await cut_to(OUT_AT, -PI / 2)
	Snd.play_at("door_slam", OUT_AT + Vector3(-1.0, 1.0, 0), -6.0, 1.0, 6.0)
	_left = true
