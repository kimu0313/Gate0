class_name LoungeShaft
extends RefCounted
## Over the main lounge's glass side there is no roof (user, with a photo of a concrete tunnel running on into black:
## "전창을 위로 끝없는 어둠으로 — 내가 있는 쪽은 밝은데 천장 바라보면 이렇게"; then, of the beams that first
## crossed it: "천장에 선, 기둥 같은 거 다 없애줘, 그냥 끝없는 공간으로"; then "창문 위도 벽으로, 창문은 그대로,
## 가운데 기둥도 천장이랑 같은 높이로, 천장 쪽 안개는 검은색"): from the south column row (Terminal.ROOF_Z) to the
## glass, the whole width of the lounge, the walls go on straight up to TOP — over the glass facade (its own frame
## and panes up to Terminal.HALL_ROOF stay as they are) a wall too — and nothing crosses the space between them, no
## beam, rib or frame, and no column stands in it (the row that once rose into the dark with the walls was taken out:
## "가운데 기둥 4개 다 빼줘").
## Up there the air is black: a fog that scatters no light swallows the walls (BlackAir), and the walls themselves
## darken with height (shaders/shaft_fade.gdshader, so they read black even without the volumetric fog). A black lid
## closes it at TOP, long after everything has gone. The lights over the floor hang nowhere and light nothing but the
## floor (no cone in the haze, no wash up the walls), so the floor stays lit and above it nothing is. Nothing up there
## collides: nobody can reach it.

const RECT := Rect2(-20.0, Terminal.ROOF_Z, Terminal.HALL_E + 20.0, Terminal.HALL_S - Terminal.ROOF_Z)   # x: the end walls, z: ROOF_Z .. the glass
const BASE := 12.0             # the walls go up from the lounge's ceiling height (Terminal.HALL_H)
const OVER_GLASS := 20.9       # the wall over the facade starts on its head bar (Terminal.HALL_ROOF)
const TOP := 400.0
const CLEAR_FROM := 13.5       # no haze from here (ClearAir; the lounge smoke stops here too) ...
const BLACK_FROM := 16.5       # ... and from here up the air is black (BlackAir)
const BLACK_DENSITY := 0.12    # on top of the world's own fog, which nothing up there lights
const FADE_FROM := 14.0        # shaft_fade: the walls' colour falls off by e every FADE metres above FADE_FROM
const FADE := 18.0
const LAMP_Y := 15.5           # the lights over the glass side, up in the clear dark
const LAMP_RANGE := 34.0
## The lights over the glass side: [x, z, energy]. They light the floor and nothing else: not the haze (no cone to
## look up into, no glow in the dark) and nothing above the ceiling line — the user had the glows over the middle
## taken out ("중앙부분만 조명 치워줘"), then the cones at the ends and the washes up the end walls ("라인 조명도
## 없애줘"), so nothing lights the dark up there at all.
const LAMPS := [
	[-13.0, 13.0, 15.0], [-1.0, 13.0, 15.0], [11.0, 13.0, 15.0],
	[-7.0, 20.5, 16.0], [6.0, 20.5, 16.0],
	[-14.0, 26.0, 16.5], [0.0, 26.0, 16.5], [14.0, 26.0, 16.5]]
const CONCRETE := Color(0.72, 0.72, 0.7)


