extends CharacterBody3D

signal inventory_changed
signal stats_changed
signal selection_changed(slot: int)

const BARBARIAN_PATH := "res://assets/models/Barbarian.glb"
const ITEM_NAMES := {
	"branch": "가지",
	"stone": "돌",
	"wood": "목재",
	"mushroom": "붉은버섯",
	"berry": "산딸기",
	"meat": "훈제고기",
	"trophy": "뿔 파편",
	"stone_axe": "돌도끼",
	"hammer": "망치",
}
const HOTBAR := ["stone_axe", "hammer", "mushroom", "meat", "trophy"]
const FOOD_DATA := {
	"mushroom": {"hp": 15.0, "stamina": 18.0, "duration": 240.0, "color": Color(0.70, 0.23, 0.18)},
	"berry": {"hp": 10.0, "stamina": 22.0, "duration": 210.0, "color": Color(0.55, 0.20, 0.34)},
	"meat": {"hp": 32.0, "stamina": 12.0, "duration": 300.0, "color": Color(0.68, 0.38, 0.22)},
}

var game: Node
var inventory: Dictionary = {"berry": 2}
var food_slots: Array[Dictionary] = []
var selected_slot := 0
var hp := 25.0
var max_hp := 25.0
var stamina := 50.0
var max_stamina := 50.0
var input_enabled := true
var blocking := false
var dodge_time := 0.0
var invulnerable_time := 0.0
var attack_cooldown := 0.0
var stamina_regen_delay := 0.0
var camera_yaw := 0.0
var camera_pitch := -0.18
var camera_shake := 0.0
var food_ui_tick := 0.0
var heal_tick := 0.0
var spawn_point := Vector3.ZERO
var active_model: Node3D
var hand_item: Node3D
var character_animator: AnimationPlayer
var character_clips: Dictionary = {}
var current_character_clip: StringName = &""
var character_visual_mode := "procedural_fallback"
var attack_animation_active := false
var glb_idle_started := false

@onready var visual_root: Node3D = $VisualRoot
@onready var fallback_body: MeshInstance3D = $VisualRoot/FallbackBody
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var aim_ray: RayCast3D = $CameraPivot/SpringArm3D/Camera3D/AimRay


func _ready() -> void:
	_build_character_visual()
	camera_pivot.rotation = Vector3(camera_pitch, camera_yaw, 0)


