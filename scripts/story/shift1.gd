class_name Shift1
extends StoryScript
## The game from its start (user, 2026-11-05: "게임 루프를 다시 정해줄게" — the prologue and the old chapter 1 are out
## of the game; Game.start_new_game comes here). On black, the letter that hired you (LETTER): the night shift at A
## International Airport from 22:00 tonight, in by the staff entrance to the facilities team's office, give your name
## to the member of staff there. Any key, and you are on the 4th floor with your back to the lift you came up in, its
## doors sliding shut behind you, in the corridors that wind round the office (ServiceHall). Find your way round to
## the office's door on the west corridor — it opens ([E]) and you walk in (a PortalView each way: the corridors and
## the office are built apart; Lift.carry moves you across while the door stands open) — and at the guard's desk the
## facilities supervisor (OfficeNpc) is waiting to hand over the night: talk to him with [E]. Nothing is shown as a goal
## (objective() only records the beat). The lift and the stairs still go down to the lounge.

## The letter, a paragraph a block, in the user's words (2026-11-05, second version); the first is its heading (bold,
## a size up), [b] marks the part shown bold and yellow, the last is the sender.
const LETTER := [
	"귀하의 합격을 진심으로 축하드립니다.",
	"귀하는 A국제공항 야간 시설관리팀 계약직 채용에 최종 합격하셨습니다.",
	"근무 시작에 앞서 필요한 절차를 진행하기 위해\nA국제공항 내부에 위치한 [b]시설관리팀 관리실로 방문해[/b] 주시기 바랍니다.",
	"앞으로 귀하와 함께하게 되기를 기대합니다.",
	"A국제공항 채용 담당 부서",
]
const TASK_FIND := "시설관리팀 관리실 찾기"
const TASK_TALK := "시설 관리자와 대화하기"
## After the handover (user: "관리자와 대화가 끝나면 ui로 … 이렇게 띄워죠"): the uniform is in locker 04 in the office
## (user: "직원복은 관리실안에 있는 사물함에서 갈아 입을 수 있게"), the flashlight on the guard's desk (user: "플래시
## 라이트는 그냥 책상 위에다가 올려줘"), the guidelines folder on a shelf in the records room (user: "자료실 선반에 이런
## 지참서 올려놔줘", ArchiveRoom.GUIDE).
const TASK_UNIFORM := "[b]사물함[/b]에 있는 작업복으로 갈아입기"       # ([b]: shown yellow — user)
const TASK_GUIDE := "[b]자료실[/b]에 있는 지침서 챙기기"
const TASK_LIGHT := "[b]책상위[/b]에 있는 손전등 챙기기"
const TASKS_AFTER := [TASK_UNIFORM, TASK_LIGHT, TASK_GUIDE]                  # (in this order — user)
## On the guard's desk top (the south arm's island, its west block, south desk): along its front edge right of the chair
## (behind the chair's back a step away you could not see it), in front of the phone.
const LIGHT_AT := Vector3(-18.135, OfficeKit.DESK_H, -18.9)
const GUIDE_H := 0.3                                             # the folder picture's height (clip to foot)
const START_LOCAL := ServiceHall.FAR + Vector3(0, 0.05, -1.4)   # before the lift, your back to it (corridor space)
const BOSS_AT := Vector3(-24.975, 0.0, -29.95)                  # the deepest desk: the north arm's west block, its north seat
const BOSS_YAW := PI + 0.2                                       # facing his desk (south)

var hall: ServiceHall
var boss: OfficeNpc
var in_office := false            # you have walked into the office
var _in_view: PortalView          # from the corridor: the office through its west door
var _out_view: PortalView         # from the office: the corridor through the same door
var _door_open := false
var _side := 0                    # where you are: 0 the corridors, 1 the office
var _close_t := 0.0
var _crossing := false
var _found := false               # the to-do (find the office) ticked off
var changed := false              # in the staff uniform
var has_light := false            # the flashlight found
var _uniform: Node3D              # what hangs in locker 04 (the uniform, then your own jacket)
var _uniform_use: Interactable
var _light_node: Node3D           # the flashlight on the desk
var _light_use: Interactable
var has_guide := false            # the guidelines found
var _guide: Node3D                # the folder on its shelf
var _guide_use: Interactable
var _runner: OfficeNpc            # the manager, running up to you once you have the guidelines


