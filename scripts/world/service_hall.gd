class_name ServiceHall
extends Node3D
## The long service corridor between the security office and the main lounge (the corridor reference): grey-green
## lockers down both walls, the windows above them on the outside wall boarded over with steel sheets (light leaking
## round their edges), fluorescent fittings across the ceiling all the way along in a green haze, a door now and then,
## and at the far end a pair of steel doors under a clock, a dark figure standing before them. Built far below the
## terminal (ORIGIN) like the jet bridge: the main story joins it to the office's passage door and to the lounge's
## east doors with PortalViews. Local frame: the entrance doorway at the origin, the corridor running along +Z to the
## far doors at LENGTH; the outside wall (windows) on -X, the rooms (doors) on +X.

const ORIGIN := Vector3(-160, -320, 0)
const LENGTH := 46.0
const W := 3.4                # between the wall faces
const H := 3.0                # ceiling
const FAR_W := 1.7            # the far double doors (and the lounge's east doors, built by the same hand)
const FAR_H := 2.3
const LOCKER := Vector3(0.455, 1.85, 0.48)
const LOCKER_STEP := 0.46
const SIDE_DOORS := [8.0, 20.0, 33.0]     # the rooms' doors (z), between locker banks

var zone: LightZone
var entry: Dictionary         # the door you come in by (Terminal.steel_door: {root, leaf, block, use}), open out of it
var far_doors: Dictionary     # double_door: {root, leaf, leaves, block, use}
var far_vestibule: Array[MeshInstance3D] = []   # past the far doors: the story lines them with the lounge's portal
var beyond: Area3D            # just past the far doors
var figure: Node3D
var side_doors: Array[Dictionary] = []


func build() -> void:
	name = "ServiceHall"
	position = ORIGIN
	var wall := Mats.shader_mat("res://shaders/wall_panel.gdshader", {
		"color": Color(0.3, 0.34, 0.31), "seam_color": Color(0.17, 0.19, 0.17), "panel_w": 1.2, "panel_h": 1.25,
		"roughness": 0.62, "base_height": ORIGIN.y, "skirting": 0.1})
	var floor_m := Mats.shader_mat("res://shaders/floor_tile.gdshader", {
		"color_a": Color(0.31, 0.33, 0.31), "color_b": Color(0.28, 0.3, 0.28), "grout_color": Color(0.2, 0.21, 0.2),
		"tile_size": 0.6, "roughness_base": 0.07, "roughness_var": 0.3})
	var ceil_m := Mats.shader_mat("res://shaders/ceiling.gdshader", {"color": Color(0.5, 0.53, 0.5), "grid_color": Color(0.36, 0.38, 0.36)})
	var hw := W * 0.5
	# shell: floor, ceiling, the long walls, the entrance wall (a 1 m doorway) and the far wall (the double doors)
	Geo.box(self, Vector3(0, -0.05, LENGTH * 0.5), Vector3(W + 0.6, 0.1, LENGTH + 0.6), floor_m)
	Geo.box(self, Vector3(0, H + 0.1, LENGTH * 0.5), Vector3(W + 0.6, 0.2, LENGTH + 0.6), ceil_m, false)
	# the outside wall solid, the rooms' wall opened for its three doors; the end walls centred on the door frames
	Geo.box(self, Vector3(-(hw + 0.15), H * 0.5, LENGTH * 0.5), Vector3(0.3, H, LENGTH + 0.6), wall)
	var openings := []
	for z: float in SIDE_DOORS:
		openings.append([z + 0.3 - 0.5, z + 0.3 + 0.5, 2.13])
	Geo.wall(self, Vector2(hw + 0.15, -0.3), Vector2(hw + 0.15, LENGTH + 0.3), H, wall, 0.3, openings)
	for s in [-1.0, 1.0]:
		Geo.box(self, Vector3(s * (0.5 + hw + 0.3) * 0.5, H * 0.5, 0), Vector3(hw + 0.3 - 0.5, H, 0.3), wall)
		Geo.box(self, Vector3(s * (FAR_W * 0.5 + 0.08 + hw + 0.3) * 0.5, H * 0.5, LENGTH), Vector3(hw + 0.3 - FAR_W * 0.5 - 0.08, H, 0.3), wall)
	Geo.box(self, Vector3(0, (2.15 + H) * 0.5, 0), Vector3(1.0, H - 2.15, 0.3), wall)
	Geo.box(self, Vector3(0, (FAR_H + 0.08 + H) * 0.5, LENGTH), Vector3(FAR_W + 0.16, H - FAR_H - 0.08, 0.3), wall)
	_build_entry()
	_build_far_end()
	_build_lockers()
	_build_windows()
	_build_side_doors()
	_build_lights()
	_build_details()
	_build_reverb()


