class_name NightPlan
extends RefCounted
## Builds the inspections of one dawn shift (5일 구성):
## - DAY 1 is the training shift: 8 inspections and no anomalies at all; DAY 2–5 have 14
## - inspections 1–3 are the 인수인계 (00:00–01:00): the day's facilities, switched on by hand, all normal
## - only facilities in the zones opened so far (DAY 1 체크인 → DAY 2 +수하물 → DAY 3 +X-ray →
##   DAY 4 +무빙워크·게이트 → DAY 5 everything)
## - easy anomalies early in the dawn, hard ones after the 03:00 broadcast; never the same anomaly twice a day
## - `AUTO` is the facility that starts by itself and becomes the next work order; `RESERVED` slots belong
##   to the day's script (its `custom` handlers create those tasks)

const DAYS := 5
const SLOTS := {1: 8, 2: 14, 3: 14, 4: 14, 5: 14}
const HANDOVER := 3
## game clock (minutes after 00:00) once inspection N is done: 01:00 handover ends, 02:00 the FIDS beat,
## 03:00 the regular broadcast, 05:30 the last inspection; linear in between
const CLOCK_ANCHORS := [[0, 0], [3, 60], [6, 120], [10, 180], [14, 330]]
const CLOCK_ANCHORS_TRAINING := [[0, 0], [3, 60], [6, 180], [8, 330]]

const ALL_FACS := ["lights", "fids", "pa", "baggage", "xray", "walkway", "gate"]
const DAY_FACS := {
	1: ["lights", "fids", "pa"],
	2: ["lights", "fids", "pa", "baggage"],
	3: ["lights", "fids", "pa", "baggage", "xray"],
	4: ALL_FACS,
	5: ALL_FACS,
}
## the handover inspections: learn today's normal state first
const HANDOVER_FACS := {1: ["lights", "fids", "pa"], 2: ["baggage", "fids", "pa"], 3: ["xray", "baggage", "lights"],
	4: ["walkway", "gate", "xray"], 5: ["gate", "walkway", "fids"]}
## facilities new today appear at least twice after the handover
const NEW_FACS := {1: [], 2: ["baggage"], 3: ["xray"], 4: ["walkway", "gate"], 5: ["gate"]}
## anomalous inspections per day, including the scripted and autonomous ones
const ANOMALY_COUNT := {1: 0, 2: 6, 3: 7, 4: 8, 5: 8}
## slot → [facility kind, anomaly] that starts by itself before that inspection
const AUTO := {2: {8: ["pa", "pa_auto"]}}
## slot → facility kind handled by the day script
const RESERVED := {2: {7: "fids"}, 3: {6: "baggage", 11: "xray"}, 4: {4: "pa", 5: "walkway", 6: "gate"}, 5: {12: "gate"}}
## anomalies the day script places itself (so the random picks never repeat them that day)
const SCRIPTED := {2: ["fids_gate04"], 3: ["bag_name", "xray_mybag"], 4: ["pa_auto", "auto_run", "gate_open"]}

