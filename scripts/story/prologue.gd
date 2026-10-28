class_name Prologue
extends StoryScript
## The cold open (Gate 0 v2 — 오프닝 시나리오, SCENE 01–04).
##
## 01 마지막 점검 — A국제공항 터미널, AM 02:17. The last checks of the night from the lobby: lights and PA are done, the
##    baggage system still needs a look. On the way, a baggage cart rattling somewhere it should not be.
## 02 형체 — down the dark staff passage into the closed baggage hall (02:19): a cart left askew and someone in a
##    cabin-crew uniform with their back to you, tearing baggage tags. Say something, try to see the face — it turns,
##    joint by joint.
## 03 도주 — run. SECURITY OFFICE →. Stop at the door and push it open ([E]; running past does nothing) — you fall in:
##    a wide boarding-bridge connector, black glass.
## 04 사라진 문 — on the floor you turn to shut the door: wall. Getting up you call it in on the radio ("그쪽으로 들어가시면
##    안 됩니다"), the tablet has lost you, the wall again, the PA starts boarding FLIGHT 000 and the board at the end
##    lights up: FLIGHT 000 — GATE 0. Forward, and black. (SCENE 05: the title.)
##
## Checkpoints: "" (the start), "chase" (caught: back to the moment it starts to move), "bridge" (debug: inside).

const START := Vector3(-2.7, 0.05, 7.6)              # beside the broadcast desk, the PA just checked
const PASSAGE_IN := Vector3(-11.2, 1.2, -9.4)        # the staff passage's mouth on the strip
const PASSAGE_END := Vector3(-11.2, 1.2, -39.0)
const CART_SOUND := Vector3(-14.0, 0.6, -46.5)
const FIGURE_POS := Vector3(-12.7, 0.0, -45.4)
const CART_POS := Vector3(-13.1, 0.0, -46.8)
const CHASE_SPAWN := Vector3(-12.2, 0.05, -42.8)
const SEC_DOOR := Vector3(-12.25, 0.0, -16.0)        # on the passage's west wall, facing into it
const SIGN_TOP := Vector3(-11.25, 3.0, -25.5)
const CHECKLIST := [["조명 설비", "ok"], ["안내방송 설비", "ok"], ["수하물 운송 설비", "check"], ["직원 통로", "todo"]]

var fig: CrewFigure
var _talked := false
var _tag_seen := false
var _chasing := false
var _chase_t := 0.0
var _crumb := Vector3.INF
var _door_hit := false
var _leaf: Node3D                # the SECURITY OFFICE door's leaf (hinge node)
var _door_block: StaticBody3D
var _door_use: Interactable
var _sign_passed := false
var _wall_felt := false
var _cart_on := false
var _cart_t := 0.0
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
	_build_scene_02()
	match Game.checkpoint:
		"chase":
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
	await d.wait(1.2)
	await d.say("……이제 마지막 구역이네.")
	d.objective("태블릿으로 점검 목록 확인하기  [Tab]")
	await d.until(func(): return d.ui.modal == "tablet")
	await d.until(func(): return d.ui.modal == "")
	d.objective("수하물 운송 설비 확인하기", PASSAGE_IN)
	# the moment you set off for it: a cart, rattling, from the closed side of the building
	var from := d.player.global_position
	var t0 := Time.get_ticks_msec()
	await d.until(func(): return d.player.global_position.distance_to(from) > 3.0 or Time.get_ticks_msec() - t0 > 7000)
	_cart_burst()
	d.cutscene(true)
	await d.wait(0.5)
	d.player.glance(PASSAGE_IN, 2.0)
	d.caption("달그락…… 덜컹…… 달그락……", 3.4)
	await d.wait(3.6)
	_cart_burst()
	d.caption("……덜컹…… 달그락……", 2.8)
	await d.wait(2.4)
	await d.say("……이 시간에 저쪽을 쓸 직원은 없는데.")
	d.player.toggle_flashlight(1)
	await d.wait(0.6)
	d.player.glance(Vector3.INF)
	d.cutscene(false)
	Events.notify.emit("[F] 손전등을 켜고 끌 수 있습니다.", "info")
	d.objective("소리가 난 곳 확인하기", PASSAGE_IN)
	_cart_on = true
	_cart_t = 4.0
	await d.until(func(): return d.player.global_position.z < -9.6 and d.player.global_position.x < -9.8)
	d.objective("소리가 난 곳 확인하기", PASSAGE_END)
	await d.until(func(): return d.player.global_position.z < -24.0)
	_cart_on = false                                     # it stops, and the passage goes quiet
	d.set_clock(2 * 60 + 18)
	await d.until(func(): return d.player.global_position.z < -38.5)
	await _scene_02()


