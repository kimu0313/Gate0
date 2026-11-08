class_name OfficeNpc
extends Node3D
## The facilities manager (관리자), waiting at a desk in the security office to hand the night over to the new hire
## (user: "관리실안 사무실 책상 어딘가에 공항직원 상사가 플레이어에게 인수인계를 해 주기 위해 앉아있어 … 그 npc와는 e키를
## 눌러서 대화 할 수 있어"; his name and lines from the user, 2026-11-05: polite, tired, and evasive about what the night
## is like). Built from primitives like the rest of the office: a man in a navy uniform jacket over a pale blue shirt,
## tie pulled loose, staff card on a lanyard, glasses, slumped back in an office chair with his right hand on the mouse
## and his left on his knee. He breathes, works the mouse, now and then sighs; he looks up at you while he talks, and
## away when he does not know how to put it.
##
## [E] on him: he talks, one line a press (player-paced subtitles, "npc" with his name; no sound — user: "말소리 없애줘");
## the first time through, LINES; after that AGAIN. Once he has gone to rest he lies asleep on the night-duty room's bed
## (create_asleep — user: "관리실 나갔다 들어오면 관리자는 숙직실 침대 위에 누워있게"), and [E] on him only gets a snore
## (SNORE). Local frame: seated he faces -Z (his desk), feet on the floor at y 0; asleep he lies on his back along +X
## (his head that way) on whatever is at y 0.

signal started                    # the first [E] on him: the talk has begun
signal line_said(i: int)          # he has just said LINES[i] (the story hands things over on some: RADIO_LINE)
signal finished                   # the first talk is over (every line of LINES heard)

const NAME := "관리자"
## The handover, the first time you speak to him (the user's lines, as written — rewritten 2026-11-06).
const LINES := [
	"...일찍 오셨네요. 이번에 새로 오신 분 맞죠?",
	"업무 설명부터 드릴게요. 오래 걸리진 않을 겁니다.",
	"업무는 공항 내부를 순회하면서 시설 상태를 확인하는 일입니다. 문제가 없는지 살펴보고, 특이사항이 있으면 보고해 주시면 됩니다.",
	"아, 그리고 근무하시기 전에 알아두셔야 할 게 하나 있는데요.",
	"...",
	"뭐라고 설명해야 할지... 직접 설명하기는 좀 곤란하네요. 어차피 근무하시다 보면 알게 될 겁니다.",
	"지침서에 적힌 내용만 잘 따라주세요.",
	"거기에 있는 사항들은 전부 이유가 있어서 만들어진 겁니다.",
	"굳이 궁금해하실 필요는 없어요. 그냥 적힌 대로 하시면 됩니다.",
	"아, 그리고 근무 중에는 외부 이용객과 마주칠 일이 있을 수도 있습니다.",
	"그런 경우에는 평소처럼 응대하시면 됩니다. 불필요한 이야기는 하지 마시고요.",
	"필요한 물품은 이 방에 있습니다. 챙겨서 근무 하시면 되고요.",
	"무전기는 관리실과 연락할 때 사용하시면 됩니다. 문제가 생기면 우선 연락부터 주세요.",
	"물론... 연락이 항상 되는 건 아니지만요.",
	"...외부 이용객이요?",
	"뭐, 너무 신경 쓰지는 마세요.",
	"그럼 저는 이만 숙직실로 쉬러 가보겠습니다. 준비되시면 근무 시작하세요.",
]
## The lines he looks away on (he does not know how to put it).
const LOOK_AWAY := [4, 5, 13, 14]
## The line he hands you the radio on (user: "이 대사 할때는 플레이어가 무전기를 얻었다는 표시가").
const RADIO_LINE := 12
## Afterwards, while he is still at his desk.
const AGAIN := [
	"준비되시면 근무 시작하세요.",
]
## Asleep on the night-duty room's bed (user: "누워있는 관리자에게 말 걸면 그냥 ...드르렁 이런 대사로").
const SNORE := [
	"...드르렁",
	"...드르렁... 쿠울...",
	"...음... 드르렁",
]
const SKIN := Color(0.78, 0.6, 0.48)

