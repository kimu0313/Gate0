extends PhaseScript
## DAY 1 — 10/19, 정식 개장 나흘 전 · 첫 근무 = 교육 근무. 체크인 구역만 (조명·전광판·안내방송), 점검 8회,
## 이상현상 없음. (Day1~5 초안 · Day 1: 반복되는 채용 공고 · 겹쳐 붙은 사물함 이름표 · 교대 근무자의 말 ·
## 말하지 못한 한마디)
## 00:00 시설관리실 문 앞에서 시작: 카드로 문을 열고 들어가면 안에 있던 저녁 근무자가 돌아보며 손을 흔든다.
## (DAY 1은 튜토리얼 — 현재 지시의 위치를 HUD가 초록 마름모로 표시한다, ShiftDirector.marker_target)
## 저녁 근무자: "또 새로 오신 분이네요." PC에서 근무 배정을 확인하면 내가 지원한 공고가 매주
## 다시 올라온 이력이 보이고, 배정된 사물함 04에는 내 이름표 아래로 이름표가 여러 겹 붙어 있다. 돌아오면 장비를
## 넘겨준다 — 태블릿, 무전기, 바인더(아직 0·1페이지뿐). "얼마 지나면 못 보겠지만." 무언가 말하려는 순간 소장의
## 무전이 끊고 들어오고, 근무자는 아무 말 없이 나간다. 소장: 쓸데없는 데 관심 두는 사람은 오래 못 간다.
## 교육: 태블릿 → 바인더 → 점검 1–3 (무전 안내; 수칙 2·3·4페이지는 각 시설 앞에서 챙긴다).
## 01:00 조명 절반 소등, 혼자 점검 4–8 (전부 정상). 03:00 정기 방송 — 오늘 날짜와 시각 (p.9는 사무실 팩스로 온다).
## 06:00 퇴근하러 가는 길에만, 출발 전광판 맨 위에 A0 · 23:40 · GATE 0 · BOARDING이 잠깐 뜬다.

const POST := "npc_office"   # Terminal spot: in the office, between your spawn and the door
## first words: [text, item handed over with this line]
const TALK_HELLO := [
	["아, 또 새로 오신 분이네요.", ""],
	["…아, 반가워요. 저는 저녁 근무예요. 오늘부터 새벽 근무 하시는 거죠?", ""],
	["들어가기 전에 저기 PC에서 근무 배정 확인 한 번 눌러 주세요. 인사팀에서 확인한대요.", ""],
	["사물함은 04번 쓰시면 돼요. 이름표 붙여 놨어요. 다 보고 오면 장비 넘겨 드릴게요.", ""],
]
const TALK_ITEMS := [
	["확인했어요? 그럼 장비요. 이건 점검 태블릿. 점검 지시가 여기로 와요. [Tab]으로 열고, 보고도 여기서 해요.", "tablet"],
	["무전기요. 소장님은 이걸로만 연락해요. 얼굴 보기 힘든 분이에요.", "radio"],
	["근무 수칙 바인더요. 아직 몇 장 없죠? 나머지 페이지는 시설마다 꽂혀 있어요. 갈 때마다 챙겨서 끼우면 돼요.", "binder"],
	["무전이랑 수칙이 다르면, 수칙이 먼저예요. 꼭이요.", ""],
	["뭐… 얼마 지나면 못 보겠지만. 그래도 잘 부탁해요.", ""],
	["…그리고, 저기. 사실 전에 이 자리에 있던 사람들이요—", "cut"],
	["…아니에요. 별거 아니에요. 그럼 먼저 갈게요.", ""],
]
const ITEMS := {
	"tablet": ["점검 태블릿 수령 — [Tab]으로 열기", "tablet_open"],
	"radio": ["무전기 수령 — 소장의 지시는 무전으로 옵니다", "radio_on"],
	"binder": ["근무 수칙 바인더 수령 — [B]로 펼치기 (아직 p.0 · p.1뿐)", "binder_open"],
}
## the first three inspections, talked through on the radio: where to go (and the rule page waiting there), then
## (once you are there) what normal is
const GUIDE := {
	"lights": ["첫 번째는 조명 분전반이에요. 사무실 문 바로 옆 벽. 분전반 옆에 수칙 2페이지가 꽂혀 있어요. 먼저 챙기세요.",
		"켠 구역이 전부 고르게 밝으면 정상이에요. 분전반을 보고 있으면 관찰 표시가 차요. 다 차면 [Tab] 태블릿에서 보고."],
	"fids": ["다음은 출발 전광판. 체크인 홀 북쪽 벽이요. 3페이지는 전광판 아래, 제어함 왼쪽 벽에 붙어 있어요.",
		"맨 위에 TEST MODE, 테스트 편 여덟 개. 이 목록이랑 시계 잘 봐 둬요. 내일부터는 이거랑 비교하는 거예요."],
	"pa": ["마지막은 안내방송. 안내 데스크 콘솔이요. 4페이지는 콘솔 옆에 놓여 있어요.",
		"[테스트 방송]을 눌러요. 문안은 수칙 4페이지랑 똑같아야 해요. 끝까지 듣고 보고하세요."],
}

