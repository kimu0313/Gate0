class_name PartBaggage
extends StoryPart
## C, the baggage branch: the one with something to fear. A roller shutter in the back of the storage room goes up and
## past it you are in baggage claim, B-03 turning, nobody there. Every bag on it has someone's tag; one has yours, a
## case you never checked. Now and then the belts stop dead and the hall goes quiet, and the sound of a tag being torn
## comes closer (TearStalker): get behind a pillar until it has gone by. The tag on your bag is torn across: take what
## is left. Then up onto the belt and through the rubber flaps, and it carries you out onto a belt that was not in the
## lounge before.

const ENTRY_SOUND := "shutter_roll"
const SHUTTER_AT := Vector3(21.72, 0.0, -5.5)     # in the storage room's east wall
const ARRIVE := Vector3(-18.0, 0.05, -62.4)       # by the arrivals exit doors, in baggage claim
const PILLARS := [Vector2(-22.5, -43.0), Vector2(-16.5, -43.0), Vector2(-22.5, -48.5), Vector2(-16.5, -48.5),
	Vector2(-21.0, -54.0), Vector2(-15.0, -54.0), Vector2(-15.0, -60.5), Vector2(-31.5, -62.9), Vector2(-27.0, -41.0)]
## Its rounds: either way along any of them, whichever starts furthest from you.
const ROUTES := [
	[Vector3(-11.0, 0.8, -49.0), Vector3(-19.5, 0.8, -46.0), Vector3(-19.5, 0.8, -62.5), Vector3(-34.5, 0.8, -62.5)],
	[Vector3(-34.5, 0.8, -55.5), Vector3(-19.0, 0.8, -55.5), Vector3(-19.5, 0.8, -41.0), Vector3(-11.0, 0.8, -41.0)],
]
const FIRST_ROUND := 13.0
const ROUND_EVERY := 24.0
const LOUNGE_BELT := Vector3(14.5, 0.0, -2.3)     # where the belt comes out of the lounge's north wall, running south
const BELT_LEN := 6.0

var stalker: TearStalker
var _shutter: Node3D
var _open := false
var _gate: Area3D
var _inside := false
var _got_tag := false
var _riding := false
var _ride_use: Interactable
var _lounge_belt: Node3D
var _belt: BaggageBelt
var _done := false
var _next_round := 0.0
var _busy := false


func setup() -> void:
	var t := d.terminal
	_belt = t.facilities.get("baggage")
	_build_shutter()
	_build_pillars()
	_build_lounge_belt()
	_build_ride()
	stalker = TearStalker.create(d.world, d.player, PILLARS)
	stalker.seen.connect(func(): ch.caught())
	(t.doors.storage as SlidingDoor).locked = true
	Events.player_action.connect(_on_action)


func entry_pos() -> Vector3:
	return SHUTTER_AT + Vector3(0, 1.2, 0)


func open_entry() -> void:
	_open = true
	var t := d.terminal
	(t.doors.storage as SlidingDoor).locked = false
	(t.zones.service as LightZone).night_dim = 0.5
	t.set_zone_light("service", true, true)
	var tw := create_tween()
	tw.tween_property(_shutter, "position:y", 2.2, 2.4).set_trans(Tween.TRANS_SINE)


func entered() -> bool:
	if not _open:
		return false
	var q := d.player.global_position
	return Vector2(q.x - SHUTTER_AT.x, q.z - SHUTTER_AT.z).length() < 1.4


func run() -> void:
	var t := d.terminal
	var z: LightZone = t.zones.baggage
	z.night_dim = 0.42
	z.erratic = 0.06
	z.set_on(true, true)
	Game.set_checkpoint("baggage")
	d.objective("내 가방 찾기")
	await cut_to(ARRIVE, PI)
	Snd.play_at("door_slam", ARRIVE + Vector3(0, 1.0, -1.2), -4.0, 1.0, 7.0)
	_inside = true
	_belts(true)
	_belt.bags.clear()
	_belt.spawn_queue.assign(["pax", "pax", "pax", "name", "pax", "pax", "pax"])
	_belt.spawn_timer = 0.6
	_next_round = FIRST_ROUND
	await d.until(func(): return _got_tag)
	d.objective("벨트에 올라타기")
	_ride_use.enabled = true
	_ride_use.collision_layer = Geo.LAYER_INTERACT
	await d.until(func(): return _done)
	_inside = false
	stalker.stop()
	Snd.set_tension(0.0)


func _physics_process(delta: float) -> void:
	if not _inside or _riding or _busy:
		return
	_next_round -= delta
	if _next_round <= 0.0:
		_round()


## A round: the belts stop, quiet; then it comes through, and goes; the belts start again.
func _round() -> void:
	_busy = true
	_belts(false)
	Snd.set_tension(0.45)
	await d.wait(2.0)
	if _inside:
		await stalker.walk(_far_route())
	Snd.set_tension(0.0)
	if _inside and not d.dead:
		_belts(true)
	_next_round = ROUND_EVERY
	_busy = false


func _belts(on: bool) -> void:
	if on:
		_belt.start(false)
	else:
		_belt.stop()
		Snd.play_at("power_down", _belt.global_position + Vector3(0, 1.0, 0), -6.0, 1.0, 12.0, 60.0)


func _far_route() -> Array:
	var at := d.player.global_position
	var best: Array = ROUTES[0]
	var far := -1.0
	for r: Array in ROUTES:
		var back := r.duplicate()
		back.reverse()
		for way: Array in [r, back]:
			var dist := at.distance_to(way[0])
			if dist > far:
				far = dist
				best = way
	return best


