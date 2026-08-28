class_name OnboardingStore
extends RefCounted
## Private local onboarding progress keyed by durable world and local-player IDs.

const PATH := "user://onboarding.json"
const VERSION := 1
const OBJECTIVE_VERSION := 1
const MAX_RECORDS := 64
const MAX_IDS := 512
const MAX_CURSOR := 1000000
const MAX_ID_LENGTH := 128

var last_error: String = ""
var _json := JsonStore.new()

func load(world_id: String, local_player_id: String) -> Dictionary:
	last_error = ""
	if not IdentityStore.is_uuid(world_id) or not IdentityStore.is_uuid(local_player_id):
		last_error = "invalid onboarding identity"
		return {"ok": false, "error": last_error}
	var loaded := _load_root()
	if not bool(loaded.get("ok", false)):
		return loaded
	var records: Dictionary = loaded["value"]["records"]
	var key := record_key(world_id, local_player_id)
	if not records.has(key):
		return {"ok": true, "progress": empty_progress()}
	var progress: Dictionary = (records[key] as Dictionary).duplicate(true)
	progress.erase("world_id")
	progress.erase("local_player_id")
	return {"ok": true, "progress": progress}

func save(world_id: String, local_player_id: String, progress: Dictionary) -> bool:
	last_error = ""
	if not IdentityStore.is_uuid(world_id) or not IdentityStore.is_uuid(local_player_id):
		last_error = "invalid onboarding identity"
		return false
	var valid_progress := _validate_progress(progress)
	if not bool(valid_progress.get("ok", false)):
		last_error = str(valid_progress.get("error", "invalid onboarding progress"))
		return false
	var loaded := _load_root()
	if not bool(loaded.get("ok", false)):
		return false
	var root: Dictionary = loaded["value"].duplicate(true)
	var records: Dictionary = root["records"]
	var key := record_key(world_id, local_player_id)
	if not records.has(key) and records.size() >= MAX_RECORDS:
		last_error = "onboarding record limit exceeded"
		return false
	var stored := progress.duplicate(true)
	stored["world_id"] = world_id
	stored["local_player_id"] = local_player_id
	records[key] = stored
	root["records"] = records
	var ok := _json.save_document(PATH, root, _validate_root)
	if not ok:
		last_error = _json.last_error
	return ok

func clear(world_id: String, local_player_id: String) -> bool:
	last_error = ""
	if not IdentityStore.is_uuid(world_id) or not IdentityStore.is_uuid(local_player_id):
		last_error = "invalid onboarding identity"
		return false
	var loaded := _load_root()
	if not bool(loaded.get("ok", false)):
		return false
	var root: Dictionary = loaded["value"].duplicate(true)
	var records: Dictionary = root["records"]
	records.erase(record_key(world_id, local_player_id))
	root["records"] = records
	var ok := _json.save_document(PATH, root, _validate_root)
	if not ok:
		last_error = _json.last_error
	return ok

static func record_key(world_id: String, local_player_id: String) -> String:
	return world_id + "/" + local_player_id

static func empty_progress() -> Dictionary:
	return {"objective_version": OBJECTIVE_VERSION, "cursor": 0,
		"completed_ids": [], "skipped": false, "evidence_ids": []}

func _load_root() -> Dictionary:
	if not FileAccess.file_exists(PATH) and not FileAccess.file_exists(PATH + ".bak") \
			and not FileAccess.file_exists(PATH + ".previous") \
			and not FileAccess.file_exists(PATH + ".invalid") \
			and not FileAccess.file_exists(PATH + ".tmp"):
		return {"ok": true, "value": {"version": VERSION, "records": {}}}
	var loaded := _json.load_document(PATH, _validate_root)
	if not bool(loaded.get("ok", false)):
		last_error = str(loaded.get("error", "onboarding load failed"))
		return {"ok": false, "error": last_error}
	return loaded

func _validate_root(document: Dictionary) -> Dictionary:
	if not _is_integer(document.get("version")):
		return {"ok": false, "error": "onboarding version is missing"}
	if int(document["version"]) != VERSION:
		return {"ok": false, "error": "unsupported onboarding version", "terminal": true}
	if document.size() != 2 or not document.has("records"):
		return {"ok": false, "error": "invalid onboarding root schema"}
	if not (document.get("records") is Dictionary):
		return {"ok": false, "error": "onboarding records must be an object"}
	var records: Dictionary = document["records"]
	if records.size() > MAX_RECORDS:
		return {"ok": false, "error": "onboarding record limit exceeded"}
	for key in records:
		if not (key is String) or key.length() != 73 or not (records[key] is Dictionary):
			return {"ok": false, "error": "invalid onboarding record"}
		var record: Dictionary = records[key]
		if record.size() != 7 or not record.has("world_id") \
				or not record.has("local_player_id"):
			return {"ok": false, "error": "invalid onboarding record schema"}
		if record_key(str(record.get("world_id", "")),
				str(record.get("local_player_id", ""))) != key:
			return {"ok": false, "error": "onboarding record identity mismatch"}
		if not IdentityStore.is_uuid(record.get("world_id")) \
				or not IdentityStore.is_uuid(record.get("local_player_id")):
			return {"ok": false, "error": "invalid onboarding record identity"}
		var progress_valid := _validate_progress(record, true)
		if not bool(progress_valid.get("ok", false)):
			if bool(progress_valid.get("terminal", false)):
				return {"ok": false, "error": str(progress_valid.get("error",
					"unsupported objective version")), "terminal": true}
			return progress_valid
	return {"ok": true}

func _validate_progress(progress: Dictionary, stored_record: bool = false) -> Dictionary:
	if not _is_integer(progress.get("objective_version")):
		return {"ok": false, "error": "objective version is missing"}
	if int(progress["objective_version"]) != OBJECTIVE_VERSION:
		return {"ok": false, "error": "unsupported objective version", "terminal": true}
	var allowed := ["objective_version", "cursor", "completed_ids", "skipped", "evidence_ids"]
	if stored_record:
		allowed.append_array(["world_id", "local_player_id"])
	if progress.size() != allowed.size():
		return {"ok": false, "error": "invalid onboarding progress schema"}
	for key in allowed:
		if not progress.has(key):
			return {"ok": false, "error": "missing onboarding progress field"}
	for key in progress:
		if not key in allowed:
			return {"ok": false, "error": "unknown onboarding progress field"}
	if not _is_integer(progress.get("cursor")) or int(progress["cursor"]) < 0 \
			or int(progress["cursor"]) > MAX_CURSOR:
		return {"ok": false, "error": "invalid onboarding cursor"}
	if not (progress.get("skipped") is bool):
		return {"ok": false, "error": "invalid onboarding skip state"}
	for field in ["completed_ids", "evidence_ids"]:
		if not (progress.get(field) is Array) or progress[field].size() > MAX_IDS:
			return {"ok": false, "error": "invalid onboarding ID list"}
		var seen := {}
		for value in progress[field]:
			if not (value is String) or value.is_empty() or value.length() > MAX_ID_LENGTH \
					or seen.has(value):
				return {"ok": false, "error": "invalid onboarding ID"}
			seen[value] = true
	return {"ok": true}

static func _is_integer(value: Variant) -> bool:
	return (value is int) or (value is float and is_finite(value) and value == floor(value))
