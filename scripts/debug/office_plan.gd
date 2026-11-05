extends Node
## Debug: `godot --path . res://scenes/game.tscn -- --skip-boot --office-plan <png>` (windowed) = a labelled top-down
## plan of the security office with the service corridors' maze drawn round it where it belongs (ServiceHall is built
## far below the terminal at ORIGIN; for the picture it is lifted into place). Nothing else is drawn; everything from
## CUT up (door heads, ceilings, fittings) drops out so doorways read open. Labels: white = the office, orange = the way
## through (1 to 5), tan = locked doors by their plates, blue = the big windows, red = the ball's doors and the figure,
## green = the start and the way out. Saves <png> and quits.

var world: Node3D

const RECT := Rect2(-39.5, -33.0, 31.5, 31.5)   # x, z (north at the top of the picture)
const PX_PER_M := 56.0
const CUT := 2.0
const ROUTE := Color(1.0, 0.62, 0.2)
const DOOR := Color(0.93, 0.8, 0.6)
const WINDOW := Color(0.45, 0.78, 1.0)
const BEAT := Color(1.0, 0.36, 0.32)
const GO := Color(0.45, 1.0, 0.55)

var _marks: Node3D
var _font: Font
var _line_m: StandardMaterial3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	var out: String = args[args.find("--office-plan") + 1]
	await get_tree().create_timer(1.5).timeout
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(n as CanvasLayer).visible = false
	var t: Terminal = world.terminal
	var hall := t.service_hall
	hall.position = Vector3(0, -0.03, 0)          # round the office (its floor just under the office's)
	var keep: Array[Node] = [t.sec_root, hall]
	for n in get_tree().root.find_children("*", "GeometryInstance3D", true, false):
		var g := n as GeometryInstance3D
		if not keep.any(func(k: Node): return k == g or k.is_ancestor_of(g)) or (g.layers & Geo.VIS_PORTAL_HIDDEN) != 0:
			g.visible = false
		elif (g.global_transform * g.get_aabb()).position.y > CUT:
			g.visible = false
	for n in get_tree().root.find_children("*", "FogVolume", true, false):
		(n as Node3D).visible = false
	for n in get_tree().root.find_children("*", "VisualInstance3D", true, false):
		if n is ReflectionProbe or n is Decal or n is VoxelGI or n is LightmapGI:
			(n as VisualInstance3D).visible = false     # the shiny floors' reflections came out as white haze
	for n in get_tree().root.find_children("*", "Light3D", true, false):
		(n as Light3D).visible = false
		(n as Light3D).light_cull_mask = 0
	_marks = Node3D.new()
	_marks.name = "PlanMarks"
	world.add_child(_marks)
	_font = Geo.korean_font(700, true)
	_line_m = StandardMaterial3D.new()
	_line_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_m.no_depth_test = true
	_line_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line_m.vertex_color_use_as_albedo = true
	_line_m.render_priority = 1
	var sun := DirectionalLight3D.new()
	_marks.add_child(sun)
	sun.rotation = Vector3(-PI / 2 + 0.16, 0.7, 0)
	sun.light_energy = 0.8
	sun.light_specular = 0.0          # the polished floors threw cloudy highlights straight up into the camera
	sun.shadow_enabled = true
	_draw(hall)

	var vp := SubViewport.new()
	vp.size = Vector2i(int(RECT.size.x * PX_PER_M), int(RECT.size.y * PX_PER_M))
	vp.msaa_3d = Viewport.MSAA_4X
	vp.world_3d = world.get_world_3d()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = RECT.size.y
	cam.near = 0.5
	cam.far = 60.0
	cam.position = Vector3(RECT.get_center().x, CUT + 30.0, RECT.get_center().y)
	cam.rotation = Vector3(-PI / 2, 0, 0)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.105, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	cam.environment = env
	cam.attributes = CameraAttributesPractical.new()
	cam.current = true
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	print("office plan: ", out)
	get_tree().quit()


