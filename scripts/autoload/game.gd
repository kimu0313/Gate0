extends Node
## Settings, scene flow, story progress and save data for GATE 0.
##
## Story order: the title screen (SCENE 05, scripts/ui/menu.gd) → 새 게임 = the prologue (SCENE 01–04,
## scripts/story/prologue.gd) → back to the title, where 계속하기 starts the main story
## (scripts/story/chapter1.gd).

const SAVE_PATH := "user://save_v2.json"   # the anomaly-shift prototype's save.json is not read any more
const SETTINGS_PATH := "user://settings.cfg"

const SCENE_MENU := "res://scenes/menu.tscn"
const SCENE_GAME := "res://scenes/game.tscn"

## Parts of the story in play order. Only the main story ("ch1" on) is saved; the prologue always plays from its start.
const CHAPTERS := ["prologue", "ch1"]
const START_CLOCK := 2 * 60 + 17   # SCENE 01: AM 02:17

# --- settings -----------------------------------------------------------------
var settings := {
	"mouse_sensitivity": 1.0,
	"invert_y": false,
	"fov": 75.0,
	"master_volume": 0.9,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"window_mode": "windowed",  # "windowed" | "fullscreen" (exclusive) | "borderless"
	"vsync": true,
	"max_fps": 0,               # 0 = unlimited
	"render_scale": 1.0,        # 3D resolution; below 1 upscales with FSR (Steam Deck)
	"quality": "high",  # "high" | "low"
	"brightness": 1.0,          # world exposure multiplier (Environment.adjustment_brightness)
	"calibrated": false,        # brightness calibration shown on first launch
	"subtitles": true,
	"subtitle_size": 1,         # 0 small / 1 medium / 2 large
	"subtitle_bg": 0.62,
	"reduce_motion": false,     # calmer UI: no shakes, flickers or HUD glitch jitter
	"crosshair": true,
	"keys": {},                 # action -> physical keycode (rebound primary key)
	"language": "",             # "ko" | "en" | "ja"; empty = follow the OS on first launch
}

## Primary + alternate keys and mouse buttons per action; the first key of the actions listed in
## REBINDABLE can be changed in Settings (stored in settings.keys).
const BINDINGS := {
	"move_forward": [[KEY_W, KEY_UP], []],
	"move_back": [[KEY_S, KEY_DOWN], []],
	"move_left": [[KEY_A, KEY_LEFT], []],
	"move_right": [[KEY_D, KEY_RIGHT], []],
	"sprint": [[KEY_SHIFT], []],
	"interact": [[KEY_E], [MOUSE_BUTTON_LEFT]],
	"flashlight": [[KEY_F], []],
	"tablet": [[KEY_TAB], []],
	"close_eyes": [[KEY_C], []],
	"pause": [[KEY_ESCAPE], []],
	"ui_page_next": [[KEY_D, KEY_RIGHT, KEY_PAGEDOWN], []],
	"ui_page_prev": [[KEY_A, KEY_LEFT, KEY_PAGEUP], []],
}
const REBINDABLE := [["move_forward", "앞으로 이동"], ["move_back", "뒤로 이동"], ["move_left", "왼쪽 이동"],
	["move_right", "오른쪽 이동"], ["sprint", "달리기"], ["interact", "상호작용"], ["flashlight", "손전등"],
	["tablet", "태블릿"]]

# --- session state ---------------------------------------------------------------
var chapter := "prologue"
var checkpoint := ""          # where the chapter picks up again after you are caught ("" = its start)
var inventory: Array = []     # item ids you carry ("key_gate" …), Events.inventory_changed
var flags := {}               # story flags
var clock_minutes := START_CLOCK
var player_name := "점검원"   # facility props print it (B-03 bag tags, the X-ray tag)
var phase := "night"          # look-dev tools name their captures by it
## How the title screen opens next time: "short" = the menu at once (launch, back from the game) | "full" = SCENE 05
## (black, cart wheels, the PA, then the title) | "after_prologue" = SCENE 05 in full, then only the title and 계속하기.
var title_intro := "short"

var _snapshot := {}           # inventory and flags as they were at the last checkpoint
var paused_by_ui := false   # true while the tablet / documents own the mouse
var _default_settings := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_default_settings = settings.duplicate(true)
	_register_input()
	load_settings()
	reset_session()
	_debug_args()