func setup() -> void:
	var t := d.terminal
	hall = t.service_hall
	# the office and the corridors round it lit; the lounge below lights when you get there
	for zn in t.zones:
		t.set_zone_light(zn, zn == "secoffice", true)
	(t.zones.secoffice as LightZone).night_dim = 1.0
	hall.zone.set_on(true, true)
	t.crossed.connect(_crossed)
	d.set_clock(21 * 60 + 52)
	_build_door()
	boss = OfficeNpc.create(t.sec_root, BOSS_AT, BOSS_YAW)
	boss.hud = d.ui.hud
	boss.started.connect(func(): d.ui.hud.task_done(TASK_TALK))   # ticked as the talk begins (user)
	boss.line_said.connect(func(i: int):
		if i == OfficeNpc.RADIO_LINE:
			_give_radio())
	Terminal.office_layers(boss)
	Game.remove_item("radio")
	# no flashlight until you find one (its [F] hint hidden too)
	Game.remove_item("flashlight")
	d.player.flashlight_owned = false
	if d.player.flashlight_on:
		d.player.toggle_flashlight(0)
	d.ui.hud.set_flashlight_hint(false)
	_hang_uniform()
	_place_flashlight()
	_place_guide()
	t.locker_toggled.connect(_locker_toggled)
	d.tab_opens = "none"                                  # [Tab] opens nothing until you have the guidelines
	d.ui.hud.hide_key_hints()                            # no controls guide on screen (user)
	# your back to the lift you came up in, its doors still open
	t.lift.open_now(0)
	t.lift.locked = true                                 # you cannot take it back down (user: "그때는 엘베를 탈 수 없어")
	d.player.teleport(Transform3D(Basis(), hall.to_global(START_LOCAL)))
	d.player.zone_override = "servicehall"
	d.player.no_sprint = true                            # no running in the corridors
	d.ui.cut_to(1.0)


func run() -> void:
	Snd.set_ambience("amb_night_loop", -20.0, 3.0)
	d.player.controls_enabled = false
	await _letter()
	d.terminal.lift.shut()                               # the doors slide shut behind you as the picture comes up
	await d.ui.fade_to(0.0, 1.8)
	d.player.controls_enabled = true
	d.objective("시설관리팀 관리실 찾기")
	await d.wait(0.6)
	# the to-do list, top left (user): both lines at once, each ticked off and gone when it is done
	d.ui.hud.task_show(TASK_FIND)
	d.ui.hud.task_show(TASK_TALK)
	await d.until(func(): return in_office)
	d.objective(TASK_TALK)
	await d.until(func(): return boss.talked)
	d.clear_objective()
	# what to do now: on the to-do list, top left
	await d.wait(0.4)
	for task: String in TASKS_AFTER:
		if not (task == TASK_UNIFORM and changed) and not (task == TASK_LIGHT and has_light) and not (task == TASK_GUIDE and has_guide):   # (done before he finished)
			d.ui.hud.task_show(task)


# --------------------------------------------------------------------------------------------
## The staff uniform on its hanger in locker 04 ([E] once the locker is open: 직원복으로 갈아입기).
func _hang_uniform() -> void:
	var hang: Node3D = d.terminal.sec_locker.hang
	_uniform = _clothes(hang, true)
	_uniform_use = Interactable.create(hang, Vector3(0, -0.32, 0.0), Vector3(0.34, 0.7, 0.22), "직원복으로 갈아입기", _change)
	_uniform_use.press_sound = ""
	_uniform_use.enabled = false
	_uniform_use.collision_layer = 0                     # behind the shut door: nothing to reach
	Terminal.office_layers(hang)


func _locker_toggled(open: bool) -> void:
	if _uniform_use and not changed:
		_uniform_use.enabled = open
		_uniform_use.collision_layer = Geo.LAYER_INTERACT if open else 0