func _cart_burst() -> void:
	Snd.play_at(Snd.variant("cart_rattle"), CART_SOUND, 4.0, randf_range(0.94, 1.04), 12.0, 90.0)


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
		d.say("수하물 태그 조각이다. ‘…IGHT 000’, ‘GATE 0’…… 나머지는 찢겨 나갔다."))
	use.press_sound = ""


func _scene_02() -> void:
	d.set_clock(2 * 60 + 19)
	d.clear_objective()
	await d.until(func(): return _dist_to_fig() < 7.5)
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
## or you come too close, or you hang about long enough after it would not answer.
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
	return _talked and dist < 8.0 and Time.get_ticks_msec() - t0 > 30000


func _talk() -> void:
	if _talked:
		await d.say("……저기요?")
		return
	_talked = true
	fig.interactable.prompt = "다시 말 걸기"
	await d.say("저기요…… 여기는 출입 통제 구역입니다.")
	await d.wait(1.4)
	d.caption("찌익……", 1.6)
	await d.wait(1.0)
	d.objective("손전등으로 얼굴 확인하기")


## The turn (SCENE 02's last beat): the light comes up to the face, everything goes quiet, and then the joints.
func _turn() -> void:
	d.clear_objective()
	d.cutscene(true)
	if not d.player.flashlight_on:
		d.player.toggle_flashlight(1)
	d.player.glance(fig.head_position(), 3.0)
	Snd.set_ambience("", 0.8)
	var yaw := fig.face_yaw_to(d.player.global_position)
	await fig.turn_around(yaw)
	Snd.play("stinger_hit", -3.0)
	Snd.set_tension(0.85)
	d.player.add_shake(0.45)
	d.caption("뚝……", 1.2)
	await d.wait(0.5)
	d.player.glance(Vector3.INF)
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
	_build_escape()
	d.cutscene(false)
	d.objective("도망쳐라")
	Events.notify.emit("[SHIFT] 달리기", "alert")
	d.caption("달그락. 덜컹. 달그락.", 2.4)
	await d.wait(0.7)
	_crumb = d.player.global_position
	fig.trail.clear()
	fig.speed = 0.0
	fig.chase(d.player)
	_chasing = true
	_chase_t = 0.0
	d.terminal.shutters.baggage.close()                  # the way you came in is shut: the door is the only way
	await d.until(func(): return _door_hit or d.dead)
	if d.dead:
		return
	await _through_the_door()


