class_name Task
extends RefCounted
## One work order on the tablet.

var id := ""
var kind := "inspect"      # inspect | goal
var title := ""
var detail := ""
var facility_id := ""
var location := ""         # zone name for the map
var anomaly := ""          # assigned anomaly ("" = normal)
var state := "pending"     # pending | active | responding | done
var progress := 0.0        # observation seconds
var observed := false
var fix_done := false
var result := ""           # correct | missed | false_alarm | cleared | failed | done
var deadline := 0.0        # seconds left while responding
var urgent := false
var optional := false
var reported_as := ""      # normal | anomaly
var locked := ""           # non-empty = reporting blocked with this message
var slot := 0              # inspection number within the shift (1..14), 0 = not an inspection
var group := ""            # orders that started together; the player picks which one to look at first
var target: Node3D         # story goals: the thing to use (an Interactable or Pickup; debug bots go there)
const OBSERVE_TIME := 2.5


func is_open() -> bool:
	return state == "active" or state == "responding"


func status_text() -> String:
	match state:
		"pending":
			return "대기"
		"active":
			return "관찰 완료 — 보고 가능" if observed else "현장 확인 필요"
		"responding":
			return tr("대응 중 (%d초)") % int(ceil(deadline))
		"done":
			match result:
				"correct":
					return "정상 확인"
				"cleared":
					return "이상 해제"
				"missed":
					return "판정 오류"
				"false_alarm":
					return "오판"
				"failed":
					return "대응 실패"
			return "완료"
	return ""
