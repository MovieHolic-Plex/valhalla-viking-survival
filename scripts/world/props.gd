class_name Props
extends RefCounted
## 청크별 배치물 생성기.
## 가까운 청크는 상호작용 가능한 실제 노드로, 먼 청크는 멀티메시(그리기 1회)로 만든다.
## 두 경로가 동일한 RNG 시퀀스를 쓰므로 배치가 완전히 일치한다.

const B := Const.Biome

## 바이옴별 배치 규칙: [종류, 서브종류, 청크당 개수, 최대 경사]
static func rules(biome: int) -> Array:
	match biome:
		B.MEADOWS:
			return [
				["tree", "beech", 9, 0.42],
				["tree", "birch", 1, 0.40],
				["rock", "", 3, 0.55],
				["bush", "raspberry", 4, 0.40],
				["pick", "branch", 5, 0.50],
				["pick", "stone", 5, 0.55],
				["pick", "flint", 3, 0.45],
				["pick", "dandelion", 6, 0.35],
				["pick", "mushroom", 2, 0.40],
			]
		B.BLACKFOREST:
			return [
				["tree", "pine", 14, 0.50],
				["tree", "fir", 8, 0.50],
				["rock", "", 5, 0.60],
				["ore", "copper", 0.35, 0.42],
				["ore", "tin", 0.7, 0.40],
				["bush", "blueberry", 4, 0.42],
				["pick", "branch", 4, 0.55],
				["pick", "stone", 3, 0.55],
				["pick", "mushroom", 5, 0.45],
				["pick", "flint", 1, 0.45],
			]
		B.SWAMP:
			return [
				["tree", "swamp_dead", 7, 0.45],
				["tree", "ancient", 3, 0.42],
				["ore", "iron", 0.9, 0.35],
				["pick", "bone", 5, 0.40],
				["pick", "guck", 3, 0.45],
				["pick", "thistle", 4, 0.40],
				["pick", "surtling_core", 0.25, 0.35],
				["rock", "", 2, 0.55],
			]
		B.MOUNTAIN:
			return [
				["tree", "fir", 1.2, 0.45],
				["rock", "", 7, 0.75],
				["ore", "silver", 0.30, 0.50],
				["ore", "obsidian", 0.55, 0.55],
				["pick", "stone", 4, 0.70],
			]
		B.PLAINS:
			return [
				["tree", "birch", 1.5, 0.40],
				["tree", "oak", 0.8, 0.38],
				["rock", "", 4, 0.55],
				["ore", "black_metal", 0.25, 0.40],
				["bush", "cloudberry", 3, 0.35],
				["pick", "barley", 4, 0.35],
				["pick", "flax", 4, 0.35],
				["pick", "stone", 2, 0.55],
			]
		B.MISTLANDS:
			return [
				["tree", "yggdrasil", 5, 0.55],
				["rock", "", 8, 0.70],
				["ore", "black_metal", 0.4, 0.45],
				["pick", "guck", 2, 0.50],
				["pick", "bone", 3, 0.50],
			]
		B.ASHLANDS:
			return [
				["tree", "swamp_dead", 3, 0.50],
				["rock", "", 9, 0.70],
				["ore", "flametal", 0.45, 0.50],
				["ore", "surtling", 0.6, 0.45],
				["pick", "bone", 4, 0.50],
			]
		_:
			return []

## 바이옴별 풀 밀도(멀티메시 인스턴스 수) / 지면색 대비 풀색 배율.
## 풀색은 그 지점의 지면 색에서 뽑아 쓰므로 여기서는 "지면보다 얼마나
## 밝고 노란가"만 정한다 — 지면과 풀이 따로 놀지 않는 게 발헤임 룩의 핵심.
static func grass_of(biome: int) -> Dictionary:
	match biome:
		B.MEADOWS: return {"n": 1100, "m": Color(1.45, 1.62, 1.15), "h": 1.15}
		B.BLACKFOREST: return {"n": 750, "m": Color(1.35, 1.70, 1.25), "h": 0.95}
		B.SWAMP: return {"n": 520, "m": Color(1.30, 1.35, 1.05), "h": 1.25}
		B.PLAINS: return {"n": 1050, "m": Color(1.35, 1.30, 0.95), "h": 1.45}
		B.MISTLANDS: return {"n": 300, "m": Color(1.25, 1.40, 1.20), "h": 0.85}
		B.ASHLANDS: return {"n": 220, "m": Color(1.25, 1.05, 0.90), "h": 0.75}
		B.MOUNTAIN: return {"n": 0, "m": Color.WHITE, "h": 1.0}
		_: return {"n": 0, "m": Color.WHITE, "h": 1.0}

