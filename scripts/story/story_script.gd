class_name StoryScript
extends Node
## One part of the story (the prologue, a chapter). `setup` builds and places what the part needs before the first
## frame is shown; `run` plays it, awaiting the director's helpers (`d`).

var d: StoryDirector


func setup() -> void:
	pass


func run() -> void:
	pass

