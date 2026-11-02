class_name PartHub
extends StoryPart
## The lounge as the hub. In front of security's glass stands a check-in device with three empty slots: nothing else
## opens until you have looked at it. Then, across the lounge, a door booms open, a shutter rolls up and another door
## goes: the three ways on (PartFog, PartRepeat, PartBaggage), in any order. Each comes back to the lounge by another
## way than it went in, and every time the lounge has changed: by how many times you have been back (_stage), and by
## where you have been (_trace). The three things you bring go into the device; when it has all three the voice on
## the PA says check-in is complete and you are a passenger.

const DEVICE_AT := Vector3(1.2, 0.0, -7.6)
const SEE_DEVICE := 2.6                       # this close counts as having looked at it
const SLOTS := [["boarding_pass", "탑승권"], ["id_card", "신원 확인"], ["bag_tag", "수하물표"]]
const HALL_DARK := 0.14                       # the lounge's lights by the third return

var seen := false
var checked_in := false
var _use: Interactable
var _lamps: Array[MeshInstance3D] = []
var _in: Array[String] = []                   # what has gone into the device
var _enter := ""                              # the branch you have just stepped into
var _returns := 0


func setup() -> void:
	_build_device()


func parts() -> Dictionary:
	return {"a": ch.fog, "b": ch.repeat, "c": ch.bags}


## Restored from a save: the lounge as you left it.
func restore() -> void:
	seen = Game.flag("device_seen")
	if seen:
		_use.prompt = "수속 장치에 넣기"
	_returns = int(Game.flags.get("returns", 0))
	for i in _returns:
		_stage(i + 1, true)
	for b: String in ["a", "b", "c"]:
		if Game.flag("done_" + b):
			_trace(b)
	if seen:
		for b: String in ["a", "b", "c"]:
			if not Game.flag("done_" + b):
				parts()[b].open_entry()


func run() -> void:
	if Game.checkpoint == "baggage":
		_enter = "c"
		await ch.bags.run()
		_came_back("c")
	else:
		Game.set_checkpoint("hub")
	d.objective("수속 장치 확인")
	if not seen:
		await d.until(func(): return seen or _near())
		_see()
		await d.wait(1.6)
		await _cue_all()
	d.objective("갈래 다녀오기")
	while not _all_done():
		_enter = ""
		await d.until(func(): return _entered() != "")
		_enter = _entered()
		await parts()[_enter].run()
		_came_back(_enter)
	d.objective("수속 장치에 넣기")
	await d.until(func(): return checked_in)


func _near() -> bool:
	var q := d.player.global_position
	return q.y < 1.0 and Vector2(q.x - DEVICE_AT.x, q.z - DEVICE_AT.z).length() < SEE_DEVICE


func _see() -> void:
	seen = true
	Game.set_flag("device_seen")
	Game.save_game()
	_use.prompt = "수속 장치에 넣기"
	Events.subtitle.emit("self", "……탑승 수속? 빈칸이 세 개 있다.", 3.4)


func _all_done() -> bool:
	return Game.flag("done_a") and Game.flag("done_b") and Game.flag("done_c")


func _entered() -> String:
	for b: String in ["a", "b", "c"]:
		if not Game.flag("done_" + b) and parts()[b].entered():
			return b
	return ""


## Across the lounge, one after another, the ways on open: you hear them before you see them.
func _cue_all() -> void:
	for b: String in ["a", "c", "b"]:
		if Game.flag("done_" + b):
			continue
		await _cue(b)
		await d.wait(2.2)


func _cue(b: String) -> void:
	var part: Variant = parts()[b]
	part.open_entry()
	Snd.play_at(part.ENTRY_SOUND, part.entry_pos(), 7.0, 0.9, 24.0, 140.0)
	d.player.add_shake(0.08)


## Back in the lounge from a branch: it has changed.
func _came_back(b: String) -> void:
	Game.set_flag("done_" + b)
	_returns += 1
	Game.flags["returns"] = _returns
	_trace(b)
	_stage(_returns, false)
	Game.set_checkpoint("hub")
	_announce()


