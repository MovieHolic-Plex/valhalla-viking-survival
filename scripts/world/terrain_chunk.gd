class_name TerrainChunk
extends StaticBody3D
## 지형 청크 하나. 격자 하이트필드 + 버텍스 컬러 + 스커트(LOD 균열 은폐).

var cx: int
var cz: int
var res: int = 24
var has_collision := false

var _mi: MeshInstance3D
var _col: CollisionShape3D
var props: Node3D          # 나무·바위 등 배치물 컨테이너

func setup(gen: WorldGen, _cx: int, _cz: int, _res: int, want_collision: bool) -> void:
	cx = _cx
	cz = _cz
	res = maxi(4, _res)
	name = "chunk_%d_%d" % [cx, cz]
	collision_layer = Const.L_WORLD
	collision_mask = 0
	position = Vector3(float(cx) * Const.CHUNK_SIZE, 0.0, float(cz) * Const.CHUNK_SIZE)

	_mi = MeshInstance3D.new()
	_mi.name = "mesh"
	_mi.mesh = _build_mesh(gen)
	_mi.material_override = MatLib.terrain_mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(_mi)

	if want_collision:
		_make_collision(gen)

	props = Node3D.new()
	props.name = "props"
	add_child(props)

func _build_mesh(gen: WorldGen) -> ArrayMesh:
	var step := Const.CHUNK_SIZE / float(res)
	var ox := float(cx) * Const.CHUNK_SIZE
	var oz := float(cz) * Const.CHUNK_SIZE

	# 여유 링 1칸을 더 샘플링해 경계 법선을 매끄럽게
	var n := res + 3
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	var cols: Array[Color] = []
	cols.resize(n * n)
	for j in range(n):
		for i in range(n):
			var wx := ox + float(i - 1) * step
			var wz := oz + float(j - 1) * step
			var h := gen.height(wx, wz)
			hs[j * n + i] = h
			cols[j * n + i] = gen.ground_color(wx, wz, h, gen.biome_from(wx, wz, h))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)

	var get_p := func(i: int, j: int) -> Vector3:
		return Vector3(float(i) * step, hs[(j + 1) * n + (i + 1)], float(j) * step)
	var get_n := func(i: int, j: int) -> Vector3:
		var hl: float = hs[(j + 1) * n + i]
		var hr: float = hs[(j + 1) * n + (i + 2)]
		var hd: float = hs[j * n + (i + 1)]
		var hu: float = hs[(j + 2) * n + (i + 1)]
		return Vector3(hl - hr, 2.0 * step, hd - hu).normalized()
	var get_c := func(i: int, j: int) -> Color:
		return cols[(j + 1) * n + (i + 1)]

	for j in range(res):
		for i in range(res):
			var p00: Vector3 = get_p.call(i, j)
			var p10: Vector3 = get_p.call(i + 1, j)
			var p11: Vector3 = get_p.call(i + 1, j + 1)
			var p01: Vector3 = get_p.call(i, j + 1)
			var n00: Vector3 = get_n.call(i, j)
			var n10: Vector3 = get_n.call(i + 1, j)
			var n11: Vector3 = get_n.call(i + 1, j + 1)
			var n01: Vector3 = get_n.call(i, j + 1)
			var c00: Color = get_c.call(i, j)
			var c10: Color = get_c.call(i + 1, j)
			var c11: Color = get_c.call(i + 1, j + 1)
			var c01: Color = get_c.call(i, j + 1)
			# 대각선 방향을 번갈아 두면 격자 무늬가 덜 보인다
			if (i + j) % 2 == 0:
				_emit(st, p00, n00, c00, p01, n01, c01, p11, n11, c11)
				_emit(st, p00, n00, c00, p11, n11, c11, p10, n10, c10)

			else:
				_emit(st, p00, n00, c00, p01, n01, c01, p10, n10, c10)
				_emit(st, p01, n01, c01, p11, n11, c11, p10, n10, c10)


	_add_skirt(st, get_p, get_c)

	return st.commit()

func _emit(st: SurfaceTool, a: Vector3, na: Vector3, ca: Color,
		b: Vector3, nb: Vector3, cb: Color, c: Vector3, nc: Vector3, cc: Color) -> void:
	st.set_normal(na); st.set_color(ca); st.set_uv(Vector2(a.x, a.z) * 0.05); st.add_vertex(a)
	st.set_normal(nb); st.set_color(cb); st.set_uv(Vector2(b.x, b.z) * 0.05); st.add_vertex(b)
	st.set_normal(nc); st.set_color(cc); st.set_uv(Vector2(c.x, c.z) * 0.05); st.add_vertex(c)

## LOD 해상도가 다른 이웃 청크와의 틈을 가리는 세로 치마
func _add_skirt(st: SurfaceTool, get_p: Callable, get_c: Callable) -> void:
	var drop := Vector3(0, -6.0, 0)
	var edges: Array = []
	for i in range(res):
		edges.append([get_p.call(i, 0), get_p.call(i + 1, 0), get_c.call(i, 0), false])
		edges.append([get_p.call(i + 1, res), get_p.call(i, res), get_c.call(i, res), false])
	for j in range(res):
		edges.append([get_p.call(res, j), get_p.call(res, j + 1), get_c.call(res, j), false])
		edges.append([get_p.call(0, j + 1), get_p.call(0, j), get_c.call(0, j), false])
	for e in edges:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var c: Color = e[2]
		var a2 := a + drop
		var b2 := b + drop
		var nrm := (b - a).cross(Vector3.DOWN).normalized()
		st.set_normal(nrm); st.set_color(c); st.set_uv(Vector2.ZERO); st.add_vertex(a)
		st.set_normal(nrm); st.set_color(c); st.set_uv(Vector2.ZERO); st.add_vertex(b)
		st.set_normal(nrm); st.set_color(c); st.set_uv(Vector2.ZERO); st.add_vertex(b2)
		st.set_normal(nrm); st.set_color(c); st.set_uv(Vector2.ZERO); st.add_vertex(a)
		st.set_normal(nrm); st.set_color(c); st.set_uv(Vector2.ZERO); st.add_vertex(b2)
		st.set_normal(nrm); st.set_color(c); st.set_uv(Vector2.ZERO); st.add_vertex(a2)

## 지형 충돌은 하이트맵으로 만든다 — 1m 간격 격자라 스케일 보정이 필요 없고
## 삼각형 메시보다 빠르며 레이/캐릭터 충돌이 안정적이다.
func _make_collision(gen: WorldGen) -> void:
	var w := int(Const.CHUNK_SIZE) + 1
	var ox := float(cx) * Const.CHUNK_SIZE
	var oz := float(cz) * Const.CHUNK_SIZE
	var data := PackedFloat32Array()
	data.resize(w * w)
	for j in range(w):
		for i in range(w):
			data[j * w + i] = gen.height(ox + float(i), oz + float(j))
	var shape := HeightMapShape3D.new()
	shape.map_width = w
	shape.map_depth = w
	shape.map_data = data
	_col = CollisionShape3D.new()
	_col.name = "col"
	_col.shape = shape
	# HeightMapShape3D 는 노드 원점을 중심으로 펼쳐지므로 청크 중앙에 놓는다
	_col.position = Vector3(float(w - 1) * 0.5, 0.0, float(w - 1) * 0.5)
	add_child(_col)
	has_collision = true

func add_collision_later(gen: WorldGen) -> void:
	if has_collision:
		return
	_make_collision(gen)
