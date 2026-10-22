extends Node
## Debug: `godot --headless --path . res://scenes/game.tscn -- --day 1 --punchtest`
## Clocks out at the time clock in each phase and checks the game moves on:
## DAY 1 → NIGHT 1 → morning report → DAY 2 (add `--to5` to go on to NIGHT 5). Exit code 0 = pass, 1 = fail.

var world: Node


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var d: ShiftDirector = world.director
	print("[punchtest] in %s %d" % [Game.phase, Game.cycle])
	# `--to5`: keep clocking out through every day and night until NIGHT 5 (which ends in the finale, not the clock)
	var goal_phase := ["night", 5] if OS.get_cmdline_user_args().has("--to5") else ["day", 2]
	if Game.phase == goal_phase[0] and Game.cycle == goal_phase[1]:
		print("[punchtest] PASS — reached %s %d" % [Game.phase.to_upper(), Game.cycle])
		get_tree().quit(0)
		return
	# the clock-out goal is the only open work order, exactly as at the end of a real shift
	d.tasks.clear()
	d.current = null
	var g := d.goal("퇴근 기록", "근태 기록기에서 근무 종료를 기록하십시오.", "office")
	d.punch_enabled = true
	var got := [false]
	d.punched.connect(func(): got[0] = true, CONNECT_ONE_SHOT)
	d._on_punch()
	if not got[0]:
		print("[punchtest] FAIL — clock-out refused in %s %d" % [Game.phase, Game.cycle])
		get_tree().quit(1)
		return
	print("[punchtest] clock-out accepted in %s %d" % [Game.phase, Game.cycle])
	d.complete_goal(g)
	if Game.phase == "night":
		# the morning report waits for its button (it appears after the night's end cut)
		_close_report_when_shown()
	d.end_phase()
	await get_tree().create_timer(40.0).timeout
	print("[punchtest] FAIL — still in %s %d after clocking out" % [Game.phase, Game.cycle])
	get_tree().quit(1)


func _close_report_when_shown() -> void:
	while is_inside_tree():
		await get_tree().create_timer(1.0).timeout
		if is_inside_tree():
			world.ui.report_closed.emit()
