class_name MeshBuilder
extends RefCounted
## 로우폴리 메시 조립기.
## 박스·원기둥·원뿔·저면 구·쐐기를 하나의 ArrayMesh 로 합쳐 페이스티드 셰이딩을 낸다.
## 발헤임 룩: 폴리곤은 적고, 면은 각지고, 색은 버텍스 컬러로.

var st: SurfaceTool
var count := 0

func _init() -> void:
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)  # -1 = 평면 셰이딩(각진 로우폴리)

func smooth(on: bool) -> MeshBuilder:
	st.set_smooth_group(0 if on else -1)
	return self

# ─────────────────────────────────────────────── 저수준
func _v(p: Vector3, c: Color, uv: Vector2 = Vector2.ZERO) -> void:
	st.set_color(c)
	st.set_uv(uv)
	st.add_vertex(p)
	count += 1

func tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	_v(a, col, Vector2(0, 0))
	_v(b, col, Vector2(1, 0))
	_v(c, col, Vector2(0.5, 1))

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_v(a, col, Vector2(0, 0)); _v(b, col, Vector2(1, 0)); _v(c, col, Vector2(1, 1))
	_v(a, col, Vector2(0, 0)); _v(c, col, Vector2(1, 1)); _v(d, col, Vector2(0, 1))

# ─────────────────────────────────────────────── 프리미티브
## 중심 기준 박스
func box(xf: Transform3D, size: Vector3, col: Color) -> MeshBuilder:
	var h := size * 0.5
	var p := [
		xf * Vector3(-h.x, -h.y, -h.z), xf * Vector3(h.x, -h.y, -h.z),
		xf * Vector3(h.x, -h.y, h.z), xf * Vector3(-h.x, -h.y, h.z),
		xf * Vector3(-h.x, h.y, -h.z), xf * Vector3(h.x, h.y, -h.z),
		xf * Vector3(h.x, h.y, h.z), xf * Vector3(-h.x, h.y, h.z),
	]
	quad(p[7], p[6], p[5], p[4], col)   # +Y
	quad(p[0], p[1], p[2], p[3], col)   # -Y
	quad(p[3], p[2], p[6], p[7], col)   # +Z
	quad(p[1], p[0], p[4], p[5], col)   # -Z
	quad(p[2], p[1], p[5], p[6], col)   # +X
	quad(p[0], p[3], p[7], p[4], col)   # -X
	return self

## 바닥 중심(0,0,0)에서 위로 자라는 박스
func box_up(pos: Vector3, size: Vector3, col: Color) -> MeshBuilder:
	return box(Transform3D(Basis.IDENTITY, pos + Vector3(0, size.y * 0.5, 0)), size, col)

## 원기둥/원뿔대. 바닥 중심 기준, +Y 로 h 만큼.
func cyl(xf: Transform3D, r0: float, r1: float, h: float, seg: int, col: Color,
		cap_bottom: bool = true, cap_top: bool = true) -> MeshBuilder:
	seg = maxi(3, seg)
	var prev_b := Vector3.ZERO
	var prev_t := Vector3.ZERO
	for i in range(seg + 1):
		var a := TAU * float(i) / float(seg)
		var cb := Vector3(cos(a) * r0, 0.0, sin(a) * r0)
		var ct := Vector3(cos(a) * r1, h, sin(a) * r1)
		var b := xf * cb
		var t := xf * ct
		if i > 0:
			if r0 > 0.0001 or r1 > 0.0001:
				quad(prev_b, b, t, prev_t, col)
			if cap_bottom and r0 > 0.0001:
				tri(xf * Vector3(0, 0, 0), b, prev_b, col)
			if cap_top and r1 > 0.0001:
				tri(xf * Vector3(0, h, 0), prev_t, t, col)
		prev_b = b
		prev_t = t
	return self

func cone(xf: Transform3D, r: float, h: float, seg: int, col: Color) -> MeshBuilder:
	return cyl(xf, r, 0.0, h, seg, col, true, false)

## 저폴리 UV 구 (중심 기준)
func sphere(ctr: Vector3, r: float, seg: int, rings: int, col: Color,
		squash: Vector3 = Vector3.ONE) -> MeshBuilder:
	seg = maxi(4, seg)
	rings = maxi(2, rings)
	for j in range(rings):
		var p0 := PI * float(j) / float(rings)
		var p1 := PI * float(j + 1) / float(rings)
		for i in range(seg):
			var t0 := TAU * float(i) / float(seg)
			var t1 := TAU * float(i + 1) / float(seg)
			var a := ctr + _sph(r, p0, t0) * squash
			var b := ctr + _sph(r, p0, t1) * squash
			var c := ctr + _sph(r, p1, t1) * squash
			var d := ctr + _sph(r, p1, t0) * squash
			if j == 0:
				tri(a, c, d, col)
			elif j == rings - 1:
				tri(a, b, c, col)
			else:
				quad(a, b, c, d, col)
	return self