var talked := false               # LINES heard to the end
var asleep := false               # lying on the night-duty room's bed (create_asleep)
var hud: Hud                      # (set by the story) to clear his line when he stops
var talking := false
var use: Interactable
var _line := -1
var _again := 0
var _look := 0.0                  # 0 the screen .. 1 you (eased)
var _look_want := 0.0
var _t := 0.0
var _sigh_at := 6.0
var _head: Node3D
var _upper: Node3D
var _hand_r: Node3D
var _hand_r_base := Vector3.ZERO
signal arrived                    # (standing) at the end of run_path
var standing := false             # on his feet (create_standing): runs, stops, talks
var lines_custom: Array = []      # (standing) what he says, one a press (say_lines)
var _body: Node3D                 # (standing) everything above the floor: it bobs as he runs
var _legs: Array = []             # (standing) [hip, knee] left, right
var _arms: Array = []             # (standing) [shoulder, elbow] left, right
var _path: Array[Vector3] = []    # (standing) where he is running to, in his parent's space
var _speed := 0.0
var _phase := 0.0
var _run := 0.0                   # 0 standing .. 1 running (eased)
var _hold := 0.0                  # (standing) 0 arm down .. 1 holding something out to you (eased)
var _hold_want := 0.0
var _held: Node3D                 # (standing) what he holds out (hold)


static func create(parent: Node3D, pos: Vector3, rot_y: float) -> OfficeNpc:
	var n := OfficeNpc.new()
	n.name = "OfficeNpc"
	parent.add_child(n)
	n.position = pos
	n.rotation.y = rot_y
	n._build()
	return n


## Him asleep, on his back along local +X (his head that way), on a surface at local y 0 (`pos` in `parent`).
static func create_asleep(parent: Node3D, pos: Vector3, rot_y: float) -> OfficeNpc:
	var n := OfficeNpc.new()
	n.name = "OfficeNpcAsleep"
	n.asleep = true
	n.talked = true
	parent.add_child(n)
	n.position = pos
	n.rotation.y = rot_y
	n._build_asleep()
	return n


## Him on his feet (user: "자료실에서 지침서를 얻으면 우측에서 관리자가 뛰어와서 말을 걸어"): standing at `pos` in
## `parent`, facing -Z turned by `rot_y`; run_path() runs him along points (arms pumping, footsteps), arrived when he
## stops; say_lines() makes him talk (the first line at once, then one a press).
static func create_standing(parent: Node3D, pos: Vector3, rot_y: float) -> OfficeNpc:
	var n := OfficeNpc.new()
	n.name = "OfficeNpcStanding"
	n.standing = true
	n.talked = true
	parent.add_child(n)
	n.position = pos
	n.rotation.y = rot_y
	n._build_standing()
	return n


## Runs along `points` (in his parent's space) at `speed`; `arrived` when he is at the last.
func run_path(points: Array, speed := 3.6) -> void:
	_path = []
	for p: Vector3 in points:
		_path.append(p)
	_speed = speed


## (Standing) holds `item` out to you in his right hand (its frame: front +Z toward you, top +Y), until release().
func hold(item: Node3D) -> void:
	release()
	var el: Node3D = _arms[1][1]
	el.add_child(item)
	# in the forearm's frame once the arm is raised: -Y runs out toward you, -Z is up
	item.transform = Transform3D(Basis(Vector3(-1, 0, 0), Vector3(0, 0, -1), Vector3(0, -1, 0)), Vector3(0, -0.34, -0.05))
	_held = item
	_hold_want = 1.0


## (Standing) whatever he held out is gone (handed over); the arm goes down.
func release() -> void:
	if _held:
		_held.queue_free()
		_held = null
	_hold_want = 0.0


## Starts talking: `lines` one a press, the first now.
func say_lines(lines: Array) -> void:
	lines_custom = lines.duplicate()
	_line = -1
	use.enabled = true
	_press()


