class_name PhaseScript
extends RefCounted
## Base for the per-shift story scripts (night1.gd … night5.gd = DAY 1–5, each one dawn shift 00:00–06:00).
## setup() configures the world before the player gains control; run() is the scripted coroutine.
## Shared helpers below place the documents and pickups that recur across days, and the evening-shift
## colleague (StaffNpc) who hands each shift over in person.

const DOCS := {
	# clue id: [Terminal spot, rotation, prompt, first day it can be found]
	"log1": ["doc_log1", 0.2, "낡은 업무일지 읽기", 1],
	"memo_worker": ["doc_memo_worker", 0.4, "구겨진 메모 읽기", 1],
	"log2": ["doc_log2", PI / 2, "사물함 속 업무일지 읽기", 3],
	"newspaper": ["doc_newspaper", -0.3, "의자 위 신문 조각 읽기", 4],
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
	if Game.cycle >= 3:
		# staff locker beside the security checkpoint (the missing mechanic's work log)
		var locker := d.t.spot("locker")
		Geo.box(d.t, locker + Vector3(0, 0.95, 0), Vector3(0.45, 1.9, 0.9), Mats.get_mat("metal_dark"))
		Geo.box(d.t, locker + Vector3(-0.3, 0.99, 0), Vector3(0.24, 0.03, 0.8), Mats.get_mat("metal"), false)
	if Game.cycle >= 5:
		Geo.box(d.t, d.t.spot("timecard_shelf"), Vector3(0.5, 0.04, 0.3), Mats.get_mat("metal_dark"), false)
	for id in DOCS.keys():
		var e: Array = DOCS[id]
		# DAY 3: the locker stays shut until the colleague hands over its key (night3.gd places the log then)
		if id == "log2" and Game.cycle == 3 and not Game.flag("got_locker_key"):
			continue
		if Game.cycle >= int(e[3]):
			d.spawn_doc(id, d.t.spot(e[0]), e[1], e[2])
	if Game.cycle >= 2 and not Game.has_clue("plaque"):
		var pl := Pickup.create(d.t, d.t.spot("plaque"), 0.0, "plaque", "덮개 아래 동판 살펴보기", "plaque")
		pl.keep_after_pick = true
		pl.picked.connect(func(_p):
			if Game.has_clue("plaque"):
				return
			Game.add_clue("plaque")
			var c: Dictionary = RulesDB.CLUES.plaque
			d.ui.read_doc(c.title, c.body, "serif"))


## The usual end of a shift: a clock-out order, the time clock, then the morning report.
func punch_out(title := "퇴근 기록", detail := "시설관리실 [b]근태 기록기[/b]에서 근무 종료를 기록하십시오.") -> void:
	var g := d.goal(title, detail, "office")
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


## Every shift opens with the colleague's handover: a work order to go and talk to them, the talk itself
## (stepped through with [E]; the day's items change hands on the way — `give` is called with each item id),
## then they clock out and walk off (`way`, see ShiftDirector.npc_leave) while you get to work.
func colleague_handover(detail: String, location: String, lines: Array, give: Callable, way := "entrance") -> void:
	var g := d.goal("교대 근무자와 대화하기", detail, location)
	await d.npc_talk(lines, give)
	d.complete_goal(g)
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
