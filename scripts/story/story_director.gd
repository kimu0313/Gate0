class_name StoryDirector
extends Node
## Runs the part of the story being played (Game.chapter): the prologue's scenes (Prologue) or the main story
## (Chapter1). Holds the world and gives the part scripts their vocabulary: objectives with a marker, the
## inspector's own lines, sound captions, radio calls, the PA from a speaker, waits and cutscene holds, and
## being caught.

var world: Node3D
var terminal: Terminal
var bridge: JetBridge
var player: Player
var ui: GameUI
var part: StoryScript
var dead := false
var tablet_allowed := true
var objective_text := ""
var _pa: AudioStreamPlayer3D


func setup(w: Node3D) -> void:
	world = w
	terminal = w.terminal
	bridge = w.bridge
	player = w.player
	ui = w.ui
	match Game.chapter:
		"ch1":
			part = Chapter1.new()
		_:
			part = Prologue.new()
	part.name = "Part_" + Game.chapter
	part.d = self
	add_child(part)
	part.setup()


func start() -> void:
	await part.run()



# --- objectives ---------------------------------------------------------------------------------
## The objective sign (top right); `marker` = a world point for the green diamond (null = none).
func objective(text: String, marker: Variant = null) -> void:
	objective_text = text
	ui.hud.set_objective(text)
	ui.hud.set_marker(marker)
	if text != "":
		Snd.play("ui_notify", -14.0, 1.1)


func clear_objective() -> void:
	objective_text = ""
	ui.hud.set_objective("")
	ui.hud.set_marker(null)


# --- lines --------------------------------------------------------------------------------------
static func _dur(text: String) -> float:
	return clampf(1.4 + text.length() * 0.075, 1.8, 6.0)


## The inspector's own words (subtitle "나"). Waits about as long as the line takes to read.
func say(text: String, hold := 0.0) -> void:
	var d := hold if hold > 0.0 else _dur(text)
	Events.subtitle.emit("self", text, d)
	await wait(d)


## A caption for a sound (accessibility: "달그락…… 덜컹……"). Returns at once.
func caption(text: String, hold := 3.0) -> void:
	Events.subtitle.emit("sound", text, hold)


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
	Snd.pa_busy = true
	await _pa_clip("pa_chime")
	await wait(0.3)
	for i in clips.size():
		var s := Snd.voice(str(clips[i]))
		if s == null:
			continue
		if i < subs.size():
			Events.subtitle.emit("pa", str(subs[i]), s.get_length() + 0.5)
		await _pa_clip(str(clips[i]))
		if i < clips.size() - 1:
			await wait(gap)
	await wait(0.2)
	await _pa_clip("pa_chime_end")
	Snd.pa_busy = false


func _pa_clip(clip: String) -> void:
	var s := Snd.voice(clip)
	if s == null:
		return
	_pa.stream = s
	_pa.play()
	while _pa.playing:
		await get_tree().process_frame


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
