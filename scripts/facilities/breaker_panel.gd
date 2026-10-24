class_name BreakerPanel
extends Node3D
## 시설 전원 배전반 — cuts or restores power per facility group: a distribution board (Equipment.board) with one
## breaker module per group.

var groups := {}      # key -> Array[Facility]
var switches := {}    # key -> ToggleSwitch


## entries: [[key, caption, [Facility...]], ...]
func build(entries: Array, title := "시설 전원 배전반  BREAKER") -> void:
	var n := entries.size()
	var w := 0.15 * n + 0.3
	var face := Equipment.board(self, Vector2(w, 0.75), title, "※ 차단 시 해당 시설 즉시 정지")
	for i in n:
		var e: Array = entries[i]
		var key: String = e[0]
		groups[key] = e[2]
		var s := ToggleSwitch.create(face, Vector3((i - (n - 1) * 0.5) * 0.15, -0.02, 0.0), e[1], true)
		s.on_prompt = "전원 투입"
		s.off_prompt = "전원 차단"
		s._refresh(true)
		s.toggled.connect(_on_toggle.bind(key))
		switches[key] = s


func _on_toggle(on: bool, key: String) -> void:
	for f in groups.get(key, []):
		(f as Facility).set_powered(on)
	Events.player_action.emit("power_on" if on else "power_off", key)


## Switches a facility's circuit back on (if the player cut it). Returns true if it was off.
func restore_for(f: Facility) -> bool:
	for key in groups.keys():
		if (groups[key] as Array).has(f) and not f.powered:
			set_power(key, true)
			return true
	return false


func set_power(key: String, on: bool) -> void:
	if switches.has(key):
		switches[key].set_on(on)
	for f in groups.get(key, []):
		(f as Facility).set_powered(on)


func lock_all(locked: bool, message := "") -> void:
	for s in switches.values():
		s.locked = locked
		s.locked_message = message
