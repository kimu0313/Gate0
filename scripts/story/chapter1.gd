class_name Chapter1
extends StoryScript
## The main story picks up where the prologue blacked out: the boarding-bridge connector, FLIGHT 000 — GATE 0 lit
## over an airport door with a chain and a padlock through its pull bars. For now (temporary, as asked): the key lies
## on the floor right in front of the door — pick it up, open the padlock, go through. What lies past it is not built
## yet; walking through ends this build ("TO BE CONTINUED") and goes back to the title.

const KEY_LOCAL := Vector3(0.32, 0.0, -JetBridge.LENGTH + 0.75)   # bridge space, on the floor before the door

var key_node: Node3D
var _key_use: Interactable
var _through := false


func setup() -> void:
	var b := d.bridge
	d.terminal.visible = false
	b.zone.set_on(true, true)
	b.zone.night_dim = 0.7
	b.set_board(JetBridge.BOARD_BOARDING, false)
	d.player.teleport(Transform3D(Basis(), b.to_global(Vector3(0, 0.05, -JetBridge.LENGTH + 11.0))))
	d.player.zone_override = "jetbridge"
	d.player.toggle_flashlight(1)
	d.ui.hud.set_clock_override("--:--")
	d.ui.tablet.lost = true
	d.ui.tablet.lose_signal_now()
	b.door_use.callback = _door
	b.door_use.prompt = "문 열기"
	b.beyond.body_entered.connect(func(body):
		if body == d.player and not b.locked:
			_through = true)
	if not Game.has_item("key_gate") and not Game.flag("gate_unlocked"):
		_place_key()


func run() -> void:
	Snd.set_ambience("amb_night_loop", -20.0, 3.0)
	d.player.controls_enabled = false
	await d.ui.fade_to(0.0, 1.8)
	d.player.controls_enabled = true
	d.ui.hud.show_key_hints(12.0)
	d.objective("앞으로 나아가기", d.bridge.door_front() + Vector3(0, 1.2, 0))
	await d.until(func(): return d.player.global_position.distance_to(d.bridge.door_front()) < 2.4)
	d.objective("문 열기")
	await d.until(func(): return _through)
	d.clear_objective()
	d.cutscene(true)
	await d.ui.fade_to(1.0, 1.4)
	Snd.stop_all_world()
	await d.ui.title_card("TO BE CONTINUED", "다음 이야기는 준비 중입니다.", 2.0, false)
	Game.go_menu()


## A small brass key on the carpet, catching the light.
func _place_key() -> void:
	key_node = Node3D.new()
	key_node.name = "GateKey"
	d.bridge.add_child(key_node)
	key_node.position = KEY_LOCAL
	key_node.rotation.y = 0.7
	var brass := Mats.std(Color(0.78, 0.6, 0.26), 0.3, 0.9)
	var bow := Geo.cyl(key_node, Vector3(-0.035, 0.004, 0), 0.016, 0.004, brass, false, 20)
	Geo.cyl(bow, Vector3(0, 0.0005, 0), 0.007, 0.0045, Mats.get_mat("black"), false, 12)     # the ring's hole
	Geo.box(key_node, Vector3(0.012, 0.004, 0), Vector3(0.06, 0.004, 0.008), brass, false)
	for i in 3:
		Geo.box(key_node, Vector3(0.025 + i * 0.011, 0.004, 0.007), Vector3(0.006, 0.004, 0.008), brass, false)
	var glint := Geo.omni(key_node, Vector3(0, 0.25, 0), Color(1.0, 0.9, 0.7), 0.2, 1.2)
	glint.light_volumetric_fog_energy = 0.0
	_key_use = Interactable.create(key_node, Vector3(0, 0.1, 0), Vector3(0.4, 0.3, 0.4), "열쇠 줍기", _take_key)
	_key_use.press_sound = ""


func _take_key() -> void:
	Snd.play("key_pickup", -4.0)
	Game.add_item("key_gate")
	Events.notify.emit("열쇠를 주웠다.", "good")
	key_node.queue_free()
	key_node = null
	d.bridge.door_use.prompt = "열쇠로 자물쇠 열기"
	d.objective("자물쇠 열기")


func _door() -> void:
	var b := d.bridge
	if not b.locked:
		return
	if not Game.has_item("key_gate"):
		Snd.play_at("door_heavy", b.gate_door.global_position + Vector3(0, 1.0, 0.2), -14.0, 1.6, 4.0)
		Snd.play_at("chain_drop", b.gate_door.global_position + Vector3(0, 1.1, 0.2), -16.0, 1.5, 4.0)
		d.say("……자물쇠로 잠겨 있다.")
		if key_node:
			d.objective("열쇠 찾기", key_node.global_position + Vector3(0, 0.3, 0))
		return
	Game.remove_item("key_gate")
	Game.set_flag("gate_unlocked")
	b.unlock()
	await d.wait(1.6)
	d.objective("문 너머로 나아가기")
