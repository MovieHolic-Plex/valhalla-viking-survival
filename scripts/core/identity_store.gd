class_name IdentityStore
extends RefCounted
## Private installation identity. The ID identifies only this local product profile.

const PATH := "user://identity.json"
const VERSION := 1
const LEGACY_NAMESPACE_HEX := "72a47756119c4f31a5572cb21962f801"

var last_error: String = ""
var _json := JsonStore.new()

func load_or_create() -> Dictionary:
	last_error = ""
	var loaded := _json.load_document(PATH, _validate)
	if bool(loaded.get("ok", false)):
		return {"ok": true, "local_player_id": str(loaded["value"]["local_player_id"])}
	if FileAccess.file_exists(PATH) or FileAccess.file_exists(PATH + ".bak") \
			or FileAccess.file_exists(PATH + ".previous") \
			or FileAccess.file_exists(PATH + ".invalid") \
			or FileAccess.file_exists(PATH + ".tmp"):
		last_error = str(loaded.get("error", "identity load failed"))
		return {"ok": false, "error": last_error}
	var local_player_id := create_uuid_v4()
	var document := {"version": VERSION, "local_player_id": local_player_id}
	if not _json.save_document(PATH, document, _validate):
		last_error = _json.last_error
		return {"ok": false, "error": last_error}
	return {"ok": true, "local_player_id": local_player_id}

func load() -> Dictionary:
	last_error = ""
	var loaded := _json.load_document(PATH, _validate)
	if not bool(loaded.get("ok", false)):
		last_error = str(loaded.get("error", "identity load failed"))
		return {"ok": false, "error": last_error}
	return {"ok": true, "local_player_id": str(loaded["value"]["local_player_id"])}

func save(local_player_id: String) -> bool:
	last_error = ""
	if not is_uuid(local_player_id):
		last_error = "invalid local player ID"
		return false
	var ok := _json.save_document(PATH,
		{"version": VERSION, "local_player_id": local_player_id}, _validate)
	if not ok:
		last_error = _json.last_error
	return ok

static func create_uuid_v4() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	return _format_uuid(bytes)

static func legacy_uuid(name: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA1)
	context.update(LEGACY_NAMESPACE_HEX.hex_decode())
	context.update(name.to_utf8_buffer())
	var bytes := context.finish().slice(0, 16)
	bytes[6] = (bytes[6] & 0x0f) | 0x50
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	return _format_uuid(bytes)

static func is_uuid(value: Variant) -> bool:
	if not (value is String):
		return false
	var text: String = value
	if text.length() != 36 or text[8] != "-" or text[13] != "-" \
			or text[18] != "-" or text[23] != "-":
		return false
	for i in text.length():
		if i == 8 or i == 13 or i == 18 or i == 23:
			continue
		var ch := text[i].to_lower()
		if not ((ch >= "0" and ch <= "9") or (ch >= "a" and ch <= "f")):
			return false
	return true

func _validate(document: Dictionary) -> Dictionary:
	if not ((document.get("version") is int) or (document.get("version") is float \
			and is_finite(document["version"]) \
			and document["version"] == floor(document["version"]))):
		return {"ok": false, "error": "identity version is missing"}
	if int(document["version"]) != VERSION:
		return {"ok": false, "error": "unsupported identity version", "terminal": true}
	if document.size() != 2 or not document.has("local_player_id"):
		return {"ok": false, "error": "invalid identity schema"}
	if not is_uuid(document.get("local_player_id")):
		return {"ok": false, "error": "invalid local player ID"}
	return {"ok": true}

static func _format_uuid(bytes: PackedByteArray) -> String:
	var hex := ""
	for byte in bytes:
		hex += "%02x" % byte
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4),
		hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