# ═══════════════════════════════════════════════ 배치
## detailed=true 면 상호작용 가능한 노드, false 면 멀티메시 시각물만.
static func populate(chunk: TerrainChunk, gen: WorldGen, detailed: bool,
		removed: Dictionary) -> void:
	var parent := chunk.props
	for c in parent.get_children():
		c.queue_free()

	var cx := chunk.cx
	var cz := chunk.cz
	var ox := float(cx) * Const.CHUNK_SIZE
	var oz := float(cz) * Const.CHUNK_SIZE
	var rng := gen.chunk_rng(cx, cz, 77)

	# 멀티메시용 누적 변환 목록: key -> Array[Transform3D]
	var mm_bucket: Dictionary = {}
	var idx := 0

	# 청크 대표 바이옴으로 규칙을 정하되, 개별 배치는 지점 바이옴을 다시 확인한다
	var center_h := gen.height(ox + Const.CHUNK_SIZE * 0.5, oz + Const.CHUNK_SIZE * 0.5)
	var center_b := gen.biome_from(ox + Const.CHUNK_SIZE * 0.5, oz + Const.CHUNK_SIZE * 0.5,
		center_h)
	var rl := rules(center_b)

	for rule in rl:
		var rtype: String = rule[0]
		var rsub: String = rule[1]
		var rcount: float = float(rule[2])
		var max_slope: float = float(rule[3])
		# 소수 개수는 확률로 처리
		var n := int(rcount)
		if rng.randf() < (rcount - float(n)):
			n += 1
		for i in range(n):
			idx += 1
			var px := ox + rng.randf() * Const.CHUNK_SIZE
			var pz := oz + rng.randf() * Const.CHUNK_SIZE
			var yaw := rng.randf() * TAU
			var scl := rng.randf_range(0.85, 1.2)
			var sv := int(rng.randi())

			var h := gen.height(px, pz)
			if h < Const.WATER_LEVEL + 0.4:
				continue
			if gen.biome_from(px, pz, h) != center_b:
				continue
			if gen.slope_at(px, pz) > max_slope:
				continue
			# 숲 밀도 노이즈로 나무는 뭉치게
			if rtype == "tree" and gen.forest_density(px, pz) < 0.30:
				continue
			if removed.has(idx):
				continue

			var lpos := Vector3(px - ox, h, pz - oz)
			if detailed:
				var node := _make_node(rtype, rsub, sv, rng)
				if node == null:
					continue
				parent.add_child(node)
				node.position = lpos
				node.rotation.y = yaw
				node.scale = Vector3(scl, scl, scl)
				node.set_meta("chunk", Vector2i(cx, cz))
				node.set_meta("idx", idx)
			else:
				var key := rtype + ":" + rsub + ":" + str(sv % 8)
				if not mm_bucket.has(key):
					mm_bucket[key] = {"sv": sv, "type": rtype, "sub": rsub, "xf": []}
				var xf := Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(scl, scl, scl)),
					lpos)
				mm_bucket[key]["xf"].append(xf)

	if not detailed:
		_build_multimesh(parent, mm_bucket)

	_build_grass(parent, gen, cx, cz, center_b, detailed)

static func _make_node(rtype: String, rsub: String, sv: int,
		rng: RandomNumberGenerator) -> ResourceNode:
	match rtype:
		"tree":
			return ResourceNode.make_tree(rsub, sv)
		"rock":
			return ResourceNode.make_rock(rng.randf_range(0.6, 1.9), sv)
		"ore":
			return ResourceNode.make_ore(rsub, rng.randf_range(1.1, 2.0), sv)
		"bush":
			return ResourceNode.make_bush(rsub, sv)
		"pick":
			return ResourceNode.make_pickable(rsub, sv)
	return null

