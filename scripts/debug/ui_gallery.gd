extends Node
## Debug: `godot --path . -- --uigallery <dir> [--night]` walks through every UI screen (menu, HUD,
## tablet tabs, binder, documents, keypad, camera, pause, report, BOARDED, prologue), saves a
## screenshot of each and quits. Does not touch the save file.

var menu: Control
var world: Node
var out_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var idx := args.find("--uigallery")
	out_dir = args[idx + 1] if idx >= 0 and idx + 1 < args.size() and not args[idx + 1].begins_with("--") else OS.get_user_data_dir() + "/uigallery"
	DirAccess.make_dir_recursive_absolute(out_dir)
	if menu:
		_run_menu()
	else:
		_run_world()


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, shot_name])
	print("ui shot: ", shot_name)


func _run_menu() -> void:
	while not menu._intro_started:
		await get_tree().process_frame
	await _wait(3.0)
	await _shot("01_menu")
	menu._rows[0]._on_hover(true)
	await _wait(0.35)
	await _shot("02_menu_hover")
	menu._rows[0]._on_hover(false)
	menu._on_new()
	menu._name_edit.text = "김훈철"
	await _wait(0.6)
	await _shot("03_menu_staff_card")
	menu._name_panel.visible = false
	menu._on_chapters()
	await _wait(0.5)
	await _shot("04_menu_chapters")
	menu._chapter_panel.visible = false
	menu._on_settings()
	await _wait(0.5)
	await _shot("05_menu_settings")
	for t in ["display", "access"]:
		menu._settings._show_tab(t, false)
		await _wait(0.3)
		await _shot("05_menu_settings_" + t)
	menu._settings.visible = false
	var notice := BootNotice.new()
	menu.add_child(notice)
	await _wait(0.9)
	await _shot("06_boot_warning")
	notice.show_calibration()
	await _wait(0.6)
	await _shot("07_boot_calibration")
	notice.queue_free()
	var cv := CreditsView.new()
	cv.autoscroll = false
	menu.add_child(cv)
	await _wait(0.8)
	await _shot("08_credits")
	cv._scroll.scroll_vertical = 1500
	await _wait(0.2)
	await _shot("09_credits_licenses")
	cv.queue_free()
	Game.reset_session()
	Game.player_name = "김훈철"
	var args := OS.get_cmdline_user_args()
	var night := args.has("--night")
	var ci := args.find("--cycle")
	Game.cycle = int(args[ci + 1]) if ci >= 0 and ci + 1 < args.size() else 2
	Game.phase = "night" if night else "day"
	Game.prepare_chapter(Game.cycle, Game.phase)
	Game.photos_left = Game.PHOTOS_PER_DAY
	Game.clock_minutes = (23 * 60 + 47) if night else (9 * 60 + 40)
	Game.change_scene(Game.SCENE_GAME)