## SECURITY OFFICE →: a sign over the passage and a steel staff door in its west wall, there now that you need them.
## The door is built here so it can swing: it takes the doorway Terminal left in the wall (passage_plug), its leaf
## hangs on the south jamb and opens away from you into a dark lobby behind.
func _build_escape() -> void:
	var t := d.terminal
	LevelKit.hanging_sign(t, SIGN_TOP, 0.0, "SECURITY OFFICE  →\n보안실", 1.9, "")
	if t.passage_plug and is_instance_valid(t.passage_plug):
		t.passage_plug.queue_free()
	var door := Node3D.new()
	door.name = "SecurityDoor"
	t.add_child(door)
	door.position = Vector3(SEC_DOOR.x - 0.15, 0.0, SEC_DOOR.z)     # on the wall's centre line; local +X = the passage
	# nothing but dark behind it
	var black := Mats.get_mat("black")
	Geo.box(door, Vector3(-0.95, -0.02, 0), Vector3(1.6, 0.04, 1.6), black)
	Geo.box(door, Vector3(-0.95, 2.4, 0), Vector3(1.6, 0.1, 1.6), black, false)
	Geo.box(door, Vector3(-1.8, 1.2, 0), Vector3(0.1, 2.4, 1.6), black)
	for sz in [-1.0, 1.0]:
		Geo.box(door, Vector3(-0.95, 1.2, sz * 0.85), Vector3(1.6, 2.4, 0.1), black)
	# steel frame on the passage face
	var frame := Mats.std(Color(0.3, 0.32, 0.35), 0.4, 0.6)
	for sz in [-1.0, 1.0]:
		Geo.box(door, Vector3(0.17, 1.07, sz * 0.53), Vector3(0.07, 2.14, 0.07), frame, false)
	Geo.box(door, Vector3(0.17, 2.18, 0), Vector3(0.07, 0.07, 1.13), frame, false)
	# the leaf: push plate, a narrow wired-glass light, kick plate
	_leaf = Node3D.new()
	door.add_child(_leaf)
	_leaf.position = Vector3(0.1, 0, 0.49)
	var steel := Mats.std(Color(0.42, 0.45, 0.5), 0.5, 0.45)
	var metal := Mats.get_mat("metal")
	Geo.box(_leaf, Vector3(0, 1.05, -0.485), Vector3(0.045, 2.08, 0.96), steel, false)
	Geo.box(_leaf, Vector3(0.024, 1.5, -0.75), Vector3(0.006, 0.5, 0.13), Mats.std(Color(0.05, 0.06, 0.07), 0.15, 0.3), false)
	Geo.box(_leaf, Vector3(0.027, 1.08, -0.84), Vector3(0.008, 0.32, 0.1), metal, false)
	Geo.box(_leaf, Vector3(0.025, 0.14, -0.485), Vector3(0.004, 0.24, 0.9), metal, false)
	_door_block = Geo.blocker(door, Vector3(0.0, 1.07, 0), Vector3(0.3, 2.14, 1.0))
	var plate := Node3D.new()
	t.add_child(plate)
	plate.position = SEC_DOOR + Vector3(0.012, 1.55, 0.95)
	plate.rotation.y = PI / 2
	Geo.box(plate, Vector3.ZERO, Vector3(0.5, 0.2, 0.012), Mats.std(Color(0.16, 0.17, 0.19), 0.45, 0.3), false)
	Geo.fit(Geo.label(plate, "보안실  SECURITY OFFICE", Vector3(0, 0, 0.008), 0.0, 40, Color(0.95, 0.95, 0.92), 0.003), 0.44, 0.15).set_meta("no_fit", true)
	# only by hand: running past it does nothing, you have to stop and push it open
	_door_use = Interactable.create(door, Vector3(0.3, 1.1, 0.0), Vector3(0.4, 2.1, 1.1), "문 열고 들어가기", func():
		if _chasing:
			_door_hit = true)
	_door_use.press_sound = ""


func _physics_process(delta: float) -> void:
	_flicker_lamp(delta)
	if _cart_on:
		_cart_t -= delta
		if _cart_t <= 0.0:
			_cart_t = randf_range(3.6, 6.0)
			_cart_burst()
	if not _chasing or fig == null:
		return
	_chase_t += delta
	var p := d.player.global_position
	if not _sign_passed and p.z > SIGN_TOP.z - 1.5 and p.x < -10.0:
		_sign_passed = true                              # under SECURITY OFFICE →: the order names the door
		d.objective("보안실 문으로 피하기")
	if p.distance_to(_crumb) > 0.45:
		_crumb = p
		fig.trail.append(p)
	# never long out of earshot: slower when it is right on you, faster when you pull away
	var dist := Vector2(p.x - fig.global_position.x, p.z - fig.global_position.z).length()
	var want := 3.9
	if _chase_t < 1.3:
		want = 1.2
	elif dist > 9.0:
		want = 5.2
	elif dist < 3.5:
		want = 3.4
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


