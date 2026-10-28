class_name Prologue
extends StoryScript
## The cold open (Gate 0 v2 — 오프닝 시나리오, SCENE 01–04).
##
## 01 마지막 점검 — A국제공항 터미널, AM 02:17. The last checks of the night from the security office off the staff
##    passage: lights and PA are done, the baggage system still needs a look. A baggage cart rattles somewhere it
##    should not be, and keeps on, always a little ahead: out of the office door (it swings shut behind you) and up the
##    dark passage after it. To the right, the passage ends in a pair of fire doors, locked: they only rattle.
## 02 형체 — down the dark staff passage into the closed baggage hall (02:19): a cart left askew and someone in a
##    cabin-crew uniform with their back to you, tearing baggage tags. Say something, try to see the face — it turns,
##    joint by joint.
## 03 도주 — run, back down the passage. Your office's door is gone from its wall; at the end the locked fire doors are
##    GATE 0 now, under a lit sign that should say EXIT. Push them open ([E]; running into them does nothing) — you
##    fall through into the dark: a wide boarding-bridge connector, black glass. Down on its floor you look back for
##    the doors: wall. You look ahead again as you get up.
## 04 사라진 문 — you get up. A second after you set off, the chime: the PA starts boarding FLIGHT 000 and the board
##    at the end lights up, FLIGHT 000 — GATE 0. On the way the radio answers your call ("그쪽으로 들어가시면 안 됩니다") and the
##    tablet, if you look, has lost you — neither is waited for. At the end a steel fire door, chained and padlocked
##    (it only rattles), and a key on the carpet in front of it: pick it up and black. (SCENE 05: the title; the main
##    story opens at this door with the key.)
##
## The inspector never speaks on screen (no lines of their own, no subtitles for them), sounds get no captions, there
## are no markers (the way is found by eye, or by ear: StoryDirector.guide) and the game never takes the controls away
## to make them listen: only the fall through the door, getting up off the floor and the blackouts do.
##
## Checkpoints: "" (the start), "chase" (caught: back to the moment it starts to move), "bridge" (debug: inside).

const START := Vector3(-16.2, 0.05, -11.75)          # in the security office by its south wall, looking up the room
const FIGURE_POS := Vector3(-12.7, 0.0, -45.4)
const CART_POS := Vector3(-13.1, 0.0, -46.8)
const CHASE_SPAWN := Vector3(-12.2, 0.05, -42.8)
const SEC_DOOR := Vector3(-12.25, 0.0, -16.0)        # the office door on the passage's west wall (Terminal.sec_door)
const FIRE_DOOR := Vector3(-11.2, 0.0, -8.5)         # the staff passage's mouth on the strip: the chase's way out
const KEY_LOCAL := Vector3(0.32, 0.0, -JetBridge.LENGTH + 0.75)   # bridge space, on the floor before the gate door
## The cart you hear from the office, a little ahead of you all the way: behind the office door, up the passage, at
## the cart in the baggage hall ([point, reach m]: it rolls on when you come within reach).
const CART_PATH := [
	[Vector3(-11.0, 0.8, -16.6), 1.3], [Vector3(-11.2, 0.8, -27.0), 3.0], [Vector3(-11.2, 0.8, -38.5), 3.0],
	[Vector3(-13.1, 0.8, -46.8), 0.0],
]
const CHECKLIST := [["조명 설비", "ok"], ["안내방송 설비", "ok"], ["수하물 운송 설비", "check"], ["직원 통로", "todo"]]

var fig: CrewFigure
var _talked := false
var _tag_seen := false
var _chasing := false
var _chase_t := 0.0
var _crumb := Vector3.INF
var _door_hit := false
var _door_use: Interactable      # Terminal.sec_use: out of the office at the start
var _door_open := false          # opened from inside, waiting to swing shut behind you
var _fire_l: Node3D              # the fire door's leaves (hinge nodes), its collider and its [E]
var _fire_r: Node3D
var _fire_block: StaticBody3D
var _fire_use: Interactable
var _fire_face: MeshInstance3D    # the sign's face over the doors (dark until the chase)
var _fire_glow: OmniLight3D
var _fire_gate0: Array[Node3D] = []  # what reads GATE 0 (the sign's lettering, the stencils), shown in the chase
var _rattle_at := -10000
var _portal: PortalView          # behind the fire doors: the boarding bridge you are about to fall into
var _near_door := false
var key_node: Node3D              # on the carpet before the boarding bridge's gate door: picking it up ends the prologue
var _board_on := false
var _at_door := false
var _door_tried := false
var _ended := false
var _lamp: OmniLight3D
var _lamp_panel: MeshInstance3D
var _lamp_t := 0.0


