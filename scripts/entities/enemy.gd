class_name Enemy
extends CharacterBody3D
## 몬스터 AI. 배회 → 추적 → 공격 → (약하면) 도주.
## 지형 충돌이 아직 로드되지 않은 경우를 대비해 높이 질의로 바닥을 보정한다.

signal died(enemy)

enum St { IDLE, WANDER, CHASE, ATTACK, FLEE, DEAD }

var cfg: Dictionary = {}
var hp := 10.0
var max_hp := 10.0
var state: int = St.IDLE
var anim: RigAnimator
var rig: Node3D

var target: Node3D = null
var _home := Vector3.ZERO
var _wander_target := Vector3.ZERO
var _timer := 0.0
var _atk_cd := 0.0
var _telegraph := -1.0
var _stagger_acc := 0.0
var _stagger_time := 0.0
var _dead := false
var _fade := 0.0
var _hp_bar: Sprite3D
var _hp_bar_timer := 0.0
var _flying := false
var _hover := 3.0
var _size := 1.0
var _rng := RandomNumberGenerator.new()
var _stuck_t := 0.0
var _last_p := Vector3.ZERO

static func spawn(id: String, parent: Node, pos: Vector3) -> Enemy:
	var c := EnemyDB.get_cfg(id)
	if c.is_empty():
		return null
	var e := Enemy.new()
	e.cfg = c
	parent.add_child(e)
	e.global_position = pos
	return e

func _ready() -> void:
	add_to_group("enemy")
	collision_layer = Const.L_ENEMY
	collision_mask = Const.L_WORLD | Const.L_BUILDING
	floor_max_angle = deg_to_rad(60.0)
	_rng.randomize()

	if cfg.is_empty():
		cfg = EnemyDB.get_cfg("greyling")
	max_hp = float(cfg.get("hp", 20.0))
	hp = max_hp
	_size = float(cfg.get("size", 1.0))
	_flying = bool(cfg.get("flying", false))
	_hover = 3.0 + _size

	var cap := CapsuleShape3D.new()
	cap.radius = 0.36 * _size
	cap.height = maxf(1.6 * _size, cap.radius * 2.2)
	var cs := CollisionShape3D.new()
	cs.shape = cap
	cs.position = Vector3(0, cap.height * 0.5, 0)
	add_child(cs)

	_build_rig()
	_home = global_position
	_wander_target = global_position
	_last_p = global_position
	name = "enemy_" + str(cfg.get("id", "?"))

func _build_rig() -> void:
	var rc: Dictionary = cfg.get("rig_cfg", {})
	match str(cfg.get("rig", "humanoid")):
		"quad":
			rig = MeshFactory.quadruped(rc)
		"flyer":
			rig = MeshFactory.flyer(rc)
		"blob":
			var mi := MeshInstance3D.new()
			mi.mesh = MeshFactory.blob_mesh(float(rc.get("size", 0.8)),
				rc.get("color", Color(0.3, 0.7, 0.35)), int(cfg.get("id", "x").hash()))
			mi.material_override = MatLib.flat(Color.WHITE, 0.35)
			rig = Node3D.new()
			var body := Node3D.new()
			body.name = "body"
			rig.add_child(body)
			body.add_child(mi)
		_:
			rig = MeshFactory.humanoid(rc)
	add_child(rig)
	anim = RigAnimator.new(rig)

	if cfg.has("glow"):
		var l := OmniLight3D.new()
		l.light_color = cfg["glow"]
		l.light_energy = 2.2
		l.omni_range = 8.0 * _size
		l.position = Vector3(0, 1.0 * _size, 0)
		add_child(l)

	# 머리 위 체력바
	_hp_bar = Sprite3D.new()
	_hp_bar.texture = _bar_texture(1.0)
	_hp_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bar.pixel_size = 0.0035
	_hp_bar.no_depth_test = false
	_hp_bar.position = Vector3(0, 2.2 * _size, 0)
	_hp_bar.visible = false
	_hp_bar.shaded = false
	add_child(_hp_bar)

