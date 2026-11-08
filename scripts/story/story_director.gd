class_name StoryDirector
extends Node
## Runs the part of the story being played (Game.chapter): the game, Shift1 (the old Prologue and Chapter1 are out of
## the game — user — and only start from the debug flags). Holds the world and gives the part scripts their vocabulary: objectives (text only — no markers), a
## sound that leads the way to the next thing to do (guide), radio calls, the PA from a speaker, waits and cutscene
## holds, and being caught. The inspector has no lines of their own and sounds get no captions.

var world: Node3D
var terminal: Terminal
var bridge: JetBridge
var player: Player
var ui: GameUI
var part: StoryScript
var dead := false
var tablet_allowed := true
var tab_opens := "tablet"       # what [Tab] opens: "tablet", "guide" (the guidelines folder, GameUI.open_guide) or "none"
var objective_text := ""
var pa_clip := ""                # the pa_at clip on air ("" between them)
var _pa: AudioStreamPlayer3D
var _pa_cut := false
var _guide: AudioStreamPlayer3D
var _guide_path: Array = []      # [point, reach m] still ahead of the player, the guide waiting at the first
var _guide_speed := 4.0
var _guide_db := 0.0
var _guide_focus := 0.0          # 0..1, eased: how squarely you are looking toward it
## Extra gain on the guide set by the part (Prologue: faint behind the shut office door, slowly louder, clear once it
## opens). guide() resets it to 0.
var guide_gain_db := 0.0
## Where the guide is heard from: its path is laid out in the world, and this maps it (Prologue: while you are still
## in the office its path in the staff passage is heard beyond the office's west door, the way out through its portal).
## Identity: as laid out.
var guide_xform := Transform3D()
var _guide_pos := Vector3.ZERO
## The guide is this much louder while you look toward it (user: looking the figure's way, it should be louder).
const GUIDE_FOCUS_DB := 6.0


func setup(w: Node3D) -> void:
	world = w
	terminal = w.terminal
	bridge = w.bridge
	player = w.player
	ui = w.ui
	match Game.chapter:
		"ch1":
			part = Chapter1.new()                      # (out of the game: debug flags only)
		"prologue":
			part = Prologue.new()                      # (out of the game: debug flags only)
		"wake":
			part = Wake.new()                          # after the prologue: you come round in the lift
		_:
			part = Shift1.new()
	part.name = "Part_" + Game.chapter
	part.d = self
	add_child(part)
	part.setup()


func start() -> void:
	await part.run()



# --- objectives ---------------------------------------------------------------------------------
## The objective sign (top right). There is no marker: the way is found by eye, or by ear (guide).
## The story's current goal. It is never shown (user: no quest objectives — the player finds the way and works things
## out alone): the HUD's order panel and the pause menu's 현재 목표 stay empty. It is kept as the beat the story and the
## debug bots follow.
func objective(text: String) -> void:
	objective_text = text


func clear_objective() -> void:
	objective_text = ""
	ui.hud.set_marker(null)


# --- the way by ear ----------------------------------------------------------------------------
## A sound that leads the way: it waits at the first point of `path` ([Vector3 point, float reach m], in order) and
## rolls on to the next as soon as the player comes within `reach` of it, so following it by ear takes you round
## corners and through doors. It plays until guide_stop() — the next thing to do is reached.
func guide(sound: String, path: Array, db := 0.0, unit := 6.0, speed := 4.0) -> void:
	guide_stop(0.0)
	_guide = Snd.make_loop(sound, world, db, unit, 70.0)
	_guide_path = path.duplicate()
	_guide_speed = speed
	_guide_db = db
	_guide_focus = 0.0
	guide_gain_db = 0.0
	_guide_pos = _guide_path[0][0]
	_guide.global_position = guide_xform * _guide_pos
	_guide.play()


func guide_stop(fade := 0.8) -> void:
	if _guide == null:
		return
	var g := _guide
	_guide = null
	_guide_path.clear()
	if fade <= 0.0:
		g.queue_free()
		return
	var tw := g.create_tween()
	tw.tween_property(g, "volume_db", -60.0, fade)
	tw.tween_callback(g.queue_free)