## A jacket on a wire hanger under the rail (`hang`, facing +Z): the staff uniform — navy work jacket, grey reflective
## bands, a zip, a white name badge, its cap on the shelf above — or, once you have changed, your own jacket.
func _clothes(hang: Node3D, staff: bool) -> Node3D:
	var n := Node3D.new()
	n.name = "Uniform" if staff else "OwnJacket"
	hang.add_child(n)
	var wire := Mats.get_mat("metal")
	var cloth := Mats.std(Color(0.11, 0.14, 0.22), 0.85) if staff else Mats.std(Color(0.5, 0.47, 0.41), 0.9)
	Geo.cyl(n, Vector3(0, -0.02, 0), 0.003, 0.05, wire)                                      # the hook
	for s: float in [-1.0, 1.0]:
		var arm := Geo.box(n, Vector3(s * 0.09, -0.07, 0), Vector3(0.19, 0.006, 0.006), wire, false)
		arm.rotation.z = -s * 0.38
		var shoulder := Geo.box(n, Vector3(s * 0.1, -0.1, 0), Vector3(0.18, 0.05, 0.1), cloth, false)
		shoulder.rotation.z = -s * 0.36
		var sleeve := Geo.box(n, Vector3(s * 0.175, -0.38, 0.0), Vector3(0.075, 0.5, 0.075), cloth, false)
		sleeve.rotation.z = s * 0.07
	Geo.box(n, Vector3(0, -0.4, 0), Vector3(0.3, 0.58, 0.085), cloth, false)                # the body
	Geo.box(n, Vector3(0, -0.11, 0.025), Vector3(0.13, 0.05, 0.06), cloth, false)          # the collar
	if staff:
		var tape := Mats.std(Color(0.86, 0.88, 0.86), 0.3, 0.2)
		for y: float in [-0.52, -0.6]:
			Geo.box(n, Vector3(0, y, 0.044), Vector3(0.3, 0.022, 0.004), tape, false)
		for s: float in [-1.0, 1.0]:
			Geo.box(n, Vector3(s * 0.178, -0.5, 0.039), Vector3(0.076, 0.02, 0.004), tape, false)
		Geo.box(n, Vector3(0, -0.4, 0.044), Vector3(0.006, 0.56, 0.003), wire, false)         # zip
		Geo.box(n, Vector3(-0.08, -0.24, 0.045), Vector3(0.07, 0.035, 0.003), Mats.get_mat("plastic_white"), false)  # badge
		Geo.box(n, Vector3(0.08, -0.24, 0.045), Vector3(0.045, 0.03, 0.003), Mats.std(Color(0.12, 0.26, 0.62), 0.6), false)
		# the cap on the shelf
		var cap := Geo.sphere(n, Vector3(0, 0.15, -0.02), 0.08, cloth)
		cap.scale = Vector3(1.0, 0.55, 1.05)
		Geo.box(n, Vector3(0, 0.125, 0.085), Vector3(0.13, 0.008, 0.08), cloth, false)       # brim
	else:
		var hood := Geo.box(n, Vector3(0, -0.13, -0.05), Vector3(0.2, 0.14, 0.05), cloth, false)
		hood.rotation.x = 0.3
	return n


## [E] on the uniform: the screen goes dark, you change (fabric, a zip), your own jacket goes on the hanger.
func _change() -> void:
	if changed:
		return
	changed = true
	_uniform_use.enabled = false
	_uniform_use.collision_layer = 0
	d.player.controls_enabled = false
	await d.ui.fade_to(1.0, 0.45)
	Snd.play("cloth_change", -8.0, 1.0, "SFX")
	_uniform.queue_free()
	_uniform = _clothes(d.terminal.sec_locker.hang, false)
	Terminal.office_layers(_uniform)
	Game.set_flag("uniform")
	await d.wait(2.2)
	await d.ui.fade_to(0.0, 0.6)
	d.player.controls_enabled = true
	Events.notify.emit("직원복으로 갈아입었다.", "good")
	d.ui.hud.task_done(TASK_UNIFORM)


