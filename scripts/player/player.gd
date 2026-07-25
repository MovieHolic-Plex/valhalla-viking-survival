class_name Player
extends CharacterBody3D
## 플레이어: 이동 · 수영 · 전투 · 채집 · 상호작용.

signal interact_target_changed(node)
signal notify(text: String)

const WALK := 3.6
const RUN := 6.4
const CROUCH := 1.7
const SWIM := 2.6
const JUMP_V := 7.2
const ACCEL := 12.0
const AIR_ACCEL := 2.5
const MOUSE_SENS := 0.0026
const INTERACT_RANGE := 4.5
const PICKUP_RANGE := 2.1

var inventory: Inventory
var stats: PlayerStats
var anim  # RigAnimator(코드 리그) 또는 GlbRig(GLB 리그) — 같은 인터페이스

var rig: Node3D
var yaw_pivot: Node3D
var spring: SpringArm3D
var cam: Camera3D
var hand_r: Node3D
var hand_l: Node3D
var _weapon_mi: MeshInstance3D
var _shield_mi: MeshInstance3D
var _torch_light: OmniLight3D
var _torch_fx: GPUParticles3D

var yaw := 0.0
var pitch := -0.18
var zoom := 4.2

var is_swimming := false
var is_crouching := false
var is_blocking := false
var _block_time := 0.0
var _attack_cd := 0.0
var _attack_pending := 0.0
var _pending_hit := false
var _dodge_time := 0.0
var _iframes := 0.0
var _bow_charge := 0.0
var _bow_drawing := false
var _foot_acc := 0.0
var _hit_ids: Array = []
var _interact_node: Node = null
var _last_pos := Vector3.ZERO
var _wet_timer := 0.0
var _near_fire := false
var _comfort := 0
var _rested_timer := 0.0
var _biome_check := 0.0
var _build_system = null
var input_locked := false
var _cam_shake := 0.0
var _sit := false
var terrain_mode := 0            # 0 평탄화 · 1 융기 · 2 굴착
var _bobber: Bobber = null
var _cast_charge := 0.0
const TERRAIN_MODE_KEY := ["MSG_HOE_LEVEL", "MSG_HOE_RAISE", "MSG_HOE_DIG"]

func _ready() -> void:
	add_to_group("player")
	collision_layer = Const.L_PLAYER
	collision_mask = Const.L_WORLD | Const.L_BUILDING
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.4

	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.34
	cap.height = 1.75
	shape.shape = cap
	shape.position = Vector3(0, 0.88, 0)
	add_child(shape)

	inventory = Inventory.new()
	stats = PlayerStats.new()
	stats.died.connect(_on_died)

	# 실제 리깅 모델(KayKit CC0 Barbarian)이 있으면 그것을 쓰고,
	# 없으면 코드 생성 스켈레탈 리그(팔꿈치/무릎이 실제로 접힌다)로 대체한다
	rig = GlbRig.create()
	if rig != null:
		add_child(rig)
		anim = rig
		hand_r = rig.hand_r
		hand_l = rig.hand_l
	else:
		rig = MeshFactory.humanoid_skeletal({
			"skin": Color(0.80, 0.64, 0.52), "cloth": Color(0.45, 0.36, 0.26),
			"hair": Color(0.48, 0.32, 0.16), "height": 1.8, "beard": true,
		})
		add_child(rig)
		anim = RigAnimator.new(rig)
		hand_r = rig.get_node_or_null("skel/hand_r")
		hand_l = rig.get_node_or_null("skel/hand_l")

	# 카메라 리그
	yaw_pivot = Node3D.new()
	yaw_pivot.name = "yaw"
	yaw_pivot.position = Vector3(0, 1.55, 0)
	add_child(yaw_pivot)
	spring = SpringArm3D.new()
	spring.spring_length = zoom
	spring.margin = 0.35
	spring.collision_mask = Const.L_WORLD | Const.L_BUILDING
	yaw_pivot.add_child(spring)
	cam = Camera3D.new()
	cam.current = true
	cam.fov = 72.0
	cam.far = 2200.0
	cam.near = 0.12
	spring.add_child(cam)

	inventory.equipment_changed.connect(_refresh_equipment)
	inventory.changed.connect(_on_inventory_changed)
	GameState.player = self
	_last_pos = global_position

	# 시작 장비
	inventory.add_item("club", 1)
	inventory.add_item("wood", 10)
	inventory.add_item("stone", 6)
	inventory.add_item("raspberries", 5)
	_refresh_equipment()

func set_build_system(bs) -> void:
	_build_system = bs

func get_inventory() -> Inventory:
	return inventory

# ═══════════════════════════════════════════════ 입력
func _unhandled_input(event: InputEvent) -> void:
	if input_locked or stats.is_dead:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * MOUSE_SENS
		pitch = clampf(pitch - event.relative.y * MOUSE_SENS, -1.30, 0.95)
	elif event.is_action_pressed("zoom_in"):
		zoom = clampf(zoom - 0.5, 0.0, 9.0)
	elif event.is_action_pressed("zoom_out"):
		zoom = clampf(zoom + 0.5, 0.0, 9.0)
	elif event.is_action_pressed("interact"):
		_do_interact()
	elif event.is_action_pressed("dodge"):
		_do_dodge()
	elif event.is_action_pressed("sit"):
		_sit = not _sit
	elif event.is_action_pressed("rotate_piece"):
		var rid := inventory.equipped_id(Inventory.SLOT_RIGHT)
		if ItemDB.get_item(rid).get("use", "") == "terrain":
			terrain_mode = (terrain_mode + 1) % 3
			GameState.msg(tr(TERRAIN_MODE_KEY[terrain_mode]))
			Sfx.play("click", -16.0)

