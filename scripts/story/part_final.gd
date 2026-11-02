class_name PartFinal
extends StoryPart
## The last stretch. Check-in is done and security's glass slides open; the moment you start to move, feet behind you,
## running: the figure, for the first time since the prologue, coming out of the lounge after you. Through security and
## up the boarding corridor, and the corridor does not end: every so often the lights cut out for a moment and you are
## further back along it (the same 24 m comes round), it right behind you. Then it lets you through into the gate
## lounge and it is gone, and quiet. The middle of the window wall has opened: Gate 0, a long bridge, a door marked HOME.
## Behind it is your office, 02:17, as it was at the start, and the game goes back to the title.
## Caught: back at the device, the glass open, and it comes again.

const RUN_FROM := Vector3(1.2, 0.05, 9.0)        # where it comes from, behind you, out of the lounge
const MOVE_OFF := 1.2                            # how far you move before you hear it
const LOOP_FROM := -62.0                         # past here up the corridor (z) and you are...
const LOOP_STEP := 24.0                          # ...this far back: its windows and lights repeat every 24 m
const LOOPS := 4
const SPEED := 3.15                              # your run is 4.4, your walk 2.2
const CATCH_UP := 4.4
const FAR := 18.0
const ARRIVED_Z := -79.0                         # in the gate lounge: it stops
const CRUMB := 0.45

var fig: CrewFigure
var loops := 0
var ended := false
var _chasing := false
var _crumb := Vector3.INF


func _lights() -> void:
	var t := d.terminal
	for zn: Array in [["security", 0.5], ["corridor", 0.4], ["gates", 0.5]]:
		var z: LightZone = t.zones[zn[0]]
		z.night_dim = zn[1]
		z.erratic = 0.1
		z.set_on(true, true)
	t.shutters.security.open(true)
	t.shutters.corridor.open(true)
	t.shutters.gates.open(true)


func run() -> void:
	var p := d.player
	_lights()
	Game.set_checkpoint("final")
	d.objective("도망쳐라")
	var from := p.global_position
	await d.until(func(): return p.global_position.distance_to(from) > MOVE_OFF)
	Snd.play("stinger_hit", -6.0)
	Snd.set_tension(0.8)
	fig = CrewFigure.create(d.terminal, RUN_FROM, 0.0)
	fig.no_cart = true
	fig.step_db = 4.0
	fig.pose_broken(fig.face_yaw_to(p.global_position))
	fig.caught.connect(func(): ch.caught())
	fig.trail.clear()
	fig.speed = 0.0
	fig.chase(p)
	_crumb = p.global_position
	_chasing = true
	await d.until(func(): return p.global_position.z < ARRIVED_Z or d.dead)
	if d.dead:
		return
	_chasing = false
	fig.stop_chase()
	fig.queue_free()
	fig = null
	Snd.set_tension(0.0)
	(d.terminal.zones.gates as LightZone).trigger_dip(1.0)
	Snd.stop_all_world()
	await d.wait(2.0)
	await _gate0()


func _physics_process(delta: float) -> void:
	if not _chasing or fig == null:
		return
	var p := d.player
	var at := p.global_position
	if at.distance_to(_crumb) > CRUMB:
		_crumb = at
		fig.trail.append(at)
	var dist := Vector2(at.x - fig._pos.x, at.z - fig._pos.z).length()
	fig.speed = move_toward(fig.speed, CATCH_UP if dist > FAR else SPEED, delta * 3.5)
	if loops < LOOPS and at.z < LOOP_FROM and at.z > -70.0:
		_loop()


## The lights cut out for a moment and you are further back along the corridor, it just as far behind you.
func _loop() -> void:
	loops += 1
	var p := d.player
	var by := Vector3(0, 0, LOOP_STEP)
	var yaw: float = p._yaw
	var pitch: float = p._pitch
	var mv := p.move_vel
	var vel := p.velocity
	d.ui.cut_to(0.92)
	p.teleport(Transform3D(Basis(), p.global_position + by))
	p.set_look(yaw, pitch)
	p.move_vel = mv
	p.velocity = vel
	fig._pos += by
	fig.global_position += by
	for i in fig.trail.size():
		fig.trail[i] += by
	_crumb += by
	(d.terminal.zones.corridor as LightZone).trigger_dip(0.25)
	Snd.play("flicker_zap", -6.0, 0.9)
	d.ui.fade_to(0.0, 0.2)


## Quiet. The wall opens: Gate 0, its bridge, the door at the end of it.
func _gate0() -> void:
	var t := d.terminal
	var p := d.player
	d.objective("GATE 0")
	Snd.play_at("door_heavy", Vector3(0, 1.5, -99.0), 6.0, 0.8, 24.0, 120.0)
	t.reveal_gate0()
	(t.gates["0"] as BoardingGate).open_door(false)
	await d.until(func(): return p.global_position.z < -133.0)
	d.cutscene(true)
	await d.ui.fade_to(1.0, 1.2)
	Snd.stop_all_world()
	Snd.set_ambience("", 0.2)
	await d.wait(1.6)
	# the first shot again: the office, 02:17, as if nothing had happened
	ch.restore_office()
	p.teleport(Transform3D(Basis(), Prologue.START))
	p.set_look(0.0, 0.0)
	d.ui.hud.set_visible_all(false)
	d.ui.hud.set_clock_override("")
	d.set_clock(Game.START_CLOCK)
	d.ui.fade_to(0.0, 2.2)
	d.ui.place_card(["A국제공항 터미널", "AM 02:17", "정상 근무"], 3.0)
	await d.wait(6.4)
	await d.ui.fade_to(1.0, 1.6)
	ended = true
	await get_tree().process_frame
	await get_tree().process_frame
	Game.finish_game()