# --------------------------------------------------------------------------------------------
## The flashlight lying on the guard's desk (LIGHT_AT), two spare batteries beside it; [E] on it.
func _place_flashlight() -> void:
	var o: Node3D = d.terminal.sec_root
	_light_node = Node3D.new()
	_light_node.name = "Flashlight"
	o.add_child(_light_node)
	_light_node.position = LIGHT_AT
	_light_node.rotation.y = 0.06
	var black := Mats.std(Color(0.05, 0.05, 0.055), 0.4, 0.3)
	var grip := Mats.std(Color(0.1, 0.1, 0.11), 0.85)
	for p: Array in [[Vector3(-0.005, 0.019, 0), 0.018, 0.16, black], [Vector3(0.1, 0.027, 0), 0.027, 0.05, black],
			[Vector3(0.0785, 0.024, 0), 0.022, 0.02, black], [Vector3(-0.09, 0.0185, 0), 0.0175, 0.016, grip]]:
		var c := Geo.cyl(_light_node, p[0], p[1], p[2], p[3])
		c.rotation.z = PI / 2
	for k in 4:
		var ring := Geo.cyl(_light_node, Vector3(-0.055 + k * 0.022, 0.019, 0), 0.0188, 0.008, grip)
		ring.rotation.z = PI / 2
	var lens := Geo.cyl(_light_node, Vector3(0.1255, 0.027, 0), 0.023, 0.003, Mats.std(Color(0.78, 0.8, 0.78), 0.05, 0.7))
	lens.rotation.z = PI / 2
	Geo.box(_light_node, Vector3(0.045, 0.038, 0), Vector3(0.022, 0.008, 0.012), grip, false)   # the switch
	var bats := Node3D.new()
	o.add_child(bats)
	bats.position = LIGHT_AT + Vector3(-0.27, 0.0, -0.005)
	bats.rotation.y = PI / 2 + 0.1
	for k in 2:
		var bat := Geo.cyl(bats, Vector3(k * 0.022, 0.007, 0), 0.007, 0.05, Mats.std(Color(0.75, 0.6, 0.12), 0.5, 0.4))
		bat.rotation.x = PI / 2
	_light_use = Interactable.create(_light_node, Vector3(0.02, 0.03, 0), Vector3(0.28, 0.09, 0.12), "플래시 라이트 줍기", _take_light)
	_light_use.press_sound = ""
	Terminal.office_layers(_light_node)
	Terminal.office_layers(bats)


# --------------------------------------------------------------------------------------------
## The guidelines: the user's folder picture (assets/textures/level/guide_folder.png, cut out by
## tools/make_guide_tex.gd) standing on its shelf in the records room (ArchiveRoom.guide_xform), a kraft board with
## its papers behind it; lit by the room's own lamps (sealed). [E] 지침서 챙기기.
func _place_guide() -> void:
	var hall_n: ServiceHall = d.terminal.service_hall
	_guide = Node3D.new()
	_guide.name = "Guidelines"
	hall_n.add_child(_guide)
	_guide.transform = ArchiveRoom.guide_xform()
	var h := GUIDE_H
	var w := h * 372.0 / 420.0
	var pic := StandardMaterial3D.new()
	pic.albedo_texture = load("res://assets/textures/level/guide_folder.png")
	pic.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	pic.alpha_scissor_threshold = 0.5
	pic.roughness = 0.85
	pic.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var q := QuadMesh.new()
	q.size = Vector2(w, h)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = pic
	_guide.add_child(mi)
	mi.position = Vector3(0, h * 0.5, 0.001)
	# the folder's body behind (image x 24..322, y 20..401 of 372 x 420: without the tab and the clip)
	var bw := w * (322.0 - 24.0) / 372.0
	var bh := h * (401.0 - 20.0) / 420.0
	var bx := w * ((24.0 + 322.0) * 0.5 / 372.0 - 0.5)
	var by := h * (1.0 - (20.0 + 401.0) * 0.5 / 420.0)
	Geo.box(_guide, Vector3(bx, by, -0.008), Vector3(bw, bh, 0.016), Mats.std(Color(0.7, 0.55, 0.37), 0.85), false)
	_guide_use = Interactable.create(_guide, Vector3(0, h * 0.5, 0.0), Vector3(w, h, 0.12), "지침서 챙기기", _take_guide)
	_guide_use.press_sound = ""
	_guide_use.set_meta("floor_y", hall_n.global_position.y)       # (for the reach audit: it stands in a shelf)
	Geo.seal(_guide)


