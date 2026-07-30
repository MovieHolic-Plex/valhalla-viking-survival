extends Node3D

const RESOURCE_SCENE: PackedScene = preload("res://scenes/entities/resource_node.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/entities/enemy.tscn")
const ALTAR_SCENE: PackedScene = preload("res://scenes/entities/altar.tscn")
const RECIPES := {
	"stone_axe": {"name": "돌도끼", "cost": {"branch": 3, "stone": 2}},
	"hammer": {"name": "망치", "cost": {"wood": 3, "stone": 1}},
}
const OBJECTIVES := [
	{"title": "해안의 흔적", "description": "가지 3개와 돌 2개를 E로 주우세요."},
	{"title": "손에 쥔 돌날", "description": "Tab 또는 C를 열어 돌도끼를 제작하세요."},
	{"title": "숲의 첫 상처", "description": "1번 돌도끼를 들고 나무를 쓰러뜨리세요."},
	{"title": "불과 손길", "description": "망치를 만들고 모닥불과 작업대를 모두 설치하세요."},
	{"title": "밤의 이빨", "description": "숲을 배회하는 그레이링을 처치해 뿔 파편을 얻으세요."},
	{"title": "뿔 제단", "description": "해안의 녹색 제단에 뿔 파편을 바치세요."},
	{"title": "수호자의 심장", "description": "돌진을 피하고 뿌리 강타에서 벗어나 에이크비드를 쓰러뜨리세요."},
	{"title": "해안의 주인", "description": "숲의 수호자가 쓰러졌습니다. 해안의 새 아침을 맞았습니다."},
]
const CAPTURE_OBJECTIVE_STEP := 4
const CAPTURE_PLAYER_POSITION := Vector3(0.0, 0.0, 0.0)
const CAPTURE_CAMP_Z_RANGE := Vector2(4.0, 8.0)
const CAPTURE_CAMPFIRE_POSITION := Vector3(-1.8, 0.0, 4.4)
const CAPTURE_WORKBENCH_POSITION := Vector3(2.2, 0.0, 6.1)
const CAPTURE_ENEMY_POSITION := Vector3(-3.2, 0.0, 13.5)
const CAPTURE_ALTAR_POSITION := Vector3(-7.0, 0.0, 11.5)

@onready var world: Node3D = $World
@onready var buildings: Node3D = $Buildings
@onready var actors: Node3D = $Actors
@onready var player: CharacterBody3D = $Player
@onready var building_system: Node3D = $BuildingSystem
@onready var save_system: Node = $SaveSystem
@onready var feedback: Node3D = $Feedback
@onready var hud: CanvasLayer = $HUD

var objective_step := 0
var world_time := 0.31
var day_number := 1
var was_night := false
var raid_started := false
var raid_active := false
var raid_remaining := 0
var raid_completed := false
var tree_felled := false
var regular_kills := 0
var altar_awakened := false
var boss_active := false
var boss_defeated := false
var ui_open := false
var gameplay_started := false
var auto_mode := false
var smoke_mode := false
var capture_path := ""
var capture_mode := false
var capture_state_ready := false
var last_phase_label := ""


func _ready() -> void:
	_parse_command_line()
	feedback.setup(self)
	world.setup(self)
	var start_position := Vector3(0, world.height_at(0, 1.5) + 0.15, 1.5)
	player.setup(self, start_position)
	hud.setup(self, player)
	building_system.setup(self, player, hud)
	save_system.setup(self)
	spawn_enemy(Vector3(11.5, world.height_at(11.5, 15.0) + 0.1, 15.0))
	refresh_objective()
	_update_day_display(true)

	if auto_mode or smoke_mode or capture_mode:
		start_game()
	else:
		gameplay_started = false
		ui_open = true
		player.input_enabled = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		hud.show_title(true)

	if capture_mode:
		_stage_capture_scene()
		_capture_after_frames.call_deferred()
	elif smoke_mode:
		_run_smoke.call_deferred()


