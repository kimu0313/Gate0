class_name NightPlan
extends RefCounted
## Builds the 10 inspections of one night (concept doc · 1차 프로토타입 플레이 흐름):
## - only facilities in the zones opened so far (N1 체크인 → N2 +수하물 → N3 +보안검색·무빙워크 → N4/N5 +탑승 게이트)
## - inspection 6 is a facility that started by itself; it becomes the next work order
## - the same anomaly never appears twice in a night; placement is random every playthrough
## - `FORCED` guarantees the anomaly a fake/damaged page of that night contradicts shows up at least once

const SLOTS := 10
const AUTO_SLOT := 6

const NIGHT_FACS := {
	1: ["lights", "fids", "pa"],
	2: ["lights", "fids", "pa", "baggage"],
	3: ["lights", "fids", "pa", "baggage", "xray", "walkway"],
	4: ["lights", "fids", "pa", "baggage", "xray", "walkway", "gate"],
	5: ["lights", "fids", "pa", "baggage", "xray", "walkway", "gate"],
}
## facilities that are new tonight appear at least twice
const NEW_FACS := {1: ["fids", "pa", "lights"], 2: ["baggage"], 3: ["xray", "walkway"], 4: ["gate"], 5: ["gate", "xray"]}
## anomalous inspections per night, including the autonomous one
const ANOMALY_COUNT := {1: 4, 2: 5, 3: 5, 4: 6, 5: 6}
## the facility that turns itself on before inspection 6, and what it does
const AUTO := {1: ["pa", "pa_auto"], 2: ["baggage", "bag_name"], 3: ["walkway", "auto_run"], 4: ["gate", "gate_open"],
	5: ["xray", "xray_figure"]}
const FORCED := {1: {"fids": "fids_gate04"}, 3: {"baggage": "bag_reverse"},
	4: {"pa": "pa_slow", "xray": "xray_figure", "walkway": "walk_reverse"}, 5: {"gate": "gate_passenger"}}

const FAC_TEXT := {
	"lights": ["조명 분전반 점검", "시설관리실 출입문 옆 [b]조명 분전반[/b] 앞에서 켜 둔 구역의 조명을 관찰하고 보고하십시오.\n(꺼진 구역이 있으면 스위치로 켜십시오)"],
	"fids": ["FIDS 출발 전광판 점검", "체크인 홀 북측 [b]출발 전광판[/b]을 낮의 기록(점검 앨범)과 비교하고, 시계를 태블릿 시각과 비교하십시오."],
	"pa": ["안내방송 테스트 송출", "안내 데스크 [b]PA 콘솔[/b]에서 테스트 방송을 송출하고 끝까지 들으십시오. 표준 문안은 수칙 p.4에 있습니다."],
	"baggage": ["수하물 B-03 가동 테스트", "수하물 수취대 [b]B-03[/b]을 [가동]하고 나오는 가방을 끝까지 확인하십시오. 정상은 노란 TEST 태그 가방 3개입니다."],
	"xray": ["보안검색 X-ray 1번 판독", "보안검색 1번 레인 데스크에서 [b][가방 투입][/b]을 누르고 판독 화면을 관찰하십시오. 정상: 노트북, 물병, 열쇠, 케이블."],
	"walkway": ["무빙워크 MW-1 가동 점검", "탑승동 통로 남쪽 제어대에서 [b]MW-1[/b]을 가동하고 이동 방향과 속도를 관찰하십시오. 정상: ▲ 탑승동 쪽, 천천히."],
	"gate01": ["탑승구 GATE 01 점검", "GATE 01 포디움의 [b][상태 확인][/b]을 누르고 출입문·상단 표시·대기석을 관찰하십시오. (수칙 p.8)"],
	"gate02": ["탑승구 GATE 02 점검", "GATE 02 포디움의 [b][상태 확인][/b]을 누르고 출입문·상단 표시·대기석을 관찰하십시오. (수칙 p.8)"],
	"gate03": ["탑승구 GATE 03 점검", "GATE 03 포디움의 [b][상태 확인][/b]을 누르고 출입문·상단 표시·대기석을 관찰하십시오. (수칙 p.8)"],
	"gate04": ["탑승구 GATE 04 점검", "GATE 04 포디움의 [b][상태 확인][/b]을 누르고 출입문·상단 표시·대기석을 관찰하십시오. (수칙 p.8)"],
}
const AUTO_TEXT := {
	"pa": ["⚠ 안내방송 무단 송출 감지", "아무도 송출하지 않은 방송이 나오고 있습니다. 안내 데스크 [b]PA 콘솔[/b]을 확인하고 보고하십시오."],
	"baggage": ["⚠ 수하물 B-03 비인가 가동", "수하물 수취대 B-03이 혼자 가동 중입니다. 현장에서 [b]정지[/b]시키고 끝까지 확인한 뒤 보고하십시오."],
	"walkway": ["⚠ MW-1 무단 가동 감지", "아무도 가동하지 않은 [b]무빙워크 MW-1[/b]이 움직이고 있습니다. 현장을 확인하고 보고하십시오."],
	"gate01": ["⚠ GATE 01 출입문 개방 감지", "닫혀 있어야 할 [b]GATE 01[/b] 출입문이 열렸다는 신호가 들어왔습니다. 포디움에서 [상태 확인] 후 보고하십시오."],
	"gate02": ["⚠ GATE 02 출입문 개방 감지", "닫혀 있어야 할 [b]GATE 02[/b] 출입문이 열렸다는 신호가 들어왔습니다. 포디움에서 [상태 확인] 후 보고하십시오."],
	"gate03": ["⚠ GATE 03 출입문 개방 감지", "닫혀 있어야 할 [b]GATE 03[/b] 출입문이 열렸다는 신호가 들어왔습니다. 포디움에서 [상태 확인] 후 보고하십시오."],
	"gate04": ["⚠ GATE 04 출입문 개방 감지", "닫혀 있어야 할 [b]GATE 04[/b] 출입문이 열렸다는 신호가 들어왔습니다. 포디움에서 [상태 확인] 후 보고하십시오."],
	"xray": ["⚠ X-ray 1번 무단 스캔 감지", "보안검색 1번 레인 X-ray가 혼자 가방을 스캔했습니다. [b]판독 화면[/b]을 확인하고 보고하십시오."],
}
const GATES := ["gate01", "gate02", "gate03", "gate04"]