static func build(t: Node3D) -> void:
	var root := Node3D.new()
	root.name = "LoungeShaft"
	t.add_child(root)
	var x0 := RECT.position.x
	var x1 := RECT.end.x
	var z0 := RECT.position.y
	var z1 := RECT.end.y
	var mid_x := (x0 + x1) * 0.5
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	# the walls on up, plain: the north one over the lounge's flat ceiling, the two end walls, and over the glass
	# facade one more (its ends inside the end walls)
	var h := TOP - BASE
	_box(walls, Vector3(mid_x, BASE + h * 0.5, z0), Vector3(x1 - x0 + 0.4, h, 0.4))
	for wx: float in [x0, x1]:
		_box(walls, Vector3(wx, BASE + h * 0.5, (z0 + z1) * 0.5), Vector3(0.4, h, z1 - z0))
	_box(walls, Vector3(mid_x, (OVER_GLASS + TOP) * 0.5, z1), Vector3(x1 - x0, TOP - OVER_GLASS, 0.4))
	var mi := MeshInstance3D.new()
	mi.name = "Walls"
	mi.mesh = walls.commit()
	mi.material_override = Mats.shader_mat("res://shaders/shaft_fade.gdshader", {"color": CONCRETE, "roughness": 0.88,
			"metallic": 0.0, "stain": 0.2, "y0": FADE_FROM, "fade": FADE})
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	# the lid nobody sees: black, but under the same fog as the rest (Mats "void" skips the fog and would show)
	var cap := StandardMaterial3D.new()
	cap.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cap.albedo_color = Color.BLACK
	Geo.box(root, Vector3(mid_x, TOP + 0.5, (z0 + z1) * 0.5), Vector3(x1 - x0 + 0.4, 1.0, z1 - z0 + 0.4), cap, false)
	# no haze round the lights (the world's and the lounge's stop at CLEAR_FROM): their cones show only once they are
	# down in the lounge's haze
	var clear := FogVolume.new()
	clear.name = "ClearAir"
	clear.size = Vector3(x1 - x0, BLACK_FROM - CLEAR_FROM, z1 - z0)
	var fm := FogMaterial.new()
	fm.density = -1.0
	fm.edge_fade = 0.1
	clear.material = fm
	root.add_child(clear)
	clear.position = Vector3(mid_x, (CLEAR_FROM + BLACK_FROM) * 0.5, (z0 + z1) * 0.5)
	# and above them black air: a fog that scatters nothing (albedo black, and no light up there lights the world's
	# own), so looking up the walls and columns go into black, not into a grey glow
	var black := FogVolume.new()
	black.name = "BlackAir"
	black.size = Vector3(x1 - x0, TOP - BLACK_FROM, z1 - z0)
	var bm := FogMaterial.new()
	bm.density = BLACK_DENSITY
	bm.albedo = Color.BLACK
	bm.edge_fade = 0.01
	black.material = bm
	root.add_child(black)
	black.position = Vector3(mid_x, (BLACK_FROM + TOP) * 0.5, (z0 + z1) * 0.5)


## The lounge's lights over the glass side (on the hall zone `z`): downlights up in the dark (LAMPS, no fixture) that
## light the floor only. Looking up there is nothing lit.
static func lights(t: Node3D, z: LightZone) -> void:
	for l: Array in LAMPS:
		var p := Vector3(l[0], LAMP_Y, l[1])
		var s := Geo.spot(t, p, p, Terminal.ZONE_LIGHT, l[2], LAMP_RANGE, 38.0)
		s.rotation.x = -PI / 2
		s.spot_attenuation = 0.9
		s.spot_angle_attenuation = 1.6
		s.light_volumetric_fog_energy = 0.0
		z.add_light(s)


## An axis-aligned box centred on `c` into `st` (outward faces, flat normals).
static func _box(st: SurfaceTool, c: Vector3, s: Vector3) -> void:
	var e := s * 0.5
	for ax in 3:
		for sg: float in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[ax] = sg
			var u := Vector3.ZERO
			u[(ax + 1) % 3] = 1.0
			var v := n.cross(u)                        # along the third axis
			var o := c + n * e[ax]
			var du := u * e[(ax + 1) % 3]
			var dv := v * e[(ax + 2) % 3]
			var q := [o - du - dv, o + du - dv, o + du + dv, o - du + dv]
			for i: int in [0, 2, 1, 0, 3, 2]:            # clockwise seen from outside (Godot's front face)
				st.set_normal(n)
				st.add_vertex(q[i])