func _physics_process(delta: float) -> void:
	if stats.is_dead:
		velocity = Vector3.ZERO
		anim.update(delta, 0.0, false, false, true)
		return

	_update_timers(delta)
	_update_camera(delta)
	_update_environment(delta)

	var moving_speed := _move(delta)
	stats.update(delta, moving_speed > 0.5)

	_update_combat(delta)
	_update_interaction()
	_auto_pickup()

	var sp01: float = clampf(moving_speed / RUN, 0.0, 1.0)
	anim.set_block(is_blocking, delta)
	anim.update(delta, sp01, not is_on_floor() and not is_swimming, is_swimming)

	# 이동 거리 통계
	var d := global_position.distance_to(_last_pos)
	if d < 20.0:
		GameState.stats["distance"] = float(GameState.stats["distance"]) + d
	_last_pos = global_position

func _update_timers(delta: float) -> void:
	if _attack_cd > 0.0:
		_attack_cd -= delta
	if _iframes > 0.0:
		_iframes -= delta
	if _dodge_time > 0.0:
		_dodge_time -= delta
	if _block_time > 0.0:
		_block_time -= delta
	if _cam_shake > 0.0:
		_cam_shake = maxf(0.0, _cam_shake - delta * 3.0)
	if _pending_hit and _attack_pending > 0.0:
		_attack_pending -= delta
		if _attack_pending <= 0.0:
			_pending_hit = false
			_resolve_melee()

# ═══════════════════════════════════════════════ 이동
func _move(delta: float) -> float:
	# 배에 타고 있으면 조종은 배가 맡는다
	if has_meta("boat"):
		var b = get_meta("boat")
		if b != null and is_instance_valid(b):
			velocity = Vector3.ZERO
			is_swimming = false
			return 0.0
		remove_meta("boat")

	var input := Vector2.ZERO
	if not input_locked:
		input.x = Input.get_axis("move_left", "move_right")
		input.y = Input.get_axis("move_forward", "move_back")
	if input.length() > 1.0:
		input = input.normalized()
	if input.length_squared() > 0.01:
		_sit = false

	var basis_yaw := Basis(Vector3.UP, yaw)
	var wish := basis_yaw * Vector3(input.x, 0, input.y)
	if wish.length() > 0.001:
		wish = wish.normalized()

	# 던전은 해수면보다 훨씬 아래 좌표에 있으므로 물 판정에서 제외한다
	var in_dungeon := has_meta("in_dungeon")
	var depth := -100.0 if in_dungeon else Const.WATER_LEVEL - global_position.y
	is_swimming = depth > 1.25

	var target_speed := WALK
	var sprinting := false
	if is_swimming:
		target_speed = SWIM
		if Input.is_action_pressed("sprint") and stats.has_stamina(1.0):
			target_speed = SWIM * 1.45
	elif is_crouching:
		target_speed = CROUCH
	elif Input.is_action_pressed("sprint") and not input_locked and wish.length() > 0.1 \
			and not is_blocking:
		if stats.use_stamina(Const.SPRINT_DRAIN * delta):
			target_speed = RUN
			sprinting = true
			stats.raise_skill(Const.Skill.RUN, delta * 0.25)
	if is_blocking:
		target_speed *= 0.55
	if _sit:
		target_speed = 0.0

	# 장비 무게 / 과적
	target_speed *= 1.0 + inventory.move_speed_mod()
	if inventory.is_overweight():
		target_speed *= 0.35
	if stats.has_status("freezing"):
		target_speed *= 0.75
	if GameState.power_is_active("yagluth"):
		target_speed *= 1.15
	# 무릎 깊이의 물은 감속
	if not is_swimming and depth > 0.2:
		target_speed *= lerpf(1.0, 0.55, clampf(depth / 1.25, 0.0, 1.0))
	# 가파른 경사 감속
	if is_on_floor():
		var fn := get_floor_normal()
		target_speed *= lerpf(1.0, 0.45, clampf((1.0 - fn.y) / 0.45, 0.0, 1.0))

	if is_swimming:
		_swim_move(delta, wish, target_speed)
	else:
		_ground_move(delta, wish, target_speed, sprinting)

	move_and_slide()

	# 발소리
	var hspeed := Vector3(velocity.x, 0, velocity.z).length()
	if is_on_floor() and hspeed > 1.0 and not is_swimming:
		_foot_acc += delta * hspeed
		if _foot_acc > 3.4:
			_foot_acc = 0.0
			Sfx.play_at("footstep", global_position, get_tree().current_scene, -18.0,
				randf_range(0.85, 1.15))
	return hspeed