func setup() -> void:
	var t := d.terminal
	# 02:17, the night lighting: the halls on, the closed baggage area (and the staff passage through it) dark
	for zn in t.zones.keys():
		t.set_zone_light(zn, zn != "baggage" and zn != "service", true)
		(t.zones[zn] as LightZone).night_dim = 0.62
	t.shutters.baggage.open(true)
	d.ui.tablet.set_checklist(CHECKLIST)
	d.ui.tablet.set_target("수하물 운송 설비 확인", "baggage", Terminal.BELT_POS)
	d.bridge.set_board(JetBridge.BOARD_OFF, false)
	d.bridge.get_node("GateDoor").visible = true
	d.bridge.door_use.prompt = "문 열기"
	d.bridge.door_use.callback = _gate_pressed
	_place_key()
	_build_scene_02()
	_build_fire_door()
	_door_use = t.sec_use
	_door_use.callback = _door_pressed
	match Game.checkpoint:
		"chase":
			t.set_zone_light("secoffice", false, true)
			d.set_clock(2 * 60 + 19)
			fig.pose_broken(fig.face_yaw_to(CHASE_SPAWN))
			fig.rotation.y = 0.0
			d.player.teleport(Transform3D(Basis(), CHASE_SPAWN))
			d.player.look_at_point(fig.head_position(), 0.01)
			d.player.toggle_flashlight(1)
		"bridge":
			fig.queue_free()
			_enter_bridge_instant()
		_:
			d.set_clock(Game.START_CLOCK)
			d.player.teleport(Transform3D(Basis(), START))


func run() -> void:
	match Game.checkpoint:
		"chase":
			await _chase_retry()
		"bridge":
			await _scene_03_end()
		_:
			await _scene_01()


# =========================================================================================
# SCENE 01 · 마지막 점검
# =========================================================================================
func _scene_01() -> void:
	Snd.set_ambience("amb_night_loop", -2.0, 3.0)
	Snd.set_beds(true)
	d.player.controls_enabled = false
	await d.ui.fade_to(0.0, 2.2)
	d.ui.place_card(["A국제공항 터미널", "AM 02:17", "정상 근무"], 3.5)
	d.player.controls_enabled = true
	d.ui.hud.show_key_hints(25.0)
	_door_use.prompt = "문 열기"
	_door_use.enabled = true
	await d.wait(1.2)
	d.objective("태블릿으로 점검 목록 확인하기  [Tab]")
	# nothing says what to do (the tablet's checklist does, if you look): the moment you set off — or after a while
	# anyway — a cart, rattling, just beyond the door, and it keeps on, a little ahead of you, all the way to the
	# baggage hall
	var from := d.player.global_position
	var t0 := Time.get_ticks_msec()
	await d.until(func(): return d.ui.modal == "" and (d.player.global_position.distance_to(from) > 1.5 or Time.get_ticks_msec() - t0 > 10000))
	d.objective("수하물 운송 설비 확인하기")
	d.guide("cart_rattle_loop", CART_PATH, 2.0, 6.0, 3.6)
	await d.wait(2.4)
	if not d.player.flashlight_on:
		d.player.toggle_flashlight(1)
	Events.notify.emit("[F] 손전등을 켜고 끌 수 있습니다.", "info")
	d.objective("소리가 난 곳 확인하기")
	await d.until(func(): return d.player.global_position.z < -24.0)
	d.set_clock(2 * 60 + 18)
	await d.until(func(): return d.player.global_position.z < -38.5)
	await _scene_02()


## [E] on the office door from inside: it opens (and swings shut by itself once you are up the passage).
func _door_pressed() -> void:
	if _door_open:
		return
	_door_open = true
	_door_use.enabled = false
	Snd.play_at("door_heavy", SEC_DOOR + Vector3(-0.3, 1.0, 0), -10.0, 1.15, 5.0)
	d.terminal.swing_sec_door(84.0, 1.1)


