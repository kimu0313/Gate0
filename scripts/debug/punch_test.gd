extends Node
## Debug: `godot --headless --path . res://scenes/game.tscn -- --day 1 --punchtest`
## Clocks out at the time clock in each phase and checks the game moves on:
## DAY 1 → morning report → DAY 2 (add `--toN`, e.g. `--to5`, to go on to DAY N; DAY 5 ends at Gate 0). Exit 0 = pass, 1 = fail.

var world: Node


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var d: ShiftDirector = world.director
	print("[punchtest] in DAY %d" % Game.cycle)
	# `--toN`: keep clocking out through every shift until DAY N (DAY 5 ends at Gate 0, not at the clock)
	var goal_day := 2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--to") and a.substr(4).is_valid_int():
			goal_day = clampi(int(a.substr(4)), 2, Game.MAX_CYCLE)
	if Game.cycle == goal_day:
		print("[punchtest] PASS — reached DAY %d" % Game.cycle)
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
		print("[punchtest] FAIL — clock-out refused in DAY %d" % Game.cycle)
		get_tree().quit(1)
		return
	print("[punchtest] clock-out accepted in DAY %d" % Game.cycle)
	d.complete_goal(g)
	# the morning report waits for its button (it appears after the shift's end cut)
	_close_report_when_shown()
	d.end_phase()
	await get_tree().create_timer(40.0).timeout
	print("[punchtest] FAIL — still in DAY %d after clocking out" % Game.cycle)
	get_tree().quit(1)


func _close_report_when_shown() -> void:
	while is_inside_tree():
		await get_tree().create_timer(1.0).timeout
		if is_inside_tree():
			world.ui.report_closed.emit()