func _take_guide() -> void:
	if has_guide:
		return
	has_guide = true
	Snd.play("page_flip", -6.0)
	Game.add_item("guide")
	_guide.queue_free()
	_guide = null
	_guide_use = null
	Events.notify.emit("지침서를 찾았다.", "good")
	d.ui.hud.task_done(TASK_GUIDE)
	# now [Tab] opens it (user: "지침서를 얻으면 tab을 눌러 열 수 있고 … ui로 안내해줘")
	d.tab_opens = "guide"
	_manager_runs_in()
	await d.wait(1.2)
	Events.notify.emit("[TAB] 지침서를 열 수 있습니다.", "info")


## Once you have the guidelines the manager comes running from your right (user: "자료실에서 지침서를 얻으면 우측에서
## 관리자가 뛰어와서 말을 걸어"): from the far end of the records room's back aisle — the guidelines' shelf faces the
## third aisle west, so its back end is on your right — round into your aisle, up to you, and he talks.
## ARCHIVE_LINES is a stand-in (he only catches his breath) until the user gives his lines.
const ARCHIVE_LINES := ["……헉, 헉……"]


func _manager_runs_in() -> void:
	if _runner:
		return
	var hall_n: ServiceHall = d.terminal.service_hall
	var a3: float = ArchiveRoom.AISLES[2]
	var back_z := ArchiveRoom.ROW_Z - ArchiveRoom.BAYS * ArchiveRoom.BAY - 0.95          # the back aisle's middle
	var start := Vector3(ArchiveRoom.ROOM.end.x - 0.6, 0.0, back_z)
	# the one at his desk or on his bed is gone
	if boss:
		if boss.talking:
			boss._end_talk()
		boss.queue_free()
	await d.wait(0.8)
	_runner = OfficeNpc.create_standing(hall_n, start, PI / 2)
	_runner.hud = d.ui.hud
	Geo.seal(_runner)                                    # (lit by the records room's own lamps)
	boss = _runner
	var p := hall_n.to_local(d.player.global_position)
	var stop_z := clampf(p.z - 1.25, back_z + 0.4, ArchiveRoom.ROW_Z - 0.4)
	_runner.run_path([Vector3(a3, 0.0, back_z), Vector3(a3, 0.0, stop_z)], 3.8)
	await _runner.arrived
	Geo.blocker(_runner, Vector3(0, 0.9, 0), Vector3(0.5, 1.8, 0.34))
	await d.wait(0.35)
	_runner.say_lines(ARCHIVE_LINES)


func _take_light() -> void:
	if has_light:
		return
	has_light = true
	Snd.play("key_pickup", -6.0)
	Game.add_item("flashlight")
	d.player.flashlight_owned = true
	d.ui.hud.set_flashlight_hint(true)
	_light_node.queue_free()
	_light_node = null
	_light_use = null
	Events.notify.emit("플래시 라이트를 찾았다.", "good")
	d.ui.hud.task_done(TASK_LIGHT)
	await d.wait(1.4)
	Events.notify.emit("[F] 손전등을 켜고 끌 수 있습니다.", "info")


## He hands you the radio as he tells you what it is for: it goes in your belongings (the tile bottom right), a toast
## says so, a pickup and the radio's own click (user: "무전기를 얻었다는 표시가 있었으면").
func _give_radio() -> void:
	if Game.has_item("radio"):
		return
	Game.add_item("radio")
	Snd.play("card_pickup", -6.0)
	Snd.play("radio_on", -16.0, 1.05)
	Events.notify.emit("무전기를 받았다.", "good")


