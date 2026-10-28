class_name Hud
extends CanvasLayer
## SIGN-language HUD: objective sign (top right) with its marker, toasts, subtitles, reticle, interaction prompt,
## warning banner, key hints, the clock / place row and what you are carrying (bottom right).

var has_target := false
var player: Player

# current-order sign (top left)
var _obj_root: VBoxContainer
var _obj_head: HBoxContainer
var _obj_tile: PanelContainer
var _obj_icon: UiIcon
var _obj_body: PanelContainer
var _obj_caption: FlapLabel
var _objective: FlapLabel
var _clock: FlapLabel
var _phase_chip: Label
var _phase_box: PanelContainer
var _zone: FlapLabel
var _obj_text := ""
var _boarding := false           # BOARDING-style signage (navy); off for now
var chip_text := ""              # chip beside the clock
var _quest_box: HBoxContainer    # top right: the current order (퀘스트)
var _obj_fade: Tween             # the panel's fade-out when an order is done; the next order cancels it
var _obj_dist: Label             # DAY 1: distance to the green diamond, beside the caption
var _marker: Control             # DAY 1 (tutorial): green diamond over where the current order is
var marker_pos: Variant = null   # world point the diamond points at (null = none); ShiftDirector.marker_target()
var _marker_t := 0.0
# toasts (top right)
var _notes_root: Control
var _notes: Array = []          # [{node, life, max, accent}]
# subtitles
var _sub_root: VBoxContainer
var _sub_chip_slot: HBoxContainer
var _sub_text: Label
var _sub_band: PanelContainer
var _sub_grad: Gradient
var _sub_time := 0.0
var _sub_fade: Tween            # fade-out of the last line; a new line cancels it
var _key_caps: Array = []      # [[keycap PanelContainer, action]] relabelled when keys are rebound
# reticle, prompt, observation
var _reticle: Control
var _target_k := 0.0
var _progress := -1.0
var _burst := 0.0
var _observe_label: Label
var _prompt_row: HBoxContainer
var _prompt_box: PanelContainer
var _prompt_text: Label
var _prompt_tw: Tween
# warning, hints
var _warn: Control
var _warn_text := ""
var _warn_t := 0.0
var _warn_age := 0.0
var _keys: PanelContainer
var _keys_t := 0.0
var _keys_tile: PanelContainer
var _keys_icon: UiIcon
var _keys_caption: Label
var _clock_override := ""        # "--:--" where time has stopped
var _items: HBoxContainer        # what you carry (bottom right)

## Names and icons of the things you can carry (Game.inventory).
const ITEMS := {"key_gate": ["열쇠", "key"]}


func _ready() -> void:
	layer = 5
	var root := Control.new()
	UiKit.full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_objective(root)
	_build_notes(root)
	_build_subtitles(root)
	_build_reticle(root)
	_build_warning(root)
	_build_controls(root)
	_build_items(root)
	_build_marker(root)   # last: the diamond pinned to a screen edge stays above the notes
	_keys_t = 40.0
	Events.subtitle.connect(show_subtitle)
	Events.notify.connect(add_note)
	Events.inventory_changed.connect(refresh_items)


func _build_items(root: Control) -> void:
	_items = HBoxContainer.new()
	_items.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_items.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_items.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_items.offset_right = -44
	_items.offset_bottom = -40
	_items.alignment = BoxContainer.ALIGNMENT_END
	_items.add_theme_constant_override("separation", 10)
	_items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_items)
	refresh_items()


