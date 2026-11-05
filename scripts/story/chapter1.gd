class_name Chapter1
extends StoryScript
## The main story picks up where the prologue blacked out: the boarding-bridge connector, FLIGHT 000 — GATE 0 lit
## over a steel fire door with a chain and a padlock through its push bars, and you in front of it with the key you
## have just picked up off the floor. Open the padlock: the leaves swing away and what lies past them is no gate — a
## dark vestibule and an open door into your own security office (a PortalView on the bridge's vestibule, looking in
## from Terminal.SEC_ENTRY_PLANE). Walk through and you are there, coming in at the office's door — its only one, the
## steel door in the west wall with the card reader (user: the card door moved there, the other doors were removed)
## — which slams shut behind you and is locked: it wants a key card: open the drawers ([E], Drawer) until
## one has it, tag the reader and it opens — not onto the dark vestibule but onto the service corridors that wind
## round the office like a maze (ServiceHall, far below; a PortalView on that vestibule). Through it, the door slams
## and locks behind you; doors everywhere, square lights in a grey-green haze, the lit office through its own big
## windows as you pass them, and no running (the red ball and the figure that once played out in here are gone —
## user: "복도에서 공 나오고 … 이런거 다 빼"). The office and the corridors are on the 4th floor,
## the main lounge on the 1st: down the last long run is the lift, and from the run's north end the emergency stairs
## lead down through a stair lobby (Lift, StairCore — the terminal's; either one emits Terminal.crossed); you come out
## by the lounge's east wall, the airliner that came through its glass ahead. From there the lounge is the hub
## (PartHub): a check-in device at security wants three things, one from each of three branches (PartFog, PartRepeat,
## PartBaggage), in any order; then PartFinal, the last run to Gate 0 and back to the start. The
## office you come back to here is not the one you left (_warp_office). The inspector says nothing on screen and keeps
## the controls the whole way (a thought at a locked door or the device apart); no markers.
##
## Checkpoints: "" (the gate door), "hub" (the lounge, your progress in the flags), "baggage" (caught there), "final".

const STAGES := ["", "hub", "baggage", "final"]
const CARD_DRAWER := "c3"                # the guard's desk, bottom drawer
const HINT_GAP_MS := 6000                # the locked key card door's thought comes again at most this often
## How much of their light the lounge and its 2F units have at night (the rest of the terminal's zones run at 0.62;
## user: "내부 조금 더 어둡게").
const HUB_DIM := {"hall": 0.48, "shops": 0.48, "airhall": 0.62}

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
var _in_hall := false
var _in_lounge := false            # down on the lounge's floor (by the lift or the stairs) at least once
var hub: PartHub
var fog: PartFog
var repeat: PartRepeat
var bags: PartBaggage
var final_part: PartFinal
var _caught_once := false
var _warp_nodes: Array[Node3D] = []   # what _warp_office added to your office
var _clock_labels: Array[Label3D] = []
var _screens := {}                    # MeshInstance3D -> [dead, snow] as they were


func setup() -> void:
	var t := d.terminal
	# 02:17 still: only your office is lit; the passage outside it is dark
	for zn in t.zones.keys():
		t.set_zone_light(zn, zn == "secoffice", true)
	d.ui.hud.set_clock_override("--:--")
	d.ui.tablet.show_belongings()
	hub = PartHub.new()
	fog = PartFog.new()
	repeat = PartRepeat.new()
	bags = PartBaggage.new()
	final_part = PartFinal.new()
	var parts: Array[StoryPart] = [fog, repeat, bags, hub, final_part]
	for part: StoryPart in parts:
		part.d = d
		part.ch = self
		add_child(part)
		part.setup()
	var at := STAGES.find(Game.checkpoint)
	if at > 0:
		_restore()
		return
	_warp_office()
	var b := d.bridge
	b.zone.set_on(true, true)
	b.zone.night_dim = 0.7
	b.set_board(JetBridge.BOARD_BOARDING, false)
	# where the prologue left you: at the door, the key off the floor in your hand
	d.player.teleport(Transform3D(b.global_basis.orthonormalized(), b.door_front()))
	d.player.set_look(d.player.rotation.y, deg_to_rad(-10.0))
	d.player.zone_override = "jetbridge"
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


