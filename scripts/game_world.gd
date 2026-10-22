extends Node3D
## Root of a playable dawn shift (DAY 1–3): builds the terminal, player, UI and the shift director.

var atmosphere: Atmosphere
var terminal: Terminal
var player: Player
var ui: GameUI
var director: ShiftDirector


func _ready() -> void:
	atmosphere = Atmosphere.new()
	add_child(atmosphere)
	atmosphere.setup("night")
	terminal = Terminal.new()
	terminal.name = "Terminal"
	add_child(terminal)
	terminal.build()
	player = Player.new()
	player.name = "Player"
	player.terminal = terminal
	add_child(player)
	player.teleport(terminal.spawns.office)
	ui = GameUI.new()
	add_child(ui)
	director = ShiftDirector.new()
	add_child(director)
	director.setup(self)
	ui.bind(player, director)
	_initial_lights()
	Events.erosion_changed.emit(Game.erosion)
	if OS.get_cmdline_user_args().has("--tour"):
		var tour = load("res://scripts/debug/tour.gd").new()
		tour.world = self
		add_child(tour)
		ui.fade_to(0.0, 0.01)
		return
	if OS.get_cmdline_user_args().has("--uigallery"):
		var gal = load("res://scripts/debug/ui_gallery.gd").new()
		gal.world = self
		add_child(gal)
		return
	if OS.get_cmdline_user_args().has("--autotest"):
		var at = load("res://scripts/debug/autotest.gd").new()
		at.world = self
		add_child(at)
		ui.fade_to(0.0, 0.01)
		return
	if OS.get_cmdline_user_args().has("--punchtest"):
		var pt = load("res://scripts/debug/punch_test.gd").new()
		pt.world = self
		add_child(pt)
		ui.fade_to(0.0, 0.01)
		return
	_begin()


func _begin() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	player.controls_enabled = false
	Snd.set_music("", 1.0)
	Snd.set_ambience("amb_night_loop", 0.0, 3.0)
	if Game.cycle == 1 and not Game.flag("prologue_seen"):
		Game.set_flag("prologue_seen")
		await ui.typewriter([
			"서해국제공항 정식 개장 이틀 전, 자정.",
			"",
			"구인 사이트의 단기 계약직 공고.",
			"새벽 시설 점검원 · 00:00 – 06:00 · 사흘 근무.",
			"",
			"지급품: 점검 태블릿, 무전기,",
			"그리고 두꺼운 근무 수칙 바인더 한 권.",
			"",
			"\"어려울 건 없어요. 수칙만 지키시면 됩니다.\"",
		])
	var lines := director.script_obj.title_lines()
	if lines.size() >= 2:
		await ui.title_card(lines[0], lines[1], 2.2)
	else:
		await ui.fade_to(0.0, 1.0)
	player.controls_enabled = true
	director.start()


## 00:00 the evening staff are still clocking out: every zone is lit until 01:00 (ShiftDirector.ev_staff_leave).
func _initial_lights() -> void:
	for zn in terminal.zones.keys():
		terminal.set_zone_light(zn, true, true)