## Inside the corridor (or in the doorways at its ends)?
func contains(p: Vector3) -> bool:
	var l := to_local(p)
	return absf(l.x) < W * 0.5 + 0.3 and l.z > -1.6 and l.z < LENGTH + 3.4 and absf(l.y) < 6.0


## The door frames the story joins with portals, global: +Z = on into the corridor at the entrance, on through the
## far doors at the far end.
func entry_frame() -> Transform3D:
	return global_transform


func far_frame() -> Transform3D:
	return global_transform * Transform3D(Basis(), Vector3(0, 0, LENGTH))


# --------------------------------------------------------------------------------------------
## The way in: the office's own passage door seen from the passage side (Terminal.steel_door), hung open out of the
## corridor into a dark closet behind it (the closet stays out of the portal's view); its leaf only shows once you
## are through (the office's real leaf stands in front of it until then).
func _build_entry() -> void:
	entry = Terminal.steel_door(self, Vector3.ZERO, -PI / 2)
	(entry.leaf as Node3D).rotation.y = deg_to_rad(84.0)
	(entry.leaf as Node3D).visible = false
	(entry.block as StaticBody3D).collision_layer = 0
	(entry.use as Interactable).enabled = false
	var black := Mats.get_mat("black")
	for b: Array in [[Vector3(0, -0.05, -0.95), Vector3(1.6, 0.1, 1.6)], [Vector3(0, 2.3, -0.95), Vector3(1.6, 0.1, 1.6)],
			[Vector3(-0.85, 1.15, -0.95), Vector3(0.1, 2.4, 1.6)], [Vector3(0.85, 1.15, -0.95), Vector3(0.1, 2.4, 1.6)],
			[Vector3(0, 1.15, -1.8), Vector3(1.6, 2.4, 0.1)]]:
		Geo.box(self, b[0], b[1], black, true).layers = Geo.VIS_PORTAL_HIDDEN


