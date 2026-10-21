class_name AnomalyDB
extends RefCounted
## Data-driven anomaly catalogue.
## fix    : accepted [action, target] pairs that resolve the anomaly ("$zone" = facility.anomaly_zone,
##          "$id" = facility id, "*" = any target). Special continuous fixes are handled by the director:
##          "eyes_closed_near" (target facility, seconds), "face_away_from_passenger", "pa_slow_survived".
## lethal : [action, target] pairs that kill the player while the anomaly is active.
## timer  : seconds allowed to respond after reporting [이상].

const DATA := {
	# --- 조명 분전반 ----------------------------------------------------------------------
	"light_flicker": {
		"facility": "lights", "name": "조명 리듬 점멸", "page": "p2",
		"fix": [["lights_cycle", "$zone"]], "lethal": [], "timer": 120.0,
		"miss_hint": "%s 구역 조명이 일정한 리듬으로 깜빡이고 있었습니다.",
		"fix_hint": "해당 구역 스위치를 내리고 10초 뒤 다시 올려야 했습니다. (수칙 p.2)",
	},
	"light_red": {
		"facility": "lights", "name": "붉은 조명", "page": "p2",
		"fix": [["lights_off", "$zone"]], "lethal": [["stand_under_red", "*"]], "timer": 120.0,
		"miss_hint": "%s 구역에 붉게 빛나는 조명이 하나 있었습니다.",
		"fix_hint": "붉은 조명 아래에 서지 말고 해당 구역 조명을 꺼야 했습니다. (수칙 p.2)",
		"death": "붉은 조명 아래에 서 있었습니다.",
	},
	# --- FIDS ------------------------------------------------------------------------------
	"fids_extra": {
		"facility": "fids", "name": "목록에 없는 항공편", "page": "p3",
		"fix": [["reset", "fids"]], "lethal": [["power_off", "fids"]], "timer": 120.0,
		"miss_hint": "전광판에 테스트 목록에 없는 항공편(SH 000)이 있었습니다.",
		"fix_hint": "제어함의 [RESET]을 눌러야 했습니다. (수칙 p.3)",
		"death": "목록 이상인데 전광판 전원을 차단했습니다. (수칙 p.3: 전원을 차단하지 마십시오)",
	},
	"fids_changed": {
		"facility": "fids", "name": "바뀐 행", "page": "p3",
		"fix": [["reset", "fids"]], "lethal": [["power_off", "fids"]], "timer": 120.0,
		"miss_hint": "전광판의 한 행이 낮에 기록한 테스트 목록과 달랐습니다.",
		"fix_hint": "제어함의 [RESET]을 눌러야 했습니다. (수칙 p.3)",
		"death": "목록 이상인데 전광판 전원을 차단했습니다. (수칙 p.3: 전원을 차단하지 마십시오)",
	},
	"fids_clock": {
		"facility": "fids", "name": "거꾸로 가는 시계", "page": "p3",
		"fix": [["power_off", "fids"]], "lethal": [["reset", "fids"]], "timer": 150.0,
		"miss_hint": "전광판 시계가 태블릿 시각과 다르게 흐르고 있었습니다.",
		"fix_hint": "배전반에서 FIDS 전원을 차단해야 했습니다. RESET 금지. (수칙 p.3)",
		"death": "시계 이상인데 [RESET]을 눌렀습니다. (수칙 p.3)",
	},
	# --- 안내방송 ----------------------------------------------------------------------------
	"pa_word": {
		"facility": "pa", "name": "바뀐 문안", "page": "p4",
		"fix": [["pa_stop", "pa"]], "lethal": [], "timer": 120.0,
		"miss_hint": "테스트 방송의 단어 하나가 표준 문안과 달랐습니다.",
		"fix_hint": "방송 중에 [송출 중지]를 눌러야 했습니다. (수칙 p.4)",
	},
	"pa_slow": {
		"facility": "pa", "name": "늘어지는 목소리", "page": "p4",
		"fix": [["pa_slow_survived", "pa"]], "lethal": [["pa_stop", "pa"]], "timer": 150.0,
		"miss_hint": "방송 목소리가 점점 느리고 낮아졌습니다.",
		"fix_hint": "[송출 중지]를 누르지 말고, 탑승동(북쪽)을 등진 채 방송이 끝날 때까지 기다려야 했습니다. (수칙 p.4)",
		"death": "늘어지는 방송을 [송출 중지]로 끊었습니다. (수칙 p.4)",
	},
	# --- 수하물 -------------------------------------------------------------------------------
	"bag_extra": {
		"facility": "baggage", "name": "네 번째 가방", "page": "p5",
		"fix": [["estop", "baggage"]], "lethal": [["touch_bag", "extra"]], "timer": 120.0,
		"miss_hint": "TEST 태그가 없는 붉은 가방이 하나 더 나왔습니다.",
		"fix_hint": "가방에 손대지 말고 [비상정지]를 눌러야 했습니다. (수칙 p.5)",
		"death": "테스트 수하물이 아닌 가방에 손을 댔습니다. (수칙 p.5)",
	},
	"bag_reverse": {
		"facility": "baggage", "name": "역회전", "page": "p5",
		"fix": [["power_off", "baggage"]], "lethal": [["estop", "baggage"]], "timer": 150.0,
		"miss_hint": "벨트가 화살표와 반대 방향으로 돌고 있었습니다.",
		"fix_hint": "[비상정지] 금지. 배전반에서 B-03 전원을 차단해야 했습니다. (수칙 p.5)",
		"death": "역회전 중인 벨트에 [비상정지]를 눌렀습니다. (수칙 p.5)",
	},
	"bag_nostop": {
		"facility": "baggage", "name": "멈추지 않는 벨트", "page": "p5",
		"fix": [["estop", "baggage"]], "lethal": [["touch_bag", "*"]], "timer": 120.0,
		"miss_hint": "[정지]를 눌러도 벨트가 멈추지 않았습니다.",
		"fix_hint": "[비상정지]를 눌러야 했습니다. (수칙 p.5)",
		"death": "멈추지 않는 벨트의 가방에 손을 댔습니다.",
	},
	"bag_name": {
		"facility": "baggage", "name": "당신의 가방", "page": "p5",
		"fix": [["estop", "baggage"]], "lethal": [["touch_bag", "name"]], "timer": 120.0,
		"miss_hint": "당신의 이름이 적힌 가방이 나왔습니다.",
		"fix_hint": "절대 손대지 말고 [비상정지] 후 떠나야 했습니다. (수칙 p.5)",
		"death": "당신의 이름이 적힌 가방을 집어 들었습니다.",
	},
	# --- 무빙워크 -------------------------------------------------------------------------------
	"walk_reverse": {
		"facility": "walkway", "name": "역방향 무빙워크", "page": "p6",
		"fix": [["power_off", "walkway"]], "lethal": [["ride_walkway", "walkway"]], "timer": 150.0,
		"miss_hint": "무빙워크가 표시(▲ 탑승동)와 반대로 움직이고 있었습니다.",
		"fix_hint": "절대 탑승하지 말고 배전반에서 MW-1 전원을 차단해야 했습니다. (수칙 p.6)",
		"death": "역방향으로 움직이는 무빙워크에 올라탔습니다. (수칙 p.6)",
	},
	"walk_fast": {
		"facility": "walkway", "name": "과속", "page": "p6",
		"fix": [["estop", "walkway"]], "lethal": [["ride_walkway", "walkway"]], "timer": 120.0,
		"miss_hint": "무빙워크 속도가 비정상적으로 빨랐습니다.",
		"fix_hint": "탑승하지 말고 [비상정지]를 눌러야 했습니다. (수칙 p.6)",
		"death": "과속 중인 무빙워크에 올라탔습니다. (수칙 p.6)",
	},
	"auto_run": {
		"facility": "walkway", "name": "무단 가동", "page": "p6",
		"fix": [["stop", "walkway"], ["estop", "walkway"], ["power_off", "walkway"]],
		"lethal": [["ride_walkway", "walkway"]], "timer": 150.0,
		"miss_hint": "아무도 켜지 않은 무빙워크가 움직이고 있었습니다.",
		"fix_hint": "탑승하지 말고 정지시켜야 했습니다. (수칙 p.6)",
		"death": "아무도 켜지 않은 무빙워크에 올라탔습니다. (수칙 p.6)",
	},
	# --- 보안검색 -------------------------------------------------------------------------------
	"xray_figure": {
		"facility": "xray", "name": "판독 화면 속 사람", "page": "p7",
		"fix": [["eyes_closed_near", "xray"]], "lethal": [["monitor_off", "xray"]], "timer": 120.0,
		"miss_hint": "X-ray 화면 속 가방 안에 웅크린 사람의 형체가 있었습니다.",
		"fix_hint": "모니터를 끄지 말고, 화면 앞에서 눈을 감고 10초를 세야 했습니다. (수칙 p.7)",
		"death": "사람 형체가 보이는 X-ray 모니터를 껐습니다. (수칙 p.7)",
	},
	"xray_heart": {
		"facility": "xray", "name": "뛰는 무언가", "page": "p7",
		"fix": [["estop", "xray"]], "lethal": [["monitor_off", "xray"]], "timer": 120.0,
		"miss_hint": "가방 속에서 무언가가 규칙적으로 뛰고 있었습니다.",
		"fix_hint": "X-ray [비상정지]를 눌러야 했습니다. (수칙 p.7)",
		"death": "움직이는 물체가 보이는 X-ray 모니터를 껐습니다. (수칙 p.7)",
	},
	# --- 탑승구 ----------------------------------------------------------------------------------
	"gate_open": {
		"facility": "gate", "name": "열린 탑승구", "page": "p8",
		"fix": [["close_gate", "$id"]], "lethal": [["enter_gate", "$id"]], "timer": 120.0,
		"miss_hint": "닫혀 있어야 할 탑승구가 열려 있었고, FLIGHT 000 탑승 중이라고 표시됐습니다.",
		"fix_hint": "문 너머로 들어가지 말고 포디움의 [닫기·잠금]을 눌러야 했습니다. (수칙 p.8)",
		"death": "열린 탑승구 너머 탑승교로 들어갔습니다. (수칙 p.8)",
	},
	"gate_seats": {
		"facility": "gate", "name": "돌아앉은 대기석", "page": "p8",
		"fix": [["lights_off", "gates"]], "lethal": [], "timer": 150.0,
		"miss_hint": "탑승구 앞 대기석이 전부 반대쪽을 보고 있었습니다.",
		"fix_hint": "게이트 구역 조명을 꺼야 했습니다. (수칙 p.8)",
	},
	"gate_passenger": {
		"facility": "gate", "name": "한 명의 승객", "page": "p8",
		"fix": [["face_away_from_passenger", "$id"]], "lethal": [["approach_passenger", "$id"]], "timer": 120.0,
		"miss_hint": "대기석에 승객 한 명이 앉아 있었습니다.",
		"fix_hint": "다가가지 말고, 등을 돌린 채 10초간 기다려야 했습니다. (수칙 p.8)",
		"death": "대기석의 승객에게 다가갔습니다. (수칙 p.8)",
	},
}

