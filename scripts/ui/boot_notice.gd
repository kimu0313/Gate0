class_name BootNotice
extends Control
## Shown before the title on launch: a photosensitivity / headphones notice, then (first launch only)
## a brightness calibration card. Emits `done` when the player moves on.

signal done

var _page := ""
var _age := 0.0
var _root: VBoxContainer
var _slider: HSlider


func _ready() -> void:
	UiKit.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiKit.theme()
	var bg := ColorRect.new()
	bg.color = Color(0.008, 0.009, 0.012)
	UiKit.full_rect(bg)
	add_child(bg)
	show_warning()


func _clear() -> void:
	if _root:
		_root.queue_free()
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 18)
	UiKit.center(_root, Vector2(980, 560))
	add_child(_root)
	_age = 0.0


func show_warning() -> void:
	_clear()
	_page = "warning"
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	_root.add_child(head)
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(64, 64)
	tile.add_theme_stylebox_override("panel", UiKit.box(UiKit.SIGNAL, Color(0, 0, 0, 0), 0, 0, 0))
	head.add_child(tile)
	var cc := CenterContainer.new()
	tile.add_child(cc)
	cc.add_child(UiIcon.make("warn", 36, UiKit.INK_0))
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(hv)
	hv.add_child(UiKit.caption("PHOTOSENSITIVITY WARNING", UiKit.SIGNAL, 18))
	hv.add_child(UiKit.label("광과민성 발작 경고", 36, UiKit.TEXT, "sans", 900))
	var body := UiKit.rich("이 게임에는 [b]깜빡이는 조명과 화면 효과[/b]가 포함되어 있습니다. 빛에 민감하거나 발작 병력이 있는 분은 플레이 전에 의사와 상의하십시오. 플레이 중 어지러움, 시야 이상, 경련 등이 느껴지면 즉시 중단하십시오.\n\n[color=#9aa3ae]설정 › 자막·접근성에서 UI 흔들림과 깜빡임을 줄일 수 있습니다.[/color]", 21, UiKit.BODY)
	body.custom_minimum_size = Vector2(980, 0)
	_root.add_child(body)
	var sep := HSeparator.new()
	_root.add_child(sep)
	var hp := HBoxContainer.new()
	hp.add_theme_constant_override("separation", 12)
	_root.add_child(hp)
	hp.add_child(UiIcon.make("headphones", 24, UiKit.TEXT_DIM))
	hp.add_child(UiKit.label("헤드폰 착용을 권장합니다. 소리가 단서가 됩니다.", 19, UiKit.TEXT_DIM))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 20)
	_root.add_child(gap)
	var cont := UiKit.key_hints([["ENTER", "계속"]], 18, UiKit.TEXT_MUTE)
	_root.add_child(cont)
	_root.modulate.a = 0.0
	UiFx.fade(_root, 1.0, 0.6)


func show_calibration() -> void:
	_clear()
	_page = "calibrate"
	_root.add_child(UiKit.caption("DISPLAY CALIBRATION", UiKit.SIGNAL, 18))
	_root.add_child(UiKit.label("화면 밝기 조정", 36, UiKit.TEXT, "sans", 900))
	_root.add_child(UiKit.label("어두운 장면이 많은 게임입니다. 처음 한 번만 맞추면 되고, 설정에서 언제든 바꿀 수 있습니다.", 20, UiKit.BODY))
	var prev := SettingsPanel.BrightnessPreview.new()
	prev.custom_minimum_size = Vector2(980, 170)
	_root.add_child(prev)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_root.add_child(row)
	row.add_child(UiKit.label("밝기", 20, UiKit.BODY))
	_slider = HSlider.new()
	_slider.min_value = 0.6
	_slider.max_value = 1.6
	_slider.step = 0.02
	_slider.value = float(Game.settings.brightness)
	_slider.custom_minimum_size = Vector2(620, 30)
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.focus_mode = Control.FOCUS_NONE
	row.add_child(_slider)
	var val := UiKit.label("%d%%" % roundi(_slider.value * 100.0), 20, UiKit.SIGNAL, "display", 700)
	row.add_child(val)
	_slider.value_changed.connect(func(x):
		Game.settings.brightness = x
		val.text = "%d%%" % roundi(x * 100.0)
		Game.apply_settings())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	_root.add_child(h)
	var ok := UiKit.primary("확인", 22, _finish)
	ok.custom_minimum_size = Vector2(220, 58)
	h.add_child(ok)
	var keys := UiKit.key_hints([["←/→", "조정"], ["ENTER", "확인"]], 18, UiKit.TEXT_MUTE)
	keys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(keys)
	_root.modulate.a = 0.0
	UiFx.fade(_root, 1.0, 0.4)


func _process(delta: float) -> void:
	_age += delta
	# the notice moves on by itself after a while; calibration waits for the player
	if _page == "warning" and _age > 8.0:
		_next()


func _unhandled_input(event: InputEvent) -> void:
	if _page == "calibrate":
		if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
			_slider.value += _slider.step * 3.0 * (1.0 if event.is_action_pressed("ui_right") else -1.0)
		elif event.is_action_pressed("ui_accept"):
			_finish()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed()
	if pressed and _age > 1.0:
		get_viewport().set_input_as_handled()
		_next()


func _next() -> void:
	if not bool(Game.settings.calibrated):
		show_calibration()
	else:
		_finish()


func _finish() -> void:
	if _page == "":
		return
	_page = ""
	Game.settings.calibrated = true
	Game.save_settings()
	Snd.play("ui_tap", -10.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func():
		done.emit()
		queue_free())
