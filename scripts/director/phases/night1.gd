extends PhaseScript
## DAY 1 — 10/19, 정식 개장 나흘 전 · 첫 근무 = 교육 근무. 체크인 구역만 (조명·전광판·안내방송), 점검 8회,
## 이상현상 없음.
## 00:00 시설관리실: 저녁 근무자가 기다리다 손을 흔든다. [E]로 말을 걸고, [E]를 누를 때마다 다음 말이 자막으로
## 뜬다 (목소리 없이 마스크 너머 웅얼거림만). 말하는 동안 근무 장비를 하나씩 건네준다 — 점검 태블릿, 무전기,
## 근무 수칙 바인더 — 그리고 사무실 문으로 퇴근한다. 그때부터 소장이 무전으로 교육을 시작한다:
## 태블릿 열어 보기 → 바인더 펼쳐 보기 → 점검 1–3 (무전으로 한 시설씩 안내).
## 01:00 남은 저녁 근무자들도 퇴근 → 조명 절반 소등, 혼자 점검 4–8 (전부 정상).
## 03:00 정기 방송 (대기 수칙 p.9 ③) — 오늘은 문안도 평소 그대로.
## 06:00 퇴근하러 시설관리실로 가는 길에만, 출발 전광판 맨 위에 없는 항공편(SH 000 · GATE 0)이 잠깐 뜬다.

const POST := Vector3(-26.4, 0, 1.0)   # in the office, between your spawn and the door
## the handover talk: [text, item handed over with this line]
const HANDOVER_TALK := [
	["아, 오늘부터 새벽 근무 하시는 분이죠? 반가워요. 저는 저녁 근무예요.", ""],
	["퇴근 전에 장비부터 넘겨 드릴게요. 이건 점검 태블릿. 점검 지시가 여기로 와요. [Tab]으로 열고, 보고도 여기서 해요.", "tablet"],
	["무전기요. 소장님은 이걸로만 연락해요. 얼굴 보기 힘든 분이에요.", "radio"],
	["그리고 근무 수칙 바인더. 이게 제일 중요해요. [B]로 펼쳐 봐요.", "binder"],
	["무전이랑 수칙이 다르면, 수칙이 먼저예요. 꼭이요.", ""],
	["그럼 전 퇴근할게요. 오늘은 교육 근무라 별일 없을 거예요.", ""],
]
const ITEMS := {
	"tablet": ["점검 태블릿 수령 — [Tab]으로 열기", "tablet_open"],
	"radio": ["무전기 수령 — 소장의 지시는 무전으로 옵니다", "radio_on"],
	"binder": ["근무 수칙 바인더 수령 — [B]로 펼치기", "binder_open"],
}
## the first three inspections, talked through on the radio: where to go, then (once you are there) what normal is
const GUIDE := {
	"lights": ["첫 번째는 조명 분전반이에요. 사무실 문 바로 옆 벽. 구역 스위치를 올려서 조명을 켜 봐요.",
		"켠 구역이 전부 고르게 밝으면 정상이에요. 분전반을 보고 있으면 관찰 표시가 차요. 다 차면 [Tab] 태블릿에서 보고."],
	"fids": ["다음은 출발 전광판. 체크인 홀 북쪽 벽이요.",
		"맨 위에 TEST MODE, 테스트 편 여덟 개. 이 목록이랑 시계 잘 봐 둬요. 내일부터는 이거랑 비교하는 거예요."],
	"pa": ["마지막은 안내방송. 안내 데스크 콘솔에서 [테스트 송출]을 눌러요.",
		"문안은 수칙 4페이지랑 똑같아야 해요. 끝까지 듣고 보고하세요."],
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
	spawn_worker(POST, StaffNpc.yaw_for(Vector3(-1, 0, 0)))
	d.punched.connect(func(): _punched = true, CONNECT_ONE_SHOT)


func run() -> void:
	handover_ambience()
	await colleague_handover("시설관리실에 있는 [b]저녁 근무자[/b]에게 다가가 [E]로 말을 거십시오. ([E]를 누를 때마다 다음 말로 넘어갑니다)",
		"office", HANDOVER_TALK, _hand_over, "office")
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
	await punch_out()


## 00:00 · the colleague hands over the tablet, the radio and the rule binder, one line at a time.
func _hand_over(item: String) -> void:
	d.npc.present(item, 3.0)
	match item:
		"tablet":
			Game.set_flag("got_tablet")
		"radio":
			Game.set_flag("got_radio")
		"binder":
			Game.add_day_pages(1)
			Game.set_flag("got_binder")
	var it: Array = ITEMS[item]
	Snd.play(it[1], -6.0)
	d.notify(it[0], "good")


## The manager takes over on the radio: open the tablet, open the binder, then the first work order.
func _training() -> void:
	await d.wait(4.0)   # they are out of the office by now
	Snd.play_at("distant_door", d.t.doors.entrance.global_position + Vector3(0, 1.2, 0), -6.0, 1.0, 40.0)
	await d.wait(1.5)
	await d.radio("…들려요? 시설운영팀 소장입니다. 오늘부터 닷새, 새벽 점검 부탁해요. 첫날은 교육이라고 생각하세요.")
	# the prompts run alongside the goals: opening the tablet while the radio still talks counts
	var g1 := d.goal("점검 태블릿 열어 보기", "[b][Tab][/b]으로 점검 태블릿을 열어 보십시오.", "office")
	d.radio_async("먼저 태블릿부터. [Tab]으로 열어 봐요. 점검 지시랑 보고가 전부 여기서 돼요.")
	await d.until(func(): return d.ui.modal == "tablet" or d.dead)
	d.complete_goal(g1)
	await d.until(func(): return d.ui.modal == "" or d.dead)
	var g2 := d.goal("근무 수칙 바인더 펼쳐 보기", "[b][B][/b]로 근무 수칙 바인더를 펼쳐 보십시오. 1페이지 총칙부터 읽어 두십시오.", "office")
	d.radio_async("다음은 바인더. [B]로 펼쳐요. 1페이지 총칙은 꼭 읽어 두세요.")
	await d.until(func(): return d.ui.modal == "binder" or d.dead)
	d.complete_goal(g2)
	await d.until(func(): return d.ui.modal == "" or d.dead)
	d.ui.hud.show_key_hints(20.0)
	await d.radio("좋아요. 이제 점검이에요. 태블릿에 지시가 하나씩 떠요. 오늘은 여덟 번. 현장 가서 직접 보고, [정상]이든 [이상]이든 바로 보고하면 돼요.")


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


func _broadcast_soon() -> void:
	await d.radio("곧 세 시 정기 방송이에요. 수칙 9페이지 3번 — 방송이 끝날 때까지 그 자리에서 움직이지 마세요.")


func _broadcast() -> void:
	await d.wait(1.5)
	await d.ev_regular_broadcast(false, false)
	if d.dead:
		return
	await d.radio("잘했어요. 정기 방송은 매일 세 시에 나와요.")


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
			d.say("…SH 000? 저런 편이 있었나.", 3.0)
		if waited > 8.0 and seen <= 0.0 and not chimed:
			chimed = true   # a soft wrong chime from the board, in case you walk past without looking
			Snd.play_at("pa_chime_wrong", fp, -20.0, 0.8, 8.0, 40.0)
	fids.ghost_row(false)