func _ground_move(delta: float, wish: Vector3, speed: float, sprinting: bool) -> void:
	if _dodge_time > 0.0:
		# 구르는 동안은 관성 유지
		velocity.y -= 22.0 * delta
		return
	var accel := ACCEL if is_on_floor() else AIR_ACCEL
	var target := wish * speed
	velocity.x = move_toward(velocity.x, target.x, accel * delta * maxf(speed, 1.0))
	velocity.z = move_toward(velocity.z, target.z, accel * delta * maxf(speed, 1.0))
	if is_on_floor():
		velocity.y = -1.0
		if Input.is_action_just_pressed("jump") and not input_locked and not _sit:
			var cost := Const.JUMP_COST
			if GameState.power_is_active("eikthyr"):
				cost *= 0.4
			if stats.use_stamina(cost):
				velocity.y = JUMP_V
				Sfx.play_at("jump", global_position, get_tree().current_scene, -14.0)
				stats.raise_skill(Const.Skill.JUMP, 0.35)
	else:
		velocity.y -= 22.0 * delta
		velocity.y = maxf(velocity.y, -55.0)

	is_crouching = Input.is_action_pressed("crouch") and is_on_floor() and not input_locked
	if is_crouching:
		stats.raise_skill(Const.Skill.SNEAK, delta * 0.12)

func _swim_move(delta: float, wish: Vector3, speed: float) -> void:
	var target := wish * speed
	velocity.x = move_toward(velocity.x, target.x, 6.0 * delta * speed)
	velocity.z = move_toward(velocity.z, target.z, 6.0 * delta * speed)
	# 수면으로 떠오르기 / 잠수
	var surface := Const.WATER_LEVEL - 0.9
	var dy := surface - global_position.y
	velocity.y = clampf(dy * 3.0, -3.0, 3.0)
	if Input.is_action_pressed("jump"):
		velocity.y = 2.5
	if Input.is_action_pressed("crouch"):
		velocity.y = -2.5
	if not stats.use_stamina(Const.SWIM_DRAIN * delta):
		# 스태미나가 바닥나면 가라앉으며 익사 피해
		velocity.y = -1.2
		stats.set_hp(stats.hp - 6.0 * delta)
	else:
		stats.raise_skill(Const.Skill.SWIM, delta * 0.2)

# ═══════════════════════════════════════════════ 카메라
func _update_camera(delta: float) -> void:
	yaw_pivot.rotation.y = yaw
	spring.rotation.x = pitch
	spring.spring_length = lerpf(spring.spring_length, zoom, delta * 10.0)
	# 1인칭에 가까우면 몸을 숨긴다
	rig.visible = spring.spring_length > 0.8
	# 몸통은 카메라 방향을 따라간다
	rig.rotation.y = lerp_angle(rig.rotation.y, 0.0, delta * 12.0)
	rotation.y = yaw
	if _cam_shake > 0.0:
		cam.h_offset = randf_range(-0.06, 0.06) * _cam_shake
		cam.v_offset = randf_range(-0.06, 0.06) * _cam_shake
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0

func shake(amount: float) -> void:
	_cam_shake = maxf(_cam_shake, amount)

# ═══════════════════════════════════════════════ 환경
func _update_environment(delta: float) -> void:
	# 던전 안에서는 날씨·바이옴 판정을 멈춘다
	if has_meta("in_dungeon"):
		stats.remove_status("freezing")
		stats.remove_status("wet")
		_update_comfort(delta)
		return

	_biome_check -= delta
	if _biome_check <= 0.0:
		_biome_check = 0.5
		GameState.set_biome(GameState.biome_at(global_position.x, global_position.z))
		_update_map_discovery()

	# 젖음 / 추위
	var depth := Const.WATER_LEVEL - global_position.y
	var raining := false
	var sky = get_tree().current_scene.get_node_or_null("sky")
	if sky != null:
		raining = sky.weather in ["rain", "storm"]
	if depth > 0.2 or raining:
		_wet_timer = 60.0
	if _wet_timer > 0.0:
		_wet_timer -= delta
		stats.add_status("wet", 2.0)
	else:
		stats.remove_status("wet")

	var b := GameState.current_biome
	var cold := b == Const.Biome.MOUNTAIN or (GameState.is_night() and stats.has_status("wet"))
	var res := inventory.resistances()
	if cold and float(res.get("res_frost", 0.0)) < 0.5 and not _near_fire:
		if b == Const.Biome.MOUNTAIN:
			stats.add_status("freezing", 2.0, {"dps": 2.0, "nonlethal": false})
		else:
			stats.add_status("cold", 2.0)
	else:
		stats.remove_status("freezing")
		stats.remove_status("cold")

	if b == Const.Biome.ASHLANDS and float(res.get("res_fire", 0.0)) < 0.5:
		stats.add_status("burning", 2.0, {"dps": 1.0, "nonlethal": true})

	# 안락도 → 휴식 버프
	_update_comfort(delta)

func _update_comfort(delta: float) -> void:
	_rested_timer -= delta
	if _rested_timer > 0.0:
		return
	_rested_timer = 1.0
	var comfort := 0
	_near_fire = false
	var seen: Dictionary = {}
	for n in get_tree().get_nodes_in_group("comfort_source"):
		if not is_instance_valid(n) or not (n is Node3D):
			continue
		if n.global_position.distance_to(global_position) > 10.0:
			continue
		var pid: String = n.get_meta("piece_id", "")
		if pid == "" or seen.has(pid):
			continue
		seen[pid] = true
		comfort += int(n.get_meta("comfort", 0))
		if bool(n.get_meta("fire", false)):
			_near_fire = true
	_comfort = comfort
	if comfort > 0:
		stats.add_status("rested", 60.0 + float(comfort) * 60.0, {"comfort": comfort})

