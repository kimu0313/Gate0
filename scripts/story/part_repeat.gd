class_name PartRepeat
extends StoryPart
## B, the repeat branch. A door in the back of a 2F unit booms open. Past it: a room with a desk, and a door on the far
## side that will not open until you have done the one thing the room wants (a wall switch, or a drawer of the desk).
## Through it: the same room. A light has gone, a bag has appeared, and the staff badge on the desk is less and less
## yours. In the last room the badge reads PASSENGER and the identity card lies by it; its door lets you out through a
## door in the lounge's 1F east wall. No puzzle to solve and nothing to fear: you walk, do the small thing, walk on.

const ENTRY_SOUND := "door_heavy"
const ROOMS := 5
## What each room wants: [kind, index] (switch = which of RepeatRoom.switches, drawer = any of the desk's).
const TASKS := [["switch", 0], ["drawer", 0], ["switch", 1], ["drawer", 2], ["card", 0]]
const OUT_DOOR := Vector3(43.78, 0.0, 20.0)      # in the lounge's 1F east wall
const SHOP_DOOR_Z := -5.44                       # in unit e2's frame: its back wall

var room: RepeatRoom
var _shop: Dictionary                            # the double door in the unit's back wall
var _k := 0
var _unlocked := false
var _done := false
var _got_card := false
var _in_vestibule := false
var _card_use: Interactable
var _open := false


func setup() -> void:
	var t := d.terminal
	room = RepeatRoom.new()
	d.world.add_child(room)
	room.build(t)
	# the way in, in the back wall of unit e2 (black behind it once it stands open)
	var frame := Shops.frame(Shops.UNITS[6])
	_shop = ServiceHall.double_door(t, frame * Transform3D(Basis(), Vector3(0, 0, SHOP_DOOR_Z)))
	(_shop.use as Interactable).enabled = false
	(_shop.use as Interactable).collision_layer = 0
	(_shop.block as StaticBody3D).collision_layer = 0
	Geo.box(t, frame * Vector3(0, 1.15, SHOP_DOOR_Z - 0.03), Vector3(0.01, 2.3, 1.7), Mats.get_mat("void"), false)
	var out := ServiceHall.double_door(t, Transform3D(Basis(Vector3.UP, -PI / 2), OUT_DOOR))
	(out.use as Interactable).enabled = false
	(out.use as Interactable).collision_layer = 0
	for i in room.switch_uses.size():
		room.switch_uses[i].callback = _switch.bind(i)
	for i in room.desk_drawers.size():
		room.desk_drawers[i].toggled.connect(_drawer.bind(i))
	room.exit_door.use.callback = func(): if not _unlocked: t.rattle(room.exit_door)
	room.entry.use.enabled = false
	_card_use = Interactable.create(room.card_node, Vector3(0.0, 0.14, 0.0), Vector3(0.5, 0.4, 0.5), "신원 카드 줍기", _take_card)
	_card_use.press_sound = ""
	_card_use.enabled = false
	_card_use.collision_layer = 0
	room.beyond.body_entered.connect(func(body):
		if body == d.player and _unlocked:
			_through.call_deferred())


func entry_pos() -> Vector3:
	return Shops.frame(Shops.UNITS[6]) * Vector3(0, 1.2, SHOP_DOOR_Z)


func open_entry() -> void:
	_open = true
	ServiceHall.swing(_shop, 82.0, 0.5)


func entered() -> bool:
	if not _open:
		return false
	var q := d.player.global_position
	var at := entry_pos()
	return q.y > 3.0 and Vector2(q.x - at.x, q.z - at.z).length() < 2.0


func run() -> void:
	d.objective("앞으로 나아가기")
	Game.set_flag("in_repeat")
	await d.ui.fade_to(1.0, 0.4)
	_k = 0
	_start_room()
	stand(room.to_global(Vector3(0, 0.05, 0.7)), 0.0)
	room.entry.leaf.rotation.y = deg_to_rad(84.0)
	(room.entry.block as StaticBody3D).collision_layer = 0
	await d.wait(0.2)
	await d.ui.fade_to(0.0, 0.5)
	await d.until(func(): return _done)