func setup(owner_game: Node, start_position: Vector3) -> void:
	game = owner_game
	spawn_point = start_position
	global_position = start_position
	hp = max_hp
	stamina = max_stamina
	inventory_changed.emit()
	stats_changed.emit()
	selection_changed.emit(selected_slot)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if game == null:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	dodge_time = maxf(0.0, dodge_time - delta)
	invulnerable_time = maxf(0.0, invulnerable_time - delta)
	stamina_regen_delay = maxf(0.0, stamina_regen_delay - delta)
	camera_shake = maxf(0.0, camera_shake - delta * 1.8)
	_update_camera_shake()
	_update_food(delta)

	if not is_on_floor():
		velocity.y -= float(ProjectSettings.get_setting("physics/3d/default_gravity", 22.0)) * delta
	else:
		velocity.y = maxf(velocity.y, -0.5)

	if not input_enabled or game.ui_open:
		blocking = false
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
		move_and_slide()
		_update_character_animation(Vector2(velocity.x, velocity.z).length())
		_update_prompt("")
		return

	if Input.is_action_just_pressed("interact") and not game.building_system.active:
		_try_interact()
	if Input.is_action_just_pressed("save_game"):
		game.save_system.save_game()
	if Input.is_action_just_pressed("load_game"):
		game.save_system.load_game()
	for index in range(5):
		if Input.is_action_just_pressed("hotbar_%d" % (index + 1)):
			select_slot(index)

	blocking = Input.is_action_pressed("block") and not game.building_system.active
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camera_right := camera.global_transform.basis.x
	camera_right.y = 0.0
	camera_right = camera_right.normalized()
	var camera_forward := -camera.global_transform.basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var move_direction := (camera_right * input_vector.x + camera_forward * -input_vector.y).normalized()

	if Input.is_action_just_pressed("dodge") and dodge_time <= 0.0 and stamina >= 18.0 and not game.building_system.active:
		spend_stamina(18.0)
		dodge_time = 0.44
		invulnerable_time = 0.34
		if move_direction.length_squared() < 0.1:
			move_direction = -visual_root.global_transform.basis.z
		velocity.x = move_direction.x * 10.5
		velocity.z = move_direction.z * 10.5
		game.notify("회피", Color(0.69, 0.83, 0.82), 0.5)
	elif dodge_time <= 0.0:
		var sprinting := Input.is_action_pressed("sprint") and move_direction.length_squared() > 0.1 and stamina > 0.5
		var speed := 7.1 if sprinting else 4.4
		if blocking:
			speed *= 0.55
		var target_velocity := move_direction * speed
		velocity.x = move_toward(velocity.x, target_velocity.x, 22.0 * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, 22.0 * delta)
		if sprinting:
			spend_stamina(13.5 * delta)
		if Input.is_action_just_pressed("jump") and is_on_floor() and stamina >= 9.0 and not game.building_system.active:
			spend_stamina(9.0)
			velocity.y = 7.6

	if stamina_regen_delay <= 0.0 and not blocking and not Input.is_action_pressed("sprint"):
		stamina = minf(max_stamina, stamina + (16.0 + float(food_slots.size()) * 1.5) * delta)

	if Input.is_action_just_pressed("attack") and not game.building_system.active:
		_attack()

	move_and_slide()
	if move_direction.length_squared() > 0.05 and dodge_time <= 0.0:
		var target_angle := atan2(-move_direction.x, -move_direction.z)
		visual_root.rotation.y = lerp_angle(visual_root.rotation.y, target_angle, minf(1.0, delta * 12.0))
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	visual_root.position.y = sin(Time.get_ticks_msec() * 0.012) * minf(horizontal_speed * 0.006, 0.035)
	_update_character_animation(horizontal_speed)
	_update_prompt(_current_prompt())
	stats_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and input_enabled and (game == null or not game.ui_open):
		var motion := event as InputEventMouseMotion
		camera_yaw -= motion.relative.x * 0.0024
		camera_pitch = clampf(camera_pitch - motion.relative.y * 0.0022, -1.05, 0.45)
		camera_pivot.rotation = Vector3(camera_pitch, camera_yaw, 0)
	elif event.is_action_pressed("zoom_in"):
		spring_arm.spring_length = maxf(2.8, spring_arm.spring_length - 0.45)
	elif event.is_action_pressed("zoom_out"):
		spring_arm.spring_length = minf(7.0, spring_arm.spring_length + 0.45)


func select_slot(index: int) -> void:
	selected_slot = clampi(index, 0, HOTBAR.size() - 1)
	var item: String = HOTBAR[selected_slot]
	if item in FOOD_DATA:
		eat_food(item)
	elif item == "hammer":
		if item_count("hammer") > 0:
			game.building_system.enter()
		else:
			game.notify("먼저 제작 패널에서 망치를 만드세요.", Color(0.94, 0.68, 0.35))
	elif game != null and game.building_system.active:
		game.building_system.exit()
	_update_hand_item()
	selection_changed.emit(selected_slot)


func _attack() -> void:
	if attack_cooldown > 0.0:
		return
	var tool := "stone_axe" if selected_slot == 0 and item_count("stone_axe") > 0 else "fists"
	var cost := 11.0 if tool == "stone_axe" else 6.0
	if stamina < cost:
		game.notify("기력이 부족합니다.", Color(0.92, 0.55, 0.34), 0.7)
		return
	spend_stamina(cost)
	attack_cooldown = 0.58
	_play_attack_animation()
	var target: Object
	aim_ray.force_raycast_update()
	if aim_ray.is_colliding():
		target = aim_ray.get_collider()
	if target == null or not target.has_method("take_hit"):
		target = game.find_attack_target(global_position, -visual_root.global_transform.basis.z, 3.2)
	var damage := 21.0 if tool == "stone_axe" else 7.0
	if target != null and target.has_method("take_hit"):
		target.take_hit(damage, tool, self)
	else:
		game.feedback.burst(global_position + -visual_root.global_transform.basis.z * 1.4, Color(0.66, 0.70, 0.66, 0.35), 0.45)
	_swing_visual()