func _process(delta: float) -> void:
	if _guide == null or player == null:
		return
	var me := guide_xform.affine_inverse() * player.global_position     # (where you stand, on the path's side)
	var q := Vector2(me.x, me.z)
	while _guide_path.size() > 1:
		# on to the next point once you are within reach of this one, or have gone by it (somewhat nearer to the
		# next than this one is, not far off to the side)
		var at := Vector2(_guide_path[0][0].x, _guide_path[0][0].z)
		var nx := Vector2(_guide_path[1][0].x, _guide_path[1][0].z)
		var reach := float(_guide_path[0][1])
		var gone_by := q.distance_to(at) < reach * 2.5 and q.distance_to(nx) < at.distance_to(nx) - 2.0
		if q.distance_to(at) > reach and not gone_by:
			break
		_guide_path.pop_front()
	_guide_pos = _guide_pos.move_toward(_guide_path[0][0], _guide_speed * delta)
	_guide.global_position = guide_xform * _guide_pos
	# louder while you look its way (eased, so turning the head does not click)
	var look := smoothstep(0.3, 0.92, player.facing_dot(_guide.global_position))
	_guide_focus = move_toward(_guide_focus, look, delta * 2.5)
	_guide.volume_db = _guide_db + guide_gain_db + GUIDE_FOCUS_DB * _guide_focus


# --- lines --------------------------------------------------------------------------------------
static func _dur(text: String) -> float:
	return clampf(1.4 + text.length() * 0.075, 1.8, 6.0)


## One radio line from `who` (with the radio's own click and a little static), waits it out.
func radio(who: String, text: String, hold := 0.0) -> void:
	var d := hold if hold > 0.0 else _dur(text)
	Snd.play("radio_on", -10.0, 1.0, "SFX")
	Snd.radio_static(true)
	Events.subtitle.emit("radio", "%s|%s" % [who, text], d)
	await wait(d)
	Snd.radio_static(false)
	Snd.play("radio_off", -12.0, 1.0, "SFX")
	await wait(0.35)


## A PA announcement from a speaker at `pos` (chime, the voice clips with their subtitles, closing chime), through the
## PA bus so it sounds like the terminal's system but comes from where the speaker is. Await it.
func pa_at(pos: Vector3, clips: Array, subs: Array, gap := 1.2) -> void:
	if _pa == null:
		_pa = AudioStreamPlayer3D.new()
		_pa.bus = "PA"
		_pa.unit_size = 9.0
		_pa.max_distance = 80.0
		Snd.setup_3d(_pa, false)
		world.add_child(_pa)
	_pa.global_position = pos
	_pa_cut = false
	Snd.pa_busy = true
	await _pa_clip("pa_chime")
	await wait(0.3)
	for i in clips.size():
		var s := Snd.voice(str(clips[i]))
		if s == null or _pa_cut:
			continue
		if i < subs.size():
			Events.subtitle.emit("pa", str(subs[i]), s.get_length() + 0.5)
		await _pa_clip(str(clips[i]))
		if i < clips.size() - 1:
			await wait(gap)
	if _pa_cut:
		return
	await wait(0.2)
	await _pa_clip("pa_chime_end")
	Snd.pa_busy = false


## Cuts the announcement on air off where it is; the rest of it is dropped (pa_at returns).
func pa_stop() -> void:
	if _pa == null or not Snd.pa_busy:
		return
	_pa_cut = true
	_pa.stop()
	Snd.pa_busy = false


func _pa_clip(clip: String) -> void:
	var s := Snd.voice(clip)
	if s == null:
		return
	_pa.stream = s
	_pa.play()
	pa_clip = clip
	while _pa.playing:
		await get_tree().process_frame
	pa_clip = ""


# --- time and holds -----------------------------------------------------------------------------
## Pausable wait (the pause menu stops the story too).
func wait(seconds: float) -> void:
	if not is_inside_tree():
		await _halt
	await get_tree().create_timer(seconds, false).timeout


## Waits until `cond` is true (checked every frame).
func until(cond: Callable) -> void:
	while is_inside_tree() and not cond.call():
		await get_tree().process_frame
	if not is_inside_tree():
		await _halt


## Never emitted: a story coroutine still waiting when its scene is torn down (back to the menu, retried)
## parks on it and is dropped with the director, instead of waking up outside the tree.
signal _halt


## A scripted moment: no looking, walking or using things (the script moves the view itself).
func cutscene(on: bool) -> void:
	player.cutscene = on
	if on:
		ui.hud.set_prompt("")


func set_clock(minutes: int) -> void:
	Game.clock_minutes = minutes
	Events.clock_changed.emit(minutes)


# --- caught -------------------------------------------------------------------------------------
func die(reason: String) -> void:
	if dead:
		return
	dead = true
	player.controls_enabled = false
	player.cutscene = true
	ui.close_all()
	ui.hud.set_visible_all(false)
	Snd.stop_all_world()
	Snd.play("death_sting", -2.0)
	ui.show_death(reason)
