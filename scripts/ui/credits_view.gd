class_name CreditsView
extends Control
## Credits and third-party notices: the team, bundled fonts (SIL OFL 1.1) and Godot Engine with the
## libraries it ships (license texts come from the engine itself, so they always match the build).
## Opened from the main menu and after an ending; rolls on its own until the player scrolls.

signal closed

const TEAM := [["제작", "RevStudio"], ["기획 · 원안", "김훈철 외"]]
const FONTS := [
	["나눔명조 · 나눔손글씨 펜", "Copyright (c) 2010, NHN Corporation"],
	["Noto Sans KR", "Copyright 2014-2021 Adobe, with Reserved Font Name 'Source'"],
	["Barlow", "Copyright 2017 The Barlow Project Authors"],
	["IBM Plex Mono", "Copyright © 2017 IBM Corp., with Reserved Font Name \"Plex\""],
]

var autoscroll := true
var _scroll: ScrollContainer
var _pos := 0.0


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	var bg := ColorRect.new()
	bg.color = Color(0.012, 0.014, 0.018)
	UiKit.full_rect(bg)
	add_child(bg)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiKit.center(_scroll, Vector2(1120, 900))
	_scroll.offset_top -= 20
	_scroll.offset_bottom -= 20
	add_child(_scroll)
	_scroll.get_v_scroll_bar().scrolling.connect(func(): autoscroll = false)
	_scroll.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton:
			autoscroll = false)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 14)
	_scroll.add_child(v)
	var top := Control.new()
	top.custom_minimum_size = Vector2(0, 300)
	v.add_child(top)
	var board := FlapBoard.new()
	board.font_size = 96
	board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(board)
	board.show_text("GATE 0", 0.1)
	_center(v, UiKit.caption("SEOHAE INT'L AIRPORT · CREDITS", UiKit.TEXT_MUTE, 18))
	_gap(v, 40)
	for t in TEAM:
		_center(v, UiKit.caption(t[0], UiKit.SIGNAL, 18))
		_center(v, UiKit.label(t[1], 30, UiKit.TEXT, "sans", 700))
		_gap(v, 12)
	_gap(v, 40)
	_heading(v, "FONTS · 글꼴")
	for f in FONTS:
		_center(v, UiKit.label(f[0], 22, UiKit.TEXT, "sans", 700))
		_center(v, UiKit.label("%s — SIL Open Font License 1.1" % f[1], UiKit.MIN_TEXT, UiKit.TEXT_DIM))
		_gap(v, 4)
	_center(v, UiKit.label("Bahnschrift · 맑은 고딕 · Consolas는 게임에 포함되지 않으며, 설치된 경우에만 시스템 글꼴로 쓰입니다.", UiKit.MIN_TEXT, UiKit.TEXT_MUTE))
	_gap(v, 40)
	_heading(v, "ENGINE · 엔진")
	_center(v, UiKit.label("This game uses Godot Engine, available under the following license:", 18, UiKit.TEXT_DIM))
	_notice(v, Engine.get_license_text())
	_gap(v, 30)
	_heading(v, "THIRD-PARTY · 엔진 구성요소")
	var parts := PackedStringArray()
	for info in Engine.get_copyright_info():
		var lines := PackedStringArray()
		for part in info.parts:
			for c in part.copyright:
				lines.append("© " + str(c))
			lines.append("License: " + str(part.license))
		parts.append("[b]%s[/b]\n%s" % [str(info.name).replace("[", "[lb]"), "\n".join(lines).replace("[", "[lb]")])
	_notice(v, "\n\n".join(parts), true)
	_gap(v, 30)
	_heading(v, "LICENSE TEXTS · 라이선스 전문")
	var lic: Dictionary = Engine.get_license_info()
	for name in lic:
		_notice(v, "[b]%s[/b]\n\n%s" % [str(name).replace("[", "[lb]"), str(lic[name]).replace("[", "[lb]")], true)
	_gap(v, 300)
	var hints := UiKit.key_hints([["ESC", "닫기"]], UiKit.MIN_TEXT, UiKit.TEXT_DIM)
	hints.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hints.offset_top = -64
	hints.offset_bottom = -30
	hints.offset_left = -200
	hints.offset_right = 200
	hints.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hints)
	modulate.a = 0.0
	UiFx.fade(self, 1.0, 0.4)


func _center(parent: Control, c: Control) -> void:
	if c is Label:
		(c as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		(c as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(c)


func _gap(parent: Control, h: float) -> void:
	var g := Control.new()
	g.custom_minimum_size = Vector2(0, h)
	parent.add_child(g)


func _heading(parent: Control, text: String) -> void:
	var line := ColorRect.new()
	line.color = UiKit.SIGNAL
	line.custom_minimum_size = Vector2(80, 3)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(line)
	_center(parent, UiKit.caption(text, UiKit.SIGNAL, 20))


## Notice text in a quiet, monospaced block (already-escaped BBCode when `bbcode`).
func _notice(parent: Control, text: String, bbcode := false) -> void:
	var r := UiKit.rich(text if bbcode else text.replace("[", "[lb]"), UiKit.MIN_TEXT, UiKit.TEXT_MUTE, "mono")
	r.custom_minimum_size = Vector2(780, 0)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)


func _process(delta: float) -> void:
	if autoscroll:
		_pos += delta * 60.0
		_scroll.scroll_vertical = int(_pos)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		autoscroll = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.25)
		tw.tween_callback(func():
			closed.emit()
			queue_free())
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		autoscroll = false