## The voice and the sounds after a return. Nothing waits for them: the next branch can be walked into straight away.
func _announce() -> void:
	await d.wait(1.0)
	if _returns == 1:
		await d.pa_at(Vector3(0.0, 8.0, 6.0), ["pa_v3_000_ready_ko"],
			["서해항공 Flight 000편이 출발 준비를 마쳤습니다. 아직 탑승하지 않으신 승객께서는, 0번 탑승구로 오시기 바랍니다."], 0.6)
	elif _returns == 2:
		await d.pa_at(Vector3(0.0, 8.0, 6.0), ["pa_v3_000_wait_ko"],
			["Flight 000편은, 승객 한 분을 기다리고 있습니다. 승객님, 0번 탑승구로 오시기 바랍니다."], 0.6)
	elif _returns == 3:
		Snd.play_at("cart_rattle_2", Vector3(2.0, 1.0, 24.0), 2.0, 0.85, 22.0, 120.0)
	# whichever way is still open sounds again, so you know where it is
	for k: String in ["a", "c", "b"]:
		if not Game.flag("done_" + k):
			var part: Variant = parts()[k]
			Snd.play_at(part.ENTRY_SOUND, part.entry_pos(), 5.0, 0.9, 24.0, 140.0)
			await d.wait(2.0)


## What changes with the number of times you have come back, whatever order you went in.
func _stage(n: int, instant: bool) -> void:
	var t := d.terminal
	match n:
		1:
			var flip := Basis(Vector3.BACK, PI)
			var rows: Array = t.warp.benches
			for i in rows.size():
				var row: Node3D = rows[i]
				var p := row.position
				# only under the flat ceiling: past ROOF_Z there is no roof, only the dark (LoungeShaft), and nothing
				# hangs up there
				if i % 4 == 0 and p.z < Terminal.ROOF_Z:
					row.transform = Transform3D(flip * row.basis, Vector3(p.x, Terminal.HALL_H, p.z))
		2:
			for board: Variant in [t.facilities.get("fids"), t.arrivals]:
				if board:
					board.set_story("story", ["FLIGHT 000", "GATE 0"])
			var c := Terminal.DESK_AT
			var m := Transform3D(Basis.from_euler(Vector3(deg_to_rad(9), 0, deg_to_rad(-12))), c + Vector3(0, -0.62, 0)) * Transform3D(Basis(), -c)
			var desk: Node3D = t.warp.desk
			desk.transform = m * desk.transform
			var pa: Node3D = t.facilities.get("pa")
			if pa:
				pa.transform = m * pa.transform
		3:
			var z: LightZone = t.zones.hall
			z.night_dim = HALL_DARK
			z.set_on(true, true)
			(t.zones.shops as LightZone).night_dim = 0.2
			(t.zones.shops as LightZone).set_on(true, true)
			if not instant:
				z.trigger_dip(0.9)
				Snd.play("sub_boom", -10.0, 0.7)


## What a branch leaves behind in the lounge.
func _trace(b: String) -> void:
	var t := d.terminal
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261102
	match b:
		"a":
			# the cabin's pale green haze, spreading across the floor from its door
			t._smoke(AABB(Vector3(-20.0, 0.0, 6.0), Vector3(14.0, 1.5, 21.0)), 91, 0.4, Color(0.84, 0.92, 0.82), Color(0.2, 0.26, 0.2))
		"b":
			# the same door, here and there on the walls, opening on nothing
			for xf: Transform3D in [Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(Terminal.HALL_E - 0.22, 0, 5.8)),
					Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(Terminal.HALL_E - 0.22, 0, 25.9)),
					Transform3D(Basis(), Vector3(-11.0, 0, -2.28)), Transform3D(Basis(Vector3.UP, PI / 2), Vector3(-19.78, 0, 24.0))]:
				var door := ServiceHall.double_door(t, xf)
				(door.use as Interactable).enabled = false
				(door.use as Interactable).collision_layer = 0
				(door.block as StaticBody3D).collision_layer = 0
		"c":
			# bags nobody came for, across the floor and up the stopped escalators
			for i in 16:
				var bag := Props.suitcase(t, Color.from_hsv(rng.randf(), rng.randf_range(0.1, 0.4), rng.randf_range(0.18, 0.45)))
				bag.position = Vector3(rng.randf_range(-14.0, 6.0), 0.0, rng.randf_range(4.0, 26.0))
				bag.rotation.y = rng.randf() * TAU


