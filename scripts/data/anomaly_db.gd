class_name AnomalyDB
extends RefCounted
## Data-driven anomaly catalogue.
## fix    : accepted [action, target] pairs that resolve the anomaly ("$zone" = facility.anomaly_zone,
##          "$id" = facility id, "*" = any target). Special continuous fixes are handled by the director:
##          "eyes_closed_near" (target facility, seconds), "face_away_from_passenger", "pa_slow_survived",
##          "pa_still_survived".
## lethal : [action, target] pairs that kill the player while the anomaly is active.
## timer  : seconds allowed to respond after reporting [이상].
## miss   : one line for the morning report when the anomaly was missed (사후 정답 공개).

const DATA := {
	# --- 조명 분전반 ----------------------------------------------------------------------
	"light_flicker": {
		"facility": "lights", "name": "조명 리듬 점멸", "page": "p2",
		"fix": [["lights_cycle", "$zone"]], "lethal": [], "timer": 120.0,
		"miss": "조명이 짧게 세 번, 길게 한 번 — 일정한 리듬으로 깜빡이고 있었습니다.",
	},
	"light_dark": {
		"facility": "lights", "name": "꺼진 패널", "page": "p2",
		"fix": [["lights_cycle", "$zone"]], "lethal": [], "timer": 120.0,
		"miss": "켜 둔 구역의 천장 패널 하나만 꺼져 있었습니다.",
	},
	"light_red": {
		"facility": "lights", "name": "붉은 조명", "page": "p2",
		"fix": [["lights_off", "$zone"]], "lethal": [["stand_under_red", "*"]], "timer": 120.0,
		"miss": "천장 조명 하나가 붉게 빛나고 있었습니다.",
		"death": "붉은 조명 아래에 서 있었습니다.",
	},
	# --- FIDS ------------------------------------------------------------------------------
	"fids_gate04": {
		"facility": "fids", "name": "GATE 04 체크인", "page": "p3",
		"fix": [["reset", "fids"]], "lethal": [["power_off", "fids"]], "timer": 120.0,
		"miss": "전광판 전체에 'FLIGHT 000 / GATE 04 / CHECK-IN'이 떠 있었습니다. 테스트 목록이 아닙니다.",
		"death": "목록 이상인데 전광판 전원을 차단했습니다. (수칙 p.3: 전원을 차단하지 마십시오)",
	},
	"fids_extra": {
		"facility": "fids", "name": "목록에 없는 항공편", "page": "p3",
		"fix": [["reset", "fids"]], "lethal": [["power_off", "fids"]], "timer": 120.0,
		"miss": "테스트 목록에 없는 항공편(SH 000)이 한 줄 끼어 있었습니다.",
		"death": "목록 이상인데 전광판 전원을 차단했습니다. (수칙 p.3: 전원을 차단하지 마십시오)",
	},
	"fids_changed": {
		"facility": "fids", "name": "바뀐 행", "page": "p3",
		"fix": [["reset", "fids"]], "lethal": [["power_off", "fids"]], "timer": 120.0,
		"miss": "전광판의 한 행이 낮에 기록한 테스트 목록과 달랐습니다.",
		"death": "목록 이상인데 전광판 전원을 차단했습니다. (수칙 p.3: 전원을 차단하지 마십시오)",
	},
	"fids_clock": {
		"facility": "fids", "name": "거꾸로 가는 시계", "page": "p3",
		"fix": [["power_off", "fids"]], "lethal": [["reset", "fids"]], "timer": 150.0,
		"miss": "전광판 시계가 태블릿 시각과 다르게, 거꾸로 흐르고 있었습니다.",
		"death": "시계 이상인데 [RESET]을 눌렀습니다. (수칙 p.3)",
	},
	# --- 안내방송 ----------------------------------------------------------------------------
	"pa_word": {
		"facility": "pa", "name": "바뀐 문안", "page": "p4",
		"fix": [["pa_stop", "pa"]], "lethal": [], "timer": 120.0,
		"miss": "테스트 방송의 단어 하나가 표준 문안과 달랐습니다.",
	},
	"pa_extra": {
		"facility": "pa", "name": "덧붙은 문장", "page": "p4",
		"fix": [["pa_still_survived", "pa"]], "lethal": [], "timer": 150.0,
		"miss": "표준 문안이 끝난 뒤 문장이 하나 더 붙어 나왔습니다.",
	},
	"pa_slow": {
		"facility": "pa", "name": "늘어지는 목소리", "page": "p4",
		"fix": [["pa_slow_survived", "pa"]], "lethal": [["pa_stop", "pa"]], "timer": 150.0,
		"miss": "방송 목소리가 점점 느리고 낮아졌습니다.",
		"death": "늘어지는 방송을 [송출 중지]로 끊었습니다. (수칙 p.4)",
	},
	"pa_auto": {
		"facility": "pa", "name": "혼자 나오는 방송", "page": "p4",
		"fix": [["pa_stop", "pa"]], "lethal": [], "timer": 150.0,
		"miss": "아무도 송출하지 않은 방송이 혼자 반복되고 있었습니다.",
	},
	# --- 수하물 -------------------------------------------------------------------------------
	"bag_extra": {
		"facility": "baggage", "name": "네 번째 가방", "page": "p5",
		"fix": [["estop", "baggage"]], "lethal": [["touch_bag", "extra"]], "timer": 120.0,
		"miss": "TEST 태그가 없는 붉은 가방이 하나 더 나왔습니다.",
		"death": "테스트 수하물이 아닌 가방에 손을 댔습니다. (수칙 p.5)",
	},
	"bag_reverse": {
		"facility": "baggage", "name": "역회전", "page": "p5",
		"fix": [["power_off", "baggage"]], "lethal": [["estop", "baggage"]], "timer": 150.0,
		"miss": "벨트가 바닥 화살표와 반대 방향으로 돌고 있었습니다.",
		"death": "역회전 중인 벨트에 [비상정지]를 눌렀습니다. (수칙 p.5)",
	},
	"bag_nostop": {
		"facility": "baggage", "name": "멈추지 않는 벨트", "page": "p5",
		"fix": [["estop", "baggage"]], "lethal": [["touch_bag", "*"]], "timer": 120.0,
		"miss": "[정지]를 눌러도 벨트가 멈추지 않았습니다.",
		"death": "멈추지 않는 벨트의 가방에 손을 댔습니다.",
	},
	"bag_name": {
		"facility": "baggage", "name": "당신의 가방", "page": "p5",
		"fix": [["estop", "baggage"]], "lethal": [["touch_bag", "name"]], "timer": 120.0,
		"miss": "당신의 이름이 적힌 가방이 나왔습니다.",
		"death": "당신의 이름이 적힌 가방을 집어 들었습니다.",
	},
	# --- 무빙워크 -------------------------------------------------------------------------------
	"walk_reverse": {
		"facility": "walkway", "name": "역방향 무빙워크", "page": "p6",
		"fix": [["power_off", "walkway"]], "lethal": [["ride_walkway", "walkway"]], "timer": 150.0,
		"miss": "무빙워크가 표시(▲ 탑승동)와 반대로 움직이고 있었습니다.",
		"death": "역방향으로 움직이는 무빙워크에 올라탔습니다. (수칙 p.6)",
	},
	"walk_fast": {
		"facility": "walkway", "name": "과속", "page": "p6",
		"fix": [["estop", "walkway"]], "lethal": [["ride_walkway", "walkway"]], "timer": 120.0,
		"miss": "무빙워크 속도가 비정상적으로 빨랐습니다.",
		"death": "과속 중인 무빙워크에 올라탔습니다. (수칙 p.6)",
	},
	"auto_run": {
		"facility": "walkway", "name": "무단 가동", "page": "p6",
		"fix": [["stop", "walkway"], ["estop", "walkway"], ["power_off", "walkway"]],
		"lethal": [["ride_walkway", "walkway"]], "timer": 150.0,
		"miss": "아무도 켜지 않은 무빙워크가 움직이고 있었습니다.",
		"death": "아무도 켜지 않은 무빙워크에 올라탔습니다. (수칙 p.6)",
	},
	# --- 보안검색 -------------------------------------------------------------------------------
	"xray_figure": {
		"facility": "xray", "name": "판독 화면 속 사람", "page": "p7",
		"fix": [["eyes_closed_near", "xray"]], "lethal": [["monitor_off", "xray"]], "timer": 120.0,
		"miss": "X-ray 화면 속 가방 안에 웅크린 사람의 형체가 있었습니다.",
		"death": "사람 형체가 보이는 X-ray 모니터를 껐습니다. (수칙 p.7)",
	},
	"xray_heart": {
		"facility": "xray", "name": "뛰는 무언가", "page": "p7",
		"fix": [["estop", "xray"]], "lethal": [["monitor_off", "xray"]], "timer": 120.0,
		"miss": "X-ray 화면 속 가방 안에서 무언가가 규칙적으로 뛰고 있었습니다.",
		"death": "움직이는 물체가 보이는 X-ray 모니터를 껐습니다. (수칙 p.7)",
	},
	# --- 탑승구 ----------------------------------------------------------------------------------
	"gate_open": {
		"facility": "gate", "name": "열린 탑승구", "page": "p8",
		"fix": [["close_gate", "$id"]], "lethal": [["enter_gate", "$id"]], "timer": 120.0,
		"miss": "닫혀 있어야 할 탑승구가 열려 있었고, FLIGHT 000 탑승 중이라고 표시됐습니다.",
		"death": "열린 탑승구 너머 탑승교로 들어갔습니다. (수칙 p.8)",
	},
	"gate_seats": {
		"facility": "gate", "name": "돌아앉은 대기석", "page": "p8",
		"fix": [["lights_off", "gates"]], "lethal": [], "timer": 150.0,
		"miss": "탑승구 앞 대기석이 전부 반대쪽을 보고 있었습니다.",
	},
	"gate_passenger": {
		"facility": "gate", "name": "한 명의 승객", "page": "p8",
		"fix": [["face_away_from_passenger", "$id"]], "lethal": [["approach_passenger", "$id"]], "timer": 120.0,
		"miss": "탑승구 대기석에 승객 한 명이 앉아 있었습니다.",
		"death": "대기석의 승객에게 다가갔습니다. (수칙 p.8)",
	},
}