func _build_standing() -> void:
	var m := _mats()
	_body = Node3D.new()
	add_child(_body)
	var hips := Node3D.new()
	_body.add_child(hips)
	hips.position = Vector3(0, 0.95, 0)
	Geo.box(hips, Vector3(0, 0.0, 0.0), Vector3(0.34, 0.2, 0.22), m.trousers, false)
	for side: float in [-1.0, 1.0]:
		var hip := Node3D.new()
		hips.add_child(hip)
		hip.position = Vector3(side * 0.1, -0.06, 0)
		_limb(hip, Vector3.ZERO, Vector3(0, -0.43, 0), 0.07, m.trousers)
		var knee := Node3D.new()
		hip.add_child(knee)
		knee.position = Vector3(0, -0.43, 0)
		_limb(knee, Vector3.ZERO, Vector3(0, -0.4, 0), 0.058, m.trousers)
		Geo.box(knee, Vector3(0, -0.42, -0.05), Vector3(0.1, 0.08, 0.26), m.shoe, false)
		_legs.append([hip, knee])
	_upper = Node3D.new()
	hips.add_child(_upper)
	_upper.position = Vector3(0, 0.06, 0)
	Geo.box(_upper, Vector3(0, 0.28, 0.0), Vector3(0.38, 0.54, 0.22), m.jacket, false)
	Geo.box(_upper, Vector3(0, 0.34, -0.112), Vector3(0.12, 0.4, 0.012), m.shirt, false)
	var tie := Geo.box(_upper, Vector3(0.015, 0.31, -0.12), Vector3(0.05, 0.34, 0.006), m.tie, false)
	tie.rotation.z = 0.08
	Geo.box(_upper, Vector3(0, 0.53, -0.07), Vector3(0.16, 0.05, 0.1), m.shirt, false)
	Geo.box(_upper, Vector3(-0.06, 0.39, -0.124), Vector3(0.012, 0.28, 0.004), m.lanyard, false)
	Geo.box(_upper, Vector3(-0.06, 0.23, -0.128), Vector3(0.07, 0.1, 0.004), m.card, false)
	for side: float in [-1.0, 1.0]:
		Geo.sphere(_upper, Vector3(side * 0.21, 0.5, 0.0), 0.075, m.jacket)
		var sh := Node3D.new()
		_upper.add_child(sh)
		sh.position = Vector3(side * 0.225, 0.49, 0.0)
		_limb(sh, Vector3.ZERO, Vector3(side * 0.02, -0.29, 0), 0.055, m.jacket)
		var el := Node3D.new()
		sh.add_child(el)
		el.position = Vector3(side * 0.02, -0.29, 0)
		_limb(el, Vector3.ZERO, Vector3(0, -0.27, 0), 0.045, m.jacket)
		Geo.box(el, Vector3(0, -0.31, 0), Vector3(0.06, 0.09, 0.04), m.skin, false)
		_arms.append([sh, el])
	Geo.cyl(_upper, Vector3(0, 0.6, 0.0), 0.055, 0.1, m.skin)
	_head = Node3D.new()
	_upper.add_child(_head)
	_head.position = Vector3(0, 0.63, 0.0)
	_build_head(_head, m, false)
	use = Interactable.create(self, Vector3(0, 1.0, 0), Vector3(0.6, 1.8, 0.5), "대화하기", Callable())
	use.press_sound = ""
	use.callback = _press
	use.enabled = false