func _bar_texture(frac: float) -> ImageTexture:
	var w := 120
	var h := 12
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.05, 0.05, 0.05, 0.85))
	var fw := int(float(w - 4) * clampf(frac, 0.0, 1.0))
	for y in range(2, h - 2):
		for x in range(2, 2 + fw):
			img.set_pixel(x, y, Color(0.80, 0.18, 0.16, 0.95))
	return ImageTexture.create_from_image(img)

# ═══════════════════════════════════════════════ 갱신
func _physics_process(delta: float) -> void:
	if _dead:
		_death_update(delta)
		return

	_atk_cd = maxf(0.0, _atk_cd - delta)
	_timer -= delta
	if _stagger_time > 0.0:
		_stagger_time -= delta
	_stagger_acc = maxf(0.0, _stagger_acc - delta * max_hp * 0.06)
	if _hp_bar_timer > 0.0:
		_hp_bar_timer -= delta
		if _hp_bar_timer <= 0.0 and _hp_bar:
			_hp_bar.visible = false

	if _telegraph > 0.0:
		_telegraph -= delta
		if _telegraph <= 0.0:
			_telegraph = -1.0
			_do_attack()

	_acquire_target()
	if _stagger_time > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	else:
		match state:
			St.IDLE: _st_idle(delta)
			St.WANDER: _st_wander(delta)
			St.CHASE: _st_chase(delta)
			St.ATTACK: _st_attack(delta)
			St.FLEE: _st_flee(delta)

	_apply_motion(delta)

	var sp: float = Vector3(velocity.x, 0, velocity.z).length() / maxf(float(cfg.get("run", 4.0)), 0.1)
	anim.update(delta, clampf(sp, 0.0, 1.0), not is_on_floor() and not _flying, false)

func _acquire_target() -> void:
	var p := GameState.player
	if p == null or not is_instance_valid(p) or p.stats.is_dead:
		target = null
		if state == St.CHASE or state == St.ATTACK:
			state = St.WANDER
		return
	var d := global_position.distance_to(p.global_position)
	var aggro := float(cfg.get("aggro", 22.0))
	# 웅크리면 발각 거리가 줄어든다
	if p.is_crouching:
		aggro *= 0.4 * (1.0 - p.stats.skill_level(Const.Skill.SNEAK) / Const.SKILL_MAX * 0.5)
	if target == null:
		if not cfg.get("passive", false) and not cfg.get("flee", false) and d < aggro:
			target = p
			state = St.CHASE
			if _rng.randf() < 0.4:
				Sfx.play_at("growl", global_position, get_tree().current_scene, -8.0,
					_rng.randf_range(0.7, 1.3))
	else:
		if d > aggro * 2.2:
			target = null
			state = St.WANDER

func _st_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	if _timer <= 0.0:
		_timer = _rng.randf_range(2.0, 6.0)
		state = St.WANDER
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(4.0, 18.0)
		_wander_target = _home + Vector3(cos(a) * r, 0, sin(a) * r)
		_wander_target.y = GameState.height_at(_wander_target.x, _wander_target.z)

func _st_wander(delta: float) -> void:
	var to := _wander_target - global_position
	to.y = 0.0
	if to.length() < 1.5 or _timer <= 0.0:
		state = St.IDLE
		_timer = _rng.randf_range(1.5, 5.0)
		return
	_steer(to.normalized(), float(cfg.get("speed", 2.2)), delta)

func _st_chase(delta: float) -> void:
	if target == null:
		state = St.WANDER
		return
	var to := target.global_position - global_position
	var flat := Vector3(to.x, 0, to.z)
	var rng_atk := float(cfg.get("range", 2.0))
	if flat.length() <= rng_atk * 0.9:
		state = St.ATTACK
		return
	# 도망 성향: 체력이 낮으면 달아난다
	if cfg.get("flee", false) or (hp < max_hp * 0.2 and cfg.get("timid", false)):
		state = St.FLEE
		return
	if flat.length() > 0.01:
		_steer(flat.normalized(), float(cfg.get("run", 3.6)), delta)