## The letter on black, a paragraph at a time, then "any key".
func _letter() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	# only the letter is in the centred column, so it sits in the middle of the screen (user: "화면의 중앙에");
	# the "any key" hint is pinned near the bottom on its own. (A handwritten card version was tried and dropped the
	# same day — user: "그 전으로 되돌려줘".)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 52)        # (lines and paragraphs spaced out — user: "글자 단이 너무 붙어")
	center.add_child(col)
	var paras: Array[RichTextLabel] = []
	for i in LETTER.size():
		# a plain, square-cut face (user: "담백하고 각진 글씨체"): the sign face (Bahnschrift) with the plain Korean gothic
		var r := UiKit.rich(LETTER[i], 26, Color(0.9, 0.9, 0.88), "display")
		r.custom_minimum_size = Vector2(1000, 0)
		# the part in bold is the one to remember: yellow (user: "시설관리팀 관리실로 방문해 여기는 노란색으로")
		var body := r.text.replace("[b]", "[b][color=#ffc21a]").replace("[/b]", "[/color][/b]")
		if i == 0:
			body = "[font_size=31][b]%s[/b][/font_size]" % body              # the heading
		r.text = "[center]%s[/center]" % body
		r.add_theme_constant_override("line_separation", 16)
		r.modulate.a = 0.0
		col.add_child(r)
		paras.append(r)
	var hint := UiKit.label("계속하려면 아무 키나 누르세요", 18, UiKit.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate.a = 0.0
	root.add_child(hint)
	hint.anchor_left = 0.0
	hint.anchor_right = 1.0
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 0.0
	hint.offset_right = 0.0
	hint.offset_top = -110.0
	hint.offset_bottom = -76.0
	await d.wait(0.6)
	# a sentence at a time, quicker (user: "문단이 나오는 속도가 너무 빨라", "아주 조금 빠르게", then "합격메세지 올라오는거
	# 너무 느려" and "문장만 좀 더 빠르게": each fades in over 0.8 s, the next 1.4 s later)
	for r in paras:
		r.create_tween().tween_property(r, "modulate:a", 1.0, 0.8)
		await d.wait(1.4)
	await d.wait(0.5)
	var breathe := hint.create_tween().set_loops()
	breathe.tween_property(hint, "modulate:a", 0.85, 1.1)
	breathe.tween_property(hint, "modulate:a", 0.35, 1.1)
	# any key (let go of whatever was held when the game started first)
	if OS.get_cmdline_user_args().has("--storytest"):
		await d.wait(1.5)                                   # (the bot presses nothing: let a shot see the hint)
	await d.until(func(): return not Input.is_anything_pressed())
	await d.until(func(): return Input.is_anything_pressed() or OS.get_cmdline_user_args().has("--storytest"))
	breathe.kill()
	var out := root.create_tween()
	out.tween_property(root, "modulate:a", 0.0, 0.9)
	await out.finished
	layer.queue_free()


# --------------------------------------------------------------------------------------------
## The office's door on the west corridor: the corridors' copy of it (ServiceHall.entry) and the office's own
## (Terminal.sec_entry) open and shut together; while it stands open, the side you are on shows the other through it
## (PortalView on the dark box behind the corridor's copy / on the dark vestibule outside the office's), and walking
## through carries you across. It shuts by itself behind you.
func _build_door() -> void:
	var t := d.terminal
	var env: Environment = null
	for we: WorldEnvironment in d.world.find_children("*", "WorldEnvironment", true, false):
		env = we.environment
	_in_view = PortalView.create(hall, _hall_frame(), _office_frame(), d.player.camera, env)
	for m: MeshInstance3D in hall.entry_closet:
		m.material_override = _in_view.surface_material()
	_out_view = PortalView.create(t, _office_frame(), _hall_frame(), d.player.camera, env)
	for m: MeshInstance3D in t.sec_vestibule:
		m.material_override = _out_view.surface_material()
		m.layers = Geo.VIS_PORTAL_HIDDEN               # (the corridor's view of the office looks through it)
	for door: Dictionary in [hall.entry, t.sec_entry]:
		(door.leaf as Node3D).visible = true
		(door.leaf as Node3D).rotation.y = 0.0
		(door.block as StaticBody3D).collision_layer = Geo.LAYER_WORLD
		var use := door.use as Interactable
		use.prompt = "문 열기"
		use.enabled = true
		use.callback = _toggle
	t.sec_reader.interactable.enabled = false
	var into := Geo.area(hall, ServiceHall.ENTRY + Vector3(0.8, 1.0, 0.0), Vector3(0.6, 2.0, 1.0))
	into.body_entered.connect(func(body):
		if body == d.player and _door_open and _side == 0 and not _crossing:
			_cross.call_deferred(1))
	var out := Geo.area(t, Vector3(-23.2, 1.0, Terminal.SEC_ENTRY_Z), Vector3(0.6, 2.0, 1.0))
	out.body_entered.connect(func(body):
		if body == d.player and _door_open and _side == 1 and not _crossing:
			_cross.call_deferred(0))


func _office_frame() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, -PI / 2), (d.terminal.sec_entry.root as Node3D).global_position)