## One sign tile per carried item; a new one flashes in.
func refresh_items() -> void:
	var had := _items.get_child_count()
	for c in _items.get_children():
		c.queue_free()
	var i := 0
	for id in Game.inventory:
		var it: Array = ITEMS.get(id, [id, "dot"])
		var tile := PanelContainer.new()
		tile.add_theme_stylebox_override("panel", UiKit.boxm(UiKit.SHADE, Vector4(12, 8, 16, 8)))
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(h)
		var ic := UiIcon.make(it[1], 26, UiKit.SIGNAL_TEXT)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		h.add_child(UiKit.label(it[0], 20, UiKit.TEXT, "sans", 700))
		_items.add_child(tile)
		if i >= had:
			tile.modulate = Color(2.0, 2.0, 2.0, 0.0)
			tile.create_tween().tween_property(tile, "modulate", Color.WHITE, 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		i += 1


# =========================================================================================
# build
# =========================================================================================
func _build_objective(root: Control) -> void:
	_obj_root = VBoxContainer.new()
	_obj_root.position = Vector2(44, 44)
	_obj_root.add_theme_constant_override("separation", 0)
	_obj_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_obj_root)
	# the current order hangs in the top right corner, the notes stack up under it
	_quest_box = HBoxContainer.new()
	_quest_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_quest_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_quest_box.offset_right = -44
	_quest_box.offset_top = 44
	_quest_box.alignment = BoxContainer.ALIGNMENT_END
	_quest_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_quest_box)
	_obj_head = HBoxContainer.new()
	_obj_head.add_theme_constant_override("separation", 0)
	_obj_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_box.add_child(_obj_head)
	_obj_tile = PanelContainer.new()
	_obj_tile.custom_minimum_size = Vector2(72, 0)
	_obj_tile.add_theme_stylebox_override("panel", UiKit.box(UiKit.SIGNAL, Color(0, 0, 0, 0), 0, 0, 0))
	_obj_head.add_child(_obj_tile)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_tile.add_child(cc)
	_obj_icon = UiIcon.make("order", 34, UiKit.SIGNAL_INK)
	cc.add_child(_obj_icon)
	_obj_body = PanelContainer.new()
	_obj_body.add_theme_stylebox_override("panel", UiKit.boxm(UiKit.SHADE, Vector4(18, 11, 22, 13)))
	_obj_head.add_child(_obj_body)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 2)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_obj_body.add_child(bv)
	var cap_row := HBoxContainer.new()
	cap_row.add_theme_constant_override("separation", 10)
	cap_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(cap_row)
	_obj_caption = FlapLabel.make("OBJECTIVE · 현재 목표", UiKit.MIN_TEXT, UiKit.SIGNAL_TEXT, "display", 700)
	_obj_caption.tick_sound = false
	_obj_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap_row.add_child(_obj_caption)
	_obj_dist = UiKit.label("", UiKit.MIN_TEXT, MARKER_GREEN, "display", 700)
	_obj_dist.visible = false
	cap_row.add_child(_obj_dist)
	_objective = FlapLabel.make("", 27, UiKit.TEXT, "sans", 700)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size = Vector2(430, 0)
	bv.add_child(_objective)
	_obj_head.visible = false
	# meta row: clock · phase · zone
	var meta := PanelContainer.new()
	meta.add_theme_stylebox_override("panel", UiKit.boxm(Color(0.035, 0.043, 0.055, 0.62), Vector4(14, 6, 16, 7)))
	meta.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_obj_root.add_child(meta)
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 12)
	mh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_child(mh)
	_clock = FlapLabel.make(Game.clock_text(), 20, UiKit.TEXT, "display", 700)
	_clock.tick_sound = false
	_clock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mh.add_child(_clock)
	_phase_box = PanelContainer.new()
	_phase_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mh.add_child(_phase_box)
	_phase_chip = UiKit.label("", UiKit.MIN_TEXT, UiKit.INK_0, "display", 700)
	_phase_box.add_child(_phase_chip)
	_refresh_phase_chip()
	var pin := UiIcon.make("pin", 18, UiKit.TEXT_DIM)
	pin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mh.add_child(pin)
	_zone = FlapLabel.make("", 18, UiKit.BODY, "sans", 500)
	_zone.tick_sound = false
	_zone.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mh.add_child(_zone)


## DAY 1 is the tutorial: the current order's place gets a green diamond, on screen or pinned to the screen edge
## in its direction, with the distance under it.
const MARKER_GREEN := Color(0.3, 0.92, 0.45)


func _build_marker(root: Control) -> void:
	_marker = Control.new()
	UiKit.full_rect(_marker)
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.draw.connect(_draw_marker)
	root.add_child(_marker)


func set_marker(pos: Variant) -> void:
	marker_pos = pos


func _draw_marker() -> void:
	if marker_pos == null or player == null or player.camera == null:
		return
	var cam := player.camera
	var wp: Vector3 = marker_pos
	var vs := _marker.size
	var dist := cam.global_position.distance_to(wp)
	var a := clampf((dist - 1.6) / 1.4, 0.0, 1.0)      # fades out once you are there
	if a <= 0.0:
		return
	var edge := 64.0
	var inner := Rect2(Vector2(edge, edge), vs - Vector2(edge, edge) * 2.0)
	var behind := cam.is_position_behind(wp)
	var sp := cam.unproject_position(wp)
	var off := behind or not inner.has_point(sp)
	var out_dir := Vector2.ZERO
	if off:
		# pinned to the screen edge, in the target's direction
		var c := vs * 0.5
		var d := (sp - c) if not behind else (c - sp)
		if d.length() < 1.0:
			d = Vector2(0, 1)
		var k := minf(absf(inner.size.x * 0.5 / d.x) if absf(d.x) > 0.001 else INF, absf(inner.size.y * 0.5 / d.y) if absf(d.y) > 0.001 else INF)
		sp = c + d * k
		out_dir = d.normalized()
	else:
		sp.y += sin(_marker_t * 3.2) * 4.0
	var r := 13.0
	var pts := PackedVector2Array([sp + Vector2(0, -r), sp + Vector2(r, 0), sp + Vector2(0, r), sp + Vector2(-r, 0)])
	var glow := PackedVector2Array([sp + Vector2(0, -r - 6), sp + Vector2(r + 6, 0), sp + Vector2(0, r + 6), sp + Vector2(-r - 6, 0)])
	_marker.draw_colored_polygon(glow, Color(MARKER_GREEN, 0.18 * a))
	_marker.draw_colored_polygon(pts, Color(MARKER_GREEN, 0.92 * a))
	pts.append(pts[0])
	_marker.draw_polyline(pts, Color(0.02, 0.12, 0.05, 0.9 * a), 2.0, true)
	var ri := r * 0.42
	_marker.draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -ri), sp + Vector2(ri, 0), sp + Vector2(0, ri), sp + Vector2(-ri, 0)]), Color(0.9, 1.0, 0.92, 0.85 * a))
	if off:
		var tip := sp + out_dir * (r + 14.0)
		var side := Vector2(-out_dir.y, out_dir.x) * 7.0
		_marker.draw_colored_polygon(PackedVector2Array([tip, sp + out_dir * (r + 5.0) + side, sp + out_dir * (r + 5.0) - side]), Color(MARKER_GREEN, 0.92 * a))
	var font := UiKit.font("display", 700)
	var txt := "%d m" % roundi(dist)
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	var tp := sp + Vector2(-tw * 0.5, r + 24.0)
	if off and out_dir.y > 0.5:
		tp.y = sp.y - r - 12.0          # pinned to the bottom edge: the distance goes above
	_marker.draw_string_outline(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, 5, Color(0, 0, 0, 0.7 * a))
	_marker.draw_string(font, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(0.92, 1.0, 0.94, a))