## Picked up from a checkpoint in the lounge or past it: the lounge lit, what you have done in the flags.
func _restore() -> void:
	var t := d.terminal
	_hub_lights()
	t.set_zone_light("secoffice", false, true)
	d.bridge.zone.set_on(false, true)
	t.service_hall.zone.set_on(false, true)            # the 4th floor's corridors: lit again if you go back up
	t.crossed.connect(_crossed)
	_in_lounge = true
	if not Game.has_item("keycard") and not Game.flag("checked_in"):
		Game.add_item("keycard")
	hub.restore()
	match Game.checkpoint:
		"baggage":
			d.player.teleport(Transform3D(Basis(), PartBaggage.ARRIVE))
			d.player.set_look(PI, 0.0)
		"final":
			hub.checked_in = true
			d.ui.tablet.set_passenger()
			d.player.teleport(Transform3D(Basis(), PartHub.DEVICE_AT + Vector3(-1.2, 0.05, 1.2)))
			d.player.set_look(0.0, 0.0)
		_:
			d.player.teleport(Transform3D(Basis(), PartHub.DEVICE_AT + Vector3(0.0, 0.05, 4.0)))
			d.player.set_look(0.0, 0.0)


func _hub_lights() -> void:
	var t := d.terminal
	for zn: String in ["hall", "shops", "airhall"]:
		t.set_zone_light(zn, true, true)
		(t.zones[zn] as LightZone).night_dim = HUB_DIM[zn]


func run() -> void:
	Snd.set_ambience("amb_night_loop", -20.0, 3.0)
	if STAGES.find(Game.checkpoint) > 0:
		await d.ui.fade_to(0.0, 1.4)
		if Game.checkpoint != "final":
			await hub.run()
		await final_part.run()
		return
	await _arrive()
	d.objective("라운지로 내려가기")
	await hub.run()
	await final_part.run()


## Caught anywhere past the lounge: black at once, the thing screaming in the dark, back at the last checkpoint.
func caught() -> void:
	if _caught_once:
		return
	_caught_once = true
	d.dead = true
	d.cutscene(true)
	d.player.controls_enabled = false
	d.ui.hud.hide_subtitle()
	d.ui.cut_to(1.0)
	d.pa_stop()
	Snd.stop_all_world()
	Snd.play("monster_scream", -5.0, 1.0, "SFX")
	await d.wait(2.2)
	Game.restart_checkpoint()


## The office as you come back to it: not the room you left. Every monitor is snow (a clock showing 2:17 would go to
## 0:00, but the office has none now — user: "시계도 없었으면 좋겠어"), a row
## of airport seats stands in the middle of the floor, bags have been left round it. (The key card is where it always
## was. The red FLIGHT 000 / GATE 0 written across the floor is gone — user: "바닥에 이 빨간글씨 삭제해라".)
func _warp_office() -> void:
	var t := d.terminal
	for l: Label3D in t.sec_root.find_children("*", "Label3D", true, false):
		if l.text == "2:17":
			Geo.set_text(l, "0:00")
			_clock_labels.append(l)
	for m: MeshInstance3D in t.sec_root.find_children("*", "MeshInstance3D", true, false):
		var sm := m.material_override as ShaderMaterial
		if sm and sm.shader and sm.shader.resource_path.ends_with("cctv_feed.gdshader"):
			_screens[m] = [m.get_instance_shader_parameter("dead"), m.get_instance_shader_parameter("snow")]
			m.set_instance_shader_parameter("dead", 0.0)
			m.set_instance_shader_parameter("split", 1.0)
			m.set_instance_shader_parameter("snow", 1.0)
	var row := Props.seat_row(t, Vector3(-17.3, 0, -22.0), 4, PI)
	Terminal.office_layers(row)
	_warp_nodes.append(row)
	for i in 3:
		var bag := Props.suitcase(t, Color.from_hsv(0.05 + i * 0.3, 0.3, 0.3))
		bag.position = [Vector3(-19.15, 0.0, -22.0), Vector3(-15.6, 0.0, -22.05), Vector3(-17.5, 0.0, -21.25)][i]
		bag.rotation.y = i * 1.4
		Terminal.office_layers(bag)
		_warp_nodes.append(bag)


## The first shot again: the office as it was at 02:17.
func restore_office() -> void:
	var t := d.terminal
	for n in _warp_nodes:
		n.visible = false
	for l in _clock_labels:
		Geo.set_text(l, "2:17")
	for m: MeshInstance3D in _screens.keys():
		m.set_instance_shader_parameter("dead", _screens[m][0])
		m.set_instance_shader_parameter("snow", _screens[m][1])
	t.swing_sec_door(0.0, 0.01)
	t.swing_door(t.sec_entry, 0.0, 0.01)
	t.service_hall.zone.set_on(true, true)               # the corridors round it lit again, out of its windows
	var z: LightZone = t.zones.secoffice
	z.night_dim = 1.0
	z.set_on(true, true)