func _update_map_discovery() -> void:
	var tile := Vector2i(int(global_position.x / 32.0), int(global_position.z / 32.0))
	for dz in range(-6, 7):
		for dx in range(-6, 7):
			GameState.discovered[Vector2i(tile.x + dx, tile.y + dz)] = true

# ═══════════════════════════════════════════════ 전투
func _update_combat(delta: float) -> void:
	if input_locked:
		is_blocking = false
		_bow_drawing = false
		return
	var right := inventory.equipped_id(Inventory.SLOT_RIGHT)
	var item := ItemDB.get_item(right)
	var is_bow: bool = item.get("bow", false)

	# 방어
	var want_block := Input.is_action_pressed("block") and not is_bow \
		and inventory.equipped_id(Inventory.SLOT_LEFT) != ""
	if want_block and not is_blocking:
		_block_time = 0.35     # 패링 윈도
	is_blocking = want_block

	# ── 낚시 ──
	if bool(item.get("fishing", false)):
		_update_fishing(delta)
		return
	# ── 지팡이 (에이트르 시전) ──
	if item.has("staff"):
		if Input.is_action_just_pressed("attack") and _attack_cd <= 0.0:
			_cast_staff(right, item)
		return

	if is_bow:
		if Input.is_action_pressed("attack") and _has_ammo():
			if not _bow_drawing:
				_bow_drawing = true
				_bow_charge = 0.0
				anim.attack("bow")
			_bow_charge = minf(_bow_charge + delta * float(item.get("draw", 1.0)), 1.0)
			if not stats.use_stamina(6.0 * delta):
				_release_arrow(right, item)
		elif _bow_drawing:
			_release_arrow(right, item)
	else:
		if Input.is_action_just_pressed("attack") and _attack_cd <= 0.0 and not _sit:
			if str(item.get("use", "")) == "terrain":
				_use_terrain_tool()
			else:
				_start_melee(right, item)

func _start_melee(id: String, item: Dictionary) -> void:
	var spd := float(item.get("spd", 1.1)) if not item.is_empty() else 1.4
	var cost := float(item.get("stam", 8.0)) if not item.is_empty() else 5.0
	if not stats.use_stamina(cost):
		Sfx.play("error", -14.0)
		return
	_attack_cd = 1.0 / maxf(spd, 0.2)
	var kind := "slash"
	var skill := int(item.get("skill", Const.Skill.UNARMED)) if not item.is_empty() \
		else Const.Skill.UNARMED
	match skill:
		Const.Skill.AXES: kind = "chop"
		Const.Skill.SPEARS: kind = "stab"
		Const.Skill.CLUBS: kind = "chop"
		Const.Skill.PICKAXES: kind = "chop"
	anim.attack(kind)
	Sfx.play_at("swing", global_position, get_tree().current_scene, -10.0)
	_hit_ids.clear()
	_pending_hit = true
	_attack_pending = _attack_cd * 0.30

func _resolve_melee() -> void:
	var id := inventory.equipped_id(Inventory.SLOT_RIGHT)
	var q := inventory.equipped_quality(Inventory.SLOT_RIGHT)
	var item := ItemDB.get_item(id)
	var rng := float(item.get("rng", 1.8)) if not item.is_empty() else 1.6
	var kb := float(item.get("kb", 20.0)) if not item.is_empty() else 10.0
	var skill := int(item.get("skill", Const.Skill.UNARMED)) if not item.is_empty() \
		else Const.Skill.UNARMED
	var tool_tier := int(item.get("tier", 0))
	if item.has("mine_tier"):
		tool_tier = int(item["mine_tier"])

	var dmg: Dictionary = ItemDB.total_damage(id, q) if not item.is_empty() \
		else {Const.Dmg.BLUNT: 8.0}
	var mult := Const.skill_damage_mult(stats.skill_level(skill))
	if GameState.power_is_active("bonemass"):
		mult *= 1.0
	var scaled := {}
	for k in dmg:
		scaled[k] = float(dmg[k]) * mult

	var origin := global_position + Vector3(0, 1.2, 0)
	var fwd := -Basis(Vector3.UP, yaw).z
	var center := origin + fwd * (rng * 0.55)

	var space := get_world_3d().direct_space_state
	var q_par := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = maxf(rng * 0.55, 0.7)
	q_par.shape = sph
	q_par.transform = Transform3D(Basis.IDENTITY, center)
	q_par.collision_mask = Const.L_ENEMY | Const.L_RESOURCE
	q_par.collide_with_areas = false
	q_par.collide_with_bodies = true
	var hits := space.intersect_shape(q_par, 12)

	var any := false
	for h in hits:
		var col = h["collider"]
		if col == null or not is_instance_valid(col) or col == self:
			continue
		var iid: int = col.get_instance_id()
		if _hit_ids.has(iid):
			continue
		# 등 뒤의 대상은 맞지 않는다
		var to: Vector3 = (col.global_position - global_position)
		to.y = 0
		if to.length() > 0.05 and to.normalized().dot(fwd) < 0.15:
			continue
		_hit_ids.append(iid)
		var hit_point: Vector3 = col.global_position + Vector3(0, 1.0, 0)
		if col is ResourceNode:
			var r: Dictionary = col.take_hit(scaled, tool_tier, hit_point, self)
			if r.get("ok", false):
				any = true
				var ws := Const.Skill.WOODCUTTING if col.accept == Const.Dmg.CHOP \
					else Const.Skill.PICKAXES
				stats.raise_skill(ws, 0.4)
				if r.get("killed", false) and col.kind == ResourceNode.Kind.TREE:
					GameState.stats["trees"] = int(GameState.stats["trees"]) + 1
		elif col.has_method("take_hit"):
			col.take_hit(scaled, hit_point, self, kb)
			any = true
			Sfx.play_at("flesh_hit", hit_point, get_tree().current_scene, -3.0)
	if any:
		stats.raise_skill(skill, 0.7)
		shake(0.35)
	elif item.has("mine_tier"):
		# 바위를 맞히지 못한 곡괭이질은 땅을 판다
		_dig_terrain()

