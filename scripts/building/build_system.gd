class_name BuildSystem
extends Node3D
## 건축 모드: 스냅 미리보기 · 설치/철거 · 구조 무결성 전파.

signal piece_selected(id: String)
signal build_mode_changed(active: bool)
signal placement_resolved(result: Dictionary)

const FAULT_NONE := ""
const FAULT_RESERVE := "reserve"
const FAULT_CREATE := "create"
const FAULT_ATTACH := "attach"
const FAULT_EVIDENCE := "evidence"

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
var _injected_fault := FAULT_NONE
var _placement_committing := false

## 결정적 트랜잭션 결함 주입은 디버그 빌드에서만 사용할 수 있다.
func set_placement_fault_for_debug(fault: String) -> bool:
	if not OS.is_debug_build() or fault not in [FAULT_NONE, FAULT_RESERVE, FAULT_CREATE,
			FAULT_ATTACH, FAULT_EVIDENCE]:
		return false
	_injected_fault = fault
	return true

func setup(p: Player) -> void:
	player = p

func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
	if player == null or not is_instance_valid(player):
		return
	# 망치 장착 상태와 메뉴 입력 잠금은 별개다. 팔레트가 입력을 잠갔다고
	# 건축 모드를 해제하면 열린 직후 스스로 닫히는 순환이 생긴다.
	var want := player.inventory.equipped_id(Inventory.SLOT_RIGHT) == "hammer" \
		and not player.stats.is_dead
	if want != active:
		active = want
		build_mode_changed.emit(active)
		if not active:
			_clear_ghost()
	if not active or player.input_locked:
		_clear_ghost()
		return
	_update_ghost()

	if Input.is_action_just_pressed("rotate_piece"):
		rot_step = fmod(rot_step + PI * 0.25, TAU)
		Sfx.play("click", -18.0)
	if Input.is_action_just_pressed("attack") and _cooldown <= 0.0:
		_cooldown = 0.2
		try_place_result()
	if Input.is_action_just_pressed("block") and _cooldown <= 0.0:
		_cooldown = 0.2
		try_remove_result()

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
	return bool(try_place_result().get("accepted", false))

func try_place_result() -> Dictionary:
	# RT1 원격 호출은 로컬 검증/예약/생성보다 먼저 닫는다.
	if Net.is_online and not Net.is_host:
		return _resolve_placement(Net.unsupported_build_result("PLACE"), "PLACE")
	if player == null or not is_instance_valid(player) or player.input_locked \
			or player.stats == null or player.stats.is_dead:
		return _resolve_placement(Net.build_result(false, Net.BUILD_STATUS_REJECTED,
			"INPUT_LOCKED", "PLACE"), "PLACE")
	if _placement_committing:
		var busy := Net.build_result(false, Net.BUILD_STATUS_REJECTED,
			"PLACEMENT_BUSY", "PLACE")
		busy["operation"] = "PLACE"
		return busy
	var scene := get_tree().current_scene
	if scene == null:
		return _resolve_placement(Net.build_result(false, Net.BUILD_STATUS_REJECTED,
			"CREATE_FAILED", "PLACE"), "PLACE")
	var d := RecipeDB.piece(current_id)
	if d.is_empty():
		return _resolve_placement(Net.build_result(false, Net.BUILD_STATUS_REJECTED,
			"UNKNOWN_PIECE", "PLACE"), "PLACE")
	# Boats have no RT1 persistence or replication contract. Reject before validation and reservation.
	if d.has("boat") or str(d.get("kind", "")) == "boat":
		return _resolve_placement(Net.unsupported_build_result("PLACE"), "PLACE")
	if not _check_valid(d, _place_xf):
		Sfx.play("error", -14.0)
		return _resolve_placement(Net.build_result(false, Net.BUILD_STATUS_REJECTED,
			"INVALID_PLACEMENT", "PLACE"), "PLACE")

	var mats: Dictionary = (d.get("mats", {}) as Dictionary).duplicate(true)
	var reservation_id := Inventory.RESERVATION_INVALID
	if _injected_fault != FAULT_RESERVE:
		reservation_id = player.inventory.reserve_materials(mats)
	if reservation_id == Inventory.RESERVATION_INVALID:
		return _resolve_placement(Net.build_result(false, Net.BUILD_STATUS_REJECTED,
			"MISSING_MATERIALS", "PLACE"), "PLACE")

	var candidate: Node3D = null
	if _injected_fault != FAULT_CREATE:
		candidate = _create_detached_candidate(current_id, d)
	if candidate == null:
		player.inventory.cancel_reservation(reservation_id)
		return _resolve_placement(Net.build_result(false, Net.BUILD_STATUS_REJECTED,
			"CREATE_FAILED", "PLACE"), "PLACE")

	# Evidence feasibility is checked while both resources remain detached and silent.
	if _injected_fault == FAULT_EVIDENCE:
		candidate.free()
		player.inventory.cancel_reservation(reservation_id)
		return _resolve_placement(Net.build_result(false, Net.BUILD_STATUS_REJECTED,
			"EVIDENCE_FAILED", "PLACE"), "PLACE")

	# From here through publication the commit is non-yielding and reentrancy-guarded.
	# No scene attachment, signal, registry entry, stat, evidence, SFX, or replication
	# precedes completion of every fallible feasibility step.
	_placement_committing = true
	if not player.inventory.commit_reservation(reservation_id):
		_placement_committing = false
		candidate.free()
		player.inventory.cancel_reservation(reservation_id)
		return _resolve_placement(Net.build_result(false, Net.BUILD_STATUS_REJECTED,
			"COMMIT_FAILED", "PLACE"), "PLACE")
	if _injected_fault == FAULT_ATTACH:
		player.inventory.cancel_reservation(reservation_id)
		candidate.free()
		_placement_committing = false
		return _resolve_placement(Net.build_result(false, Net.BUILD_STATUS_REJECTED,
			"ATTACH_FAILED", "PLACE"), "PLACE")

	var piece := candidate as BuildPiece
	_attach_committed_candidate(piece, _place_xf, scene)
	piece.removed.connect(_on_piece_removed)
	pieces.append(piece)
	GameState.stats["built"] = int(GameState.stats.get("built", 0)) + 1
	var published := player.inventory.publish_reservation(reservation_id)
	assert(published)
	_placement_committing = false
	_publish_placement(piece, d)
	return _resolve_placement(Net.build_result(true, Net.BUILD_STATUS_ACCEPTED, "", "PLACE"),
		"PLACE")

