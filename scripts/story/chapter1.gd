class_name Chapter1
extends StoryScript
## The main story picks up where the prologue blacked out: the boarding-bridge connector, FLIGHT 000 — GATE 0 lit
## over a steel fire door with a chain and a padlock through its push bars, and you in front of it with the key you
## have just picked up off the floor. Open the padlock: the leaves swing away and what lies past them is no gate — a
## dark vestibule and an open door into your own security office (a PortalView on the bridge's vestibule, looking in
## from Terminal.SEC_ENTRY_PLANE). Walk through and you are there, coming in at the office's west door, which slams
## shut behind you and will not open again. The passage door is locked now and wants a key card: open the drawers
## ([E], Drawer) until one has it, tag the reader by the door and it opens — not onto the passage but onto a long
## service corridor (ServiceHall, far below; a PortalView on a dark box in the passage beyond the door). Through it,
## the door slams and locks behind you; lockers, boarded windows leaking light, fluorescent tubes in a green haze, and
## at the far end, before a pair of steel doors under a clock, someone standing — gone in a dip of the lights as you
## come near. The office and the corridor are a floor up: the doors open onto the main lounge's closed 2F deck
## (another PortalView: the deck from its staff doors), the hall below with the airliner that came through its glass;
## you come out of those doors, they slam and lock, and you go down the stopped escalator — on the lounge floor,
## walking on toward the wreck is "TO BE CONTINUED" for now, back to the title. The inspector says nothing on screen
## and keeps the controls the whole way (only the end takes them); no markers.

const CARD_DRAWER := "c3"                # the guard's desk, bottom drawer
const LOUNGE_WALK := 18.0                # how far from the escalator's foot, down on the lounge floor, it ends at the latest
const HINT_GAP_MS := 6000                # the locked passage door's thought comes again at most this often

var _portal: PortalView
var _through := false
var _card_node: Node3D
var _card_use: Interactable
var _refused := false             # the passage door or its reader has turned you away
var _tries := 0                   # how many times it has
var _hint_at := -HINT_GAP_MS      # when the "it wants a card" thought last showed (ms)
var _granted := false
var hall: ServiceHall
var _hall_portal: PortalView      # the office's passage door -> the corridor's entrance
var _lounge_portal: PortalView    # the corridor's far doors -> the lounge deck's staff doors
var _in_hall := false
var _far_open := false
var _in_lounge := false


func setup() -> void:
	var b := d.bridge
	var t := d.terminal
	# 02:17 still: only your office is lit; the passage outside it is dark
	for zn in t.zones.keys():
		t.set_zone_light(zn, zn == "secoffice", true)
	b.zone.set_on(true, true)
	b.zone.night_dim = 0.7
	b.set_board(JetBridge.BOARD_BOARDING, false)
	# where the prologue left you: at the door, the key off the floor in your hand
	d.player.teleport(Transform3D(b.global_basis.orthonormalized(), b.door_front()))
	d.player.set_look(d.player.rotation.y, deg_to_rad(-10.0))
	d.player.zone_override = "jetbridge"
	d.ui.hud.set_clock_override("--:--")
	d.ui.tablet.lost = true
	d.ui.tablet.lose_signal_now()
	if not Game.has_item("key_gate") and not Game.flag("gate_unlocked"):
		Game.add_item("key_gate")
	b.door_use.callback = _door
	b.door_use.prompt = "열쇠로 자물쇠 열기"
	b.beyond.body_entered.connect(func(body):
		if body == d.player and not b.locked and not _through:
			_through = true
			_into_office.call_deferred())
	_build_portal()
	_set_office()
	_build_hall()