func _process(delta: float) -> void:
	if not gameplay_started or smoke_mode or capture_mode:
		return
	var previous_time := world_time
	world_time += delta / 300.0
	if world_time >= 1.0:
		world_time -= 1.0
		day_number += 1
		raid_started = false
	var night := _is_night(world_time)
	world.set_daylight(world_time, night)
	if night != was_night or absf(world_time - previous_time) > 0.01:
		_update_day_display(night != was_night)
	if night and not was_night and _can_start_night_raid():
		_start_night_raid()
	was_night = night


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("crafting") and gameplay_started and not building_system.active:
		toggle_crafting()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("cancel"):
		if building_system.active:
			building_system.exit()
		elif ui_open and gameplay_started:
			toggle_crafting(false)
		elif gameplay_started:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED


func start_game() -> void:
	gameplay_started = true
	ui_open = false
	player.input_enabled = true
	hud.show_title(false)
	hud.set_crafting_visible(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func toggle_crafting(force: Variant = null) -> void:
	if not gameplay_started or building_system.active:
		return
	var open := not ui_open if force == null else bool(force)
	ui_open = open
	player.input_enabled = not open
	hud.set_crafting_visible(open)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED


func craft_item(recipe_id: String) -> void:
	if not RECIPES.has(recipe_id):
		return
	if player.item_count(recipe_id) > 0:
		notify("이미 %s을(를) 가지고 있습니다." % RECIPES[recipe_id]["name"], Color(0.82, 0.74, 0.48))
		return
	var recipe: Dictionary = RECIPES[recipe_id]
	var cost: Dictionary = recipe["cost"]
	if not player.has_items(cost):
		var missing: Array[String] = []
		for item: String in cost:
			var needed: int = int(cost[item]) - player.item_count(item)
			if needed > 0:
				missing.append("%s %d" % [player.ITEM_NAMES.get(item, item), needed])
		notify("재료 부족 · %s" % " · ".join(missing), Color(0.96, 0.48, 0.34), 2.4)
		return
	player.consume_items(cost)
	player.add_item(recipe_id, 1)
	feedback.play_sfx("craft")
	if recipe_id == "hammer":
		toggle_crafting(false)
	player.select_slot(0 if recipe_id == "stone_axe" else 1)
	notify("%s 제작 성공" % recipe["name"], Color(0.62, 0.88, 0.62), 2.2)
	_evaluate_objectives()


func spawn_resource(kind: String, spawn_position: Vector3, variant_seed: int = 0, amount: int = 1) -> Node3D:
	var resource := RESOURCE_SCENE.instantiate() as Node3D
	world.resources_root.add_child(resource)
	resource.global_position = spawn_position
	resource.setup(kind, self, variant_seed, amount)
	return resource


func spawn_pickup(kind: String, spawn_position: Vector3, amount: int = 1) -> Node3D:
	var resource_kind := kind
	if kind == "trophy_drop":
		resource_kind = "trophy_drop"
	elif kind == "meat_drop":
		resource_kind = "meat_drop"
	var pickup := spawn_resource(resource_kind, spawn_position, Time.get_ticks_msec() % 10000, amount)
	pickup.rotation.y = randf_range(0.0, TAU)
	return pickup


func spawn_enemy(spawn_position: Vector3, as_boss: bool = false, staged: bool = false) -> CharacterBody3D:
	var enemy := ENEMY_SCENE.instantiate() as CharacterBody3D
	actors.add_child(enemy)
	enemy.global_position = spawn_position
	enemy.setup(self, as_boss, staged)
	return enemy


func spawn_altar(spawn_position: Vector3) -> Node3D:
	var new_altar := ALTAR_SCENE.instantiate() as Node3D
	world.resources_root.add_child(new_altar)
	new_altar.global_position = spawn_position
	new_altar.setup(self)
	return new_altar


func resource_collected(item_id: String, amount: int) -> void:
	notify("%s +%d" % [player.ITEM_NAMES.get(item_id, item_id), amount], Color(0.72, 0.82, 0.65), 0.9)
	_evaluate_objectives()


func resource_broken(kind: String) -> void:
	if kind == "tree":
		tree_felled = true
		notify("나무가 쓰러졌습니다. 떨어진 목재를 주우세요.", Color(0.76, 0.66, 0.42), 2.0)
	_evaluate_objectives()


func building_placed(_kind: String) -> void:
	_evaluate_objectives()


func enemy_defeated(as_boss: bool, _death_position: Vector3) -> void:
	if as_boss:
		boss_active = false
		boss_defeated = true
		hud.hide_boss()
		_evaluate_objectives()
		return
	regular_kills += 1
	if raid_active:
		raid_remaining = maxi(0, raid_remaining - 1)
		if raid_remaining == 0:
			raid_active = false
			raid_completed = true
			notify("밤의 습격을 막아냈습니다.", Color(0.64, 0.88, 0.72), 3.0)
	_evaluate_objectives()


func altar_activated(altar_position: Vector3) -> void:
	if boss_active or boss_defeated:
		return
	altar_awakened = true
	boss_active = true
	_evaluate_objectives()
	notify("공물이 받아들여졌습니다. 숲의 수호자가 깨어납니다!", Color(0.50, 0.92, 0.65), 3.2)
	feedback.play_sfx("boss")
	feedback.burst(altar_position + Vector3.UP * 0.2, Color(0.28, 1.0, 0.55, 0.9), 7.0)
	var boss_position := altar_position + Vector3(0, 0.2, 6.0)
	boss_position.y = world.height_at(boss_position.x, boss_position.z) + 0.15
	spawn_enemy(boss_position, true)


func find_interactable(origin: Vector3, radius: float) -> Object:
	var nearest: Object
	var nearest_distance := radius
	for candidate in world.resources_root.get_children():
		if candidate is Node3D and candidate.has_method("get_prompt"):
			var distance := origin.distance_to((candidate as Node3D).global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = candidate
	return nearest


func find_attack_target(origin: Vector3, forward: Vector3, radius: float) -> Object:
	var nearest: Object
	var nearest_distance := radius
	var candidates: Array[Node] = []
	candidates.append_array(actors.get_children())
	candidates.append_array(world.resources_root.get_children())
	for candidate in candidates:
		if not candidate is Node3D or not candidate.has_method("take_hit"):
			continue
		var offset: Vector3 = (candidate as Node3D).global_position - origin
		var distance := offset.length()
		if distance <= 0.01 or distance >= nearest_distance:
			continue
		var flat_offset := Vector3(offset.x, 0, offset.z).normalized()
		var flat_forward := Vector3(forward.x, 0, forward.z).normalized()
		if flat_forward.dot(flat_offset) > 0.16:
			nearest = candidate
			nearest_distance = distance
	return nearest


func _clear_dynamic_actors() -> void:
	for actor in actors.get_children():
		actors.remove_child(actor)
		actor.queue_free()


func prepare_for_load() -> void:
	_clear_dynamic_actors()
	raid_started = false
	raid_active = false
	raid_remaining = 0
	boss_active = false
	boss_defeated = false
	altar_awakened = false
	regular_kills = 0
	capture_state_ready = false
	if world.altar != null:
		world.altar.awakened = false
	hud.hide_boss()
	if hud.raid_banner != null:
		hud.raid_banner.visible = false
	if hud.victory_overlay != null:
		hud.victory_overlay.visible = false


func replenish_loaded_starter_pickups() -> int:
	for resource in world.resources_root.get_children():
		if resource.has_meta("loaded_starter_pickup"):
			world.resources_root.remove_child(resource)
			resource.queue_free()
	if objective_step >= 2:
		return 0
	var requirements := {"branch": 3, "stone": 2}
	var offsets := [
		Vector3(-2.2, 0, 1.2), Vector3(2.1, 0, 1.5), Vector3(-1.4, 0, 2.6),
		Vector3(1.5, 0, 2.8), Vector3(0.2, 0, 3.3),
	]
	var spawned := 0
	for item_id in ["branch", "stone"]:
		var missing := maxi(0, int(requirements[item_id]) - player.item_count(item_id))
		for index in range(missing):
			var position: Vector3 = player.global_position + offsets[spawned % offsets.size()]
			position.y = world.height_at(position.x, position.z) + 0.08
			var resource_kind := "branch" if item_id == "branch" else "stone_pickup"
			var pickup := spawn_resource(resource_kind, position, 8200 + spawned)
			pickup.set_meta("loaded_starter_pickup", true)
			spawned += 1
	return spawned


func apply_loaded_objective_state() -> void:
	raid_started = raid_completed or _is_night(world_time)
	was_night = _is_night(world_time)
	tree_felled = objective_step >= 3
	regular_kills = 1 if objective_step >= 5 else 0
	altar_awakened = objective_step >= 6
	boss_defeated = objective_step >= 7
	if world.altar != null:
		world.altar.awakened = objective_step >= 6
	if objective_step <= 4:
		var enemy_position := Vector3(11.5, world.height_at(11.5, 15.0) + 0.1, 15.0)
		spawn_enemy(enemy_position)
	if objective_step == 6:
		boss_active = true
		var boss_position: Vector3 = world.altar.global_position + Vector3(0, 0, 6.0)
		boss_position.y = world.height_at(boss_position.x, boss_position.z) + 0.15
		spawn_enemy(boss_position, true)
	elif objective_step >= 7:
		boss_active = false
		hud.hide_boss()
		hud.show_victory()


func refresh_objective() -> void:
	objective_step = clampi(objective_step, 0, OBJECTIVES.size() - 1)
	var objective: Dictionary = OBJECTIVES[objective_step]
	var description := str(objective["description"])
	if objective_step == 0:
		description += "\n가지 %d/3  ·  돌 %d/2" % [mini(player.item_count("branch"), 3), mini(player.item_count("stone"), 2)]
	elif objective_step == 3:
		var kinds: Array[String] = building_system.placed_kinds()
		description += "\n모닥불 %s  ·  작업대 %s" % ["완료" if "campfire" in kinds else "미설치", "완료" if "workbench" in kinds else "미설치"]
	hud.set_objective(objective_step, str(objective["title"]), description)


func notify(text: String, color: Color = Color.WHITE, duration: float = 2.2) -> void:
	if hud != null:
		hud.notify(text, color, duration)


func _evaluate_objectives() -> void:
	var advanced := true
	while advanced and objective_step < OBJECTIVES.size() - 1:
		advanced = false
		match objective_step:
			0:
				advanced = player.item_count("branch") >= 3 and player.item_count("stone") >= 2
			1:
				advanced = player.item_count("stone_axe") > 0
			2:
				advanced = tree_felled
			3:
				var kinds: Array[String] = building_system.placed_kinds()
				advanced = "campfire" in kinds and "workbench" in kinds
			4:
				advanced = regular_kills > 0
			5:
				advanced = altar_awakened
			6:
				advanced = boss_defeated
		if advanced:
			objective_step += 1
			refresh_objective()
			notify("새 목표 · %s" % OBJECTIVES[objective_step]["title"], Color(0.87, 0.74, 0.43), 2.6)
			if objective_step == OBJECTIVES.size() - 1:
				hud.show_victory()
	refresh_objective()


func _can_start_night_raid() -> bool:
	return not raid_started and not raid_completed and not raid_active and not boss_active


func _start_night_raid() -> void:
	if not _can_start_night_raid():
		return
	raid_started = true
	raid_active = true
	raid_remaining = 3
	hud.show_raid("숲이 움직입니다")
	notify("밤의 습격 · 모닥불을 지키세요!", Color(0.95, 0.38, 0.28), 3.0)
	feedback.play_sfx("warning")
	for index in range(3):
		var angle := TAU * float(index) / 3.0 + 0.4
		var spawn_position := player.global_position + Vector3(cos(angle) * 15.0, 0, sin(angle) * 15.0)
		spawn_position.y = world.height_at(spawn_position.x, spawn_position.z) + 0.1
		var raider := spawn_enemy(spawn_position)
		raider.aggressive = true


func _is_night(phase: float) -> bool:
	return phase < 0.17 or phase >= 0.72


func _update_day_display(force: bool = false) -> void:
	var phase_name := "한밤"
	if world_time < 0.17:
		phase_name = "새벽"
	elif world_time < 0.30:
		phase_name = "아침"
	elif world_time < 0.54:
		phase_name = "낮"
	elif world_time < 0.72:
		phase_name = "해질녘"
	if force or phase_name != last_phase_label:
		last_phase_label = phase_name
		hud.set_day(day_number, _is_night(world_time), phase_name)
	world.set_daylight(world_time, _is_night(world_time))


func _parse_command_line() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--auto":
			auto_mode = true
		elif argument == "--smoke":
			smoke_mode = true
			auto_mode = true
		elif argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
			capture_mode = true
			auto_mode = true


func _stage_capture_scene() -> void:
	world_time = 0.42
	objective_step = CAPTURE_OBJECTIVE_STEP
	tree_felled = true
	regular_kills = 0
	altar_awakened = false
	boss_active = false
	boss_defeated = false
	raid_started = false
	raid_active = false
	raid_remaining = 0
	raid_completed = false
	_clear_dynamic_actors()
	player.global_position = CAPTURE_PLAYER_POSITION
	player.global_position.y = world.height_at(player.global_position.x, player.global_position.z) + 0.15
	player.velocity = Vector3.ZERO
	world.clear_capture_camp_corridor(player.global_position)
	player.import_inventory({
		"stone_axe": 1, "hammer": 1, "wood": 18, "stone": 8,
		"mushroom": 2, "meat": 1,
	})
	player.import_foods([
		{"id": "mushroom", "time": 240.0},
		{"id": "meat", "time": 300.0},
	])
	player.hp = floorf(player.max_hp)
	player.stamina = floorf(player.max_stamina)
	player.stats_changed.emit()
	var placements := [
		["floor", Vector3(-1.25, 0, 5.7), 0.0],
		["floor", Vector3(1.25, 0, 5.7), 0.0],
		["campfire", CAPTURE_CAMPFIRE_POSITION, 0.0],
		["workbench", CAPTURE_WORKBENCH_POSITION, -0.18],
		["wall", Vector3(-3.15, 0, 6.7), PI * 0.5],
		["wall", Vector3(3.15, 0, 6.7), PI * 0.5],
	]
	for entry: Array in placements:
		var position: Vector3 = entry[1]
		position.y = world.height_at(position.x, position.z)
		building_system.create_piece(str(entry[0]), Transform3D(Basis(Vector3.UP, float(entry[2])), position))
	if world.altar != null:
		var altar_position := CAPTURE_ALTAR_POSITION
		altar_position.y = world.height_at(altar_position.x, altar_position.z)
		world.altar.global_position = altar_position
		world.altar.awakened = false
	var staged_enemy_position := CAPTURE_ENEMY_POSITION
	staged_enemy_position.y = world.height_at(staged_enemy_position.x, staged_enemy_position.z) + 0.1
	spawn_enemy(staged_enemy_position, false, true)
	player.visual_root.rotation.y = PI
	player.camera_yaw = PI
	player.camera_pitch = -0.16
	player.camera_pivot.rotation = Vector3(player.camera_pitch, player.camera_yaw, 0)
	player.spring_arm.spring_length = 6.2
	_update_day_display(true)
	refresh_objective()
	capture_state_ready = _capture_runtime_state_valid()


func _capture_contract_valid() -> bool:
	var constants_valid := (
		CAPTURE_OBJECTIVE_STEP == 4
		and str(OBJECTIVES[CAPTURE_OBJECTIVE_STEP]["title"]) == "밤의 이빨"
		and CAPTURE_CAMPFIRE_POSITION.z >= CAPTURE_CAMP_Z_RANGE.x
		and CAPTURE_WORKBENCH_POSITION.z <= CAPTURE_CAMP_Z_RANGE.y
		and CAPTURE_ENEMY_POSITION.z > CAPTURE_CAMP_Z_RANGE.y
		and CAPTURE_ALTAR_POSITION.x < 0.0
		and CAPTURE_ALTAR_POSITION.z > CAPTURE_CAMP_Z_RANGE.y
	)
	if not constants_valid or not capture_mode:
		return constants_valid
	return capture_state_ready and _capture_runtime_state_valid()


func _capture_runtime_state_valid() -> bool:
	var food_ids: Array[String] = []
	for food: Dictionary in player.food_slots:
		food_ids.append(str(food.get("id", "")))
	var staged_enemy_found := false
	for actor in actors.get_children():
		if bool(actor.get("staged_for_capture")):
			staged_enemy_found = true
			break
	var placed: Array[String] = building_system.placed_kinds()
	return (
		objective_step == CAPTURE_OBJECTIVE_STEP
		and tree_felled
		and regular_kills == 0
		and player.item_count("trophy") == 0
		and "mushroom" in food_ids
		and "meat" in food_ids
		and "campfire" in placed
		and "workbench" in placed
		and staged_enemy_found
	)


func _capture_after_frames() -> void:
	if not _capture_contract_valid():
		push_error("[CAPTURE] 연출 상태 계약을 충족하지 못했습니다.")
		get_tree().quit(4)
		return
	if not capture_path.is_absolute_path():
		push_error("[CAPTURE] --capture 경로는 절대 경로여야 합니다: %s" % capture_path)
		get_tree().quit(2)
		return
	for frame in range(120):
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(capture_path)
	if error == OK:
		print("[CAPTURE] SUCCESS: %s" % capture_path)
		get_tree().quit(0)
	else:
		push_error("[CAPTURE] PNG 저장 실패 (%d): %s" % [error, capture_path])
		get_tree().quit(3)


func _smoke_raid_completed_gate() -> bool:
	var previous_started := raid_started
	var previous_active := raid_active
	var previous_completed := raid_completed
	var previous_boss_active := boss_active
	raid_started = false
	raid_active = false
	raid_completed = true
	boss_active = false
	var blocked := not _can_start_night_raid()
	raid_started = previous_started
	raid_active = previous_active
	raid_completed = previous_completed
	boss_active = previous_boss_active
	return blocked


func _run_smoke() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	var visual_mode: String = player.get_character_visual_mode()
	var visual_contract: bool = player.has_valid_character_visual() and visual_mode in ["animated_glb", "procedural_fallback"]
	if visual_mode == "animated_glb":
		visual_contract = visual_contract and player.is_glb_idle_playing()
	var tree_count := 0
	for resource in world.resources_root.get_children():
		if resource.has_method("get_prompt") and str(resource.get_prompt()) == "돌도끼로 채집":
			tree_count += 1
	var checks: Dictionary = {
		"game_scene": has_node("World") and has_node("Player") and has_node("HUD"),
		"terrain": world.terrain_ready and world.has_node("CoastalTerrain") and world.has_node("TerrainCollision"),
		"grass_silhouette": world.grass_silhouette_contract_valid(),
		"sky_depth": world.sky_depth_contract_valid(),
		"compatibility_renderer": RenderingServer.get_current_rendering_method() == "gl_compatibility",
		"forest_population": tree_count >= 36 and tree_count <= 44 and world.foliage_root.get_child_count() >= 240 and world.foliage_root.get_child_count() <= 320,
		"packed_scenes": RESOURCE_SCENE != null and ENEMY_SCENE != null and ALTAR_SCENE != null,
		"player_loop": player.HOTBAR.size() == 5 and player.FOOD_DATA.size() == 3,
		"player_visual": visual_contract,
		"craft_data": RECIPES.size() == 2,
		"build_data": building_system.PIECE_DATA.size() == 4,
		"sfx_bank": feedback.sfx_contract_valid(),
		"objectives": OBJECTIVES.size() == 8,
		"capture_contract": _capture_contract_valid(),
		"raid_completed_gate": _smoke_raid_completed_gate(),
		"save_contract": save_system.smoke_contract(),
		"altar": world.altar != null and is_instance_valid(world.altar),
	}
	var failed: Array[String] = []
	for check_name: String in checks:
		if not bool(checks[check_name]):
			failed.append(check_name)
	if not failed.is_empty():
		push_error("[SMOKE] FAILED: %s" % ", ".join(failed))
		get_tree().quit(1)
		return
	print("[SMOKE] SUCCESS: game/player/world/triangle-grass/cloud-depth/resources/crafting/building/SFX/AI/objectives/save ready; renderer=%s; visual=%s" % [RenderingServer.get_current_rendering_method(), visual_mode])
	get_tree().quit(0)
