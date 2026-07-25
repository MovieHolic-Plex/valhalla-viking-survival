extends Node
## 절차적 모델 라이브러리. 오토로드 이름: MeshFactory
## 외부 3D 에셋 없이 모든 오브젝트를 코드로 생성한다.

var _cache: Dictionary = {}

func _key(parts: Array) -> String:
	return "|".join(parts.map(func(x): return str(x)))

# ═══════════════════════════════════════════════════════ 나무
## kind: beech(너도밤나무) / pine(소나무) / fir(전나무) / birch(자작나무)
##       oak(참나무) / ancient(고목·늪) / swamp_dead(고사목) / yggdrasil(미스트랜드)
## 반환: {"trunk": Mesh, "leaves": Mesh, "h": 높이, "r": 밑동 반경, "log": Mesh}
func tree(kind: String, seed_v: int) -> Dictionary:
	var k := _key(["tree", kind, seed_v])
	if _cache.has(k):
		return _cache[k]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var trunk := MeshBuilder.new()
	var leaf := MeshBuilder.new()
	var h := 8.0
	var r := 0.35

	match kind:
		"pine":
			h = rng.randf_range(11.0, 17.0)
			r = h * 0.030
			var bark := Color(0.30, 0.21, 0.14)
			trunk.cyl(Transform3D.IDENTITY, r, r * 0.35, h, 7, bark)
			var lc := Color(0.10, 0.22, 0.13)
			var layers := 6
			for i in range(layers):
				var t := float(i) / float(layers - 1)
				var y: float = lerp(h * 0.34, h * 0.97, t)
				var rr: float = lerp(h * 0.20, h * 0.045, t)
				var hh: float = lerp(h * 0.20, h * 0.10, t)
				leaf.cone(Transform3D(Basis.IDENTITY, Vector3(0, y, 0)), rr, hh, 7,
					lc.lightened(t * 0.18))
		"fir":
			h = rng.randf_range(13.0, 20.0)
			r = h * 0.028
			trunk.cyl(Transform3D.IDENTITY, r, r * 0.3, h, 7, Color(0.26, 0.19, 0.13))
			var fc := Color(0.08, 0.18, 0.12)
			for i in range(8):
				var t := float(i) / 7.0
				var y: float = lerp(h * 0.20, h * 0.98, t)
				var rr: float = lerp(h * 0.17, h * 0.03, t)
				leaf.cone(Transform3D(Basis.IDENTITY, Vector3(0, y, 0)), rr, h * 0.16, 6,
					fc.lightened(t * 0.22))
		"birch":
			h = rng.randf_range(9.0, 14.0)
			r = h * 0.026
			trunk.cyl(Transform3D.IDENTITY, r, r * 0.5, h, 7, Color(0.86, 0.86, 0.82))
			# 자작나무 특유의 검은 가로줄
			for i in range(5):
				var y := h * (0.15 + 0.15 * float(i))
				trunk.cyl(Transform3D(Basis.IDENTITY, Vector3(0, y, 0)),
					r * 1.03, r * 1.0, h * 0.03, 7, Color(0.16, 0.16, 0.15))
			var bc := Color(0.52, 0.62, 0.22)
			for i in range(4):
				var a := rng.randf() * TAU
				var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.4, 1.6)
				leaf.sphere(Vector3(0, h * 0.82, 0) + off, h * rng.randf_range(0.16, 0.24),
					7, 5, bc.lightened(rng.randf_range(-0.08, 0.14)), Vector3(1, 0.8, 1))
		"oak":
			h = rng.randf_range(9.0, 13.0)
			r = h * 0.055
			trunk.cyl(Transform3D.IDENTITY, r, r * 0.55, h * 0.6, 8, Color(0.32, 0.24, 0.16))
			# 갈라진 가지
			for i in range(4):
				var a := TAU * float(i) / 4.0 + rng.randf() * 0.5
				var from := Vector3(0, h * 0.55, 0)
				var to := from + Vector3(cos(a), 1.1, sin(a)) * h * 0.28
				trunk.rod(from, to, r * 0.30, 5, Color(0.30, 0.22, 0.15))
				leaf.sphere(to + Vector3(0, h * 0.06, 0), h * 0.22, 7, 5,
					Color(0.24, 0.38, 0.16).lightened(rng.randf_range(0.0, 0.16)),
					Vector3(1, 0.75, 1))
			leaf.sphere(Vector3(0, h * 0.82, 0), h * 0.30, 8, 6, Color(0.22, 0.36, 0.15),
				Vector3(1, 0.72, 1))
		"ancient":
			h = rng.randf_range(12.0, 18.0)
			r = h * 0.070
			trunk.cyl(Transform3D.IDENTITY, r, r * 0.4, h * 0.75, 9, Color(0.22, 0.20, 0.16))
			for i in range(5):
				var a := TAU * float(i) / 5.0 + rng.randf()
				var from := Vector3(0, h * rng.randf_range(0.45, 0.7), 0)
				var to := from + Vector3(cos(a), rng.randf_range(0.3, 0.9), sin(a)) * h * 0.32
				trunk.rod(from, to, r * 0.22, 5, Color(0.20, 0.18, 0.15))
			# 고목엔 잎이 거의 없다 — 늘어진 이끼만
			for i in range(6):
				var a2 := rng.randf() * TAU
				var p := Vector3(cos(a2), 0, sin(a2)) * rng.randf_range(0.8, 2.6)
				p.y = h * rng.randf_range(0.5, 0.75)
				leaf.box(Transform3D(Basis.IDENTITY, p), Vector3(0.12, 1.4, 0.12),
					Color(0.26, 0.30, 0.18))
		"swamp_dead":
			h = rng.randf_range(6.0, 11.0)
			r = h * 0.045
			trunk.cyl(Transform3D.IDENTITY, r, r * 0.25, h, 6, Color(0.19, 0.17, 0.14))
			for i in range(3):
				var a := rng.randf() * TAU
				var from := Vector3(0, h * rng.randf_range(0.5, 0.85), 0)
				var to := from + Vector3(cos(a), 0.5, sin(a)) * h * 0.25
				trunk.rod(from, to, r * 0.25, 4, Color(0.18, 0.16, 0.13))
		"yggdrasil":
			h = rng.randf_range(14.0, 20.0)
			r = h * 0.045
			trunk.cyl(Transform3D.IDENTITY, r, r * 0.4, h * 0.8, 8, Color(0.32, 0.36, 0.30))
			for i in range(5):
				var t := float(i) / 4.0
				leaf.sphere(Vector3(0, h * (0.6 + t * 0.35), 0), h * (0.22 - t * 0.10),
					7, 5, Color(0.34, 0.52, 0.36).lightened(t * 0.2), Vector3(1.3, 0.6, 1.3))
		_:  # beech (기본 — 초원)
			h = rng.randf_range(8.0, 12.0)
			r = h * 0.038
			trunk.cyl(Transform3D.IDENTITY, r, r * 0.45, h * 0.7, 7, Color(0.40, 0.29, 0.18))
			var cc := Color(0.30, 0.46, 0.19)
			leaf.sphere(Vector3(0, h * 0.80, 0), h * 0.28, 8, 6, cc, Vector3(1.1, 0.82, 1.1))
			for i in range(3):
				var a := rng.randf() * TAU
				leaf.sphere(Vector3(cos(a) * h * 0.16, h * 0.66, sin(a) * h * 0.16),
					h * 0.19, 7, 5, cc.lightened(rng.randf_range(-0.06, 0.12)),
					Vector3(1, 0.85, 1))

	var log_mb := MeshBuilder.new()
	log_mb.cyl(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), r, r * 0.7,
		h * 0.45, 7, Color(0.38, 0.27, 0.17))
	var res := {"trunk": trunk.commit(), "leaves": leaf.commit(), "h": h, "r": r,
		"log": log_mb.commit()}
	_cache[k] = res
	return res

