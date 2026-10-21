extends Node
## Session state, settings, scene flow and save data for GATE 0.

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.cfg"
const PHOTO_DIR := "user://photos"
const MAX_CYCLE := 3
const PHOTOS_PER_DAY := 6

const SCENE_MENU := "res://scenes/menu.tscn"
const SCENE_GAME := "res://scenes/game.tscn"
const SCENE_ENDING := "res://scenes/ending.tscn"

# --- settings -----------------------------------------------------------------
var settings := {
	"mouse_sensitivity": 1.0,
	"invert_y": false,
	"fov": 75.0,
	"master_volume": 0.9,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"fullscreen": false,
	"quality": "high",  # "high" | "low"
}

# --- session state ---------------------------------------------------------------
var player_name := "점검원"
var cycle := 1             # 1..3 : Day N -> Night N
var phase := "day"         # "day" | "night"
var erosion := 0.0         # 0..100
var clock_minutes := 9 * 60
var clues := {}            # clue_id -> true
var binder_pages: Array = []   # page ids currently in the binder
var stats := {}
var flags := {}            # story flags
var photos: Array = []     # [{image: Image, tex: ImageTexture, label: String, cycle: int, altered: bool}]
var photos_left := PHOTOS_PER_DAY
var night_lights := {"hall": true, "baggage": true, "security": false, "corridor": true, "gates": false}
var ending_id := ""
var name_voice_path := ""   # runtime TTS of the player's name (optional)

var _snapshot := {}
var paused_by_ui := false   # true while tablet/binder/panels own the mouse


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_input()
	load_settings()
	reset_session()
	_debug_args()


## Debug / test hooks: `-- --night 2` or `-- --day 3` jumps straight into a phase.
func _debug_args() -> void:
	var args := OS.get_cmdline_user_args()
	for key in ["--night", "--day"]:
		var i := args.find(key)
		if i >= 0:
			phase = key.substr(2)
			cycle = int(args[i + 1]) if i + 1 < args.size() and args[i + 1].is_valid_int() else 1
			clock_minutes = 23 * 60 if phase == "night" else 9 * 60
			prepare_chapter(cycle, phase)


## Binder contents a player would have when starting directly at (cycle, phase).
func prepare_chapter(c: int, ph: String) -> void:
	binder_pages = []
	if c > 1 or ph == "night":
		binder_pages.append_array(["p0", "p1", "p2", "p3", "p4", "p5", "p9"])
	if (c == 2 and ph == "night") or c >= 3:
		binder_pages.append_array(["p6", "p7"])
	if c >= 3 and ph == "night":
		binder_pages.append("p8")
	set_flag("prologue_seen")


func reset_session() -> void:
	cycle = 1
	phase = "day"
	erosion = 0.0
	clock_minutes = 9 * 60
	clues = {}
	binder_pages = []
	flags = {}
	photos = []
	photos_left = PHOTOS_PER_DAY
	night_lights = {"hall": true, "baggage": true, "security": false, "corridor": true, "gates": false}
	ending_id = ""
	stats = {
		"correct": 0, "missed": 0, "false_alarm": 0, "cleared": 0,
		"failed": 0, "deaths": 0, "fake_followed": 0, "photos": 0,
	}


# --- input -----------------------------------------------------------------------
func _register_input() -> void:
	_bind("move_forward", [KEY_W, KEY_UP])
	_bind("move_back", [KEY_S, KEY_DOWN])
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("sprint", [KEY_SHIFT])
	_bind("interact", [KEY_E], [MOUSE_BUTTON_LEFT])
	_bind("flashlight", [KEY_F])
	_bind("tablet", [KEY_TAB])
	_bind("binder", [KEY_B])
	_bind("close_eyes", [KEY_C])
	_bind("pause", [KEY_ESCAPE])
	_bind("ui_page_next", [KEY_D, KEY_RIGHT, KEY_PAGEDOWN])
	_bind("ui_page_prev", [KEY_A, KEY_LEFT, KEY_PAGEUP])
	_bind("camera_shoot", [], [MOUSE_BUTTON_LEFT])
	_bind("camera_cancel", [], [MOUSE_BUTTON_RIGHT])


