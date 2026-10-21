class_name BreakerPanel
extends Node3D
## 시설 전원 배전반 — cuts or restores power per facility group.

var groups := {}      # key -> Array[Facility]
var switches := {}    # key -> ToggleSwitch


## entries: [[key, caption, [Facility...]], ...]
func build(entries: Array, title := "시설 전원 배전반  BREAKER") -> void:
	var w := 0.2 * entries.size() + 0.35
	var holder := Props.panel_box(self, Vector3.ZERO, 0.0, Vector2(w, 0.75), title)
	Geo.label(holder, "※ 차단 시 해당 시설 즉시 정지", Vector3(0, -0.31, 0.006), 0.0, 18, Color(0.85, 0.85, 0.85), 0.0022, false, "print")
	for i in entries.size():
		var e: Array = entries[i]
		var key: String = e[0]
		groups[key] = e[2]
		var s := ToggleSwitch.create(holder, Vector3(-w * 0.5 + 0.27 + i * 0.2, -0.04, 0.0), e[1], true)
		s.on_prompt = "전원 투입"
		s.off_prompt = "전원 차단"
		s._refresh(true)
		s.toggled.connect(_on_toggle.bind(key))
		switches[key] = s


func _on_toggle(on: bool, key: String) -> void:
	for f in groups.get(key, []):
		(f as Facility).set_powered(on)
	Events.player_action.emit("power_on" if on else "power_off", key)


func set_power(key: String, on: bool) -> void:
	if switches.has(key):
		switches[key].set_on(on)
	for f in groups.get(key, []):
		(f as Facility).set_powered(on)


func lock_all(locked: bool, message := "") -> void:
	for s in switches.values():
		s.locked = locked
		s.locked_message = message