var fids: FidsBoard
var _punched := false


func title_lines() -> Array:
	return ["DAY 1", "10월 19일 · 00:00 · 첫 근무 (교육)"]


func setup() -> void:
	d.set_shutters_for_cycle(1)
	d.clock_speed = 0.1
	fids = d.t.facility("fids")
	place_documents()
	# the day's rule pages wait at their facilities (p.9 arrives on the fax before 03:00)
	rule_page("p2", "page_p2", PI / 2)
	rule_page("p3", "page_p3", 0.0)
	rule_page("p4", "page_p4", 0.0, "paper")
	spawn_worker(d.t.spot(POST), StaffNpc.yaw_for(Vector3(-1, 0, 0)))
	d.npc.beckon = false   # the arrival scene has them turn round and wave
	# the first shift starts outside the office door, in the hall
	d.p.teleport(Transform3D(Basis(), d.t.spot("office_entry")))
	var to_door := d.t.spot("reader_stand") - d.t.spot("office_entry")
	d.p.set_look(atan2(-to_door.x, -to_door.z), deg_to_rad(-4.0))
	d.p.cutscene = true    # the view is held until the first order comes up (_arrive)
	d.punched.connect(func(): _punched = true, CONNECT_ONE_SHOT)


func run() -> void:
	handover_ambience()
	await _arrive()
	if d.dead:
		return
	await colleague_talk("교대 근무자와 대화하기", "시설관리실에 있는 [b]저녁 근무자[/b]에게 다가가 [E]로 말을 거십시오. ([E]를 누를 때마다 다음 말로 넘어갑니다)",
		"office", TALK_HELLO, func(_item): pass)
	if d.dead:
		return
	await use_goal("근무 배정 확인 (사무실 PC)", "사무실 서쪽 책상의 [b]PC[/b]에서 근무 배정을 확인하십시오.", "office",
		d.t.office_pc, func(): return Game.has_clue("job_post"))
	d.say("…같은 공고가, 매주 다시 올라왔다.", 3.0)
	await use_goal("배정된 사물함 확인 (04)", "사무실 북쪽 벽 [b]사물함 04[/b]의 이름표를 확인하십시오.", "office",
		d.t.locker_tag, func(): return Game.has_clue("locker_tags"))
	d.say("이름표 밑에 이름표가… 몇 명째야.", 3.0)
	await colleague_handover("[b]저녁 근무자[/b]에게 돌아가 [E]로 근무 장비를 받으십시오.", "office", TALK_ITEMS, _hand_over, "office",
		"교대 근무자에게 장비 받기")
	if d.dead:
		return
	await _training()
	if d.dead:
		return
	var plan := NightPlan.build(1)
	await d.run_inspections(plan, {1: _first_report, 3: _evening_out, 5: _broadcast_soon, 6: _broadcast},
		{1: _guided, 2: _guided, 3: _guided})
	if d.dead:
		return
	await d.radio("오늘은 여기까지. 다 정상이었죠? 첫날은 원래 그래요. 사무실 근태 기록기에 퇴근 찍고 가세요.")
	_flight0_glimpse()
	if not Game.binder_pages.has("p9"):
		var pk := d.t.get_node_or_null("page_p9") as Pickup
		await use_goal("팩스로 온 수칙 p.9 챙기기", "시설관리실 [b]팩스[/b] 옆에 소장이 보낸 수칙 9페이지(비상 수칙)가 있습니다. 퇴근 전에 챙기십시오.",
			"office", pk, func(): return Game.binder_pages.has("p9"))
	await punch_out()