## Returns SLOTS dictionaries: {fac, anomaly, title, detail, auto}
static func build(cycle: int, tutorial := false) -> Array:
	var c := clampi(cycle, 1, 5)
	var facs: Array = NIGHT_FACS[c]
	var auto_kind: String = AUTO[c][0]
	# --- facility sequence (slot AUTO_SLOT is reserved) ---
	var pool: Array = []
	for f in NEW_FACS.get(c, []):
		pool.append(f)
		pool.append(f)
	while pool.size() < SLOTS - 1:
		pool.append(facs[randi() % facs.size()])
	pool.shuffle()
	var seq: Array = []
	if tutorial:
		# Night 1 opens gently: lights and PA are normal, then the board shows something it should not
		seq = ["lights", "pa", "fids"]
		for f in seq:
			pool.erase(f)
	seq.append_array(_spread(pool))
	seq.insert(AUTO_SLOT - 1, auto_kind)
	seq.resize(SLOTS)
	# --- concrete facilities and texts ---
	var plan: Array = []
	for i in SLOTS:
		var kind: String = seq[i]
		var fac := kind
		if kind == "gate":
			fac = GATES[randi() % GATES.size()]
		var auto := i == AUTO_SLOT - 1
		var txt: Array = (AUTO_TEXT[fac] if AUTO_TEXT.has(fac) else AUTO_TEXT[kind]) if auto else FAC_TEXT[fac]
		plan.append({"fac": fac, "kind": kind, "anomaly": AUTO[c][1] if auto else "", "title": txt[0], "detail": txt[1], "auto": auto})
	# --- anomalies ---
	var used: Array = [AUTO[c][1]]
	var forced: Dictionary = FORCED.get(c, {})
	for kind in forced.keys():
		for i in SLOTS:
			var s: Dictionary = plan[i]
			if s.kind == kind and not s.auto and s.anomaly == "" and i > 0:
				s.anomaly = forced[kind]
				used.append(forced[kind])
				break
	var want: int = ANOMALY_COUNT[c]
	var have := plan.filter(func(s): return s.anomaly != "").size()
	var order := range(1, SLOTS)
	order.shuffle()
	for i in order:
		if have >= want:
			break
		var s: Dictionary = plan[i]
		if s.anomaly != "" or (tutorial and i < 2):
			continue
		var a := AnomalyDB.pick(s.kind, c, used)
		if a == "":
			continue
		s.anomaly = a
		used.append(a)
		have += 1
	return plan


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
