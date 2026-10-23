class_name LightZone
extends Node3D
## One switchable lighting zone: ceiling panels (shared emissive material) + area lights + hum.

const AREA_GAIN := 1.2         # area light energy per unit of the panel's old omni energy
const GI_DIRECT := 0.3         # share of the bounce omni's light that also lands directly
const NO_GI_DIRECT := 0.6      # without SDFGI the omni stands in for the bounce with direct light

var zone_name := ""
var display_name := ""
var is_on := false
var powered := true
var mode := "steady"           # steady | pattern
var erratic := 0.0             # 0..1 random flicker amount (erosion)
var panel_mat: StandardMaterial3D
var panel_energy := 3.2
var panels: Array[MeshInstance3D] = []
var lights: Array[Light3D] = []
var _base_energy := {}
var _hums: Array[AudioStreamPlayer3D] = []
var _level := 0.0
var _target := 0.0
var _startup := 0.0
var _t := 0.0
var _dip := 0.0
var _red_panel: MeshInstance3D
var _red_light: OmniLight3D
var red_area: Area3D
var red_index := -1
## Overall brightness multiplier: each judgment mistake dims the whole terminal one step.
var intensity := 1.0
var night_dim := 1.0   # 01:00, the evening staff gone: the zones run on half their panels' light
var _panel_light := {}      # panel -> its lights [area, fill omni] (if any)
var _dark_panel: MeshInstance3D
var _dark_mat: StandardMaterial3D


func setup(zname: String, dname: String, color := Color(0.9, 0.95, 1.0), energy := 3.2) -> void:
	zone_name = zname
	display_name = dname
	panel_energy = energy
	panel_mat = StandardMaterial3D.new()
	panel_mat.albedo_color = Color(0.85, 0.87, 0.9)
	panel_mat.emission_enabled = true
	panel_mat.emission = color
	panel_mat.emission_energy_multiplier = 0.0
	panel_mat.roughness = 0.5


## A rectangular ceiling light panel (emissive) with an optional omni light under it.
func add_panel(pos: Vector3, size: Vector2, with_light := true, light_energy := 1.1, light_range := 11.0,
		color := Color(0.88, 0.93, 1.0), shadow := false) -> MeshInstance3D:
	var mi := Geo.box(self, pos, Vector3(size.x, 0.06, size.y), panel_mat, false)
	panels.append(mi)
	# fixture housing: a pale rim around the diffuser so it reads as a troffer, not a cut-out
	if TripoProps.exists("common", "CMN_TrofferLight"):
		_tripo_housing(pos, size)
	else:
		Geo.box(self, pos + Vector3(0, 0.02, 0), Vector3(size.x + 0.1, 0.05, size.y + 0.1), Mats.get_mat("plastic_white"), false)
	if with_light:
		var area := Geo.area_light(self, pos + Vector3(0, -0.04, 0), size, color, light_energy * AREA_GAIN, light_range, shadow)
		add_light(area)
		# area lights do not feed SDFGI yet: a dim omni with boosted indirect energy carries the bounce.
		# Without GI (low quality) it lights the ceiling and walls directly instead.
		var share := GI_DIRECT if Atmosphere.gi_enabled else NO_GI_DIRECT
		var gi := Geo.omni(self, pos + Vector3(0, -0.6, 0), color, light_energy * share, light_range)
		gi.light_indirect_energy = 1.0 / share
		gi.light_specular = 0.0
		gi.light_volumetric_fog_energy = 0.0
		add_light(gi)
		_panel_light[mi] = [area, gi]
	return mi


## Tripo fixture frames (troffers, or slot lights for thin strips) tiled along a panel, turned face-down with
## the glowing panel box standing just proud of their face.
func _tripo_housing(pos: Vector3, size: Vector2) -> void:
	var along_x := size.x >= size.y
	var long := maxf(size.x, size.y)
	var short := minf(size.x, size.y)
	var id := "CMN_TrofferLight" if short >= 0.4 else "CMN_LinearLight"
	var count := maxi(1, int(round(long / (1.2 if short >= 0.4 else 1.6))))
	var seg := long / count
	for i in count:
		var off := -long * 0.5 + seg * (i + 0.5)
		var n := TripoProps.spawn(self, "common", id, Vector3.ZERO, 0.0 if along_x else PI / 2)
		var h := TripoProps.bounds(n).size.y
		TripoProps.fit(n, Vector3(seg + 0.04, h, short + 0.1))
		n.rotate_object_local(Vector3.RIGHT, PI)
		n.position = pos + (Vector3(off, 0, 0) if along_x else Vector3(0, 0, off)) + Vector3(0, h - 0.025, 0)


func add_light(l: Light3D) -> void:
	lights.append(l)
	_base_energy[l] = l.light_energy


