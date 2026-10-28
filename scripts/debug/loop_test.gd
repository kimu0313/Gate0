extends Node
## `res://scenes/menu.tscn -- --skip-boot --looptest --storytest loop` (headless OK): the whole game once, end to end,
## through the real scenes — main menu → 새 게임 → the prologue played by the story bot → the title's "계속하려면 아무 키나
## 누르세요" (a key press) → chapter 1 played by the bot → TO BE CONTINUED → back on the main menu. Lives on the scene
## tree's root so it survives every scene change. Exit 0 = the loop closed; 1 = stuck somewhere (the step is printed).
## With --storytest the player's save is never written or deleted.

const LIMIT := 900.0

var _step := "menu"
var _t0 := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_t0 = Time.get_ticks_msec()
	_log("start")


func _log(s: String) -> void:
	print("[loop %6.1f] %s" % [(Time.get_ticks_msec() - _t0) / 1000.0, s])


func _end(code: int, why: String) -> void:
	_log(("PASS " if code == 0 else "FAIL ") + why)
	get_tree().quit(code)


## The title screen's music must be on (menu_music_loop through Snd's music player).
func _music_ok(where: String) -> bool:
	var m: AudioStreamPlayer = Snd._music
	var on := m.playing and m.stream != null and m.stream.resource_path.ends_with("menu_music_loop.wav")
	_log("%s: title music %s (%.1f dB)" % [where, "playing" if on else "NOT playing", m.volume_db])
	return on


func _process(_delta: float) -> void:
	if (Time.get_ticks_msec() - _t0) / 1000.0 > LIMIT:
		_end(1, "timed out at step '%s'" % _step)
		set_process(false)
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var is_menu := scene.scene_file_path == Game.SCENE_MENU
	var is_game := scene.scene_file_path == Game.SCENE_GAME
	match _step:
		"menu":
			if is_menu and scene.get("_state") == "menu":
				var rows: Array = scene.get("_rows")
				_log("main menu up: %s" % ", ".join(rows.map(func(r): return r.label_text)))
				if not _music_ok("launch title"):
					_end(1, "no title music at launch")
					return
				_step = "prologue"
				scene.call("_on_new")
		"prologue":
			if is_menu and (scene.get("_confirm") as Control).visible:
				_log("a save exists: confirming 새 게임")
				(scene.get("_confirm_rows")[0] as SignRow).pressed.emit()
			if is_game and Game.chapter == "prologue":
				_log("prologue running (the story bot plays it)")
				_step = "title"
		"title":
			if is_menu and bool(scene.get("_after_prologue")) and bool(scene.get("_press_ready")):
				var rows: Array = scene.get("_rows")
				_log("title after the prologue: prompt shown, %d menu rows" % rows.size())
				if not rows.is_empty():
					_end(1, "the title after the prologue still shows menu rows")
					return
				if not _music_ok("title after the prologue"):
					_end(1, "no title music after the prologue")
					return
				var key := InputEventKey.new()
				key.physical_keycode = KEY_ENTER
				key.keycode = KEY_ENTER
				key.pressed = true
				Input.parse_input_event(key)
				_step = "ch1"
		"ch1":
			if is_game and Game.chapter == "ch1":
				_log("chapter 1 running (the story bot plays it)")
				_step = "back"
		"back":
			if is_menu and scene.get("_state") == "menu" and not bool(scene.get("_after_prologue")):
				var rows: Array = scene.get("_rows")
				_end(0 if rows.size() >= 4 else 1, "back on the main menu after TO BE CONTINUED (%d rows)" % rows.size())
				set_process(false)