func stump(r: float, col: Color = Color(0.38, 0.27, 0.17)) -> Mesh:
	var k := _key(["stump", r])
	if _cache.has(k):
		return _cache[k]
	var mb := MeshBuilder.new()
	mb.cyl(Transform3D.IDENTITY, r * 1.15, r, 0.5, 8, col)
	mb.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)), r * 0.98, r * 0.98, 0.03, 8,
		Color(0.72, 0.58, 0.38))
	_cache[k] = mb.commit()
	return _cache[k]

# ═══════════════════════════════════════════════════════ 바위 · 광맥
func boulder(size: float, seed_v: int, col: Color = Color(0.46, 0.46, 0.48)) -> Mesh:
	var k := _key(["rock", size, seed_v, col.to_html()])
	if _cache.has(k):
		return _cache[k]
	var mb := MeshBuilder.new()
	mb.rock(Vector3(0, size * 0.55, 0), size, seed_v, col, 8, 5, 0.30,
		Vector3(1.0, 0.75, 1.0))
	_cache[k] = mb.commit()
	return _cache[k]

## 광맥: 바위 + 색이 다른 광석 결정
func ore_node(kind: String, size: float, seed_v: int) -> Dictionary:
	var k := _key(["ore", kind, size, seed_v])
	if _cache.has(k):
		return _cache[k]
	var rock_col := Color(0.34, 0.33, 0.32)
	var vein_col := Color(0.78, 0.44, 0.20)
	var emis := 0.0
	match kind:
		"copper": vein_col = Color(0.30, 0.66, 0.50)   # 산화 구리의 청록빛
		"tin": vein_col = Color(0.72, 0.76, 0.80)
		"iron": vein_col = Color(0.48, 0.34, 0.26); rock_col = Color(0.24, 0.22, 0.20)
		"silver": vein_col = Color(0.88, 0.90, 0.94); rock_col = Color(0.72, 0.76, 0.82)
		"obsidian": vein_col = Color(0.09, 0.09, 0.13); rock_col = Color(0.16, 0.16, 0.20)
		"black_metal": vein_col = Color(0.18, 0.18, 0.22); rock_col = Color(0.26, 0.24, 0.20)
		"flametal": vein_col = Color(1.0, 0.42, 0.12); rock_col = Color(0.20, 0.12, 0.10); emis = 1.6
		"surtling": vein_col = Color(1.0, 0.55, 0.15); emis = 2.2
	var body := MeshBuilder.new()
	body.rock(Vector3(0, size * 0.5, 0), size, seed_v, rock_col, 8, 5, 0.26,
		Vector3(1.0, 0.80, 1.0))
	var veins := MeshBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v + 991
	for i in range(6):
		var a := rng.randf() * TAU
		var e := rng.randf_range(0.2, 1.0)
		var p := Vector3(cos(a) * size * 0.62, size * (0.25 + e * 0.55), sin(a) * size * 0.62)
		veins.rock(p, size * rng.randf_range(0.16, 0.28), seed_v + i * 17, vein_col, 5, 3, 0.4)
	var res := {"rock": body.commit(), "vein": veins.commit(), "emission": emis,
		"vein_color": vein_col}
	_cache[k] = res
	return res

# ═══════════════════════════════════════════════════════ 식물 · 소품
func bush(kind: String, seed_v: int) -> Dictionary:
	var k := _key(["bush", kind, seed_v])
	if _cache.has(k):
		return _cache[k]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var leaves := MeshBuilder.new()
	var fruit := MeshBuilder.new()
	var lc := Color(0.22, 0.36, 0.18)
	var fc := Color(0.80, 0.15, 0.25)
	match kind:
		"blueberry": fc = Color(0.24, 0.30, 0.72); lc = Color(0.20, 0.33, 0.20)
		"cloudberry": fc = Color(0.95, 0.72, 0.22); lc = Color(0.26, 0.34, 0.22)
		"thistle": fc = Color(0.62, 0.36, 0.78); lc = Color(0.22, 0.30, 0.24)
	for i in range(5):
		var a := TAU * float(i) / 5.0 + rng.randf() * 0.6
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.05, 0.30)
		leaves.sphere(p + Vector3(0, rng.randf_range(0.20, 0.42), 0),
			rng.randf_range(0.18, 0.28), 6, 4, lc.lightened(rng.randf_range(0.0, 0.15)),
			Vector3(1, 0.8, 1))
	for i in range(7):
		var a2 := rng.randf() * TAU
		var rr := rng.randf_range(0.10, 0.36)
		fruit.sphere(Vector3(cos(a2) * rr, rng.randf_range(0.25, 0.55), sin(a2) * rr),
			0.055, 5, 3, fc)
	var res := {"leaves": leaves.commit(), "fruit": fruit.commit(), "color": fc}
	_cache[k] = res
	return res