# =========================================================================================
# SCENE 02 · 형체
# =========================================================================================
func _build_scene_02() -> void:
	var t := d.terminal
	# a baggage trolley left at an angle, two cases still on it
	var cart := Props.luggage_cart(t, CART_POS, 0.55)
	Props.suitcase(cart, Color(0.22, 0.24, 0.28)).position = Vector3(0, 0.36, 0.05)
	var s2 := Props.suitcase(cart, Color(0.42, 0.12, 0.1), "", true)
	s2.position = Vector3(0.02, 0.62, -0.02)
	s2.rotation.y = 0.2
	# one panel over it still half-working, so it stands out of the dark
	_lamp = Geo.omni(t, FIGURE_POS + Vector3(-0.3, 3.0, 0.6), Color(0.85, 0.9, 1.0), 0.0, 6.0)
	_lamp.light_volumetric_fog_energy = 1.0
	_lamp_panel = Geo.box(t, Vector3(FIGURE_POS.x - 0.3, Terminal.BAG_H - 0.04, FIGURE_POS.z + 0.6), Vector3(1.6, 0.06, 0.16), Mats.emissive(Color(0.85, 0.9, 1.0), 0.0), false)
	fig = CrewFigure.create(t, FIGURE_POS, 0.0)
	fig.on_talk = _talk
	fig.tearing = true
	fig.caught.connect(_caught)
	# what it has torn so far, and one piece where you can still read part of the tag
	for i in 16:
		var a := randf() * TAU
		var r := randf_range(0.15, 1.1)
		var p := FIGURE_POS + Vector3(cos(a) * r, 0.003, sin(a) * r)
		Geo.box(t, p, Vector3(randf_range(0.03, 0.07), 0.002, randf_range(0.025, 0.05)), Mats.std(Color(0.9, 0.88, 0.8), 0.9), false, randf() * TAU)
	var tag := Node3D.new()
	t.add_child(tag)
	tag.position = FIGURE_POS + Vector3(0.55, 0.004, 0.75)
	tag.rotation.y = 0.4
	Geo.box(tag, Vector3.ZERO, Vector3(0.11, 0.003, 0.055), Mats.std(Color(0.93, 0.92, 0.86), 0.85), false)
	Geo.box(tag, Vector3(-0.04, 0.0022, 0), Vector3(0.018, 0.001, 0.05), Mats.std(Color(0.12, 0.3, 0.7), 0.7), false)
	var tl := Geo.label(tag, "…IGHT 000\nGATE 0", Vector3(0.012, 0.0026, 0), 0.0, 22, Color(0.08, 0.08, 0.1), 0.0011, false, "print")
	tl.rotation.x = -PI / 2
	var use := Interactable.create(tag, Vector3(0, 0.08, 0), Vector3(0.35, 0.2, 0.35), "종잇조각 살펴보기", func():
		_tag_seen = true
		Snd.play("page_flip", -12.0, 1.2)
		Events.notify.emit("찢긴 수하물 태그 — ‘…IGHT 000’ ‘GATE 0’", "info"))
	use.press_sound = ""


func _scene_02() -> void:
	d.set_clock(2 * 60 + 19)
	d.clear_objective()
	await d.until(func(): return _dist_to_fig() < 7.5)
	d.guide_stop(1.4)                                    # the rattle dies away by the cart: there it is
	# the air handling seems to drop away
	Snd.set_ambience("amb_night_loop", -16.0, 4.0)
	Snd.set_beds(false)
	d.objective("저 사람에게 말 걸기")
	var t0 := Time.get_ticks_msec()
	await d.until(func(): return _turn_now(t0))
	await _turn()


func _dist_to_fig() -> float:
	var a := d.player.global_position
	var b := fig.global_position
	return Vector2(a.x - b.x, a.z - b.z).length()


## When it turns: you try to see its face (walk round it, or come right up with the light on it after speaking),
## or you come too close, or you hang about near it long enough (sooner once it would not answer you).
func _turn_now(t0: int) -> bool:
	var dist := _dist_to_fig()
	var rel := d.player.global_position - fig.global_position
	rel.y = 0.0
	var behind := fig.global_basis.z
	var off_back := rad_to_deg(Vector2(rel.x, rel.z).angle_to(Vector2(behind.x, behind.z)))
	if dist < 1.6:
		return true
	if dist < 4.5 and absf(off_back) > 55.0:
		return true
	if _talked and dist < 3.0 and d.player.flashlight_on and d.player.facing_dot(fig.head_position()) > 0.9:
		return true
	return dist < 8.0 and Time.get_ticks_msec() - t0 > (30000 if _talked else 45000)


## [E] speaks to it: it goes still, as if listening, then tears again, louder.
func _talk() -> void:
	fig.hush(1.4 if _talked else 2.2)
	if _talked:
		return
	_talked = true
	fig.interactable.prompt = "다시 말 걸기"
	await d.wait(3.2)
	d.objective("손전등으로 얼굴 확인하기")


## The turn (SCENE 02's last beat): the light comes up to the face, everything goes quiet, and then the joints.
func _turn() -> void:
	d.clear_objective()
	if not d.player.flashlight_on:
		d.player.toggle_flashlight(1)
	Snd.set_ambience("", 0.8)
	var yaw := fig.face_yaw_to(d.player.global_position)
	await fig.turn_around(yaw)
	Snd.play("stinger_hit", -3.0)
	Snd.set_tension(0.85)
	d.player.add_shake(0.45)
	await d.wait(0.5)
	Game.set_checkpoint("chase")
	await _chase()


