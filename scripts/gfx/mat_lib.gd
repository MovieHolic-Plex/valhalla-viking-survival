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
var macro_tex: ImageTexture
var terrain_mat: ShaderMaterial
var water_mat: ShaderMaterial

# ─────────────────────────────────────────────── 셰이더 소스
const TERRAIN_SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D detail : filter_nearest, repeat_enable;   // 거친 픽셀 그레인
uniform sampler2D macro_tex : filter_linear, repeat_enable; // 부드러운 대형 얼룩
uniform float detail_scale = 0.30;
uniform float detail_power = 0.34;
// 암반: 따뜻한 흑갈색(0) ↔ 차갑고 밝은 화강암(1). COLOR.a 로 보간한다.
uniform vec3 rock_warm : source_color = vec3(0.215, 0.180, 0.145);
uniform vec3 rock_cool : source_color = vec3(0.395, 0.410, 0.445);
uniform vec3 dirt_col : source_color = vec3(0.205, 0.155, 0.105);

varying vec3 v_world;
varying vec3 v_norm;
varying float v_rock_t;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_norm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_rock_t = COLOR.a;
}

// UV 없이 삼면 투영으로 샘플링.
// 필터 힌트가 다른 샘플러를 한 함수에 넘길 수 없어 두 벌로 나눈다.
float tri_d(vec3 p, vec3 bw) {
	return texture(detail, p.yz).r * bw.x + texture(detail, p.xz).r * bw.y
		+ texture(detail, p.xy).r * bw.z;
}
// 대형 얼룩은 위에서 내려다본 XZ 평면 투영만 쓴다.
// 절벽에 늘어져 보이지만 그 위엔 어차피 암반색이 덮이고, 샘플 수가 1/3 이다.
float mac(vec2 p) {
	return texture(macro_tex, p).r;
}

void fragment() {
	vec3 bw = pow(abs(v_norm), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);

	float d  = tri_d(v_world * detail_scale, bw);       // 근거리 그레인
	float m1 = mac(v_world.xz * 0.013);           // 수십 m 단위 얼룩
	float m2 = mac(v_world.xz * 0.075);           // 수 m 단위 얼룩

	vec3 base = COLOR.rgb;
	// 대·중·소 세 단계 밝기 변주를 겹쳐 단색 평면을 깬다
	base *= mix(0.80, 1.16, m1);
	base *= mix(0.88, 1.10, m2);
	base *= mix(1.0, 0.58 + d * 0.88, detail_power);

	// 경사도에 따라 흙 → 암반. 두 단계로 나눠야 절벽 아래 흙띠가 생긴다.
	float slope = 1.0 - clamp(v_norm.y, 0.0, 1.0);
	vec3 rock = mix(rock_warm, rock_cool, clamp(v_rock_t, 0.0, 1.0));
	float dirt_amt = smoothstep(0.13, 0.33, slope) * (0.75 + m2 * 0.4);
	base = mix(base, dirt_col * mix(0.78, 1.30, d), clamp(dirt_amt, 0.0, 1.0));
	base = mix(base, rock * mix(0.70, 1.34, d), smoothstep(0.30, 0.58, slope));

	// 위를 향한 면일수록 하늘빛을 조금 더 받는다 (대기 산란 흉내)
	base *= mix(vec3(0.94, 0.95, 0.98), vec3(1.02, 1.01, 0.99), clamp(v_norm.y, 0.0, 1.0));

	ALBEDO = base;
	ROUGHNESS = mix(0.99, 0.80, slope);
	SPECULAR = 0.08;
	AO = mix(1.0, 0.72 + m2 * 0.28, 0.55);
	AO_LIGHT_AFFECT = 0.4;
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
uniform float wind = 0.5;        // 날씨에 따른 바람 세기
uniform float fade_start = 0.0;  // 0 이면 거리 페이드 없음
uniform float fade_end = 1.0;

varying vec3 v_world;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// 밑동은 고정, 위로 갈수록 크게 흔들리는 바람.
	// 큰 너울(돌풍)과 잔떨림을 겹쳐야 발헤임처럼 들판이 물결친다.
	float h = max(VERTEX.y, 0.0);
	float amp = sway * h * (1.0 - stiffness) * (0.45 + wind);
	float t = TIME * sway_speed;
	float gust = sin(t * 0.31 + wp.x * 0.035 + wp.z * 0.028) * 0.5 + 0.5;
	amp *= 0.55 + gust * 0.9;
	VERTEX.x += sin(t + wp.x * 0.35 + wp.z * 0.21) * amp;
	VERTEX.z += cos(t * 0.87 + wp.z * 0.31) * amp * 0.7;

	// 멀어지면 서서히 땅으로 가라앉혀 컬링 경계가 튀지 않게 한다
	if (fade_start > 0.0) {
		float dist = length((VIEW_MATRIX * vec4(wp, 1.0)).xyz);
		float f = 1.0 - clamp((dist - fade_start) / max(fade_end - fade_start, 1.0), 0.0, 1.0);
		VERTEX.y *= f;
	}
	v_world = wp;
}