func _sph(r: float, phi: float, theta: float) -> Vector3:
	return Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta)) * r

## 불규칙한 바위 — 구를 시드 기반으로 찌그러뜨린다
func rock(ctr: Vector3, r: float, seed_v: int, col: Color, seg: int = 7, rings: int = 5,
		jitter: float = 0.34, squash: Vector3 = Vector3(1, 0.8, 1)) -> MeshBuilder:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	# 링 x 세그먼트 격자를 미리 흔들어 두고 면을 잇는다
	var grid: Array = []
	for j in range(rings + 1):
		var row: Array = []
		for i in range(seg):
			var phi := PI * float(j) / float(rings)
			var th := TAU * float(i) / float(seg)
			var rr := r * (1.0 + rng.randf_range(-jitter, jitter))
			row.append(ctr + _sph(rr, phi, th) * squash)
		grid.append(row)
	for j in range(rings):
		for i in range(seg):
			var i2 := (i + 1) % seg
			var a: Vector3 = grid[j][i]
			var b: Vector3 = grid[j][i2]
			var c: Vector3 = grid[j + 1][i2]
			var d: Vector3 = grid[j + 1][i]
			if j == 0:
				tri(a, c, d, col)
			elif j == rings - 1:
				tri(a, b, c, col)
			else:
				quad(a, b, c, d, col)
	return self

## 지붕용 쐐기. 바닥 w x d, 높이 h, +X 방향으로 경사.
func wedge(xf: Transform3D, w: float, h: float, d: float, col: Color) -> MeshBuilder:
	var hw := w * 0.5
	var hd := d * 0.5
	var a := xf * Vector3(-hw, 0, -hd)
	var b := xf * Vector3(hw, 0, -hd)
	var c := xf * Vector3(hw, 0, hd)
	var dd := xf * Vector3(-hw, 0, hd)
	var e := xf * Vector3(-hw, h, -hd)
	var f := xf * Vector3(-hw, h, hd)
	quad(a, b, c, dd, col)      # 바닥
	quad(e, f, dd, a, col)      # 뒷벽
	quad(b, e, a, a, col)       # 측면(퇴화 방지용 삼각 처리)
	tri(a, e, b, col)
	tri(dd, c, f, col)
	quad(b, e, f, c, col)       # 경사면
	return self

## 사면 지붕(양쪽 경사)
func gable(xf: Transform3D, w: float, h: float, d: float, col: Color) -> MeshBuilder:
	var hw := w * 0.5
	var hd := d * 0.5
	var a := xf * Vector3(-hw, 0, -hd)
	var b := xf * Vector3(hw, 0, -hd)
	var c := xf * Vector3(hw, 0, hd)
	var dd := xf * Vector3(-hw, 0, hd)
	var r0 := xf * Vector3(0, h, -hd)
	var r1 := xf * Vector3(0, h, hd)
	quad(a, b, c, dd, col)
	quad(a, dd, r1, r0, col)
	quad(c, b, r0, r1, col)
	tri(a, r0, b, col)
	tri(c, r1, dd, col)
	return self

## 평면 사각형(러그, 배너, 잎사귀 카드)
func plane(xf: Transform3D, w: float, d: float, col: Color) -> MeshBuilder:
	var hw := w * 0.5
	var hd := d * 0.5
	quad(xf * Vector3(-hw, 0, -hd), xf * Vector3(hw, 0, -hd),
		 xf * Vector3(hw, 0, hd), xf * Vector3(-hw, 0, hd), col)
	return self

## 두 점을 잇는 막대
func rod(a: Vector3, b: Vector3, r: float, seg: int, col: Color) -> MeshBuilder:
	var dir := b - a
	var len := dir.length()
	if len < 0.0001:
		return self
	var xf := Transform3D(_basis_from_up(dir / len), a)
	return cyl(xf, r, r, len, seg, col)

static func _basis_from_up(up: Vector3) -> Basis:
	var u := up.normalized()
	var ref := Vector3.RIGHT if absf(u.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := ref.cross(u).normalized()
	var z := u.cross(x).normalized()
	return Basis(x, u, z)

# ─────────────────────────────────────────────── 마감
func commit(generate_normals: bool = true) -> ArrayMesh:
	if count == 0:
		return ArrayMesh.new()      # 빈 메시 — 탄젠트 생성 경고 방지
	if generate_normals:
		st.generate_normals()
	st.generate_tangents()
	return st.commit()