## Running along _path (or standing, catching his breath, his head toward you).
func _process_standing(delta: float, player: Node3D) -> void:
	var running := not _path.is_empty()
	if running:
		var target: Vector3 = _path[0]
		var to := target - position
		to.y = 0.0
		var dist := to.length()
		var step := _speed * delta
		if dist <= step:
			position = Vector3(target.x, position.y, target.z)
			_path.pop_front()
			if _path.is_empty():
				arrived.emit()
		else:
			position += to / dist * step
			rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 10.0))
		var before := floori(_phase / PI)
		_phase += delta * _speed * 2.7
		if floori(_phase / PI) != before:
			Snd.play_at(Snd.variant("footstep_tile"), global_position + Vector3(0, 0.05, 0), -3.0, randf_range(0.94, 1.04), 8.0)
	_run = move_toward(_run, 1.0 if running else 0.0, delta * (6.0 if running else 3.0))
	var s := sin(_phase)
	var c := cos(_phase)
	for i in 2:
		var sg := 1.0 if i == 0 else -1.0
		var hip: Node3D = _legs[i][0]
		var knee: Node3D = _legs[i][1]
		hip.rotation.x = sg * s * 0.75 * _run
		knee.rotation.x = -(0.25 + 0.95 * maxf(0.0, sg * c)) * _run
		var sh: Node3D = _arms[i][0]
		var el: Node3D = _arms[i][1]
		sh.rotation.x = -sg * s * 0.6 * _run + 0.04
		el.rotation.x = 1.25 * _run + 0.12
	# the right arm raised, holding something out to you
	_hold = move_toward(_hold, _hold_want, delta * 2.5)
	if _hold > 0.0:
		var e := _hold * _hold * (3.0 - 2.0 * _hold)
		var sh_r: Node3D = _arms[1][0]
		var el_r: Node3D = _arms[1][1]
		sh_r.rotation.x = lerpf(sh_r.rotation.x, 0.95, e)
		sh_r.rotation.z = lerpf(0.0, -0.18, e)
		el_r.rotation.x = lerpf(el_r.rotation.x, 0.55, e)
	_body.position.y = absf(s) * 0.05 * _run
	# leaning into the run; out of breath once he stops
	var breath := (1.0 - _run) * (0.5 + 0.5 * sin(_t * 5.2))
	_upper.rotation.x = -0.2 * _run - 0.05 * breath
	# his head toward you once he has stopped
	var yaw_you := 0.0
	var pitch_you := 0.0
	if player and not running:
		var cam := (player as Player).camera.global_position if player is Player else player.global_position + Vector3(0, 1.6, 0)
		var q := _upper.global_transform.affine_inverse() * cam
		yaw_you = clampf(atan2(-q.x, -q.z), -1.2, 1.2)
		pitch_you = clampf(atan2(q.y - 0.7, Vector2(q.x, q.z).length()), -0.4, 0.4)
	_head.rotation.y = lerp_angle(_head.rotation.y, yaw_you, minf(1.0, delta * 4.0))
	_head.rotation.x = lerpf(_head.rotation.x, pitch_you, minf(1.0, delta * 4.0))


## The clothes and skin he is made of.
static func _mats() -> Dictionary:
	var lens := Mats.std(Color(0.75, 0.82, 0.85, 0.12), 0.05)
	lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return {
		"jacket": Mats.std(Color(0.11, 0.14, 0.22), 0.8), "shirt": Mats.std(Color(0.66, 0.74, 0.84), 0.75),
		"trousers": Mats.std(Color(0.12, 0.13, 0.15), 0.8), "shoe": Mats.std(Color(0.04, 0.04, 0.04), 0.35),
		"skin": Mats.std(SKIN, 0.65), "hair": Mats.std(Color(0.06, 0.05, 0.05), 0.7),
		"dark": Mats.std(Color(0.03, 0.03, 0.03), 0.4), "lens": lens,
		"tie": Mats.std(Color(0.38, 0.08, 0.08), 0.6), "lanyard": Mats.std(Color(0.1, 0.22, 0.6), 0.8),
		"card": Mats.std(Color(0.92, 0.92, 0.9), 0.6), "lip": Mats.std(Color(0.45, 0.28, 0.25), 0.6),
	}


## His head, in its own frame: the crown up +Y, the face toward -Z, the neck at the origin. `shut`: eyes closed and the
## mouth a little open (asleep).
static func _build_head(head: Node3D, m: Dictionary, shut: bool) -> void:
	var face := Geo.sphere(head, Vector3(0, 0.12, -0.01), 0.11, m.skin)
	face.scale = Vector3(0.88, 1.12, 1.0)
	var scalp := Geo.sphere(head, Vector3(0, 0.17, 0.02), 0.112, m.hair)
	scalp.scale = Vector3(0.92, 0.82, 1.02)
	for sx: float in [-1.0, 1.0]:
		Geo.box(head, Vector3(sx * 0.098, 0.12, 0.0), Vector3(0.02, 0.05, 0.035), m.skin, false)        # ears
		# eyes: half shut, or shut (a thin line)
		Geo.box(head, Vector3(sx * 0.036, 0.14, -0.105), Vector3(0.022, 0.004 if shut else 0.009, 0.006), m.dark, false)
		Geo.box(head, Vector3(sx * 0.038, 0.165, -0.103), Vector3(0.034, 0.008, 0.008), m.hair, false)  # brows
		# glasses: a thin black rim round each eye
		Geo.box(head, Vector3(sx * 0.037, 0.14, -0.112), Vector3(0.052, 0.036, 0.004), m.lens, false)
		for ry: float in [-1.0, 1.0]:
			Geo.box(head, Vector3(sx * 0.037, 0.14 + ry * 0.018, -0.113), Vector3(0.054, 0.004, 0.005), m.dark, false)
		for rx: float in [-1.0, 1.0]:
			Geo.box(head, Vector3(sx * 0.037 + rx * 0.026, 0.14, -0.113), Vector3(0.004, 0.036, 0.005), m.dark, false)
		Geo.box(head, Vector3(sx * 0.064, 0.14, -0.075), Vector3(0.004, 0.005, 0.07), m.dark, false)
	Geo.box(head, Vector3(0, 0.12, -0.112), Vector3(0.018, 0.04, 0.016), m.skin, false)                 # nose
	Geo.box(head, Vector3(0, 0.072, -0.1), Vector3(0.04, 0.014 if shut else 0.006, 0.006), m.lip, false)  # mouth


