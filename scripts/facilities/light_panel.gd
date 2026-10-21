class_name LightPanel
extends Facility
## 조명 분전반 — wall panel with one lever per lighting zone.
## Anomalies: light_flicker (rhythmic blink in a zone), light_red (one panel glows red).

var zones := {}             # zone_name -> LightZone
var switches := {}          # zone_name -> ToggleSwitch
var anomaly_zone := "hall"
var _off_since := {}        # zone_name -> time switched off (sec)
var _time := 0.0


func build(zone_map: Dictionary, zone_order: Array, panel_title := "조명 분전반  LIGHTING") -> void:
	zones = zone_map
	needs_running = false
	observe_radius = 30.0
	var w := 0.22 * zone_order.size() + 0.3
	var holder := Props.panel_box(self, Vector3.ZERO, 0.0, Vector2(w, 0.7), panel_title)
	focus = holder
	for i in zone_order.size():
		var zn: String = zone_order[i]
		var z: LightZone = zones[zn]
		var s := ToggleSwitch.create(holder, Vector3(-w * 0.5 + 0.26 + i * 0.22, -0.05, 0.0), z.display_name, z.is_on)
		s.on_prompt = "조명 켜기"
		s.off_prompt = "조명 끄기"
		s._refresh(true)
		s.toggled.connect(_on_switch.bind(zn))
		switches[zn] = s


func _process(delta: float) -> void:
	_time += delta


func set_zone(zone_name: String, on: bool, instant := false) -> void:
	if zones.has(zone_name):
		zones[zone_name].set_on(on, instant)
	if switches.has(zone_name):
		switches[zone_name].set_on(on)


func _on_switch(on: bool, zone_name: String) -> void:
	var z: LightZone = zones[zone_name]
	z.set_on(on)
	if on:
		act("lights_on", zone_name)
		if _off_since.has(zone_name):
			var off_time: float = _time - float(_off_since[zone_name])
			_off_since.erase(zone_name)
			if off_time >= 7.0:
				act("lights_cycle", zone_name)
	else:
		_off_since[zone_name] = _time
		act("lights_off", zone_name)
	changed.emit()


func zones_on() -> Array:
	var out := []
	for zn in zones.keys():
		if zones[zn].is_on:
			out.append(zn)
	return out


func is_observable() -> bool:
	return not zones_on().is_empty()


func _apply_anomaly(anomaly_id: String) -> void:
	var z: LightZone = zones.get(anomaly_zone)
	if z == null:
		return
	match anomaly_id:
		"light_flicker":
			z.set_pattern(true)
		"light_red":
			z.set_red(true)


func _remove_anomaly(anomaly_id: String) -> void:
	var z: LightZone = zones.get(anomaly_zone)
	if z == null:
		return
	match anomaly_id:
		"light_flicker":
			z.set_pattern(false)
		"light_red":
			z.set_red(false)


func describe_state() -> String:
	var on := zones_on()
	return "점등 구역: %d" % on.size()
