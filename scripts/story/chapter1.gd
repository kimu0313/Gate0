class_name Chapter1
extends StoryScript
## The main story picks up where the prologue blacked out: the boarding-bridge connector, FLIGHT 000 — GATE 0 lit
## over a steel fire door with a chain and a padlock through its push bars, and you in front of it with the key you
## have just picked up off the floor. Open the padlock: the leaves swing away and what lies past them is no gate — a
## dark vestibule and an open door into your own security office (a PortalView on the bridge's vestibule, looking in
## from Terminal.SEC_ENTRY_PLANE). Walk through and you are there, coming in at the office's west door, which slams
## shut behind you and will not open again. The passage door is locked now and wants a key card: open the drawers
## ([E], Drawer) until one has it, tag the reader by the door and it lets you out into the dark passage — "TO BE
## CONTINUED" for now, back to the title. The inspector says nothing on screen and keeps the controls the whole way
## (only the end takes them); no markers.

const CARD_DRAWER := "c3"                # the guard's desk, bottom drawer

var _portal: PortalView
var _through := false
var _card_node: Node3D
var _card_use: Interactable
var _refused := false             # the passage door or its reader has turned you away
var _granted := false


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
	d.player.toggle_flashlight(1)
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
	await d.until(func(): return d.player.global_position.x > -12.1)       # out into the passage
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
	var env: Environment = null
	for we: WorldEnvironment in d.world.find_children("*", "WorldEnvironment", true, false):
		env = we.environment
	_portal = PortalView.create(b, src, dst, d.player.camera, env)
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


func _swipe(reader: CardReader) -> void:
	if _granted:
		return
	if not Game.has_item("keycard"):
		reader.show_result(false, "DENIED")
		_refuse()
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