## 00:00 — you arrive outside the office: your card opens the door, you step in, and the evening colleague
## inside turns round and waves you over. Then the first order comes up. Until then the scene holds the view too
## (Player.cutscene: no mouse look, no walking).
func _arrive() -> void:
	var p := d.p
	p.controls_enabled = false
	var door: SlidingDoor = d.t.doors.office
	var reader: CardReader = d.t.readers.office_out
	# up to the card reader, the head turning on the way: the lighting panel on the left, the dark lobby and its
	# departure board on the right, then the reader as you reach it
	await d.wait(0.4)
	p.walk_to(d.t.spot("reader_stand"), 1.2)
	await d.wait(0.3)
	p.glance(d.t.spot("look_lights") + Vector3(0, 0.15, 0), 2.4)
	await d.wait(1.1)
	p.glance(d.t.facility("fids").focus_position() + Vector3(0, -1.2, 0), 2.2)
	await d.wait(1.2)
	p.glance(reader.global_position, 3.2)
	await _until_walked(6.0)
	await d.wait(0.35)
	reader.show_result(true, "STAFF OK")
	await d.wait(0.45)
	door.open()
	# through the door while it slides open, a look round the office, then the colleague turns round
	p.glance(d.t.spot("office_doorway") + Vector3(0, 1.55, -1.6), 2.8)
	await d.wait(0.35)
	p.walk_path([d.t.spot("office_door_front"), d.t.spot("office_doorway"), d.t.spot("office_arrive")], 1.15)
	await d.wait(1.0)
	p.glance(d.t.spot("look_punch") + Vector3(-1.8, 0.0, 0.0), 2.4)     # the lockers and the time clock
	await d.wait(1.0)
	if d.npc:
		d.npc.face(p.global_position)
		p.glance(d.npc.head_position(), 2.8)
	await _until_walked(6.0)
	if d.npc:
		d.npc.wave()
		d.npc.murmur(0.9)
	await d.wait(1.0)
	door.close()
	p.glance(Vector3.INF)
	p.controls_enabled = true
	p.cutscene = false     # the first order ("교대 근무자와 대화하기") comes up right after this


func _until_walked(limit: float) -> void:
	var e := 0.0
	while d.p.walking() and e < limit and not d.dead:
		await d.wait(0.1)
		e += 0.1


## 00:00 · the colleague hands over the tablet, the radio and the rule binder, one line at a time — and starts to
## say something about the people who had this job before, until the manager cuts in on the radio.
func _hand_over(item: String) -> Variant:
	if item == "cut":
		await d.wait(2.4)
		await d.radio_cut_in("교대 근무자님, 퇴근 기록 아직이에요? 시간 지났어요.")
		if d.npc:
			d.npc.face(d.t.doors.office.global_position)
		return true
	d.npc.present(item, 3.0)
	match item:
		"tablet":
			Game.set_flag("got_tablet")
		"radio":
			Game.set_flag("got_radio")
		"binder":
			Game.add_binder_page("p0")
			Game.add_binder_page("p1")
			Game.set_flag("got_binder")
	var it: Array = ITEMS[item]
	Snd.play(it[1], -6.0)
	d.notify(it[0], "good")
	return false


## The manager takes over on the radio: open the tablet, open the binder, then the first work order.
func _training() -> void:
	await d.wait(4.0)   # they are out of the office by now
	Snd.play_at("distant_door", d.t.doors.entrance.global_position + Vector3(0, 1.2, 0), -6.0, 1.0, 40.0)
	await d.wait(1.5)
	await d.radio("…들려요? 시설운영팀 소장입니다. 오늘부터 닷새, 새벽 점검 부탁해요. 첫날은 교육이라고 생각하세요.")
	await d.radio("그리고 방금 그분이 하려던 말은 신경 쓰지 마세요. 여기선 쓸데없는 데 관심 두는 사람이 오래 못 가요.")
	# the prompts run alongside the goals: opening the tablet while the radio still talks counts
	var g1 := d.goal("점검 태블릿 열어 보기", "[b][Tab][/b]으로 점검 태블릿을 열어 보십시오.", "office")
	d.radio_async("먼저 태블릿부터. [Tab]으로 열어 봐요. 점검 지시랑 보고가 전부 여기서 돼요.")
	await d.until(func(): return d.ui.modal == "tablet" or d.dead)
	d.complete_goal(g1)
	await d.until(func(): return d.ui.modal == "" or d.dead)
	var g2 := d.goal("근무 수칙 바인더 펼쳐 보기", "[b][B][/b]로 근무 수칙 바인더를 펼쳐 보십시오. 1페이지 총칙부터 읽어 두십시오.", "office")
	d.radio_async("다음은 바인더. [B]로 펼쳐요. 아직 0페이지 목차랑 1페이지 총칙뿐이죠? 1페이지는 꼭 읽어 두세요.")
	await d.until(func(): return d.ui.modal == "binder" or d.dead)
	d.complete_goal(g2)
	await d.until(func(): return d.ui.modal == "" or d.dead)
	d.ui.hud.show_key_hints(20.0)
	await d.radio("좋아요. 이제 점검이에요. 태블릿에 지시가 하나씩 떠요. 오늘은 여덟 번. 시설마다 그 시설 수칙 페이지가 있으니까, 챙겨서 바인더에 끼우고 시작해요.")