func mushroom(seed_v: int) -> Mesh:
	var k := _key(["mush", seed_v])
	if _cache.has(k):
		return _cache[k]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mb := MeshBuilder.new()
	for i in range(rng.randi_range(2, 4)):
		var a := rng.randf() * TAU
		var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.22)
		var hh := rng.randf_range(0.13, 0.22)
		mb.cyl(Transform3D(Basis.IDENTITY, off), 0.028, 0.022, hh, 5, Color(0.90, 0.86, 0.74))
		mb.sphere(off + Vector3(0, hh, 0), rng.randf_range(0.07, 0.11), 7, 3,
			Color(0.78, 0.30, 0.20), Vector3(1, 0.55, 1))
	_cache[k] = mb.commit()
	return _cache[k]

func flower(col: Color, seed_v: int) -> Mesh:
	var k := _key(["flower", col.to_html(), seed_v])
	if _cache.has(k):
		return _cache[k]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mb := MeshBuilder.new()
	for i in range(rng.randi_range(3, 6)):
		var a := rng.randf() * TAU
		var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.3)
		var hh := rng.randf_range(0.20, 0.36)
		mb.cyl(Transform3D(Basis.IDENTITY, off), 0.012, 0.010, hh, 4, Color(0.28, 0.42, 0.20))
		mb.sphere(off + Vector3(0, hh, 0), 0.05, 6, 3, col, Vector3(1, 0.5, 1))
	_cache[k] = mb.commit()
	return _cache[k]

func grass_tuft(col: Color, seed_v: int) -> Mesh:
	var k := _key(["grass", col.to_html(), seed_v])
	if _cache.has(k):
		return _cache[k]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var mb := MeshBuilder.new()
	for i in range(7):
		var a := rng.randf() * TAU
		var base := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.0, 0.14)
		var tip := base + Vector3(rng.randf_range(-0.10, 0.10), rng.randf_range(0.16, 0.32),
			rng.randf_range(-0.10, 0.10))
		var w := 0.022
		var side := Vector3(-sin(a), 0, cos(a)) * w
		mb.quad(base - side, base + side, tip + side * 0.25, tip - side * 0.25,
			col.lightened(rng.randf_range(-0.10, 0.16)))
	_cache[k] = mb.commit()
	return _cache[k]

func crop_plant(stage: float, col: Color, tall: bool) -> Mesh:
	var mb := MeshBuilder.new()
	var s: float = clampf(stage, 0.12, 1.0)
	var h := (0.85 if tall else 0.42) * s
	for i in range(5):
		var a := TAU * float(i) / 5.0
		var off := Vector3(cos(a), 0, sin(a)) * 0.10 * s
		mb.cyl(Transform3D(Basis.IDENTITY, off), 0.02 * s, 0.012 * s, h, 4, col)
	if s > 0.85 and not tall:
		mb.sphere(Vector3(0, h * 0.9, 0), 0.12, 6, 4, col.lightened(0.25), Vector3(1, 0.9, 1))
	if s > 0.85 and tall:
		mb.sphere(Vector3(0, h, 0), 0.09, 5, 3, col.lightened(0.35), Vector3(0.6, 2.0, 0.6))
	return mb.commit()