func run() -> void:
	var t := d.terminal
	Snd.set_ambience("amb_night_loop", -20.0, 3.0)
	d.player.controls_enabled = false
	await d.ui.fade_to(0.0, 1.8)
	d.player.controls_enabled = true
	d.ui.hud.show_key_hints(12.0)
	d.objective("자물쇠 열기")
	await d.until(func(): return _through)
	# your office again, in at its west door — which slams and locks behind you once you are in
	d.clear_objective()
	await d.until(func(): return d.player.global_position.x > -18.6)
	d.player.zone_override = ""
	var entry: Node3D = t.sec_entry.root
	t.swing_door(t.sec_entry, 0.0, 0.22)
	(t.sec_entry.use as Interactable).enabled = true
	await d.wait(0.2)
	Snd.play_at("door_slam", entry.global_position + Vector3(0.2, 1.0, 0), -2.0, 1.05, 6.0)
	d.player.add_shake(0.25)
	await d.wait(0.25)
	Snd.play_at("lock_click", entry.global_position + Vector3(0.2, 1.0, 0.4), -6.0, 0.9, 4.0)
	await d.wait(1.4)
	_office_objective()
	await d.until(func(): return _granted)
	await d.until(func(): return _in_hall)
	# the service corridor: the door you came through slams and locks behind you
	await d.wait(0.5)
	var e := hall.entry
	t.swing_door(e, 0.0, 0.22)
	await d.wait(0.2)
	Snd.play_at("door_slam", (e.root as Node3D).global_position + Vector3(0, 1.0, 0), -2.0, 1.0, 6.0)
	d.player.add_shake(0.25)
	await d.wait(0.25)
	Snd.play_at("lock_click", (e.root as Node3D).global_position + Vector3(0, 1.0, 0), -6.0, 0.9, 4.0)
	(e.use as Interactable).enabled = true
	_watch_figure()
	await d.until(func(): return _in_lounge)
	# out onto the lounge's 2F deck by its staff doors, which swing to and lock behind you
	var ld := t.lounge_door
	await d.wait(0.4)
	ServiceHall.swing(ld, 0.0, 0.25)
	await d.wait(0.22)
	Snd.play_at("door_slam", (ld.root as Node3D).global_position + Vector3(0, 1.0, 0), -2.0, 0.92, 7.0)
	d.player.add_shake(0.25)
	await d.wait(0.25)
	Snd.play_at("lock_click", (ld.root as Node3D).global_position + Vector3(0, 1.0, 0), -6.0, 0.9, 4.0)
	d.objective("라운지로 내려가기")
	await d.until(func(): return _down_in_lounge())
	d.clear_objective()
	d.cutscene(true)
	await d.ui.fade_to(1.0, 1.4)
	Snd.stop_all_world()
	await d.ui.title_card("TO BE CONTINUED", "다음 이야기는 준비 중입니다.", 2.0, false)
	Game.go_menu()


## Past the gate door the bridge's dark vestibule shows the vestibule outside your office's west door (PortalView), so
## once the doors swing open you see it and the lit office through its open door. (The portal only renders from the
## unlock: the steel leaves hide everything past them until then.)
func _build_portal() -> void:
	var b := d.bridge
	var t := d.terminal
	var src := Transform3D(b.global_basis.orthonormalized() * Basis(Vector3.UP, PI), b.gate_door.global_position)
	var dst := Transform3D(Basis(Vector3.UP, PI / 2), Terminal.SEC_ENTRY_PLANE)
	_portal = PortalView.create(b, src, dst, d.player.camera, _env())
	for m in b.vestibule:
		m.material_override = _portal.surface_material()
	t.sec_vestibule_end.visible = false                  # out of the way of the view in
	t.swing_door(t.sec_entry, 84.0, 0.01)
	(t.sec_entry.use as Interactable).enabled = false      # standing open: nothing to try yet


## Through the gate door: you are in the vestibule outside the office's west door, exactly where the portal showed it
## (the same offset from the doorway, heading and pitch).
func _into_office() -> void:
	var p := d.player
	var m := _portal.dst * _portal.src.affine_inverse()
	var fwd := m.basis * (-p.camera.global_basis.z)
	p.teleport(Transform3D(Basis(), m * p.global_position))
	p.set_look(atan2(-fwd.x, -fwd.z), asin(clampf(fwd.y, -1.0, 1.0)))
	p.zone_override = "secoffice"                        # the vestibule is no zone of its own: it is the office's
	_portal.set_active(false)
	d.terminal.sec_vestibule_end.visible = true
	d.bridge.zone.set_on(false, true)


func _env() -> Environment:
	for we: WorldEnvironment in d.world.find_children("*", "WorldEnvironment", true, false):
		return we.environment
	return null


## The service corridor past the office's passage door (built far below, its lights on), the portal that shows it
## through the door once it opens — a dark box lining the passage just beyond the door — and the trigger just past
## the doorway; its far doors (locked to nothing, they open on [E]) and the deck's staff doors they open onto,
## leaves out of sight until you come through.
func _build_hall() -> void:
	var t := d.terminal
	hall = ServiceHall.new()
	d.world.add_child(hall)
	hall.build()
	hall.zone.set_on(true, true)
	var src := Transform3D(Basis(Vector3.UP, PI / 2), t.sec_door.global_position)
	_hall_portal = PortalView.create(t, src, hall.entry_frame(), d.player.camera, _env())
	var mat := _hall_portal.surface_material()
	for b: Array in [[Vector3(-11.2, 0.003, -16.0), Vector3(1.98, 0.004, 5.0)], [Vector3(-11.2, 2.6, -16.0), Vector3(1.98, 0.02, 5.0)],
			[Vector3(-10.25, 1.3, -16.0), Vector3(0.02, 2.6, 5.0)], [Vector3(-11.2, 1.3, -18.5), Vector3(1.98, 2.6, 0.02)],
			[Vector3(-11.2, 1.3, -13.5), Vector3(1.98, 2.6, 0.02)]]:
		Geo.box(t, b[0], b[1], mat, false)
	var past := Geo.area(t, Vector3(-11.6, 1.0, -16.0), Vector3(0.6, 2.0, 1.0))   # far enough in to clear the leaf
	past.body_entered.connect(func(body):
		if body == d.player and _granted and not _in_hall:
			_in_hall = true
			_into_hall.call_deferred())
	hall.far_doors.use.prompt = "문 열기"
	hall.far_doors.use.callback = _open_far
	hall.entry.use.callback = func(): t.rattle(hall.entry)
	hall.beyond.body_entered.connect(func(body):
		if body == d.player and _far_open and not _in_lounge:
			_in_lounge = true
			_into_lounge.call_deferred())
	for leaf: Node3D in t.lounge_door.leaves:
		leaf.visible = false


