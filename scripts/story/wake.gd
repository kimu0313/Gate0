class_name Wake
extends StoryScript
## After the prologue (user, 2026-11-08: "계속하기 누르면 플레이어가 엘리베이터에서 눈을 뜨고 일어나는거지. 엘리베이터는
## 여전히 빨간 불빛이고 안개가 있어. 엘베 문이 바로 열리는데 복도가 녹색빛 빛만 은은하게 나면서 불 꺼진 복도야. 안개가
## 엄청 쌓여있고."): you come round on the floor of the stopped lift — its light still red, haze in the car — and as you
## open your eyes its doors grind open by themselves onto the corridors (ServiceHall, the 4F landing the car stands
## behind) with every light out, only a faint green glow in the air and thick fog lying low over the floor. You get up
## (a knee, then your feet) and the corridors are yours to walk; nothing more happens yet.
##
## What you carry comes from the save (Game.finish_shift1 keeps it). The lift is dead (no power: its buttons only
## beep) and stays open; the office's door is shut and locked from the corridor.

const GREEN := Color(0.34, 0.92, 0.56)
const GLOW_ENERGY := 0.32
const GLOW_RANGE := 6.5
const GLOW_FOG := 3.2               # how much of it shows in the fog
const FOG := 0.6                    # the fog lying on the floor (density at the floor; thinning upward)
const FOG_FALLOFF := 1.0
const FOG_GLOW := Color(0.09, 0.22, 0.14)
const CAR_GAIN := 0.55              # the car's red light, dimmer than in the breakdown

var hall: ServiceHall
var awake := false                  # up on your feet, the controls yours
var doors_open := false


func setup() -> void:
	var t := d.terminal
	hall = t.service_hall
	for zn in t.zones:
		t.set_zone_light(zn, false, true)
	hall.zone.set_on(false, true)
	_dark_corridors()
	# what you carry (from the save; started with nothing — `--chapter wake`, or no save — the prologue's kit)
	if Game.inventory.is_empty():
		for id: String in ["radio", "flashlight", "guide", "camera"]:
			Game.add_item(id)
	var p := d.player
	p.flashlight_owned = Game.has_item("flashlight")
	p.camera_owned = Game.has_item("camera")
	if p.flashlight_on:
		p.toggle_flashlight(0)
	d.ui.hud.set_flashlight_hint(p.flashlight_owned)
	d.tab_opens = "guide" if Game.has_item("guide") else "none"
	d.ui.hud.hide_key_hints()
	# the office's door: shut, and locked now
	var e: Dictionary = hall.entry
	(e.leaf as Node3D).visible = true
	(e.leaf as Node3D).rotation.y = 0.0
	(e.block as StaticBody3D).collision_layer = Geo.LAYER_WORLD
	var use := e.use as Interactable
	use.enabled = true
	use.prompt = "문 열기"
	use.callback = func(): t.rattle(e)
	# the lift: stuck at 4F with no power, its light still red, haze in the car
	var lift := t.lift
	lift.set_powered(false)
	lift.car_light(Shift1.RED, CAR_GAIN)
	var c0: Dictionary = lift.cars[0]
	for l: OmniLight3D in c0.lights:
		l.light_volumetric_fog_energy = 1.4              # (its red shows in the haze, and spills out of the doors)
	for fog: FogVolume in (c0.root as Node).find_children("*", "FogVolume", true, false):
		var fm := FogMaterial.new()
		fm.density = 0.09
		fm.albedo = Color(0.62, 0.6, 0.6)
		fm.edge_fade = 0.15
		fog.material = fm
	# you, lying on the car's floor facing the doors, eyes shut
	var root: Node3D = c0.root
	p.teleport(Transform3D(root.global_basis * Basis(Vector3.UP, PI), root.global_transform * Vector3(0.3, 0.05, -1.3)))
	p.controls_enabled = false
	p.view_drop = 1.15
	p.view_roll = 0.55
	p.eyes_script = 1.0
	p.no_sprint = false                                  # (you can run in the corridors — user)
	d.ui.hud.visible = false
	d.ui.cut_to(1.0)


func run() -> void:
	var p := d.player
	Snd.set_ambience("amb_night_loop", -26.0, 4.0)
	await d.wait(1.5)
	d.ui.fade_to(0.0, 2.4)
	# the eyes flutter open; the head lifts off the floor a little
	var lids := create_tween()
	for step: Array in [[0.7, 0.7], [1.0, 0.45], [0.45, 0.9], [0.85, 0.4], [0.25, 0.9], [0.55, 0.3], [0.0, 0.8]]:
		lids.tween_property(p, "eyes_script", step[0], step[1]).set_trans(Tween.TRANS_SINE)
	create_tween().tween_property(p, "view_drop", 1.0, 3.0).set_trans(Tween.TRANS_SINE)
	await lids.finished
	# the doors grind open by themselves
	_open_doors()
	await d.wait(0.9)
	# up: a knee, then the feet
	var up := create_tween()
	up.tween_property(p, "view_drop", 0.6, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	up.parallel().tween_property(p, "view_roll", 0.18, 1.0)
	up.tween_interval(0.35)
	up.tween_property(p, "view_drop", 0.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	up.parallel().tween_property(p, "view_roll", 0.0, 1.2)
	await up.finished
	p.eyes_script = -1.0
	p.controls_enabled = true
	d.ui.hud.visible = true
	awake = true


func _open_doors() -> void:
	var lift := d.terminal.lift
	var land: Node3D = lift.cars[0].land
	Snd.play_at("amb_creak_1", land.global_transform * Vector3(0, 1.4, 0), -6.0, 0.7, 5.0)
	lift.busy = true                                    # (it stays open: no idle close, no calls)
	await lift._doors(0, true)
	doors_open = true


## Every light out in the corridors; a faint green glow hanging in the air where the battens are (no fixture shows
## it: only the fog and the walls catch it), and thick fog lying on the floor, thinning upward.
func _dark_corridors() -> void:
	var mask := 0xFFFFF & ~(Geo.VIS_SEALED | Terminal.VIS_OFFICE)
	for f: Array in ServiceHall.FITTINGS:
		var l := Geo.omni(hall, Vector3(f[0], ServiceHall.H - 0.5, f[1]), GREEN, GLOW_ENERGY, GLOW_RANGE)
		l.light_volumetric_fog_energy = GLOW_FOG
		l.light_specular = 0.15
		l.light_cull_mask = mask
	var fm := FogMaterial.new()
	fm.density = FOG
	fm.height_falloff = FOG_FALLOFF
	fm.albedo = Color(0.55, 0.66, 0.6)
	fm.emission = FOG_GLOW                               # (lit from the ceiling only it read as plain dark: it glows a little)
	fm.edge_fade = 0.25
	for r: Rect2 in ServiceHall.HALLS.values():
		var fog := FogVolume.new()
		fog.size = Vector3(r.size.x, ServiceHall.H * 2.0, r.size.y)
		fog.material = fm
		hall.add_child(fog)
		fog.position = Vector3(r.get_center().x, 0.0, r.get_center().y)   # (centred on the floor: densest there)
