extends Node
## 저장/불러오기. 오토로드 이름: SaveSystem
## user:// 아래에 JSON 으로 저장한다. 월드는 시드로 재생성되므로 변경분만 기록한다.

const DIR := "user://saves"
const SLOT := "world1"
const VERSION := 1
const MAX_COLLECTION := 200000
const MAX_STATS_ABS := 1.0e15
const MAX_COORD_ABS := 1000000000
const MAX_FLOAT_ABS := 1.0e15
const REQUIRED_SAVE_FIELDS := ["version", "world_id", "local_player_id", "seed", "world_name",
	"time", "day", "bosses", "powers", "active_power", "stats", "player", "spawn",
	"removed", "terrain", "discovered", "pieces", "tombs"]
const LEGACY_SAVE_FIELDS := ["version", "seed", "world_name", "time", "day", "bosses", "powers",
	"active_power", "stats", "player", "spawn", "removed", "terrain", "discovered",
	"pieces", "tombs"]

signal saved()
signal loaded()

var last_error: String = ""
var _json := JsonStore.new()
var _identity := IdentityStore.new()

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var identity := _identity.load_or_create()
	if bool(identity.get("ok", false)):
		GameState.local_player_id = str(identity["local_player_id"])
	else:
		last_error = str(identity.get("error", "identity initialization failed"))

func path(slot: String = SLOT) -> String:
	return "%s/%s.json" % [DIR, SLOT] if slot == SLOT else ""

func has_save(slot: String = SLOT) -> bool:
	var save_path := path(slot)
	return save_path != "" and (FileAccess.file_exists(save_path) \
		or FileAccess.file_exists(save_path + ".bak") \
		or FileAccess.file_exists(save_path + ".previous") \
		or FileAccess.file_exists(save_path + ".tmp"))

func save_game(player, build_system, slot: String = SLOT) -> bool:
	last_error = ""
	if slot != SLOT:
		return _save_failure("unsupported save slot")
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return _save_failure("invalid player")
	if build_system == null or not is_instance_valid(build_system) \
			or not build_system.is_inside_tree():
		return _save_failure("invalid build system")
	var identity_result := _load_identity_id()
	if not bool(identity_result.get("ok", false)) or not IdentityStore.is_uuid(GameState.world_id):
		return _save_failure("durable identity unavailable")
	var local_player_id := str(identity_result["local_player_id"])
	var document := {
		"version": VERSION,
		"world_id": GameState.world_id,
		"local_player_id": local_player_id,
		"seed": GameState.world_seed,
		"world_name": GameState.world_name,
		"time": GameState.time_of_day,
		"day": GameState.day,
		"bosses": GameState.bosses_killed.duplicate(true),
		"powers": GameState.known_powers.duplicate(true),
		"active_power": GameState.active_power,
		"stats": GameState.stats.duplicate(true),
		"player": player.to_dict(),
		"spawn": _v3_arr(player.get_meta("spawn_point", Vector3.ZERO)),
		"removed": _pack_removed(),
		"terrain": GameState.gen.mods_to_array() if GameState.gen != null else [],
		"discovered": _pack_discovered(),
		"pieces": build_system.to_dict(),
		"tombs": _pack_tombs(player),
	}
	var validation := _validate_save_complete(document)
	if not bool(validation.get("ok", false)):
		return _save_failure(str(validation.get("error", "save validation failed")))
	if not _json.save_document(path(slot), document,
			_validate_save_for_identity.bind(local_player_id)):
		return _save_failure(_json.last_error)
	GameState.local_player_id = local_player_id
	GameState.msg(tr("MSG_SAVED"))
	Sfx.play("click", -12.0)
	saved.emit()
	return true