const FAC_TEXT := {
	"lights": ["조명 분전반 점검", "시설관리실 출입문 옆 [b]조명 분전반[/b] 앞에서 켜 둔 구역의 조명을 관찰하고 보고하십시오.\n(꺼진 구역이 있으면 스위치로 켜십시오)"],
	"fids": ["FIDS 출발 전광판 점검", "체크인 홀 북측 [b]출발 전광판[/b]을 인수인계 때 본 정상 목록과 비교하고, 시계를 태블릿 시각과 비교하십시오."],
	"pa": ["안내방송 테스트 송출", "안내 데스크 [b]PA 콘솔[/b]에서 테스트 방송을 송출하고 끝까지 들으십시오. 표준 문안은 수칙 p.4에 있습니다."],
	"baggage": ["수하물 B-03 가동 테스트", "수하물 수취대 [b]B-03[/b]을 [가동]하고 나오는 가방을 끝까지 확인하십시오. 정상은 노란 TEST 태그 가방 3개입니다."],
	"xray": ["보안검색 X-ray 1번 판독", "보안검색 1번 레인 데스크에서 [b][가방 투입][/b]을 누르고 판독 화면을 관찰하십시오. 정상: 노트북, 물병, 열쇠, 케이블."],
	"walkway": ["무빙워크 MW-1 가동 점검", "탑승동 통로 남쪽 제어대에서 [b]MW-1[/b]을 가동하고 이동 방향과 속도를 관찰하십시오. 정상: ▲ 탑승동 쪽, 천천히."],
	"gate01": ["탑승구 GATE 01 점검", "GATE 01 포디움의 [b][상태 확인][/b]을 누르고 출입문·상단 표시·대기석을 관찰하십시오. (수칙 p.8)"],
	"gate02": ["탑승구 GATE 02 점검", "GATE 02 포디움의 [b][상태 확인][/b]을 누르고 출입문·상단 표시·대기석을 관찰하십시오. (수칙 p.8)"],
	"gate03": ["탑승구 GATE 03 점검", "GATE 03 포디움의 [b][상태 확인][/b]을 누르고 출입문·상단 표시·대기석을 관찰하십시오. (수칙 p.8)"],
	"gate04": ["탑승구 GATE 04 점검", "GATE 04 포디움의 [b][상태 확인][/b]을 누르고 출입문·상단 표시·대기석을 관찰하십시오. (수칙 p.8)"],
}
## handover wording: the evening staff are still around, you switch each facility on yourself
const HANDOVER_TEXT := {
	"lights": ["인수인계 · 조명 분전반 켜기", "시설관리실 출입문 옆 [b]조명 분전반[/b]에서 구역 조명을 직접 켜 보고, 정상 상태를 익힌 뒤 보고하십시오."],
	"fids": ["인수인계 · 출발 전광판 확인", "체크인 홀 [b]출발 전광판[/b] 앞에서 정상 목록(TEST MODE, SH 101~804)과 시계를 익힌 뒤 보고하십시오."],
	"pa": ["인수인계 · 안내방송 테스트", "안내 데스크 [b]PA 콘솔[/b]에서 표준 테스트 방송을 끝까지 들어 두고 보고하십시오. (수칙 p.4)"],
	"baggage": ["인수인계 · 수하물 B-03 가동", "수하물 수취대 [b]B-03[/b]을 직접 [가동]해 정상(TEST 태그 가방 3개)을 확인하고 보고하십시오."],
	"xray": ["인수인계 · X-ray 1번 판독", "보안검색 1번 레인에서 [b][가방 투입][/b]을 눌러 정상 판독 화면을 익히고 보고하십시오."],
	"walkway": ["인수인계 · 무빙워크 MW-1 가동", "탑승동 통로 남쪽 제어대에서 [b]MW-1[/b]을 직접 가동해 정상(▲ 탑승동 쪽, 천천히)을 확인하고 보고하십시오."],
	"gate01": ["인수인계 · GATE 01 상태 확인", "GATE 01 포디움에서 [b][상태 확인][/b]을 눌러 정상 상태를 익히고 보고하십시오. (수칙 p.8)"],
	"gate02": ["인수인계 · GATE 02 상태 확인", "GATE 02 포디움에서 [b][상태 확인][/b]을 눌러 정상 상태를 익히고 보고하십시오. (수칙 p.8)"],
	"gate03": ["인수인계 · GATE 03 상태 확인", "GATE 03 포디움에서 [b][상태 확인][/b]을 눌러 정상 상태를 익히고 보고하십시오. (수칙 p.8)"],
	"gate04": ["인수인계 · GATE 04 상태 확인", "GATE 04 포디움에서 [b][상태 확인][/b]을 눌러 정상 상태를 익히고 보고하십시오. (수칙 p.8)"],
}
const AUTO_TEXT := {
	"pa": ["⚠ 안내방송 무단 송출 감지", "아무도 송출하지 않은 방송이 나오고 있습니다. 안내 데스크 [b]PA 콘솔[/b]을 확인하고 보고하십시오."],
	"baggage": ["⚠ 수하물 B-03 비인가 가동", "수하물 수취대 B-03이 혼자 가동 중입니다. 현장에서 끝까지 확인한 뒤 보고하십시오."],
	"walkway": ["⚠ MW-1 무단 가동 감지", "아무도 가동하지 않은 [b]무빙워크 MW-1[/b]이 움직이고 있습니다. 현장을 확인하고 보고하십시오."],
	"gate01": ["⚠ GATE 01 출입문 개방 감지", "닫혀 있어야 할 [b]GATE 01[/b] 출입문이 열렸다는 신호가 들어왔습니다. 포디움에서 [상태 확인] 후 보고하십시오."],
	"gate02": ["⚠ GATE 02 출입문 개방 감지", "닫혀 있어야 할 [b]GATE 02[/b] 출입문이 열렸다는 신호가 들어왔습니다. 포디움에서 [상태 확인] 후 보고하십시오."],
	"gate03": ["⚠ GATE 03 출입문 개방 감지", "닫혀 있어야 할 [b]GATE 03[/b] 출입문이 열렸다는 신호가 들어왔습니다. 포디움에서 [상태 확인] 후 보고하십시오."],
	"gate04": ["⚠ GATE 04 출입문 개방 감지", "닫혀 있어야 할 [b]GATE 04[/b] 출입문이 열렸다는 신호가 들어왔습니다. 포디움에서 [상태 확인] 후 보고하십시오."],
	"xray": ["⚠ X-ray 1번 무단 스캔 감지", "보안검색 1번 레인 X-ray가 혼자 가방을 스캔했습니다. [b]판독 화면[/b]을 확인하고 보고하십시오."],
}
const GATES := ["gate01", "gate02", "gate03", "gate04"]