## Anomaly pools per facility and the first cycle they may appear in.
const POOLS := {
	"lights": [["light_flicker", 1], ["light_red", 2]],
	"fids": [["fids_extra", 1], ["fids_changed", 2], ["fids_clock", 3]],
	"pa": [["pa_word", 1], ["pa_slow", 3]],
	"baggage": [["bag_extra", 1], ["bag_reverse", 2], ["bag_nostop", 3]],
	"walkway": [["walk_reverse", 2], ["walk_fast", 3]],
	"xray": [["xray_figure", 2], ["xray_heart", 3]],
	"gate": [["gate_open", 3], ["gate_seats", 3], ["gate_passenger", 3]],
}


static func get_def(id: String) -> Dictionary:
	return DATA.get(id, {})


static func pick(facility_kind: String, cycle: int, exclude: Array = []) -> String:
	var options := []
	for e in POOLS.get(facility_kind, []):
		if int(e[1]) <= cycle and not exclude.has(e[0]):
			options.append(e[0])
	if options.is_empty():
		return ""
	# prefer anomalies introduced this cycle (new content every night)
	var fresh := options.filter(func(a): return _cycle_of(facility_kind, a) == cycle)
	if not fresh.is_empty() and randf() < 0.6:
		return fresh[randi() % fresh.size()]
	return options[randi() % options.size()]


static func _cycle_of(kind: String, a: String) -> int:
	for e in POOLS.get(kind, []):
		if e[0] == a:
			return int(e[1])
	return 99