func _draw(hall: ServiceHall) -> void:
	# the office
	_tag("보안실", -15.6, -17.4, 0.6)
	_tag("▲ 시작", Prologue.START.x, Prologue.START.z + 0.15, 0.36, GO)
	_tag("CCTV 관제실", Terminal.SEC_CCTV.get_center().x, Terminal.SEC_CCTV.get_center().y - 0.6, 0.36)
	_tag("접수 카운터", Terminal.SEC_CCTV.position.x - 1.5, -22.3, 0.3)
	_tag("보안실 북쪽", -23.5, -30.75, 0.36)
	_tag("◀ 키 카드 문", Terminal.SEC_LEG.position.x + 0.3, Terminal.SEC_ENTRY_Z, 0.27, GO, false, HORIZONTAL_ALIGNMENT_LEFT)
	_tag("숙직실 문 ▼", Terminal.SEC_DORM_X, -15.45, 0.24, DOOR)
	for z: float in Terminal.SEC_VIEW_W:
		var wx := Terminal.SEC_LEG.position.x
		_bar(Vector3(wx, 0, z - Terminal.SEC_VIEW_SIZE.x * 0.5), Vector3(wx, 0, z + Terminal.SEC_VIEW_SIZE.x * 0.5), 0.16, WINDOW)
		_tag("큰 창", wx + 0.85, z, 0.26, WINDOW)
	for x: float in Terminal.SEC_VIEW_N:
		var wz := Terminal.SEC_LEG.position.y
		_bar(Vector3(x - Terminal.SEC_VIEW_SIZE.x * 0.5, 0, wz), Vector3(x + Terminal.SEC_VIEW_SIZE.x * 0.5, 0, wz), 0.16, WINDOW)
		_tag("큰 창", x, wz - 0.7, 0.26, WINDOW)
	# the way through: out of the west door (the key card door), W, N, V to the lift (or north up V to the stairs)
	var way := [Prologue.START, Vector3(-22.4, 0, Terminal.SEC_ENTRY_Z), Vector3(-23.65, 0, Terminal.SEC_ENTRY_Z),
		Vector3(-23.65, 0, -24.75), Vector3(-36.1, 0, -24.75), Vector3(-36.1, 0, -6.0)]
	for i in way.size() - 1:
		_bar(way[i], way[i + 1], 0.07, Color(ROUTE, 0.55))
	_tag("E", -11.15, -14.3, 0.36, ROUTE, true)
	_tag("S", -14.5, -11.75, 0.36, ROUTE)
	_tag("① W", -23.65, -13.4, 0.36, ROUTE, true)
	_tag("② N", -29.0, -24.75, 0.36, ROUTE)
	_tag("③ V", -36.1, -13.5, 0.36, ROUTE, true)
	_tag("S2", -19.8, -9.4, 0.3, ROUTE, true)
	_tag("B", -26.0, -19.4, 0.3, ROUTE)
	_tag("B2", -31.6, -17.3, 0.3, ROUTE, true)
	_tag("막힘", -11.15, -20.6, 0.24)
	_tag("비상계단 ▲ (4F→1F)", -36.1, -28.6, 0.24, GO)
	_tag("막힘", -19.8, -5.4, 0.24)
	_tag("가짜 EXIT · 막힘", -31.6, -13.3, 0.22, BEAT)
	_tag("엘리베이터 ▼ 1층 라운지", ServiceHall.FAR.x, -5.25, 0.3, GO)
	_tag("숙직실", -20.5, -13.95, 0.28)
	# the locked doors, by their plates, just off the wall on the corridor's side
	for plate: String in hall.doors_by:
		if plate == "보안실":
			continue
		var root := hall.doors_by[plate].root as Node3D
		var rot := root.rotation.y
		var into := Basis(Vector3.UP, rot) * Vector3(1, 0, 0)
		var at := Vector3(root.position.x, 0, root.position.z) + into * 0.45
		var hot := false
		_tag(plate, at.x, at.z, 0.24, BEAT if hot else DOOR, absf(cos(rot)) > 0.5)
	# legend, scale and north
	var lx := -34.3
	var lines := [
		["보안실 + 관리동 복도 · 탑뷰", Color.WHITE, 0.42],
		["주황 선 = 지나가는 길 ①→⑤", ROUTE, 0.3],
		["갈색 = 잠긴 문 (명판 이름)", DOOR, 0.3],
		["하늘색 = 큰 창 (안팎에서 서로 보임)", WINDOW, 0.3],
		["초록 = 시작 · 키 카드 문 · 출구", GO, 0.3],
	]
	for i in lines.size():
		_tag(lines[i][0], lx, -9.6 + i * 0.62, lines[i][2], lines[i][1], false, HORIZONTAL_ALIGNMENT_LEFT)
	_bar(Vector3(lx, 0, -3.2), Vector3(lx + 5.0, 0, -3.2), 0.1, Color.WHITE)
	for k in 6:
		_bar(Vector3(lx + k, 0, -3.35), Vector3(lx + k, 0, -3.05), 0.05, Color.WHITE)
	_tag("5 m", lx + 5.4, -3.2, 0.3, Color.WHITE, false, HORIZONTAL_ALIGNMENT_LEFT)
	_tag("▲ 북", -24.0, -3.2, 0.36)


## A flat label lying on the plan, reading from the south (or, `vertical`, from the east: along a north-south corridor).
func _tag(text: String, x: float, z: float, size: float, color := Color.WHITE, vertical := false,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var holder := Node3D.new()
	_marks.add_child(holder)
	holder.position = Vector3(x, CUT + 0.6, z)
	holder.rotation.y = PI / 2 if vertical else 0.0
	var l := Label3D.new()
	holder.add_child(l)
	l.text = text
	l.font = _font
	l.font_size = 96
	l.pixel_size = size / 96.0
	l.modulate = color
	l.outline_size = 22
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.horizontal_alignment = align
	l.no_depth_test = true
	l.shaded = false
	l.double_sided = true
	l.render_priority = 10
	l.outline_render_priority = 9
	l.rotation = Vector3(-PI / 2, 0, 0)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


## A flat bar from a to b (on the plan), `w` wide.
func _bar(a: Vector3, b: Vector3, w: float, color: Color) -> void:
	var d := b - a
	d.y = 0.0
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(d.length() + w, 0.01, w)
	mi.mesh = bm
	var m := _line_m.duplicate() as StandardMaterial3D
	m.vertex_color_use_as_albedo = false
	m.albedo_color = color
	mi.material_override = m
	_marks.add_child(mi)
	mi.position = (a + b) * 0.5 + Vector3(0, CUT + 0.5, 0)
	mi.rotation.y = -atan2(d.z, d.x)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
