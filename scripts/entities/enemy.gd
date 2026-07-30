extends CharacterBody3D

const ENEMY_GREEN := Color(0.19, 0.29, 0.22)
const ENEMY_BARK := Color(0.28, 0.21, 0.15)
const BOSS_GREEN := Color(0.12, 0.24, 0.17)
const RUNE_GLOW := Color(0.36, 0.92, 0.66)

var game: Node
var is_boss := false
var staged_for_capture := false
var aggressive := false
var state := "wander"
var health := 48.0
var max_health := 48.0
var speed := 2.3
var attack_damage := 11.0
var attack_timer := 0.0
var wander_timer := 0.0
var wander_direction := Vector3.ZERO
var hit_timer := 0.0
var dead := false
var pattern_timer := 3.5
var pattern_state := ""
var pattern_phase := 0.0
var charge_direction := Vector3.ZERO
var charge_has_hit := false
var root_target := Vector3.ZERO
var body_material: StandardMaterial3D
var rng := RandomNumberGenerator.new()

@onready var visual: Node3D = $Visual
@onready var collision: CollisionShape3D = $CollisionShape3D


func setup(owner_game: Node, boss: bool = false, capture_staged: bool = false) -> void:
	game = owner_game
	is_boss = boss
	staged_for_capture = capture_staged
	rng.seed = 9203 + get_instance_id()
	if is_boss:
		health = 360.0
		max_health = health
		speed = 3.1
		attack_damage = 23.0
		collision.scale = Vector3(1.55, 1.8, 1.55)
	_build_visual()
	if is_boss:
		game.hud.show_boss("에이크비드 · 뿔 달린 숲 수호자", health, max_health)


func _physics_process(delta: float) -> void:
	if game == null or dead or not game.gameplay_started:
		return
	attack_timer = maxf(0.0, attack_timer - delta)
	hit_timer = maxf(0.0, hit_timer - delta)
	if not is_on_floor():
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity", 22.0)) * delta
	else:
		velocity.y = maxf(velocity.y, -0.5)

	if staged_for_capture:
		velocity.x = 0.0
		velocity.z = 0.0
		_look_toward(game.player.global_position, delta)
		move_and_slide()
		return

	var player: Node3D = game.player
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var distance := to_player.length()

	if is_boss and _update_boss_pattern(delta, to_player, distance):
		move_and_slide()
		return

	if hit_timer > 0.0:
		state = "hit"
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	elif distance < (24.0 if is_boss else 17.0) or aggressive:
		if distance > (3.0 if is_boss else 2.15):
			state = "chase"
			var direction := to_player.normalized()
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
			_look_toward(player.global_position, delta)
		else:
			state = "attack"
			velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
			_look_toward(player.global_position, delta)
			if attack_timer <= 0.0:
				attack_timer = 1.35 if not is_boss else 1.05
				_melee_attack(player)
	else:
		state = "wander"
		wander_timer -= delta
		if wander_timer <= 0.0:
			wander_timer = rng.randf_range(2.0, 4.8)
			var angle := rng.randf_range(0.0, TAU)
			wander_direction = Vector3(cos(angle), 0, sin(angle))
		velocity.x = move_toward(velocity.x, wander_direction.x * speed * 0.35, 4.0 * delta)
		velocity.z = move_toward(velocity.z, wander_direction.z * speed * 0.35, 4.0 * delta)
		_look_toward(global_position + wander_direction, delta)
	move_and_slide()


func take_hit(damage: float, _tool: String, attacker: Node) -> void:
	if dead:
		return
	health -= damage
	hit_timer = 0.2
	state = "hit"
	var away: Vector3 = global_position - attacker.global_position
	away.y = 0.0
	if away.length_squared() > 0.01:
		away = away.normalized()
		velocity.x = away.x * (2.2 if is_boss else 4.0)
		velocity.z = away.z * (2.2 if is_boss else 4.0)
	game.feedback.hit(global_position + Vector3.UP * (2.8 if is_boss else 1.6), int(damage), Color(0.85, 0.88, 0.68), damage >= 20.0)
	_hit_flash()
	if is_boss:
		game.hud.update_boss(health, max_health)
	if health <= 0.0:
		_die()