## You shove the door open — it swings in onto the dark — and stumble through it, the floor coming up at you. You land
## somewhere that is not the security office.
func _through_the_door() -> void:
	_chasing = false
	fig.chasing = false                                  # it stops where it is; its rattle goes on until the door
	_door_use.enabled = false
	d.clear_objective()
	d.cutscene(true)
	var p := d.player
	# one run at it, no stopping: in line with the doorway (unless you already are) and straight on through, at a
	# sprint; the leaf bursts open the moment your shoulder reaches it
	_door_block.collision_layer = 0
	var pos := p.global_position
	var pts := [SEC_DOOR + Vector3(-1.05, 0.05, 0.0)]
	if pos.x - SEC_DOOR.x > 0.9 or absf(pos.z - SEC_DOOR.z) > 0.25:
		pts.push_front(SEC_DOOR + Vector3(0.62, 0.05, 0.0))
	p.walk_path(pts, 4.4)
	p.glance(SEC_DOOR + Vector3(-1.2, 1.35, 0.0), 9.0)
	var t0 := Time.get_ticks_msec()
	await d.until(func():
		var q := p.global_position
		return (q.x - SEC_DOOR.x < 0.5 and absf(q.z - SEC_DOOR.z) < 0.4) or Time.get_ticks_msec() - t0 > 1500)
	Snd.play_at("door_heavy", SEC_DOOR + Vector3(0.2, 1.0, 0), 3.0, 1.25, 6.0)
	p.add_shake(0.5)
	var shove := create_tween().set_parallel(true)
	shove.tween_property(p, "view_roll", -0.14, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	shove.tween_property(p, "view_drop", 0.14, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var swing := create_tween()
	swing.tween_property(_leaf, "rotation:y", deg_to_rad(97.0), 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	swing.tween_property(_leaf, "rotation:y", deg_to_rad(84.0), 0.35).set_trans(Tween.TRANS_SINE)
	await d.wait(0.12)
	# a foot catches the threshold: head first into the dark
	p.glance(Vector3.INF)
	p.look_at_point(SEC_DOOR + Vector3(-1.5, 0.0, 0.05), 0.36)
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
	await d.wait(0.6)
	await d.ui.fade_to(0.0, 0.7)
	await _down_inside()


## Into the corridor at once, just inside its south wall (where the door should be), running forward.
func _enter_bridge_instant() -> void:
	var b := d.bridge
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


## On the corridor floor, out of breath: you twist round to shut the door behind you — your hand meets wall. Then
## SCENE 04: you get up, calling it in on the radio as you do.
func _down_inside() -> void:
	var b := d.bridge
	var p := d.player
	await d.wait(1.8)
	# roll over toward the door to slam it shut behind you
	p.look_at_point(b.to_global(Vector3(0.0, 0.6, 0.35)), 0.9)
	var turn := create_tween().set_parallel(true)
	turn.tween_property(p, "view_drop", 1.1, 0.9).set_trans(Tween.TRANS_SINE)
	turn.tween_property(p, "view_roll", -0.12, 0.9).set_trans(Tween.TRANS_SINE)
	await d.wait(1.0)
	Snd.play_at("wall_rub", b.to_global(Vector3(0.0, 0.6, 0.05)), -2.0, 1.15, 3.0)
	Snd.play("stinger_soft", -10.0)
	await d.wait(0.9)
	await d.say("……문이, 없어?")
	await d.wait(0.5)
	await _scene_04()


# =========================================================================================
# SCENE 04 · 사라진 문
# =========================================================================================
func _scene_04() -> void:
	var b := d.bridge
	var p := d.player
	d.cutscene(true)
	Snd.set_ambience("amb_night_loop", -20.0, 6.0)
	# getting up — onto a knee, then the feet — the radio already out, looking round a corridor that is no security
	# office: glass down both sides and nothing behind the glass
	var up := create_tween()
	up.tween_property(p, "view_drop", 0.6, 1.6).set_trans(Tween.TRANS_SINE)
	up.parallel().tween_property(p, "view_roll", 0.05, 1.6).set_trans(Tween.TRANS_SINE)
	up.tween_interval(1.4)
	up.tween_property(p, "view_drop", 0.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	up.parallel().tween_property(p, "view_roll", 0.0, 2.2).set_trans(Tween.TRANS_SINE)
	p.look_at_point(b.to_global(Vector3(0, 1.3, -JetBridge.LENGTH)), 1.8)
	await d.wait(1.2)
	Snd.play("radio_on", -8.0, 1.0, "SFX")
	p.glance(b.to_global(Vector3(-3.0, 1.5, -5.0)), 1.4)
	await d.say("여기 보안실이 아닙니다. 지금 제가 어디에 있는 거죠?")
	p.glance(b.to_global(Vector3(3.0, 1.5, -7.0)), 1.4)
	await d.radio("담당자", "……현재 위치를 다시 확인해 주세요.")
	p.glance(b.to_global(Vector3(0.0, 1.3, 0.3)), 2.0)          # back at the wall
	await d.say("출입문이 사라졌습니다. 제가 들어온 문이 없습니다.")
	await d.radio("담당자", "……", 2.6)
	await d.radio("담당자", "그쪽으로 들어가시면 안 됩니다.", 3.2)
	Snd.radio_static(true)
	await d.wait(0.5)
	Snd.radio_static(false)
	Snd.play("glitch", -12.0, 0.7, "SFX")
	d.caption("[무전이 끊긴다]", 2.0)
	await d.wait(1.2)
	p.glance(Vector3.INF)
	p.view_drop = 0.0
	p.view_roll = 0.0
	d.cutscene(false)
	# the tablet: the plan, but no you on it — then not even the plan
	d.ui.tablet.set_target("", "", Vector3.INF)
	d.objective("태블릿으로 현재 위치 확인하기  [Tab]")
	await d.until(func(): return d.ui.modal == "tablet")
	d.clear_objective()
	d.ui.tablet_locked = true
	d.ui.tablet._show_tab("map", false)
	await d.wait(0.6)
	await d.ui.tablet.lose_signal()
	await d.wait(1.0)
	d.ui.tablet_locked = false
	await d.until(func(): return d.ui.modal == "")
	await d.wait(0.6)
	# one more look at the wall: there is no way back
	var wall := Interactable.create(b, Vector3(0, 1.2, -0.12), Vector3(2.6, 2.0, 0.2), "벽 더듬기", func():
		Snd.play_at("wall_rub", d.player.global_position + d.player.forward() * 0.6, -4.0, randf_range(0.95, 1.05), 3.0)
		_wall_felt = true)
	wall.press_sound = ""
	d.objective("벽 다시 살펴보기", b.to_global(Vector3(0, 1.2, 0.0)))
	await d.until(func(): return _wall_felt)
	wall.enabled = false
	d.clear_objective()
	d.cutscene(true)
	await d.wait(0.5)
	await d.say("손잡이도, 문틈도…… 아무것도 없어.")
	await d.say("……돌아갈 길이 없어.")
	# the PA, from the far end
	d.player.look_at_point(b.to_global(Vector3(0, 1.6, -JetBridge.LENGTH)), 2.4)
	await d.wait(1.2)
	await d.pa_at(b.pa_point(), ["pa_v2_attention"], ["승객 여러분께 안내 말씀드립니다."])
	await d.wait(1.6)
	await d.pa_at(b.pa_point(), ["pa_v2_boarding_start"], ["Flight 000편의 탑승을 시작하겠습니다."])
	await d.wait(0.6)
	# the board at the end that was not there a moment ago
	b.set_board(JetBridge.BOARD_BOARDING)
	await d.wait(2.4)
	d.cutscene(false)
	d.objective("앞으로 나아가기")
	# on toward it until the board can be read, then black
	await d.until(func(): return b.to_local(d.player.global_position).z < -JetBridge.LENGTH + 11.0)
	# black
	d.clear_objective()
	d.cutscene(true)
	d.ui.cut_to(1.0)
	Snd.stop_all_world()
	Snd.play("sub_boom", -10.0, 0.7)
	await d.wait(2.4)
	Game.finish_prologue()