func _hall_frame() -> Transform3D:
	return hall.entry_frame()


func _toggle() -> void:
	if _crossing:
		return
	_set_door(not _door_open)


func _set_door(open: bool) -> void:
	if not open and _in_doorway():
		return
	_door_open = open
	var t := d.terminal
	if open and _side == 0 and not _found:
		_found = true
		d.ui.hud.task_done(TASK_FIND)                    # found it: ticked, and the line goes (user)
	for door: Dictionary in [t.sec_entry, hall.entry]:
		t.swing_door(door, 84.0 if open else 0.0, 0.9 if open else 0.6)
		(door.use as Interactable).prompt = "문 닫기" if open else "문 열기"
	var here: Node3D = hall.entry.root if _side == 0 else t.sec_entry.root
	Snd.play_at("door_heavy" if open else "door_slam", here.global_position + Vector3(0, 1.0, 0), -10.0 if open else -13.0, 1.1, 5.0)
	_views()


func _views() -> void:
	_in_view.set_active(_door_open and _side == 0)
	_out_view.set_active(_door_open and _side == 1)


## Standing in the doorway (either copy): the door will not shut on you.
func _in_doorway() -> bool:
	var p := d.player.global_position
	for r: Node3D in [hall.entry.root, d.terminal.sec_entry.root]:
		var q := r.global_transform.affine_inverse() * p
		if absf(q.x) < 0.7 and absf(q.z) < 0.75 and absf(q.y) < 2.0:
			return true
	return false


## Through the door: the same spot, heading and pace on the other side.
func _cross(to: int) -> void:
	_crossing = true
	if to == 1:
		Lift.carry(d.player, _hall_frame(), _office_frame())
	else:
		Lift.carry(d.player, _office_frame(), _hall_frame())
	_side = to
	d.player.zone_override = "" if to == 1 else "servicehall"
	d.player.no_sprint = to == 0
	if to == 1:
		in_office = true
	elif boss.talked and not boss.asleep and not boss.standing:
		_to_bed()
	_views()
	_close_t = 1.4
	_crossing = false


## He has gone to rest (his last line): once you are out of the office after the handover, he is asleep on the
## night-duty room's bed when you come back (user: "관리실 나갔다 들어오면 관리자는 숙직실 침대 위에 누워있게").
func _to_bed() -> void:
	if boss.talking:
		boss._end_talk()
	boss.queue_free()
	boss = OfficeNpc.create_asleep(d.terminal.dorm_bed, Vector3(-0.04, 0.54, 0.0), 0.0)
	boss.hud = d.ui.hud
	Geo.seal(boss)                                       # (the room's own lamps light only what is sealed)


func _process(delta: float) -> void:
	if _door_open and _close_t > 0.0:
		_close_t -= delta
		if _close_t <= 0.0:
			if _in_doorway():
				_close_t = 0.5
			else:
				_set_door(false)


## Down to the lounge by the lift or the stairs, or back up: the floor you are on is lit.
func _crossed(to_lounge: bool) -> void:
	var t := d.terminal
	for zn: String in ["hall", "shops", "airhall"]:
		t.set_zone_light(zn, to_lounge, true)
		(t.zones[zn] as LightZone).night_dim = Chapter1.HUB_DIM.get(zn, 0.62)
	hall.zone.set_on(not to_lounge, true)
	t.set_zone_light("secoffice", not to_lounge, true)
	d.player.no_sprint = not to_lounge