func _arrive() -> void:
	var t := d.terminal
	d.player.controls_enabled = false
	await d.ui.fade_to(0.0, 1.8)
	d.player.controls_enabled = true
	d.ui.hud.show_key_hints(12.0)
	d.objective("자물쇠 열기")
	await d.until(func(): return _through)
	# your office again, in at its door (the west one, its only one) — which slams and locks behind you once you are in
	d.clear_objective()
	await d.until(func(): return d.player.global_position.x > Terminal.SEC_LEG.position.x + 1.4)
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
	# down to the lounge on 1F by the lift at the far end or the stairs at the north end (_crossed)
	await d.until(func(): return _in_lounge)


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


## The service corridors past the office's west door, the key card door (the terminal builds them far below, lights
## on, for the office's windows), the portal that shows them through the door once it opens — on the dark vestibule
## outside it (Terminal.sec_vestibule) — and the trigger just past the doorway. The way on down to the lounge is the terminal's own: the
## lift at the far end and the stairs (Terminal.crossed).
func _build_hall() -> void:
	var t := d.terminal
	hall = t.service_hall
	hall.zone.set_on(true, true)
	# out of the west door (the key card door), on (-X) into the corridor that runs past it: the dark vestibule outside
	# it shows the corridor once the door opens
	var src := Transform3D(Basis(Vector3.UP, -PI / 2), (t.sec_entry.root as Node3D).global_position)
	_hall_portal = PortalView.create(t, src, hall.entry_frame(), d.player.camera, _env())
	for m: MeshInstance3D in t.sec_vestibule:
		m.material_override = _hall_portal.surface_material()
	var past := Geo.area(t, Vector3(-23.2, 1.0, Terminal.SEC_ENTRY_Z), Vector3(0.6, 2.0, 1.0))   # far enough out to clear the frame
	past.body_entered.connect(func(body):
		if body == d.player and _granted and not _in_hall:
			_in_hall = true
			_into_hall.call_deferred())
	hall.entry.use.callback = func(): t.rattle(hall.entry)
	t.crossed.connect(_crossed)


## Through the office door: you are at the corridor's entrance, the same offset from its doorway, heading and pitch.
## The lounge is lit for the night now.
func _into_hall() -> void:
	var p := d.player
	var m := _hall_portal.dst * _hall_portal.src.affine_inverse()
	var fwd := m.basis * (-p.camera.global_basis.z)
	p.teleport(Transform3D(Basis(), m * p.global_position))
	p.set_look(atan2(-fwd.x, -fwd.z), asin(clampf(fwd.y, -1.0, 1.0)))
	p.zone_override = "servicehall"
	p.no_sprint = true                                   # no running in the corridor
	_hall_portal.set_active(false)
	(hall.entry.leaf as Node3D).visible = true
	_hub_lights()                                        # (the office stays lit: you see it through its windows)
	d.objective("1층으로 내려가기")


## Down to the lounge on 1F by the lift or the stairs, or back up to the 4th floor: the corridors and the office are
## lit only while you are on their floor (from the corridors you see the office through its windows); no running up
## there.
func _crossed(to_lounge: bool) -> void:
	var p := d.player
	p.no_sprint = not to_lounge
	hall.zone.set_on(not to_lounge, true)
	d.terminal.set_zone_light("secoffice", not to_lounge, true)
	if to_lounge:
		_in_lounge = true


## The office as you come back to it: the west door (the steel key card door) locked — it rattles, and its reader
## wants a card — and the key card lying in one of the drawers.
func _set_office() -> void:
	var t := d.terminal
	var use: Interactable = t.sec_entry.use
	use.prompt = "문 열기"
	use.enabled = true
	use.callback = func():
		if _granted:
			return
		t.rattle(t.sec_entry)
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
	(d.terminal.sec_entry.use as Interactable).enabled = false
	d.clear_objective()
	var door: Node3D = d.terminal.sec_entry.root
	await d.wait(0.35)
	Snd.play_at("lock_click", door.global_position + Vector3(0.2, 1.0, 0.4), -4.0, 1.0, 4.0)
	await d.wait(0.3)
	Snd.play_at("door_heavy", door.global_position + Vector3(0.3, 1.0, 0), -8.0, 1.1, 5.0)
	_hall_portal.set_active(true)                  # past the door now: the service corridor
	d.terminal.swing_door(d.terminal.sec_entry, 84.0, 1.4)
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
	Terminal.office_layers(dr.inside)                    # lit by the office's lights like the rest of it
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