func add_hum(pos: Vector3, volume_db := -20.0) -> void:
	var p := Snd.make_loop("hum_light_loop", self, volume_db, 3.0, 14.0)
	p.position = pos
	_hums.append(p)


func set_on(on: bool, instant := false) -> void:
	if on == is_on and not instant:
		return
	is_on = on
	_target = 1.0 if on else 0.0
	if instant:
		_level = _target
		_startup = 0.0
	elif on:
		_startup = randf_range(0.5, 1.1)
		if not _hums.is_empty():
			Snd.play_at("flicker_zap", _hums[0].global_position, -10.0, randf_range(0.9, 1.1), 6.0)
	_apply(_level)


func set_powered(on: bool) -> void:
	powered = on


func set_pattern(enabled: bool) -> void:
	mode = "pattern" if enabled else "steady"
	_t = 0.0


## Makes one panel glow red (anomaly). index -1 picks one at random. Returns the panel position.
func set_red(enabled: bool, index := -1) -> Vector3:
	if enabled:
		if panels.is_empty():
			return Vector3.ZERO
		red_index = index if index >= 0 else randi() % panels.size()
		_red_panel = panels[red_index]
		var m := Mats.emissive(Color(1.0, 0.05, 0.03), 5.0, Color(0.5, 0.0, 0.0))
		_red_panel.material_override = m
		_red_light = Geo.omni(self, _red_panel.position + Vector3(0, -0.8, 0), Color(1.0, 0.1, 0.05), 2.2, 7.0)
		red_area = Geo.area(self, Vector3(_red_panel.position.x, 1.0, _red_panel.position.z), Vector3(2.6, 2.4, 2.6))
		return _red_panel.global_position
	else:
		if _red_panel:
			_red_panel.material_override = panel_mat
		if _red_light:
			_red_light.queue_free()
		if red_area:
			red_area.queue_free()
		_red_panel = null
		_red_light = null
		red_area = null
		red_index = -1
		return Vector3.ZERO


## One panel (and its light) stays dark while the zone is on (anomaly light_dark). Returns its position.
func set_dark(enabled: bool, index := -1) -> Vector3:
	if enabled:
		if panels.is_empty():
			return Vector3.ZERO
		var lit := panels.filter(func(m): return _panel_light.has(m))
		var pool: Array = lit if not lit.is_empty() else panels
		_dark_panel = pool[index if index >= 0 and index < pool.size() else randi() % pool.size()]
		_dark_mat = Mats.std(Color(0.18, 0.18, 0.2), 0.6)
		_dark_panel.material_override = _dark_mat
		return _dark_panel.global_position
	if _dark_panel:
		_dark_panel.material_override = panel_mat
		for l: Light3D in _panel_light.get(_dark_panel, []):
			l.visible = _level > 0.01
	_dark_panel = null
	return Vector3.ZERO


func has_dark() -> bool:
	return _dark_panel != null


func has_red() -> bool:
	return _red_panel != null


func trigger_dip(duration := 0.25) -> void:
	_dip = duration


func _process(delta: float) -> void:
	_t += delta
	var target := _target if powered else 0.0
	_level = move_toward(_level, target, delta * (6.0 if target > _level else 3.5))
	var k := _level
	if _startup > 0.0:
		_startup -= delta
		k *= 0.08 if fmod(_t * 13.0, 1.0) < 0.45 else 1.0
	if mode == "pattern" and k > 0.0:
		k *= _pattern(fmod(_t, 3.2))
	if erratic > 0.0 and k > 0.0 and randf() < erratic * delta * 0.8:
		_dip = randf_range(0.05, 0.3)
	if _dip > 0.0:
		_dip -= delta
		k *= 0.15
	_apply(k)


func _pattern(t: float) -> float:
	# three short blinks, one long — repeating
	if t < 0.12 or (t > 0.3 and t < 0.42) or (t > 0.6 and t < 0.72):
		return 0.05
	if t > 1.3 and t < 2.0:
		return 0.03
	return 1.0


func _apply(k: float) -> void:
	k *= intensity * night_dim
	panel_mat.emission_energy_multiplier = panel_energy * k
	for l in lights:
		l.light_energy = _base_energy[l] * k
		l.visible = k > 0.01
	if _dark_panel:
		for l: Light3D in _panel_light.get(_dark_panel, []):
			l.visible = false
	for h in _hums:
		var want := k > 0.2
		if want and not h.playing and is_inside_tree():
			h.play(randf() * 1.5)
		elif not want and h.playing:
			h.stop()
	if _red_light:
		_red_light.visible = k > 0.01
		_red_panel.material_override.emission_energy_multiplier = 5.0 * k