func _try_interact() -> void:
	var target: Object
	aim_ray.force_raycast_update()
	if aim_ray.is_colliding():
		target = aim_ray.get_collider()
	if target == null or not target.has_method("interact"):
		target = game.find_interactable(global_position, 3.4)
	if target != null and target.has_method("interact"):
		target.interact(self)


func _current_prompt() -> String:
	if game == null or game.building_system.active:
		return ""
	var target: Object
	aim_ray.force_raycast_update()
	if aim_ray.is_colliding():
		target = aim_ray.get_collider()
	if target == null or not target.has_method("get_prompt"):
		target = game.find_interactable(global_position, 3.4)
	if target != null and target.has_method("get_prompt"):
		return str(target.get_prompt())
	return ""


func add_item(item: String, count: int = 1) -> void:
	inventory[item] = item_count(item) + count
	inventory_changed.emit()


func remove_item(item: String, count: int = 1) -> bool:
	if item_count(item) < count:
		return false
	inventory[item] = item_count(item) - count
	if int(inventory[item]) <= 0:
		inventory.erase(item)
	inventory_changed.emit()
	return true


func has_items(cost: Dictionary) -> bool:
	for item: String in cost:
		if item_count(item) < int(cost[item]):
			return false
	return true


func consume_items(cost: Dictionary) -> bool:
	if not has_items(cost):
		return false
	for item: String in cost:
		remove_item(item, int(cost[item]))
	return true


func item_count(item: String) -> int:
	return int(inventory.get(item, 0))


func eat_food(item: String) -> void:
	if item_count(item) <= 0:
		game.notify("먹을 %s이(가) 없습니다." % ITEM_NAMES.get(item, item), Color(0.92, 0.66, 0.36))
		return
	for food: Dictionary in food_slots:
		if str(food.get("id", "")) == item:
			game.notify("같은 음식 효과가 아직 남아 있습니다.", Color(0.88, 0.72, 0.42))
			return
	if food_slots.size() >= 3:
		game.notify("음식 슬롯 3개가 모두 찼습니다.", Color(0.88, 0.72, 0.42))
		return
	remove_item(item, 1)
	var definition: Dictionary = FOOD_DATA[item]
	food_slots.append({
		"id": item,
		"time": float(definition["duration"]),
		"duration": float(definition["duration"]),
		"hp": float(definition["hp"]),
		"stamina": float(definition["stamina"]),
		"color": definition["color"],
	})
	_recalculate_food_stats()
	hp = minf(max_hp, hp + 6.0)
	game.notify("%s을(를) 먹었습니다. 최대 능력치가 증가합니다." % ITEM_NAMES.get(item, item), Color(0.67, 0.86, 0.62))


func take_damage(amount: float, _source: Node = null) -> void:
	if invulnerable_time > 0.0:
		return
	var final_damage := amount
	if blocking and stamina >= amount * 0.75:
		spend_stamina(amount * 0.75)
		final_damage *= 0.32
		game.notify("방어 성공", Color(0.60, 0.82, 0.88), 0.65)
	hp = maxf(0.0, hp - final_damage)
	game.feedback.player_hurt()
	game.feedback.hit(global_position + Vector3.UP * 1.8, int(ceil(final_damage)), Color(0.92, 0.28, 0.22), true, false)
	stats_changed.emit()
	if hp <= 0.0:
		_respawn()


func spend_stamina(amount: float) -> void:
	stamina = maxf(0.0, stamina - amount)
	stamina_regen_delay = 0.85


func add_camera_shake(amount: float) -> void:
	camera_shake = maxf(camera_shake, amount)


func export_inventory() -> Dictionary:
	return inventory.duplicate(true)


func import_inventory(data: Dictionary) -> void:
	inventory.clear()
	for key: Variant in data:
		inventory[str(key)] = maxi(0, int(data[key]))
	inventory_changed.emit()
	_update_hand_item()


func serialize_foods() -> Array:
	var output: Array = []
	for food: Dictionary in food_slots:
		output.append({
			"id": food.get("id", ""),
			"time": food.get("time", 0.0),
		})
	return output