# ─────────────────────────────────────────── 지형 변형
func _terrain_aim(max_dist: float) -> Dictionary:
	var from := cam.global_position
	var to := from + -cam.global_transform.basis.z * (max_dist + spring.spring_length)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = Const.L_WORLD
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return {}
	if hit["position"].distance_to(global_position) > max_dist:
		return {}
	return hit

func _apply_terrain(center: Vector3, radius: float, mode: String,
		amount: float, cost: float) -> void:
	if GameState.gen == null:
		return
	if not stats.use_stamina(cost):
		Sfx.play("error", -14.0)
		return
	# 온라인이면 호스트가 판정한 뒤 모두에게 적용한다.
	# 클라이언트는 여기서 로컬 적용을 건너뛰고 승인된 결과를 받는다.
	if not Net.request_terrain(center, radius, mode, amount):
		var keys := GameState.gen.modify(center, radius, mode, amount)
		var cm = get_tree().current_scene.get_node_or_null("chunks")
		if cm != null:
			cm.rebuild(keys)
	Sfx.play_at("build", center, get_tree().current_scene, -6.0, 0.8)
	Fx.burst(get_tree().current_scene, center + Vector3(0, 0.3, 0),
		Color(0.52, 0.42, 0.28), 14, 3.0, 0.08, 0.8)
	anim.attack("chop")
	_attack_cd = 0.7

func _use_terrain_tool() -> void:
	var hit := _terrain_aim(6.0)
	if hit.is_empty():
		return
	var p: Vector3 = hit["position"]
	match terrain_mode:
		0:
			# 평탄화 기준 높이는 플레이어 발밑
			_apply_terrain(Vector3(p.x, global_position.y, p.z), 2.6, "level", 0.0, 12.0)
		1:
			_apply_terrain(p, 2.2, "raise", 0.55, 14.0)
		2:
			_apply_terrain(p, 2.2, "dig", 0.55, 14.0)

func _dig_terrain() -> void:
	var hit := _terrain_aim(4.0)
	if hit.is_empty():
		return
	var p: Vector3 = hit["position"]
	_apply_terrain(p, 1.8, "dig", 0.6, 10.0)
	# 파낸 흙에서 돌이 조금 나온다
	if randf() < 0.35:
		ItemDrop.spawn(get_tree().current_scene, p + Vector3(0, 0.5, 0), "stone",
			randi_range(1, 2))

# ─────────────────────────────────────────── 낚시
func _update_fishing(delta: float) -> void:
	if _bobber != null and is_instance_valid(_bobber):
		if Input.is_action_just_pressed("attack"):
			_bobber.try_hook()
		if Input.is_action_just_pressed("block"):
			_bobber.queue_free()
			_bobber = null
		return
	if Input.is_action_pressed("attack"):
		_cast_charge = minf(_cast_charge + delta * 1.4, 1.0)
		anim.attack("bow")
	elif _cast_charge > 0.08:
		_throw_bobber()
		_cast_charge = 0.0

func _throw_bobber() -> void:
	if inventory.count("fishing_bait") <= 0:
		GameState.msg(tr("MSG_NO_BAIT"))
		Sfx.play("error", -12.0)
		return
	inventory.remove_item("fishing_bait", 1)
	var dir := -cam.global_transform.basis.z.normalized()
	dir.y += 0.28
	var b := Bobber.new()
	get_tree().current_scene.add_child(b)
	b.launch(global_position + Vector3(0, 1.5, 0) + dir * 1.2,
		dir.normalized() * lerpf(10.0, 26.0, _cast_charge), self)
	b.finished.connect(func(_f): _bobber = null)
	_bobber = b
	anim.attack("bow")
	Sfx.play_at("swing", global_position, get_tree().current_scene, -10.0, 1.3)

