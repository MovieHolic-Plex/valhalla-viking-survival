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

// 발헤임 룩의 핵심: 저해상도 픽셀 텍스처 4장을 경사/고도로 스플랫하고
// 조명·안개가 나머지를 담당한다. 단색 버텍스 컬러만으로는 이 느낌이 안 난다.
uniform sampler2D tex_grass : filter_nearest, repeat_enable;
uniform sampler2D tex_dirt  : filter_nearest, repeat_enable;
uniform sampler2D tex_rock  : filter_nearest, repeat_enable;
uniform sampler2D tex_snow  : filter_nearest, repeat_enable;
uniform sampler2D macro_tex : filter_linear, repeat_enable;

uniform float tex_scale = 0.55;    // 1m 당 텍셀 밀도 (클수록 촘촘)
uniform float wetness = 0.0;
uniform vec3 rock_warm : source_color = vec3(0.285, 0.245, 0.200);
uniform vec3 rock_cool : source_color = vec3(0.395, 0.410, 0.445);
uniform vec3 dirt_col : source_color = vec3(0.285, 0.215, 0.145);

varying vec3 v_world;
varying vec3 v_norm;
varying float v_rock_t;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_norm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_rock_t = COLOR.a;
}

// 삼면 투영 — 절벽에서도 텍스처가 늘어지지 않는다
vec3 tri3(sampler2D t, vec3 p, vec3 bw) {
	return texture(t, p.yz).rgb * bw.x + texture(t, p.xz).rgb * bw.y
		+ texture(t, p.xy).rgb * bw.z;
}
float mac(vec2 p) { return texture(macro_tex, p).r; }

void fragment() {
	vec3 bw = pow(abs(v_norm), vec3(4.0));
	bw /= (bw.x + bw.y + bw.z);
	vec3 p = v_world * tex_scale;
	// 두 배율을 겹쳐 타일 반복이 눈에 띄지 않게 한다
	vec3 p2 = v_world * (tex_scale * 0.23);

	float m1 = mac(v_world.xz * 0.013);
	float m2 = mac(v_world.xz * 0.075);
	float slope = 1.0 - clamp(v_norm.y, 0.0, 1.0);
	float snowy = clamp(v_rock_t, 0.0, 1.0);

	vec3 g = tri3(tex_grass, p, bw) * (0.72 + tri3(tex_grass, p2, bw).g * 0.55);
	vec3 d = tri3(tex_dirt, p, bw);
	vec3 r = tri3(tex_rock, p * 0.6, bw);
	vec3 sn = tri3(tex_snow, p * 0.7, bw);

	// 지면 = 바이옴 색(버텍스) x 잔디 텍스처
	vec3 base = COLOR.rgb * g * 1.30;
	base *= mix(0.84, 1.14, m1);        // 큰 스케일 얼룩

	// 경사 → 흙 → 암반 2단 블렌드
	float dirt_amt = smoothstep(0.30, 0.54, slope) * (0.75 + m2 * 0.4);
	base = mix(base, dirt_col * d * 1.75, clamp(dirt_amt, 0.0, 1.0));
	vec3 rock_c = mix(rock_warm, rock_cool, snowy);
	base = mix(base, rock_c * r * 1.85, smoothstep(0.52, 0.78, slope));

	// 설산: 완만한 면에만 눈이 쌓인다.
	// snowy 는 암반 색 파라미터를 겸하므로 1.0 에 가까울 때(설산)만 눈으로 친다.
	float snow_amt = smoothstep(0.86, 1.0, snowy) * smoothstep(0.55, 0.20, slope);
	base = mix(base, sn * vec3(0.86, 0.90, 0.96), snow_amt);

	// 젖은 땅
	float puddle = wetness * (1.0 - smoothstep(0.02, 0.16, slope))
		* smoothstep(0.35, 0.75, m2);
	base *= mix(1.0, 0.64, wetness * 0.85);
	base = mix(base, base * 0.55, puddle);

	ALBEDO = base;
	ROUGHNESS = mix(mix(0.98, 0.82, slope), 0.14, max(wetness * 0.55, puddle));
	SPECULAR = mix(0.08, 0.55, max(wetness * 0.7, puddle));
	AO = mix(1.0, 0.74 + m2 * 0.26, 0.5);
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

const LEAFCARD_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, depth_prepass_alpha;

// 알파가 뚫린 잎 텍스처를 붙인 카드. 발헤임 나뭇잎의 실루엣이 여기서 나온다.
uniform sampler2D leaf_tex : filter_nearest;
uniform float sway = 0.05;
uniform float wind = 0.5;
uniform float alpha_cut = 0.45;

varying vec3 v_world;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * 1.1;
	float gust = sin(t * 0.31 + wp.x * 0.035 + wp.z * 0.028) * 0.5 + 0.5;
	float amp = sway * (0.45 + wind) * (0.55 + gust * 0.9);
	VERTEX.x += sin(t + wp.x * 0.3 + wp.z * 0.2) * amp;
	VERTEX.z += cos(t * 0.87 + wp.z * 0.31) * amp * 0.7;
	v_world = wp;
}

