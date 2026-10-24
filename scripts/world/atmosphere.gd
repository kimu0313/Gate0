class_name Atmosphere
extends Node3D
## WorldEnvironment + sun/moon presets for day, night and the day-3 "wrong day".

var world_env: WorldEnvironment
var env: Environment
var sun: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var preset := "night"
static var gi_enabled := false   # SDFGI on for this phase (LightZone splits its light by this)


func setup(p: String) -> void:
	preset = p
	world_env = WorldEnvironment.new()
	add_child(world_env)
	env = Environment.new()
	world_env.environment = env
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	sun = DirectionalLight3D.new()
	add_child(sun)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	var high: bool = Game.settings.quality == "high"
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.glow_hdr_threshold = 1.15    # only lamps and screens bloom, not lit white walls
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.8
	env.ssr_enabled = high
	env.ssr_max_steps = 56
	env.ssr_fade_in = 0.12
	env.ssr_fade_out = 2.2
	env.ssr_depth_tolerance = 0.25
	env.adjustment_enabled = true
	env.volumetric_fog_enabled = high
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 70.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_ambient_inject = 0.0
	env.volumetric_fog_sky_affect = 0.0
	# light bounce for the day presets (SDFGI); at night LightZone fakes the bounce with its fill omnis
	env.sdfgi_use_occlusion = true
	env.sdfgi_bounce_feedback = 0.5
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.25
	env.ssil_enabled = high
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	match p:
		"day":
			_day(high, false)
		"day_wrong":
			_day(high, true)
		_:
			_night(high)
	gi_enabled = env.sdfgi_enabled


func _night(high: bool) -> void:
	sky_mat.sky_top_color = Color(0.004, 0.006, 0.016)
	sky_mat.sky_horizon_color = Color(0.03, 0.035, 0.055)
	sky_mat.ground_horizon_color = Color(0.02, 0.022, 0.03)
	sky_mat.ground_bottom_color = Color(0.0, 0.0, 0.0)
	sky_mat.sun_angle_max = 1.0
	sky_mat.sky_energy_multiplier = 1.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.055, 0.065, 0.09)
	env.ambient_light_energy = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_exposure = 0.9       # lit whites (kiosks, signs, the FIDS frame) stay below clipping
	env.glow_intensity = 0.5
	env.glow_bloom = 0.02
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.8
	env.volumetric_fog_density = 0.016
	env.volumetric_fog_albedo = Color(0.8, 0.85, 0.92)
	env.sdfgi_enabled = false   # too costly for what it adds at night (see LightZone.NO_GI_DIRECT)
	# film-photo night: teal shadows, faintly green fluorescent highlights (GDD lounge reference)
	env.adjustment_color_correction = grade_lut(Vector3(-0.03, 0.012, 0.024), Vector3(-0.006, 0.014, -0.006))
	sun.light_color = Color(0.55, 0.65, 1.0)
	sun.light_energy = 0.12
	sun.rotation = Vector3(deg_to_rad(-38), deg_to_rad(155), 0)
	sun.light_volumetric_fog_energy = 0.2


func _day(high: bool, wrong: bool) -> void:
	sky_mat.sky_top_color = Color(0.28, 0.45, 0.72) if not wrong else Color(0.42, 0.42, 0.44)
	sky_mat.sky_horizon_color = Color(0.68, 0.74, 0.8) if not wrong else Color(0.62, 0.58, 0.55)
	sky_mat.ground_horizon_color = Color(0.5, 0.52, 0.55)
	sky_mat.ground_bottom_color = Color(0.2, 0.2, 0.22)
	sky_mat.sky_energy_multiplier = 1.0
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75 if not wrong else 0.55
	env.ambient_light_sky_contribution = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_exposure = 1.12
	env.glow_intensity = 0.4
	env.glow_bloom = 0.03
	env.adjustment_contrast = 1.03
	env.adjustment_saturation = 0.95 if not wrong else 0.55
	env.volumetric_fog_density = 0.003 if not wrong else 0.009
	env.volumetric_fog_albedo = Color(1, 1, 1)
	env.sdfgi_enabled = high
	env.sdfgi_energy = 1.25
	env.adjustment_color_correction = grade_lut(Vector3(-0.008, 0.0, 0.012), Vector3(0.02, 0.01, -0.012))
	sun.light_color = Color(1.0, 0.95, 0.86) if not wrong else Color(0.95, 0.85, 0.8)
	sun.light_energy = 2.4 if not wrong else 1.1
	sun.rotation = Vector3(deg_to_rad(-48), deg_to_rad(-25), 0)
	sun.light_volumetric_fog_energy = 1.0


## Colour grade as a 3D LUT (sRGB in → sRGB out): darks lean toward `shadow`, brights toward `high`.
## Offsets are small RGB shifts, faded by luminance so mid-greys and pure white stay put.
static func grade_lut(shadow: Vector3, high: Vector3) -> ImageTexture3D:
	const N := 17
	var slices: Array[Image] = []
	for bi in N:
		var img := Image.create(N, N, false, Image.FORMAT_RGB8)
		for gi in N:
			for ri in N:
				var c := Vector3(ri, gi, bi) / float(N - 1)
				var l := c.dot(Vector3(0.2126, 0.7152, 0.0722))
				var ws := pow(1.0 - l, 2.0) * smoothstep(0.0, 0.12, l)
				var wh := l * l * (1.0 - smoothstep(0.85, 1.0, l))
				c = (c + shadow * ws + high * wh).clamp(Vector3.ZERO, Vector3.ONE)
				img.set_pixel(ri, gi, Color(c.x, c.y, c.z))
		slices.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGB8, N, N, N, false, slices)
	return tex