func _build() -> void:
	var m := _mats()
	# legs: thighs out over the seat, shins down, shoes
	for sx: float in [-1.0, 1.0]:
		_limb(self, Vector3(sx * 0.1, 0.5, 0.02), Vector3(sx * 0.12, 0.5, -0.4), 0.075, m.trousers)
		_limb(self, Vector3(sx * 0.12, 0.5, -0.4), Vector3(sx * 0.13, 0.09, -0.44), 0.06, m.trousers)
		Geo.box(self, Vector3(sx * 0.13, 0.04, -0.5), Vector3(0.1, 0.08, 0.26), m.shoe, false)
	Geo.box(self, Vector3(0, 0.5, 0.02), Vector3(0.36, 0.16, 0.3), m.trousers, false)       # seat of the trousers
	# the upper body leans back in the chair, slumped; it turns a little toward you when he has to talk
	_upper = Node3D.new()
	add_child(_upper)
	_upper.position = Vector3(0, 0.55, 0.04)
	_upper.rotation.x = 0.16
	Geo.box(_upper, Vector3(0, 0.27, 0.02), Vector3(0.38, 0.54, 0.22), m.jacket, false)
	Geo.box(_upper, Vector3(0, 0.33, -0.1), Vector3(0.12, 0.4, 0.012), m.shirt, false)          # shirt front between lapels
	var tie := Geo.box(_upper, Vector3(0.015, 0.3, -0.108), Vector3(0.05, 0.34, 0.006), m.tie, false)
	tie.rotation.z = 0.08                                                                     # pulled loose
	Geo.box(_upper, Vector3(0, 0.52, -0.06), Vector3(0.16, 0.05, 0.1), m.shirt, false)          # open collar
	# lanyard and staff card
	Geo.box(_upper, Vector3(-0.06, 0.38, -0.112), Vector3(0.012, 0.28, 0.004), m.lanyard, false)
	Geo.box(_upper, Vector3(-0.06, 0.22, -0.116), Vector3(0.07, 0.1, 0.004), m.card, false)
	# shoulders and arms: right hand on the mouse, left on his knee
	for sx: float in [-1.0, 1.0]:
		Geo.sphere(_upper, Vector3(sx * 0.21, 0.49, 0.02), 0.075, m.jacket)
	_limb(_upper, Vector3(0.22, 0.48, 0.02), Vector3(0.25, 0.22, -0.14), 0.055, m.jacket)
	_limb(_upper, Vector3(0.25, 0.22, -0.14), Vector3(0.22, 0.24, -0.5), 0.045, m.jacket)
	_hand_r = Node3D.new()
	_upper.add_child(_hand_r)
	_hand_r.position = Vector3(0.22, 0.24, -0.52)
	_hand_r_base = _hand_r.position
	Geo.box(_hand_r, Vector3.ZERO, Vector3(0.08, 0.035, 0.1), m.skin, false)
	_limb(_upper, Vector3(-0.22, 0.48, 0.02), Vector3(-0.27, 0.2, -0.08), 0.055, m.jacket)
	_limb(_upper, Vector3(-0.27, 0.2, -0.08), Vector3(-0.15, 0.0, -0.32), 0.045, m.jacket)
	Geo.box(_upper, Vector3(-0.14, -0.01, -0.36), Vector3(0.08, 0.04, 0.1), m.skin, false)
	# neck and head (the head turns from the neck)
	Geo.cyl(_upper, Vector3(0, 0.59, 0.0), 0.055, 0.1, m.skin)
	_head = Node3D.new()
	_upper.add_child(_head)
	_head.position = Vector3(0, 0.62, 0.0)
	_build_head(_head, m, false)
	# he is solid, and [E] on him talks
	Geo.blocker(self, Vector3(0, 0.65, -0.12), Vector3(0.55, 1.3, 0.75))
	use = Interactable.create(self, Vector3(0, 0.9, -0.08), Vector3(0.7, 1.1, 0.7), "대화하기", Callable())
	use.press_sound = ""
	use.callback = _press