func _resolve_placement(result: Dictionary, operation: String) -> Dictionary:
	var resolved := result.duplicate(true)
	resolved["operation"] = operation
	placement_resolved.emit(resolved)
	return resolved

func _create_detached_candidate(id: String, d: Dictionary) -> Node3D:
	if d.has("boat"):
		return Boat.make(str(d["boat"]))
	return BuildPiece.make(id)

func _attach_committed_candidate(piece: BuildPiece, xf: Transform3D, scene: Node) -> void:
	piece.transform = scene.global_transform.affine_inverse() * xf
	piece.yaw = rot_step
	piece.owner_id = GameState.local_player_id
	scene.add_child(piece)

func _publish_placement(piece: BuildPiece, _d: Dictionary) -> void:
	Sfx.play_at("build", piece.global_position, get_tree().current_scene, -4.0)
	Fx.burst(get_tree().current_scene, piece.global_position, Color(0.7, 0.6, 0.4), 10,
		2.5, 0.06, 0.6)
	recompute_support()
	Net.project_committed_piece(piece)
	player.notify_local_build(current_id, piece)

## 권위자가 이미 커밋한 상태를 클라이언트에 읽기 전용으로 투영한다.
func project_authority_snapshot(id: String, pos: Vector3, yaw: float,
		owner_id: String) -> BuildPiece:
	if Net.is_host or not Net.is_online or not RecipeDB.pieces.has(id) \
			or not IdentityStore.is_uuid(owner_id):
		return null
	var d := RecipeDB.piece(id)
	if d.has("boat") or str(d.get("kind", "")) == "boat":
		return null
	var piece := BuildPiece.make_authority_snapshot(id)
	var scene := get_tree().current_scene
	if scene == null:
		piece.free()
		return null
	scene.add_child(piece)
	piece.global_position = pos
	piece.rotation.y = yaw
	piece.yaw = yaw
	piece.owner_id = owner_id
	piece.removed.connect(_on_piece_removed)
	pieces.append(piece)
	return piece

func try_remove() -> bool:
	return bool(try_remove_result().get("accepted", false))

