extends Node

const SAVE_VERSION := 2
const SAVE_PATH := "user://coastal_survival_v2.json"

var game: Node


func setup(owner_game: Node) -> void:
	game = owner_game


func save_game() -> bool:
	if game == null or game.player == null:
		return false
	var player_position: Vector3 = game.player.global_position
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"player_position": [player_position.x, player_position.y, player_position.z],
		"inventory": game.player.export_inventory(),
		"food_slots": game.player.serialize_foods(),
		"objective_step": game.objective_step,
		"world_time": game.world_time,
		"raid_completed": game.raid_completed,
		"buildings": game.building_system.serialize_buildings(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		game.notify("저장 파일을 열 수 없습니다.", Color(0.95, 0.42, 0.36))
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	game.notify("세계가 저장되었습니다.  [F5]", Color(0.65, 0.86, 0.68))
	return true


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		game.notify("불러올 저장 파일이 없습니다.", Color(0.95, 0.72, 0.38))
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		game.notify("저장 파일을 읽을 수 없습니다.", Color(0.95, 0.42, 0.36))
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		game.notify("저장 데이터가 손상되었습니다.", Color(0.95, 0.42, 0.36))
		return false
	var data: Dictionary = parsed
	if int(data.get("version", -1)) != SAVE_VERSION:
		game.notify("지원하지 않는 저장 버전입니다.", Color(0.95, 0.42, 0.36))
		return false

	game.prepare_for_load()
	var position_data: Array = data.get("player_position", [])
	if position_data.size() == 3:
		game.player.global_position = Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
		game.player.velocity = Vector3.ZERO
	game.player.import_inventory(data.get("inventory", {}))
	game.player.import_foods(data.get("food_slots", []))
	game.objective_step = clampi(int(data.get("objective_step", 0)), 0, game.OBJECTIVES.size() - 1)
	game.world_time = float(data.get("world_time", 0.28))
	game.raid_completed = bool(data.get("raid_completed", false))
	game.building_system.clear_buildings()
	game.building_system.restore_buildings(data.get("buildings", []))
	game.apply_loaded_objective_state()
	game.replenish_loaded_starter_pickups()
	game.refresh_objective()
	game.notify("저장된 해안 세계를 불러왔습니다.  [F9]", Color(0.65, 0.82, 0.96))
	return true


func smoke_contract() -> bool:
	return SAVE_VERSION == 2 and SAVE_PATH.ends_with("coastal_survival_v2.json")
