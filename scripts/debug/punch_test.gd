extends Node
## Debug: `godot --headless --path . res://scenes/game.tscn -- --day 1 --punchtest`
## Clocks out at the time clock in each phase and checks the game moves on:
## DAY 1 → NIGHT 1 → morning report → DAY 2. Exit code 0 = pass, 1 = fail.

var world: Node


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var d: ShiftDirector = world.director
	print("[punchtest] in %s %d" % [Game.phase, Game.cycle])
	if Game.phase == "day" and Game.cycle == 2:
		print("[punchtest] PASS — reached DAY 2")
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
		# the morning report waits for its button
		get_tree().create_timer(4.0).timeout.connect(func(): world.ui.report_closed.emit())
	d.end_phase()
	await get_tree().create_timer(20.0).timeout
	print("[punchtest] FAIL — still in %s %d after clocking out" % [Game.phase, Game.cycle])
	get_tree().quit(1)
