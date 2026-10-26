extends Node
## Debug: `godot --headless --path . -- --skip-boot --settingstest`
## Main menu settings: ESC closes the panel, and the language row cycles 한국어 → English → 日本語 → 한국어
## from the 화면 tab — each switch must relabel the menu in place: same menu (no scene reload), the
## settings still open on the same tab. Exit 0 = pass, 1 = fail.

const LANGS := ["en", "ja", "ko"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var start := str(Game.settings.language)
	await _frames(30)
	var menu := _menu()
	# --- ESC closes the settings ---
	menu._on_settings()
	await _frames(5)
	if not menu._settings.visible:
		_fail("settings did not open")
		return
	_press_esc()
	await _frames(5)
	if menu._settings.visible or not menu._main.visible:
		_fail("ESC did not close the settings (settings=%s main=%s)" % [menu._settings.visible, menu._main.visible])
		return
	print("[settingstest] ESC closes the settings: OK")
	# --- language switches (the › button on the language row) ---
	Game.settings.language = "ko"
	Game.apply_settings()
	for want in LANGS:
		menu = _menu()
		if not menu._settings.visible:
			menu._on_settings()
			await _frames(5)
		menu._settings._show_tab("display", false)
		await _frames(3)
		var next := _language_next(menu._settings)
		if next == null:
			_fail("no language › button")
			return
		next.pressed.emit()
		await _frames(20)
		var locale := TranslationServer.get_locale()
		print("[settingstest] language=%s locale=%s settings_open=%s tab=%s" % [Game.settings.language, locale,
			menu._settings.visible, menu._settings._current])
		if str(Game.settings.language) != want or not locale.begins_with(want):
			_fail("expected %s" % want)
			return
		if _menu() != menu:
			_fail("the menu scene was reloaded (the screen jumps)")
			return
		if not menu._settings.visible or menu._settings._current != "display":
			_fail("settings closed or left the 화면 tab after the language change")
			return
		_press_esc()
		await _frames(5)
		if menu._settings.visible:
			_fail("ESC did not close the settings in %s" % want)
			return
	Game.settings.language = start
	Game.apply_settings()
	Game.save_settings()
	print("[settingstest] PASS")
	get_tree().quit(0)


func _menu() -> Node:
	return get_tree().current_scene


func _language_next(panel: Node) -> Button:
	for row in panel.find_children("*", "HBoxContainer", true, false):
		var labels := row.find_children("*", "Label", true, false).filter(func(l): return "Language" in (l as Label).text)
		if labels.is_empty():
			continue
		for b in row.find_children("*", "Button", true, false):
			if (b as Button).text == "›":
				return b
	return null


func _press_esc() -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.physical_keycode = KEY_ESCAPE
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await get_tree().process_frame


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _fail(why: String) -> void:
	print("[settingstest] FAIL — " + why)
	get_tree().quit(1)