func load_game(player, build_system, slot: String = SLOT) -> bool:
	last_error = ""
	if slot != SLOT:
		return _load_failure("unsupported save slot")
	if not has_save(slot):
		last_error = "save not found"
		GameState.msg(tr("MSG_NO_SAVE"))
		return false
	var identity_result := _load_identity_id()
	if not bool(identity_result.get("ok", false)):
		return _load_failure(str(identity_result.get("error", "durable identity unavailable")))
	var local_player_id := str(identity_result["local_player_id"])
	var identity_validator := _validate_save_for_identity.bind(local_player_id)
	var loaded_result := _json.load_document(path(slot), identity_validator)
	if not bool(loaded_result.get("ok", false)):
		return _load_failure(str(loaded_result.get("error", "save is corrupt")))
	var migrated := _migrate_save(loaded_result["value"], slot, local_player_id)
	if not bool(migrated.get("ok", false)):
		return _load_failure(str(migrated.get("error", "save migration failed")))
	var document: Dictionary = migrated["value"]
	var candidate_result := _build_candidate(document)
	if not bool(candidate_result.get("ok", false)):
		return _load_failure(str(candidate_result.get("error", "save validation failed")))
	var candidate: Dictionary = candidate_result["value"]
	var preflight := _preflight_apply(player, build_system)
	if not bool(preflight.get("ok", false)):
		return _load_failure(str(preflight.get("error", "load preflight failed")))
	var next_gen := WorldGen.new(int(candidate["world"]["seed"]))
	next_gen.mods_from_array(candidate["terrain"])
	candidate["world"]["gen"] = next_gen

	var snapshot_result := _snapshot_live_state(player, build_system)
	if not bool(snapshot_result.get("ok", false)):
		return _load_failure(str(snapshot_result.get("error", "live snapshot failed")))
	var snapshot: Dictionary = snapshot_result["value"]
	var apply_result := _apply_candidate(candidate, player, build_system)
	if not bool(apply_result.get("ok", false)):
		var apply_error := str(apply_result.get("error", "load apply failed"))
		if not _restore_live_state(snapshot, player, build_system):
			return _load_failure(apply_error + "; live rollback failed")
		return _load_failure(apply_error)
	if bool(migrated.get("changed", false)):
		if not _json.save_document(path(slot), document, identity_validator):
			var persistence_error := _json.last_error
			if not _restore_live_state(snapshot, player, build_system):
				return _load_failure("migration persistence failed: " + persistence_error \
					+ "; live rollback failed")
			return _load_failure("migration persistence failed: " + persistence_error)
	GameState.msg(tr("MSG_LOADED"))
	loaded.emit()
	return true

func delete_save(slot: String = SLOT) -> void:
	if slot != SLOT:
		last_error = "unsupported save slot"
		return
	for suffix in ["", ".tmp", ".bak", ".bak.old", ".previous", ".invalid"]:
		var file_path: String = path(slot) + suffix
		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)

func _load_identity_id() -> Dictionary:
	var identity := _identity.load_or_create()
	if not bool(identity.get("ok", false)):
		return {"ok": false, "error": str(identity.get("error", "identity unavailable"))}
	var local_player_id := str(identity["local_player_id"])
	if IdentityStore.is_uuid(GameState.local_player_id) \
			and GameState.local_player_id != local_player_id:
		return {"ok": false, "error": "live local identity mismatch"}
	return {"ok": true, "local_player_id": local_player_id}

func _migrate_save(source: Dictionary, slot: String, local_player_id: String) -> Dictionary:
	var source_validation := _validate_save(source)
	if not bool(source_validation.get("ok", false)):
		return source_validation
	var document := source.duplicate(true)
	var changed := false
	if not document.has("world_id"):
		document["world_id"] = IdentityStore.legacy_uuid(
			"legacy-world/%s:%d" % [slot, int(document["seed"])])
		document["local_player_id"] = local_player_id
		changed = true
	elif not document.has("local_player_id"):
		return _invalid("malformed durable save identity")
	if str(document["local_player_id"]) != local_player_id:
		return _invalid("save belongs to a different local player")
	var validation := _validate_save_complete(document)
	if not bool(validation.get("ok", false)):
		return validation
	return {"ok": true, "value": document, "changed": changed}

func _preflight_apply(player, build_system) -> Dictionary:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return _invalid("invalid player")
	if build_system == null or not is_instance_valid(build_system) \
			or not build_system.is_inside_tree():
		return _invalid("invalid build system")
	if Net.is_online:
		return _invalid("cannot load while online")
	var tree: SceneTree = player.get_tree()
	if tree == null or tree.current_scene == null or build_system.get_tree() != tree:
		return _invalid("load owners are not in the active scene")
	return {"ok": true}

