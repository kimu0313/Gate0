class_name Mats
extends RefCounted
## Shared material library for the procedurally built terminal.

static var _cache := {}


static func get_mat(mat_name: String) -> Material:
	if _cache.has(mat_name):
		return _cache[mat_name]
	var m := _make(mat_name)
	_cache[mat_name] = m
	return m


static func std(color: Color, roughness := 0.6, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


static func emissive(color: Color, energy := 2.0, albedo := Color.BLACK) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m


## Old painted sheet steel in `color` (user, with a photo of worn lockers: "사물함이나 책상 쇠 부분 텍스처 참고해서
## 이렇게 바꿔줘"): the paint gone dull and grimy, rust in patches that run downward, scratches through to bright metal
## (shaders/weathered.gdshader). One material per colour, cached.
static func weathered_steel(color: Color) -> Material:
	var key := "wsteel_" + color.to_html()
	if not _cache.has(key):
		_cache[key] = shader_mat("res://shaders/weathered.gdshader", {"base_color": color,
				"rust_color": Color(0.42, 0.29, 0.15), "grime_color": color * Color(0.55, 0.53, 0.48), "metallic": 0.4,
				"roughness": 0.52, "rust": 0.3, "grime": 0.5, "scale": 6.5, "scratches": 1.0, "runs": 0.75,
				"scratch_color": Color(0.74, 0.75, 0.74)})
	return _cache[key]


static func shader_mat(path: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for k in params.keys():
		m.set_shader_parameter(k, params[k])
	return m


static func _make(mat_name: String) -> Material:
	match mat_name:
		"floor":
			return shader_mat("res://shaders/floor_tile.gdshader")
		"floor_accent":
			return shader_mat("res://shaders/floor_tile.gdshader", {"accent_band": 1.0})
		"floor_lounge":
			# main lounge: big polished grey-beige granite tiles, mirror-like, with dark stone tiles scattered through
			# (the lounge and night-airport references)
			return shader_mat("res://shaders/floor_tile.gdshader", {
				"color_a": Color(0.5, 0.48, 0.45), "color_b": Color(0.44, 0.42, 0.39), "grout_color": Color(0.33, 0.31, 0.29),
				"tile_size": 1.5, "roughness_base": 0.05, "roughness_var": 0.12, "dark_share": 0.07,
				"dark_color": Color(0.12, 0.115, 0.11)})
		"column":
			# lounge columns: warm limestone cladding in 1.5 m courses, a dark bronze skirting (night-airport reference)
			return shader_mat("res://shaders/wall_panel.gdshader", {
				"color": Color(0.56, 0.52, 0.46), "seam_color": Color(0.36, 0.33, 0.29), "panel_w": 100.0,
				"panel_h": 1.5, "seam": 0.01, "roughness": 0.5, "skirting": 0.14, "skirting_color": Color(0.22, 0.2, 0.18)})
		"column_shaft":
			# the same, on the columns that go on up over the lounge's glass side, fading into the dark with its walls
			# (LoungeShaft)
			var cs := (get_mat("column") as ShaderMaterial).duplicate() as ShaderMaterial
			cs.set_shader_parameter("fade_from", LoungeShaft.FADE_FROM)
			cs.set_shader_parameter("fade", LoungeShaft.FADE)
			return cs
		"ceiling_lounge":
			# the lounge's ceilings and the 2F's underside: warm grey panels
			return shader_mat("res://shaders/ceiling.gdshader", {"color": Color(0.5, 0.48, 0.45), "grid_color": Color(0.36, 0.34, 0.31), "tile": 1.2})
		"ad_screen":
			return shader_mat("res://shaders/ad_screen.gdshader", {
				"plane_tex": load("res://assets/textures/level/icon_plane.png")})
		"cctv_feed":
			return shader_mat("res://shaders/cctv_feed.gdshader")
		"led_blink":
			return shader_mat("res://shaders/led_blink.gdshader")
		"floor_office":
			return shader_mat("res://shaders/floor_tile.gdshader", {
				"color_a": Color(0.5, 0.49, 0.46), "color_b": Color(0.46, 0.45, 0.42),
				"tile_size": 0.6, "roughness_base": 0.35, "roughness_var": 0.2})
		"floor_service":
			return shader_mat("res://shaders/floor_tile.gdshader", {
				"color_a": Color(0.22, 0.23, 0.22), "color_b": Color(0.2, 0.21, 0.2),
				"tile_size": 2.0, "roughness_base": 0.55, "roughness_var": 0.3, "grout": 0.02})
		"carpet":
			return shader_mat("res://shaders/carpet.gdshader")
		"plastic_peripheral":
			# the office keyboards' and mice's light grey plastic (user, with photos of the two): barely yellowed,
			# grimy where hands go
			return shader_mat("res://shaders/weathered.gdshader", {"base_color": Color(0.8, 0.79, 0.74),
					"rust_color": Color(0.76, 0.72, 0.6), "grime_color": Color(0.58, 0.56, 0.5), "metallic": 0.0, "roughness": 0.55,
					"rust": 0.3, "grime": 0.3, "scale": 24.0})
		"plastic_aged":
			# old computers' beige plastic (user, with a photo of an old beige PC: "컴퓨터 텍스처도 참고해줘"): yellowed in
			# patches, grimy, scuffed dark in places
			return shader_mat("res://shaders/weathered.gdshader", {"base_color": Color(0.74, 0.69, 0.56),
					"rust_color": Color(0.66, 0.58, 0.4), "grime_color": Color(0.46, 0.42, 0.34), "metallic": 0.0, "roughness": 0.62,
					"rust": 0.6, "grime": 0.45, "scale": 11.0})
		"fixture_cast":
			# the office light fittings' cast housings and end brackets: near-black iron, rust and grime
			return shader_mat("res://shaders/weathered.gdshader", {"base_color": Color(0.085, 0.075, 0.065),
					"rust_color": Color(0.27, 0.14, 0.07), "metallic": 0.55, "roughness": 0.58, "rust": 0.45, "grime": 0.35, "scale": 14.0})
		"fixture_reflector":
			# their reflector troughs: brushed steel gone dull and warm, a little rust, grime in patches
			return shader_mat("res://shaders/weathered.gdshader", {"base_color": Color(0.56, 0.53, 0.47),
					"rust_color": Color(0.36, 0.24, 0.13), "grime_color": Color(0.2, 0.19, 0.16), "metallic": 0.85, "roughness": 0.34,
					"rust": 0.14, "grime": 0.55, "scale": 7.0, "brushed": 1.0})
		"cork_board":
			# the office's notice boards (user, a cork photo: "이 텍스처로 바꿔줘"): the photo once across each board
			# (OfficeKit.notice_board crops it to the board's shape; repeated, its edges showed as stripes)
			var m := StandardMaterial3D.new()
			m.albedo_texture = load("res://assets/textures/level/cork_board.png")
			m.roughness = 0.95
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			return m
		"ceiling_corridor_tile":
			# the service corridors' ceiling (user, with a photo of pale marbled square tiles in grey joints: "천장 텍스처 이걸로
			# 해줘"): four by four 0.6 m tiles to a repeat, in world space
			var m := StandardMaterial3D.new()
			m.albedo_texture = load("res://assets/textures/level/ceiling_corridor_tile.png")
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3.ONE / 2.4
			m.roughness = 0.8
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			return m
		"floor_corridor_concrete":
			# the service corridors' and the stair hall's floor (user, a grey concrete picture: "이 텍스처를 복도 바닥에
			# 넣어줘", "복도 바닥 텍스처를 계단에 넣어줘", "복도 바닥 색 어둡게"): that picture made seamless
			# (tools/make_seamless.gd), darkened, world space, its 1:2 shape kept — 1.2 m across x, 2.4 m along z
			var m := StandardMaterial3D.new()
			m.albedo_texture = load("res://assets/textures/level/floor_corridor_concrete.png")
			m.albedo_color = Color(0.55, 0.55, 0.55)
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3(1.0 / 1.2, 1.0 / 2.4, 1.0 / 2.4)
			m.roughness = 0.6
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			return m
		"floor_office_stone":
			# the security office's floor (user, with a dark stone-tile photo: "보안실 바닥 이 텍스처로 해줘"): that photo,
			# four 0.6 m tiles to a repeat, laid in world space so every floor slab lines up; a little sheen for the pools
			var m := StandardMaterial3D.new()
			m.albedo_texture = load("res://assets/textures/level/floor_office_stone.png")
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3.ONE / 1.2
			m.roughness = 0.62
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			return m
		"floor_checker":
			# the security office's black-and-white checkerboard vinyl (the police-station concept art)
			return shader_mat("res://shaders/floor_checker.gdshader", {"white_tile": Color(0.64, 0.62, 0.55)})   # aged ivory
		"plaster_wall":
			# its painted plaster walls and pilasters: pale sage over a dark teal-green dado, grimy (user: a dark old-office
			# reference, "사무실의 색감과 분위기는 이래야해")
			return shader_mat("res://shaders/concrete.gdshader", {"color": Color(0.6, 0.62, 0.53), "dark": Color(0.49, 0.51, 0.44),
					"joint": 0.0, "tie": 0.0, "roughness": 0.72, "dado": 1.0, "dado_color": Color(0.17, 0.25, 0.24),
					"use_detail": true, "detail_tex": load("res://assets/textures/level/wall_office_plaster.png"),
					"detail_size": Vector2(2.4, 4.0)})     # the worn-plaster photo (user: "투톤 색상은 유지한 채 텍스처만 이렇게")
		"plaster_ceiling":
			# the security office's ceiling: the light grey stone-relief photo (user: "천장 텍스처를 이걸로 바꿔줘"),
			# repeated mirror-wise every 1.5 x 3 m
			return shader_mat("res://shaders/concrete.gdshader", {"color": Color(0.72, 0.72, 0.7), "dark": Color(0.66, 0.66, 0.64),
					"joint": 0.0, "tie": 0.0, "roughness": 0.85, "use_detail": true, "detail_horiz": true,
					"detail_tex": load("res://assets/textures/level/ceiling_office_stone.png"), "detail_size": Vector2(1.5, 3.0),
					"detail_mean": 0.813})
		"carpet_red":
			return shader_mat("res://shaders/carpet.gdshader", {
				"base_color": Color(0.12, 0.035, 0.04), "pattern_color": Color(0.16, 0.06, 0.05)})
		"wall":
			return shader_mat("res://shaders/wall_panel.gdshader")
		"wall_office":
			return shader_mat("res://shaders/wall_panel.gdshader", {
				"color": Color(0.7, 0.7, 0.67), "panel_w": 1.2, "panel_h": 3.2})
		"wall_tile":
			# glazed white wall tile of the boarding corridor (the 8번 출구 passage look)
			return shader_mat("res://shaders/wall_panel.gdshader", {
				"color": Color(0.86, 0.86, 0.84), "seam_color": Color(0.55, 0.55, 0.53), "panel_w": 0.3,
				"panel_h": 0.15, "seam": 0.004, "roughness": 0.16})
		"wall_service":
			return shader_mat("res://shaders/wall_panel.gdshader", {
				"color": Color(0.34, 0.35, 0.34), "panel_w": 3.0, "panel_h": 1.0, "roughness": 0.85})
		"ceiling":
			return shader_mat("res://shaders/ceiling.gdshader")
		"ceiling_dark":
			return shader_mat("res://shaders/ceiling.gdshader", {"color": Color(0.36, 0.36, 0.36), "grid_color": Color(0.22, 0.22, 0.22), "tile": 1.2})
		"metal":
			return std(Color(0.55, 0.57, 0.6), 0.32, 0.85)
		"metal_dark":
			return std(Color(0.2, 0.205, 0.215), 0.45, 0.3)
		"steel_frame":
			return std(Color(0.36, 0.37, 0.39), 0.35, 0.55)
		"plastic_dark":
			return std(Color(0.11, 0.11, 0.12), 0.5)
		"plastic_grey":
			return std(Color(0.32, 0.33, 0.34), 0.5)
		"plastic_white":
			return std(Color(0.8, 0.8, 0.78), 0.4)
		"counter":
			return std(Color(0.78, 0.78, 0.75), 0.25)
		"counter_front":
			return std(Color(0.14, 0.18, 0.28), 0.35)
		"wood":
			return std(Color(0.36, 0.26, 0.18), 0.6)
		"rubber":
			return std(Color(0.07, 0.07, 0.07), 0.9)
		"seat":
			return std(Color(0.16, 0.17, 0.19), 0.38)
		"seat_frame":
			return std(Color(0.42, 0.43, 0.45), 0.3, 0.9)
		"sign_back":
			var s := std(Color(0.03, 0.05, 0.13), 0.35)
			s.emission_enabled = true
			s.emission = Color(0.02, 0.035, 0.09)
			s.emission_energy_multiplier = 1.0
			return s
		"asphalt":
			return std(Color(0.045, 0.045, 0.05), 0.92)
		"concrete":
			return std(Color(0.32, 0.32, 0.31), 0.9)
		"yellow_paint":
			return std(Color(0.75, 0.6, 0.08), 0.7)
		"white_paint":
			return std(Color(0.7, 0.7, 0.68), 0.7)
		"glass":
			var g := StandardMaterial3D.new()
			g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			g.albedo_color = Color(0.55, 0.65, 0.7, 0.1)
			g.roughness = 0.04
			g.metallic = 0.1
			g.metallic_specular = 0.9
			g.cull_mode = BaseMaterial3D.CULL_DISABLED
			return g
		"glass_frosted":
			var gf := StandardMaterial3D.new()
			gf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			gf.albedo_color = Color(0.75, 0.8, 0.82, 0.45)
			gf.roughness = 0.35
			gf.cull_mode = BaseMaterial3D.CULL_DISABLED
			return gf
		"shutter":
			return std(Color(0.4, 0.41, 0.42), 0.45, 0.75)
		"paper":
			return std(Color(0.88, 0.87, 0.82), 0.85)
		"plane_body":
			return std(Color(0.82, 0.83, 0.85), 0.28, 0.2)
		"plane_dark":
			return std(Color(0.1, 0.11, 0.13), 0.3, 0.3)
		"screen_off":
			return std(Color(0.01, 0.01, 0.012), 0.12, 0.2)
		"black":
			return std(Color(0.0, 0.0, 0.0), 1.0)
		"void":                                          # nothing there: no light, no sheen, no fog — black through any gap
			var v := std(Color.BLACK, 1.0)
			v.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			v.disable_fog = true
			return v
		"figure":
			var f := std(Color(0.008, 0.008, 0.01), 0.95)
			return f
		"exit_green":
			return emissive(Color(0.1, 1.0, 0.35), 3.0)
		"lamp_red":
			return emissive(Color(1.0, 0.08, 0.05), 3.0)
		"lamp_green":
			return emissive(Color(0.15, 1.0, 0.3), 2.5)
		"lamp_amber":
			return emissive(Color(1.0, 0.6, 0.1), 2.5)
		"lamp_white":
			return emissive(Color(1.0, 0.97, 0.9), 4.0)
		"lamp_blue":
			return emissive(Color(0.3, 0.55, 1.0), 2.5)
		"runway_light":
			return emissive(Color(1.0, 0.75, 0.35), 6.0)
		"runway_blue":
			return emissive(Color(0.25, 0.45, 1.0), 6.0)
		"lightbox":
			return emissive(Color(0.85, 0.9, 1.0), 1.4, Color(0.6, 0.6, 0.6))
		"button_green":
			return emissive(Color(0.1, 0.8, 0.25), 0.8, Color(0.05, 0.4, 0.1))
		"button_red":
			return emissive(Color(0.9, 0.05, 0.03), 0.8, Color(0.5, 0.02, 0.02))
		"button_yellow":
			return emissive(Color(0.9, 0.7, 0.05), 0.6, Color(0.6, 0.45, 0.02))
		"button_white":
			return std(Color(0.86, 0.87, 0.88), 0.35)
		"button_grey":
			return std(Color(0.2, 0.2, 0.22), 0.5)
		"button_blue":
			return emissive(Color(0.15, 0.4, 1.0), 0.7, Color(0.05, 0.15, 0.5))
		_:
			push_warning("Unknown material: " + mat_name)
			return std(Color.MAGENTA)