func _update_boss_pattern(delta: float, to_player: Vector3, distance: float) -> bool:
	if pattern_state.is_empty():
		pattern_timer -= delta
		if pattern_timer <= 0.0:
			if rng.randf() < 0.5:
				pattern_state = "charge_warning"
				pattern_phase = 0.9
				charge_direction = to_player.normalized()
				charge_has_hit = false
				game.notify("에이크비드가 뿔을 낮춥니다!", Color(0.92, 0.55, 0.34), 1.2)
				game.feedback.burst(global_position, Color(0.88, 0.38, 0.22, 0.75), 1.6)
			else:
				pattern_state = "root_warning"
				pattern_phase = 1.15
				root_target = game.player.global_position
				game.notify("땅 아래 뿌리가 꿈틀거립니다!", Color(0.45, 0.88, 0.57), 1.3)
				game.feedback.burst(root_target, Color(0.30, 0.76, 0.42, 0.72), 5.6)
			return true
		return false

	pattern_phase -= delta
	match pattern_state:
		"charge_warning":
			state = "attack"
			velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
			_look_toward(global_position + charge_direction, delta * 2.0)
			if pattern_phase <= 0.0:
				pattern_state = "charge"
				pattern_phase = 0.85
		"charge":
			state = "attack"
			velocity.x = charge_direction.x * 12.5
			velocity.z = charge_direction.z * 12.5
			if distance < 2.2 and not charge_has_hit:
				charge_has_hit = true
				game.player.take_damage(34.0, self)
			if pattern_phase <= 0.0:
				_finish_pattern(3.4)
		"root_warning":
			state = "attack"
			velocity.x = 0.0
			velocity.z = 0.0
			if pattern_phase <= 0.0:
				_root_slam()
				_finish_pattern(3.0)
	return true


func _root_slam() -> void:
	var center: Vector3 = root_target
	center.y = game.world.height_at(center.x, center.z) + 0.05
	game.feedback.burst(center, Color(0.32, 0.92, 0.50, 0.9), 6.2)
	for index in range(10):
		var angle := TAU * float(index) / 10.0
		var root := MeshInstance3D.new()
		var root_mesh := CylinderMesh.new()
		root_mesh.top_radius = 0.02
		root_mesh.bottom_radius = 0.18
		root_mesh.height = 1.8
		root_mesh.radial_segments = 5
		root.mesh = root_mesh
		var root_material := StandardMaterial3D.new()
		root_material.albedo_color = Color(0.25, 0.35, 0.20)
		root_material.emission_enabled = true
		root_material.emission = Color(0.15, 0.42, 0.21)
		root.material_override = root_material
		game.feedback.add_child(root)
		root.global_position = center + Vector3(cos(angle) * 3.8, -0.8, sin(angle) * 3.8)
		root.rotation.z = sin(angle) * 0.35
		root.rotation.x = cos(angle) * 0.35
		var tween := root.create_tween()
		tween.tween_property(root, "position:y", root.position.y + 1.8, 0.18).set_trans(Tween.TRANS_BACK)
		tween.tween_interval(0.42)
		tween.tween_property(root, "scale", Vector3.ZERO, 0.25)
		tween.tween_callback(root.queue_free)
	if center.distance_to(game.player.global_position) < 6.2:
		game.player.take_damage(28.0, self)


func _finish_pattern(delay: float) -> void:
	pattern_state = ""
	pattern_timer = delay
	pattern_phase = 0.0
	velocity.x *= 0.2
	velocity.z *= 0.2


func _melee_attack(player: Node) -> void:
	var attack_color := Color(0.42, 0.86, 0.55, 0.7) if is_boss else Color(0.70, 0.52, 0.28, 0.6)
	game.feedback.burst(global_position + -visual.global_transform.basis.z * 1.2, attack_color, 0.8)
	if global_position.distance_to(player.global_position) <= (3.4 if is_boss else 2.5):
		player.take_damage(attack_damage, self)


func _die() -> void:
	dead = true
	state = "dead"
	collision.set_deferred("disabled", true)
	game.enemy_defeated(is_boss, global_position)
	if not is_boss:
		game.spawn_pickup("trophy_drop", global_position + Vector3(0.3, 0.25, 0), 1)
		game.spawn_pickup("meat_drop", global_position + Vector3(-0.35, 0.25, 0.2), 1)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual, "scale", Vector3(1.2, 0.05, 1.2), 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(visual, "rotation:z", 1.25, 0.45)
	tween.chain().tween_callback(queue_free)


func _look_toward(target: Vector3, delta: float) -> void:
	var flat_target := target
	flat_target.y = global_position.y
	if global_position.distance_squared_to(flat_target) < 0.01:
		return
	var target_angle := atan2(-(flat_target.x - global_position.x), -(flat_target.z - global_position.z))
	visual.rotation.y = lerp_angle(visual.rotation.y, target_angle, minf(1.0, delta * 6.0))