func _refresh_phase_chip() -> void:
	_phase_chip.text = chip_text
	_phase_box.visible = chip_text != ""
	var bg := UiKit.NAVY_TEXT if _boarding else UiKit.TEXT
	_phase_chip.add_theme_color_override("font_color", UiKit.NAVY if _boarding else UiKit.INK_0)
	_phase_box.add_theme_stylebox_override("panel", UiKit.boxm(bg, Vector4(8, 1, 8, 2)))


## Signage accent: signal blue, or boarding-pass cream once the terminal takes over (75%+).
func _accent() -> Color:
	return UiKit.NAVY_TEXT if _boarding else UiKit.SIGNAL


## The accent for text and thin marks on the dark HUD (the deep blue fill is too dark to read there).
func _accent_text() -> Color:
	return UiKit.NAVY_TEXT if _boarding else UiKit.SIGNAL_TEXT


func _build_notes(root: Control) -> void:
	_notes_root = Control.new()
	_notes_root.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_notes_root.offset_left = -644
	_notes_root.offset_right = -44
	_notes_root.offset_top = 44
	_notes_root.offset_bottom = 700
	_notes_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notes_root.clip_contents = false
	root.add_child(_notes_root)


func _build_subtitles(root: Control) -> void:
	_sub_root = VBoxContainer.new()
	_sub_root.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_sub_root.offset_left = -620
	_sub_root.offset_right = 620
	_sub_root.offset_top = -310
	_sub_root.offset_bottom = -156
	_sub_root.alignment = BoxContainer.ALIGNMENT_END
	_sub_root.add_theme_constant_override("separation", 10)
	_sub_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_sub_root)
	_sub_chip_slot = HBoxContainer.new()
	_sub_chip_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	_sub_chip_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_root.add_child(_sub_chip_slot)
	_sub_band = PanelContainer.new()
	var band := StyleBoxTexture.new()
	_sub_grad = Gradient.new()
	_sub_grad.offsets = PackedFloat32Array([0.0, 0.14, 0.86, 1.0])
	_set_sub_bg(0.62)
	var gt := GradientTexture2D.new()
	gt.gradient = _sub_grad
	gt.width = 256
	gt.height = 4
	band.texture = gt
	band.content_margin_left = 60
	band.content_margin_right = 60
	band.content_margin_top = 12
	band.content_margin_bottom = 14
	_sub_band.add_theme_stylebox_override("panel", band)
	_sub_band.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sub_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_root.add_child(_sub_band)
	_sub_text = UiKit.label("", 27, Color(0.97, 0.97, 0.97))
	_sub_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_text.custom_minimum_size = Vector2(1080, 0)
	_sub_text.add_theme_constant_override("outline_size", 6)
	_sub_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_sub_text.add_theme_constant_override("line_spacing", 4)
	_sub_band.add_child(_sub_text)
	_sub_root.visible = false


func _set_sub_bg(a: float) -> void:
	_sub_grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, a), Color(0, 0, 0, a), Color(0, 0, 0, 0)])