func _guided(slot: Dictionary) -> Task:
	var task := d.inspect(slot.fac, slot.title, slot.detail)
	_guide(slot.fac, task)
	return task


func _guide(fac: String, task: Task) -> void:
	var lines: Array = GUIDE[fac]
	await d.radio(lines[0])
	var f := d.t.facility(fac)
	await d.until(func(): return task.state == "done" or d.dead or d.p.global_position.distance_to(f.focus_position()) < 9.0)
	if task.state == "done" or d.dead:
		return
	await d.radio(lines[1])


func _first_report() -> void:
	await d.radio("네, 접수됐어요. 그렇게 하면 돼요.")


## 01:00 — the rest of the evening staff are gone too; half the lights switch off.
func _evening_out() -> void:
	await d.ev_lights_down("01시예요. 다른 저녁 근무자들도 다 나갔어요. 이제 조명 절반은 자동으로 꺼져요.",
		"여기서부터 혼자예요. 판정을 세 번 틀리면 그날 근무는 무효고요. 수칙 1페이지에 있어요.")


## The emergency page comes in on the office fax; the rule that matters right now is said on the radio.
func _broadcast_soon() -> void:
	var fax := d.t.spot("page_p9")
	Snd.play_at("keypad_beep", fax + Vector3(0, 0.3, 0), -6.0, 0.7, 6.0)
	rule_page("p9", "page_p9", PI / 2, "paper")
	await d.radio("곧 세 시 정기 방송이에요. 비상 수칙 9페이지는 방금 사무실 팩스로 보냈어요. 이따 챙기고요.")
	await d.radio("지금은 이것만 기억해요. 9페이지 3번 — 방송이 끝날 때까지 그 자리에서 움직이지 마세요.")


## The first 03:00 broadcast — the one time the game says it out loud: do not move until it ends.
func _broadcast() -> void:
	await d.wait(1.5)
	d.notify("정기 방송 중에는 움직이지 마십시오. 방송이 끝날 때까지 그 자리에 서 있으십시오. (수칙 p.9 ③)", "alert")
	await d.ev_regular_broadcast(false, false)
	if d.dead:
		return
	await d.radio("잘했어요. 정기 방송은 매일 세 시에 나와요. 날짜랑 시각을 알려 주니까 잘 들어 두세요.")


## On the way to the time clock, one row on the departure board that was never there. Not an inspection —
## nothing to report, only a feeling. It is gone again once you look away.
func _flight0_glimpse() -> void:
	await d.wait(1.5)
	await d.until(func(): return d.dead or _punched or d.p.zone == "hall")
	if d.dead or _punched:
		return
	fids.ghost_row(true)
	Snd.play_at("glitch", fids.focus_position(), -16.0, 0.7, 10.0, 40.0)
	var fp := fids.focus_position()
	var seen := 0.0
	var waited := 0.0
	var noticed := false
	var chimed := false
	while not d.dead and not _punched:
		await d.wait(0.1)
		waited += 0.1
		var looking := d.p.facing_dot(fp) > 0.8 and d.p.camera.global_position.distance_to(fp) < 32.0
		if looking:
			seen += 0.1
		elif noticed:
			break   # looked at it, then away: it is not there any more
		if seen >= 1.0 and not noticed:
			noticed = true
			d.say("…A0, 23시 40분? 저런 편이 있었나.", 3.0)
		if waited > 8.0 and seen <= 0.0 and not chimed:
			chimed = true   # a soft wrong chime from the board, in case you walk past without looking
			Snd.play_at("pa_chime_wrong", fp, -20.0, 0.8, 8.0, 40.0)
	fids.ghost_row(false)