func _hit_flash() -> void:
	var start_scale := visual.scale
	var tween := visual.create_tween()
	tween.tween_property(visual, "scale", start_scale * 1.1, 0.06)
	tween.tween_property(visual, "scale", start_scale, 0.14)
	if body_material != null:
		body_material.emission_enabled = true
		body_material.emission = Color(0.92, 0.88, 0.64)
		body_material.emission_energy_multiplier = 2.5
		var material_tween := create_tween()
		material_tween.tween_property(body_material, "emission_energy_multiplier", 0.0, 0.18)


func _build_visual() -> void:
	for child in visual.get_children():
		child.queue_free()
	var scale_factor := 1.65 if is_boss else 1.0
	visual.scale = Vector3.ONE * scale_factor
	body_material = StandardMaterial3D.new()
	body_material.albedo_color = BOSS_GREEN if is_boss else ENEMY_GREEN
	body_material.roughness = 0.94

	var torso := CapsuleMesh.new()
	torso.radius = 0.42
	torso.height = 1.25
	torso.radial_segments = 7
	torso.rings = 3
	_mesh(torso, body_material, Vector3(0, 1.03, 0), Vector3.ONE)
	var head_material := StandardMaterial3D.new()
	head_material.albedo_color = ENEMY_BARK
	head_material.roughness = 0.98
	var head := SphereMesh.new()
	head.radius = 0.34
	head.height = 0.62
	head.radial_segments = 7
	head.rings = 4
	_mesh(head, head_material, Vector3(0, 1.75, -0.03), Vector3(1.0, 0.9, 0.95))
	for side in [-1.0, 1.0]:
		var arm := CylinderMesh.new()
		arm.top_radius = 0.08
		arm.bottom_radius = 0.13
		arm.height = 1.05
		arm.radial_segments = 6
		var arm_node := _mesh(arm, head_material, Vector3(side * 0.48, 1.05, 0), Vector3.ONE)
		arm_node.rotation.z = side * 0.24
		var leg := CylinderMesh.new()
		leg.top_radius = 0.10
		leg.bottom_radius = 0.14
		leg.height = 0.78
		leg.radial_segments = 6
		_mesh(leg, head_material, Vector3(side * 0.2, 0.4, 0), Vector3.ONE)

	var eye_material := StandardMaterial3D.new()
	eye_material.albedo_color = RUNE_GLOW
	eye_material.emission_enabled = true
	eye_material.emission = RUNE_GLOW
	eye_material.emission_energy_multiplier = 3.5
	for side in [-1.0, 1.0]:
		var eye := SphereMesh.new()
		eye.radius = 0.045
		eye.height = 0.09
		eye.radial_segments = 6
		eye.rings = 3
		_mesh(eye, eye_material, Vector3(side * 0.12, 1.8, -0.30), Vector3.ONE)

	if is_boss:
		_build_antlers(head_material)
		var moss := TorusMesh.new()
		moss.inner_radius = 0.36
		moss.outer_radius = 0.5
		moss.rings = 12
		moss.ring_segments = 6
		var moss_material := StandardMaterial3D.new()
		moss_material.albedo_color = Color(0.28, 0.48, 0.27)
		moss_material.roughness = 1.0
		_mesh(moss, moss_material, Vector3(0, 1.38, 0), Vector3.ONE)


func _build_antlers(material: StandardMaterial3D) -> void:
	for side in [-1.0, 1.0]:
		var beam := CylinderMesh.new()
		beam.top_radius = 0.07
		beam.bottom_radius = 0.13
		beam.height = 1.45
		beam.radial_segments = 6
		var beam_node := _mesh(beam, material, Vector3(side * 0.38, 2.32, 0), Vector3.ONE)
		beam_node.rotation.z = side * 0.48
		for tine_index in range(3):
			var tine := CylinderMesh.new()
			tine.top_radius = 0.025
			tine.bottom_radius = 0.075
			tine.height = 0.68 - tine_index * 0.08
			tine.radial_segments = 5
			var tine_node := _mesh(tine, material, Vector3(side * (0.55 + tine_index * 0.18), 2.05 + tine_index * 0.38, 0), Vector3.ONE)
			tine_node.rotation.z = side * 0.95


func _mesh(mesh: PrimitiveMesh, material: Material, at: Vector3, mesh_scale: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.scale = mesh_scale
	node.material_override = material
	visual.add_child(node)
	return node