func _build_reticle(root: Control) -> void:
	_reticle = Control.new()
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reticle.draw.connect(_draw_reticle)
	root.add_child(_reticle)
	_observe_label = UiKit.caption("", UiKit.SIGNAL_TEXT, 16)
	_observe_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_observe_label.set_anchors_preset(Control.PRESET_CENTER)
	_observe_label.offset_left = -300
	_observe_label.offset_right = 300
	_observe_label.offset_top = 40
	_observe_label.offset_bottom = 62
	_observe_label.add_theme_constant_override("outline_size", 5)
	_observe_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_observe_label.modulate.a = 0.0
	root.add_child(_observe_label)
	_prompt_row = HBoxContainer.new()
	_prompt_row.set_anchors_preset(Control.PRESET_CENTER)
	_prompt_row.offset_left = -500
	_prompt_row.offset_right = 500
	_prompt_row.offset_top = 72
	_prompt_row.offset_bottom = 118
	_prompt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_prompt_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_prompt_row)
	_prompt_box = PanelContainer.new()
	_prompt_box.add_theme_stylebox_override("panel", UiKit.boxm(Color(0.035, 0.043, 0.055, 0.72), Vector4(6, 6, 16, 6)))
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_row.add_child(_prompt_box)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 12)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_box.add_child(ph)
	var use_cap := UiKit.keycap("E", 19)
	_key_caps.append([use_cap, "interact"])
	ph.add_child(use_cap)
	_prompt_text = UiKit.label("", 21, UiKit.TEXT, "sans", 700)
	_prompt_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ph.add_child(_prompt_text)
	_prompt_row.modulate.a = 0.0


## Control guide (bottom left): a sign panel with a keyboard tile, a WASD cluster and grouped keys.
func _build_controls(root: Control) -> void:
	_keys = PanelContainer.new()
	_keys.add_theme_stylebox_override("panel", UiKit.boxm(Color(0.035, 0.043, 0.055, 0.8), Vector4.ZERO))
	_keys.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_keys.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_keys.offset_left = 44
	_keys.offset_top = -40
	_keys.offset_bottom = -40
	_keys.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_keys)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys.add_child(h)
	_keys_tile = PanelContainer.new()
	_keys_tile.custom_minimum_size = Vector2(58, 0)
	_keys_tile.add_theme_stylebox_override("panel", UiKit.box(UiKit.SIGNAL, Color(0, 0, 0, 0), 0, 0, 0))
	h.add_child(_keys_tile)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_keys_tile.add_child(cc)
	_keys_icon = UiIcon.make("keyboard", 32, UiKit.SIGNAL_INK)
	cc.add_child(_keys_icon)
	var body := MarginContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [["margin_left", 18], ["margin_top", 10], ["margin_right", 22], ["margin_bottom", 12]]:
		body.add_theme_constant_override(side[0], side[1])
	h.add_child(body)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(v)
	_keys_caption = UiKit.caption("CONTROLS · 조작 안내", UiKit.SIGNAL_TEXT)
	v.add_child(_keys_caption)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	# movement cluster
	var mv := HBoxContainer.new()
	mv.add_theme_constant_override("separation", 10)
	row.add_child(mv)
	var cluster := VBoxContainer.new()
	cluster.add_theme_constant_override("separation", 3)
	mv.add_child(cluster)
	var top := HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	cluster.add_child(top)
	var w_cap := UiKit.keycap("W", 15, false)
	_key_caps.append([w_cap, "move_forward"])
	top.add_child(w_cap)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 3)
	cluster.add_child(bottom)
	for k in [["A", "move_left"], ["S", "move_back"], ["D", "move_right"]]:
		var kc := UiKit.keycap(k[0], 15, false)
		_key_caps.append([kc, k[1]])
		bottom.add_child(kc)
	mv.add_child(_guide_label("이동", "MOVE"))
	for group in [[["sprint", "달리기", "SPRINT"]], [["interact", "상호작용", "USE"], ["flashlight", "손전등", "LIGHT"]],
			[["tablet", "태블릿", "TABLET"], ["pause", "메뉴", "MENU"]]]:
		var sep := ColorRect.new()
		sep.color = Color(1, 1, 1, 0.12)
		sep.custom_minimum_size = Vector2(1, 46)
		sep.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(sep)
		for it in group:
			var item := HBoxContainer.new()
			item.add_theme_constant_override("separation", 8)
			var cap := UiKit.keycap(Game.key_label(it[0]), UiKit.MIN_TEXT, false)
			cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_key_caps.append([cap, it[0]])
			item.add_child(cap)
			item.add_child(_guide_label(it[1], it[2]))
			row.add_child(item)