# --------------------------------------------------------------------------------------------
func _build_device() -> void:
	var t := d.terminal
	var root := Node3D.new()
	root.name = "CheckInDevice"
	t.add_child(root)
	root.position = DEVICE_AT
	var body := Mats.std(Color(0.8, 0.81, 0.8), 0.4)
	var dark := Mats.get_mat("plastic_dark")
	Geo.box(root, Vector3(0, 0.03, 0), Vector3(0.9, 0.06, 0.6), Mats.get_mat("metal_dark"), false)
	Geo.box(root, Vector3(0, 0.62, 0), Vector3(0.7, 1.2, 0.34), body, false)
	Geo.box(root, Vector3(0, 1.42, 0.02), Vector3(0.78, 0.46, 0.08), dark, false)
	Geo.box(root, Vector3(0, 1.42, 0.065), Vector3(0.68, 0.36, 0.006), Mats.emissive(Color(0.1, 0.3, 0.75), 1.3), false)
	var head := Geo.label(root, "탑승 수속", Vector3(0, 1.5, 0.072), 0.0, 44, Color(0.92, 0.95, 1.0), 0.0026, false, "sign")
	head.set_meta("no_fit", true)
	var sub_l := Geo.label(root, "FLIGHT 000", Vector3(0, 1.36, 0.072), 0.0, 30, Color(0.7, 0.8, 1.0), 0.0024, false, "led")
	sub_l.set_meta("no_fit", true)
	for i in SLOTS.size():
		var x := -0.22 + i * 0.22
		Geo.box(root, Vector3(x, 1.0, 0.176), Vector3(0.17, 0.06, 0.012), dark, false)
		_lamps.append(Geo.box(root, Vector3(x, 1.08, 0.176), Vector3(0.05, 0.03, 0.01), Mats.get_mat("lamp_red"), false))
		var l := Geo.label(root, SLOTS[i][1], Vector3(x, 0.92, 0.176), 0.0, 22, Color(0.12, 0.13, 0.15), 0.0018, false, "print")
		l.set_meta("no_fit", true)
	Geo.blocker(root, Vector3(0, 0.6, 0), Vector3(0.8, 1.2, 0.4))
	_use = Interactable.create(root, Vector3(0, 1.2, 0.2), Vector3(0.9, 1.0, 0.3), "수속 장치 살펴보기", _press)
	_use.press_sound = "card_beep"
	var g := Geo.omni(root, Vector3(0, 1.5, 0.8), Color(0.3, 0.5, 1.0), 0.7, 5.0)
	g.light_volumetric_fog_energy = 0.4


func _press() -> void:
	if not seen:
		_see()
		await d.wait(1.6)
		await _cue_all()
		return
	var put := false
	for i in SLOTS.size():
		var id: String = SLOTS[i][0]
		if Game.has_item(id) and not _in.has(id):
			_in.append(id)
			_lamps[i].material_override = Mats.get_mat("lamp_green")
			put = true
	if put:
		Snd.play_at("beep_ok", DEVICE_AT + Vector3(0, 1.2, 0), -4.0, 1.0, 5.0)
	else:
		Snd.play_at("beep_error", DEVICE_AT + Vector3(0, 1.2, 0), -6.0, 1.0, 5.0)
	if _in.size() >= SLOTS.size() and not checked_in:
		_complete()


## All three are in: the voice from the ceiling, your record on the tablet.
func _complete() -> void:
	_use.enabled = false
	Game.set_flag("checked_in")
	d.ui.tablet.set_passenger()
	await d.pa_at(DEVICE_AT + Vector3(0, 3.0, 2.0), ["pa_boarding_complete_ko"], ["탑승 수속이 완료되었습니다. 안녕히 가십시오."], 0.4)
	checked_in = true
