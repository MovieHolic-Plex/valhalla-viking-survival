class_name SkySystem
extends Node3D
## 낮/밤 · 날씨 · 바이옴별 안개.
## 발헤임 룩의 절반은 여기서 나온다: 짙은 안개, 낮게 깔린 태양, 강한 블룸.

var env: WorldEnvironment
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var _sky_mat: ShaderMaterial

var rain: GPUParticles3D
var snow: GPUParticles3D

## 현재 날씨: clear / cloudy / rain / storm / snow / mist / ashfall
var weather := "clear"
var weather_timer := 0.0
var wind_strength := 0.4
var _wind_target := 0.4

var _fog_color := Color(0.62, 0.72, 0.78)
var _fog_density := 0.0012
var _rng := RandomNumberGenerator.new()

const SUN_DAY := Color(1.0, 0.94, 0.82)
const SUN_DUSK := Color(1.0, 0.56, 0.28)
const MOON_COL := Color(0.55, 0.66, 0.92)

func _ready() -> void:
	name = "sky"
	_rng.randomize()
	_make_env()
	_make_lights()
	_make_weather_particles()
	_pick_weather(true)
	GameState.biome_changed.connect(_on_biome_changed)

func _make_env() -> void:
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var sh := Shader.new()
	sh.code = SkyShaderLib.SKY
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = sh
	_sky_mat.set_shader_parameter("cloud_tex", SkyShaderLib.make_cloud_texture(128))
	_sky_mat.set_shader_parameter("top_color", Color(0.20, 0.40, 0.72))
	_sky_mat.set_shader_parameter("horizon_color", Color(0.72, 0.80, 0.84))
	_sky_mat.set_shader_parameter("ground_color", Color(0.14, 0.15, 0.16))
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	e.sky = sky

	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_sky_contribution = 1.0
	e.ambient_light_energy = 0.85
	e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	# 안개 — 거리감과 분위기의 핵심
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	e.fog_light_color = _fog_color
	e.fog_light_energy = 1.0
	e.fog_sun_scatter = 0.20
	e.fog_density = _fog_density
	e.fog_sky_affect = 0.55
	e.fog_height = Const.WATER_LEVEL + 12.0
	e.fog_height_density = 0.02
	e.fog_aerial_perspective = 0.12

	# 볼류메트릭 포그 — 빛줄기
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.008
	e.volumetric_fog_albedo = Color(0.85, 0.88, 0.92)
	e.volumetric_fog_emission_energy = 0.0
	e.volumetric_fog_length = 96.0
	e.volumetric_fog_detail_spread = 2.0
	e.volumetric_fog_gi_inject = 0.4
	e.volumetric_fog_ambient_inject = 0.6

	# 톤매핑 + 블룸 — 저해상도 텍스처를 고급스럽게 만드는 부분
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.05
	e.tonemap_white = 6.0
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_strength = 1.0
	e.glow_bloom = 0.16
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.glow_hdr_threshold = 0.92
	e.set_glow_level(1, 0.0)
	e.set_glow_level(3, 0.9)
	e.set_glow_level(5, 0.7)

	e.ssao_enabled = true
	e.ssao_radius = 1.2
	e.ssao_intensity = 0.9
	e.ssao_power = 1.4
	e.ssil_enabled = false

	e.adjustment_enabled = true
	e.adjustment_saturation = 1.12
	e.adjustment_contrast = 1.06
	e.adjustment_brightness = 1.0

	env = WorldEnvironment.new()
	env.environment = e
	add_child(env)

	# 카메라 감쇠(피사계 심도 대신 가벼운 시네마틱 보정)
	var att := CameraAttributesPractical.new()
	att.dof_blur_far_enabled = false
	att.auto_exposure_enabled = false
	env.camera_attributes = att

func _make_lights() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "sun"
	sun.light_color = SUN_DAY
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 220.0
	sun.directional_shadow_split_1 = 0.06
	sun.directional_shadow_split_2 = 0.16
	sun.directional_shadow_split_3 = 0.42
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = 0.02
	sun.shadow_normal_bias = 0.7
	sun.light_angular_distance = 1.2
	add_child(sun)

	moon = DirectionalLight3D.new()
	moon.name = "moon"
	moon.light_color = MOON_COL
	moon.light_energy = 0.0
	moon.shadow_enabled = false
	add_child(moon)

func _make_weather_particles() -> void:
	rain = _precip(Color(0.72, 0.80, 0.92, 0.55), Vector3(0.02, 0.55, 0.02), 900, 26.0)
	rain.emitting = false
	add_child(rain)
	snow = _precip(Color(0.96, 0.98, 1.0, 0.9), Vector3(0.09, 0.09, 0.09), 700, 3.2)
	snow.emitting = false
	add_child(snow)