# ═══════════════════════════════════════════════════════ 캐릭터 리그
## 인간형 리그. 반환 Node3D 자식 이름:
##   hips / torso / head_pivot / head / arm_l / arm_r / leg_l / leg_r / hand_r / hand_l
func humanoid(cfg: Dictionary) -> Node3D:
	var skin: Color = cfg.get("skin", Color(0.78, 0.62, 0.50))
	var cloth: Color = cfg.get("cloth", Color(0.42, 0.34, 0.26))
	var hair: Color = cfg.get("hair", Color(0.36, 0.24, 0.14))
	var height: float = cfg.get("height", 1.8)
	var bulk: float = cfg.get("bulk", 1.0)
	var head_sc: float = cfg.get("head", 1.0)
	var mat_leaf: bool = cfg.get("mossy", false)

	var leg_h := height * 0.46
	var torso_h := height * 0.34
	var head_r := height * 0.085 * head_sc
	var sh_w := height * 0.115 * bulk
	var arm_len := height * 0.40

	var rig := Node3D.new()
	rig.name = "rig"

	var hips := Node3D.new()
	hips.name = "hips"
	hips.position = Vector3(0, leg_h, 0)
	rig.add_child(hips)

	# 몸통
	var tb := MeshBuilder.new()
	tb.box_up(Vector3.ZERO, Vector3(sh_w * 1.7, torso_h, sh_w * 0.95), cloth)
	tb.box_up(Vector3(0, torso_h * 0.55, 0), Vector3(sh_w * 2.0, torso_h * 0.42, sh_w * 1.0),
		cloth.darkened(0.12))
	var torso := MeshInstance3D.new()
	torso.name = "torso"
	torso.mesh = tb.commit()
	torso.material_override = MatLib.flat(Color.WHITE)
	hips.add_child(torso)

	# 머리
	var head_pivot := Node3D.new()
	head_pivot.name = "head_pivot"
	head_pivot.position = Vector3(0, torso_h, 0)
	hips.add_child(head_pivot)
	var hb := MeshBuilder.new()
	hb.box(Transform3D(Basis.IDENTITY, Vector3(0, head_r, 0)),
		Vector3(head_r * 1.6, head_r * 2.0, head_r * 1.7), skin)
	# 머리카락 / 수염
	hb.box(Transform3D(Basis.IDENTITY, Vector3(0, head_r * 1.62, -head_r * 0.08)),
		Vector3(head_r * 1.7, head_r * 0.8, head_r * 1.8), hair)
	if cfg.get("beard", false):
		hb.box(Transform3D(Basis.IDENTITY, Vector3(0, head_r * 0.45, head_r * 0.72)),
			Vector3(head_r * 1.1, head_r * 1.0, head_r * 0.4), hair)
	# 눈
	var eye: Color = cfg.get("eye", Color(0.08, 0.08, 0.10))
	hb.box(Transform3D(Basis.IDENTITY, Vector3(-head_r * 0.38, head_r * 1.15, head_r * 0.86)),
		Vector3(head_r * 0.30, head_r * 0.22, head_r * 0.08), eye)
	hb.box(Transform3D(Basis.IDENTITY, Vector3(head_r * 0.38, head_r * 1.15, head_r * 0.86)),
		Vector3(head_r * 0.30, head_r * 0.22, head_r * 0.08), eye)
	if cfg.get("horns", false):
		hb.cone(Transform3D(Basis(Vector3.FORWARD, -0.5), Vector3(-head_r * 0.7, head_r * 1.7, 0)),
			head_r * 0.22, head_r * 1.2, 5, Color(0.86, 0.82, 0.70))
		hb.cone(Transform3D(Basis(Vector3.FORWARD, 0.5), Vector3(head_r * 0.7, head_r * 1.7, 0)),
			head_r * 0.22, head_r * 1.2, 5, Color(0.86, 0.82, 0.70))
	var head := MeshInstance3D.new()
	head.name = "head"
	head.mesh = hb.commit()
	head.material_override = MatLib.flat(Color.WHITE)
	head_pivot.add_child(head)

	# 팔 (어깨 피벗에서 아래로)
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.name = "arm_l" if side < 0 else "arm_r"
		pivot.position = Vector3(sh_w * float(side) * 1.05, torso_h * 0.88, 0)
		hips.add_child(pivot)
		var ab := MeshBuilder.new()
		ab.box(Transform3D(Basis.IDENTITY, Vector3(0, -arm_len * 0.5, 0)),
			Vector3(sh_w * 0.46, arm_len, sh_w * 0.46), cloth.lightened(0.06))
		ab.box(Transform3D(Basis.IDENTITY, Vector3(0, -arm_len * 0.94, 0)),
			Vector3(sh_w * 0.5, arm_len * 0.16, sh_w * 0.5), skin)
		var arm := MeshInstance3D.new()
		arm.name = "mesh"
		arm.mesh = ab.commit()
		arm.material_override = MatLib.flat(Color.WHITE)
		pivot.add_child(arm)
		var hand := Node3D.new()
		hand.name = "hand_l" if side < 0 else "hand_r"
		hand.position = Vector3(0, -arm_len, 0)
		pivot.add_child(hand)

	# 다리
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.name = "leg_l" if side < 0 else "leg_r"
		pivot.position = Vector3(sh_w * float(side) * 0.45, 0, 0)
		hips.add_child(pivot)
		var lb := MeshBuilder.new()
		lb.box(Transform3D(Basis.IDENTITY, Vector3(0, -leg_h * 0.5, 0)),
			Vector3(sh_w * 0.55, leg_h, sh_w * 0.55), cloth.darkened(0.2))
		lb.box(Transform3D(Basis.IDENTITY, Vector3(0, -leg_h * 0.97, sh_w * 0.12)),
			Vector3(sh_w * 0.6, leg_h * 0.10, sh_w * 0.85), Color(0.24, 0.18, 0.13))
		var leg := MeshInstance3D.new()
		leg.name = "mesh"
		leg.mesh = lb.commit()
		leg.material_override = MatLib.flat(Color.WHITE)
		pivot.add_child(leg)

	if mat_leaf:
		# 그레이드워프 계열: 몸에 이끼 덩어리
		var mb := MeshBuilder.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = int(height * 1000.0)
		for i in range(7):
			var a := rng.randf() * TAU
			mb.sphere(Vector3(cos(a) * sh_w, torso_h * rng.randf(), sin(a) * sh_w * 0.6),
				rng.randf_range(0.06, 0.13), 5, 3, Color(0.24, 0.36, 0.18))
		var moss := MeshInstance3D.new()
		moss.name = "moss"
		moss.mesh = mb.commit()
		moss.material_override = MatLib.foliage(Color(1, 1, 1), 0.4, 0.03)
		hips.add_child(moss)

	rig.set_meta("height", height)
	rig.set_meta("leg_h", leg_h)
	rig.set_meta("torso_h", torso_h)
	return rig