## Anomaly pools per facility and the first night they may appear in (Day/Night 1–5 schedule):
## N1 체크인 (조명·FIDS·방송) → N2 +수하물 → N3 +보안검색·무빙워크 → N4 +탑승 게이트 → N5 전 구역.
## Story/autonomous anomalies (fids_gate04, pa_auto, bag_name, auto_run) are placed by the night plans.
const POOLS := {
	"lights": [["light_flicker", 1], ["light_dark", 1], ["light_red", 2]],
	"fids": [["fids_extra", 1], ["fids_changed", 1], ["fids_clock", 2]],
	"pa": [["pa_word", 1], ["pa_extra", 1], ["pa_slow", 3]],
	"baggage": [["bag_extra", 2], ["bag_reverse", 2], ["bag_nostop", 3]],
	"walkway": [["walk_reverse", 3], ["walk_fast", 4]],
	"xray": [["xray_figure", 3], ["xray_heart", 4]],
	"gate": [["gate_open", 4], ["gate_seats", 4], ["gate_passenger", 4]],
}


static func get_def(id: String) -> Dictionary:
	return DATA.get(id, {})


## Facility kind of a facility id ("gate03" -> "gate").
static func kind_of(fac_id: String) -> String:
	return "gate" if fac_id.begins_with("gate") else fac_id


## Picks an unused anomaly for this facility kind. `used` = anomaly ids already placed this night
## (the same anomaly never appears twice in one night).
static func pick(facility_kind: String, cycle: int, used: Array = []) -> String:
	var options := []
	for e in POOLS.get(facility_kind, []):
		if int(e[1]) <= cycle and not used.has(e[0]):
			options.append(e[0])
	if options.is_empty():
		return ""
	# prefer anomalies introduced tonight (every night brings something new)
	var fresh := options.filter(func(a): return _cycle_of(facility_kind, a) == cycle)
	if not fresh.is_empty() and randf() < 0.65:
		return fresh[randi() % fresh.size()]
	return options[randi() % options.size()]


static func available(facility_kind: String, cycle: int, used: Array = []) -> int:
	var n := 0
	for e in POOLS.get(facility_kind, []):
		if int(e[1]) <= cycle and not used.has(e[0]):
			n += 1
	return n


static func _cycle_of(kind: String, a: String) -> int:
	for e in POOLS.get(kind, []):
		if e[0] == a:
			return int(e[1])
	return 99
