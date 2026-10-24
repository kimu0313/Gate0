extends Node
## Debug: `res://scenes/game.tscn -- --fids-sheet <out dir>` (windowed) renders every departure-board state the
## game uses into PNGs shown at the board's physical proportions (6.0 x 2.8 m), and prints any text that runs past
## its column or off the screen.

const BOARD := Vector2(6.0, 2.8)

var states := [
	["normal", "normal", [], {}],
	["ghost", "normal", [], {"ghost": true}],
	["changed_home", "normal", [], {"row": [4, "dest", "HOME", "ko", "집"]}],
	["changed_boarding", "normal", [], {"row": [6, "remark", "BOARDING"]}],
	["arrivals", "message", ["운영 준비 중", "NOT IN SERVICE"], {"title": "도착  ARRIVALS"}],
	["gate04", "story", ["FLIGHT 000", "GATE 04", "CHECK-IN"], {}],
	["final_day2", "final", ["GATE 0", "BOARDING"], {}],
	["final_day5", "final", ["SH 000", "GATE 0", "BOARDING"], {}],
	["final_ending", "final", ["FLIGHT 000", "BOARDING"], {}],
	["reboot", "reboot", [], {}],
]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--fids-sheet")
	var out: String = args[i + 1] if i >= 0 and args.size() > i + 1 else "user://fids"
	DirAccess.make_dir_recursive_absolute(out)
	var vw := FidsBoard.SCREEN_W
	var vh := FidsBoard.screen_px(BOARD.x, BOARD.y).y
	Geo.fonts()
	for st in states:
		var vp := SubViewport.new()
		vp.size = Vector2i(vw, vh)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var s := FidsScreen.new()
		s.size = Vector2(vw, vh)
		vp.add_child(s)
		var rows: Array = FidsBoard.NORMAL_ROWS.duplicate(true)
		var opt: Dictionary = st[3]
		if opt.get("ghost", false):
			rows.insert(0, FidsBoard.FLIGHT0_ROW.duplicate())
			rows.pop_back()
		if opt.has("row"):
			var r: Array = opt.row
			for k in range(1, r.size(), 2):
				rows[r[0]][r[k]] = r[k + 1]
		if opt.has("title"):
			s.title = opt.title
			s.icon = load("res://assets/textures/level/icon_arrivals.png")
		s.rows = rows
		s.mode = st[1]
		s.big_lines = st[2]
		s.clock = "02:47"
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		for msg in s.overflows():
			print("FIDS OVERFLOW [%s] %s" % [st[0], msg])
		var img := vp.get_texture().get_image()
		img.resize(img.get_width(), int(img.get_width() * BOARD.y / BOARD.x), Image.INTERPOLATE_LANCZOS)
		img.save_png(out.path_join(st[0] + ".png"))
		vp.queue_free()
	print("FIDS SHEET done (%dx%d)" % [vw, vh])
	get_tree().quit(0)