## 네발짐승 리그. 자식: body / neck / head / leg_fl,fr,bl,br / tail
func quadruped(cfg: Dictionary) -> Node3D:
	var fur: Color = cfg.get("fur", Color(0.52, 0.38, 0.24))
	var belly: Color = cfg.get("belly", fur.lightened(0.25))
	var len_v: float = cfg.get("length", 1.5)
	var hgt: float = cfg.get("height", 0.9)
	var girth: float = cfg.get("girth", 0.5)
	var head_sz: float = cfg.get("head", 0.32)
	var leg_h := hgt * 0.5

	var rig := Node3D.new()
	rig.name = "rig"
	var body_node := Node3D.new()
	body_node.name = "body"
	body_node.position = Vector3(0, leg_h, 0)
	rig.add_child(body_node)

	var bb := MeshBuilder.new()
	bb.box(Transform3D(Basis.IDENTITY, Vector3(0, girth * 0.5, 0)),
		Vector3(girth, girth, len_v), fur)
	bb.box(Transform3D(Basis.IDENTITY, Vector3(0, girth * 0.14, 0)),
		Vector3(girth * 0.86, girth * 0.4, len_v * 0.9), belly)
	var body := MeshInstance3D.new()
	body.name = "mesh"
	body.mesh = bb.commit()
	body.material_override = MatLib.flat(Color.WHITE)
	body_node.add_child(body)

	# 목 + 머리
	var neck := Node3D.new()
	neck.name = "neck"
	neck.position = Vector3(0, girth * 0.62, -len_v * 0.48)
	body_node.add_child(neck)
	var hb := MeshBuilder.new()
	var neck_len: float = cfg.get("neck", 0.25)
	hb.box(Transform3D(Basis.IDENTITY, Vector3(0, neck_len * 0.4, -neck_len * 0.4)),
		Vector3(girth * 0.55, neck_len, girth * 0.6), fur)
	var hc := Vector3(0, neck_len * 0.85, -neck_len * 0.85)
	hb.box(Transform3D(Basis.IDENTITY, hc), Vector3(head_sz, head_sz * 0.85, head_sz * 1.25), fur)
	# 주둥이
	hb.box(Transform3D(Basis.IDENTITY, hc + Vector3(0, -head_sz * 0.16, -head_sz * 0.85)),
		Vector3(head_sz * 0.55, head_sz * 0.45, head_sz * 0.6), belly)
	# 눈
	var eye: Color = cfg.get("eye", Color(0.06, 0.05, 0.04))
	for s in [-1.0, 1.0]:
		hb.box(Transform3D(Basis.IDENTITY,
			hc + Vector3(head_sz * 0.42 * s, head_sz * 0.18, -head_sz * 0.35)),
			Vector3(head_sz * 0.10, head_sz * 0.16, head_sz * 0.16), eye)
	# 뿔 / 귀
	match str(cfg.get("horn", "none")):
		"antler":
			for s in [-1.0, 1.0]:
				var base := hc + Vector3(head_sz * 0.32 * s, head_sz * 0.5, 0)
				var tip := base + Vector3(head_sz * 0.8 * s, head_sz * 1.5, head_sz * 0.2)
				hb.rod(base, tip, head_sz * 0.07, 4, Color(0.72, 0.62, 0.46))
				hb.rod(base.lerp(tip, 0.5), base.lerp(tip, 0.5) + Vector3(head_sz * 0.5 * s, head_sz * 0.5, -head_sz * 0.4),
					head_sz * 0.05, 4, Color(0.72, 0.62, 0.46))
		"tusk":
			for s in [-1.0, 1.0]:
				hb.cone(Transform3D(Basis(Vector3.RIGHT, -2.2),
					hc + Vector3(head_sz * 0.28 * s, -head_sz * 0.2, -head_sz * 0.75)),
					head_sz * 0.08, head_sz * 0.5, 4, Color(0.90, 0.88, 0.80))
		"ear":
			for s in [-1.0, 1.0]:
				hb.box(Transform3D(Basis(Vector3.FORWARD, 0.4 * s),
					hc + Vector3(head_sz * 0.42 * s, head_sz * 0.55, head_sz * 0.1)),
					Vector3(head_sz * 0.16, head_sz * 0.5, head_sz * 0.1), fur.darkened(0.15))
	var head := MeshInstance3D.new()
	head.name = "head"
	head.mesh = hb.commit()
	head.material_override = MatLib.flat(Color.WHITE)
	neck.add_child(head)

	# 다리 4개
	var lx := girth * 0.38
	var lz := len_v * 0.34
	var legs := {"leg_fl": Vector3(-lx, 0, -lz), "leg_fr": Vector3(lx, 0, -lz),
		"leg_bl": Vector3(-lx, 0, lz), "leg_br": Vector3(lx, 0, lz)}
	for lname in legs:
		var pivot := Node3D.new()
		pivot.name = lname
		pivot.position = legs[lname]
		body_node.add_child(pivot)
		var lb := MeshBuilder.new()
		lb.box(Transform3D(Basis.IDENTITY, Vector3(0, -leg_h * 0.5, 0)),
			Vector3(girth * 0.20, leg_h, girth * 0.20), fur.darkened(0.16))
		lb.box(Transform3D(Basis.IDENTITY, Vector3(0, -leg_h * 0.98, 0)),
			Vector3(girth * 0.24, leg_h * 0.10, girth * 0.28), Color(0.16, 0.14, 0.12))
		var leg := MeshInstance3D.new()
		leg.name = "mesh"
		leg.mesh = lb.commit()
		leg.material_override = MatLib.flat(Color.WHITE)
		pivot.add_child(leg)

	# 꼬리
	var tail := Node3D.new()
	tail.name = "tail"
	tail.position = Vector3(0, girth * 0.55, len_v * 0.5)
	body_node.add_child(tail)
	var tb := MeshBuilder.new()
	var tl: float = cfg.get("tail", 0.3)
	tb.box(Transform3D(Basis(Vector3.RIGHT, 0.6), Vector3(0, 0, tl * 0.5)),
		Vector3(girth * 0.14, girth * 0.14, tl), fur.darkened(0.1))
	var tailm := MeshInstance3D.new()
	tailm.name = "mesh"
	tailm.mesh = tb.commit()
	tailm.material_override = MatLib.flat(Color.WHITE)
	tail.add_child(tailm)

	rig.set_meta("leg_h", leg_h)
	return rig

## 비행체(드레이크·데스스퀴토) 리그. 자식: body / wing_l / wing_r
func flyer(cfg: Dictionary) -> Node3D:
	var col: Color = cfg.get("color", Color(0.62, 0.80, 0.90))
	var size: float = cfg.get("size", 1.0)
	var wing: float = cfg.get("wing", 1.4)
	var rig := Node3D.new()
	rig.name = "rig"
	var body_node := Node3D.new()
	body_node.name = "body"
	rig.add_child(body_node)
	var bb := MeshBuilder.new()
	bb.box(Transform3D.IDENTITY, Vector3(size * 0.45, size * 0.42, size * 1.1), col)
	bb.box(Transform3D(Basis.IDENTITY, Vector3(0, size * 0.14, -size * 0.66)),
		Vector3(size * 0.32, size * 0.30, size * 0.45), col.lightened(0.1))
	bb.cone(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, size * 0.14, -size * 0.9)),
		size * 0.12, size * 0.34, 5, col.darkened(0.2))
	for s in [-1.0, 1.0]:
		bb.box(Transform3D(Basis.IDENTITY, Vector3(size * 0.12 * s, size * 0.24, -size * 0.86)),
			Vector3(size * 0.08, size * 0.10, size * 0.08), Color(1.0, 0.75, 0.15))
	bb.box(Transform3D(Basis(Vector3.RIGHT, 0.5), Vector3(0, 0, size * 0.78)),
		Vector3(size * 0.16, size * 0.16, size * 0.7), col.darkened(0.15))
	var body := MeshInstance3D.new()
	body.name = "mesh"
	body.mesh = bb.commit()
	body.material_override = MatLib.flat(Color.WHITE)
	body_node.add_child(body)
	for s in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "wing_l" if s < 0.0 else "wing_r"
		pivot.position = Vector3(size * 0.2 * s, size * 0.15, 0)
		body_node.add_child(pivot)
		var wb := MeshBuilder.new()
		wb.quad(Vector3.ZERO, Vector3(wing * s, 0, -wing * 0.28),
			Vector3(wing * s, 0, wing * 0.34), Vector3(0, 0, size * 0.4),
			col.lightened(0.12))
		var wm := MeshInstance3D.new()
		wm.name = "mesh"
		wm.mesh = wb.commit()
		wm.material_override = MatLib.foliage(Color.WHITE, 0.7, 0.0)
		pivot.add_child(wm)
	return rig