# ─────────────────────────────────────────── 마법 (에이트르)
func _cast_staff(id: String, item: Dictionary) -> void:
	var cost := float(item.get("eitr_cost", 20.0))
	if stats.max_eitr <= 0.0:
		GameState.msg(tr("MSG_NO_EITR_FOOD"))
		Sfx.play("error", -12.0)
		return
	if not stats.use_eitr(cost):
		GameState.msg(tr("MSG_NOT_ENOUGH_EITR"))
		Sfx.play("error", -12.0)
		return
	_attack_cd = 1.0 / maxf(float(item.get("spd", 0.9)), 0.2)
	anim.attack("stab")
	var q := inventory.equipped_quality(Inventory.SLOT_RIGHT)
	var scene := get_tree().current_scene
	var col := ItemDB.color_of(id)
	match str(item.get("staff", "bolt")):
		"bolt":
			var dmg := ItemDB.total_damage(id, q)
			var dir := -cam.global_transform.basis.z.normalized()
			var pr := Projectile.make(dmg, col, self)
			scene.add_child(pr)
			pr.gravity = 0.0
			pr.knockback = 40.0
			pr.launch(cam.global_position + dir * 1.2, dir * 42.0)
			Sfx.play_at("bow_shoot", global_position, scene, -4.0, 0.7)
		"shield":
			stats.add_status("magic_shield", 30.0)
			Fx.burst(scene, global_position + Vector3(0, 1.0, 0), col, 40, 4.0, 0.1, 1.2)
			Sfx.play("level_up", -8.0, 0.9)
			GameState.msg(tr("MSG_SHIELD_UP"))
		"summon":
			var fwd := -Basis(Vector3.UP, yaw).z
			for i in range(2):
				var off := fwd.rotated(Vector3.UP, (float(i) - 0.5) * 0.8) * 3.0
				var pos := global_position + off
				pos.y = GameState.height_at(pos.x, pos.z) + 0.4
				var e := Enemy.spawn("skeleton", scene, pos)
				if e:
					e.set_meta("friendly", true)
					e.add_to_group("tamed")
			Fx.burst(scene, global_position, col, 30, 4.0, 0.09, 1.0)
			Sfx.play("portal", -6.0, 0.8)
			GameState.msg(tr("MSG_SUMMONED"))
	Fx.burst(scene, hand_r.global_position if hand_r else global_position, col,
		14, 3.0, 0.07, 0.7)

func _has_ammo() -> bool:
	return inventory.equipped_id(Inventory.SLOT_AMMO) != ""

func _release_arrow(bow_id: String, item: Dictionary) -> void:
	_bow_drawing = false
	var ammo := inventory.equipped_id(Inventory.SLOT_AMMO)
	if ammo == "" or _bow_charge < 0.15:
		_bow_charge = 0.0
		return
	if not inventory.remove_item(ammo, 1):
		return
	var q := inventory.equipped_quality(Inventory.SLOT_RIGHT)
	var dmg := ItemDB.total_damage(bow_id, q)
	var adm: Dictionary = ItemDB.get_item(ammo).get("dmg", {})
	for k in adm:
		dmg[k] = float(dmg.get(k, 0.0)) + float(adm[k])
	var mult := Const.skill_damage_mult(stats.skill_level(Const.Skill.BOWS)) * _bow_charge
	var scaled := {}
	for k in dmg:
		scaled[k] = float(dmg[k]) * mult

	var dir := -cam.global_transform.basis.z.normalized()
	var origin := cam.global_position + dir * 1.2
	var arrow := Projectile.make(scaled, ItemDB.color_of(ammo), self)
	get_tree().current_scene.add_child(arrow)
	arrow.launch(origin, dir * lerpf(28.0, 58.0, _bow_charge))
	Sfx.play_at("bow_shoot", global_position, get_tree().current_scene, -6.0)
	stats.raise_skill(Const.Skill.BOWS, 0.6)
	_bow_charge = 0.0
	_attack_cd = 0.35

## 외부(적)에서 호출하는 피격 처리
func take_hit(dmg: Dictionary, from_pos: Vector3, attacker = null,
		knockback: float = 0.0) -> void:
	if stats.is_dead or _iframes > 0.0:
		return
	var total := 0.0
	for k in dmg:
		total += float(dmg[k])

	# 방어 / 패링
	var left := inventory.equipped_id(Inventory.SLOT_LEFT)
	if is_blocking and left != "":
		var lq := inventory.equipped_quality(Inventory.SLOT_LEFT)
		var bp := ItemDB.block_of(left, lq)
		var parry := _block_time > 0.0
		var eff: float = bp * (float(ItemDB.get_item(left).get("parry", 1.0)) if parry else 1.0)
		eff *= 1.0 + stats.skill_level(Const.Skill.BLOCK) / Const.SKILL_MAX * 0.5
		stats.use_stamina(maxf(4.0, total * 0.25))
		stats.raise_skill(Const.Skill.BLOCK, 0.6)
		Sfx.play_at("metal_hit", global_position, get_tree().current_scene, -2.0)
		if eff >= total:
			Fx.float_text(get_tree().current_scene, global_position + Vector3(0, 1.8, 0),
				tr("MSG_PARRY") if parry else tr("MSG_BLOCKED"),
				Color(0.75, 0.9, 1.0), 0.45)
			if parry and attacker != null and is_instance_valid(attacker) \
					and attacker.has_method("stagger"):
				attacker.stagger(3.0)
			shake(0.4)
			return
		var ratio := 1.0 - eff / maxf(total, 0.001)
		for k in dmg:
			dmg[k] = float(dmg[k]) * ratio

	if stats.has_status("magic_shield"):
		for k in dmg:
			dmg[k] = float(dmg[k]) * 0.35
	var taken := stats.take_damage(dmg, inventory.total_armor(), inventory.resistances())
	if taken > 0.0:
		anim.hit()
		shake(clampf(taken / 30.0, 0.2, 1.2))
		Sfx.play_at("hurt", global_position, get_tree().current_scene, -4.0)
		Fx.float_text(get_tree().current_scene, global_position + Vector3(0, 1.9, 0),
			"-" + str(int(round(taken))), Color(1.0, 0.35, 0.35), 0.55)
		if knockback > 0.0:
			var kd := global_position - from_pos
			kd.y = 0
			if kd.length() > 0.01:
				velocity += kd.normalized() * clampf(knockback * 0.06, 0.5, 6.0)
				velocity.y = maxf(velocity.y, 2.0)

