class_name Ambience
extends Node3D
## 바이옴별 공중 부유물 — 꽃가루, 반딧불이, 재, 안개 조각.
##
## 발헤임 화면이 "살아 있는" 이유의 큰 부분이 이 미세 파티클이다.
## 텅 빈 공기를 채워 거리감과 스케일을 만든다. 플레이어를 따라다닌다.

## 바이옴 → {색, 개수, 크기, 상승속도, 발광, 밤전용}
const SPEC := {
	Const.Biome.MEADOWS: {
		"c": Color(1.0, 0.94, 0.66), "n": 90, "s": 0.045, "rise": 0.22,
		"glow": 1.6, "night": false, "box": Vector3(26, 9, 26),
	},
	Const.Biome.BLACKFOREST: {
		"c": Color(0.72, 0.90, 0.62), "n": 70, "s": 0.040, "rise": 0.14,
		"glow": 2.2, "night": false, "box": Vector3(22, 8, 22),
	},
	Const.Biome.SWAMP: {
		"c": Color(0.62, 0.86, 0.55), "n": 55, "s": 0.055, "rise": 0.10,
		"glow": 3.0, "night": false, "box": Vector3(24, 6, 24),
	},
	Const.Biome.PLAINS: {
		"c": Color(1.0, 0.90, 0.55), "n": 80, "s": 0.045, "rise": 0.30,
		"glow": 1.4, "night": false, "box": Vector3(28, 9, 28),
	},
	Const.Biome.MOUNTAIN: {
		"c": Color(0.92, 0.96, 1.0), "n": 60, "s": 0.050, "rise": -0.05,
		"glow": 1.0, "night": false, "box": Vector3(26, 10, 26),
	},
	Const.Biome.MISTLANDS: {
		"c": Color(0.66, 0.72, 0.80), "n": 70, "s": 0.090, "rise": 0.06,
		"glow": 0.9, "night": false, "box": Vector3(22, 8, 22),
	},
	Const.Biome.ASHLANDS: {
		"c": Color(1.0, 0.44, 0.14), "n": 80, "s": 0.050, "rise": 0.55,
		"glow": 4.0, "night": false, "box": Vector3(26, 12, 26),
	},
}

var _parts: GPUParticles3D
var _mat: ParticleProcessMaterial
var _draw: StandardMaterial3D
var _biome := -1

func _ready() -> void:
	name = "ambience"
	_parts = GPUParticles3D.new()
	_parts.amount = 90
	_parts.lifetime = 9.0
	_parts.preprocess = 6.0
	_parts.local_coords = false
	_parts.visibility_aabb = AABB(Vector3(-40, -20, -40), Vector3(80, 60, 80))
	_parts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	_mat = ParticleProcessMaterial.new()
	_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_mat.emission_box_extents = Vector3(26, 9, 26)
	_mat.direction = Vector3(0, 1, 0)
	_mat.spread = 180.0
	_mat.initial_velocity_min = 0.05
	_mat.initial_velocity_max = 0.28
	_mat.gravity = Vector3(0, 0.2, 0)
	_mat.damping_min = 0.1
	_mat.damping_max = 0.4
	_mat.scale_min = 0.5
	_mat.scale_max = 1.6
	# 위아래로 살랑거리게 — 일직선으로 뜨면 눈에 거슬린다
	_mat.turbulence_enabled = true
	_mat.turbulence_noise_strength = 0.35
	_mat.turbulence_noise_scale = 2.0
	# 나타났다 사라지도록 알파 곡선
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.25, Color(1, 1, 1, 1))
	grad.add_point(0.75, Color(1, 1, 1, 1))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	_mat.color_ramp = gt
	_parts.process_material = _mat

	var qm := QuadMesh.new()
	qm.size = Vector2.ONE
	_parts.draw_pass_1 = qm

	_draw = StandardMaterial3D.new()
	_draw.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_draw.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_draw.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_draw.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	# 빌보드는 기본적으로 스케일을 무시한다. 이걸 켜지 않으면 모든 입자가
	# 1m 짜리 사각형으로 그려진다.
	_draw.billboard_keep_scale = true
	# 네모난 판때기가 보이지 않도록 부드러운 원형 알파를 입힌다
	_draw.albedo_texture = _dot_texture()
	_draw.vertex_color_use_as_albedo = true
	_draw.cull_mode = BaseMaterial3D.CULL_DISABLED
	_draw.disable_receive_shadows = true
	_draw.no_depth_test = false
	_parts.material_override = _draw
	add_child(_parts)

## 가운데가 밝고 가장자리가 투명한 작은 점 텍스처
func _dot_texture(size: int = 32) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(float(x) - c, float(y) - c).length() / (c + 0.001)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

	_apply(Const.Biome.MEADOWS)
	GameState.biome_changed.connect(_apply)

func _apply(biome: int) -> void:
	if biome == _biome:
		return
	_biome = biome
	var s = SPEC.get(biome)
	if s == null:
		_parts.emitting = false
		return
	_parts.emitting = true
	_parts.amount = int(s["n"])
	var box: Vector3 = s["box"]
	_mat.emission_box_extents = box
	_mat.gravity = Vector3(0, float(s["rise"]) * 0.6, 0)
	_mat.initial_velocity_max = maxf(absf(float(s["rise"])) * 1.2, 0.12)
	var col: Color = s["c"]
	col.a = 0.55
	_mat.color = col
	var sz: float = float(s["s"])
	_mat.scale_min = sz * 0.5
	_mat.scale_max = sz * 1.6
	_draw.albedo_color = col
	_draw.emission_enabled = true
	_draw.emission = Color(col.r, col.g, col.b)
	_draw.emission_energy_multiplier = float(s["glow"])
	_parts.visibility_aabb = AABB(-box * 1.5, box * 3.0)
	_parts.restart()

func _process(_delta: float) -> void:
	var p := GameState.player
	if p == null or not is_instance_valid(p):
		return
	# 지하에서는 끈다
	var under := p.has_meta("in_dungeon")
	_parts.emitting = not under and SPEC.has(_biome)
	if not under:
		global_position = p.global_position + Vector3(0, 2.0, 0)