func import_foods(data: Array) -> void:
	food_slots.clear()
	for entry: Variant in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var food_id := str(entry.get("id", ""))
		if not FOOD_DATA.has(food_id) or food_slots.size() >= 3:
			continue
		var definition: Dictionary = FOOD_DATA[food_id]
		food_slots.append({
			"id": food_id,
			"time": minf(float(entry.get("time", 0.0)), float(definition["duration"])),
			"duration": float(definition["duration"]),
			"hp": float(definition["hp"]),
			"stamina": float(definition["stamina"]),
			"color": definition["color"],
		})
	_recalculate_food_stats()


func _update_food(delta: float) -> void:
	var changed := false
	for index in range(food_slots.size() - 1, -1, -1):
		food_slots[index]["time"] = float(food_slots[index]["time"]) - delta
		if float(food_slots[index]["time"]) <= 0.0:
			food_slots.remove_at(index)
			changed = true
	if changed:
		_recalculate_food_stats()
	food_ui_tick -= delta
	if food_ui_tick <= 0.0:
		food_ui_tick = 0.25
		stats_changed.emit()
	heal_tick += delta
	if heal_tick >= 5.0 and not food_slots.is_empty():
		heal_tick = 0.0
		hp = minf(max_hp, hp + 1.0 + food_slots.size() * 0.45)


func _recalculate_food_stats() -> void:
	max_hp = 25.0
	max_stamina = 50.0
	for food: Dictionary in food_slots:
		var ratio := clampf(float(food["time"]) / maxf(float(food["duration"]), 1.0), 0.0, 1.0)
		var fade := 0.5 + ratio * 0.5
		max_hp += float(food["hp"]) * fade
		max_stamina += float(food["stamina"]) * fade
	hp = minf(hp, max_hp)
	stamina = minf(stamina, max_stamina)
	stats_changed.emit()


func _respawn() -> void:
	hp = max_hp
	stamina = max_stamina
	global_position = spawn_point
	velocity = Vector3.ZERO
	game.notify("파도가 당신을 해안으로 돌려보냈습니다.", Color(0.82, 0.54, 0.44), 3.0)


func _update_prompt(text: String) -> void:
	if game != null and game.hud != null:
		game.hud.set_prompt(text)


func _update_camera_shake() -> void:
	if camera_shake > 0.0:
		camera.h_offset = randf_range(-camera_shake, camera_shake)
		camera.v_offset = randf_range(-camera_shake, camera_shake)
	else:
		camera.h_offset = move_toward(camera.h_offset, 0.0, 0.03)
		camera.v_offset = move_toward(camera.v_offset, 0.0, 0.03)


func _swing_visual() -> void:
	if hand_item == null:
		return
	var start_rotation := hand_item.rotation
	var tween := hand_item.create_tween()
	tween.tween_property(hand_item, "rotation", start_rotation + Vector3(-1.1, 0, -0.5), 0.12).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(hand_item, "rotation", start_rotation, 0.24).set_trans(Tween.TRANS_BACK)


func _build_character_visual() -> void:
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.27, 0.34, 0.31)
	body_material.roughness = 0.9
	fallback_body.material_override = body_material
	_build_fallback_details()
	if ResourceLoader.exists(BARBARIAN_PATH):
		var resource: Resource = load(BARBARIAN_PATH)
		if resource is PackedScene:
			var candidate := (resource as PackedScene).instantiate()
			if candidate is Node3D and _contains_mesh(candidate):
				var animator := _find_animation_player_with_idle(candidate)
				if animator != null:
					active_model = candidate as Node3D
					active_model.name = "BarbarianModel"
					active_model.rotation.y = PI
					active_model.visible = false
					visual_root.add_child(active_model)
					character_animator = animator
					character_clips = _collect_character_clips(character_animator)
					_configure_character_animation_loops()
					character_animator.animation_finished.connect(_on_character_animation_finished)
					var idle_clip: StringName = character_clips.get("idle", &"")
					_play_character_clip(idle_clip)
					character_animator.advance(0.001)
					glb_idle_started = character_animator.is_playing() and character_animator.current_animation == idle_clip
					if glb_idle_started:
						character_visual_mode = "animated_glb"
						active_model.visible = true
						for child in visual_root.get_children():
							if child.name.begins_with("Fallback"):
								child.visible = false
					else:
						_discard_glb_model()
				else:
					candidate.queue_free()
			else:
				candidate.queue_free()
	_update_hand_item()