## The far end: the double doors under a clock (2:17), the figure before them, a dark vestibule behind them that the
## story lines with the lounge's portal, and the trigger past them.
func _build_far_end() -> void:
	far_doors = double_door(self, Transform3D(Basis(), Vector3(0, 0, LENGTH)))
	var clock := Node3D.new()
	add_child(clock)
	clock.position = Vector3(0, 2.66, LENGTH - 0.18)
	clock.rotation.y = PI
	Geo.cyl(clock, Vector3.ZERO, 0.19, 0.05, Mats.get_mat("plastic_white")).rotation.x = PI / 2
	Geo.cyl(clock, Vector3(0, 0, -0.005), 0.205, 0.04, Mats.get_mat("plastic_dark")).rotation.x = PI / 2
	Geo.label(clock, "2:17", Vector3(0, 0, 0.03), 0.0, 32, Color(0.1, 0.1, 0.1), 0.003, true, "lcd")
	var black := Mats.get_mat("black")
	var vz := LENGTH + 1.75
	far_vestibule.append(Geo.box(self, Vector3(0, -0.04, vz), Vector3(FAR_W + 1.4, 0.1, 3.2), black, false))
	far_vestibule.append(Geo.box(self, Vector3(0, FAR_H + 0.5, vz), Vector3(FAR_W + 1.4, 0.2, 3.2), black, false))
	for sx in [-1.0, 1.0]:
		far_vestibule.append(Geo.box(self, Vector3(sx * (FAR_W * 0.5 + 0.6), FAR_H * 0.5 + 0.25, vz), Vector3(0.2, FAR_H + 0.5, 3.2), black, false))
	far_vestibule.append(Geo.box(self, Vector3(0, FAR_H * 0.5 + 0.25, vz + 1.6), Vector3(FAR_W + 1.4, FAR_H + 0.5, 0.2), black, false))
	Geo.box(self, Vector3(0, -0.05, vz), Vector3(FAR_W + 1.4, 0.1, 3.2), black).visible = false     # floor to stand on
	beyond = Geo.area(self, Vector3(0, 1.0, LENGTH + 1.5), Vector3(FAR_W, 2.0, 1.1))   # clear of the leaves' swing
	# someone standing in front of the doors, facing you: a dark shape in the haze
	figure = Node3D.new()
	figure.name = "Figure"
	add_child(figure)
	figure.position = Vector3(0.3, 0, LENGTH - 2.3)
	var shade := StandardMaterial3D.new()
	shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shade.albedo_color = Color(0.012, 0.016, 0.014)
	var robe := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.16
	cm.bottom_radius = 0.36
	cm.height = 1.5
	cm.radial_segments = 14
	robe.mesh = cm
	robe.material_override = shade
	figure.add_child(robe)
	robe.position = Vector3(0, 0.75, 0)
	var shoulders := Geo.capsule(figure, Vector3(0, 1.42, 0), 0.17, 0.62, shade)
	shoulders.rotation.z = PI / 2
	var head := Geo.sphere(figure, Vector3(0.02, 1.66, 0.04), 0.125, shade)
	head.scale = Vector3(1.0, 1.15, 1.0)
	for c in figure.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The figure goes in a dip of the lights.
func vanish() -> void:
	if not figure.visible:
		return
	zone.trigger_dip(0.35)
	Snd.play_at("flicker_zap", to_global(Vector3(0, H - 0.2, LENGTH - 6.0)), -8.0, 0.8, 10.0)
	await get_tree().create_timer(0.12).timeout
	figure.visible = false


## A pair of steel doors with wired-glass lights and push bars in a frame on the wall plane at `xf` (in `parent`'s
## space); they swing to local +Z (swing). Returns {root, leaf, leaves, block, use}; the use is "문 열기" with no
## callback. The lounge's east doors are the same pair.
static func double_door(parent: Node3D, xf: Transform3D) -> Dictionary:
	var root := Node3D.new()
	parent.add_child(root)
	root.transform = xf
	var frame := Mats.std(Color(0.3, 0.32, 0.35), 0.4, 0.6)
	var steel := Mats.std(Color(0.4, 0.43, 0.46), 0.5, 0.45)
	var wired := Mats.std(Color(0.05, 0.06, 0.07), 0.15, 0.3)
	var metal := Mats.get_mat("metal")
	var hw := FAR_W * 0.5
	for sx in [-1.0, 1.0]:
		Geo.box(root, Vector3(sx * (hw + 0.04), FAR_H * 0.5, 0), Vector3(0.08, FAR_H, 0.34), frame, false)
	Geo.box(root, Vector3(0, FAR_H + 0.04, 0), Vector3(FAR_W + 0.16, 0.08, 0.34), frame, false)
	var leaves: Array[Node3D] = []
	for sx in [-1.0, 1.0]:
		var hinge := Node3D.new()
		root.add_child(hinge)
		hinge.position = Vector3(sx * hw, 0, 0)
		var lw := hw - 0.008
		var cx: float = -sx * lw * 0.5                # the leaf runs from its hinge to the middle
		Geo.box(hinge, Vector3(cx, FAR_H * 0.5, 0), Vector3(lw, FAR_H - 0.03, 0.05), steel, false)
		Geo.box(hinge, Vector3(cx, 1.6, 0), Vector3(0.24, 0.62, 0.056), wired, false)
		for sz in [-1.0, 1.0]:
			Geo.box(hinge, Vector3(cx, 1.0, sz * 0.055), Vector3(lw * 0.78, 0.045, 0.045), metal, false)
		Geo.box(hinge, Vector3(cx, 0.12, 0), Vector3(lw - 0.02, 0.2, 0.056), metal, false)    # kick plates
		leaves.append(hinge)
	var block := Geo.blocker(root, Vector3(0, FAR_H * 0.5, 0), Vector3(FAR_W, FAR_H, 0.3))
	var use := Interactable.create(root, Vector3(0, 1.1, 0), Vector3(FAR_W, 2.1, 0.5), "문 열기", Callable())
	use.press_sound = ""
	return {"root": root, "leaf": leaves[0], "leaves": leaves, "block": block, "use": use}