func _st_attack(delta: float) -> void:
	if target == null:
		state = St.WANDER
		return
	var to := target.global_position - global_position
	var flat := Vector3(to.x, 0, to.z)
	var rng_atk := float(cfg.get("range", 2.0))
	if flat.length() > rng_atk * 1.25:
		state = St.CHASE
		return
	velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)
	_face(flat, delta)
	if _atk_cd <= 0.0 and _telegraph < 0.0:
		_atk_cd = float(cfg.get("cd", 2.0))
		_telegraph = 0.42
		anim.attack("stab" if cfg.has("ranged") else "slash")
		Sfx.play_at("swing", global_position, get_tree().current_scene, -12.0)

func _st_flee(delta: float) -> void:
	var p := GameState.player
	if p == null or not is_instance_valid(p):
		state = St.WANDER
		return
	var away := global_position - p.global_position
	away.y = 0.0
	if away.length() > 45.0:
		state = St.WANDER
		target = null
		return
	if away.length() > 0.01:
		_steer(away.normalized(), float(cfg.get("run", 3.6)), delta)

func _steer(dir: Vector3, speed: float, delta: float) -> void:
	var target_v := dir * speed
	velocity.x = move_toward(velocity.x, target_v.x, 9.0 * delta * speed)
	velocity.z = move_toward(velocity.z, target_v.z, 9.0 * delta * speed)
	_face(dir, delta)

func _face(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.001:
		return
	var want := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, want, delta * 7.0)

func _apply_motion(delta: float) -> void:
	var ground := GameState.height_at(global_position.x, global_position.z)
	if _flying:
		var want_y := ground + _hover
		if target != null and is_instance_valid(target):
			want_y = maxf(ground + 1.6, target.global_position.y + 1.6)
		velocity.y = clampf((want_y - global_position.y) * 2.4, -6.0, 6.0)
		global_position += velocity * delta
		# 지형을 뚫지 않게
		if global_position.y < ground + 0.6:
			global_position.y = ground + 0.6
		return

	velocity.y -= 22.0 * delta
	velocity.y = maxf(velocity.y, -55.0)
	move_and_slide()

	# 지형 충돌이 없는 구역이면 높이로 보정
	if global_position.y < ground:
		global_position.y = ground
		velocity.y = 0.0
	# 물에 빠지면 살짝 떠오른다
	var depth := Const.WATER_LEVEL - global_position.y
	if depth > 1.0 and not cfg.get("water", false):
		velocity.y = maxf(velocity.y, 2.0)

	# 끼임 탈출
	if state == St.CHASE:
		if global_position.distance_to(_last_p) < 0.05:
			_stuck_t += delta
			if _stuck_t > 1.2:
				_stuck_t = 0.0
				velocity.y = 6.0
				velocity += Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3))
		else:
			_stuck_t = 0.0
	_last_p = global_position

# ═══════════════════════════════════════════════ 공격 실행
func _do_attack() -> void:
	if target == null or not is_instance_valid(target) or _dead:
		return
	var dmg: Dictionary = cfg.get("dmg", {}).duplicate()
	# 난이도 상승: 게임 일수에 따라 소폭 강화
	var day_scale: float = 1.0 + clampf(float(GameState.day) * 0.006, 0.0, 0.5)
	for k in dmg:
		dmg[k] = float(dmg[k]) * day_scale

	if cfg.has("ranged"):
		var r: Dictionary = cfg["ranged"]
		var origin := global_position + Vector3(0, 1.2 * _size, 0)
		var to := target.global_position + Vector3(0, 1.0, 0) - origin
		var dist := to.length()
		var spd := float(r.get("speed", 20.0))
		# 중력 보정 (탄도 예측)
		var dir := to.normalized()
		dir.y += clampf(dist / spd * 0.35, 0.0, 0.6)
		var proj := Projectile.make(dmg, r.get("color", Color(1, 1, 1)), self, true)
		get_tree().current_scene.add_child(proj)
		proj.launch(origin, dir.normalized() * spd)
		Sfx.play_at("bow_shoot", global_position, get_tree().current_scene, -10.0, 0.8)
		return

	var to_t := target.global_position - global_position
	to_t.y = 0.0
	if to_t.length() > float(cfg.get("range", 2.0)) * 1.5:
		return
	if target.has_method("take_hit"):
		target.take_hit(dmg, global_position, self, float(cfg.get("kb", 25.0)))
	Sfx.play_at("flesh_hit", target.global_position, get_tree().current_scene, -6.0)