func _do_dodge() -> void:
	if _dodge_time > 0.0 or is_swimming or not is_on_floor():
		return
	if not stats.use_stamina(Const.DODGE_COST):
		return
	var input := Vector2(Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back"))
	var dir := Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y if input.y != 0.0 else 1.0)
	if dir.length() < 0.01:
		dir = Basis(Vector3.UP, yaw) * Vector3(0, 0, 1)
	dir = dir.normalized()
	velocity = dir * 9.5 + Vector3(0, 2.0, 0)
	_dodge_time = 0.45
	_iframes = 0.35
	Sfx.play_at("jump", global_position, get_tree().current_scene, -12.0, 1.3)

func stagger(_t: float) -> void:
	anim.knock(0.8)

# ═══════════════════════════════════════════════ 상호작용
func _update_interaction() -> void:
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var to := from + -cam.global_transform.basis.z * (INTERACT_RANGE + spring.spring_length)
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = Const.L_RESOURCE | Const.L_BUILDING
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	var found: Node = null
	if hit:
		var col = hit["collider"]
		if col != null and col.has_method("can_interact") and col.can_interact(self):
			if col.global_position.distance_to(global_position) <= INTERACT_RANGE + 1.5:
				found = col
	if found != _interact_node:
		_interact_node = found
		interact_target_changed.emit(found)

func _do_interact() -> void:
	# 승선 중이면 먼저 하선
	if has_meta("boat"):
		var b = get_meta("boat")
		if b != null and is_instance_valid(b):
			b.interact(self)
			return
		remove_meta("boat")
	if _interact_node != null and is_instance_valid(_interact_node):
		if _interact_node.has_method("interact"):
			_interact_node.interact(self)
		return
	# 손 닿는 거리의 채집물 자동 상호작용
	for n in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(n) or not (n is Node3D):
			continue
		if n.global_position.distance_to(global_position) < 2.4 and n.has_method("interact"):
			n.interact(self)
			return

func _auto_pickup() -> void:
	for d in get_tree().get_nodes_in_group("item_drop"):
		if not is_instance_valid(d):
			continue
		if d.global_position.distance_to(global_position) < PICKUP_RANGE:
			if d.try_pickup(self):
				notify_pickup(d.item_id, d.amount if d.amount > 0 else 1)

func notify_pickup(id: String, amount: int) -> void:
	notify.emit("+%d %s" % [amount, ItemDB.name_of(id)])
	Sfx.play("pickup", -12.0)

# ═══════════════════════════════════════════════ 장비 표시
func _on_inventory_changed() -> void:
	pass

func _refresh_equipment() -> void:
	if _weapon_mi and is_instance_valid(_weapon_mi):
		_weapon_mi.queue_free()
	_weapon_mi = null
	if _shield_mi and is_instance_valid(_shield_mi):
		_shield_mi.queue_free()
	_shield_mi = null
	if _torch_light and is_instance_valid(_torch_light):
		_torch_light.queue_free()
	_torch_light = null
	if _torch_fx and is_instance_valid(_torch_fx):
		_torch_fx.queue_free()
	_torch_fx = null

	var right := inventory.equipped_id(Inventory.SLOT_RIGHT)
	if right != "" and hand_r:
		_weapon_mi = _build_held(right)
		hand_r.add_child(_weapon_mi)
	var left := inventory.equipped_id(Inventory.SLOT_LEFT)
	if left != "" and hand_l:
		_shield_mi = _build_held(left)
		hand_l.add_child(_shield_mi)
		if left == "torch":
			_torch_light = OmniLight3D.new()
			_torch_light.light_color = Color(1.0, 0.66, 0.32)
			_torch_light.light_energy = 3.2
			_torch_light.omni_range = 16.0
			_torch_light.shadow_enabled = true
			_torch_light.position = Vector3(0, -0.45, 0)
			hand_l.add_child(_torch_light)
			Flicker.attach(_torch_light, 0.30, 1.2)
			_torch_fx = Fx.fire(hand_l, 0.5)
			_torch_fx.position = Vector3(0, -0.45, 0)
	# 방어구 색을 몸통에 반영
	_tint_armor()