## Debug / test hooks: `-- --prologue` or `-- --chapter ch1` starts that part when the game scene is run directly,
## `--checkpoint <name>` jumps inside it.
func _debug_args() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--prologue"):
		chapter = "prologue"
	var i := args.find("--chapter")
	if i >= 0 and i + 1 < args.size() and CHAPTERS.has(args[i + 1]):
		chapter = args[i + 1]
	i = args.find("--checkpoint")
	if i >= 0 and i + 1 < args.size():
		checkpoint = args[i + 1]
	# `--storytest --test-save <json>`: start from a copy of a player's save (it stays a test save, never written back)
	i = args.find("--test-save")
	if i >= 0 and i + 1 < args.size() and _testing():
		var f := FileAccess.open(args[i + 1], FileAccess.READ)
		var data = JSON.parse_string(f.get_as_text()) if f else null
		if typeof(data) == TYPE_DICTIONARY:
			_test_save = data
			load_game()


func reset_session() -> void:
	chapter = "prologue"
	checkpoint = ""
	inventory = []
	flags = {}
	clock_minutes = START_CLOCK
	_snapshot = {}


# --- input -----------------------------------------------------------------------
func _register_input() -> void:
	var rebound: Dictionary = settings.get("keys", {})
	for action in BINDINGS:
		var keys: Array = (BINDINGS[action][0] as Array).duplicate()
		if rebound.has(action) and not keys.is_empty():
			keys[0] = int(rebound[action])
		_bind(action, keys, BINDINGS[action][1])


## Label of the key an action is bound to ("E", "TAB", "SHIFT") for prompts and guides.
func key_label(action: String) -> String:
	if InputMap.has_action(action):
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				var code: Key = (ev as InputEventKey).physical_keycode
				match code:
					KEY_ESCAPE:
						return "ESC"
					KEY_SPACE:
						return "SPACE"
					KEY_CTRL:
						return "CTRL"
				return OS.get_keycode_string(code).to_upper()
	return "?"


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
		# older settings files had a fullscreen bool
		if cfg.has_section_key("settings", "fullscreen") and not cfg.has_section_key("settings", "window_mode"):
			settings.window_mode = "fullscreen" if cfg.get_value("settings", "fullscreen") else "windowed"
	if str(settings.language) == "":
		var os_lang := OS.get_locale_language()
		settings.language = os_lang if os_lang in ["ko", "ja"] else "en"
	get_tree().node_added.connect(func(n: Node):
		if n is WorldEnvironment:
			_apply_brightness.call_deferred(n))
	apply_settings()


## Settings › 기본값으로 되돌리기 (the brightness calibration is not asked again).
func reset_settings() -> void:
	settings = _default_settings.duplicate(true)
	settings.calibrated = true
	apply_settings()
	save_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # keep the [progress] section
	for k in settings.keys():
		cfg.set_value("settings", k, settings[k])
	cfg.save(SETTINGS_PATH)


func apply_settings() -> void:
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_WINDOWED
		match str(settings.window_mode):
			"fullscreen":
				mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
			"borderless":
				mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings.vsync else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(settings.max_fps)
	var vp := get_tree().root
	vp.scaling_3d_scale = clampf(float(settings.render_scale), 0.5, 1.0)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if vp.scaling_3d_scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	_set_bus_volume("Master", settings.master_volume)
	_set_bus_volume("Music", settings.music_volume)
	_set_bus_volume("SFX", settings.sfx_volume)
	_register_input()
	for we in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		_apply_brightness(we)
	# `-- --lang en|ko` overrides for captures without touching the saved choice
	var args := OS.get_cmdline_user_args()
	var li := args.find("--lang")
	TranslationServer.set_locale(args[li + 1] if li >= 0 and li + 1 < args.size() else str(settings.language))


## Brightness setting on a world's environment (post-tonemap multiplier; the UI is unaffected).
func _apply_brightness(we: WorldEnvironment) -> void:
	if is_instance_valid(we) and we.environment:
		we.environment.adjustment_enabled = true
		we.environment.adjustment_brightness = float(settings.brightness)


func _set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