# =========================================================================================
# SCENE 03 · 도주
# =========================================================================================
func _chase_retry() -> void:
	Snd.set_tension(0.85)
	d.player.controls_enabled = false
	await d.ui.fade_to(0.0, 0.6)
	d.player.controls_enabled = true
	await _chase()


func _chase() -> void:
	var t := d.terminal
	t.set_zone_light("secoffice", false, true)
	_door_open = false
	t.remove_security_door()                             # your office's door is gone from its wall
	_fire_to_gate0()                                     # and the locked doors at the passage's end are GATE 0
	d.cutscene(false)
	d.objective("도망쳐라")
	Events.notify.emit("[SHIFT] 달리기", "alert")
	await d.wait(0.7)
	_crumb = d.player.global_position
	fig.trail.clear()
	fig.speed = 0.0
	fig.chase(d.player)
	_chasing = true
	_chase_t = 0.0
	await d.until(func(): return _door_hit or d.dead)
	if d.dead:
		return
	await _through_the_door()


func _physics_process(delta: float) -> void:
	_flicker_lamp(delta)
	# the office door you left open swings shut behind you once you are up the passage
	if _door_open and not _chasing:
		var q := d.player.global_position
		if q.x > -12.2 and q.distance_to(SEC_DOOR) > 4.5:
			_door_open = false
			d.terminal.swing_sec_door(0.0, 1.3)
			Snd.play_at("door_heavy", SEC_DOOR + Vector3(0.2, 1.0, 0), -14.0, 1.3, 5.0)
	if not _chasing or fig == null:
		return
	_chase_t += delta
	var p := d.player.global_position
	if not _near_door and p.z > FIRE_DOOR.z - 7.0 and p.x < -10.0:
		_near_door = true                                # running into it does nothing: the order says to open it
		d.objective("문 열고 나가기")
	if p.distance_to(_crumb) > 0.45:
		_crumb = p
		fig.trail.append(p)
	# a little under your running pace, steady: flat out you gain on it slowly, falter or look back and it gains on
	# you (it no longer eases off when it is close); and it never lets you get far ahead
	var dist := Vector2(p.x - fig._pos.x, p.z - fig._pos.z).length()
	var want := 4.0
	if _chase_t < 1.3:
		want = 1.2
	elif dist > 9.0:
		want = 5.0
	fig.speed = move_toward(fig.speed, want, delta * 3.5)


## The failing panel over the figure: mostly a dim glow, now and then a stutter or a few seconds dark.
func _flicker_lamp(delta: float) -> void:
	if _lamp == null or not is_instance_valid(_lamp):
		return
	_lamp_t -= delta
	if _lamp_t > 0.0:
		return
	var k := 0.0
	var r := randf()
	if r < 0.55:
		k = randf_range(0.7, 1.0)
		_lamp_t = randf_range(0.4, 1.6)
	elif r < 0.85:
		k = randf_range(0.0, 0.3)
		_lamp_t = randf_range(0.03, 0.09)
	else:
		_lamp_t = randf_range(0.6, 2.2)
	_lamp.light_energy = 0.55 * k
	(_lamp_panel.material_override as StandardMaterial3D).emission_energy_multiplier = 1.6 * k
	if k < 0.3 and randf() < 0.3:
		Snd.play_at("flicker_zap", _lamp.global_position, -20.0, randf_range(1.1, 1.4), 4.0)