## Through the office door: you are at the corridor's entrance, the same offset from its doorway, heading and pitch.
## The lounge is lit for the night now, and its portal made (only now: one more full-screen view to keep).
func _into_hall() -> void:
	var p := d.player
	var m := _hall_portal.dst * _hall_portal.src.affine_inverse()
	var fwd := m.basis * (-p.camera.global_basis.z)
	p.teleport(Transform3D(Basis(), m * p.global_position))
	p.set_look(atan2(-fwd.x, -fwd.z), asin(clampf(fwd.y, -1.0, 1.0)))
	p.zone_override = "servicehall"
	_hall_portal.set_active(false)
	(hall.entry.leaf as Node3D).visible = true
	var t := d.terminal
	t.set_zone_light("hall", true, true)
	(t.zones.hall as LightZone).night_dim = 0.62
	_lounge_portal = PortalView.create(hall, hall.far_frame(), (t.lounge_door.root as Node3D).global_transform, p.camera, _env())
	for m2 in hall.far_vestibule:
		m2.material_override = _lounge_portal.surface_material()
	d.objective("복도 끝 문 열기")


## Down the escalator on the lounge floor and either up to the airliner or well away from the escalator's foot.
func _down_in_lounge() -> bool:
	var p := d.player.global_position
	if p.y > 0.6:
		return false
	var foot := Vector2(Terminal.ESC_FOOT.x, Terminal.ESC_FOOT.z)
	return d.terminal.near_wreck(p, 4) or Vector2(p.x, p.z).distance_to(foot) > LOUNGE_WALK


## The figure at the end of the corridor is gone in a dip of the lights once you come near.
func _watch_figure() -> void:
	await d.until(func(): return d.player.global_position.distance_to(hall.figure.global_position) < 17.0)
	hall.vanish()


func _open_far() -> void:
	if _far_open:
		return
	_far_open = true
	hall.far_doors.use.enabled = false
	_lounge_portal.set_active(true)
	Snd.play_at("door_heavy", hall.to_global(Vector3(0, 1.0, ServiceHall.LENGTH)), -6.0, 0.95, 6.0)
	ServiceHall.swing(hall.far_doors, 82.0, 1.2)
	d.objective("라운지로 들어가기")


## Through the corridor's far doors: out of the deck's staff doors, which stand open behind you as those did.
func _into_lounge() -> void:
	var p := d.player
	var m := _lounge_portal.dst * _lounge_portal.src.affine_inverse()
	var fwd := m.basis * (-p.camera.global_basis.z)
	p.teleport(Transform3D(Basis(), m * p.global_position))
	p.set_look(atan2(-fwd.x, -fwd.z), asin(clampf(fwd.y, -1.0, 1.0)))
	p.zone_override = ""
	_lounge_portal.set_active(false)
	var ld := d.terminal.lounge_door
	var leaves: Array[Node3D] = ld.leaves
	for i in leaves.size():
		leaves[i].visible = true
		leaves[i].rotation.y = (-1.0 if i == 0 else 1.0) * deg_to_rad(82.0)
	(ld.block as StaticBody3D).collision_layer = 0
	hall.zone.set_on(false, true)


## The office as you come back to it: the passage door locked — it rattles, and its reader wants a card — and the key
## card lying in one of the drawers.
func _set_office() -> void:
	var t := d.terminal
	t.sec_use.prompt = "문 열기"
	t.sec_use.enabled = true
	t.sec_use.callback = func():
		if _granted:
			return
		t.rattle(t.sec_passage)
		_refuse()
		_locked_hint()
	t.sec_reader.interactable.enabled = true
	t.sec_reader.swiped.connect(_swipe)
	_place_card(t.sec_drawers[CARD_DRAWER])


