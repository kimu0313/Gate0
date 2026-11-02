class_name StoryPart
extends Node
## One stretch of the main story after the lounge (Chapter1 owns them; PartHub runs the branches). `setup` builds what
## it needs before the first frame, `run` plays it.

var d: StoryDirector
var ch: Chapter1


func setup() -> void:
	pass


func run() -> void:
	pass


## Stands you at `pos`, looking along `yaw` (0 = north).
func stand(pos: Vector3, yaw: float) -> void:
	d.player.teleport(Transform3D(Basis(), pos))
	d.player.set_look(yaw, 0.0)


## A short cut through black: you are somewhere else, then the picture comes back. Await it.
func cut_to(pos: Vector3, yaw: float, time := 0.45) -> void:
	await d.ui.fade_to(1.0, time)
	stand(pos, yaw)
	await d.wait(0.2)
	await d.ui.fade_to(0.0, time)