func _build_held(id: String) -> MeshInstance3D:
	var it := ItemDB.get_item(id)
	var col := ItemDB.color_of(id)
	var mb := MeshBuilder.new()
	var t := int(it.get("t", Const.ItemType.MATERIAL))
	match t:
		Const.ItemType.SHIELD:
			mb.cyl(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.15, 0.12)),
				0.42, 0.42, 0.07, 10, col)
			mb.sphere(Vector3(0, -0.15, 0.19), 0.10, 7, 4, col.lightened(0.3))
		Const.ItemType.WEAPON, Const.ItemType.TOOL:
			if it.get("bow", false):
				mb.rod(Vector3(0, -0.75, 0), Vector3(0, 0.75, 0.0), 0.035, 5,
					col.darkened(0.2))
				mb.rod(Vector3(0, -0.72, 0), Vector3(0, 0.72, -0.16), 0.012, 4,
					Color(0.9, 0.88, 0.8))
			elif id == "torch":
				mb.cyl(Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, 0.1, 0)),
					0.035, 0.045, 0.55, 6, Color(0.32, 0.22, 0.14))
			else:
				var rr := float(it.get("rng", 2.2))
				var skill := int(it.get("skill", Const.Skill.SWORDS))
				var handle := 0.28
				var blade: float = clampf(rr * 0.42, 0.3, 1.6)
				mb.cyl(Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, 0.06, 0)),
					0.035, 0.035, handle, 6, Color(0.30, 0.21, 0.13))
				match skill:
					Const.Skill.AXES:
						mb.rod(Vector3(0, -handle, 0), Vector3(0, blade * 0.9, 0), 0.03, 5,
							Color(0.34, 0.24, 0.15))
						mb.box(Transform3D(Basis(Vector3.FORWARD, 0.25),
							Vector3(0.13, blade * 0.8, 0)), Vector3(0.30, 0.26, 0.05), col)
					Const.Skill.SPEARS:
						mb.rod(Vector3(0, -handle, 0), Vector3(0, blade * 1.6, 0), 0.028, 5,
							Color(0.34, 0.24, 0.15))
						mb.cone(Transform3D(Basis.IDENTITY, Vector3(0, blade * 1.6, 0)),
							0.05, 0.30, 5, col)
					Const.Skill.CLUBS, Const.Skill.PICKAXES:
						mb.rod(Vector3(0, -handle, 0), Vector3(0, blade * 0.8, 0), 0.032, 5,
							Color(0.34, 0.24, 0.15))
						if skill == Const.Skill.PICKAXES:
							mb.box(Transform3D(Basis(Vector3.FORWARD, 1.3),
								Vector3(0, blade * 0.8, 0)), Vector3(0.62, 0.07, 0.07), col)
						else:
							mb.box(Transform3D(Basis.IDENTITY, Vector3(0, blade * 0.85, 0)),
								Vector3(0.17, 0.24, 0.17), col)
					_:
						mb.box(Transform3D(Basis.IDENTITY, Vector3(0, -handle * 0.5, 0)),
							Vector3(0.20, 0.05, 0.06), col.darkened(0.4))
						mb.box(Transform3D(Basis.IDENTITY, Vector3(0, blade * 0.5, 0)),
							Vector3(0.075, blade, 0.028), col)
						mb.cone(Transform3D(Basis.IDENTITY, Vector3(0, blade, 0)),
							0.05, 0.14, 4, col)
		_:
			mb.box(Transform3D.IDENTITY, Vector3(0.2, 0.2, 0.2), col)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	mi.material_override = MatLib.flat(Color.WHITE, 0.5, 0.35)
	# 손에 쥔 상태로 보이게 위치 조정
	mi.position = Vector3(0, -0.05, 0)
	return mi

func _tint_armor() -> void:
	var chest := inventory.equipped_id(Inventory.SLOT_CHEST)
	var torso := rig.get_node_or_null("hips/torso") as MeshInstance3D
	if torso:
		var c := ItemDB.color_of(chest) if chest != "" else Color(0.45, 0.36, 0.26)
		torso.material_override = MatLib.flat(c, 0.85)
	var legs := inventory.equipped_id(Inventory.SLOT_LEGS)
	for ln in ["hips/leg_l/mesh", "hips/leg_r/mesh"]:
		var m := rig.get_node_or_null(ln) as MeshInstance3D
		if m:
			var c2 := ItemDB.color_of(legs) if legs != "" else Color(0.36, 0.28, 0.20)
			m.material_override = MatLib.flat(c2, 0.85)
	var head_item := inventory.equipped_id(Inventory.SLOT_HEAD)
	var hm := rig.get_node_or_null("hips/head_pivot/head") as MeshInstance3D
	if hm:
		hm.material_override = MatLib.flat(
			ItemDB.color_of(head_item).lightened(0.1) if head_item != "" else Color.WHITE, 0.85)

# ═══════════════════════════════════════════════ 사망
func _on_died() -> void:
	GameState.stats["deaths"] = int(GameState.stats["deaths"]) + 1
	Sfx.play("death", -2.0)
	# 무덤 생성 후 소지품 전부 이전
	var tomb := Tombstone.new()
	get_tree().current_scene.add_child(tomb)
	tomb.global_position = global_position + Vector3(0, 0.1, 0)
	tomb.store_from(inventory)
	inventory.clear_all()
	stats.skill_death_penalty()
	_refresh_equipment()
	GameState.msg(tr("MSG_YOU_DIED"))

func respawn_at(pos: Vector3) -> void:
	global_position = pos + Vector3(0, 1.0, 0)
	velocity = Vector3.ZERO
	stats.revive()
	stats.add_status("rested", 120.0, {"comfort": 1})
	_refresh_equipment()

# ═══════════════════════════════════════════════ 직렬화
func to_dict() -> Dictionary:
	return {
		"pos": [global_position.x, global_position.y, global_position.z],
		"yaw": yaw,
		"inv": inventory.to_dict(),
		"stats": stats.to_dict(),
	}

func from_dict(d: Dictionary) -> void:
	var p: Array = d.get("pos", [0, 60, 0])
	global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	yaw = float(d.get("yaw", 0.0))
	inventory.from_dict(d.get("inv", {}))
	stats.from_dict(d.get("stats", {}))
	_refresh_equipment()