func _apply_candidate(candidate: Dictionary, player, build_system) -> Dictionary:
	player.from_dict(candidate["player"])
	player.set_meta("spawn_point", candidate["spawn"])
	if not bool(build_system.from_dict(candidate["pieces"])):
		return _invalid("build system rejected load")
	if not _replace_tombs(candidate["tombs"], player):
		return _invalid("tombstone apply rejected")
	if not GameState.apply_loaded_world(candidate["world"]):
		return _invalid("world apply rejected")
	return {"ok": true}

func _build_candidate(document: Dictionary) -> Dictionary:
	var removed_result := _decode_removed(document["removed"])
	if not bool(removed_result.get("ok", false)):
		return removed_result
	var discovered_result := _decode_discovered(document["discovered"])
	if not bool(discovered_result.get("ok", false)):
		return discovered_result
	return {"ok": true, "value": {
		"world": {
			"seed": int(document["seed"]),
			"world_name": str(document["world_name"]),
			"world_id": str(document["world_id"]),
			"local_player_id": str(document["local_player_id"]),
			"time": float(document["time"]),
			"day": int(document["day"]),
			"bosses": _str_keys(document["bosses"]),
			"powers": _str_keys(document["powers"]),
			"active_power": str(document["active_power"]),
			"stats": document["stats"].duplicate(true),
			"removed": removed_result["value"],
			"discovered": discovered_result["value"],
		},
		"terrain": document["terrain"].duplicate(true),
		"player": document["player"].duplicate(true),
		"spawn": _array_to_v3(document["spawn"]),
		"pieces": document["pieces"].duplicate(true),
		"tombs": document["tombs"].duplicate(true),
	}}

func _validate_save(document: Dictionary) -> Dictionary:
	return _validate_save_document(document, false)

func _validate_save_complete(document: Dictionary) -> Dictionary:
	return _validate_save_document(document, true)

func _validate_save_for_identity(document: Dictionary, local_player_id: String) -> Dictionary:
	# Ownership is a selection boundary, not merely a schema field.  Detect an
	# explicit foreign owner before considering an ownerless backup generation.
	if document.has("local_player_id") and str(document["local_player_id"]) != local_player_id:
		return {"ok": false, "error": "save belongs to a different local player", "terminal": true}
	var validation := _validate_save(document)
	if not bool(validation.get("ok", false)):
		return validation
	return {"ok": true}

func _validate_save_document(document: Dictionary, require_ids: bool) -> Dictionary:
	if not _is_integer(document.get("version")):
		return _invalid("save version is missing")
	if int(document["version"]) != VERSION:
		return {"ok": false, "error": "unsupported save version", "terminal": true}
	var has_world_id := document.has("world_id")
	var has_local_player_id := document.has("local_player_id")
	if has_world_id != has_local_player_id:
		return _invalid("malformed durable save identity")
	var expected: Array = REQUIRED_SAVE_FIELDS if has_world_id else LEGACY_SAVE_FIELDS
	if require_ids and not has_world_id:
		return _invalid("durable save identity is missing")
	if document.size() != expected.size():
		return _invalid("invalid save schema")
	for key in expected:
		if not document.has(key):
			return _invalid("missing save field: " + key)
	for key in document:
		if not key in expected:
			return _invalid("unknown save field: " + str(key))
	if has_world_id and (not IdentityStore.is_uuid(document["world_id"]) \
			or not IdentityStore.is_uuid(document["local_player_id"])):
		return _invalid("invalid durable save identity")
	if not _bounded_integer(document.get("seed"), -9007199254740991, 9007199254740991):
		return _invalid("invalid world seed")
	if not (document.get("world_name") is String) or document["world_name"].length() > 256:
		return _invalid("invalid world name")
	if not _bounded_number(document.get("time"), 0.0, 0.9999999999999999):
		return _invalid("invalid world time")
	if not _bounded_integer(document.get("day"), 1, MAX_COORD_ABS):
		return _invalid("invalid world day")
	for field in ["bosses", "powers", "stats", "player", "removed"]:
		if not (document.get(field) is Dictionary):
			return _invalid("invalid " + field)
	for field in ["spawn", "terrain", "discovered", "pieces", "tombs"]:
		if not (document.get(field) is Array) or document[field].size() > MAX_COLLECTION:
			return _invalid("invalid " + field)
	if not (document.get("active_power") is String) or document["active_power"].length() > 128:
		return _invalid("invalid active power")
	if not _valid_flag_map(document["bosses"]) or not _valid_flag_map(document["powers"]):
		return _invalid("invalid progression flags")
	if not _valid_stats(document["stats"]):
		return _invalid("invalid statistics")
	if not _valid_v3(document["spawn"]):
		return _invalid("invalid spawn")
	if not _valid_player(document["player"]):
		return _invalid("invalid player")
	if not _valid_removed(document["removed"]):
		return _invalid("invalid removed props")
	if not _valid_terrain(document["terrain"]):
		return _invalid("invalid terrain")
	if not _valid_discovered(document["discovered"]):
		return _invalid("invalid discovered tiles")
	if not _valid_pieces(document["pieces"]):
		return _invalid("invalid build pieces")
	if not _valid_tombs(document["tombs"]):
		return _invalid("invalid tombstones")
	return {"ok": true}