void fragment() {
	vec4 t = texture(leaf_tex, UV);
	if (t.a < alpha_cut) discard;
	ALBEDO = COLOR.rgb * t.rgb * 1.35;
	ROUGHNESS = 0.95;
	SPECULAR = 0.04;
	BACKLIGHT = ALBEDO * 0.30;
}
"""

const WATER_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;

uniform vec4 shallow : source_color = vec4(0.150, 0.310, 0.305, 1.0);
uniform vec4 deep : source_color = vec4(0.045, 0.105, 0.135, 1.0);
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

	// 깊은 물이 새까맣게 죽지 않도록 하늘빛 산란을 조금 더한다.
	// 물리적으로는 다중산란에 해당하고, 없으면 위에서 내려다본 호수가 검게 보인다.
	col += sky_col * 0.16 * d;

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
	if _leaf_mat != null:
		_leaf_mat.set_shader_parameter("wind", v)

## 비에 젖은 정도(0~1)를 지형에 반영한다
func set_wetness(v: float) -> void:
	if terrain_mat != null:
		terrain_mat.set_shader_parameter("wetness", v)

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
	terrain_mat.set_shader_parameter("tex_grass", TexLib.get_tex("grass"))
	terrain_mat.set_shader_parameter("tex_dirt", TexLib.get_tex("dirt"))
	terrain_mat.set_shader_parameter("tex_rock", TexLib.get_tex("rock"))
	terrain_mat.set_shader_parameter("tex_snow", TexLib.get_tex("snow"))
	terrain_mat.set_shader_parameter("macro_tex", macro_tex)
	terrain_mat.set_shader_parameter("tex_scale", 0.55)

func _make_water_mat() -> void:
	var sh := Shader.new()
	sh.code = WATER_SHADER
	water_mat = ShaderMaterial.new()
	water_mat.shader = sh
	water_mat.render_priority = 1

# ─────────────────────────────────────────────── 머티리얼 팩토리
## 단색 로우폴리 머티리얼 (버텍스 컬러 곱)
func flat(col: Color, rough: float = 0.92, metal: float = 0.0, emis: float = 0.0,
		tex: String = "") -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f|%s" % [col.to_html(), rough, metal, emis, tex]
	if _flat_cache.has(key):
		return _flat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	m.vertex_color_use_as_albedo = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	# 재질을 지정하면 저해상도 픽셀 텍스처를 삼면 투영으로 입힌다.
	# 지정이 없으면 기존처럼 은은한 그레인만 얹는다.
	if tex != "":
		m.albedo_texture = TexLib.get_tex(tex)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(1.1, 1.1, 1.1)
	else:
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

## 잎 카드 머티리얼 (알파 컷 + 바람). 캐시해 한 벌만 쓴다.
var _leaf_mat: ShaderMaterial = null
func leaf_card() -> ShaderMaterial:
	if _leaf_mat != null:
		return _leaf_mat
	var sh := Shader.new()
	sh.code = LEAFCARD_SHADER
	_leaf_mat = ShaderMaterial.new()
	_leaf_mat.shader = sh
	_leaf_mat.set_shader_parameter("leaf_tex", TexLib.get_tex("leaf"))
	_leaf_mat.set_shader_parameter("sway", 0.045)
	return _leaf_mat

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