# ═══════════════════════════════════════════════ 피격
func take_hit(dmg: Dictionary, from_pos: Vector3, attacker = null,
		knockback: float = 0.0) -> void:
	if _dead:
		return
	var total := 0.0
	for k in dmg:
		total += float(dmg[k])
	var armor := float(cfg.get("armor", 0.0))
	var final := PlayerStats.mitigate(total, armor)
	hp -= final

	Fx.float_text(get_tree().current_scene, from_pos + Vector3(0, 0.3, 0),
		str(int(round(final))), Color(1.0, 0.92, 0.65), 0.45)
	Fx.burst(get_tree().current_scene, from_pos, Color(0.65, 0.15, 0.15), 8, 3.0, 0.06, 0.6)
	anim.hit()
	if _hp_bar:
		_hp_bar.texture = _bar_texture(hp / max_hp)
		_hp_bar.visible = true
		_hp_bar_timer = 5.0

	# 경직
	_stagger_acc += final
	var thresh := float(cfg.get("stagger_hp", max_hp * 0.5))
	if _stagger_acc >= thresh:
		_stagger_acc = 0.0
		stagger(2.0)

	# 넉백
	if knockback > 0.0:
		var kd := global_position - from_pos
		kd.y = 0.0
		if kd.length() > 0.01:
			var mass: float = maxf(_size * _size, 0.4)
			velocity += kd.normalized() * clampf(knockback / (mass * 12.0), 0.0, 7.0)
			if not _flying:
				velocity.y = maxf(velocity.y, 2.0)

	# 반격
	if attacker != null and is_instance_valid(attacker) and attacker is Node3D:
		target = attacker
		if state != St.FLEE:
			state = St.CHASE
		if cfg.get("flee", false):
			state = St.FLEE

	if hp <= 0.0:
		_die(attacker)

func stagger(t: float) -> void:
	_stagger_time = maxf(_stagger_time, t)
	anim.knock(1.2)
	Fx.float_text(get_tree().current_scene, global_position + Vector3(0, 2.0 * _size, 0),
		tr("MSG_STAGGERED"), Color(1.0, 0.85, 0.35), 0.45)

func _die(killer) -> void:
	if _dead:
		return
	_dead = true
	state = St.DEAD
	collision_layer = 0
	collision_mask = 0
	GameState.stats["kills"] = int(GameState.stats["kills"]) + 1
	if _hp_bar:
		_hp_bar.visible = false
	Sfx.play_at("death", global_position, get_tree().current_scene, -4.0,
		clampf(1.4 / maxf(_size, 0.5), 0.5, 1.6))
	Fx.burst(get_tree().current_scene, global_position + Vector3(0, 1.0 * _size, 0),
		Color(0.55, 0.12, 0.12), 24, 4.5, 0.09, 1.2)
	_drop_loot()
	died.emit(self)

func _drop_loot() -> void:
	var scene := get_tree().current_scene
	var drops: Dictionary = cfg.get("drops", {})
	for id in drops:
		var spec: Array = drops[id]
		if _rng.randf() > float(spec[2]):
			continue
		var amt := _rng.randi_range(int(spec[0]), int(spec[1]))
		if amt <= 0:
			continue
		ItemDrop.spawn(scene, global_position + Vector3(0, 0.9, 0), id, amt, 1,
			Vector3(_rng.randf_range(-2, 2), _rng.randf_range(2, 4), _rng.randf_range(-2, 2)))
	if cfg.has("trophy"):
		var t: Array = cfg["trophy"]
		if _rng.randf() < float(t[1]):
			ItemDrop.spawn(scene, global_position + Vector3(0, 1.1, 0), str(t[0]), 1, 1,
				Vector3(0, 3.5, 0))

func _death_update(delta: float) -> void:
	_fade += delta
	anim.update(delta, 0.0, false, false, true)
	if _fade > 2.5:
		var a: float = clampf(1.0 - (_fade - 2.5) / 1.5, 0.0, 1.0)
		if rig:
			rig.scale = Vector3(a, a, a) * 1.0
	if _fade > 4.0:
		queue_free()

func distance_to_player() -> float:
	var p := GameState.player
	if p == null or not is_instance_valid(p):
		return 99999.0
	return global_position.distance_to(p.global_position)
