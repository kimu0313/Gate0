class_name FidsBoard
extends Facility
## FIDS 출발 전광판. Normal = fixed test schedule in TEST MODE.
## Anomalies: fids_extra (a flight that is not in the list), fids_changed (one field altered),
## fids_clock (board clock runs backwards).

const NORMAL_ROWS := [
	{"time": "06:10", "flight": "SH 101", "dest": "TOKYO/NARITA", "ko": "도쿄/나리타", "gate": "01", "remark": "TEST"},
	{"time": "06:45", "flight": "SH 215", "dest": "SHANGHAI", "ko": "상하이", "gate": "02", "remark": "TEST"},
	{"time": "07:20", "flight": "SH 307", "dest": "OSAKA/KANSAI", "ko": "오사카/간사이", "gate": "03", "remark": "TEST"},
	{"time": "07:55", "flight": "SH 412", "dest": "TAIPEI", "ko": "타이베이", "gate": "04", "remark": "TEST"},
	{"time": "08:30", "flight": "SH 520", "dest": "HONG KONG", "ko": "홍콩", "gate": "02", "remark": "TEST"},
	{"time": "09:05", "flight": "SH 633", "dest": "SINGAPORE", "ko": "싱가포르", "gate": "01", "remark": "TEST"},
	{"time": "09:40", "flight": "SH 718", "dest": "BANGKOK", "ko": "방콕", "gate": "03", "remark": "TEST"},
	{"time": "10:15", "flight": "SH 804", "dest": "MANILA", "ko": "마닐라", "gate": "04", "remark": "TEST"},
]
const FLIGHT0_ROW := {"time": "--:--", "flight": "SH 000", "dest": "HOME", "ko": "집", "gate": "0", "remark": "BOARDING"}

var screen: FidsScreen
var viewport: SubViewport
var screen_mat: StandardMaterial3D
var interactive := true
var change_variant := 0
var _rows: Array = []
var _reboot_t := 0.0
var _clock_offset := 0.0
var _story_mode := ""
var _hum: AudioStreamPlayer3D


func build(width := 8.0, height := 3.2, with_controls := true) -> void:
	needs_running = false
	observe_radius = 16.0
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 640)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	add_child(viewport)
	screen = FidsScreen.new()
	screen.size = Vector2(1600, 640)
	viewport.add_child(screen)
	Geo.box(self, Vector3(0, 0, -0.12), Vector3(width + 0.3, height + 0.3, 0.2), Mats.get_mat("plastic_dark"), true)
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(width, height)
	quad.mesh = qm
	screen_mat = StandardMaterial3D.new()
	screen_mat.albedo_color = Color.BLACK
	screen_mat.emission_enabled = true
	screen_mat.emission_texture = viewport.get_texture()
	screen_mat.emission = Color.BLACK
	screen_mat.emission_energy_multiplier = 1.5
	screen_mat.roughness = 0.2
	quad.material_override = screen_mat
	add_child(quad)
	quad.position = Vector3(0, 0, -0.015)
	var glow := Geo.omni(self, Vector3(0, -height * 0.3, 1.4), Color(1.0, 0.75, 0.4), 0.5, 7.0)
	glow.light_volumetric_fog_energy = 0.8
	focus = quad
	_hum = Snd.make_loop("machine_hum_loop", self, -18.0, 3.0, 12.0)
	if with_controls:
		var box := Props.panel_box(self, Vector3(width * 0.5 - 0.45, -height * 0.5 - 1.75, 0.05), 0.0, Vector2(0.6, 0.5), "FIDS 제어함")
		Props.button(box, Vector3(-0.12, -0.04, 0), 0.0, "button_yellow", "RESET", "전광판 RESET", _on_reset)
		Geo.label(box, "SEOHAE FIDS-01", Vector3(0.13, -0.04, 0.006), 0.0, 18, Color(0.7, 0.75, 0.8), 0.0022, false, "print")
	_rows = NORMAL_ROWS.duplicate(true)
	_refresh()
	if is_inside_tree():
		_hum.play(randf())


func _process(delta: float) -> void:
	if _reboot_t > 0.0:
		_reboot_t -= delta
		if _reboot_t <= 0.0:
			_refresh()
		return
	if not powered:
		return
	if anomaly == "fids_clock":
		_clock_offset -= delta * 37.0
	screen.clock = Game.clock_text(Game.clock_minutes + int(_clock_offset))
	screen_mat.emission_energy_multiplier = 1.5 if randf() > 0.004 else 0.6


func _on_reset() -> void:
	if not powered:
		return
	act("reset", id)
	reboot()


func reboot() -> void:
	_reboot_t = 3.2
	screen.mode = "reboot"
	Snd.play_at("glitch", focus_position(), -10.0, 0.8, 6.0)


func _on_power_lost() -> void:
	screen.mode = "black"
	screen_mat.emission_energy_multiplier = 0.0
	if _hum:
		_hum.stop()
	Snd.play_at("power_down", focus_position(), -10.0, 1.4, 6.0)


func _on_power_restored() -> void:
	screen_mat.emission_energy_multiplier = 1.5
	if _hum:
		_hum.play()
	_clock_offset = 0.0 if anomaly != "fids_clock" else _clock_offset
	reboot()


## Day-time haunting: the impossible flight shows up without being an inspectable anomaly.
func ghost_row(on: bool) -> void:
	_rows = NORMAL_ROWS.duplicate(true)
	if on:
		_rows.insert(0, FLIGHT0_ROW.duplicate())
		_rows.pop_back()
	_refresh()


## story / final / message display modes. lines: Array[String]. "" restores the schedule.
func set_story(mode_name: String, lines: Array = []) -> void:
	_story_mode = mode_name
	screen.big_lines = lines
	_refresh()


func _apply_anomaly(anomaly_id: String) -> void:
	_rows = NORMAL_ROWS.duplicate(true)
	match anomaly_id:
		"fids_extra":
			var idx := randi_range(1, _rows.size() - 1)
			_rows.insert(idx, FLIGHT0_ROW.duplicate())
			_rows.pop_back()
		"fids_changed":
			match change_variant % 4:
				0:
					_rows[4]["dest"] = "HOME"
					_rows[4]["ko"] = "집"
				1:
					_rows[3]["time"] = "03:00"
				2:
					_rows[5]["gate"] = "00"
				3:
					_rows[6]["remark"] = "BOARDING"
		"fids_clock":
			_clock_offset = 0.0
	_refresh()


func _remove_anomaly(_anomaly_id: String) -> void:
	_rows = NORMAL_ROWS.duplicate(true)
	_clock_offset = 0.0
	if _reboot_t <= 0.0:
		_refresh()


func _refresh() -> void:
	if screen == null:
		return
	if not powered:
		screen.mode = "black"
		return
	if _story_mode != "":
		screen.mode = _story_mode
		return
	screen.mode = "normal"
	screen.rows = _rows


func describe_state() -> String:
	return "전원 차단" if not powered else "표시 중"