## Swings a double_door's leaves to `deg` toward its +Z side (0 = shut) over `time` s; the collider goes once open.
static func swing(door: Dictionary, deg: float, time: float) -> Tween:
	var tw := (door.root as Node3D).create_tween().set_parallel(true)
	var leaves: Array[Node3D] = door.leaves
	for i in leaves.size():
		var sx := -1.0 if i == 0 else 1.0
		tw.tween_property(leaves[i], "rotation:y", sx * deg_to_rad(deg), time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	(door.block as StaticBody3D).collision_layer = 0 if deg > 1.0 else Geo.LAYER_WORLD
	return tw


# --------------------------------------------------------------------------------------------
## Grey-green steel lockers in banks along both walls (one MultiMesh per part: bodies tinted locker by locker, the
## vent slots, the handles), a dark plinth under each bank.
func _build_lockers() -> void:
	var hw := W * 0.5
	# [side (-1 outside wall / +1 rooms), z from, z to]
	var banks := [[-1.0, 1.2, 12.6], [-1.0, 14.2, 29.8], [-1.0, 31.4, 44.6],
		[1.0, 1.2, 7.0], [1.0, 9.0, 19.0], [1.0, 21.0, 32.0], [1.0, 34.0, 44.6]]
	var bodies: Array[Transform3D] = []
	var tints: Array[Color] = []
	var slots: Array[Transform3D] = []
	var handles: Array[Transform3D] = []
	var plinths: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 3318
	for b: Array in banks:
		var s: float = b[0]
		var n := int((b[2] - b[1]) / LOCKER_STEP)
		var face := s * (hw - LOCKER.z)               # the door face (x)
		var cx := s * (hw - LOCKER.z * 0.5)
		var z0: float = b[1] + LOCKER_STEP * 0.5
		plinths.append(Transform3D(Basis.from_scale(Vector3(LOCKER.z, 0.09, n * LOCKER_STEP)), Vector3(cx, 0.045, b[1] + n * LOCKER_STEP * 0.5)))
		Geo.blocker(self, Vector3(cx, 0.95, b[1] + n * LOCKER_STEP * 0.5), Vector3(LOCKER.z, 1.9, n * LOCKER_STEP))
		for i in n:
			var z := z0 + i * LOCKER_STEP
			var lean := rng.randf_range(-0.004, 0.004)
			bodies.append(Transform3D(Basis(Vector3.UP, lean).scaled(LOCKER), Vector3(cx, 0.09 + LOCKER.y * 0.5, z)))
			var g := rng.randf_range(0.9, 1.08)
			tints.append(Color(0.22 * g, 0.27 * g, 0.24 * g) if rng.randf() > 0.06 else Color(0.2, 0.22, 0.25))
			for y in [1.68, 1.6, 0.36, 0.28]:
				slots.append(Transform3D(Basis.from_scale(Vector3(0.006, 0.022, 0.26)), Vector3(face - s * 0.003, y, z)))
			handles.append(Transform3D(Basis.from_scale(Vector3(0.03, 0.12, 0.03)), Vector3(face - s * 0.015, 1.05, z + 0.16)))
	var cube := BoxMesh.new()
	var body_m := Mats.std(Color.WHITE, 0.42, 0.4)
	body_m.vertex_color_use_as_albedo = true
	_multi(cube, body_m, bodies, tints)
	_multi(cube, Mats.std(Color(0.05, 0.055, 0.05), 0.6), slots)
	_multi(cube, Mats.get_mat("metal"), handles)
	_multi(cube, Mats.std(Color(0.1, 0.11, 0.1), 0.7), plinths)


## The outside wall's windows above the lockers, boarded over with steel sheets bolted to the frame: light leaks in
## round the edges they do not meet, one sheet hangs askew. Nothing of outside shows.
func _build_windows() -> void:
	var hw := W * 0.5
	var sheet := Mats.std(Color(0.2, 0.21, 0.22), 0.55, 0.65)
	var rust := Mats.std(Color(0.28, 0.2, 0.14), 0.8, 0.3)
	var frame := Mats.std(Color(0.16, 0.17, 0.17), 0.5, 0.4)
	var leak := Mats.emissive(Color(0.72, 0.84, 1.0), 5.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 911
	var x := -hw
	for i in 7:
		var z := 4.0 + i * 6.0
		var c := Vector3(x + 0.025, 2.38, z)
		Geo.box(self, c + Vector3(-0.012, 0, 0), Vector3(0.03, 0.98, 1.62), frame, false)             # the old frame
		var plate := Geo.box(self, c + Vector3(0.02, 0, 0), Vector3(0.012, 0.9, 1.54), rust if i == 4 else sheet, false)
		if i == 2:
			plate.rotation.x = 0.035                  # askew: a wider wedge of light down one side
		for k in 2:
			Geo.box(self, c + Vector3(0.03, -0.18 + k * 0.36, 0), Vector3(0.02, 0.05, 1.5), sheet, false)   # stiffeners
		for cz in [-0.68, 0.68]:
			for cy in [-0.36, 0.36]:
				Geo.box(self, c + Vector3(0.03, cy, cz), Vector3(0.02, 0.03, 0.03), Mats.get_mat("metal"), false)
		# light where the sheet does not meet the frame: along the top, down one side
		var top := Geo.box(self, c + Vector3(0.006, 0.462, rng.randf_range(-0.2, 0.2)), Vector3(0.004, 0.012, rng.randf_range(0.6, 1.4)), leak, false)
		top.name = "Leak"
		var side_z := 0.785 if rng.randf() < 0.5 else -0.785
		Geo.box(self, c + Vector3(0.006, rng.randf_range(-0.15, 0.15), side_z), Vector3(0.004, rng.randf_range(0.3, 0.8), 0.014 if i != 2 else 0.04), leak, false)


## The doors on the rooms' side, all locked (they rattle): a store, the plant room, the staff room.
func _build_side_doors() -> void:
	var names := ["창고  STORAGE", "기계실  PLANT ROOM", "직원 휴게실  STAFF ROOM"]
	for i in SIDE_DOORS.size():
		var door := OfficeKit.door(self, Vector3(W * 0.5 + 0.15, 0, SIDE_DOORS[i]), PI, names[i])
		(door.use as Interactable).callback = func(): Terminal.current.rattle(door)
		side_doors.append(door)
		Geo.box(self, Vector3(W * 0.5 + 0.9, 1.1, SIDE_DOORS[i]), Vector3(1.0, 2.2, 1.4), Mats.get_mat("black"), false)   # dark beyond


## Fluorescent fittings across the ceiling every 3.6 m, cold green; two dead, the zone flickers now and then.
func _build_lights() -> void:
	zone = LightZone.new()
	zone.name = "Zone_servicehall"
	add_child(zone)
	zone.setup("servicehall", "관리동 복도", Color(0.74, 1.0, 0.8), 3.0)
	var i := 0
	var z := 2.0
	while z < LENGTH:
		var dead := i == 5 or i == 9
		if dead:
			Geo.box(zone, Vector3(0, H - 0.03, z), Vector3(1.6, 0.06, 0.16), Mats.std(Color(0.3, 0.32, 0.3), 0.5), false)
		else:
			zone.add_panel(Vector3(0, H - 0.04, z), Vector2(1.6, 0.14), true, 0.85, 7.0, Color(0.72, 1.0, 0.8))
		i += 1
		z += 3.6
	zone.add_hum(Vector3(0, H - 0.3, 8.0), -22.0)
	zone.add_hum(Vector3(0, H - 0.3, 30.0), -22.0)
	zone.erratic = 0.12
	zone.night_dim = 0.85
	# the haze the light hangs in
	var fog := FogVolume.new()
	fog.size = Vector3(W, H, LENGTH)
	var fm := FogMaterial.new()
	fm.density = 0.09
	fm.albedo = Color(0.5, 0.7, 0.56)
	fm.edge_fade = 0.15
	fog.material = fm
	add_child(fog)
	fog.position = Vector3(0, H * 0.5, LENGTH * 0.5)


## A conduit and a cable tray along the rooms' side, puddles on the floor, a fire hose cabinet in the locker gap.
func _build_details() -> void:
	var hw := W * 0.5
	var conduit := Geo.cyl(self, Vector3(hw - 0.12, H - 0.22, LENGTH * 0.5), 0.04, LENGTH, Mats.get_mat("steel_frame"))
	conduit.rotation.x = PI / 2
	Geo.box(self, Vector3(hw - 0.2, H - 0.1, LENGTH * 0.5), Vector3(0.3, 0.04, LENGTH), Mats.get_mat("metal_dark"), false)
	var wet := Mats.std(Color(0.2, 0.22, 0.2), 0.0, 0.0)
	wet.metallic_specular = 0.9
	wet.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet.albedo_color.a = 0.55
	for p: Array in [[Vector3(0.3, 0.002, 6.0), Vector2(1.2, 0.8)], [Vector3(-0.5, 0.002, 17.5), Vector2(0.9, 1.6)],
			[Vector3(0.6, 0.002, 26.0), Vector2(1.4, 0.7)], [Vector3(-0.2, 0.002, 39.0), Vector2(1.0, 1.9)]]:
		var q := QuadMesh.new()
		q.size = p[1]
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = wet
		add_child(mi)
		mi.position = p[0]
		mi.rotation.x = -PI / 2
	# the floor you are on, by the way in
	LevelKit.wall_sign(self, Vector3(hw - 0.01, 2.35, 2.6), -90.0, "2F  관리동\nADMIN WING", Vector2(1.1, 0.42))
	var cab := Node3D.new()
	add_child(cab)
	cab.position = Vector3(-hw + 0.12, 1.25, 13.4)
	cab.rotation.y = PI / 2
	Geo.box(cab, Vector3.ZERO, Vector3(0.7, 0.9, 0.22), Mats.std(Color(0.55, 0.08, 0.06), 0.45, 0.2), false)
	Geo.box(cab, Vector3(0, 0, 0.112), Vector3(0.6, 0.8, 0.004), Mats.std(Color(0.1, 0.1, 0.1), 0.1), false)
	Geo.fit(Geo.label(cab, "소화전", Vector3(0, 0.28, 0.116), 0.0, 40, Color(0.95, 0.9, 0.85), 0.004, false, "print"), 0.5)


func _build_reverb() -> void:
	var a := Area3D.new()
	a.name = "Reverb_servicehall"
	a.collision_layer = Geo.LAYER_AUDIO
	a.collision_mask = 0
	a.monitoring = false
	a.reverb_bus_enabled = true
	a.reverb_bus_name = "RevLong"
	a.reverb_bus_amount = 0.36
	a.reverb_bus_uniformity = 0.4
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(W, H, LENGTH)
	cs.shape = box
	a.add_child(cs)
	add_child(a)
	a.position = Vector3(0, H * 0.5, LENGTH * 0.5)


func _multi(mesh: Mesh, mat: Material, xforms: Array[Transform3D], colors: Array[Color] = []) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
