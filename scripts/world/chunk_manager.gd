class_name ChunkManager
extends Node3D
## 지형 청크 스트리밍. 프레임당 생성량을 제한해 끊김을 막는다.

const TIER_NEAR := 2      # 이 거리 이내: 고해상도 + 충돌 + 상호작용 배치물
const TIER_MID := 5       # 이 거리 이내: 중해상도 + 멀티메시 배치물
const TIER_FAR := 6       # 이 거리 이내: 저해상도 지형만

# 가까운 청크는 격자를 촘촘히 — 2.3m 격자에서는 능선이 각져 보인다
const RES_NEAR := 48
const RES_MID := 34
const RES_FAR := 20

const BUILD_PER_FRAME := 1

var gen: WorldGen
var chunks: Dictionary = {}          # Vector2i -> TerrainChunk
var chunk_tier: Dictionary = {}      # Vector2i -> int
var _queue: Array[Vector2i] = []
var _center := Vector2i(9999, 9999)
var _ready_emitted := false

signal initial_load_done()

func setup(g: WorldGen) -> void:
	gen = g

func preload_around(pos: Vector3) -> void:
	## 게임 시작 시 로딩 화면에서 한 번에 만든다
	_center = _to_chunk(pos)
	_rebuild_queue()
	while not _queue.is_empty():
		_build_next()
	_ready_emitted = true
	initial_load_done.emit()

func _process(_delta: float) -> void:
	if gen == null:
		return
	var p := GameState.player
	if p == null or not is_instance_valid(p):
		return
	# 던전 안에서는 지상 청크를 건드리지 않는다
	if p.has_meta("in_dungeon"):
		return
	var c := _to_chunk(p.global_position)
	if c != _center:
		_center = c
		_rebuild_queue()
	for i in range(BUILD_PER_FRAME):
		if _queue.is_empty():
			break
		_build_next()

static func _to_chunk(pos: Vector3) -> Vector2i:
	return Vector2i(int(floor(pos.x / Const.CHUNK_SIZE)),
		int(floor(pos.z / Const.CHUNK_SIZE)))

func _tier_for(d: int) -> int:
	if d <= TIER_NEAR:
		return 0
	if d <= TIER_MID:
		return 1
	if d <= TIER_FAR:
		return 2
	return -1

func _rebuild_queue() -> void:
	_queue.clear()
	var want: Dictionary = {}
	for dz in range(-TIER_FAR, TIER_FAR + 1):
		for dx in range(-TIER_FAR, TIER_FAR + 1):
			var d: int = maxi(absi(dx), absi(dz))
			var t := _tier_for(d)
			if t < 0:
				continue
			var key := Vector2i(_center.x + dx, _center.y + dz)
			want[key] = t
			if not chunks.has(key) or chunk_tier.get(key, -1) != t:
				_queue.append(key)
	# 언로드
	for key in chunks.keys():
		if not want.has(key):
			var ch: TerrainChunk = chunks[key]
			if is_instance_valid(ch):
				ch.queue_free()
			chunks.erase(key)
			chunk_tier.erase(key)
	# 가까운 것부터
	var ctr := _center
	_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - ctr).length_squared() < (b - ctr).length_squared())

func _build_next() -> void:
	var key: Vector2i = _queue.pop_front()
	var d: int = maxi(absi(key.x - _center.x), absi(key.y - _center.y))
	var tier := _tier_for(d)
	if tier < 0:
		return
	if chunks.has(key):
		var old: TerrainChunk = chunks[key]
		if is_instance_valid(old):
			old.queue_free()
		chunks.erase(key)

	var res := RES_NEAR
	var want_col := true
	match tier:
		1: res = RES_MID; want_col = false
		2: res = RES_FAR; want_col = false

	var ch := TerrainChunk.new()
	add_child(ch)
	ch.setup(gen, key.x, key.y, res, want_col)
	chunks[key] = ch
	chunk_tier[key] = tier

	if tier == 0:
		Props.populate(ch, gen, true, GameState.removed_in(key))
		_hook_props(ch, key)
	elif tier == 1:
		Props.populate(ch, gen, false, GameState.removed_in(key))

func _hook_props(ch: TerrainChunk, key: Vector2i) -> void:
	for node in ch.props.get_children():
		if node is ResourceNode:
			node.destroyed.connect(_on_prop_destroyed.bind(key))

func _on_prop_destroyed(node, key: Vector2i) -> void:
	if node == null or not is_instance_valid(node):
		return
	var idx: int = node.get_meta("idx", -1)
	if idx >= 0:
		GameState.mark_prop_removed(key, idx)

## 지형이 변형된 청크를 즉시 다시 만든다
func rebuild(keys: Array) -> void:
	for k in keys:
		if not chunks.has(k):
			continue
		var d: int = maxi(absi(k.x - _center.x), absi(k.y - _center.y))
		var tier := _tier_for(d)
		if tier < 0:
			continue
		var old = chunks[k]
		if is_instance_valid(old):
			old.queue_free()
		chunks.erase(k)
		chunk_tier.erase(k)
		if not _queue.has(k):
			_queue.push_front(k)
	# 변형 직후에는 곧바로 만들어 플레이어가 빠지지 않게 한다
	var guard := 0
	while not _queue.is_empty() and guard < 64:
		guard += 1
		_build_next()

## 이 지점에 지형 충돌체가 준비돼 있는가
func has_collision_at(pos: Vector3) -> bool:
	var key := _to_chunk(pos)
	var ch = chunks.get(key)
	return ch != null and is_instance_valid(ch) and ch.has_collision

func loaded_count() -> int:
	return chunks.size()
