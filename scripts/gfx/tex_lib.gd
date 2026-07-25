extends Node
## 절차적 저해상도 텍스처 라이브러리. 오토로드 이름: TexLib
##
## 발헤임 룩("Lo-Fi HD")의 핵심은 **저해상도 픽셀 텍스처 + 현대적 조명**이다.
## 단색 버텍스 컬러만으로는 조명을 아무리 만져도 그 느낌이 나오지 않는다.
## 여기서 32~64px 타일링 텍스처를 코드로 그려 nearest 필터로 붙인다.
##
## 모든 텍스처는 흰색 기준(그레이스케일 + 약한 색조)으로 만들고, 실제 색은
## 버텍스 컬러/알베도가 곱한다. 그래야 같은 텍스처를 바이옴마다 재활용할 수 있다.

var _cache: Dictionary = {}

func _ready() -> void:
	pass

func get_tex(kind: String) -> ImageTexture:
	if _cache.has(kind):
		return _cache[kind]
	var t: ImageTexture
	match kind:
		"grass": t = _grass(64)
		"dirt": t = _dirt(64)
		"rock": t = _rock(64)
		"snow": t = _snow(64)
		"sand": t = _sand(64)
		"bark": t = _bark(64)
		"plank": t = _plank(64)
		"masonry": t = _masonry(64)
		"cloth": t = _cloth(48)
		"fur": t = _fur(48)
		"metal": t = _metal(48)
		"thatch": t = _thatch(64)
		"ash": t = _ash(64)
		"leaf": t = _leaf(64)
		_: t = _dirt(64)
	_cache[kind] = t
	return t

# ─────────────────────────────────────────────── 유틸
func _noise(sv: int, freq: float, oct: int = 3) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = sv
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = oct
	return n

## 심리스 타일링: 네 귀퉁이 샘플을 이중선형으로 섞는다
func _tile(n: FastNoiseLite, x: int, y: int, size: int) -> float:
	var a := n.get_noise_2d(float(x), float(y))
	var b := n.get_noise_2d(float(x - size), float(y))
	var c := n.get_noise_2d(float(x), float(y - size))
	var d := n.get_noise_2d(float(x - size), float(y - size))
	var fx := float(x) / float(size)
	var fy := float(y) / float(size)
	return lerp(lerp(a, b, fx), lerp(c, d, fx), fy)

func _mk(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)

func _hash2(x: int, y: int, sv: int) -> float:
	var h := (x * 374761393 + y * 668265263 + sv * 1274126177) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0