func _office_objective() -> void:
	if _granted:
		return
	if Game.has_item("keycard"):
		d.objective("키 카드로 문 열기")
	elif _refused:
		d.objective("키 카드 찾기")
	else:
		d.objective("보안실에서 나가기")


func _refuse() -> void:
	if not _refused and not Game.has_item("keycard"):
		_refused = true
		_office_objective()


## Turned away by the passage door or its reader again: from the second time on a thought says what it wants (a key
## card, or once you have one, the reader beside it) — not more often than every HINT_GAP_MS.
func _locked_hint() -> void:
	_tries += 1
	var now := Time.get_ticks_msec()
	if _tries < 2 or now - _hint_at < HINT_GAP_MS:
		return
	_hint_at = now
	var line := "……카드 리더기에 대 봐야겠다." if Game.has_item("keycard") else "……키 카드가 필요한 것 같다."
	Events.subtitle.emit("self", line, 3.2)


func _swipe(reader: CardReader) -> void:
	if _granted:
		return
	if not Game.has_item("keycard"):
		reader.show_result(false, "DENIED")
		_refuse()
		_locked_hint()
		return
	_granted = true
	reader.show_result(true, "OK")
	reader.interactable.enabled = false
	d.terminal.sec_use.enabled = false
	d.clear_objective()
	var door := d.terminal.sec_door
	await d.wait(0.35)
	Snd.play_at("lock_click", door.global_position + Vector3(-0.2, 1.0, -0.4), -4.0, 1.0, 4.0)
	await d.wait(0.3)
	Snd.play_at("door_heavy", door.global_position + Vector3(-0.3, 1.0, 0), -8.0, 1.1, 5.0)
	_hall_portal.set_active(true)                  # past the door now: the service corridor
	d.terminal.swing_sec_door(84.0, 1.4)
	d.objective("밖으로 나가기")


## The key card: white, a blue band, STAFF, a clip — lying in the drawer, to be picked up once it is open.
func _place_card(dr: Drawer) -> void:
	for c in dr.inside.get_children():                   # nothing on top of it
		c.queue_free()
	# its blue lanyard in a loose loop beside it
	var strap := Mats.std(Color(0.1, 0.22, 0.6), 0.8)
	for s: Array in [[Vector3(-0.07, 0.002, 0.02), 0.25, 0.4], [Vector3(-0.1, 0.002, -0.06), 0.16, -0.3], [Vector3(-0.03, 0.002, -0.1), 0.14, 1.3]]:
		Geo.box(dr.inside, s[0], Vector3(0.016, 0.003, s[1]), strap, false, s[2])
	_card_node = Node3D.new()
	_card_node.name = "KeyCard"
	dr.inside.add_child(_card_node)
	_card_node.position = Vector3(0.05, 0.0, 0.04)
	_card_node.rotation.y = 0.35
	Geo.box(_card_node, Vector3(0, 0.001, 0), Vector3(0.054, 0.002, 0.086), Mats.get_mat("plastic_white"), false)
	Geo.box(_card_node, Vector3(0, 0.0023, 0.024), Vector3(0.054, 0.0006, 0.016), Mats.std(Color(0.12, 0.25, 0.65), 0.5), false)
	var l := Geo.label(_card_node, "STAFF", Vector3(0, 0.0027, -0.012), 0.0, 24, Color(0.1, 0.12, 0.2), 0.0012, false, "print")
	l.rotation.x = -PI / 2
	Geo.box(_card_node, Vector3(0, 0.003, 0.048), Vector3(0.012, 0.004, 0.016), Mats.get_mat("metal"), false)
	_card_use = Interactable.create(_card_node, Vector3(0, 0.03, 0), Vector3(0.14, 0.08, 0.16), "키 카드 줍기", _take_card)
	_card_use.press_sound = ""
	_card_use.enabled = false
	_card_use.collision_layer = 0                        # shut in the drawer: nothing to reach
	dr.toggled.connect(func(x: Drawer):
		if _card_use:
			_card_use.enabled = x.is_open
			_card_use.collision_layer = Geo.LAYER_INTERACT if x.is_open else 0)


func _take_card() -> void:
	Snd.play("card_pickup", -4.0)
	Game.add_item("keycard")
	Events.notify.emit("키 카드를 주웠다.", "good")
	_card_node.queue_free()
	_card_node = null
	_card_use = null
	_office_objective()


func _door() -> void:
	var b := d.bridge
	if not b.locked:
		return
	if not Game.has_item("key_gate"):
		b.rattle()
		return
	Game.remove_item("key_gate")
	Game.set_flag("gate_unlocked")
	_portal.set_active(true)
	b.unlock()
	await d.wait(1.6)
	d.objective("문 너머로 나아가기")