func _bind(action: String, keys: Array, mouse_buttons: Array = []) -> void:
	if InputMap.has_action(action):
		InputMap.action_erase_events(action)
	else:
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in mouse_buttons:
		var mb := InputEventMouseButton.new()
		mb.button_index = b
		InputMap.action_add_event(action, mb)


# --- settings persistence ------------------------------------------------------------
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		for k in settings.keys():
			settings[k] = cfg.get_value("settings", k, settings[k])
	apply_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings.keys():
		cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_PATH)


func apply_settings() -> void:
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	_set_bus_volume("Master", settings.master_volume)
	_set_bus_volume("Music", settings.music_volume)
	_set_bus_volume("SFX", settings.sfx_volume)


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


# --- erosion / stats -----------------------------------------------------------------
func add_erosion(amount: float) -> void:
	erosion = clampf(erosion + amount, 0.0, 100.0)
	Events.erosion_changed.emit(erosion)


func stat(key: String, amount: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount


func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value


func flag(key: String) -> bool:
	return bool(flags.get(key, false))


func has_clue(id: String) -> bool:
	return clues.has(id)


func add_clue(id: String) -> void:
	if clues.has(id):
		return
	clues[id] = true
	Events.clue_found.emit(id)


func add_binder_page(page_id: String) -> void:
	if not binder_pages.has(page_id):
		binder_pages.append(page_id)
		Events.binder_changed.emit()


func remove_binder_page(page_id: String) -> void:
	binder_pages.erase(page_id)
	Events.binder_changed.emit()


func clock_text(minutes: int = -1) -> String:
	var m := clock_minutes if minutes < 0 else minutes
	m = posmod(m, 24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]


# --- scene flow ------------------------------------------------------------------------
func start_new_game(name_text: String) -> void:
	reset_session()
	player_name = name_text.strip_edges() if name_text.strip_edges() != "" else "점검원"
	_prepare_name_voice()
	start_phase(1, "day")


func start_phase(new_cycle: int, new_phase: String) -> void:
	cycle = clampi(new_cycle, 1, MAX_CYCLE)
	phase = new_phase
	if phase == "day":
		photos_left = PHOTOS_PER_DAY
		clock_minutes = 9 * 60
	else:
		clock_minutes = 23 * 60
	_take_snapshot()
	save_game()
	change_scene(SCENE_GAME)


func restart_phase() -> void:
	_restore_snapshot()
	stat("deaths", 0)
	change_scene(SCENE_GAME)


func go_ending(id: String) -> void:
	ending_id = id
	set_flag("ending_" + id)
	_record_ending(id)
	change_scene(SCENE_ENDING)


func go_menu() -> void:
	change_scene(SCENE_MENU)


func change_scene(path: String) -> void:
	get_tree().paused = false
	paused_by_ui = false
	Snd.stop_all_world()
	get_tree().call_deferred("change_scene_to_file", path)


func _take_snapshot() -> void:
	_snapshot = {
		"erosion": erosion,
		"clues": clues.duplicate(true),
		"binder_pages": binder_pages.duplicate(true),
		"stats": stats.duplicate(true),
		"flags": flags.duplicate(true),
		"photos_count": photos.size(),
		"photos_left": photos_left,
		"night_lights": night_lights.duplicate(true),
		"clock": clock_minutes,
	}


func _restore_snapshot() -> void:
	if _snapshot.is_empty():
		return
	var deaths := int(stats.get("deaths", 0))
	erosion = _snapshot.erosion
	clues = _snapshot.clues.duplicate(true)
	binder_pages = _snapshot.binder_pages.duplicate(true)
	stats = _snapshot.stats.duplicate(true)
	stats["deaths"] = deaths
	flags = _snapshot.flags.duplicate(true)
	photos.resize(mini(photos.size(), int(_snapshot.photos_count)))
	photos_left = _snapshot.photos_left
	night_lights = _snapshot.night_lights.duplicate(true)
	clock_minutes = _snapshot.clock


# --- save / load ------------------------------------------------------------------------
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var labels := []
	DirAccess.make_dir_recursive_absolute(PHOTO_DIR)
	for i in photos.size():
		var p: Dictionary = photos[i]
		labels.append({"label": p.label, "cycle": p.cycle, "altered": p.get("altered", false)})
		var img: Image = p.image
		if img:
			img.save_png("%s/photo_%02d.png" % [PHOTO_DIR, i])
	var data := {
		"version": 1,
		"player_name": player_name,
		"cycle": cycle,
		"phase": phase,
		"erosion": erosion,
		"clues": clues,
		"binder_pages": binder_pages,
		"stats": stats,
		"flags": flags,
		"photos": labels,
		"night_lights": night_lights,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return false
	reset_session()
	player_name = str(data.get("player_name", "점검원"))
	cycle = int(data.get("cycle", 1))
	phase = str(data.get("phase", "day"))
	erosion = float(data.get("erosion", 0.0))
	clues = data.get("clues", {})
	binder_pages = data.get("binder_pages", [])
	for k in data.get("stats", {}).keys():
		stats[k] = int(data.stats[k])
	flags = data.get("flags", {})
	night_lights = data.get("night_lights", night_lights)
	photos = []
	var labels: Array = data.get("photos", [])
	for i in labels.size():
		var path := "%s/photo_%02d.png" % [PHOTO_DIR, i]
		var img := Image.load_from_file(path) if FileAccess.file_exists(path) else null
		if img == null:
			continue
		photos.append({
			"image": img, "tex": ImageTexture.create_from_image(img),
			"label": str(labels[i].get("label", "")), "cycle": int(labels[i].get("cycle", 1)),
			"altered": bool(labels[i].get("altered", false)),
		})
	_prepare_name_voice()
	return true


func continue_game() -> void:
	if load_game():
		start_phase(cycle, phase)


func _record_ending(id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	var seen: Array = cfg.get_value("progress", "endings", [])
	if not seen.has(id):
		seen.append(id)
	cfg.set_value("progress", "endings", seen)
	cfg.save(SETTINGS_PATH)


func endings_seen() -> Array:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	return cfg.get_value("progress", "endings", [])


# --- runtime name voice (Windows SAPI) -----------------------------------------------------
## Synthesises "{name} 승객님..." so the PA can call the player by name. Falls back silently.
func _prepare_name_voice() -> void:
	name_voice_path = ""
	if OS.get_name() != "Windows" or DisplayServer.get_name() == "headless":
		return
	var out_path := ProjectSettings.globalize_path("user://voice_name.wav")
	var safe_name := player_name.replace("'", "").replace("\"", "").replace("`", "").replace("$", "")
	var text := "%s 승객님. %s 승객님. 영번 게이트로 오시기 바랍니다. 기다리고 있습니다." % [safe_name, safe_name]
	var ps := "Add-Type -AssemblyName System.Speech; " \
		+ "$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; " \
		+ "try { $s.SelectVoice('Microsoft Heami Desktop') } catch {}; " \
		+ "$s.Rate = -3; " \
		+ "$f = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(22050, [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen, [System.Speech.AudioFormat.AudioChannel]::Mono); " \
		+ "$s.SetOutputToWaveFile('%s', $f); $s.Speak('%s'); $s.Dispose()" % [out_path, text]
	var t := Thread.new()
	t.start(func():
		var output := []
		var code := OS.execute("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", ps], output, true, false)
		return code
	)
	_name_voice_thread = t
	_name_voice_out = out_path


var _name_voice_thread: Thread
var _name_voice_out := ""


func _process(_delta: float) -> void:
	if _name_voice_thread and not _name_voice_thread.is_alive():
		var code = _name_voice_thread.wait_to_finish()
		_name_voice_thread = null
		if code == 0 and FileAccess.file_exists(_name_voice_out):
			name_voice_path = _name_voice_out


func _exit_tree() -> void:
	if _name_voice_thread:
		_name_voice_thread.wait_to_finish()
