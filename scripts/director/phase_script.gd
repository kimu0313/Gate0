class_name PhaseScript
extends RefCounted
## Base for the per-phase story scripts (day1.gd … night5.gd).
## setup() configures the world before the player gains control; run() is the scripted coroutine.
## Shared helpers below place the documents and pickups that recur across days.

const FAX_POS := Vector3(-23.3, 1.02, -4.6)
const DOCS := {
	# clue id: [position, rotation, prompt, first cycle it can be found]
	"log1": [Vector3(-27.4, 0.77, 5.3), 0.2, "낡은 업무일지 읽기", 1],
	"memo_worker": [Vector3(-12.0, 1.1, 2.5), 0.4, "구겨진 메모 읽기", 1],
	"log2": [Vector3(6.6, 0.81, -20.6), 0.5, "누군가 두고 간 업무일지 읽기", 3],
	"newspaper": [Vector3(8.4, 0.49, -87.2), -0.3, "의자 위 신문 조각 읽기", 4],
	"log3": [Vector3(20.8, 0.49, -94.6), 0.6, "의자 위에 놓인 업무일지 읽기", 4],
	"timecard": [Vector3(-27.7, 0.93, -5.5), 0.0, "오래된 근태 카드 읽기", 5],
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


## Short scene played after clocking out at night, before the morning report (optional).
func end_cut() -> void:
	pass


func title_lines() -> Array:
	return []


# --- shared helpers ---------------------------------------------------------------------------
## Every clue that can already be found by this day and was not picked up yet.
func place_documents() -> void:
	Geo.box(d.t, Vector3(-27.4, 0.38, 5.35), Vector3(0.7, 0.76, 0.5), Mats.get_mat("wood"))
	if Game.cycle >= 5:
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


## Revision pages waiting on the office fax. Sets `flag` once they are in the binder.
func fax_pages(pages: Array, flag: String, note: String) -> void:
	if pages.all(func(p): return Game.binder_pages.has(p)):
		Game.set_flag(flag)
		return
	var pk := Pickup.create(d.t, FAX_POS, 0.3, "fax_" + flag, "팩스로 온 개정 수칙 챙기기", "folder")
	pk.picked.connect(func(_p):
		for p in pages:
			Game.add_binder_page(p)
		Game.set_flag(flag)
		Snd.play("binder_open", -4.0)
		Events.notify.emit(note, "good"))


func await_fax(flag: String, title: String, detail: String) -> void:
	var g := d.goal(title, detail, "office")
	await d.until(func(): return Game.flag(flag))
	d.complete_goal(g)


## The usual end of a shift: a clock-out order, the time clock, then the next phase.
func punch_out(title := "퇴근 기록", detail := "시설관리실 [b]근태 기록기[/b]에서 근무 종료를 기록하십시오.") -> void:
	var g := d.goal(title, detail, "office")
	d.punch_enabled = true
	await d.punched
	d.complete_goal(g)
	await d.end_phase()


func has_photo(fid: String) -> bool:
	for ph in Game.photos:
		if ph.get("facility", "") == fid and int(ph.get("cycle", 0)) == Game.cycle:
			return true
	return false


## One of the earlier photos now has someone standing in it.
func alter_a_photo() -> void:
	if Game.photos.is_empty():
		return
	var idx := 0
	for i in Game.photos.size():
		if Game.photos[i].get("facility", "") in ["fids", "baggage", "xray", "walkway"] and not Game.photos[i].get("altered", false):
			idx = i
	var ph: Dictionary = Game.photos[idx]
	if ph.get("altered", false):
		return
	var img: Image = (ph.image as Image).duplicate()
	var w := img.get_width()
	var h := img.get_height()
	var cx := int(w * 0.72)
	var base_y := int(h * 0.86)
	var fig_h := int(h * 0.42)
	var dark := Color(0.01, 0.01, 0.012)
	for y in range(base_y - fig_h, base_y):
		var t := float(y - (base_y - fig_h)) / float(fig_h)
		var half := 0.0
		if t < 0.16:
			half = sqrt(maxf(0.0, 1.0 - pow((t - 0.08) / 0.08, 2.0))) * fig_h * 0.055
		elif t < 0.55:
			half = fig_h * (0.07 + 0.03 * (t - 0.16) / 0.39)
		else:
			half = fig_h * 0.085
		for x in range(cx - int(half), cx + int(half)):
			if x >= 0 and x < w:
				var a := 0.92 - 0.25 * absf(float(x - cx)) / maxf(half, 1.0)
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(dark, a))
	ph.image = img
	ph.tex = ImageTexture.create_from_image(img)
	ph.altered = true
	Game.set_flag("photo_altered")


## Standard opening of a night: how many inspections, how many mistakes are allowed.
func night_briefing(first_line: String) -> void:
	await d.wait(1.0)
	await d.radio(first_line)
	d.ui.hud.show_key_hints(20.0)