## Asleep on his back along +X, his front up: legs straight, feet fallen a little apart, hands folded on his stomach,
## head on the pillow turned a little toward -Z (the room). _upper is his chest (it rises and falls).
func _build_asleep() -> void:
	var m := _mats()
	for sz: float in [-1.0, 1.0]:
		_limb(self, Vector3(-0.05, 0.08, sz * 0.1), Vector3(-0.47, 0.075, sz * 0.115), 0.075, m.trousers)
		_limb(self, Vector3(-0.47, 0.07, sz * 0.115), Vector3(-0.84, 0.062, sz * 0.13), 0.06, m.trousers)
		var shoe := Geo.box(self, Vector3(-0.9, 0.1, sz * 0.14), Vector3(0.08, 0.2, 0.1), m.shoe, false)
		shoe.rotation.x = sz * 0.35                                                            # toes fallen outward
	Geo.box(self, Vector3(0.0, 0.09, 0), Vector3(0.3, 0.18, 0.36), m.trousers, false)        # seat of the trousers
	_upper = Node3D.new()
	add_child(_upper)
	_upper.position = Vector3(0.05, 0.0, 0.0)
	Geo.box(_upper, Vector3(0.27, 0.11, 0), Vector3(0.54, 0.22, 0.38), m.jacket, false)
	Geo.box(_upper, Vector3(0.33, 0.222, 0), Vector3(0.4, 0.012, 0.12), m.shirt, false)          # shirt front
	var tie := Geo.box(_upper, Vector3(0.3, 0.23, 0.015), Vector3(0.34, 0.006, 0.05), m.tie, false)
	tie.rotation.y = 0.08
	Geo.box(_upper, Vector3(0.52, 0.17, 0), Vector3(0.05, 0.1, 0.16), m.shirt, false)            # open collar
	Geo.box(_upper, Vector3(0.38, 0.233, -0.06), Vector3(0.28, 0.004, 0.012), m.lanyard, false)
	var card := Geo.box(_upper, Vector3(0.2, 0.236, -0.075), Vector3(0.1, 0.004, 0.07), m.card, false)
	card.rotation.y = 0.3
	for sz: float in [-1.0, 1.0]:
		Geo.sphere(_upper, Vector3(0.49, 0.11, sz * 0.21), 0.075, m.jacket)
		_limb(_upper, Vector3(0.48, 0.1, sz * 0.22), Vector3(0.22, 0.09, sz * 0.25), 0.055, m.jacket)
		_limb(_upper, Vector3(0.22, 0.09, sz * 0.25), Vector3(0.1, 0.22, sz * 0.07), 0.045, m.jacket)
		Geo.box(_upper, Vector3(0.08, 0.245, sz * 0.045), Vector3(0.1, 0.035, 0.08), m.skin, false)  # hands folded
	# the head is not on the chest, so it stays on the pillow as he breathes
	var neck := Geo.cyl(self, Vector3(0.64, 0.15, 0), 0.055, 0.1, m.skin)
	neck.rotation.z = PI / 2
	_head = Node3D.new()
	add_child(_head)
	_head.position = Vector3(0.65, 0.17, 0)
	# crown along +X, face up (+Y), turned a little toward -Z (the room)
	_head.basis = Basis(Vector3.RIGHT, -0.35) * Basis(Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, -1, 0))
	_build_head(_head, m, true)
	# (the bed under him is already solid; nothing of his may stop the [E] ray)
	use = Interactable.create(self, Vector3(0.0, 0.2, 0), Vector3(1.8, 0.45, 0.6), "대화하기", Callable())
	use.press_sound = ""
	use.callback = _press