## Korean action name (read in play, 18px) over a quiet English sign sub-label.
func _guide_label(kr: String, en: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(UiKit.label(kr, 18, UiKit.TEXT, "sans", 500))
	if not UiKit.same(kr, en):     # in English the sub-label would repeat the action name
		v.add_child(UiKit.label(en, 14, UiKit.TEXT_MUTE, "display", 700))
	return v


func _build_warning(root: Control) -> void:
	_warn = Control.new()
	_warn.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	_warn.anchor_top = 0.5
	_warn.anchor_bottom = 0.5
	_warn.offset_top = -250
	_warn.offset_bottom = -158
	_warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warn.draw.connect(_draw_warning)
	root.add_child(_warn)


# =========================================================================================
# per frame
# =========================================================================================
func _process(delta: float) -> void:
	# safety net: no target, no fade running, yet the prompt still shows -> fade it out
	if not has_target and _prompt_row.modulate.a > 0.0 and not (_prompt_tw and _prompt_tw.is_running()):
		_prompt_row.modulate.a = move_toward(_prompt_row.modulate.a, 0.0, delta * 8.0)
	# subtitles
	if _sub_time > 0.0:
		_sub_time -= delta
		if _sub_time <= 0.0:
			_sub_fade = create_tween()
			_sub_fade.tween_property(_sub_root, "modulate:a", 0.0, 0.3)
			_sub_fade.tween_callback(func(): _sub_root.visible = false)
	# warning
	if _warn_t > 0.0:
		_warn_t -= delta
		_warn_age += delta
	_warn.queue_redraw()
	# key hints
	if _keys_t > 0.0:
		_keys_t -= delta
		_keys.modulate.a = move_toward(_keys.modulate.a, clampf(_keys_t / 3.0, 0.0, 1.0), delta * 4.0)
		_keys.visible = _keys_t > 0.0
	# meta row
	_zone.flap_to(_zone_text())
	if _clock_override != "":
		_clock.flap_to(_clock_override, false)
	else:
		_clock.flap_to(Game.clock_text())
	# reticle
	_target_k = move_toward(_target_k, 1.0 if has_target else 0.0, delta * 7.0)
	_burst = move_toward(_burst, 0.0, delta * 1.8)
	_reticle.queue_redraw()
	_update_notes(delta)
	# DAY 1 diamond and its distance in the order panel; the notes stack starts under the order panel
	_marker_t += delta
	_marker.queue_redraw()
	var showing := marker_pos != null and _obj_head.visible and player != null and player.camera != null
	_obj_dist.visible = showing
	if showing:
		_obj_dist.text = "◆ %d m" % roundi(player.camera.global_position.distance_to(marker_pos))
	var top := 44.0 + (_obj_head.size.y + 14.0 if _obj_head.visible and _obj_head.modulate.a > 0.1 else 0.0)
	_notes_root.offset_top = lerpf(_notes_root.offset_top, top, 1.0 - exp(-delta * 10.0))
	_notes_root.offset_bottom = _notes_root.offset_top + 656.0


func _zone_text() -> String:
	if player == null:
		return ""
	return UiKit.t(Terminal.ZONE_NAMES.get(player.zone, ""))


# =========================================================================================
# objective
# =========================================================================================
func set_objective(text: String) -> void:
	text = UiKit.t(text)
	_obj_text = text
	if text == "":
		if _obj_head.visible:
			if _obj_fade:
				_obj_fade.kill()
			_obj_fade = create_tween()
			_obj_fade.tween_property(_obj_head, "modulate:a", 0.0, 0.18)
			_obj_fade.tween_callback(func():
				if _obj_text == "":
					_obj_head.visible = false)
		return
	# the next order usually follows straight on: stop the last one's fade-out, or it would hide this one
	if _obj_fade:
		_obj_fade.kill()
		_obj_fade = null
	var was_hidden := not _obj_head.visible or _obj_head.modulate.a < 0.5
	_obj_head.visible = true
	_obj_head.modulate.a = 1.0
	_objective.flap_to(_shown(text), not was_hidden, 0.0)
	if was_hidden:
		_objective.flap_to(_shown(text), false)
		_obj_head.pivot_offset = Vector2(0, 0)
		_obj_head.scale = Vector2(0.0, 1.0)
		var tw := create_tween()
		tw.tween_property(_obj_head, "scale:x", 1.0, 0.32).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		var txt := _shown(text)
		_objective.text = ""
		tw.tween_callback(func(): _objective.flap_to(txt))
	# the icon tile flashes like a sign switching on
	_obj_tile.modulate = Color(2.2, 2.2, 2.2)
	create_tween().tween_property(_obj_tile, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _shown(text: String) -> String:
	return text


## The clock as the meta row shows it ("--:--" once the story has taken the time away).
func clock_shown() -> String:
	return _clock_override if _clock_override != "" else Game.clock_text()


func set_clock_override(text: String) -> void:
	_clock_override = text


## The small chip beside the clock ("" hides it).
func set_chip(text: String) -> void:
	chip_text = text
	_refresh_phase_chip()


func _sync_boarding() -> void:
	pass


# =========================================================================================
# prompt, observation, hints, warning
# =========================================================================================
func set_prompt(text: String) -> void:
	var had := has_target
	has_target = text != ""
	if has_target:
		_prompt_text.text = UiKit.keep_all(UiKit.t(text))
	if has_target == had:
		return
	# one fade at a time: a show still running when the hide starts (it is the longer of the two) used to finish
	# last and leave the prompt on screen with nothing targeted (seen after alt-tab)
	if _prompt_tw and _prompt_tw.is_valid():
		_prompt_tw.kill()
	var tw := _prompt_row.create_tween().set_parallel(true)
	_prompt_tw = tw
	if has_target:
		_prompt_row.offset_top = 82
		_prompt_row.offset_bottom = 128
		tw.tween_property(_prompt_row, "modulate:a", 1.0, 0.16)
		tw.tween_property(_prompt_row, "offset_top", 72.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_prompt_row, "offset_bottom", 118.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(_prompt_row, "modulate:a", 0.0, 0.12)


func set_inspect_progress(v: float) -> void:
	if v < 0.0 and _progress >= 0.97:
		_burst = 1.0
	_progress = v
	if v >= 0.0:
		_observe_label.text = UiKit.t("OBSERVING · 관찰 중 %d%%") % int(clampf(v, 0.0, 1.0) * 100.0)
		_observe_label.modulate.a = 1.0
	elif _burst > 0.9:
		_observe_label.text = UiKit.t("OBSERVED · 관찰 완료")
		_observe_label.add_theme_color_override("font_color", UiKit.CLEAR)
		var tw := _observe_label.create_tween()
		tw.tween_interval(0.7)
		tw.tween_property(_observe_label, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func(): _observe_label.add_theme_color_override("font_color", _accent_text()))
	elif _observe_label.modulate.a > 0.0 and _burst <= 0.0:
		_observe_label.modulate.a = 0.0


## Key caps follow the current bindings (Settings › 조작 › 키 설정).
func refresh_keys() -> void:
	for kc in _key_caps:
		var l := (kc[0] as Control).get_child(0) as Label
		l.text = Game.key_label(kc[1])


func show_key_hints(seconds := 30.0) -> void:
	refresh_keys()
	var hidden := not _keys.visible or _keys.modulate.a < 0.1
	_keys_t = seconds
	_keys.visible = true
	if hidden:
		_keys.offset_bottom = -20.0
		_keys.offset_top = -20.0
		_keys.modulate.a = 0.0
		var tw := _keys.create_tween().set_parallel(true)
		tw.tween_property(_keys, "offset_bottom", -40.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_keys, "offset_top", -40.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func flash_warning(text: String, seconds := 0.6) -> void:
	if _warn_t <= 0.0 or text != _warn_text:
		Snd.play("ui_alert", -14.0, 0.8)
		if _warn_t <= 0.0:
			_warn_age = 0.0
	_warn_text = UiKit.t(text)
	_warn_t = maxf(_warn_t, seconds)


## Rule-warning sign: an opaque plate (readable over any lighting) with a red hazard tile. Only the
## frame pulses — the text itself stays steady and high-contrast.
func _draw_warning() -> void:
	if _warn_t <= 0.0 or _warn_text == "":
		return
	var w := _warn.size.x
	var h := _warn.size.y
	var a := clampf(_warn_t * 4.0, 0.0, 1.0)
	var open := ease(clampf(_warn_age / 0.2, 0.0, 1.0), 0.3)
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 1.0 if Game.settings.reduce_motion else 0.6 + 0.4 * absf(sin(t * 6.0))
	var f := UiKit.font("sans", 900)
	var fc := UiKit.font("display", 700)
	var fs := 34
	var tw := f.get_string_size(_warn_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var tile := h
	var pw := (tile + 28.0 + tw + 34.0) * open
	var x0 := (w - pw) * 0.5
	var plate := Rect2(x0, 0, pw, h)
	# soft drop shadow (stacked, fading rects) + plate
	for i in range(8, 0, -1):
		_warn.draw_rect(plate.grow(i * 2.0).grow_individual(0, -i * 0.5, 0, i * 1.0), Color(0, 0, 0, 0.055 * a))
	_warn.draw_rect(plate, Color(0.06, 0.03, 0.03, 0.94 * a))
	if open < 0.98:
		return
	# hazard tile
	var tr := Rect2(x0, 0, tile, h)
	_warn.draw_rect(tr, Color(UiKit.ALERT, a))
	var c := tr.get_center() + Vector2(0, 2)
	var ink := Color(UiKit.INK_0, a)
	_warn.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -20), c + Vector2(22, 17), c + Vector2(-22, 17)]), ink)
	_warn.draw_line(c + Vector2(0, -7), c + Vector2(0, 6), Color(UiKit.ALERT, a), 4.0)
	_warn.draw_line(c + Vector2(0, 10), c + Vector2(0, 13), Color(UiKit.ALERT, a), 4.0)
	# pulsing frame (not the text)
	var fr := Color(UiKit.ALERT, a * pulse)
	_warn.draw_rect(Rect2(x0 + tile, 0, pw - tile, 3), fr)
	_warn.draw_rect(Rect2(x0 + tile, h - 3, pw - tile, 3), fr)
	_warn.draw_rect(Rect2(x0 + pw - 3, 0, 3, h), fr)
	# caption + message
	var tx := x0 + tile + 28.0
	_warn.draw_string(fc, Vector2(tx, 25), UiKit.t("WARNING · 수칙 경고"), HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.MIN_TEXT, Color(UiKit.ALERT.lightened(0.25), a))
	var base := h * 0.5 + 12.0 + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5 - 6.0
	_warn.draw_string(f, Vector2(tx + 2, base + 2), _warn_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.6 * a))
	_warn.draw_string(f, Vector2(tx, base), _warn_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, a))