# --- story state -----------------------------------------------------------------------
func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value


func flag(key: String) -> bool:
	return bool(flags.get(key, false))


func has_item(id: String) -> bool:
	return inventory.has(id)


func add_item(id: String) -> void:
	if not inventory.has(id):
		inventory.append(id)
		Events.inventory_changed.emit()


func remove_item(id: String) -> void:
	if inventory.has(id):
		inventory.erase(id)
		Events.inventory_changed.emit()


func clock_text(minutes: int = -1) -> String:
	var m := clock_minutes if minutes < 0 else minutes
	m = posmod(m, 24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]


## A point the chapter restarts from when you are caught: what you carry and the flags are kept as they are now.
func set_checkpoint(name_text: String) -> void:
	checkpoint = name_text
	_snapshot = {"inventory": inventory.duplicate(), "flags": flags.duplicate(true), "clock": clock_minutes}
	save_game()


# --- scene flow ------------------------------------------------------------------------
## 새 게임: the story from the very beginning — the prologue (the old save is dropped; the prologue's end saves the
## main story's start).
func start_new_game() -> void:
	_drop_save()
	start_prologue()


func _drop_save() -> void:
	if _testing():
		_test_save = {}
	elif has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func start_prologue() -> void:
	reset_session()
	chapter = "prologue"
	change_scene(SCENE_GAME)


func start_chapter(id: String) -> void:
	reset_session()
	chapter = id
	save_game()
	change_scene(SCENE_GAME)


## SCENE 04 ends in a blackout: the main story's start is saved and the title screen
## follows (SCENE 05), where 계속하기 now picks it up.
func finish_prologue() -> void:
	reset_session()
	chapter = "ch1"
	save_game()
	title_intro = "after_prologue"   # SCENE 05 in full, then only the title and 계속하기
	change_scene(SCENE_MENU)


## The ending has played: the save goes and the title comes back with nothing to continue.
func finish_game() -> void:
	_drop_save()
	reset_session()
	go_menu()


## Caught: back to the last checkpoint with what you carried then.
func restart_checkpoint() -> void:
	if not _snapshot.is_empty():
		inventory = _snapshot.inventory.duplicate()
		flags = _snapshot.flags.duplicate(true)
		clock_minutes = _snapshot.clock
	change_scene(SCENE_GAME)


func go_menu() -> void:
	title_intro = "short"
	change_scene(SCENE_MENU)


func change_scene(path: String) -> void:
	get_tree().paused = false
	paused_by_ui = false
	Snd.stop_all_world()
	get_tree().call_deferred("change_scene_to_file", path)


# --- save / load ------------------------------------------------------------------------
## A test run (--storytest) saves and loads here instead of the player's save file: it never touches theirs, and a
## save left by their own play (a later checkpoint) does not leak into the run when the bot presses 계속하기.
var _test_save := {}


func _testing() -> bool:
	return OS.get_cmdline_user_args().has("--storytest")


func has_save() -> bool:
	if _testing():
		return not _test_save.is_empty()
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	if chapter == "prologue":
		return   # the prologue is not saved
	var data := {
		"version": 2,
		"chapter": chapter,
		"checkpoint": checkpoint,
		"inventory": inventory.duplicate(),
		"flags": flags.duplicate(true),
	}
	if _testing():
		_test_save = data
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


## The saved chapter's id ("" when there is no usable save).
func saved_chapter() -> String:
	var data := _read_save()
	return str(data.get("chapter", "")) if not data.is_empty() else ""


func _read_save() -> Dictionary:
	if not has_save():
		return {}
	var data
	if _testing():
		data = _test_save.duplicate(true)
	else:
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f == null:
			return {}
		data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != 2 or not CHAPTERS.has(str(data.get("chapter", ""))):
		return {}
	return data


func load_game() -> bool:
	var data := _read_save()
	if data.is_empty():
		return false
	reset_session()
	chapter = str(data.chapter)
	checkpoint = str(data.get("checkpoint", ""))
	inventory = (data.get("inventory", []) as Array).duplicate()
	flags = (data.get("flags", {}) as Dictionary).duplicate(true)
	set_checkpoint(checkpoint)
	return true


func continue_game() -> void:
	if load_game():
		change_scene(SCENE_GAME)
