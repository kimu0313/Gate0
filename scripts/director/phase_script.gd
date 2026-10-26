class_name PhaseScript
extends RefCounted
## Base for the per-shift story scripts (night1.gd … night5.gd = DAY 1–5, each one dawn shift 00:00–06:00).
## setup() configures the world before the player gains control; run() is the scripted coroutine.
## Shared helpers below place the documents and pickups that recur across days, the evening-shift colleague
## (StaffNpc) who hands each shift over in person, and the story goals (use_goal) the days are built from.

const DOCS := {
	# clue id: [Terminal spot, rotation, prompt, first day it can be found]
	"log1": ["doc_log1", 0.2, "낡은 업무일지 읽기", 1],
	"memo_worker": ["doc_memo_worker", 0.4, "구겨진 메모 읽기", 1],
	"log3": ["doc_log3", 0.6, "의자 위에 놓인 업무일지 읽기", 4],
	"timecard": ["doc_timecard", 0.0, "오래된 근태 카드 읽기", 5],
}

var d: ShiftDirector


func setup() -> void:
	pass


func run() -> void:
	pass


## Called when the player punches the time clock. Return true if the phase may end now.
## The active work order at that point is the clock-out goal itself, so it is not counted.
func can_punch_out() -> bool:
	return d.all_required_done(d.current)


## Short scene played after clocking out, before the morning report (optional).
func end_cut() -> void:
	pass


func title_lines() -> Array:
	return []


# --- shared helpers ---------------------------------------------------------------------------
## Every clue that can already be found by this day and was not picked up yet.
func place_documents() -> void:
	Geo.box(d.t, d.t.spot("log1_desk"), Vector3(0.7, 0.76, 0.5), Mats.get_mat("wood"))
	if Game.cycle >= 5:
		Geo.box(d.t, d.t.spot("timecard_shelf"), Vector3(0.5, 0.04, 0.3), Mats.get_mat("metal_dark"), false)
	if Game.cycle >= 2:
		_ensure_day1_pages()
	for id in DOCS.keys():
		var e: Array = DOCS[id]
		if Game.cycle >= int(e[3]):
			d.spawn_doc(id, d.t.spot(e[0]), e[1], e[2])
	# from DAY 2: the rusted memorial in the corner of the strip on the way to the storage room
	if Game.cycle >= 2:
		var pl := Pickup.create(d.t, d.t.spot("plaque"), -PI / 4, "plaque", "녹슨 동판 살펴보기", "plaque")
		pl.name = "plaque"
		pl.keep_after_pick = true
		pl.picked.connect(func(_p): d.read_clue("plaque", "serif"))


## DAY 1 rule pages the player walked past are in the binder by the next shift anyway (the manager's copies).
func _ensure_day1_pages() -> void:
	for id in Game.DAY_PAGES[1]:
		if id == "p3" and Game.binder_pages.has("p3_dmg"):
			continue
		Game.add_binder_page(id)


## A rule page waiting at its facility: picking it up files it in the binder.
func rule_page(id: String, spot_name: String, rot_y: float, kind := "wallpage") -> Pickup:
	if Game.binder_pages.has(id):
		return null
	var pg := RulesDB.page(id)
	var pk := Pickup.create(d.t, d.t.spot(spot_name), rot_y, "page_" + id, tr("수칙 p.%s 챙기기") % pg.no, kind)
	pk.name = "page_" + id
	pk.picked.connect(func(_p):
		Game.add_binder_page(id)
		Snd.play("binder_open", -8.0)
		d.notify(tr("근무 수칙 p.%s %s — 바인더에 끼움") % [pg.no, tr(pg.title)], "good"))
	return pk


## A story goal on something to use (`target`: an Interactable or a Pickup — debug bots go there). It is done once
## `done` returns true (default: the target was used) and whatever it opened has been closed again.
func use_goal(title: String, detail: String, location: String, target: Node3D, done := Callable()) -> void:
	var g := d.goal(title, detail, location, {"target": target})
	if done.is_valid():
		await d.until(func(): return d.dead or done.call())
	elif target is Interactable:
		await (target as Interactable).used
	elif target is Pickup:
		await (target as Pickup).picked
	await d.until(func(): return d.dead or d.ui.modal == "")
	d.complete_goal(g)


## The usual end of a shift: a clock-out order, the time clock, then the morning report.
func punch_out(title := "퇴근 기록", detail := "시설관리실 [b]근태 기록기[/b]에서 근무 종료를 기록하십시오.") -> void:
	var g := d.goal(title, detail, "office", {"target": d.t.punch_clock})
	d.punch_enabled = true
	await d.punched
	d.complete_goal(g)
	Game.clock_minutes = 6 * 60
	Events.clock_changed.emit(Game.clock_minutes)
	d.notify("06:00 — 근무 종료", "good")
	await d.end_phase()


## 00:00–01:00: the evening staff are still clocking out somewhere in the terminal.
func handover_ambience() -> void:
	Game.set_flag("handover", true)
	var spots := [Vector3(-14, 1.5, 11), Vector3(9, 1.5, 4), Vector3(-4, 1.5, 13), Vector3(0, 1.5, -6)]
	var chat := 0
	while Game.flag("handover") and not d.dead and d.is_inside_tree():
		await d.wait(randf_range(5.0, 9.0))
		if not Game.flag("handover") or d.dead:
			return
		var at: Vector3 = spots[randi() % spots.size()]
		match randi() % 3:
			0:
				Snd.play_at("distant_footsteps", at, -8.0, randf_range(0.9, 1.1), 30.0)
			1:
				Snd.play_at("distant_door", at, -10.0, randf_range(0.9, 1.1), 30.0)
			_:
				# someone talking at the far end of the hall — too far to make out a word
				chat = chat % 3 + 1
				Snd.play_at("npc_murmur_%d" % chat, at, -10.0, randf_range(0.82, 1.1), 18.0)


## The evening-shift colleague, waiting at today's post; they wave you over when you first see them.
func spawn_worker(pos: Vector3, rot_y: float) -> StaffNpc:
	var n := StaffNpc.create(d.t, pos, rot_y)
	n.director = d
	n.player = d.p
	n.beckon = true
	d.npc = n
	return n


## A work order to go and talk to the colleague, and the talk itself (stepped through with [E]; the day's items
## change hands on the way — `give` is called with each item id, see ShiftDirector.npc_talk).
func colleague_talk(title: String, detail: String, location: String, lines: Array, give: Callable) -> void:
	var g := d.goal(title, detail, location, {"target": d.npc})
	await d.npc_talk(lines, give)
	d.complete_goal(g)


## Every shift opens with the colleague's handover: the talk, then they clock out and walk off (`way`, see
## ShiftDirector.npc_leave) while you get to work.
func colleague_handover(detail: String, location: String, lines: Array, give: Callable, way := "entrance",
		title := "교대 근무자와 대화하기") -> void:
	await colleague_talk(title, detail, location, lines, give)
	d.npc_leave(way)


## The colleague hands over rule pages: into the binder they go.
func hand_pages(ids: Array, note: String) -> void:
	if d.npc:
		d.npc.present("page", 3.0)
	for id in ids:
		Game.add_binder_page(id)
	Snd.play("page_flip", -4.0)
	d.notify(note, "good")


## Standard opening of a shift: the first radio line, then the control guide.
func night_briefing(first_line: String) -> void:
	await d.wait(1.0)
	await d.radio(first_line)
	d.ui.hud.show_key_hints(20.0)
