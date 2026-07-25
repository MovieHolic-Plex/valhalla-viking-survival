class_name BuildSystem
extends Node3D
## 건축 모드: 스냅 미리보기 · 설치/철거 · 구조 무결성 전파.

signal piece_selected(id: String)
signal build_mode_changed(active: bool)

const GRID := 2.0             # 기본 격자(벽·바닥 크기)
const FREE_SNAP := 0.5
const RANGE := 8.0
const MAX_PIECES := 3000

var active := false
var current_id := "wood_floor"
var rot_step := 0.0
var pieces: Array[BuildPiece] = []

var player: Player
var _ghost: MeshInstance3D
var _ghost_id := ""
var _valid := false
var _place_xf := Transform3D.IDENTITY
var _cooldown := 0.0
var _mat_ok := MatLib.ghost(Color(0.30, 1.0, 0.45))
var _mat_bad := MatLib.ghost(Color(1.0, 0.28, 0.22))

func setup(p: Player) -> void:
	player = p

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if player == null or not is_instance_valid(player):
		return
	var want := player.inventory.equipped_id(Inventory.SLOT_RIGHT) == "hammer" \
		and not player.input_locked and not player.stats.is_dead
	if want != active:
		active = want
		build_mode_changed.emit(active)
		if not active:
			_clear_ghost()
	if not active:
		return
	_update_ghost()

	if Input.is_action_just_pressed("rotate_piece"):
		rot_step = fmod(rot_step + PI * 0.25, TAU)
		Sfx.play("click", -18.0)
	if Input.is_action_just_pressed("attack") and _cooldown <= 0.0:
		_cooldown = 0.2
		try_place()
	if Input.is_action_just_pressed("block") and _cooldown <= 0.0:
		_cooldown = 0.2
		try_remove()

func select(id: String) -> void:
	if not RecipeDB.pieces.has(id):
		return
	current_id = id
	piece_selected.emit(id)
	_clear_ghost()

# ═══════════════════════════════════════════════ 미리보기
func _clear_ghost() -> void:
	if _ghost and is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
	_ghost_id = ""

func _update_ghost() -> void:
	var d := RecipeDB.piece(current_id)
	if d.is_empty():
		return
	if _ghost == null or _ghost_id != current_id:
		_clear_ghost()
		_ghost = MeshInstance3D.new()
		_ghost.mesh = MeshFactory.piece(str(d.get("kind", "wall")),
			d.get("size", Vector3.ONE), Color.WHITE)
		_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ghost)
		_ghost_id = current_id

	var hit := _aim()
	if hit.is_empty():
		_ghost.visible = false
		_valid = false
		return
	_ghost.visible = true
	_place_xf = _snap(d, hit["position"], hit.get("normal", Vector3.UP))
	_ghost.global_transform = _place_xf
	_valid = _check_valid(d, _place_xf)
	_ghost.material_override = _mat_ok if _valid else _mat_bad