func _draw_reticle() -> void:
	if player and (player.eyes > 0.5 or not player.controls_enabled):
		return
	var k := _target_k
	var r := _reticle
	# with the crosshair off, the dot only appears over something usable
	if Game.settings.crosshair or k > 0.01:
		r.draw_circle(Vector2.ZERO, 2.0 + k * 0.8, Color(1, 1, 1, (0.55 if Game.settings.crosshair else 0.0) + 0.4 * k))
	if k > 0.01:
		r.draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 32, Color(1, 1, 1, 0.85 * k), 2.0, true)
		var d := 15.0 + (1.0 - k) * 10.0
		var l := 5.0
		var col := Color(1, 1, 1, 0.9 * k)
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var p := Vector2(d * sx, d * sy)
				r.draw_line(p, p - Vector2(l * sx, 0), col, 2.0)
				r.draw_line(p, p - Vector2(0, l * sy), col, 2.0)
	if _progress >= 0.0:
		r.draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 64, Color(1, 1, 1, 0.16), 4.0, true)
		var p := clampf(_progress, 0.0, 1.0)
		if p > 0.0:
			r.draw_arc(Vector2.ZERO, 30.0, -PI * 0.5, -PI * 0.5 + TAU * p, 64, _accent_text(), 4.0, true)
	if _burst > 0.0:
		var b := _burst
		r.draw_arc(Vector2.ZERO, 30.0 + (1.0 - b) * 46.0, 0.0, TAU, 64, Color(UiKit.CLEAR, b), 3.0 + b * 2.0, true)
		r.draw_polyline(PackedVector2Array([Vector2(-8, 0), Vector2(-2, 6), Vector2(9, -7)]), Color(UiKit.CLEAR, b), 3.0, true)