## 젤리형(블롭) — 단일 메시
func blob_mesh(size: float, col: Color, seed_v: int) -> Mesh:
	var k := _key(["blob", size, col.to_html(), seed_v])
	if _cache.has(k):
		return _cache[k]
	var mb := MeshBuilder.new()
	mb.rock(Vector3(0, size * 0.6, 0), size, seed_v, col, 8, 5, 0.16, Vector3(1, 0.75, 1))
	_cache[k] = mb.commit()
	return _cache[k]

# ═══════════════════════════════════════════════════════ 건축 조각
## kind 는 RecipeDB.pieces[*]["kind"] 값
func piece(kind: String, size: Vector3, col: Color) -> Mesh:
	var k := _key(["piece", kind, size, col.to_html()])
	if _cache.has(k):
		return _cache[k]
	var mb := MeshBuilder.new()
	var dark := col.darkened(0.22)
	var light := col.lightened(0.12)
	match kind:
		"floor":
			# 판자 4장
			var n := 4
			for i in range(n):
				var w := size.x / float(n)
				var x := -size.x * 0.5 + w * (float(i) + 0.5)
				mb.box(Transform3D(Basis.IDENTITY, Vector3(x, 0, 0)),
					Vector3(w * 0.94, size.y, size.z),
					col.lightened(float(i % 2) * 0.08))
		"wall":
			mb.box(Transform3D.IDENTITY, size, col)
			# 대각 보강재
			mb.box(Transform3D(Basis(Vector3.FORWARD, 0.78), Vector3(0, 0, size.z * 0.55)),
				Vector3(size.x * 1.3, 0.10, 0.08), dark)
			mb.box(Transform3D(Basis(Vector3.FORWARD, -0.78), Vector3(0, 0, size.z * 0.55)),
				Vector3(size.x * 1.3, 0.10, 0.08), dark)
		"wall_half":
			mb.box(Transform3D.IDENTITY, size, col)
		"beam", "pole":
			mb.box(Transform3D.IDENTITY, size, col)
		"beam_diag":
			mb.box(Transform3D(Basis(Vector3.RIGHT, 0.7), Vector3.ZERO),
				Vector3(size.x, size.z * 1.4, size.x), col)
		"roof":
			mb.wedge(Transform3D(Basis.IDENTITY, Vector3(0, -size.y * 0.5, 0)),
				size.x, size.y, size.z, col)
		"roof_top":
			mb.gable(Transform3D(Basis.IDENTITY, Vector3(0, -size.y * 0.5, 0)),
				size.x, size.y * 2.0, size.z, col)
		"door":
			mb.box(Transform3D.IDENTITY, size, col)
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, 0, size.z * 0.6)),
				Vector3(size.x * 0.85, 0.09, 0.06), dark)
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.3, size.z * 0.6)),
				Vector3(size.x * 0.85, 0.09, 0.06), dark)
			mb.sphere(Vector3(size.x * 0.32, 0, size.z * 0.8), 0.06, 6, 4,
				Color(0.35, 0.32, 0.28))
		"stair":
			var steps := 5
			for i in range(steps):
				var t := float(i) / float(steps)
				mb.box(Transform3D(Basis.IDENTITY,
					Vector3(0, -size.y * 0.5 + size.y * (t + 0.5 / float(steps)),
						size.z * 0.5 - size.z * (t + 0.5 / float(steps)))),
					Vector3(size.x, size.y / float(steps), size.z / float(steps)),
					col.lightened(t * 0.1))
		"ladder":
			mb.box(Transform3D(Basis.IDENTITY, Vector3(-size.x * 0.4, 0, 0)),
				Vector3(0.09, size.y, 0.09), col)
			mb.box(Transform3D(Basis.IDENTITY, Vector3(size.x * 0.4, 0, 0)),
				Vector3(0.09, size.y, 0.09), col)
			for i in range(6):
				var y := -size.y * 0.5 + size.y * (float(i) + 0.5) / 6.0
				mb.box(Transform3D(Basis.IDENTITY, Vector3(0, y, 0)),
					Vector3(size.x * 0.8, 0.06, 0.06), light)
		"fence":
			for i in range(3):
				var x := -size.x * 0.5 + size.x * (float(i) + 0.5) / 3.0
				mb.box(Transform3D(Basis.IDENTITY, Vector3(x, 0, 0)),
					Vector3(0.09, size.y, 0.09), col)
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.28, 0)),
				Vector3(size.x, 0.07, 0.07), light)
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, -size.y * 0.12, 0)),
				Vector3(size.x, 0.07, 0.07), light)
		"workbench":
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.32, 0)),
				Vector3(size.x * 0.9, 0.12, size.z * 0.55), col)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					mb.box(Transform3D(Basis.IDENTITY,
						Vector3(size.x * 0.38 * sx, 0, size.z * 0.22 * sz)),
						Vector3(0.11, size.y * 0.66, 0.11), dark)
			# 위에 놓인 연장
			mb.box(Transform3D(Basis(Vector3.UP, 0.4), Vector3(size.x * 0.2, size.y * 0.42, 0)),
				Vector3(0.5, 0.06, 0.08), Color(0.5, 0.5, 0.52))
			mb.box(Transform3D(Basis.IDENTITY, Vector3(-size.x * 0.24, size.y * 0.44, 0)),
				Vector3(0.22, 0.14, 0.14), Color(0.42, 0.42, 0.44))
		"forge":
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.2, 0)),
				Vector3(size.x * 0.85, size.y * 0.4, size.z * 0.85), Color(0.35, 0.34, 0.32))
			mb.cyl(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.4, 0)),
				size.x * 0.3, size.x * 0.22, size.y * 0.55, 8, Color(0.28, 0.27, 0.26))
			mb.sphere(Vector3(0, size.y * 0.45, 0), size.x * 0.2, 7, 4,
				Color(1.0, 0.42, 0.10), Vector3(1, 0.6, 1))
		"campfire":
			mb.cyl(Transform3D.IDENTITY, size.x * 0.5, size.x * 0.44, size.y * 0.3, 9,
				Color(0.42, 0.42, 0.44))
			for i in range(5):
				var a := TAU * float(i) / 5.0
				mb.box(Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 1.1),
					Vector3(cos(a) * size.x * 0.2, size.y * 0.35, sin(a) * size.x * 0.2)),
					Vector3(0.09, size.x * 0.7, 0.09), Color(0.30, 0.21, 0.13))
		"smelter":
			mb.cyl(Transform3D.IDENTITY, size.x * 0.5, size.x * 0.30, size.y * 0.85, 8,
				Color(0.32, 0.31, 0.30))
			mb.cyl(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.85, 0)),
				size.x * 0.16, size.x * 0.16, size.y * 0.25, 7, Color(0.26, 0.25, 0.24))
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.18, size.z * 0.46)),
				Vector3(size.x * 0.35, size.y * 0.25, 0.1), Color(1.0, 0.45, 0.12))
		"kiln":
			mb.cyl(Transform3D.IDENTITY, size.x * 0.5, size.x * 0.42, size.y * 0.9, 9,
				Color(0.36, 0.34, 0.31))
			mb.cone(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.9, 0)),
				size.x * 0.42, size.y * 0.25, 9, Color(0.30, 0.28, 0.26))
		"cauldron":
			mb.cyl(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.25, 0)),
				size.x * 0.42, size.x * 0.5, size.y * 0.55, 10, Color(0.28, 0.28, 0.30))
			mb.cyl(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.72, 0)),
				size.x * 0.46, size.x * 0.46, 0.04, 10, Color(0.35, 0.42, 0.30))
			for sx in [-1.0, 1.0]:
				mb.box(Transform3D(Basis(Vector3.FORWARD, 0.3 * sx),
					Vector3(size.x * 0.4 * sx, size.y * 0.12, 0)),
					Vector3(0.07, size.y * 0.5, 0.07), Color(0.24, 0.24, 0.26))
		"cooking_station":
			for sx in [-1.0, 1.0]:
				mb.box(Transform3D(Basis.IDENTITY, Vector3(size.x * 0.45 * sx, 0, 0)),
					Vector3(0.10, size.y * 1.6, 0.10), col)
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.6, 0)),
				Vector3(size.x, 0.07, 0.07), light)
		"chest":
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, -size.y * 0.15, 0)),
				Vector3(size.x, size.y * 0.65, size.z), col)
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.25, 0)),
				Vector3(size.x * 1.02, size.y * 0.3, size.z * 1.02), dark)
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.05, size.z * 0.52)),
				Vector3(size.x * 0.16, size.y * 0.35, 0.04), Color(0.45, 0.42, 0.38))
		"bed":
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, -size.y * 0.1, 0)),
				Vector3(size.x, size.y * 0.35, size.z), col)
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.18, size.z * 0.06)),
				Vector3(size.x * 0.92, size.y * 0.3, size.z * 0.86), Color(0.55, 0.32, 0.28))
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.3, -size.z * 0.38)),
				Vector3(size.x * 0.7, size.y * 0.28, size.z * 0.16), Color(0.88, 0.86, 0.80))
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.5, -size.z * 0.5)),
				Vector3(size.x, size.y * 0.9, 0.1), dark)
		"portal":
			for sx in [-1.0, 1.0]:
				mb.box(Transform3D(Basis(Vector3.FORWARD, 0.06 * sx),
					Vector3(size.x * 0.42 * sx, 0, 0)),
					Vector3(0.24, size.y, 0.24), Color(0.42, 0.36, 0.28))
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.5, 0)),
				Vector3(size.x, 0.24, 0.24), Color(0.42, 0.36, 0.28))
			for sx2 in [-1.0, 1.0]:
				mb.sphere(Vector3(size.x * 0.42 * sx2, size.y * 0.42, 0), 0.12, 6, 4,
					Color(0.30, 0.85, 0.95))
		"sign":
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, -size.y * 0.25, 0)),
				Vector3(0.10, size.y * 0.6, 0.10), dark)
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.25, 0)),
				Vector3(size.x, size.y * 0.5, 0.07), col)
		"chair":
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)),
				Vector3(size.x, 0.09, size.z), col)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					mb.box(Transform3D(Basis.IDENTITY,
						Vector3(size.x * 0.38 * sx, -size.y * 0.28, size.z * 0.38 * sz)),
						Vector3(0.08, size.y * 0.55, 0.08), dark)
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.3, -size.z * 0.44)),
				Vector3(size.x, size.y * 0.6, 0.08), col)
		"table":
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.4, 0)),
				Vector3(size.x, 0.10, size.z), col)
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					mb.box(Transform3D(Basis.IDENTITY,
						Vector3(size.x * 0.4 * sx, 0, size.z * 0.36 * sz)),
						Vector3(0.10, size.y * 0.8, 0.10), dark)
		"banner":
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.48, 0)),
				Vector3(size.x * 1.2, 0.08, 0.08), Color(0.40, 0.30, 0.20))
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)),
				Vector3(size.x, size.y * 0.9, 0.03), col)
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.02)),
				Vector3(size.x * 0.4, size.y * 0.5, 0.02), light)
		"rug":
			mb.box(Transform3D.IDENTITY, size, col)
		"torch_stand":
			mb.cyl(Transform3D(Basis.IDENTITY, Vector3(0, -size.y * 0.5, 0)),
				size.x * 0.16, size.x * 0.10, size.y * 0.9, 6, Color(0.34, 0.25, 0.16))
			mb.cyl(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.38, 0)),
				size.x * 0.24, size.x * 0.30, size.y * 0.16, 7, Color(0.30, 0.29, 0.28))
		"windmill":
			mb.cyl(Transform3D.IDENTITY, size.x * 0.4, size.x * 0.28, size.y * 0.7, 8,
				Color(0.48, 0.36, 0.24))
			mb.cone(Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.7, 0)),
				size.x * 0.34, size.y * 0.22, 8, Color(0.34, 0.26, 0.18))
			for i in range(4):
				var a := TAU * float(i) / 4.0
				mb.box(Transform3D(Basis(Vector3.FORWARD, a),
					Vector3(cos(a) * size.x * 0.55, size.y * 0.62 + sin(a) * size.x * 0.55,
						-size.z * 0.4)),
					Vector3(size.x * 1.1, 0.22, 0.07), Color(0.72, 0.66, 0.52))
		"spinning_wheel":
			mb.cyl(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, size.y * 0.1, 0)),
				size.x * 0.42, size.x * 0.42, 0.07, 12, col)
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, -size.y * 0.35, 0)),
				Vector3(size.x * 0.7, 0.09, size.z * 0.7), dark)
		"fermenter":
			mb.cyl(Transform3D(Basis.IDENTITY, Vector3(0, -size.y * 0.5, 0)),
				size.x * 0.42, size.x * 0.48, size.y * 0.9, 10, col)
			for i in range(3):
				mb.cyl(Transform3D(Basis.IDENTITY,
					Vector3(0, -size.y * 0.5 + size.y * 0.28 * float(i + 1), 0)),
					size.x * 0.5, size.x * 0.5, 0.05, 10, Color(0.35, 0.33, 0.30))
		"plant":
			mb.cyl(Transform3D(Basis.IDENTITY, Vector3(0, -size.y * 0.5, 0)),
				size.x * 0.5, size.x * 0.44, 0.05, 7, Color(0.28, 0.20, 0.13))
		"boat":
			mb.box(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)),
				Vector3(size.x, 0.4, size.z * 0.94), col)
			for sx in [-1.0, 1.0]:
				mb.box(Transform3D(Basis.IDENTITY, Vector3(size.x * 0.5 * sx, 0.3, 0)),
					Vector3(0.16, 0.5, size.z * 0.94), dark)
			mb.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0)),
				0.10, 0.08, size.z * 0.6, 6, dark)
		_:
			mb.box(Transform3D.IDENTITY, size, col)
	_cache[k] = mb.commit()
	return _cache[k]