func _aim() -> Dictionary:
	var cam := player.cam
	var from := cam.global_position
	var to := from + -cam.global_transform.basis.z * (RANGE + player.spring.spring_length)
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = Const.L_WORLD | Const.L_BUILDING | Const.L_RESOURCE
	q.exclude = [player.get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return {}
	if hit["position"].distance_to(player.global_position) > RANGE + 2.0:
		return {}
	return hit

## 조각 종류에 맞는 격자 스냅
func _snap(d: Dictionary, pos: Vector3, normal: Vector3) -> Transform3D:
	var kind := str(d.get("kind", "wall"))
	var size: Vector3 = d.get("size", Vector3.ONE)
	var yaw := rot_step
	var p := pos

	match kind:
		"floor", "roof", "roof_top", "rug", "stair":
			p.x = snappedf(pos.x - 1.0, GRID) + 1.0
			p.z = snappedf(pos.z - 1.0, GRID) + 1.0
			p.y = snappedf(pos.y, GRID)
			if kind == "floor" or kind == "rug":
				p.y += size.y * 0.5
			else:
				p.y += size.y * 0.5
		"wall", "wall_half", "door", "fence", "ladder":
			# 회전 방향에 따라 X변 또는 Z변에 붙인다
			var along_x := absf(sin(yaw)) < 0.5
			if along_x:
				p.x = snappedf(pos.x - 1.0, GRID) + 1.0
				p.z = snappedf(pos.z, GRID)
			else:
				p.x = snappedf(pos.x, GRID)
				p.z = snappedf(pos.z - 1.0, GRID) + 1.0
			p.y = snappedf(pos.y, GRID) + size.y * 0.5
		"beam", "pole", "beam_diag":
			p.x = snappedf(pos.x, GRID * 0.5)
			p.z = snappedf(pos.z, GRID * 0.5)
			p.y = snappedf(pos.y, GRID * 0.5) + size.y * 0.5
		"boat":
			# 배는 자유 배치 + 수면에 띄운다
			p.y = Const.WATER_LEVEL
		_:
			# 가구·시설물은 지면에 자유 배치
			p.x = snappedf(pos.x, FREE_SNAP)
			p.z = snappedf(pos.z, FREE_SNAP)
			var gh := GameState.height_at(p.x, p.z)
			p.y = maxf(pos.y, gh) + size.y * 0.5
	return Transform3D(Basis(Vector3.UP, yaw), p)

func _check_valid(d: Dictionary, xf: Transform3D) -> bool:
	if pieces.size() >= MAX_PIECES:
		return false
	if player.inventory.is_overweight():
		pass
	if not player.inventory.has_materials(d.get("mats", {})):
		return false
	if bool(d.get("needs_workbench", true)) and not _near_station(xf.origin):
		return false
	# 지면 필요 조각
	if bool(d.get("ground", false)):
		var gh := GameState.height_at(xf.origin.x, xf.origin.z)
		var size: Vector3 = d.get("size", Vector3.ONE)
		if absf(xf.origin.y - size.y * 0.5 - gh) > 0.8:
			return false
	if bool(d.get("water", false)):
		# 배는 반대로 충분히 깊은 물 위여야 한다
		var gh2 := GameState.height_at(xf.origin.x, xf.origin.z)
		if Const.WATER_LEVEL - gh2 < 1.4:
			return false
	elif xf.origin.y < Const.WATER_LEVEL - 0.5:
		# 그 외 건축물은 물속에 지을 수 없다
		return false
	# 겹침 검사
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var bs := BoxShape3D.new()
	bs.size = (d.get("size", Vector3.ONE) as Vector3) * 0.82
	q.shape = bs
	q.transform = xf
	q.collision_mask = Const.L_BUILDING | Const.L_RESOURCE | Const.L_PLAYER
	if not space.intersect_shape(q, 1).is_empty():
		return false
	return true

func _near_station(pos: Vector3) -> bool:
	for s in get_tree().get_nodes_in_group("craft_station"):
		if not is_instance_valid(s):
			continue
		if str(s.data.get("station", "")) == "" :
			continue
		if s.global_position.distance_to(pos) < 20.0:
			return true
	return false

# ═══════════════════════════════════════════════ 설치 / 철거
func try_place() -> bool:
	if not _valid:
		Sfx.play("error", -14.0)
		return false
	var d := RecipeDB.piece(current_id)
	if not player.inventory.consume(d.get("mats", {})):
		return false
	# 배는 건축 조각이 아니라 탈것으로 만든다
	if d.has("boat"):
		var boat := Boat.make(str(d["boat"]))
		get_tree().current_scene.add_child(boat)
		boat.global_position = Vector3(_place_xf.origin.x, Const.WATER_LEVEL,
			_place_xf.origin.z)
		boat.rotation.y = rot_step
		GameState.stats["built"] = int(GameState.stats["built"]) + 1
		Sfx.play_at("build", boat.global_position, get_tree().current_scene, -2.0)
		return true

	var piece := BuildPiece.make(current_id)
	get_tree().current_scene.add_child(piece)
	piece.global_transform = _place_xf
	piece.yaw = rot_step
	piece.rotation.y = rot_step
	piece.removed.connect(_on_piece_removed)
	pieces.append(piece)
	GameState.stats["built"] = int(GameState.stats["built"]) + 1
	Sfx.play_at("build", _place_xf.origin, get_tree().current_scene, -4.0)
	Fx.burst(get_tree().current_scene, _place_xf.origin, Color(0.7, 0.6, 0.4), 10, 2.5,
		0.06, 0.6)
	recompute_support()
	return true

func try_remove() -> bool:
	var hit := _aim()
	if hit.is_empty():
		return false
	var col = hit["collider"]
	if col == null or not (col is BuildPiece):
		return false
	col.destroy(true)
	return true

func _on_piece_removed(p) -> void:
	pieces.erase(p)
	call_deferred("recompute_support")

# ═══════════════════════════════════════════════ 구조 무결성
## 지면에 닿은 조각에서 시작해 지지력을 전파한다. 0 이하가 되면 무너진다.
func recompute_support() -> void:
	var live: Array[BuildPiece] = []
	for p in pieces:
		if is_instance_valid(p):
			live.append(p)
	pieces = live
	if pieces.is_empty():
		return

	# 공간 해시
	var grid: Dictionary = {}
	for p in pieces:
		var k := _cell(p.global_position)
		if not grid.has(k):
			grid[k] = []
		grid[k].append(p)

	var queue: Array = []
	for p in pieces:
		var size: Vector3 = p.data.get("size", Vector3.ONE)
		var gh := GameState.height_at(p.global_position.x, p.global_position.z)
		p.grounded = (p.global_position.y - size.y * 0.5) <= gh + 0.45
		p.support = 1.0 if p.grounded else 0.0
		if p.grounded:
			queue.append(p)

	var guard := 0
	while not queue.is_empty() and guard < 40000:
		guard += 1
		var cur: BuildPiece = queue.pop_front()
		for nb in _neighbors(cur, grid):
			var stone: bool = bool(nb.data.get("stone", false)) \
				and bool(cur.data.get("stone", false))
			var dy: float = nb.global_position.y - cur.global_position.y
			# 수직으로 쌓는 편이 손실이 적다
			var cost := 0.06 if absf(dy) > 0.6 else 0.14
			if stone:
				cost *= 0.45
			var s: float = cur.support - cost
			if s > nb.support + 0.001:
				nb.support = s
				queue.append(nb)

	for p in pieces:
		if p.support <= 0.0 and not p.grounded:
			p.call_deferred("destroy", true)
		else:
			_tint_support(p)

func _tint_support(p: BuildPiece) -> void:
	# 지지력이 약할수록 붉게 (발헤임의 건축 하이라이트와 같은 개념)
	pass

static func _cell(pos: Vector3) -> Vector3i:
	return Vector3i(int(floor(pos.x / 2.0)), int(floor(pos.y / 2.0)),
		int(floor(pos.z / 2.0)))

func _neighbors(p: BuildPiece, grid: Dictionary) -> Array:
	var out: Array = []
	var base := _cell(p.global_position)
	var ps: Vector3 = p.data.get("size", Vector3.ONE)
	for dz in range(-1, 2):
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var arr = grid.get(Vector3i(base.x + dx, base.y + dy, base.z + dz))
				if arr == null:
					continue
				for q in arr:
					if q == p:
						continue
					var qs: Vector3 = q.data.get("size", Vector3.ONE)
					var d: Vector3 = (q.global_position - p.global_position).abs()
					var lim := (ps + qs) * 0.5 + Vector3(0.35, 0.35, 0.35)
					if d.x <= lim.x and d.y <= lim.y and d.z <= lim.z:
						out.append(q)
	return out

# ═══════════════════════════════════════════════ 제작대 질의
## 주어진 위치에서 사용 가능한 제작대 레벨 (0 = 없음)
func station_level(station: String, pos: Vector3) -> int:
	var found := false
	var lvl := 1
	for s in get_tree().get_nodes_in_group("craft_station"):
		if not is_instance_valid(s):
			continue
		var dist: float = s.global_position.distance_to(pos)
		if dist > 20.0:
			continue
		if str(s.data.get("station", "")) == station:
			found = true
	if not found:
		return 0
	# 업그레이드 부속 계산
	for s in get_tree().get_nodes_in_group("craft_station"):
		if not is_instance_valid(s) or s.global_position.distance_to(pos) > 20.0:
			continue
		if station == RecipeDB.ST_WORKBENCH:
			lvl += int(s.data.get("wb_up", 0))
		elif station == RecipeDB.ST_FORGE:
			lvl += int(s.data.get("forge_up", 0))
	return mini(lvl, 6)

func to_dict() -> Array:
	var out: Array = []
	for p in pieces:
		if is_instance_valid(p):
			out.append(p.to_dict())
	return out

func from_dict(arr: Array) -> void:
	for p in pieces:
		if is_instance_valid(p):
			p.queue_free()
	pieces.clear()
	for d in arr:
		var piece := BuildPiece.make(str(d.get("id", "wood_floor")))
		get_tree().current_scene.add_child(piece)
		var pp: Array = d.get("p", [0, 0, 0])
		piece.global_position = Vector3(float(pp[0]), float(pp[1]), float(pp[2]))
		piece.rotation.y = float(d.get("y", 0.0))
		piece.from_dict(d)
		piece.removed.connect(_on_piece_removed)
		pieces.append(piece)
	call_deferred("recompute_support")