# =========================================================================================
# subtitles
# =========================================================================================
## Fades the current subtitle out now (a conversation the player has stepped to its end).
func hide_subtitle() -> void:
	if _sub_time > 0.0:
		_sub_time = 0.001


func show_subtitle(speaker: String, text: String, duration: float) -> void:
	# whole line first (scripted "speaker|text" keys), else speaker and text separately (radio())
	var full := UiKit.t(text)
	var who := ""
	var body := full
	if "|" in full:
		var parts := full.split("|", true, 1)
		who = UiKit.t(parts[0])
		body = UiKit.t(parts[1])
	if not Game.settings.subtitles:
		return
	# bilingual PA (Korean then English audio) reads the same once translated: keep the line up
	if _sub_root.visible and _sub_time > 0.0 and _sub_text.text == UiKit.keep_all(body):
		_sub_time = maxf(_sub_time, duration)
		return
	for c in _sub_chip_slot.get_children():
		c.queue_free()
	_sub_text.add_theme_font_size_override("font_size", [22, 27, 34][clampi(int(Game.settings.subtitle_size), 0, 2)])
	_set_sub_bg(float(Game.settings.subtitle_bg))
	var chip: Control
	match speaker:
		"radio":
			chip = UiKit.chip("RADIO · %s" % who, UiKit.OPS, Color("13283a"), "radio")
		"pa":
			# solid sign chip (white on the signal blue); the PA becomes a boarding call at 75%+
			chip = UiKit.chip("PA · 안내방송", UiKit.NAVY if _boarding else UiKit.SIGNAL_INK, _accent(), "speaker")
		"self":
			chip = UiKit.chip(who if who != "" else "나", UiKit.TEXT_DIM, Color(0.12, 0.14, 0.17, 0.85), "")
		"npc":
			# someone standing right there, not a radio voice
			chip = UiKit.chip(who, UiKit.TEXT, Color(0.16, 0.2, 0.26, 0.92), "person")
		"sound":
			# a caption for a sound ("[멀리서 바퀴 굴러가는 소리]"), not someone talking
			chip = UiKit.chip("소리", UiKit.TEXT_DIM, Color(0.12, 0.14, 0.17, 0.85), "speaker")
		_:
			chip = UiKit.chip(who if who != "" else "SYSTEM", UiKit.TEXT_DIM, Color(0.12, 0.14, 0.17, 0.85), "info")
	for ic in chip.find_children("*", "UiIcon", true, false):
		(ic as UiIcon).animated = speaker in ["radio", "pa"]
	_sub_chip_slot.add_child(chip)
	_sub_text.add_theme_color_override("font_color", Color(0.86, 0.87, 0.9) if speaker == "self" else (UiKit.TEXT_DIM if speaker == "sound" else Color(0.97, 0.97, 0.97)))
	_sub_text.text = UiKit.keep_all(body)
	# a line that follows straight on (the colleague talks without radio clicks in between) must not be
	# hidden by the previous line's fade-out finishing after it appeared
	if _sub_fade and _sub_fade.is_valid():
		_sub_fade.kill()
	var was := _sub_root.visible and _sub_root.modulate.a > 0.5
	_sub_root.visible = true
	_sub_root.modulate.a = 1.0
	_sub_time = duration
	UiFx.typewrite(_sub_text, clampf(body.length() * 0.022, 0.2, 0.9))
	if not was:
		chip.modulate.a = 0.0
		UiFx.fade(chip, 1.0, 0.18)