func _valid_flag_map(flags: Dictionary) -> bool:
	if flags.size() > 1024:
		return false
	for key in flags:
		if not (key is String) or key.is_empty() or key.length() > 128 \
				or not (flags[key] is bool) or not bool(flags[key]):
			return false
	return true

func _valid_stats(values: Dictionary) -> bool:
	if values.size() != GameState.stats.size():
		return false
	for key in GameState.stats:
		if not values.has(key) or not _bounded_number(values[key], 0.0, MAX_STATS_ABS):
			return false
		if key != "distance" and not _is_integer(values[key]):
			return false
	return true

func _valid_player(value: Dictionary) -> bool:
	var required := ["pos", "yaw", "inv", "stats"]
	var optional := ["starter_grant_version", "starter_provenance", "rt1_rested_applied"]
	if value.size() < required.size() or value.size() > required.size() + optional.size():
		return false
	for key in required:
		if not value.has(key):
			return false
	for key in value:
		if not key in required and not key in optional:
			return false
	if not _valid_v3(value["pos"]) or not _bounded_number(value["yaw"], -MAX_FLOAT_ABS, MAX_FLOAT_ABS):
		return false
	if not _valid_inventory(value["inv"]) or not (value["stats"] is Dictionary):
		return false
	if value.has("starter_grant_version") and not _bounded_integer(
			value["starter_grant_version"], 0, 1000000):
		return false
	if value.has("starter_provenance") and not _valid_starter_provenance(
			value["starter_provenance"]):
		return false
	if value.has("rt1_rested_applied") and not (value["rt1_rested_applied"] is bool):
		return false
	return _valid_player_stats(value["stats"])

