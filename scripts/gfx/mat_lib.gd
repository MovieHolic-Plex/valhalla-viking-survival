extends Node
## 머티리얼 · 셰이더 라이브러리. 오토로드 이름: MatLib
##
## 발헤임 룩의 핵심은 "저해상도 텍스처 + 고품질 라이팅/포그"다.
## 여기서는 32~64px 절차 노이즈 텍스처를 nearest 필터로 삼면 투영해
## 거친 픽셀감을 만들고, 나머지는 환경(포그/블룸/톤매핑)이 담당한다.

var _flat_cache: Dictionary = {}
var _foliage_cache: Dictionary = {}

var noise_tex: ImageTexture
var grain_tex: ImageTexture
var terrain_mat: ShaderMaterial
var water_mat: ShaderMaterial

# ─────────────────────────────────────────────── 셰이더 소스
const TERRAIN_SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D detail : filter_nearest, repeat_enable;
uniform float detail_scale = 0.35;
uniform float detail_power = 0.30;
uniform vec3 snow_tint = vec3(0.92, 0.95, 1.0);

varying vec3 v_world;
varying vec3 v_norm;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_norm = NORMAL;
}

void fragment() {
	// 삼면 투영(triplanar)으로 UV 없이 디테일을 입힌다
	vec3 bw = abs(normalize(v_norm));
	bw = pow(bw, vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec3 p = v_world * detail_scale;
	float d =
		texture(detail, p.yz).r * bw.x +
		texture(detail, p.xz).r * bw.y +
		texture(detail, p.xy).r * bw.z;
	d = mix(1.0, d * 1.6, detail_power);

	vec3 base = COLOR.rgb * d;
	// 가파른 경사는 흙/바위색으로 어둡게 (발헤임의 절벽 느낌)
	float slope = 1.0 - clamp(v_norm.y, 0.0, 1.0);
	base = mix(base, base * vec3(0.62, 0.56, 0.50), smoothstep(0.35, 0.75, slope));

	ALBEDO = base;
	ROUGHNESS = 0.95;
	SPECULAR = 0.12;
}
"""

const FOLIAGE_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec4 tint : source_color = vec4(0.3, 0.5, 0.2, 1.0);
uniform sampler2D detail : filter_nearest, repeat_enable;
uniform float sway = 0.06;
uniform float sway_speed = 1.1;
uniform float stiffness = 0.0;   // 0 = 잎(잘 흔들림), 1 = 줄기

varying vec3 v_world;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// 밑동은 고정, 위로 갈수록 크게 흔들리는 바람
	float h = max(VERTEX.y, 0.0);
	float amp = sway * h * (1.0 - stiffness);
	float t = TIME * sway_speed;
	VERTEX.x += sin(t + wp.x * 0.35 + wp.z * 0.21) * amp;
	VERTEX.z += cos(t * 0.87 + wp.z * 0.31) * amp * 0.7;
	v_world = wp;
}

void fragment() {
	vec3 p = v_world * 0.5;
	float d = texture(detail, p.xz + p.yy * 0.5).r;
	ALBEDO = tint.rgb * COLOR.rgb * mix(1.0, d * 1.5, 0.28);
	ROUGHNESS = 0.9;
	SPECULAR = 0.08;
}
"""

const WATER_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 shallow : source_color = vec4(0.16, 0.40, 0.42, 1.0);
uniform vec4 deep : source_color = vec4(0.02, 0.08, 0.16, 1.0);
uniform vec3 sun_dir = vec3(0.0, -1.0, 0.0);
uniform vec3 sun_col : source_color = vec3(1.0, 0.94, 0.82);
uniform float wave_h = 0.30;
uniform float wave_speed = 0.55;
uniform float choppy = 1.0;              // 날씨에 따른 파고
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 v_world;
varying float v_wave;

// 서로 다른 방향의 사인파를 겹쳐 자연스러운 너울을 만든다
float wv(vec2 p, float t) {
	return sin(p.x * 0.16 + t) * 0.50
		 + sin(p.y * 0.21 - t * 1.3) * 0.35
		 + sin((p.x + p.y) * 0.09 + t * 0.7) * 0.40
		 + sin((p.x - p.y) * 0.33 - t * 1.9) * 0.16
		 + sin(p.x * 0.71 + t * 2.4) * 0.07;
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float w = wv(wp.xz, t);
	VERTEX.y += w * wave_h * choppy;
	v_wave = w;
	v_world = wp;
	float e = 1.2;
	float hx = wv(wp.xz + vec2(e, 0.0), t) - w;
	float hz = wv(wp.xz + vec2(0.0, e), t) - w;
	NORMAL = normalize(vec3(-hx * wave_h * choppy, e * 0.55, -hz * wave_h * choppy));
}

void fragment() {
	// 화면 깊이로 수심을 구해 색과 거품을 결정한다
	float depth_raw = texture(depth_tex, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	float scene_z = -(upos.z / upos.w);
	float water_z = -VERTEX.z;
	float dist = max(scene_z - water_z, 0.0);
	float d = clamp(dist / 14.0, 0.0, 1.0);

	vec3 col = mix(shallow.rgb, deep.rgb, d);

	// 얕은 곳은 바닥이 비쳐 보인다(간이 굴절)
	vec2 refr = NORMAL.xz * 0.022 * (1.0 - d);
	vec3 behind = texture(screen_tex, SCREEN_UV + refr).rgb;
	float clarity = 1.0 - clamp(dist / 5.0, 0.0, 1.0);
	col = mix(col, behind * mix(vec3(0.75, 0.92, 0.90), vec3(1.0), clarity), clarity * 0.7);

	// 해안선 거품 + 물마루 거품
	float shore = 1.0 - smoothstep(0.0, 1.6, dist);
	float crest = smoothstep(0.85, 1.25, v_wave);
	float foam = clamp(shore * 0.85 + crest * 0.45, 0.0, 0.9);
	col = mix(col, vec3(0.93, 0.97, 0.99), foam);

	// 태양 반사광 — 수면에 길게 늘어지는 윤슬
	vec3 vdir = normalize(VERTEX);
	vec3 n = normalize(NORMAL);
	vec3 sd = normalize(-(VIEW_MATRIX * vec4(normalize(sun_dir), 0.0)).xyz);
	float spec = pow(max(dot(reflect(-sd, n), -vdir), 0.0), 220.0);
	col += sun_col * spec * 1.8;

	// 프레넬 — 비스듬히 볼수록 하늘을 반사한다
	float fres = pow(1.0 - clamp(dot(n, -vdir), 0.0, 1.0), 4.0);
	col = mix(col, mix(shallow.rgb, vec3(0.72, 0.82, 0.92), 0.65), fres * 0.55);

	ALBEDO = col;
	ROUGHNESS = mix(0.02, 0.14, foam);
	METALLIC = 0.0;
	SPECULAR = 0.6;
	ALPHA = 1.0;
}
"""

## 건축 미리보기(반투명 유령) 셰이더
const GHOST_SHADER := """
shader_type spatial;
render_mode cull_disabled, unshaded, blend_add, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.3, 1.0, 0.4, 1.0);
void fragment() {
	ALBEDO = tint.rgb * 0.55;
	ALPHA = 0.55;
}
"""

func _ready() -> void:
	noise_tex = _make_noise(64, 3.0, 0.55, 1.0)
	# 그레인은 색을 어둡게 하지 않도록 0.8~1.0 범위로 만든다
	grain_tex = _make_noise(24, 5.0, 0.85, 1.0, 0.78)
	_make_terrain_mat()
	_make_water_mat()

# ─────────────────────────────────────────────── 절차 텍스처
func _make_noise(size: int, freq: float, contrast: float, seed_v: float,
		lo: float = 0.0) -> ImageTexture:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq / float(size)
	n.seed = int(seed_v * 1337.0)
	n.fractal_octaves = 3
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			# 심리스 타일링: 도넛 좌표로 4D 대신 두 방향 블렌드
			var a := n.get_noise_2d(float(x), float(y))
			var b := n.get_noise_2d(float(x - size), float(y))
			var c := n.get_noise_2d(float(x), float(y - size))
			var d := n.get_noise_2d(float(x - size), float(y - size))
			var fx := float(x) / float(size)
			var fy := float(y) / float(size)
			var v: float = lerp(lerp(a, b, fx), lerp(c, d, fx), fy)
			v = clampf(0.5 + v * contrast, 0.0, 1.0)
			v = lo + (1.0 - lo) * v
			img.set_pixel(x, y, Color(v, v, v))
	var t := ImageTexture.create_from_image(img)
	return t

func _make_terrain_mat() -> void:
	var sh := Shader.new()
	sh.code = TERRAIN_SHADER
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = sh
	terrain_mat.set_shader_parameter("detail", noise_tex)
	terrain_mat.set_shader_parameter("detail_scale", 0.30)
	terrain_mat.set_shader_parameter("detail_power", 0.42)

func _make_water_mat() -> void:
	var sh := Shader.new()
	sh.code = WATER_SHADER
	water_mat = ShaderMaterial.new()
	water_mat.shader = sh
	water_mat.render_priority = 1

# ─────────────────────────────────────────────── 머티리얼 팩토리
## 단색 로우폴리 머티리얼 (버텍스 컬러 곱)
func flat(col: Color, rough: float = 0.92, metal: float = 0.0, emis: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [col.to_html(), rough, metal, emis]
	if _flat_cache.has(key):
		return _flat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	m.vertex_color_use_as_albedo = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.albedo_texture = grain_tex
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.45, 0.45, 0.45)
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emis
	_flat_cache[key] = m
	return m

## 바람에 흔들리는 잎/풀 머티리얼
func foliage(col: Color, stiffness: float = 0.0, sway: float = 0.06) -> ShaderMaterial:
	var key := "%s|%.2f|%.3f" % [col.to_html(), stiffness, sway]
	if _foliage_cache.has(key):
		return _foliage_cache[key]
	var sh := Shader.new()
	sh.code = FOLIAGE_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("detail", grain_tex)
	m.set_shader_parameter("stiffness", stiffness)
	m.set_shader_parameter("sway", sway)
	_foliage_cache[key] = m
	return m

func ghost(col: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = GHOST_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tint", col)
	return m

## 발광 머티리얼 (불꽃, 마법, 광석 반짝임)
func glow(col: Color, energy: float = 2.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

## 반투명 (물보라, 안개 파티클, 유령)
func translucent(col: Color, alpha: float = 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var c := col
	c.a = alpha
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