# =========================================================================================
# toasts
# =========================================================================================
const NOTE_KINDS := {
	"task": ["ORDER · 지시", "order"],
	"alert": ["URGENT · 긴급", "warn"],
	"good": ["CONFIRMED · 확인", "check"],
	"bad": ["WARNING · 경고", "warn"],
	"info": ["SYSTEM · 안내", "info"],
}


func add_note(text: String, kind: String) -> void:
	text = UiKit.t(text)
	if kind == "task":
		# the order sign already announces a new order; a toast repeating it is noise
		await get_tree().process_frame
		if _obj_text != "" and text.contains(_obj_text):
			return
	var accent := UiKit.TEXT_DIM
	match kind:
		"task":
			accent = UiKit.SIGNAL
		"alert":
			accent = UiKit.WARN
		"good":
			accent = UiKit.CLEAR
		"bad":
			accent = UiKit.ALERT
	var meta: Array = NOTE_KINDS.get(kind, NOTE_KINDS.info)
	var caption: String = meta[0]
	var bg := Color(0.035, 0.043, 0.055, 0.9)
	var ink := UiKit.TEXT
	if _boarding:
		# taken over: notices arrive as boarding information (danger stays red)
		if kind not in ["alert", "bad"]:
			accent = UiKit.NAVY_TEXT
		caption = UiKit.corrupt(caption)
		bg = Color(UiKit.NAVY, 0.92)
		ink = UiKit.NAVY_TEXT
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiKit.boxm(bg, Vector4.ZERO))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = Vector2(600, 0)
	panel.custom_minimum_size = Vector2(600, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(h)
	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(56, 0)
	tile.add_theme_stylebox_override("panel", UiKit.box(accent, Color(0, 0, 0, 0), 0, 0, 0))
	h.add_child(tile)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(cc)
	cc.add_child(UiIcon.make(meta[1], 26, UiKit.NAVY if _boarding and accent == UiKit.NAVY_TEXT else UiKit.ink_on(accent)))
	var body := MarginContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [["margin_left", 16], ["margin_top", 11], ["margin_right", 16], ["margin_bottom", 13]]:
		body.add_theme_constant_override(side[0], side[1])
	h.add_child(body)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(v)
	var accent_text := UiKit.SIGNAL_TEXT if accent == UiKit.SIGNAL else accent
	v.add_child(UiKit.caption(caption, Color("9fb3e0") if _boarding and accent == UiKit.NAVY_TEXT else accent_text))
	var l := UiKit.rich(UiKit.key_bbcode(text), 20, ink)
	l.custom_minimum_size = Vector2(512, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	var rec := {"node": panel, "life": 5.0 if kind != "alert" else 7.0, "max": 5.0 if kind != "alert" else 7.0, "accent": accent}
	panel.draw.connect(func():
		var rem := clampf(rec.life / rec.max, 0.0, 1.0)
		panel.draw_rect(Rect2(56, panel.size.y - 2, (panel.size.x - 56) * rem, 2), accent_text))
	_notes_root.add_child(panel)
	_notes.insert(0, rec)
	panel.position = Vector2(640, 0)
	panel.modulate.a = 0.0
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "position:x", 0.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.18)
	tile.modulate = Color(1.8, 1.8, 1.8)
	tw.tween_property(tile, "modulate", Color.WHITE, 0.5)
	while _notes.size() > 3:
		_dismiss(_notes[_notes.size() - 1])


func _dismiss(rec: Dictionary) -> void:
	_notes.erase(rec)
	var panel: Control = rec.node
	if not is_instance_valid(panel):
		return
	var tw := panel.create_tween().set_parallel(true)
	tw.tween_property(panel, "position:x", 640.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(panel, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(panel.queue_free)


func _update_notes(delta: float) -> void:
	var y := 0.0
	for rec in _notes.duplicate():
		var panel: Control = rec.node
		if not is_instance_valid(panel):
			_notes.erase(rec)
			continue
		rec.life -= delta
		if rec.life <= 0.0:
			_dismiss(rec)
			continue
		panel.position.y = lerpf(panel.position.y, y, 1.0 - exp(-delta * 14.0))
		panel.queue_redraw()
		y += panel.size.y + 8.0


func set_visible_all(v: bool) -> void:
	visible = v
