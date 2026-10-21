extends PhaseScript
## DAY 3 — 개장 D-1. The day is wrong: grey light, the board shows SH 000 in daylight,
## a photo has changed, the PA speaks on its own. Gates open; the predecessor's last log.

var fids: FidsBoard
var gate03: BoardingGate


func title_lines() -> Array:
	return ["DAY 3", "10월 22일 · 정식 개장 D-1 · 09:00 낮 근무"]


func setup() -> void:
	d.set_shutters_for_cycle(3)
	d.clock_speed = 0.3
	fids = d.t.facility("fids")
	gate03 = d.t.facility("gate03")
	fids.ghost_row(true)
	if Game.binder_pages.has("p8"):
		Game.set_flag("got_rev3")
	else:
		var pk := Pickup.create(d.t, Vector3(-23.3, 1.02, -4.6), 0.3, "rev3", "팩스로 온 개정 수칙 챙기기", "folder")
		pk.picked.connect(func(_p):
			Game.add_binder_page("p8")
			Game.set_flag("got_rev3")
			Events.notify.emit("개정 수칙 추록 p.8 (2026.10.19)을 바인더에 끼웠다.", "good"))
	d.spawn_doc("log3", Vector3(20.8, 0.49, -94.6), 0.6, "의자 위에 놓인 업무일지 읽기")
	d.spawn_doc("log2", Vector3(6.6, 0.81, -20.6), 0.5, "누군가 두고 간 업무일지 읽기")
	if not Game.has_clue("plaque"):
		var pl := Pickup.create(d.t, Vector3(41.0, 0.0, -21.4), 0.0, "plaque", "덮개 아래 동판 살펴보기", "plaque")
		pl.keep_after_pick = true
		pl.picked.connect(func(_p):
			if Game.has_clue("plaque"):
				return
			Game.add_clue("plaque")
			var c: Dictionary = RulesDB.CLUES.plaque
			d.ui.read_doc(c.title, c.body, "serif"))
	_alter_a_photo()


## One of yesterday's photos now has someone in it.
func _alter_a_photo() -> void:
	if Game.photos.is_empty():
		return
	var idx := 0
	for i in Game.photos.size():
		if Game.photos[i].get("facility", "") in ["fids", "baggage", "xray"]:
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


func run() -> void:
	await d.wait(0.8)
	await d.radio("마지막 날이네요. 오늘은 탑승 게이트 구역까지 열어요. 내일이면 개장이에요.")
	if Game.flag("photo_altered"):
		d.notify("점검 앨범 동기화 완료 — 변경된 사진 1건", "info")
	var g1 := d.goal("개정 수칙 수령", "시설관리실 [b]팩스[/b]로 들어온 개정 수칙 추록(p.8 탑승구)을 챙기십시오.", "office")
	await d.radio("팩스로 탑승구 수칙 왔을 거예요. 8페이지.")
	await d.until(func(): return Game.flag("got_rev3"))
	d.complete_goal(g1)
	await d.radio("…근데 전광판 봤어요? 낮인데 SH 000이 떠 있다고 보안팀이 그러던데. 테스트 데이터겠죠.")
	var g2 := d.goal("탑승 게이트 구역 확인", "탑승동 끝 [b]탑승 게이트 구역[/b]으로 가서 GATE 03 포디움의 [b][상태 확인][/b]을 눌러 보십시오. (대기석 배치 촬영 권장)", "gates")
	await d.until(func(): return gate03.checked)
	d.complete_goal(g2)
	await d.wait(2.0)
	await d.pa(["pa_flight0_checkin_ko"], {"wrong": true, "tag": "auto",
		"subs": ["영편 탑승 수속을 시작합니다. 승객 여러분께서는 영번 게이트로 이동해 주시기 바랍니다."]})
	await d.radio("…방금 방송, 누가 튼 거예요? 거기 지금 아무도 없죠?")
	await d.radio("영번 게이트 같은 건 없어요. 도면에도 없어요. …오늘은 그냥 일찍 들어가요.")
	d.goal("탑승 게이트 구역 둘러보기 (선택)", "게이트 구역 대기석 주변을 둘러보십시오.", "gates", {"optional": true})
	var g3 := d.goal("퇴근 기록", "시설관리실 [b]근태 기록기[/b]에서 근무 종료를 기록하십시오.", "office")
	d.punch_enabled = true
	await d.punched
	d.complete_goal(g3)
	await d.end_phase()
