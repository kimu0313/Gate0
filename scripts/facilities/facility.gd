class_name Facility
extends Node3D
## Base class for every inspectable airport system.
## State machine: OFF (unpowered) -> IDLE -> RUNNING (normal) -> with `anomaly` set = malfunction / autonomous.

signal changed

var id := ""
var title := ""          # 한국어 표시명
var short_name := ""     # e.g. "B-03"
var zone := ""
var powered := true
var running := false
var anomaly := ""        # active anomaly id, "" = normal
var autonomous := false  # started by itself
var observe_radius := 10.0
var needs_running := true
var focus: Node3D        # point the player should look at when inspecting
var power_cut_by_player := false


func _ready() -> void:
	if focus == null:
		focus = self


func is_observable() -> bool:
	return powered and (running or not needs_running)


func focus_position() -> Vector3:
	return focus.global_position if focus else global_position


## Breaker panel calls this.
func set_powered(on: bool) -> void:
	if powered == on:
		return
	powered = on
	if not on:
		_on_power_lost()
		running = false
	else:
		_on_power_restored()
	changed.emit()
	Events.facility_changed.emit(id)


func start(by_player := true) -> void:
	if not powered:
		Snd.play_at("beep_error", focus_position(), -8.0)
		return
	autonomous = not by_player
	running = true
	_on_start()
	changed.emit()
	Events.facility_changed.emit(id)


func stop() -> void:
	running = false
	_on_stop()
	changed.emit()
	Events.facility_changed.emit(id)


func set_anomaly(anomaly_id: String) -> void:
	if anomaly != "":
		_remove_anomaly(anomaly)
	anomaly = anomaly_id
	if anomaly_id != "":
		_apply_anomaly(anomaly_id)
	changed.emit()


func clear_anomaly() -> void:
	if anomaly == "":
		return
	var old := anomaly
	anomaly = ""
	_remove_anomaly(old)
	changed.emit()


## Emits a world action for the director (who decides if it was right, wrong or lethal).
func act(action: String, target := "") -> void:
	Events.player_action.emit(action, target if target != "" else id)


# --- overridables ------------------------------------------------------------------
func _on_start() -> void:
	pass


func _on_stop() -> void:
	pass


func _on_power_lost() -> void:
	pass


func _on_power_restored() -> void:
	pass


func _apply_anomaly(_anomaly_id: String) -> void:
	pass


func _remove_anomaly(_anomaly_id: String) -> void:
	pass


## Called each frame by the director for the facility under inspection (optional per-type logic).
func describe_state() -> String:
	if not powered:
		return "전원 차단"
	return "가동 중" if running else "대기"
