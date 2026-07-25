class_name WorldGen
extends RefCounted
## 시드 기반 절차적 세계 생성기.
## 같은 시드는 언제나 같은 지형·바이옴·자원 배치를 만든다(결정적).

var seed_value: int = 0

## 지형 변형(괭이/곡괭이) — 1m 격자의 높이 보정치
var mods: Dictionary = {}          # Vector2i -> float
var mod_chunks: Dictionary = {}    # Vector2i(청크) -> true

var _cont: FastNoiseLite      # 대륙 형태
var _hill: FastNoiseLite      # 언덕
var _det: FastNoiseLite       # 잔디테일
var _mtn: FastNoiseLite       # 산맥
var _biome: FastNoiseLite     # 바이옴 경계 흔들기
var _swamp: FastNoiseLite     # 늪 패치
var _forest: FastNoiseLite    # 숲 밀도

func _init(sv: int = 0) -> void:
	seed_value = sv
	_cont = _mk(sv + 1, 0.00085, 5, FastNoiseLite.TYPE_SIMPLEX)
	_hill = _mk(sv + 2, 0.0075, 3, FastNoiseLite.TYPE_SIMPLEX)
	_det = _mk(sv + 3, 0.045, 2, FastNoiseLite.TYPE_SIMPLEX)
	_mtn = _mk(sv + 4, 0.0016, 3, FastNoiseLite.TYPE_SIMPLEX)
	_biome = _mk(sv + 5, 0.0021, 2, FastNoiseLite.TYPE_SIMPLEX)
	_swamp = _mk(sv + 6, 0.0019, 2, FastNoiseLite.TYPE_SIMPLEX)
	_forest = _mk(sv + 7, 0.012, 2, FastNoiseLite.TYPE_SIMPLEX)