func _on_action(action: String, target: String) -> void:
	if action != "touch_bag" or not _inside:
		return
	if target == "name" and not _got_tag:
		_got_tag = true
		Snd.play("page_flip", -6.0, 0.8)
		Game.add_item("bag_tag")
		Events.notify.emit("수하물표 — 내 이름이 적혀 있다. 맡긴 적 없는 가방이다. 한쪽이 찢겨 있다.", "info")
	elif target == "pax":
		Events.notify.emit("모르는 사람의 이름표다.", "info")


## The steel shutter across the opening in the storage room's east wall; it rolls up on the word.
func _build_shutter() -> void:
	var t := d.terminal
	var root := Node3D.new()
	root.name = "StorageShutter"
	t.add_child(root)
	root.position = SHUTTER_AT
	Geo.box(root, Vector3(0.2, 1.3, 0), Vector3(0.05, 2.6, 2.6), Mats.get_mat("void"), false)
	_shutter = Node3D.new()
	root.add_child(_shutter)
	var steel := Mats.std(Color(0.42, 0.44, 0.45), 0.55, 0.5)
	for i in 12:
		Geo.box(_shutter, Vector3(0.12, 0.1 + i * 0.2, 0), Vector3(0.05, 0.18, 2.4), steel, false)
	for s in [-1.0, 1.0]:
		Geo.box(root, Vector3(0.1, 1.3, s * 1.25), Vector3(0.14, 2.6, 0.1), Mats.get_mat("metal_dark"), false)
	Geo.box(root, Vector3(0.1, 2.5, 0), Vector3(0.3, 0.2, 2.6), Mats.get_mat("metal_dark"), false)


func _build_pillars() -> void:
	var t := d.terminal
	var stripe := Mats.std(Color(0.5, 0.45, 0.2), 0.6)
	for p: Vector2 in PILLARS:
		Geo.box(t, Vector3(p.x, Terminal.BAG_H * 0.5, p.y), Vector3(1.5, Terminal.BAG_H, 1.5), Mats.get_mat("column"))
		Geo.box(t, Vector3(p.x, 1.2, p.y), Vector3(1.52, 0.12, 1.52), stripe, false)


## [E] on B-03's rubber flaps, up on the belt once you have your tag.
func _build_ride() -> void:
	var hatch := _belt.global_position + Vector3(_belt.half + _belt.radius - 0.2, 1.1, 0)
	_ride_use = Interactable.create(d.terminal, hatch, Vector3(1.0, 1.4, 1.8), "벨트에 올라타기", _ride)
	_ride_use.press_sound = ""
	_ride_use.enabled = false
	_ride_use.collision_layer = 0


## Up on the belt and into the flaps: dark; then you come out of the wall on a belt in the lounge.
func _ride() -> void:
	if _riding:
		return
	_riding = true
	stalker.stop()
	_ride_use.enabled = false
	var p := d.player
	d.cutscene(true)
	Snd.play_at("luggage_thump", _belt.global_position, -2.0, 0.8, 6.0)
	await d.ui.fade_to(1.0, 0.8)
	_lounge_belt.visible = true
	(_lounge_belt.get_meta("block") as StaticBody3D).collision_layer = Geo.LAYER_WORLD
	stand(LOUNGE_BELT + Vector3(0, 0.2, 0.5), PI)
	await d.wait(0.6)
	p.walk_path([LOUNGE_BELT + Vector3(0, 0.2, BELT_LEN - 0.4), LOUNGE_BELT + Vector3(0, 0.05, BELT_LEN + 1.0)], 1.3)
	Snd.play_at("belt_loop", LOUNGE_BELT + Vector3(0, 0.5, 2.0), 0.0, 1.0, 8.0)
	await d.ui.fade_to(0.0, 1.0)
	await d.until(func(): return not p.walking())
	d.cutscene(false)
	_done = true


func _build_lounge_belt() -> void:
	var t := d.terminal
	var root := Node3D.new()
	root.name = "LoungeBelt"
	t.add_child(root)
	root.position = LOUNGE_BELT
	var steel := Mats.get_mat("metal_dark")
	var rubber := Mats.std(Color(0.06, 0.06, 0.065), 0.8)
	Geo.box(root, Vector3(0, 0.07, BELT_LEN * 0.5), Vector3(1.5, 0.14, BELT_LEN), steel, false)
	Geo.box(root, Vector3(0, 0.15, BELT_LEN * 0.5), Vector3(1.2, 0.02, BELT_LEN), rubber, false)
	for s in [-1.0, 1.0]:
		Geo.box(root, Vector3(s * 0.72, 0.28, BELT_LEN * 0.5), Vector3(0.06, 0.4, BELT_LEN), steel, false)
	Geo.box(root, Vector3(0, 1.3, 0.02), Vector3(1.8, 2.6, 0.04), Mats.get_mat("void"), false)
	for i in 7:
		Geo.box(root, Vector3(-0.54 + i * 0.18, 1.1, 0.06), Vector3(0.16, 2.0, 0.02), Mats.get_mat("rubber"), false)
	var block := Geo.blocker(root, Vector3(0, 0.07, BELT_LEN * 0.5), Vector3(1.5, 0.14, BELT_LEN))
	block.collision_layer = 0
	root.set_meta("block", block)
	root.visible = false
	_lounge_belt = root
