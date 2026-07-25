class_name SpawnManager
extends Node
## 플레이어 주변에 바이옴/시간대에 맞는 몬스터를 배치하고, 멀어지면 정리한다.
## 밤·습격 이벤트로 난이도를 조절한다.

const MAX_ALIVE := 18
const SPAWN_MIN := 22.0
const SPAWN_MAX := 46.0
const DESPAWN := 110.0

var _timer := 3.0
var _rng := RandomNumberGenerator.new()
var _raid_timer := 0.0
var _raid_active := false
var _raid_left := 0

func _ready() -> void:
	_rng.randomize()
	_raid_timer = _rng.randf_range(600.0, 1100.0)

func _process(delta: float) -> void:
	var p := GameState.player
	if p == null or not is_instance_valid(p) or p.stats.is_dead:
		return

	_timer -= delta
	if _timer <= 0.0:
		_timer = _rng.randf_range(4.0, 9.0)
		_try_spawn(p)
		_cleanup(p)

	_raid_timer -= delta
	if _raid_timer <= 0.0 and not _raid_active:
		_start_raid(p)

func alive_count() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and not e.is_in_group("boss"):
			n += 1
	return n

func _try_spawn(p: Node3D) -> void:
	if alive_count() >= MAX_ALIVE:
		return
	var night := GameState.is_night()
	var biome := GameState.current_biome
	var pool := EnemyDB.in_biome(biome, night)
	if pool.is_empty():
		return
	# 밤에는 더 자주, 더 많이
	var tries := 3 if night else 2
	for i in range(tries):
		if alive_count() >= MAX_ALIVE:
			return
		if _rng.randf() > (0.75 if night else 0.45):
			continue
		var id: String = pool[_rng.randi() % pool.size()]
		var pos := _find_spot(p, biome)
		if pos == Vector3.INF:
			continue
		var e := Enemy.spawn(id, get_tree().current_scene, pos)
		if e == null:
			continue
		# 무리 짓는 몬스터
		if id in ["greydwarf", "greyling", "wolf", "fuling", "seeker", "neck"]:
			var extra := _rng.randi_range(0, 2)
			for k in range(extra):
				var pos2 := pos + Vector3(_rng.randf_range(-5, 5), 0,
					_rng.randf_range(-5, 5))
				pos2.y = GameState.height_at(pos2.x, pos2.z) + 0.4
				Enemy.spawn(id, get_tree().current_scene, pos2)

func _find_spot(p: Node3D, biome: int) -> Vector3:
	for i in range(14):
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(SPAWN_MIN, SPAWN_MAX)
		var x := p.global_position.x + cos(a) * d
		var z := p.global_position.z + sin(a) * d
		var h := GameState.height_at(x, z)
		if h < Const.WATER_LEVEL + 0.6:
			continue
		if GameState.biome_at(x, z) != biome:
			continue
		if GameState.gen.slope_at(x, z) > 0.55:
			continue
		# 플레이어 시야 정면은 피한다(눈앞에서 튀어나오지 않게)
		var to := Vector3(x - p.global_position.x, 0, z - p.global_position.z).normalized()
		var fwd := -p.global_transform.basis.z
		fwd.y = 0
		if fwd.length() > 0.01 and to.dot(fwd.normalized()) > 0.75 and d < 34.0:
			continue
		# 작업대 근처(플레이어 기지)에는 스폰하지 않는다 — 발헤임 규칙
		if _near_base(Vector3(x, h, z)):
			continue
		return Vector3(x, h + 0.4, z)
	return Vector3.INF

func _near_base(pos: Vector3) -> bool:
	for n in get_tree().get_nodes_in_group("spawn_blocker"):
		if is_instance_valid(n) and n is Node3D:
			if n.global_position.distance_to(pos) < 20.0:
				return true
	return false

func _cleanup(p: Node3D) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e.is_in_group("boss"):
			continue
		if e.global_position.distance_to(p.global_position) > DESPAWN:
			e.queue_free()

# ─────────────────────────────────────────────── 습격 이벤트
func _start_raid(p: Node3D) -> void:
	var tier := int(Const.BIOME_TIER.get(GameState.current_biome, 0))
	var pool := EnemyDB.in_biome(GameState.current_biome, GameState.is_night())
	if pool.is_empty():
		_raid_timer = 300.0
		return
	# 진행도에 맞는 습격만 발생
	var eligible: Array = []
	for id in pool:
		var c := EnemyDB.get_cfg(id)
		if int(c.get("tier", 0)) <= tier + 1:
			eligible.append(id)
	if eligible.is_empty():
		_raid_timer = 300.0
		return

	_raid_active = true
	_raid_left = 6 + tier * 2
	GameState.msg(tr("MSG_RAID"))
	Sfx.play("boss_roar", -2.0, 0.7)

	for i in range(_raid_left):
		var id: String = eligible[_rng.randi() % eligible.size()]
		var a := TAU * float(i) / float(_raid_left)
		var d := _rng.randf_range(30.0, 44.0)
		var x := p.global_position.x + cos(a) * d
		var z := p.global_position.z + sin(a) * d
		var h := GameState.height_at(x, z)
		if h < Const.WATER_LEVEL:
			continue
		var e := Enemy.spawn(id, get_tree().current_scene, Vector3(x, h + 0.4, z))
		if e:
			e.target = p
			e.state = Enemy.St.CHASE
	_raid_timer = _rng.randf_range(900.0, 1500.0)
	await get_tree().create_timer(120.0).timeout
	_raid_active = false