static func _mk(sv: int, freq: float, oct: int, type: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = sv
	n.frequency = freq
	n.noise_type = type
	n.fractal_octaves = oct
	return n

# ─────────────────────────────────────────────────────── 높이
func height(x: float, z: float) -> float:
	var h := base_height(x, z)
	if not mods.is_empty():
		h += mod_at(x, z)
	return h

## 플레이어가 손댄 적 없는 원본 지형 높이
func base_height(x: float, z: float) -> float:
	var d := sqrt(x * x + z * z)
	var rn := d / Const.WORLD_RADIUS

	# 섬 마스크: 바깥으로 갈수록 바다로 잠긴다
	var mask := 1.0 - smoothstep(0.74, 1.02, rn)

	var c := _cont.get_noise_2d(x, z)                       # -1..1
	var land := (c * 0.5 + 0.5) * 0.80 + 0.30               # 0.30..1.10
	land *= mask

	var h := Const.WATER_LEVEL + (land - 0.545) * 98.0
	h += _hill.get_noise_2d(x, z) * 6.0 * mask
	h += _det.get_noise_2d(x, z) * 1.6

	# 산맥: 능선 노이즈를 더해 뾰족하게
	var mn := _mtn.get_noise_2d(x, z)
	var m := smoothstep(0.28, 0.72, mn)
	if m > 0.0:
		var ridge := 1.0 - absf(_hill.get_noise_2d(x * 0.6 + 700.0, z * 0.6 - 400.0))
		h += m * mask * (55.0 + 105.0 * ridge)

	# 늪은 해수면 바로 위로 평탄화
	var sw := _swamp_factor(x, z, rn)
	if sw > 0.0:
		var target := Const.WATER_LEVEL + 0.6
		h = lerp(h, target + _det.get_noise_2d(x, z) * 1.1, sw * 0.85)

	# 평원은 완만하게
	if rn > 0.44 and rn < 0.64 and h > Const.WATER_LEVEL:
		var pf := smoothstep(0.44, 0.50, rn) * (1.0 - smoothstep(0.60, 0.64, rn))
		h = lerp(h, Const.WATER_LEVEL + 6.0 + _hill.get_noise_2d(x, z) * 4.0, pf * 0.55)

	# 바다는 더 깊게 파서 수영/항해가 성립하도록
	if h < Const.WATER_LEVEL:
		h = Const.WATER_LEVEL - (Const.WATER_LEVEL - h) * 1.35 - 1.5

	# 월드 가장자리는 확실히 바다
	if rn > 1.0:
		h = minf(h, Const.WATER_LEVEL - 30.0 - (rn - 1.0) * 200.0)
	return h

## 1m 격자 보정치를 이중선형 보간해 매끄럽게 이어붙인다
func mod_at(x: float, z: float) -> float:
	var fx: float = floor(x)
	var fz: float = floor(z)
	var tx: float = x - fx
	var tz: float = z - fz
	var ix := int(fx)
	var iz := int(fz)
	var m00: float = float(mods.get(Vector2i(ix, iz), 0.0))
	var m10: float = float(mods.get(Vector2i(ix + 1, iz), 0.0))
	var m01: float = float(mods.get(Vector2i(ix, iz + 1), 0.0))
	var m11: float = float(mods.get(Vector2i(ix + 1, iz + 1), 0.0))
	return lerp(lerp(m00, m10, tx), lerp(m01, m11, tx), tz)

## 지형 변형 적용. mode: "level"(평탄화) / "raise"(융기) / "dig"(굴착)
## 반환: 갱신이 필요한 청크 키 목록
func modify(center: Vector3, radius: float, mode: String,
		amount: float = 0.5) -> Array:
	var touched: Dictionary = {}
	var r := int(ceil(radius)) + 1
	var cx := int(round(center.x))
	var cz := int(round(center.z))
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var gx := cx + dx
			var gz := cz + dz
			var d := sqrt(float(dx * dx + dz * dz))
			if d > radius:
				continue
			var falloff: float = 1.0 - smoothstep(radius * 0.45, radius, d)
			var key := Vector2i(gx, gz)
			var cur: float = float(mods.get(key, 0.0))
			var base := base_height(float(gx), float(gz))
			var now := base + cur
			var want := now
			match mode:
				"level":
					want = lerp(now, center.y, falloff)
				"raise":
					want = now + amount * falloff
				"dig":
					want = now - amount * falloff
			# 원본 대비 ±12m 로 제한 (지형이 무한히 솟거나 꺼지는 것 방지)
			var delta: float = clampf(want - base, -12.0, 12.0)
			if absf(delta) < 0.001:
				mods.erase(key)
			else:
				mods[key] = delta
			var ck := Vector2i(int(floor(float(gx) / Const.CHUNK_SIZE)),
				int(floor(float(gz) / Const.CHUNK_SIZE)))
			touched[ck] = true
			mod_chunks[ck] = true
			# 청크 경계에 걸친 지점은 이웃 청크도 갱신해야 이음매가 안 생긴다
			for ox in [-1, 1]:
				var ck2 := Vector2i(int(floor((float(gx) + float(ox)) / Const.CHUNK_SIZE)),
					int(floor(float(gz) / Const.CHUNK_SIZE)))
				touched[ck2] = true
			for oz in [-1, 1]:
				var ck3 := Vector2i(int(floor(float(gx) / Const.CHUNK_SIZE)),
					int(floor((float(gz) + float(oz)) / Const.CHUNK_SIZE)))
				touched[ck3] = true
	return touched.keys()

## 바이옴별 던전 입구 위치를 결정적으로 고른다
func dungeon_sites(biome: int, count: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 977 + biome * 131 + 7
	var out: Array = []
	var guard := 0
	while out.size() < count and guard < 20000:
		guard += 1
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * Const.WORLD_RADIUS * 0.95
		var x := cos(a) * d
		var z := sin(a) * d
		var h := base_height(x, z)
		if h < Const.WATER_LEVEL + 2.0:
			continue
		if biome_from(x, z, h) != biome:
			continue
		if slope_at(x, z) > 0.30:
			continue
		# 서로 너무 가깝지 않게
		var ok := true
		for p in out:
			if Vector2(p.x - x, p.z - z).length() < 220.0:
				ok = false
				break
		if ok:
			out.append(Vector3(x, h, z))
	return out

func mods_to_array() -> Array:
	var out: Array = []
	for k in mods:
		out.append([k.x, k.y, float(mods[k])])
	return out

func mods_from_array(arr) -> void:
	mods.clear()
	mod_chunks.clear()
	if not (arr is Array):
		return
	for e in arr:
		if e is Array and e.size() == 3:
			var key := Vector2i(int(e[0]), int(e[1]))
			mods[key] = float(e[2])
			mod_chunks[Vector2i(int(floor(float(key.x) / Const.CHUNK_SIZE)),
				int(floor(float(key.y) / Const.CHUNK_SIZE)))] = true

func _swamp_factor(x: float, z: float, rn: float) -> float:
	if rn < 0.24 or rn > 0.60:
		return 0.0
	var s := _swamp.get_noise_2d(x + 3000.0, z - 2000.0)
	var band := smoothstep(0.24, 0.30, rn) * (1.0 - smoothstep(0.52, 0.60, rn))
	return smoothstep(0.28, 0.55, s) * band

# ─────────────────────────────────────────────────────── 바이옴
func biome_at(x: float, z: float) -> int:
	var h := height(x, z)
	return biome_from(x, z, h)

func biome_from(x: float, z: float, h: float) -> int:
	if h < Const.WATER_LEVEL - 0.5:
		return Const.Biome.OCEAN

	var d := sqrt(x * x + z * z)
	var rn := d / Const.WORLD_RADIUS
	var jitter := _biome.get_noise_2d(x, z) * 0.075
	var r := rn + jitter

	# 산악은 고도 우선 (단, 시작 지역 근처는 제외해 초반 난이도를 지킨다)
	if h > Const.WATER_LEVEL + 62.0 and rn > 0.16:
		return Const.Biome.MOUNTAIN

	if _swamp_factor(x, z, rn) > 0.45 and h < Const.WATER_LEVEL + 6.0:
		return Const.Biome.SWAMP

	if r < 0.145:
		return Const.Biome.MEADOWS
	elif r < 0.315:
		return Const.Biome.BLACKFOREST
	elif r < 0.455:
		# 늪 지대 사이의 마른 땅은 검은 숲이 이어진다
		return Const.Biome.SWAMP if _swamp_factor(x, z, rn) > 0.18 else Const.Biome.BLACKFOREST
	elif r < 0.645:
		return Const.Biome.PLAINS
	elif r < 0.835:
		return Const.Biome.MISTLANDS
	else:
		return Const.Biome.ASHLANDS

## 지면 색 — 바이옴 색 + 미세 변주 + 고도/경사 반영
func ground_color(x: float, z: float, h: float, biome: int) -> Color:
	var base: Color = Const.BIOME_GROUND[biome]
	# 큰 스케일 얼룩(마른 풀 ↔ 짙은 이끼) + 잔 변주. 단색 평면을 깨는 핵심.
	var macro := _det.get_noise_2d(x * 0.09, z * 0.09)
	var v := _det.get_noise_2d(x * 0.5, z * 0.5) * 0.045
	var c := Color(base.r + v, base.g + v, base.b + v * 0.8)
	if macro > 0.0:
		# 볕에 마른 부분 — 노랗고 밝게
		c = c.lerp(Color(c.r * 1.55 + 0.045, c.g * 1.30 + 0.030, c.b * 0.80), macro * 0.55)
	else:
		# 그늘진 부분 — 어둡고 푸르게
		c = c.lerp(Color(c.r * 0.62, c.g * 0.74, c.b * 0.80), -macro * 0.50)

	# 해안선 모래 — 물속 얕은 바닥까지 이어져야 물가가 시커먼 띠로 보이지 않는다
	if biome != Const.Biome.MOUNTAIN and h < Const.WATER_LEVEL + 1.8:
		var t := clampf((Const.WATER_LEVEL + 1.8 - h) / 2.6, 0.0, 1.0)
		c = c.lerp(Color(0.52, 0.46, 0.33), t * 0.94)
		# 더 깊어지면 서서히 어두운 뻘색으로
		if h < Const.WATER_LEVEL - 3.0:
			var t2 := clampf((Const.WATER_LEVEL - 3.0 - h) / 14.0, 0.0, 1.0)
			c = c.lerp(Color(0.26, 0.25, 0.20), t2)
	# 눈은 설산 바이옴에서만 — 그 외 고지대는 바위색으로 살짝 바랜다
	if biome == Const.Biome.MOUNTAIN:
		var t2 := clampf((h - (Const.WATER_LEVEL + 46.0)) / 22.0, 0.0, 1.0)
		c = Color(0.40, 0.43, 0.47).lerp(Color(0.84, 0.87, 0.93), t2)
	elif h > Const.WATER_LEVEL + 110.0:
		# 아주 높은 곳만 바위색이 비친다
		var t3 := clampf((h - (Const.WATER_LEVEL + 110.0)) / 50.0, 0.0, 1.0)
		c = c.lerp(Color(0.34, 0.32, 0.29), t3 * 0.5)
	# 애쉬랜드의 용암빛 균열
	if biome == Const.Biome.ASHLANDS:
		var g := _forest.get_noise_2d(x, z)
		if g > 0.55:
			c = c.lerp(Color(1.0, 0.35, 0.08), (g - 0.55) * 2.0)
	# 알파 = 암반 색 파라미터. 지형 셰이더가 경사면에서 이 값으로 바위를 섞는다.
	c.a = float(Const.BIOME_ROCK_T.get(biome, 0.35))
	return c

# ─────────────────────────────────────────────────────── 배치 헬퍼
## 청크 안의 결정적 난수기
func chunk_rng(cx: int, cz: int, salt: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(cx, cz, salt + seed_value))
	return rng

## 숲 밀도 0~1
func forest_density(x: float, z: float) -> float:
	return clampf(_forest.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)

## 지형 법선(경사 판정)
func normal_at(x: float, z: float, e: float = 1.0) -> Vector3:
	var hl := height(x - e, z)
	var hr := height(x + e, z)
	var hd := height(x, z - e)
	var hu := height(x, z + e)
	return Vector3(hl - hr, 2.0 * e, hd - hu).normalized()

func slope_at(x: float, z: float) -> float:
	return 1.0 - normal_at(x, z).y

## 스폰 지점: 중앙 근처의 평탄한 초원 해안
func find_spawn() -> Vector3:
	var best := Vector3(0, Const.WATER_LEVEL + 5.0, 0)
	var best_score := -1e9
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 12345
	for i in range(600):
		var a := rng.randf() * TAU
		var d := rng.randf_range(30.0, 260.0)
		var x := cos(a) * d
		var z := sin(a) * d
		var h := height(x, z)
		if h < Const.WATER_LEVEL + 2.0 or h > Const.WATER_LEVEL + 22.0:
			continue
		if biome_from(x, z, h) != Const.Biome.MEADOWS:
			continue
		var sl := slope_at(x, z)
		var score := -sl * 40.0 - absf(h - (Const.WATER_LEVEL + 8.0)) * 0.4 - d * 0.004
		if score > best_score:
			best_score = score
			best = Vector3(x, h, z)
	return best

## 보스 제단 위치 — 각 바이옴 링에서 결정적으로 하나씩 고른다
func altar_position(biome: int) -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + biome * 7919
	var ring_map := {
		Const.Biome.MEADOWS: 0.10,
		Const.Biome.BLACKFOREST: 0.24,
		Const.Biome.SWAMP: 0.39,
		Const.Biome.MOUNTAIN: 0.42,
		Const.Biome.PLAINS: 0.55,
		Const.Biome.MISTLANDS: 0.72,
		Const.Biome.ASHLANDS: 0.90,
	}
	var want_r: float = float(ring_map.get(biome, 0.3))
	var best := Vector3.ZERO
	var best_score := -1e9
	for i in range(900):
		var a := rng.randf() * TAU
		var d: float = Const.WORLD_RADIUS * clampf(want_r + rng.randf_range(-0.06, 0.06), 0.05, 0.97)
		var x := cos(a) * d
		var z := sin(a) * d
		var h := height(x, z)
		if h < Const.WATER_LEVEL + 2.0:
			continue
		if biome_from(x, z, h) != biome:
			continue
		var score := -slope_at(x, z) * 60.0
		if score > best_score:
			best_score = score
			best = Vector3(x, h, z)
	if best == Vector3.ZERO:
		# 해당 바이옴을 못 찾으면 링 위 아무 육지
		var a2 := rng.randf() * TAU
		var d2: float = Const.WORLD_RADIUS * want_r
		best = Vector3(cos(a2) * d2, 0, sin(a2) * d2)
		best.y = height(best.x, best.z)
	return best
