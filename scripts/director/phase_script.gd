class_name PhaseScript
extends RefCounted
## Base for the per-shift story scripts (night1.gd … night3.gd = DAY 1–3, each one dawn shift 00:00–06:00).
## setup() configures the world before the player gains control; run() is the scripted coroutine.
## Shared helpers below place the documents and pickups that recur across days.

const DOCS := {
	# clue id: [position, rotation, prompt, first day it can be found]
	"log1": [Vector3(-27.4, 0.77, 5.3), 0.2, "낡은 업무일지 읽기", 1],
	"memo_worker": [Vector3(-12.0, 1.1, 2.5), 0.4, "구겨진 메모 읽기", 1],
	"log2": [Vector3(11.18, 1.02, -24.6), PI / 2, "사물함 속 업무일지 읽기", 2],
	"newspaper": [Vector3(8.4, 0.49, -87.2), -0.3, "의자 위 신문 조각 읽기", 3],
	"log3": [Vector3(20.8, 0.49, -94.6), 0.6, "의자 위에 놓인 업무일지 읽기", 3],
	"timecard": [Vector3(-27.7, 0.93, -5.5), 0.0, "오래된 근태 카드 읽기", 3],
}
const LOCKER_POS := Vector3(11.55, 0.0, -24.6)

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
	Geo.box(d.t, Vector3(-27.4, 0.38, 5.35), Vector3(0.7, 0.76, 0.5), Mats.get_mat("wood"))
	if Game.cycle >= 2:
		# staff locker beside the security checkpoint (the missing mechanic's work log)
		Geo.box(d.t, LOCKER_POS + Vector3(0, 0.95, 0), Vector3(0.45, 1.9, 0.9), Mats.get_mat("metal_dark"))
		Geo.box(d.t, LOCKER_POS + Vector3(-0.3, 0.99, 0), Vector3(0.24, 0.03, 0.8), Mats.get_mat("metal"), false)
	if Game.cycle >= 3:
		Geo.box(d.t, Vector3(-27.7, 0.9, -5.6), Vector3(0.5, 0.04, 0.3), Mats.get_mat("metal_dark"), false)
	for id in DOCS.keys():
		var e: Array = DOCS[id]
		if Game.cycle >= int(e[3]):
			d.spawn_doc(id, e[0], e[1], e[2])
	if Game.cycle >= 2 and not Game.has_clue("plaque"):
		var pl := Pickup.create(d.t, Vector3(41.0, 0.0, -21.4), 0.0, "plaque", "덮개 아래 동판 살펴보기", "plaque")
		pl.keep_after_pick = true
		pl.picked.connect(func(_p):
			if Game.has_clue("plaque"):
				return
			Game.add_clue("plaque")
			var c: Dictionary = RulesDB.CLUES.plaque
			d.ui.read_doc(c.title, c.body, "serif"))


## DAY 1: the rule binder waits on the office desk (later days start with it in hand).
func binder_pickup() -> void:
	if Game.binder_pages.has("p0"):
		Game.set_flag("got_binder")
		return
	var pk := Pickup.create(d.t, Vector3(-33.0, 0.77, 0.3), PI / 2, "binder", "근무 수칙 바인더 챙기기", "binder")
	pk.picked.connect(func(_p):
		Game.add_day_pages(1)
		Game.set_flag("got_binder")
		Snd.play("binder_open", -4.0)
		Events.notify.emit("근무 수칙 바인더 획득 — [B]로 펼치기", "good"))


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
	var spots := [Vector3(-14, 1.5, 10), Vector3(12, 1.5, 8), Vector3(0, 1.5, 13), Vector3(18, 1.5, -6)]
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
				chat = chat % 3 + 1
				Snd.play_at("staff_chat_%d" % chat, at, -12.0, randf_range(0.92, 1.04), 24.0)


## Standard opening of a shift: the first radio line, then the control guide.
func night_briefing(first_line: String) -> void:
	await d.wait(1.0)
	await d.radio(first_line)
	d.ui.hud.show_key_hints(20.0)