# ═══════════════════════════════════════════════════════ 기타
## 아이템 드롭용 작은 메시
func drop_mesh(item_id: String) -> Mesh:
	var k := _key(["drop", item_id])
	if _cache.has(k):
		return _cache[k]
	var col := ItemDB.color_of(item_id)
	var t := ItemDB.type_of(item_id)
	var mb := MeshBuilder.new()
	match t:
		Const.ItemType.WEAPON, Const.ItemType.TOOL:
			mb.box(Transform3D(Basis(Vector3.FORWARD, 0.4), Vector3.ZERO),
				Vector3(0.08, 0.7, 0.08), col.darkened(0.3))
			mb.box(Transform3D(Basis(Vector3.FORWARD, 0.4), Vector3(0.1, 0.28, 0)),
				Vector3(0.16, 0.34, 0.05), col)
		Const.ItemType.ARMOR, Const.ItemType.SHIELD:
			mb.box(Transform3D.IDENTITY, Vector3(0.36, 0.40, 0.10), col)
		Const.ItemType.CONSUMABLE:
			mb.sphere(Vector3.ZERO, 0.13, 7, 5, col)
		_:
			mb.rock(Vector3.ZERO, 0.16, item_id.hash(), col, 6, 4, 0.3)
	_cache[k] = mb.commit()
	return _cache[k]