void fragment() {
	vec3 p = v_world * 0.5;
	float d = texture(detail, p.xz + p.yy * 0.5).r;
	ALBEDO = tint.rgb * COLOR.rgb * mix(1.0, d * 1.5, 0.24);
	ROUGHNESS = 0.94;
	SPECULAR = 0.05;
	// 잎을 통과하는 빛 — 역광에서 잎이 환하게 살아난다
	BACKLIGHT = ALBEDO * 0.16;
}
"""

const WATER_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 shallow : source_color = vec4(0.135, 0.290, 0.290, 1.0);
uniform vec4 deep : source_color = vec4(0.012, 0.038, 0.062, 1.0);
uniform vec3 sun_dir = vec3(0.0, -1.0, 0.0);
uniform vec3 sun_col : source_color = vec3(1.0, 0.94, 0.82);
uniform vec3 sky_col : source_color = vec3(0.72, 0.82, 0.92);
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
	float d = clamp(dist / 26.0, 0.0, 1.0);

	vec3 col = mix(shallow.rgb, deep.rgb, d);

	// 얕은 곳은 바닥이 비쳐 보인다(간이 굴절)
	vec2 refr = NORMAL.xz * 0.022 * (1.0 - d);
	vec3 behind = texture(screen_tex, SCREEN_UV + refr).rgb;
	float clarity = 1.0 - clamp(dist / 10.0, 0.0, 1.0);
	col = mix(col, behind * mix(vec3(0.72, 0.90, 0.88), vec3(1.0), clarity), clarity * 0.80);

	// 해안선 거품 + 물마루 거품. 파도에 맞춰 해안 거품이 밀려왔다 빠진다.
	float tide = sin(TIME * 0.55 + v_world.x * 0.12 + v_world.z * 0.09) * 0.45 + 0.55;
	float shore = 1.0 - smoothstep(0.0, 0.7 + tide * 2.0, dist);
	shore *= shore;
	float crest = smoothstep(0.80, 1.30, v_wave);
	float foam = clamp(shore * 1.05 + crest * 0.40, 0.0, 0.92);
	col = mix(col, vec3(0.88, 0.93, 0.95), foam);

	// 태양 반사광 — 수면에 길게 늘어지는 윤슬
	vec3 vdir = normalize(VERTEX);
	vec3 n = normalize(NORMAL);
	vec3 sd = normalize(-(VIEW_MATRIX * vec4(normalize(sun_dir), 0.0)).xyz);
	float spec = pow(max(dot(reflect(-sd, n), -vdir), 0.0), 220.0);
	col += sun_col * spec * 1.8;

	// 프레넬 — 비스듬히 볼수록 하늘을 반사한다(슐릭 근사, F0=0.02).
	// 반사량을 0.45 로 묶지 않으면 먼 바다가 통째로 하얗게 뜬다.
	float ct = clamp(dot(n, -vdir), 0.0, 1.0);
	float fres = 0.02 + 0.98 * pow(1.0 - ct, 5.0);
	vec3 refl = mix(deep.rgb, sky_col * 0.72, 0.80);
	col = mix(col, refl, clamp(fres, 0.0, 1.0) * 0.45);

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
	# 대형 얼룩용 — 부드럽고 대비가 낮은 저주파 노이즈
	macro_tex = _make_noise(128, 2.0, 0.75, 7.0)
	_make_terrain_mat()
	_make_water_mat()

## 날씨 바람을 모든 식생 머티리얼에 반영한다
func set_wind(v: float) -> void:
	for m in _foliage_cache.values():
		m.set_shader_parameter("wind", v)

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
	terrain_mat.set_shader_parameter("macro_tex", macro_tex)
	terrain_mat.set_shader_parameter("detail_scale", 0.26)
	terrain_mat.set_shader_parameter("detail_power", 0.34)

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
func foliage(col: Color, stiffness: float = 0.0, sway: float = 0.06,
		fade_start: float = 0.0, fade_end: float = 1.0) -> ShaderMaterial:
	var key := "%s|%.2f|%.3f|%.0f|%.0f" % [col.to_html(), stiffness, sway,
		fade_start, fade_end]
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
	m.set_shader_parameter("fade_start", fade_start)
	m.set_shader_parameter("fade_end", fade_end)
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