func _valid_starter_provenance(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	if value.is_empty():
		return true
	var legacy_keys := ["source", "contents"]
	var durable_keys := ["source", "contents", "world_id", "local_player_id"]
	if value.size() != legacy_keys.size() and value.size() != durable_keys.size():
		return false
	for key in value:
		if key not in durable_keys:
			return false
	for key in legacy_keys:
		if not value.has(key):
			return false
	if value.size() == durable_keys.size() and (not value.has("world_id") \
			or not value.has("local_player_id")):
		return false
	if not (value.get("source") is String) or value["source"].is_empty() \
			or value["source"].length() > 128 or not (value.get("contents") is Dictionary):
		return false
	if value.has("world_id") and (not IdentityStore.is_uuid(str(value["world_id"])) \
			or not IdentityStore.is_uuid(str(value["local_player_id"]))):
		return false
	var contents: Dictionary = value["contents"]
	if contents.size() > 64:
		return false
	for item_id in contents:
		if not (item_id is String) or item_id.is_empty() or item_id.length() > 128 \
				or not ItemDB.has_item(item_id) or not _bounded_integer(contents[item_id], 1, 1000000):
			return false
	return true

func _valid_removed(value: Dictionary) -> bool:
	if value.size() > MAX_COLLECTION:
		return false
	for key in value:
		if not (key is String) or key.length() > 64:
			return false
		var parts: PackedStringArray = key.split(",")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int() \
				or not _bounded_integer(int(parts[0]), -MAX_COORD_ABS, MAX_COORD_ABS) \
				or not _bounded_integer(int(parts[1]), -MAX_COORD_ABS, MAX_COORD_ABS):
			return false
		if not (value[key] is Array) or value[key].size() > MAX_COLLECTION:
			return false
		var seen := {}
		for index in value[key]:
			if not _bounded_integer(index, 0, MAX_COLLECTION) or seen.has(int(index)):
				return false
			seen[int(index)] = true
	return true

func _valid_terrain(values: Array) -> bool:
	var seen := {}
	for entry in values:
		if not (entry is Array) or entry.size() != 3 \
				or not _bounded_integer(entry[0], -MAX_COORD_ABS, MAX_COORD_ABS) \
				or not _bounded_integer(entry[1], -MAX_COORD_ABS, MAX_COORD_ABS) \
				or not _bounded_number(entry[2], -MAX_FLOAT_ABS, MAX_FLOAT_ABS):
			return false
		var key := "%d,%d" % [int(entry[0]), int(entry[1])]
		if seen.has(key):
			return false
		seen[key] = true
	return true

func _valid_discovered(values: Array) -> bool:
	var seen := {}
	for entry in values:
		if not (entry is Array) or entry.size() != 2 \
				or not _bounded_integer(entry[0], -MAX_COORD_ABS, MAX_COORD_ABS) \
				or not _bounded_integer(entry[1], -MAX_COORD_ABS, MAX_COORD_ABS):
			return false
		var key := "%d,%d" % [int(entry[0]), int(entry[1])]
		if seen.has(key):
			return false
		seen[key] = true
	return true

func _valid_pieces(values: Array) -> bool:
	for piece in values:
		if not (piece is Dictionary) or piece.size() < 4 or piece.size() > 9 \
				or not (piece.get("id") is String) or piece["id"].is_empty() \
				or piece["id"].length() > 128 or RecipeDB.piece(piece["id"]).is_empty() \
				or not _valid_v3(piece.get("p")) \
				or not _bounded_number(piece.get("y"), -MAX_FLOAT_ABS, MAX_FLOAT_ABS) \
				or not _bounded_number(piece.get("hp"), 0.0, MAX_FLOAT_ABS):
			return false
		for required in ["id", "p", "y", "hp"]:
			if not piece.has(required):
				return false
		for key in piece:
			if not key in ["id", "p", "y", "hp", "owner_id", "inv", "smelt", "fuel", "grown"]:
				return false
		if piece.has("owner_id") and not IdentityStore.is_uuid(piece["owner_id"]):
			return false
		if piece.has("inv") and not _valid_inventory(piece["inv"]):
			return false
		if piece.has("smelt"):
			if not (piece["smelt"] is Array) or piece["smelt"].size() > 10:
				return false
			for item_id in piece["smelt"]:
				if not (item_id is String) or item_id.is_empty() or item_id.length() > 128 \
						or not ItemDB.has_item(item_id):
					return false
		if piece.has("fuel") and not _bounded_integer(piece["fuel"], 0, 20):
			return false
		if piece.has("grown") and not (piece["grown"] is bool):
			return false
	return true

func _valid_tombs(values: Array) -> bool:
	for tomb in values:
		if not (tomb is Dictionary) or tomb.size() != 3 \
				or not tomb.has("pos") or not tomb.has("inv") or not tomb.has("tomb") \
				or not (tomb["tomb"] is bool) or not bool(tomb["tomb"]) \
				or not _valid_v3(tomb["pos"]) or not _valid_inventory(tomb["inv"]):
			return false
	return true

func _valid_player_stats(stats: Dictionary) -> bool:
	if stats.size() != 5 or not stats.has("hp") or not stats.has("stamina") \
			or not stats.has("foods") or not stats.has("skills") or not stats.has("status") \
			or not _bounded_number(stats["hp"], 0.0, MAX_FLOAT_ABS) \
			or not _bounded_number(stats["stamina"], 0.0, MAX_FLOAT_ABS) \
			or not (stats["foods"] is Array) or stats["foods"].size() > 64 \
			or not (stats["skills"] is Dictionary) or stats["skills"].size() > 128 \
			or not (stats["status"] is Dictionary) or stats["status"].size() > 128:
		return false
	for food in stats["foods"]:
		if not (food is Dictionary) or food.size() < 6 or food.size() > 7 \
				or not (food.get("id") is String) or food["id"].is_empty() \
				or food["id"].length() > 128 or not ItemDB.has_item(food["id"]):
			return false
		for key in food:
			if not key in ["id", "t", "dur", "hp", "sp", "reg", "eitr"]:
				return false
		for field in ["t", "dur", "hp", "sp", "reg"]:
			if not food.has(field) or not _bounded_number(food[field], 0.0, MAX_FLOAT_ABS):
				return false
		if float(food["dur"]) <= 0.0 or float(food["t"]) > float(food["dur"]) \
				or food.has("eitr") and not _bounded_number(food["eitr"], 0.0, MAX_FLOAT_ABS):
			return false
	var skill_ids := Const.Skill.values()
	for key in stats["skills"]:
		var key_text := str(key)
		if not key_text.is_valid_int() or int(key_text) not in skill_ids:
			return false
		var skill = stats["skills"][key]
		if not (skill is Dictionary) or skill.size() != 2 or not skill.has("lvl") \
				or not skill.has("xp") or not _bounded_number(skill["lvl"], 0.0, MAX_FLOAT_ABS) \
				or not _bounded_number(skill["xp"], 0.0, MAX_FLOAT_ABS):
			return false
	var allowed_status_fields := ["t", "comfort", "dps", "nonlethal"]
	for key in stats["status"]:
		if not (key is String) or key.is_empty() or key.length() > 128 \
				or not (stats["status"][key] is Dictionary):
			return false
		var state: Dictionary = stats["status"][key]
		if state.is_empty() or state.size() > allowed_status_fields.size() or not state.has("t") \
				or not _bounded_number(state["t"], 0.0, MAX_FLOAT_ABS):
			return false
		for field in state:
			if not field in allowed_status_fields:
				return false
		if state.has("comfort") and not _bounded_integer(state["comfort"], 0, 1000000):
			return false
		if state.has("dps") and not _bounded_number(state["dps"], 0.0, MAX_FLOAT_ABS):
			return false
		if state.has("nonlethal") and not (state["nonlethal"] is bool):
			return false
	return true

func _valid_item_slot(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	if value.is_empty():
		return true
	if value.size() < 2 or value.size() > 3 or not value.has("id") or not value.has("amount"):
		return false
	for key in value:
		if not key in ["id", "amount", "quality"]:
			return false
	return value["id"] is String and not value["id"].is_empty() \
		and value["id"].length() <= 128 and ItemDB.has_item(value["id"]) \
		and _bounded_integer(value["amount"], 1, 1000000) \
		and (not value.has("quality") or _bounded_integer(value["quality"], 1, 1000000))

func _valid_inventory(value: Variant) -> bool:
	if not (value is Dictionary) or value.size() != 4 or not value.has("cols") \
			or not value.has("rows") or not value.has("slots") or not value.has("equipped") \
			or not _bounded_integer(value["cols"], 1, 64) \
			or not _bounded_integer(value["rows"], 1, 64):
		return false
	var cols := int(value["cols"])
	var rows := int(value["rows"])
	if not (value["slots"] is Array) or value["slots"].size() != cols * rows \
			or not (value["equipped"] is Dictionary):
		return false
	for item in value["slots"]:
		if not _valid_item_slot(item):
			return false
	var equipped: Dictionary = value["equipped"]
	var equipment_slots := ["head", "chest", "legs", "cape", "right", "left", "ammo"]
	if equipped.size() != equipment_slots.size():
		return false
	for key in equipment_slots:
		if not equipped.has(key) or not _is_integer(equipped[key]):
			return false
		var index := int(equipped[key])
		if index < -1 or index >= value["slots"].size():
			return false
		if index >= 0:
			var equipped_item = value["slots"][index]
			if not (equipped_item is Dictionary) or equipped_item.is_empty():
				return false
	return true


func _decode_removed(value: Dictionary) -> Dictionary:
	var out := {}
	for key in value:
		var parts := str(key).split(",")
		var chunk := Vector2i(int(parts[0]), int(parts[1]))
		var indices := {}
		for index in value[key]:
			indices[int(index)] = true
		out[chunk] = indices
	return {"ok": true, "value": out}

func _decode_discovered(value: Array) -> Dictionary:
	var out := {}
	for entry in value:
		out[Vector2i(int(entry[0]), int(entry[1]))] = true
	return {"ok": true, "value": out}

func _snapshot_live_state(player, build_system) -> Dictionary:
	var player_state = player.to_dict()
	var pieces_state = build_system.to_dict()
	var tombs_state := _pack_tombs(player)
	var spawn_state = player.get_meta("spawn_point", Vector3.ZERO)
	if not (player_state is Dictionary) or not _valid_player(player_state) \
			or not (pieces_state is Array) or not _valid_pieces(pieces_state) \
			or not _valid_tombs(tombs_state) or not (spawn_state is Vector3) \
			or not _valid_v3(_v3_arr(spawn_state)):
		return _invalid("live state cannot be snapshotted safely")
	return {"ok": true, "value": {
		"world": GameState.snapshot_loaded_world_state(),
		"player": player_state.duplicate(true),
		"spawn": spawn_state,
		"pieces": pieces_state.duplicate(true),
		"tombs": tombs_state.duplicate(true),
	}}

func _restore_live_state(snapshot: Dictionary, player, build_system) -> bool:
	var restored := true
	player.from_dict(snapshot["player"])
	player.set_meta("spawn_point", snapshot["spawn"])
	if not bool(build_system.from_dict(snapshot["pieces"])):
		restored = false
	if not _replace_tombs(snapshot["tombs"], player):
		restored = false
	if not GameState.restore_loaded_world_state(snapshot["world"]):
		restored = false
	return restored

func _save_failure(error: String) -> bool:
	last_error = error
	GameState.msg(tr("MSG_SAVE_FAILED"))
	return false

func _load_failure(error: String) -> bool:
	last_error = error
	GameState.msg(tr("MSG_SAVE_CORRUPT"))
	return false

func _invalid(error: String) -> Dictionary:
	return {"ok": false, "error": error}

static func _v3_arr(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

static func _array_to_v3(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

static func _valid_v3(value: Variant) -> bool:
	return value is Array and value.size() == 3 \
		and _bounded_number(value[0], -MAX_FLOAT_ABS, MAX_FLOAT_ABS) \
		and _bounded_number(value[1], -MAX_FLOAT_ABS, MAX_FLOAT_ABS) \
		and _bounded_number(value[2], -MAX_FLOAT_ABS, MAX_FLOAT_ABS)

static func _is_finite_number(value: Variant) -> bool:
	return (value is int) or (value is float and is_finite(value))

static func _is_integer(value: Variant) -> bool:
	return (value is int) or (value is float and is_finite(value) and value == floor(value))

static func _bounded_number(value: Variant, minimum: float, maximum: float) -> bool:
	return _is_finite_number(value) and float(value) >= minimum and float(value) <= maximum

static func _bounded_integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _is_integer(value) and int(value) >= minimum and int(value) <= maximum

static func _str_keys(value: Variant) -> Dictionary:
	var out := {}
	if value is Dictionary:
		for key in value:
			out[str(key)] = value[key]
	return out

func _pack_removed() -> Dictionary:
	var out := {}
	for key in GameState.removed_props:
		var indices: Array = []
		for index in GameState.removed_props[key]:
			indices.append(int(index))
		out["%d,%d" % [key.x, key.y]] = indices
	return out

func _pack_discovered() -> Array:
	var out: Array = []
	for key in GameState.discovered:
		out.append([key.x, key.y])
	return out

func _pack_tombs(player) -> Array:
	var out: Array = []
	if player == null or not player.is_inside_tree():
		return out
	for tomb in player.get_tree().get_nodes_in_group("tombstone"):
		if is_instance_valid(tomb):
			out.append(tomb.to_dict())
	return out

func _replace_tombs(values: Array, player) -> bool:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return false
	var tree: SceneTree = player.get_tree()
	if tree == null or tree.current_scene == null:
		return false
	for tomb in tree.get_nodes_in_group("tombstone"):
		if is_instance_valid(tomb):
			tomb.queue_free()
	for value in values:
		var tomb := Tombstone.new()
		tree.current_scene.add_child(tomb)
		tomb.global_position = _array_to_v3(value["pos"])
		tomb.from_dict(value)
	return true