func _precip(col: Color, size: Vector3, amount: int, speed: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = 2.2
	p.preprocess = 2.0
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-40, -40, -40), Vector3(80, 80, 80))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(34, 1, 34)
	m.direction = Vector3(0.15, -1, 0.05)
	m.spread = 6.0
	m.initial_velocity_min = speed * 0.8
	m.initial_velocity_max = speed
	m.gravity = Vector3(0, -1.5, 0)
	m.scale_min = 0.8
	m.scale_max = 1.3
	m.color = col
	p.process_material = m
	var mb := MeshBuilder.new()
	mb.box(Transform3D.IDENTITY, size, Color.WHITE)
	p.draw_pass_1 = mb.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = mat
	return p

# ══════════════════════════════════════════════ 갱신
func _process(delta: float) -> void:
	_update_sun()
	_update_weather(delta)
	_update_fog(delta)
	_follow_player()

func _update_sun() -> void:
	var t := GameState.time_of_day
	# 태양 고도: 0.5 에서 최고, 0.0/1.0 에서 지평선 아래
	var ang := (t - 0.25) * TAU
	var elev := sin(ang)
	sun.rotation = Vector3(0, 0, 0)
	sun.rotation_degrees = Vector3(-rad_to_deg(asin(clampf(elev, -1.0, 1.0))), 40.0 + t * 60.0, 0)
	moon.rotation_degrees = sun.rotation_degrees + Vector3(180, 0, 0)

	var day_amt := clampf(elev * 3.0, 0.0, 1.0)
	var dusk := clampf(1.0 - absf(elev) * 4.0, 0.0, 1.0)

	var storm_dim := 0.55 if weather == "storm" else (0.75 if weather == "rain" else 1.0)
	sun.light_energy = lerpf(0.0, 1.15, day_amt) * storm_dim
	sun.light_color = SUN_DAY.lerp(SUN_DUSK, dusk)
	moon.light_energy = lerpf(0.16, 0.0, day_amt)

	var e := env.environment
	# 하늘색 — 낮/밤/노을을 섞는다
	var top_day := Color(0.20, 0.41, 0.74)
	var top_night := Color(0.020, 0.030, 0.070)
	var hor_day := Color(0.74, 0.82, 0.86)
	var hor_night := Color(0.06, 0.08, 0.14)
	var top: Color = top_night.lerp(top_day, day_amt)
	var hor: Color = hor_night.lerp(hor_day, day_amt).lerp(
		Color(1.0, 0.50, 0.24), dusk * 0.80)
	_sky_mat.set_shader_parameter("top_color", top)
	_sky_mat.set_shader_parameter("horizon_color", hor)
	_sky_mat.set_shader_parameter("ground_color", Color(0.07, 0.08, 0.09).lerp(
		Color(0.17, 0.19, 0.19), day_amt))
	_sky_mat.set_shader_parameter("sun_color", sun.light_color)
	_sky_mat.set_shader_parameter("day_amount", day_amt)
	_sky_mat.set_shader_parameter("dusk_amount", dusk)
	_sky_mat.set_shader_parameter("star_amount", clampf(1.0 - day_amt * 2.2, 0.0, 1.0))
	_sky_mat.set_shader_parameter("moon_dir",
		-moon.global_transform.basis.z.normalized())
	var cloudy := 0.55 if weather in ["cloudy", "rain", "storm", "snow"] else 0.28
	if weather == "storm":
		cloudy = 0.85
	_sky_mat.set_shader_parameter("cloud_amount", cloudy)

	# 물에도 태양 정보를 넘겨 윤슬을 만든다
	if MatLib.water_mat != null:
		MatLib.water_mat.set_shader_parameter("sun_dir",
			sun.global_transform.basis.z.normalized())
		MatLib.water_mat.set_shader_parameter("sun_col",
			sun.light_color * maxf(day_amt, 0.05))
		MatLib.water_mat.set_shader_parameter("choppy",
			2.0 if weather == "storm" else (1.4 if weather == "rain" else 1.0))

	e.tonemap_exposure = lerpf(1.20, 0.88, day_amt)
	e.adjustment_saturation = lerpf(0.85, 1.22, day_amt)
	e.glow_intensity = lerpf(0.85, 0.55, day_amt)
	e.volumetric_fog_density = lerpf(0.014, 0.007, day_amt) \
		* (2.2 if weather == "mist" else 1.0)

func _update_weather(delta: float) -> void:
	weather_timer -= delta
	if weather_timer <= 0.0:
		_pick_weather(false)
	# 바람 세기를 서서히 바꾼다
	wind_strength = move_toward(wind_strength, _wind_target, delta * 0.15)
	if _rng.randf() < delta * 0.15:
		_wind_target = _rng.randf_range(0.15, 1.0)

	if weather == "storm" and _rng.randf() < delta * 0.08:
		_lightning()