func _contains_mesh(node: Node) -> bool:
	if node is MeshInstance3D:
		return true
	for child in node.get_children():
		if _contains_mesh(child):
			return true
	return false


func _find_animation_player_with_idle(node: Node) -> AnimationPlayer:
	var players: Array[AnimationPlayer] = []
	_collect_animation_players(node, players)
	var selected: AnimationPlayer
	var selected_score := -1
	for animator in players:
		var idle_clip := _select_character_clip(animator, ["idle"])
		if idle_clip == &"":
			continue
		var score := _animation_match_score(idle_clip, ["idle"])
		if score > selected_score:
			selected = animator
			selected_score = score
	return selected


func _collect_animation_players(node: Node, output: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		output.append(node as AnimationPlayer)
	for child in node.get_children():
		_collect_animation_players(child, output)


func _collect_character_clips(animator: AnimationPlayer) -> Dictionary:
	return {
		"idle": _select_character_clip(animator, ["idle"]),
		"walk": _select_character_clip(animator, ["walking", "walk"]),
		"run": _select_character_clip(animator, ["running", "run", "sprint"]),
		"block": _select_character_clip(animator, ["blocking", "block", "guard", "defend"]),
		"attack": _select_character_clip(animator, ["1h_melee_attack_chop", "melee_attack_chop", "attack", "chop", "slice", "swing"]),
	}


func _select_character_clip(animator: AnimationPlayer, keywords: Array) -> StringName:
	var best_clip: StringName = &""
	var best_score := -1
	for entry in animator.get_animation_list():
		var clip_name := StringName(entry)
		var lower_name := String(clip_name).to_lower()
		if lower_name.contains("reset"):
			continue
		var score := _animation_match_score(clip_name, keywords)
		if score > best_score:
			best_clip = clip_name
			best_score = score
	return best_clip


func _animation_match_score(clip_name: StringName, keywords: Array) -> int:
	var lower_name := String(clip_name).to_lower()
	var best_score := -1
	for index in range(keywords.size()):
		var keyword := str(keywords[index]).to_lower()
		var score := -1
		if lower_name == keyword:
			score = 100 - index
		elif lower_name.begins_with(keyword):
			score = 80 - index
		elif lower_name.contains(keyword):
			score = 60 - index
		best_score = maxi(best_score, score)
	return best_score


func _configure_character_animation_loops() -> void:
	for state in ["idle", "walk", "run", "block"]:
		var clip_name: StringName = character_clips.get(state, &"")
		if clip_name != &"":
			var animation := character_animator.get_animation(clip_name)
			if animation != null:
				animation.loop_mode = Animation.LOOP_LINEAR
	var attack_clip: StringName = character_clips.get("attack", &"")
	if attack_clip != &"":
		var attack_animation := character_animator.get_animation(attack_clip)
		if attack_animation != null:
			attack_animation.loop_mode = Animation.LOOP_NONE


func _play_character_clip(clip_name: StringName, restart: bool = false) -> void:
	if character_animator == null or clip_name == &"":
		return
	if not restart and current_character_clip == clip_name and character_animator.is_playing():
		return
	character_animator.play(clip_name, 0.12)
	current_character_clip = clip_name


func _update_character_animation(horizontal_speed: float) -> void:
	if character_animator == null or attack_animation_active:
		return
	var state := "idle"
	if blocking:
		state = "block"
	elif horizontal_speed > 5.25:
		state = "run"
	elif horizontal_speed > 0.2:
		state = "walk"
	var target_clip: StringName = character_clips.get(state, &"")
	if target_clip == &"" and state == "run":
		target_clip = character_clips.get("walk", &"")
	if target_clip == &"":
		target_clip = character_clips.get("idle", &"")
	_play_character_clip(target_clip)


func _play_attack_animation() -> void:
	var attack_clip: StringName = character_clips.get("attack", &"")
	if character_animator == null or attack_clip == &"":
		return
	attack_animation_active = true
	_play_character_clip(attack_clip, true)


func _on_character_animation_finished(clip_name: StringName) -> void:
	var attack_clip: StringName = character_clips.get("attack", &"")
	if attack_animation_active and clip_name == attack_clip:
		attack_animation_active = false
		_update_character_animation(Vector2(velocity.x, velocity.z).length())


func _discard_glb_model() -> void:
	if active_model != null:
		if active_model.get_parent() != null:
			active_model.get_parent().remove_child(active_model)
		active_model.queue_free()
	active_model = null
	character_animator = null
	character_clips.clear()
	current_character_clip = &""
	glb_idle_started = false
	character_visual_mode = "procedural_fallback"


func get_character_visual_mode() -> String:
	return character_visual_mode


func is_glb_idle_playing() -> bool:
	if character_visual_mode != "animated_glb" or character_animator == null:
		return false
	var idle_clip: StringName = character_clips.get("idle", &"")
	return glb_idle_started and character_animator.is_playing() and character_animator.current_animation == idle_clip


func has_valid_character_visual() -> bool:
	if character_visual_mode == "animated_glb":
		return active_model != null and is_instance_valid(active_model) and glb_idle_started
	return character_visual_mode == "procedural_fallback" and fallback_body.visible


func _build_fallback_details() -> void:
	var skin := Color(0.58, 0.42, 0.30)
	var iron := Color(0.25, 0.28, 0.28)
	_add_visual_mesh(SphereMesh.new(), skin, Vector3(0, 1.72, 0), Vector3(0.34, 0.34, 0.34), "FallbackHead")
	var helmet := SphereMesh.new()
	helmet.radius = 0.37
	helmet.height = 0.36
	helmet.radial_segments = 8
	helmet.rings = 3
	_add_visual_mesh(helmet, iron, Vector3(0, 1.92, 0), Vector3(1, 0.55, 1), "FallbackHelmet")
	var cloak := BoxMesh.new()
	cloak.size = Vector3(0.78, 1.15, 0.12)
	_add_visual_mesh(cloak, Color(0.30, 0.12, 0.10), Vector3(0, 1.06, 0.31), Vector3.ONE, "FallbackCloak")
	for side in [-1.0, 1.0]:
		var horn := CylinderMesh.new()
		horn.top_radius = 0.015
		horn.bottom_radius = 0.085
		horn.height = 0.38
		horn.radial_segments = 6
		var horn_node := _add_visual_mesh(horn, Color(0.66, 0.59, 0.43), Vector3(side * 0.31, 2.05, 0), Vector3.ONE, "FallbackHorn")
		horn_node.rotation.z = side * 0.8
	hand_item = Node3D.new()
	hand_item.name = "HandItem"
	hand_item.position = Vector3(-0.52, 1.08, -0.18)
	visual_root.add_child(hand_item)


func _update_hand_item() -> void:
	if hand_item == null:
		return
	for child in hand_item.get_children():
		child.queue_free()
	var item: String = HOTBAR[selected_slot]
	if item not in ["stone_axe", "hammer"] or item_count(item) <= 0:
		return
	var handle := CylinderMesh.new()
	handle.top_radius = 0.035
	handle.bottom_radius = 0.045
	handle.height = 0.95
	handle.radial_segments = 6
	_add_item_mesh(handle, Color(0.34, 0.23, 0.14), Vector3(0, 0, 0))
	var head := BoxMesh.new()
	head.size = Vector3(0.48 if item == "stone_axe" else 0.34, 0.22, 0.16 if item == "stone_axe" else 0.28)
	_add_item_mesh(head, Color(0.34, 0.38, 0.37) if item == "stone_axe" else Color(0.38, 0.29, 0.19), Vector3(0, 0.42, 0))
	hand_item.rotation.z = -0.25


func _add_visual_mesh(mesh: PrimitiveMesh, color: Color, at: Vector3, mesh_scale: Vector3, node_name: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.scale = mesh_scale
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	node.material_override = material
	visual_root.add_child(node)
	return node


func _add_item_mesh(mesh: PrimitiveMesh, color: Color, at: Vector3) -> void:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	node.material_override = material
	hand_item.add_child(node)