static func _build_multimesh(parent: Node3D, buckets: Dictionary) -> void:
	for key in buckets:
		var b: Dictionary = buckets[key]
		var xfs: Array = b["xf"]
		if xfs.is_empty():
			continue
		var meshes: Array = _visual_meshes(b["type"], b["sub"], int(b["sv"]))
		for pair in meshes:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = pair[0]
			mm.instance_count = xfs.size()
			for i in xfs.size():
				mm.set_instance_transform(i, xfs[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = pair[1]
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mmi)

## 멀티메시용 (메시, 머티리얼) 쌍 목록
static func _visual_meshes(rtype: String, rsub: String, sv: int) -> Array:
	match rtype:
		"tree":
			var t := MeshFactory.tree(rsub, sv)
			return [
				[t["trunk"], MatLib.flat(Color.WHITE)],
				[t["leaves"], MatLib.leaf_card()],
			]
		"rock":
			return [[MeshFactory.boulder(1.2, sv), MatLib.flat(Color.WHITE, 0.98)]]
		"ore":
			var od := MeshFactory.ore_node(rsub, 1.5, sv)
			return [
				[od["rock"], MatLib.flat(Color.WHITE, 0.98)],
				[od["vein"], MatLib.flat(Color.WHITE, 0.45, 0.5)],
			]
		"bush":
			var bb := MeshFactory.bush(rsub, sv)
			return [[bb["leaves"], MatLib.foliage(Color.WHITE, 0.0, 0.07)]]
	return []

static func _build_grass(parent: Node3D, gen: WorldGen, cx: int, cz: int, biome: int,
		detailed: bool) -> void:
	var g := grass_of(biome)
	var n: int = int(g["n"])
	if n <= 0:
		return
	if not detailed:
		n = int(n * 0.35)      # 먼 청크는 성글게 — 안개에 묻혀 티가 안 난다
	var mul: Color = g["m"]
	var hscale: float = float(g["h"])
	var rng := gen.chunk_rng(cx, cz, 991)
	var ox := float(cx) * Const.CHUNK_SIZE
	var oz := float(cz) * Const.CHUNK_SIZE

	var xfs: Array[Transform3D] = []
	var cols: Array[Color] = []
	for i in range(n):
		var px := ox + rng.randf() * Const.CHUNK_SIZE
		var pz := oz + rng.randf() * Const.CHUNK_SIZE
		var h := gen.height(px, pz)
		if h < Const.WATER_LEVEL + 0.3:
			continue
		var b := gen.biome_from(px, pz, h)
		if b != biome:
			continue
		# 가파른 곳엔 풀이 붙지 않는다 (암반이 드러나야 한다)
		if gen.slope_at(px, pz) > 0.55:
			continue
		var s := rng.randf_range(0.70, 1.20)
		xfs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU)
			.scaled(Vector3(s, s * hscale * rng.randf_range(0.80, 1.30), s)),
			Vector3(px - ox, h - 0.06, pz - oz)))
		# 그 지점 지면 색에서 풀색을 뽑는다
		var gc := gen.ground_color(px, pz, h, b)
		var v := rng.randf_range(0.86, 1.14)
		cols.append(Color(
			clampf(gc.r * mul.r * v, 0.0, 1.0),
			clampf(gc.g * mul.g * v, 0.0, 1.0),
			clampf(gc.b * mul.b * v, 0.0, 1.0), 1.0))
	if xfs.is_empty():
		return

	# 포기 모양을 몇 종류 섞어야 반복 티가 안 난다
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = MeshFactory.grass_tuft(cx * 7919 + cz * 131, 6 if detailed else 4)
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "grass"
	mmi.multimesh = mm
	# 먼 풀은 셰이더에서 납작하게 눌러 컬링 경계가 드러나지 않게 한다
	mmi.material_override = MatLib.foliage(Color.WHITE, 0.0, 0.20, 34.0, 62.0)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)