func try_remove_result() -> Dictionary:
	# 조준/조회조차 하기 전에 원격 변경을 닫는다.
	if Net.is_online and not Net.is_host:
		return _resolve_placement(Net.unsupported_build_result("REMOVE"), "REMOVE")
	if player == null or not is_instance_valid(player) or player.input_locked \
			or player.stats == null or player.stats.is_dead:
		return _resolve_placement(Net.build_result(false, Net.BUILD_STATUS_REJECTED,
			"INPUT_LOCKED", "REMOVE"), "REMOVE")
	var hit := _aim()
	if hit.is_empty():
		return _resolve_placement(Net.build_result(false, Net.BUILD_STATUS_REJECTED,
			"NO_TARGET", "REMOVE"), "REMOVE")
	var col = hit["collider"]
	if col == null or not (col is BuildPiece) or col.authority_snapshot:
		return _resolve_placement(Net.build_result(false, Net.BUILD_STATUS_REJECTED,
			"INVALID_TARGET", "REMOVE"), "REMOVE")
	col.destroy(true)
	return _resolve_placement(Net.build_result(true, Net.BUILD_STATUS_ACCEPTED, "", "REMOVE"),
		"REMOVE")

func _on_piece_removed(p) -> void:
	if is_instance_valid(p) and not bool(p.authority_snapshot):
		Net.project_removed_piece(p)
	pieces.erase(p)
	call_deferred("recompute_support")

# ═══════════════════════════════════════════════ 구조 무결성
## 지면에 닿은 조각에서 시작해 지지력을 전파한다. 0 이하가 되면 무너진다.
func recompute_support() -> void:
	var live: Array[BuildPiece] = []
	for p in pieces:
		if is_instance_valid(p) and not p.authority_snapshot:
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
		if not is_instance_valid(p) or p.authority_snapshot:
			continue
		var row := p.to_dict()
		if not row.is_empty():
			out.append(row)
	return out

func from_dict(arr: Array) -> bool:
	# Loading replaces authoritative world state and is never legal once a peer is online.
	if Net.is_online:
		push_error("Refusing build load while a multiplayer peer is active")
		return false
	var scene := get_tree().current_scene
	if scene == null:
		push_error("Refusing build load without an active scene")
		return false
	var rows: Array[Dictionary] = []
	for value in arr:
		if not (value is Dictionary):
			push_error("Refusing non-dictionary build row")
			return false
		var d := value as Dictionary
		if bool(d.get("authority_snapshot", false)):
			push_error("Refusing authority snapshot row in build save")
			return false
		var id := str(d.get("id", ""))
		var pp = d.get("p", [])
		if not RecipeDB.pieces.has(id) or not (pp is Array) or pp.size() != 3:
			push_error("Refusing malformed build row")
			return false
		if not _valid_loaded_piece_row(d):
			push_error("Refusing invalid build row")
			return false
		rows.append(d)
	var loaded: Array[BuildPiece] = []
	for d in rows:
		var piece := BuildPiece.make(str(d["id"]))
		scene.add_child(piece)
		if not piece.is_inside_tree():
			piece.free()
			_free_loaded_pieces(loaded)
			return false
		var pp: Array = d["p"]
		piece.global_position = Vector3(float(pp[0]), float(pp[1]), float(pp[2]))
		piece.rotation.y = float(d.get("y", 0.0))
		if not piece.from_dict(d):
			piece.get_parent().remove_child(piece)
			piece.free()
			_free_loaded_pieces(loaded)
			return false
		piece.removed.connect(_on_piece_removed)
		loaded.append(piece)
	# Register the complete replacement before mutating the live world. Roll back every
	# newly allocated ID on any registration failure.
	for piece in loaded:
		if not Net.register_authoritative_piece(piece):
			_unregister_loaded_pieces(loaded)
			_free_loaded_pieces(loaded)
			return false
	_unregister_loaded_pieces(pieces)
	for p in pieces:
		if is_instance_valid(p):
			p.queue_free()
	pieces = loaded
	call_deferred("recompute_support")
	return true

func _valid_loaded_piece_row(d: Dictionary) -> bool:
	var pp: Array = d["p"]
	for value in [pp[0], pp[1], pp[2], d.get("y", 0.0), d.get("hp", 0.0)]:
		if not (value is int or value is float) or not is_finite(float(value)):
			return false
	var owner = d.get("owner_id", GameState.local_player_id)
	return owner is String and IdentityStore.is_uuid(owner)

func _unregister_loaded_pieces(loaded: Array[BuildPiece]) -> void:
	for piece in loaded:
		Net.unregister_authoritative_piece(piece)

func _free_loaded_pieces(loaded: Array[BuildPiece]) -> void:
	for piece in loaded:
		if not is_instance_valid(piece):
			continue
		var parent := piece.get_parent()
		if parent != null:
			parent.remove_child(piece)
		piece.free()
