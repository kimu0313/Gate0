extends Node
## Global signal bus. Systems talk through these signals instead of holding references to each other.

## A physical action the player performed in the world (button, breaker, ...).
## action examples: "start", "stop", "estop", "reset", "power_off", "power_on", "lights_off", "lights_on",
## "pa_test", "pa_stop", "touch_bag", "monitor_off", "close_gate", "enter_gate", "ride_walkway", "sit"
signal player_action(action: String, target: String)

signal facility_changed(facility_id: String)
signal clock_changed(minutes: int)
## Something was picked up or used up (Game.inventory).
signal inventory_changed

## kind: "info" | "task" | "alert" | "good" | "bad"
signal notify(text: String, kind: String)
## speaker: "radio" | "pa" | "self" | "system" | "sound" (a caption for a sound, not a voice)
signal subtitle(speaker: String, text: String, duration: float)

signal zone_entered(zone: String)
