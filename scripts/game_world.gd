extends Node3D
## Root of a playable part of the story (Game.chapter): builds the terminal, the boarding-bridge connector the
## prologue ends in, the player, the UI and the story director, then runs the part.

var atmosphere: Atmosphere
var terminal: Terminal
var bridge: JetBridge
var player: Player
var ui: GameUI
var director: StoryDirector


func _ready() -> void:
	atmosphere = Atmosphere.new()
	add_child(atmosphere)
	atmosphere.setup("night")
	terminal = Terminal.new()
	terminal.name = "Terminal"
	add_child(terminal)
	terminal.build()
	bridge = JetBridge.new()
	bridge.name = "JetBridge"
	add_child(bridge)
	bridge.build()
	player = Player.new()
	player.name = "Player"
	player.terminal = terminal
	add_child(player)
	player.teleport(terminal.spawns.hall)
	ui = GameUI.new()
	add_child(ui)
	director = StoryDirector.new()
	add_child(director)
	director.setup(self)
	ui.bind(player, director)
	for tool in [["--tour", "tour"], ["--level-shots", "level_shots"], ["--audio-walk", "audio_walk"],
			["--shutter-clip", "shutter_clip"], ["--level-plan", "level_plan"], ["--warped-shots", "warped_shots"],
			["--lounge", "lounge_walk"]]:
		if OS.get_cmdline_user_args().has(tool[0]):
			_debug_tool(tool[1], true)
			return
	for tool in [["--xray-sheet", "xray_sheet"], ["--fids-sheet", "fids_sheet"], ["--zfight-audit", "zfight_audit"],
			["--label-audit", "label_audit"], ["--reach-audit", "reach_audit"], ["--storytest", "story_test"]]:
		if OS.get_cmdline_user_args().has(tool[0]):
			_debug_tool(tool[1], false)
			return
	_begin()


## Debug and look-dev tools (scripts/debug): each gets the world (`world`, or `level`/`player` for the level tools).
func _debug_tool(file: String, lift_fade: bool) -> void:
	var t = load("res://scripts/debug/%s.gd" % file).new()
	for prop in [["world", self], ["level", terminal], ["player", player]]:
		if prop[0] in t:
			t.set(prop[0], prop[1])
	add_child(t)
	if lift_fade:
		ui.fade_to(0.0, 0.01)


func _begin() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Snd.set_music("", 1.0)
	Snd.set_scatter(false)
	await get_tree().process_frame
	director.start()
