class_name Drawer
extends Node3D
## A drawer in a desk pedestal or a cabinet. Its front sits flush on the carcass face; [E] slides it out, [E] again
## slides it back. Whatever is put under `inside` rides with it (the floor of the drawer, in its own frame).
## Local frame: origin = the middle of the drawer's front on the carcass face, +Z = out of the carcass.

signal toggled(drawer: Drawer)

var is_open := false
var inside: Node3D
var interactable: Interactable
var size: Vector3                # front width, front height, depth into the carcass
var travel := 0.0
var _box: Node3D
var _tw: Tween


static func create(parent: Node3D, pos: Vector3, rot_y: float, sz: Vector3, front: Material, out := 0.0) -> Drawer:
	var d := Drawer.new()
	d.name = "Drawer"
	parent.add_child(d)
	d.position = pos
	d.rotation.y = rot_y
	d.size = sz
	d.travel = out if out > 0.0 else sz.z * 0.8
	d._build(front)
	return d


func _build(front: Material) -> void:
	var w := size.x
	var h := size.y
	var dp := size.z
	# the slot it slides out of: dark, so an open drawer shows a hole behind it
	Geo.box(self, Vector3(0, 0, -0.012), Vector3(w - 0.012, h - 0.012, 0.02), Mats.std(Color(0.03, 0.03, 0.035), 0.95), false)
	_box = Node3D.new()
	add_child(_box)
	var metal := Mats.get_mat("metal")
	var body := Mats.std(Color(0.36, 0.37, 0.38), 0.6, 0.3)
	Geo.box(_box, Vector3(0, 0, 0.01), Vector3(w - 0.006, h - 0.006, 0.02), front, false)
	# a pull across the top of the front, a label holder under it
	Geo.box(_box, Vector3(0, h * 0.5 - minf(0.05, h * 0.25), 0.03), Vector3(minf(0.22, w * 0.5), 0.018, 0.022), metal, false)
	if h > 0.2:
		Geo.box(_box, Vector3(0, h * 0.5 - 0.11, 0.0215), Vector3(0.08, 0.035, 0.003), metal, false)
	# the tray behind the front: floor, sides, back (lower than the front so you see into it)
	var th := h * 0.75
	var by := -h * 0.5 + 0.015
	Geo.box(_box, Vector3(0, by, -dp * 0.5), Vector3(w - 0.04, 0.01, dp - 0.02), body, false)
	for sx in [-1.0, 1.0]:
		Geo.box(_box, Vector3(sx * (w * 0.5 - 0.025), by + th * 0.5, -dp * 0.5), Vector3(0.01, th, dp - 0.02), body, false)
	Geo.box(_box, Vector3(0, by + th * 0.5, -dp + 0.015), Vector3(w - 0.04, th, 0.01), body, false)
	inside = Node3D.new()
	_box.add_child(inside)
	inside.position = Vector3(0, by + 0.005, -dp * 0.5)
	interactable = Interactable.create(_box, Vector3(0, 0, 0.035), Vector3(w, h, 0.07), "서랍 열기", toggle)
	interactable.press_sound = ""


func toggle() -> void:
	is_open = not is_open
	interactable.prompt = "서랍 닫기" if is_open else "서랍 열기"
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_property(_box, "position:z", travel if is_open else 0.0, 0.38 if is_open else 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT if is_open else Tween.EASE_IN)
	Snd.play_at(Snd.variant("drawer_open" if is_open else "drawer_close"), global_position, -6.0, randf_range(0.94, 1.06), 4.0)
	toggled.emit(self)