func _start_room() -> void:
	var t := d.terminal
	_unlocked = false
	room.dress(_k, Game.player_name)
	var task: Array = TASKS[_k]
	for i in room.switches.size():
		var on: bool = task[0] == "switch" and task[1] == i
		room.switches[i].visible = on
		room.switch_uses[i].enabled = on
		room.switch_uses[i].collision_layer = Geo.LAYER_INTERACT if on else 0
	for dr: Drawer in room.desk_drawers:
		if dr.is_open:
			dr.interactable.interact()
	room.card_node.visible = task[0] == "card"
	_card_use.enabled = task[0] == "card"
	_card_use.collision_layer = Geo.LAYER_INTERACT if task[0] == "card" else 0
	room.exit_door.leaf.rotation.y = 0.0
	(room.exit_door.block as StaticBody3D).collision_layer = Geo.LAYER_WORLD
	d.objective("문 열기")
	# the door behind you shuts once you are in the room
	_shut_behind()
	t.set_zone_light("shops", true, true)


func _shut_behind() -> void:
	var at := _k
	await d.until(func(): return at != _k or room.to_local(d.player.global_position).z < -1.2)
	if at == _k:
		d.terminal.swing_door(room.entry, 0.0, 0.5)
		Snd.play_at("door_heavy", room.to_global(Vector3(0, 1.0, 0)), -10.0, 1.1, 5.0)


func _unlock() -> void:
	if _unlocked:
		return
	_unlocked = true
	Snd.play_at("lock_click", room.to_global(Vector3(0, 1.0, RepeatRoom.DOOR_Z)), -2.0, 1.0, 6.0)
	await d.wait(0.4)
	d.terminal.swing_door(room.exit_door, 84.0, 0.9)
	Snd.play_at("door_heavy", room.to_global(Vector3(0, 1.0, RepeatRoom.DOOR_Z)), -8.0, 1.0, 5.0)
	d.objective("다음 방으로")


func _switch(i: int) -> void:
	var task: Array = TASKS[_k]
	if task[0] == "switch" and task[1] == i:
		Snd.play_at("switch_heavy", room.switches[i].global_position, -6.0, 1.2, 5.0)
		_unlock()


func _drawer(_dr: Drawer, i: int) -> void:
	var task: Array = TASKS[_k]
	if task[0] == "drawer" and room.desk_drawers[i].is_open:          # any of them: it is the looking that counts
		_unlock()


func _take_card() -> void:
	if _got_card:
		return
	_got_card = true
	Snd.play("card_pickup", -4.0)
	Game.add_item("id_card")
	Events.notify.emit("신원 카드 — 사진은 나인데, 직함이 승객으로 되어 있다.", "info")
	room.card_node.visible = false
	_card_use.enabled = false
	_card_use.collision_layer = 0
	_unlock()


## Into the black behind the door: the next time round, or out.
func _through() -> void:
	if _in_vestibule:
		return
	_in_vestibule = true
	var p := d.player
	if _k + 1 >= ROOMS:
		await cut_to(OUT_DOOR + Vector3(-1.3, 0.05, 0), PI / 2)
		Snd.play_at("door_slam", OUT_DOOR + Vector3(0, 1.0, 0), -4.0, 1.0, 7.0)
		d.player.add_shake(0.15)
		_done = true
		return
	_k += 1
	var yaw: float = p._yaw
	var pitch: float = p._pitch
	var mv := p.move_vel
	var vel := p.velocity
	p.teleport(Transform3D(Basis(), p.global_position + Vector3(0, 0, RepeatRoom.STEP)))
	p.set_look(yaw, pitch)
	p.move_vel = mv
	p.velocity = vel
	room.entry.leaf.rotation.y = deg_to_rad(84.0)
	(room.entry.block as StaticBody3D).collision_layer = 0
	_start_room()
	await d.wait(0.5)
	_in_vestibule = false