# ─────────────────────────────────────────────── 지면
## 잔디 — 짧은 세로 획이 촘촘히 박힌 결. 발헤임 지면의 기본 질감.
func _grass(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var base := _noise(11, 5.0 / float(size), 3)
	var patch := _noise(21, 1.6 / float(size), 2)
	for y in size:
		for x in size:
			var v := 0.5 + _tile(base, x, y, size) * 0.30
			v += _tile(patch, x, y, size) * 0.22
			# 세로 획(풀날) — 2~4px 길이의 밝은 선을 흩뿌린다
			var hh := _hash2(x, y / 3, 7)
			if hh > 0.80:
				v += 0.26
			elif hh < 0.10:
				v -= 0.18
			v = clampf(v, 0.18, 1.0)
			# 잔디는 약간 노란 기가 돈다
			img.set_pixel(x, y, Color(v * 1.02, v, v * 0.80))
	return _mk(img)

## 흙 — 굵은 알갱이와 작은 자갈
func _dirt(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var base := _noise(31, 6.0 / float(size), 3)
	for y in size:
		for x in size:
			var v := 0.55 + _tile(base, x, y, size) * 0.35
			var h := _hash2(x, y, 13)
			if h > 0.93:
				v += 0.30                      # 자갈
			elif h < 0.07:
				v -= 0.22                      # 그늘진 구덩이
			v = clampf(v, 0.20, 1.0)
			img.set_pixel(x, y, Color(v * 1.05, v * 0.94, v * 0.82))
	return _mk(img)

## 바위 — 큰 면과 균열
func _rock(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var base := _noise(41, 3.0 / float(size), 2)
	var crack := _noise(43, 7.0 / float(size), 2)
	for y in size:
		for x in size:
			var v := 0.62 + _tile(base, x, y, size) * 0.30
			# 균열: 노이즈 0 부근이 어두운 선이 된다
			var cr := absf(_tile(crack, x, y, size))
			if cr < 0.045:
				v -= 0.34 * (1.0 - cr / 0.045)
			var h := _hash2(x, y, 17)
			v += (h - 0.5) * 0.10
			v = clampf(v, 0.18, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.99, v * 0.96))
	return _mk(img)

## 눈 — 거의 균일하되 반짝이는 알갱이
func _snow(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var base := _noise(51, 3.5 / float(size), 2)
	for y in size:
		for x in size:
			var v := 0.86 + _tile(base, x, y, size) * 0.12
			if _hash2(x, y, 23) > 0.975:
				v = 1.0
			v = clampf(v, 0.6, 1.0)
			img.set_pixel(x, y, Color(v * 0.97, v * 0.99, v))
	return _mk(img)

func _sand(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var base := _noise(61, 8.0 / float(size), 2)
	for y in size:
		for x in size:
			var v := 0.72 + _tile(base, x, y, size) * 0.18
			v += (_hash2(x, y, 29) - 0.5) * 0.14
			v = clampf(v, 0.35, 1.0)
			img.set_pixel(x, y, Color(v * 1.04, v * 0.98, v * 0.84))
	return _mk(img)

## 잿불 — 갈라진 검은 땅에 불씨
func _ash(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var base := _noise(71, 5.0 / float(size), 3)
	var crack := _noise(73, 4.0 / float(size), 2)
	for y in size:
		for x in size:
			var v := 0.45 + _tile(base, x, y, size) * 0.30
			var cr := absf(_tile(crack, x, y, size))
			var col := Color(v, v * 0.94, v * 0.90)
			if cr < 0.05:
				var t := 1.0 - cr / 0.05
				col = col.lerp(Color(1.0, 0.42, 0.12), t * 0.85)
			img.set_pixel(x, y, col)
	return _mk(img)

# ─────────────────────────────────────────────── 재료
## 나무껍질 — 세로로 길게 찢어진 결
func _bark(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var n := _noise(81, 2.0 / float(size), 3)
	for y in size:
		for x in size:
			# x 방향으로 좁고 y 방향으로 길게 늘인 노이즈 = 세로 결
			var v := 0.62 + _tile(n, x * 4, y, size) * 0.34
			if _hash2(x / 2, y / 6, 31) > 0.86:
				v -= 0.22
			v = clampf(v, 0.20, 1.0)
			img.set_pixel(x, y, Color(v * 1.06, v * 0.92, v * 0.78))
	return _mk(img)

## 판자 — 가로 널과 못
func _plank(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var n := _noise(91, 2.5 / float(size), 3)
	var pw := 16
	for y in size:
		for x in size:
			var v := 0.70 + _tile(n, x, y * 5, size) * 0.26
			var edge := y % pw
			if edge == 0 or edge == pw - 1:
				v -= 0.34                       # 널 사이 틈
			# 나뭇결
			if _hash2(x / 3, y, 37) > 0.90:
				v -= 0.12
			# 못
			if (x % 24 == 5) and (edge == 3 or edge == pw - 4):
				v = 0.42
			v = clampf(v, 0.18, 1.0)
			img.set_pixel(x, y, Color(v * 1.06, v * 0.93, v * 0.76))
	return _mk(img)

## 석조 — 모르타르 줄눈이 있는 블록
func _masonry(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var n := _noise(101, 5.0 / float(size), 2)
	var bh := 16
	var bw := 32
	for y in size:
		for x in size:
			var row := y / bh
			var ox := (bw / 2) if row % 2 == 1 else 0        # 벽돌 엇쌓기
			var lx := (x + ox) % bw
			var ly := y % bh
			var v := 0.66 + _tile(n, x, y, size) * 0.26
			if lx < 2 or ly < 2:
				v -= 0.32                                     # 줄눈
			else:
				v += (_hash2(x / 2, y / 2, 41) - 0.5) * 0.16
			v = clampf(v, 0.20, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.99, v * 0.96))
	return _mk(img)

## 직물 — 씨실/날실 격자
func _cloth(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var n := _noise(111, 6.0 / float(size), 2)
	for y in size:
		for x in size:
			var v := 0.74 + _tile(n, x, y, size) * 0.16
			if (x + y) % 4 == 0:
				v -= 0.10
			if x % 4 == 0 or y % 4 == 0:
				v -= 0.08
			v = clampf(v, 0.30, 1.0)
			img.set_pixel(x, y, Color(v, v * 0.98, v * 0.94))
	return _mk(img)

## 털가죽 — 짧고 불규칙한 획
func _fur(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var n := _noise(121, 4.0 / float(size), 3)
	for y in size:
		for x in size:
			var v := 0.70 + _tile(n, x * 2, y, size) * 0.26
			if _hash2(x, y / 2, 43) > 0.84:
				v += 0.16
			v = clampf(v, 0.28, 1.0)
			img.set_pixel(x, y, Color(v * 1.02, v, v * 0.96))
	return _mk(img)

## 금속 — 망치 자국
func _metal(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var n := _noise(131, 4.0 / float(size), 2)
	for y in size:
		for x in size:
			var v := 0.80 + _tile(n, x, y, size) * 0.18
			if _hash2(x / 3, y / 3, 47) > 0.90:
				v -= 0.14
			v = clampf(v, 0.42, 1.0)
			img.set_pixel(x, y, Color(v, v, v * 1.01))
	return _mk(img)

## 초가 — 가로로 눕힌 짚단
func _thatch(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var n := _noise(141, 3.0 / float(size), 2)
	for y in size:
		for x in size:
			var v := 0.68 + _tile(n, x, y * 6, size) * 0.28
			if _hash2(x / 5, y, 53) > 0.80:
				v += 0.18
			if y % 8 == 0:
				v -= 0.20
			v = clampf(v, 0.24, 1.0)
			img.set_pixel(x, y, Color(v * 1.06, v * 0.96, v * 0.70))
	return _mk(img)

## 잎 — 알파가 뚫린 잎 뭉치. 나뭇잎 카드(빌보드 평면)에 쓴다.
func _leaf(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260726
	var c := float(size) * 0.5
	# 타원형 잎을 여러 장 겹쳐 뭉치를 만든다
	for i in range(26):
		var lx := rng.randf_range(0.14, 0.86) * float(size)
		var ly := rng.randf_range(0.14, 0.86) * float(size)
		var rx := rng.randf_range(0.06, 0.15) * float(size)
		var ry := rng.randf_range(0.09, 0.20) * float(size)
		var ang := rng.randf() * TAU
		var shade := rng.randf_range(0.62, 1.0)
		for y in size:
			for x in size:
				var dx := float(x) - lx
				var dy := float(y) - ly
				var ux := dx * cos(ang) + dy * sin(ang)
				var uy := -dx * sin(ang) + dy * cos(ang)
				if (ux * ux) / (rx * rx) + (uy * uy) / (ry * ry) <= 1.0:
					# 잎맥: 가운데 선이 조금 밝다
					var v := shade
					if absf(ux) < 1.2:
						v = minf(v * 1.25, 1.0)
					img.set_pixel(x, y, Color(v * 0.96, v, v * 0.88, 1.0))
	# 가장자리를 부드럽게 깎아 사각형 티를 없앤다
	for y in size:
		for x in size:
			var d := Vector2(float(x) - c, float(y) - c).length() / c
			if d > 0.92:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return _mk(img)