## A rounded limb from `a` to `b` (a capsule along the segment).
static func _limb(parent: Node3D, a: Vector3, b: Vector3, r: float, m: Material) -> void:
	var len := a.distance_to(b)
	var c := Geo.capsule(parent, (a + b) * 0.5, r, len + r * 2.0, m)
	var dir := (b - a).normalized()
	var axis := Vector3.UP.cross(dir)
	if axis.length() > 0.0001:
		c.transform.basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))


func _press() -> void:
	if standing:
		# on his feet: the lines he came with (say_lines), one a press; then he has nothing more to say
		_line += 1
		if _line >= lines_custom.size():
			_end_talk()
			use.enabled = false
			finished.emit()
			return
		talking = true
		use.prompt = "계속 듣기"
		_say(lines_custom[_line])
		if _line == 0:
			started.emit()
		line_said.emit(_line)
		return
	if asleep:
		# he does not wake: a snore, and the next press clears it
		if talking:
			_end_talk()
			return
		talking = true
		_say(SNORE[_again % SNORE.size()])
		_again += 1
		return
	if not talked:
		_line += 1
		if _line >= LINES.size():
			_end_talk()
			talked = true
			finished.emit()
			return
		talking = true
		use.prompt = "계속 듣기"
		_say(LINES[_line])
		if _line == 0:
			started.emit()
		line_said.emit(_line)
		# he looks up at you, and away when he does not know how to put it
		_look_want = 0.3 if LOOK_AWAY.has(_line) else 1.0
	else:
		if talking:
			_end_talk()
			return
		talking = true
		use.prompt = "계속 듣기"
		_say(AGAIN[_again % AGAIN.size()])
		_again += 1
		_look_want = 0.8


func _say(line: String) -> void:
	Events.subtitle.emit("npc", NAME + "|" + line, 60.0)
	_sigh_at = _t + 8.0


func _end_talk() -> void:
	talking = false
	use.prompt = "대화하기"
	if hud:
		hud.hide_subtitle()
	_look_want = 0.0


func _process(delta: float) -> void:
	_t += delta
	var player := get_tree().get_first_node_in_group("player") as Node3D
	# after a while without a word he goes back to his screen (or his sleep)
	if talking and player and player.global_position.distance_to(global_position) > 3.2:
		_end_talk()
	if asleep:
		# slow, deep breathing: the chest rises and falls
		var b := 0.5 + 0.5 * sin(_t * 1.15)
		_upper.scale = Vector3(1.0, 1.0 + b * 0.06, 1.0 + b * 0.01)
		return
	if standing:
		_process_standing(delta, player)
		return
	_look = move_toward(_look, _look_want, delta * 1.6)
	# the head toward you (in his own frame), from the screen ahead
	var yaw_screen := 0.0
	var yaw_you := 0.0
	var pitch_you := 0.0
	if player:
		var cam := (player as Player).camera.global_position if player is Player else player.global_position + Vector3(0, 1.6, 0)
		var q := _upper.global_transform.affine_inverse() * cam
		yaw_you = clampf(atan2(-q.x, -q.z), -1.3, 1.3)
		pitch_you = clampf(atan2(q.y - 0.75, Vector2(q.x, q.z).length()), -0.4, 0.4)
	_head.rotation.y = lerpf(yaw_screen, yaw_you, _look)
	_head.rotation.x = lerpf(-0.12, pitch_you, _look)
	# the upper body follows a little when he has to talk to you
	_upper.rotation.y = lerpf(0.0, yaw_you * 0.25, _look)
	# breathing, the mouse, a sigh now and then
	_upper.position.y = 0.55 + sin(_t * 1.6) * 0.004
	if _look < 0.3:
		_hand_r.position = _hand_r_base + Vector3(sin(_t * 2.3) * 0.006 + sin(_t * 0.7) * 0.01, 0, cos(_t * 1.9) * 0.008)
	if _t > _sigh_at:
		_sigh_at = _t + randf_range(9.0, 16.0)
		var tw := create_tween()
		tw.tween_property(_upper, "rotation:x", 0.24, 0.8).set_trans(Tween.TRANS_SINE)
		tw.tween_property(_upper, "rotation:x", 0.16, 1.4).set_trans(Tween.TRANS_SINE)