func _pick_weather(first: bool) -> void:
	weather_timer = _rng.randf_range(180.0, 420.0)
	var b := GameState.current_biome
	var opts: Array = []
	match b:
		Const.Biome.MEADOWS:
			opts = ["clear", "clear", "cloudy", "rain"]
		Const.Biome.BLACKFOREST:
			opts = ["clear", "cloudy", "cloudy", "rain", "mist"]
		Const.Biome.SWAMP:
			opts = ["mist", "mist", "rain", "storm"]
		Const.Biome.MOUNTAIN:
			opts = ["snow", "snow", "clear", "storm"]
		Const.Biome.PLAINS:
			opts = ["clear", "clear", "cloudy", "rain"]
		Const.Biome.MISTLANDS:
			opts = ["mist", "mist", "mist", "cloudy"]
		Const.Biome.ASHLANDS:
			opts = ["ashfall", "ashfall", "clear"]
		_:
			opts = ["clear", "cloudy", "rain", "storm"]
	if first:
		weather = "clear"
	else:
		weather = opts[_rng.randi() % opts.size()]
	rain.emitting = (weather == "rain" or weather == "storm")
	snow.emitting = (weather == "snow" or weather == "ashfall")
	if weather == "ashfall":
		var m := snow.process_material as ParticleProcessMaterial
		m.color = Color(0.35, 0.22, 0.18, 0.8)
	elif weather == "snow":
		var m2 := snow.process_material as ParticleProcessMaterial
		m2.color = Color(0.96, 0.98, 1.0, 0.9)
	_wind_target = 0.85 if weather == "storm" else _rng.randf_range(0.2, 0.7)

func _lightning() -> void:
	var e := env.environment
	var old := e.ambient_light_energy
	e.ambient_light_energy = 4.0
	var tw := create_tween()
	tw.tween_interval(0.09)
	tw.tween_property(e, "ambient_light_energy", old, 0.45)
	Sfx.play("thunder", -4.0, _rng.randf_range(0.8, 1.2))

func _update_fog(delta: float) -> void:
	var b := GameState.current_biome
	var target: Dictionary = Const.BIOME_FOG.get(b, Const.BIOME_FOG[Const.Biome.MEADOWS])
	var tc: Color = target["c"]
	var td: float = target["d"]
	match weather:
		"rain": td *= 2.2; tc = tc.darkened(0.18)
		"storm": td *= 3.0; tc = tc.darkened(0.30)
		"mist": td *= 4.0
		"snow": td *= 2.4; tc = tc.lightened(0.12)
		"cloudy": td *= 1.4
		"ashfall": td *= 2.0; tc = tc.lerp(Color(0.5, 0.22, 0.12), 0.4)

	# 밤에는 안개가 짙어진다
	var night := 1.0 if GameState.is_night() else 0.0
	td *= lerpf(1.0, 1.7, night)

	var e := env.environment
	_fog_color = _fog_color.lerp(tc, delta * 0.7)
	_fog_density = lerpf(_fog_density, td, delta * 0.7)

	# 던전 안은 캄캄하다
	var pl := GameState.player
	if pl != null and is_instance_valid(pl) and pl.has_meta("in_dungeon"):
		e.fog_light_color = Color(0.16, 0.14, 0.12)
		e.fog_density = 0.026
		e.fog_sky_affect = 1.0
		# 높이 안개는 지하에서 무한히 짙어지므로 반드시 꺼야 한다
		e.fog_height = -2000.0
		e.fog_height_density = 0.0
		e.ambient_light_energy = 0.22
		sun.light_energy = 0.0
		moon.light_energy = 0.0
		return
	e.ambient_light_energy = 0.85
	e.fog_height = Const.WATER_LEVEL + 12.0
	e.fog_height_density = 0.02

	# 수중이면 완전히 다른 안개
	var cam := get_viewport().get_camera_3d()
	if cam != null and cam.global_position.y < Const.WATER_LEVEL:
		e.fog_light_color = Color(0.06, 0.16, 0.22)
		e.fog_density = 0.14
		e.fog_sky_affect = 1.0
	else:
		e.fog_light_color = _fog_color
		e.fog_density = _fog_density
		e.fog_sky_affect = 0.55
	e.volumetric_fog_albedo = _fog_color.lightened(0.2)

func _follow_player() -> void:
	var p := GameState.player
	if p == null or not is_instance_valid(p):
		return
	global_position = p.global_position
	rain.global_position = p.global_position + Vector3(0, 22, 0)
	snow.global_position = p.global_position + Vector3(0, 22, 0)

func _on_biome_changed(_b: int) -> void:
	# 바이옴이 바뀌면 날씨를 다시 굴릴 기회를 준다
	if weather_timer > 90.0:
		weather_timer = _rng.randf_range(20.0, 60.0)

func weather_name() -> String:
	return tr("WEATHER_" + weather.to_upper())