func _run_world() -> void:
	var ui: GameUI = world.ui
	var d: ShiftDirector = world.director
	var p: Player = world.player
	ui.fade_to(0.0, 0.01)
	p.teleport(Transform3D(Basis(), world.terminal.spot("view_fids")))
	await get_tree().process_frame
	p.look_at_point(world.terminal.spot("look_fids"), 0.01)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	await _wait(1.2)
	# title card
	ui.title_card("DAY 2" if Game.phase == "day" else "NIGHT 2", "10월 21일 · 정식 개장 D-2 · 09:00 낮 근무", 1.0)
	await _wait(1.9)
	await _shot("10_title_card")
	await _wait(3.6)
	# HUD
	d.set_process(false)
	var task := d.inspect("fids", "FIDS 출발 전광판 점검", "전광판 제어함에서 [b][표시 테스트][/b]를 눌러 출발 목록을 확인하십시오. 낮에 촬영한 정상 목록과 비교하고, 다른 행이 있는지 관찰하십시오.")
	d.goal("조명 분전반 LP-1 점검", "체크인 홀 서측 벽의 분전반에서 각 구역 조명을 확인하십시오.", "hall")
	if Game.phase == "night":
		# a night in progress: inspection 4 of 10, one judgment mistake so far
		d.inspections_total = NightPlan.slots(Game.cycle)
		d.inspections_done = 3
		d.mistakes = 1
		task.slot = 4
	await _wait(0.5)
	Events.notify.emit("관찰 완료 — [Tab] 태블릿에서 정상/이상을 보고하십시오.", "info")
	Events.notify.emit("근무 수칙 바인더 획득 — [B]로 펼치기", "good")
	Events.subtitle.emit("radio", "소장|테스트 데이터겠죠. 무시하고 진행해 주세요.", 9.0)
	ui.hud.set_prompt("FIDS 제어함 열기")
	ui.hud.show_key_hints(20.0)
	ui.hud.set_inspect_progress(0.68)
	await _wait(1.3)
	await _shot("11_hud")
	ui.hud.flash_warning("조명이 켜진 곳으로", 3.0)
	await _wait(0.25)
	await _shot("12_hud_warning")
	Game.erosion = 82.0
	Events.erosion_changed.emit(Game.erosion)
	Events.subtitle.emit("pa", "|Flight 000편 승객께서는 출국장으로 이동해 주시기 바랍니다.", 6.0)
	await _wait(0.8)
	ui.hud._start_glitch(82.0)
	await get_tree().process_frame
	await _shot("13_hud_erosion")
	ui.hud._end_glitch()
	Game.erosion = 12.0
	Events.erosion_changed.emit(Game.erosion)
	await _wait(0.6)
	# staff card reader (ACT 3: ACCESS DENIED -> PASSENGER)
	var t: Terminal = world.terminal
	var rd: CardReader = t.readers.office_out
	p.teleport(Transform3D(Basis(), rd.global_position + rd.global_basis.z * 0.9 + Vector3(0, -1.2, 0)))
	await get_tree().process_frame
	p.look_at_point(rd.global_position, 0.01)
	t.readers.office_out.show_result(false, "PASSENGER")
	await _wait(0.5)
	await _shot("14_card_reader")
	p.teleport(Transform3D(Basis(), world.terminal.spot("view_fids")))
	await get_tree().process_frame
	p.look_at_point(world.terminal.spot("look_fids"), 0.01)
	await _wait(0.4)
	# tablet
	task.observed = true
	Events.tasks_changed.emit()
	ui.open_tablet()
	await _wait(0.25)
	await _shot("20_tablet_power_on")
	await _wait(0.7)
	await _shot("21_tablet_tasks")
	ui.tablet._report(task, false)
	await _wait(0.3)
	await _shot("22_tablet_stamp")
	await _wait(1.2)
	# stand-in album photos: like the real camera, no HUD in the frame
	ui.hud.set_visible_all(false)
	await RenderingServer.frame_post_draw
	for i in 3:
		var img := get_viewport().get_texture().get_image()
		img.resize(960, 540)
		Game.photos.append({"image": img, "tex": ImageTexture.create_from_image(img),
			"label": ["FIDS 출발 전광판", "수하물 수취대 B-03", "조명 분전반 LP-1"][i] + " · DAY 2 %s" % Game.clock_text(), "cycle": 2, "altered": false})
		await get_tree().process_frame
	ui.hud.set_visible_all(true)
	ui.open_tablet()
	ui.tablet._show_tab("album")
	await _wait(0.9)
	await _shot("23_tablet_album")
	ui.tablet._view_photo(0)
	await _wait(0.45)
	await _shot("24_tablet_photo")
	ui.tablet._album_viewer.visible = false
	ui.tablet._show_tab("map")
	await _wait(0.5)
	await _shot("25_tablet_map")
	if Game.phase == "day":
		ui.tablet._show_tab("power")
		await _wait(0.5)
		await _shot("26_tablet_power")
		ui.tablet._show_tab("camera")
		await _wait(0.5)
		await _shot("27_tablet_camera")
	Game.add_clue("ticket")
	Game.add_clue("job_post")
	Game.add_clue("syslog")
	ui.tablet._show_tab("records")
	await _wait(0.3)
	(ui.tablet._records_list.get_child(0) as Button).pressed.emit()
	await _wait(0.9)
	await _shot("28_tablet_records")
	var t2 := d.inspect("baggage", "수하물 수취대 B-03 점검", "[가동]을 눌러 점검용 가방 3개가 나오는지 확인하십시오.", "", {"urgent": true})
	t2.state = "responding"
	t2.deadline = 95.0
	ui.tablet._selected = t2
	ui.tablet._show_tab("tasks")
	ui.tablet.refresh()
	await _wait(0.5)
	await _shot("29_tablet_responding")
	ui.tablet.boarding_mode = true
	ui.tablet.refresh()
	await _wait(0.9)
	await _shot("30_tablet_boarding")
	ui.tablet.boarding_mode = false
	ui.close_modal()
	await _wait(0.5)
	# binder
	Game.binder_pages = ["p0", "p1", "p2", "p3", "p4", "f4", "p5", "f5", "f6", "p9"]
	ui.open_binder("p1")
	await _wait(0.9)
	await _shot("39_binder_p1")
	ui.close_modal()
	await _wait(0.4)
	ui.open_binder("p4")
	await _wait(0.9)
	await _shot("40_binder_p4")
	ui.binder._select(ui.binder._ids.find("f5"))
	await _wait(0.07)
	await _shot("41_binder_flip")
	await _wait(0.5)
	await _shot("42_binder_fake_f5")
	ui.binder._select(ui.binder._ids.find("f6"))
	await _wait(0.5)
	await _shot("43_binder_memo")
	ui.close_modal()
	await _wait(0.5)
	# document
	ui.read_doc(RulesDB.CLUES.scraps.title, RulesDB.CLUES.scraps.body, "serif")
	await _wait(0.8)
	await _shot("50_document")
	ui._close_reader()
	await _wait(0.5)
	# keypad
	ui.open_keypad(func(_c): ui.keypad.show_result(false))
	await _wait(0.4)
	ui.keypad._press("1")
	ui.keypad._press("1")
	await _wait(0.2)
	await _shot("51_keypad")
	ui.keypad._press("OK")
	await _wait(0.12)
	await _shot("52_keypad_error")
	ui.close_modal()
	await _wait(0.4)
	# camera
	ui._enter_camera()
	await _wait(1.0)
	await _shot("60_camera")
	ui._shoot()
	await _wait(0.6)
	await _shot("61_camera_saved")
	await _wait(1.6)
	ui._exit_camera()
	# pause + settings
	ui._pause()
	await _wait(0.7)
	await _shot("70_pause")
	ui._open_settings()
	await _wait(0.4)
	await _shot("71_settings")
	ui._resume()
	await _wait(0.3)
	# morning report
	await ui.fade_to(1.0, 0.2)
	ui.show_report({"correct": 5, "cleared": 3, "missed": 1, "false_alarm": 1, "failed": 0, "erosion_before": 22.0, "erosion_after": 40.0,
		"mistakes": 2, "inspections": 10, "accuracy": 80, "missed_list": [
			["수하물 수취대 B-03", AnomalyDB.get_def("bag_extra").get("miss", "")],
			["조명 분전반", "정상이었지만 [이상]으로 보고했습니다. (오판)"]]})
	await _wait(1.4)
	await _shot("80_report_mid")
	await _wait(4.2)
	await _shot("81_report")
	ui.report_closed.emit()
	for c in ui._fade_layer.get_children():
		if c != ui._fade:
			c.queue_free()
	await _wait(0.2)
	# BOARDED
	ui.show_death("이름이 적힌 수하물에 손을 댔다. 가방은 가벼웠다. 안에는 아무것도 없었다.")
	await _wait(0.9)
	await _shot("90_death_flip")
	await _wait(3.6)
	await _shot("91_death")
	for c in ui._fade_layer.get_children():
		if c != ui._fade:
			c.queue_free()
	# prologue
	ui.typewriter(["서해국제공항 정식 개장 나흘 전.", "", "구인 사이트의 단기 계약직 공고.", "야간 수당 높음. 정규직 전환 조건."], 0.03)
	await _wait(2.4)
	await _shot("92_prologue")
	get_tree().quit()