## 무덤(사망 시 소지품 보관)
func tombstone() -> Mesh:
	if _cache.has("tomb"):
		return _cache["tomb"]
	var mb := MeshBuilder.new()
	mb.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), Vector3(0.9, 0.1, 0.6),
		Color(0.34, 0.33, 0.31))
	mb.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0)), Vector3(0.6, 1.0, 0.14),
		Color(0.46, 0.46, 0.44))
	mb.cyl(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 1.05, 0.08)),
		0.3, 0.3, 0.12, 9, Color(0.46, 0.46, 0.44))
	_cache["tomb"] = mb.commit()
	return _cache["tomb"]

## 보스 제단
func altar(biome_tier: int) -> Mesh:
	var k := _key(["altar", biome_tier])
	if _cache.has(k):
		return _cache[k]
	var mb := MeshBuilder.new()
	var stone := Color(0.38, 0.38, 0.36).darkened(float(biome_tier) * 0.03)
	mb.cyl(Transform3D.IDENTITY, 5.0, 4.6, 0.4, 12, stone)
	mb.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0)), 2.2, 2.0, 0.5, 10,
		stone.lightened(0.06))
	# 룬 스톤 서클
	for i in range(7):
		var a := TAU * float(i) / 7.0
		var p := Vector3(cos(a) * 4.0, 0.4, sin(a) * 4.0)
		mb.box(Transform3D(Basis(Vector3.UP, -a) * Basis(Vector3.FORWARD, 0.07), p +
			Vector3(0, 1.1, 0)), Vector3(0.7, 2.2, 0.35), stone.darkened(0.1))
	# 중앙 공물대
	mb.box(Transform3D(Basis.IDENTITY, Vector3(0, 1.0, 0)), Vector3(1.4, 0.7, 1.4),
		stone.lightened(0.12))
	_cache[k] = mb.commit()
	return _cache[k]