## The staff passage's far end on the strip, where the glass partition was: a pair of steel fire doors (baked-enamel
## leaves, wired-glass lights, push bars, closers, 방화문 plates) under an exit sign, shut and locked; you cannot see
## past them (behind them, where the strip should be, there is only black). In the chase they become GATE 0
## (_fire_to_gate0).
func _build_fire_door() -> void:
	var t := d.terminal
	t.shutters.baggage.open(true)
	t.shutters.baggage.visible = false
	var root := Node3D.new()
	root.name = "FireDoor"
	t.add_child(root)
	root.position = FIRE_DOOR                            # local -Z = the passage, +Z = the strip
	var frame := Mats.std(Color(0.22, 0.23, 0.25), 0.45, 0.6)
	# steel frame in the 1.5 x 2.4 opening, a steel transom panel over the leaves
	for sx in [-1.0, 1.0]:
		Geo.box(root, Vector3(sx * 0.72, 1.08, 0), Vector3(0.06, 2.16, 0.42), frame, false)
	Geo.box(root, Vector3(0, 2.13, 0), Vector3(1.5, 0.06, 0.42), frame, false)
	Geo.box(root, Vector3(0, 2.28, 0), Vector3(1.5, 0.24, 0.1), FireDoor.paint(), false)
	_fire_l = _fire_leaf(root, -1.0)
	_fire_r = _fire_leaf(root, 1.0)
	_fire_block = Geo.blocker(root, Vector3(0, 1.2, 0), Vector3(1.5, 2.4, 0.42))
	_fire_use = Interactable.create(root, Vector3(0, 1.1, -0.12), Vector3(1.4, 2.1, 0.4), "문 열기", _fire_pressed)
	_fire_use.press_sound = ""
	# over it, where the EXIT light would be
	var sign := Node3D.new()
	root.add_child(sign)
	sign.position = Vector3(0, 2.7, -0.2)                # on the wall's passage face, under the passage ceiling
	Geo.box(sign, Vector3(0, 0, -0.035), Vector3(0.92, 0.3, 0.07), Mats.std(Color(0.86, 0.87, 0.85), 0.5), false)
	_fire_face = Geo.box(sign, Vector3(0, 0, -0.072), Vector3(0.85, 0.24, 0.004), Mats.std(Color(0.06, 0.13, 0.08), 0.3), false)
	var l := Geo.label(sign, "GATE  0", Vector3(0, 0, -0.076), PI, 64, Color(0.96, 1.0, 0.96), 0.004, false, "sign")
	Geo.fit(l, 0.72, 0.19)
	l.set_meta("no_fit", true)
	l.visible = false
	_fire_gate0.append(l)
	_fire_glow = Geo.omni(root, Vector3(0, 2.3, -0.8), Color(0.5, 1.0, 0.65), 0.0, 5.0)
	_fire_glow.light_volumetric_fog_energy = 0.6
	# behind it, where the strip should be, a lined vestibule the leaves swing into: black while they are shut, and
	# when they burst open its lining shows the boarding bridge (PortalView) — the doorway opens onto the corridor you
	# then fall into, its blank south wall standing where the doors are
	var b := d.bridge
	var dst := Transform3D(b.global_basis.orthonormalized() * Basis(Vector3.UP, PI), b.to_global(Vector3.ZERO))
	var env: Environment = null
	for we: WorldEnvironment in d.world.find_children("*", "WorldEnvironment", true, false):
		env = we.environment
	_portal = PortalView.create(root, Transform3D(Basis(), FIRE_DOOR), dst, d.player.camera, env)
	var lining := _portal.surface_material()
	Geo.box(root, Vector3(0, 1.25, 1.95), Vector3(1.9, 2.5, 0.05), lining, false)
	for sx in [-1.0, 1.0]:
		Geo.box(root, Vector3(sx * 0.95, 1.25, 1.07), Vector3(0.05, 2.5, 1.76), lining, false)
	Geo.box(root, Vector3(0, 2.5, 1.07), Vector3(1.9, 0.05, 1.76), lining, false)
	Geo.box(root, Vector3(0, 0.004, 1.07), Vector3(1.9, 0.008, 1.76), lining, false)


## One leaf (FireDoor.leaf) on a hinge node at its jamb (side -1 = west, +1 = east; turning `side` x angle opens it
## away from the passage), with its half of the GATE 0 stencil (hidden until the chase).
func _fire_leaf(root: Node3D, side: float) -> Node3D:
	var w := 0.685
	var hinge := FireDoor.leaf(root, side, -1.0, side * 0.69, w, 2.07)
	var c := -side * w * 0.5                             # the leaf's middle, from its hinge
	# stencilled across the pair at eye height, read from the passage: GATE on the left leaf, 0 on the right
	var st := Geo.label(hinge, "GATE" if side > 0.0 else "0", Vector3(c - side * 0.04, 1.33, -0.027), PI, 96,
		Color(0.9, 0.9, 0.86), 0.0035, false, "print")
	Geo.fit(st, w - 0.2, 0.17)
	st.set_meta("no_fit", true)
	st.visible = false
	_fire_gate0.append(st)
	return hinge


## [E] on the fire doors: locked until the chase — the push bar goes down and the leaves only knock against the latch;
## in the chase they are the way out.
func _fire_pressed() -> void:
	if _chasing:
		_door_hit = true
		return
	var now := Time.get_ticks_msec()
	if now - _rattle_at < 900:
		return
	_rattle_at = now
	Snd.play_at(Snd.variant("door_rattle"), FIRE_DOOR + Vector3(0, 1.0, -0.1), -2.0, randf_range(0.95, 1.05), 5.0)
	FireDoor.jiggle([_fire_l, _fire_r], -1.0)


## The chase: the locked doors at the passage's end are GATE 0 now — the sign over them lights up green with it, it is
## stencilled across the leaves — and they open.
func _fire_to_gate0() -> void:
	_fire_face.material_override = Mats.emissive(Color(0.1, 0.78, 0.36), 2.2)
	_fire_glow.light_energy = 0.24
	for n in _fire_gate0:
		n.visible = true
	_fire_use.prompt = "문 열고 나가기"