static func slots(cycle: int) -> int:
	return int(SLOTS[clampi(cycle, 1, DAYS)])


## Returns slots(cycle) dictionaries: {fac, kind, anomaly, title, detail, auto, handover, reserved}
static func build(cycle: int) -> Array:
	var c := clampi(cycle, 1, DAYS)
	var n_slots := slots(c)
	var facs: Array = DAY_FACS[c]
	var reserved: Dictionary = RESERVED.get(c, {})
	var autos: Dictionary = AUTO.get(c, {})
	# --- facility sequence: handover, then the dawn (reserved and autonomous slots keep their kind) ---
	var pool: Array = []
	for f in NEW_FACS.get(c, []):
		pool.append(f)
		pool.append(f)
	var free := n_slots - HANDOVER - reserved.size() - autos.size()
	while pool.size() < free:
		pool.append(facs[randi() % facs.size()])
	pool.resize(free)
	pool.shuffle()
	pool = _spread(pool)
	var seq: Array = (HANDOVER_FACS[c] as Array).duplicate()
	for n in range(HANDOVER + 1, n_slots + 1):
		if reserved.has(n):
			seq.append(reserved[n])
		elif autos.has(n):
			seq.append(autos[n][0])
		else:
			seq.append(pool.pop_front())
	# --- concrete facilities and texts ---
	var plan: Array = []
	for i in n_slots:
		var n := i + 1
		var kind: String = seq[i]
		var fac := kind
		if kind == "gate":
			fac = GATES[randi() % GATES.size()]
		var auto := autos.has(n)
		var handover := n <= HANDOVER
		var txt: Array
		if auto:
			txt = AUTO_TEXT[fac] if AUTO_TEXT.has(fac) else AUTO_TEXT[kind]
		elif handover:
			txt = HANDOVER_TEXT[fac]
		else:
			txt = FAC_TEXT[fac]
		plan.append({"fac": fac, "kind": kind, "anomaly": autos[n][1] if auto else "", "title": txt[0], "detail": txt[1],
			"auto": auto, "handover": handover, "reserved": reserved.has(n)})
	# --- anomalies: easy before 03:00, hard after; reserved slots are the script's own ---
	var used: Array = (SCRIPTED.get(c, []) as Array).duplicate()
	for s in plan:
		if s.anomaly != "":
			used.append(s.anomaly)
	var want: int = ANOMALY_COUNT[c] - reserved.size() - autos.size()
	var have := 0
	var order: Array = range(HANDOVER, n_slots)
	order.shuffle()
	for i in order:
		if have >= want:
			break
		var s: Dictionary = plan[i]
		if s.anomaly != "" or s.reserved or s.auto:
			continue
		var a := AnomalyDB.pick(s.kind, c, used, "easy" if i + 1 <= 7 else ("hard" if i + 1 >= 11 else ""))
		if a == "":
			continue
		s.anomaly = a
		used.append(a)
		have += 1
	return plan


## Game clock (minutes after 00:00) once inspection `n` of that day's shift is done.
static func clock_after(n: int, cycle := 2) -> int:
	var anchors: Array = CLOCK_ANCHORS_TRAINING if cycle == 1 else CLOCK_ANCHORS
	for k in range(1, anchors.size()):
		var a: Array = anchors[k - 1]
		var b: Array = anchors[k]
		if n <= int(b[0]):
			var f := float(n - int(a[0])) / float(int(b[0]) - int(a[0]))
			return roundi(lerpf(float(a[1]), float(b[1]), f))
	return int(anchors[anchors.size() - 1][1])


## Orders facilities so the same one rarely comes twice in a row.
static func _spread(items: Array) -> Array:
	var rest := items.duplicate()
	var out: Array = []
	while not rest.is_empty():
		var idx := 0
		for j in rest.size():
			if out.is_empty() or rest[j] != out[out.size() - 1]:
				idx = j
				break
		out.append(rest[idx])
		rest.remove_at(idx)
	return out
