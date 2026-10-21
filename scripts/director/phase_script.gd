class_name PhaseScript
extends RefCounted
## Base for the per-phase story scripts (day1.gd, night1.gd, ...).
## setup() configures the world before the player gains control; run() is the scripted coroutine.

var d: ShiftDirector


func setup() -> void:
	pass


func run() -> void:
	pass


## Called when the player punches the time clock. Return true if the phase may end now.
## The active work order at that point is the clock-out goal itself, so it is not counted.
func can_punch_out() -> bool:
	return d.all_required_done(d.current)


func title_lines() -> Array:
	return []