## Caught: no face, no game-over screen — black at once and the thing screaming in the dark, then you are back at the
## last save point (checkpoint "chase": it has just turned and is about to come for you).
func _caught() -> void:
	_chasing = false
	d.dead = true                                        # no pause menu while it happens
	d.cutscene(true)
	d.player.controls_enabled = false
	d.ui.hud.hide_subtitle()
	d.ui.cut_to(1.0)
	fig.stop_chase()
	Snd.stop_all_world()
	Snd.play("monster_scream", -5.0, 1.0, "SFX")
	await d.wait(2.2)
	Game.restart_checkpoint()


## You shove the fire doors open — both leaves fly back into the dark — and stumble through, the floor coming up at
## you. You land somewhere that is not the strip.
func _through_the_door() -> void:
	_chasing = false
	fig.chasing = false                                  # it stops where it is; its rattle goes on until the door
	_fire_use.enabled = false
	d.clear_objective()
	d.cutscene(true)
	# past the doors it is already the boarding bridge, lit, its south wall out of the way of the view in
	d.bridge.zone.set_on(true, true)
	d.bridge.zone.night_dim = 0.7
	d.bridge.south_wall.visible = false
	_portal.eye = d.player.camera
	_portal.set_active(true)
	var p := d.player
	# one run at it, no stopping: in line with the doorway (unless you already are) and straight on through, at a
	# sprint; the leaves burst open the moment your shoulder reaches them
	_fire_block.collision_layer = 0
	var pos := p.global_position
	var pts := [FIRE_DOOR + Vector3(0.0, 0.05, 1.05)]
	if FIRE_DOOR.z - pos.z > 0.9 or absf(pos.x - FIRE_DOOR.x) > 0.3:
		pts.push_front(FIRE_DOOR + Vector3(0.0, 0.05, -0.62))
	p.walk_path(pts, 4.4)
	p.glance(FIRE_DOOR + Vector3(0.0, 1.35, 1.2), 9.0)
	var t0 := Time.get_ticks_msec()
	await d.until(func():
		var q := p.global_position
		return (FIRE_DOOR.z - q.z < 0.5 and absf(q.x - FIRE_DOOR.x) < 0.4) or Time.get_ticks_msec() - t0 > 1500)
	Snd.play_at("door_heavy", FIRE_DOOR + Vector3(0, 1.0, -0.2), 3.0, 1.0, 6.0)
	Snd.play_at("door_slam", FIRE_DOOR + Vector3(0, 1.0, 0.6), -6.0, 1.15, 6.0)
	p.add_shake(0.5)
	var shove := create_tween().set_parallel(true)
	shove.tween_property(p, "view_roll", -0.14, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	shove.tween_property(p, "view_drop", 0.14, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for leaf: Array in [[_fire_l, -1.0], [_fire_r, 1.0]]:
		var swing := create_tween()
		swing.tween_property(leaf[0], "rotation:y", leaf[1] * deg_to_rad(97.0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		swing.tween_property(leaf[0], "rotation:y", leaf[1] * deg_to_rad(84.0), 0.35).set_trans(Tween.TRANS_SINE)
	await d.wait(0.12)
	# a foot catches the threshold: head first into the dark
	p.glance(Vector3.INF)
	p.look_at_point(FIRE_DOOR + Vector3(0.0, 0.0, 1.5), 0.36)
	var fall := create_tween().set_parallel(true)
	fall.tween_property(p, "view_drop", 1.0, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(p, "view_roll", 0.4, 0.36).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await d.wait(0.34)
	# the impact: black, the rattle behind you gone
	d.ui.cut_to(1.0)
	Snd.set_tension(0.0)
	Snd.stop_all_world()
	Snd.play("body_fall", 0.0, 1.0, "SFX")
	fig.queue_free()
	fig = null
	_enter_bridge_instant()
	p.view_drop = 1.3
	p.view_roll = 0.45
	p.set_look(0.0, deg_to_rad(-38.0))                   # on your side, the carpet in the flashlight
	p.stamina = 0.0
	p.eyes_script = 1.0                                  # out for a moment
	d.ui.hud.set_visible_all(false)                      # (it would sit over the eyelids) until you are up
	await d.wait(1.5)
	d.ui.cut_to(0.0)                                     # from here the eyelids are what is dark
	await _come_round()
	await _down_inside()


## Coming round on the floor: the eyes flutter open — a slit, shut again, half open, a blink or two, open — while the
## head comes up a little off the carpet and the eyes find the corridor ahead.
func _come_round() -> void:
	var p := d.player
	var lift := create_tween().set_parallel(true)
	lift.tween_property(p, "view_drop", 1.15, 2.6).set_trans(Tween.TRANS_SINE)
	lift.tween_property(p, "view_roll", 0.36, 2.6).set_trans(Tween.TRANS_SINE)
	p.look_at_point(d.bridge.to_global(Vector3(0.3, 0.3, -7.0)), 2.6)
	var lids := create_tween()
	for step: Array in [[0.74, 0.45], [0.97, 0.2], [0.97, 0.35], [0.45, 0.55], [0.9, 0.12], [0.3, 0.3], [0.85, 0.1], [0.0, 0.55]]:
		lids.tween_property(p, "eyes_script", step[0], step[1]).set_trans(Tween.TRANS_SINE)
	await lids.finished
	p.eyes_script = -1.0


## Into the corridor at once, just inside its south wall (where the door should be), running forward.
func _enter_bridge_instant() -> void:
	var b := d.bridge
	b.south_wall.visible = true
	if _portal:
		_portal.set_active(false)
	d.player.teleport(Transform3D(Basis(), b.entry_point()))
	d.player.set_look(0.0, deg_to_rad(-12.0))
	d.player.zone_override = "jetbridge"
	d.ui.hud.set_clock_override("--:--")
	if not d.player.flashlight_on:
		d.player.toggle_flashlight(1)
	b.zone.set_on(true, true)
	b.zone.night_dim = 0.7
	Game.set_checkpoint("bridge")


## Debug checkpoint "bridge": the same landing, shown from a stumble inside the corridor.
func _scene_03_end() -> void:
	var b := d.bridge
	var p := d.player
	p.stamina = 0.0                                       # out of breath on the floor
	d.ui.fade_to(0.0, 0.2)
	p.walk_to(b.to_global(Vector3(0.1, 0.05, -2.1)), 3.4)
	p.look_at_point(b.to_global(Vector3(0.4, 0.0, -3.0)), 0.38)
	var fall := create_tween().set_parallel(true)
	fall.tween_property(p, "view_drop", 1.3, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(p, "view_roll", 0.45, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await d.wait(0.4)
	Snd.play("body_fall", 0.0, 1.0, "SFX")
	p.add_shake(0.7)
	await _down_inside()


## On the corridor floor where you fell, face down the way you were running, out of breath. Still down, you look back
## over your shoulder for the doors you came through: there is only wall. Then SCENE 04: you look ahead again as you
## get up.
func _down_inside() -> void:
	var b := d.bridge
	var p := d.player
	d.cutscene(true)
	await d.wait(0.8)
	# still down, you look back over your shoulder for the doors you came through: wall
	p.look_at_point(b.to_global(Vector3(0.0, 1.1, 0.0)), 1.1)
	var turn := create_tween().set_parallel(true)
	turn.tween_property(p, "view_drop", 1.1, 1.1).set_trans(Tween.TRANS_SINE)
	turn.tween_property(p, "view_roll", -0.12, 1.1).set_trans(Tween.TRANS_SINE)
	await d.wait(1.0)
	Snd.play("stinger_soft", -10.0)
	await d.wait(1.8)
	await _scene_04()                                    # and you look ahead again as you get up


# =========================================================================================
# SCENE 04 · 사라진 문
# =========================================================================================
func _scene_04() -> void:
	var b := d.bridge
	var p := d.player
	d.cutscene(true)
	Snd.set_ambience("amb_night_loop", -20.0, 6.0)
	# getting up — onto a knee, then the feet — facing a corridor that is no security office: glass down both sides
	# and nothing behind the glass
	var up := create_tween()
	up.tween_property(p, "view_drop", 0.55, 0.9).set_trans(Tween.TRANS_SINE)
	up.parallel().tween_property(p, "view_roll", 0.05, 0.9).set_trans(Tween.TRANS_SINE)
	up.tween_interval(0.3)
	up.tween_property(p, "view_drop", 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	up.parallel().tween_property(p, "view_roll", 0.0, 1.2).set_trans(Tween.TRANS_SINE)
	p.look_at_point(b.to_global(Vector3(0, 1.3, -JetBridge.LENGTH)), 1.6)
	await up.finished
	p.view_drop = 0.0
	p.view_roll = 0.0
	d.cutscene(false)
	d.ui.hud.set_visible_all(true)
	d.ui.tablet.set_target("", "", Vector3.INF)
	_tablet_lost()                                       # if you look at the tablet in here
	_door_watch()
	# a second after you set off, the chime: the PA from the far end (not waited for), and as it starts boarding
	# FLIGHT 000 the board over the door lights up
	var stood := p.global_position
	await d.until(func(): return _ended or Vector2(p.global_position.x - stood.x, p.global_position.z - stood.z).length() > 0.3)
	await d.wait(1.0)
	if _ended:
		return
	d.pa_at(b.pa_point(), ["pa_v2_attention", "pa_v2_boarding_start"],
		["승객 여러분께 안내 말씀드립니다.", "Flight 000편의 탑승을 시작하겠습니다."], 1.4)
	await d.until(func(): return _ended or d.pa_clip == "pa_v2_boarding_start")
	if _ended:
		return
	await d.wait(1.0)
	b.set_board(JetBridge.BOARD_BOARDING)
	_board_on = true
	_door_objective()
	await d.until(func(): return _ended or d.pa_clip != "pa_v2_boarding_start")
	await d.wait(1.6)
	if not _ended:
		await _call_in()


## You call it in on the way (the inspector's words are not shown: the radio keys up, then the answer). Nothing waits
## for it: pick up the key and it is cut off.
func _call_in() -> void:
	Snd.play("radio_on", -8.0, 1.0, "SFX")
	await d.wait(1.6)
	if _ended:
		return
	Snd.play("radio_off", -10.0, 1.0, "SFX")
	await d.wait(0.6)
	if _ended:
		return
	await d.radio("담당자", "……현재 위치를 다시 확인해 주세요.")
	await d.wait(1.2)
	if _ended:
		return
	await d.radio("담당자", "……", 2.6)
	if _ended:
		return
	await d.radio("담당자", "그쪽으로 들어가시면 안 됩니다.", 3.2)
	if _ended:
		return
	Snd.radio_static(true)
	await d.wait(0.5)
	Snd.radio_static(false)
	Snd.play("glitch", -12.0, 0.7, "SFX")


## The tablet, if you look at it in here: the plan, but no you on it — then not even the plan. Nothing waits for it.
func _tablet_lost() -> void:
	await d.until(func(): return _ended or d.ui.modal == "tablet")
	if _ended:
		return
	d.ui.tablet_locked = true
	d.ui.tablet._show_tab("map", false)
	await d.wait(0.6)
	await d.ui.tablet.lose_signal()
	await d.wait(1.0)
	d.ui.tablet_locked = false


## Up at the door: chained shut. [E] only rattles it — and the key lies on the carpet right in front of it.
func _door_watch() -> void:
	var b := d.bridge
	await d.until(func(): return _ended or d.player.global_position.distance_to(b.door_front()) < 2.4)
	_at_door = true
	_door_objective()


func _door_objective() -> void:
	if _ended:
		return
	if _door_tried:
		d.objective("열쇠 찾기")
	elif _at_door:
		d.objective("문 열기")
	elif _board_on:
		d.objective("앞으로 나아가기")


func _gate_pressed() -> void:
	var now := Time.get_ticks_msec()
	if now - _rattle_at < 900:
		return
	_rattle_at = now
	d.bridge.rattle()
	_door_tried = true
	_door_objective()


## A small brass key on the carpet before the gate door, catching the light.
func _place_key() -> void:
	key_node = Node3D.new()
	key_node.name = "GateKey"
	d.bridge.add_child(key_node)
	key_node.position = KEY_LOCAL
	key_node.rotation.y = 0.7
	key_node.scale = Vector3.ONE * 1.4                  # nothing points you to it: big enough to catch the eye
	var brass := Mats.std(Color(0.78, 0.6, 0.26), 0.3, 0.9)
	var bow := Geo.cyl(key_node, Vector3(-0.035, 0.004, 0), 0.016, 0.004, brass, false, 20)
	Geo.cyl(bow, Vector3(0, 0.0005, 0), 0.007, 0.0045, Mats.get_mat("black"), false, 12)     # the ring's hole
	Geo.box(key_node, Vector3(0.012, 0.004, 0), Vector3(0.06, 0.004, 0.008), brass, false)
	for i in 3:
		Geo.box(key_node, Vector3(0.025 + i * 0.011, 0.004, 0.007), Vector3(0.006, 0.004, 0.008), brass, false)
	var glint := Geo.omni(key_node, Vector3(0, 0.25, 0), Color(1.0, 0.9, 0.7), 0.35, 1.2)
	glint.light_volumetric_fog_energy = 0.0
	var use := Interactable.create(key_node, Vector3(0, 0.1, 0), Vector3(0.4, 0.3, 0.4), "열쇠 줍기", _take_key)
	use.press_sound = ""


## The key in your hand, and black at once: the end of the prologue (SCENE 05, the title, follows straight on; the main
## story opens at this door with the key).
func _take_key() -> void:
	if _ended:
		return
	_ended = true
	d.ui.cut_to(1.0)
	d.cutscene(true)
	d.clear_objective()
	d.pa_stop()
	Snd.radio_static(false)
	d.ui.hud.hide_subtitle()
	Snd.stop_all_world()
	Snd.play("key_pickup", -4.0)
	Snd.play("sub_boom", -10.0, 0.7)
	Game.add_item("key_gate")
	key_node.queue_free()
	key_node = null
	await d.wait(0.6)
	Game.finish_prologue()
