class_name SettingsStore
extends RefCounted
## Private profile settings persisted independently from world saves.

signal changed(snapshot: Dictionary)

const PATH := "user://settings.json"
const VERSION := 1
const DEFAULTS := {
	"locale": "ko",
	"ui_scale": 1.0,
	"master_volume": 0.8,
	"sfx_volume": 0.8,
	"ambient_volume": 0.8,
	"mouse_sensitivity": 0.0026,
	"invert_y": false,
	"reduced_shake": false,
}

var last_error: String = ""
var _values: Dictionary = DEFAULTS.duplicate(true)
var _json := JsonStore.new()

func load() -> Dictionary:
	last_error = ""
	_values = DEFAULTS.duplicate(true)
	var loaded := _json.load_document(PATH, _validate_document)
	if bool(loaded.get("ok", false)):
		_values = _sanitize(loaded["value"])
	elif FileAccess.file_exists(PATH) or FileAccess.file_exists(PATH + ".bak") \
			or FileAccess.file_exists(PATH + ".tmp"):
		last_error = str(loaded.get("error", "settings load failed"))
	_apply_live()
	return snapshot()

func snapshot() -> Dictionary:
	return _values.duplicate(true)

func get_value(key: String, fallback = null):
	return _values.get(key, fallback)

func set_value(key: String, value) -> bool:
	if not DEFAULTS.has(key):
		last_error = "unknown setting"
		return false
	if not _valid_field(key, value):
		last_error = "invalid setting: " + key
		return false
	var next := _values.duplicate(true)
	next[key] = value
	next = _sanitize(next)
	var document := next.duplicate(true)
	document["version"] = VERSION
	if not _json.save_document(PATH, document, _validate_document):
		last_error = _json.last_error
		return false
	last_error = ""
	_values = next
	_apply_live()
	changed.emit(snapshot())
	return true

func _apply_live() -> void:
	TranslationServer.set_locale(str(_values["locale"]))
	Sfx.configure(float(_values["master_volume"]), float(_values["sfx_volume"]),
		float(_values["ambient_volume"]))

func _validate_document(document: Dictionary) -> Dictionary:
	if not _is_integer(document.get("version")) or int(document["version"]) != VERSION:
		return {"ok": false, "error": "unsupported settings version"}
	if document.size() != DEFAULTS.size() + 1:
		return {"ok": false, "error": "invalid settings schema"}
	for key in document:
		if key != "version" and not DEFAULTS.has(key):
			return {"ok": false, "error": "unknown setting: " + str(key)}
	for key in DEFAULTS:
		if not document.has(key) or not _valid_field(key, document[key]):
			return {"ok": false, "error": "invalid setting: " + key}
	return {"ok": true}

func _sanitize(document: Dictionary) -> Dictionary:
	var result := DEFAULTS.duplicate(true)
	for key in DEFAULTS:
		if document.has(key) and _valid_field(key, document[key]):
			result[key] = document[key]
	result["ui_scale"] = clampf(float(result["ui_scale"]), 0.75, 1.25)
	result["master_volume"] = clampf(float(result["master_volume"]), 0.0, 1.0)
	result["sfx_volume"] = clampf(float(result["sfx_volume"]), 0.0, 1.0)
	result["ambient_volume"] = clampf(float(result["ambient_volume"]), 0.0, 1.0)
	result["mouse_sensitivity"] = clampf(float(result["mouse_sensitivity"]), 0.0005, 0.01)
	return result

func _valid_field(key: String, value) -> bool:
	match key:
		"locale":
			return value is String and value in ["ko", "en"]
		"ui_scale":
			return _finite_number(value) and float(value) >= 0.75 and float(value) <= 1.25
		"master_volume", "sfx_volume", "ambient_volume":
			return _finite_number(value) and float(value) >= 0.0 and float(value) <= 1.0
		"mouse_sensitivity":
			return _finite_number(value) and float(value) >= 0.0005 and float(value) <= 0.01
		"invert_y", "reduced_shake":
			return value is bool
	return false

static func _finite_number(value) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _is_integer(value) -> bool:
	return value is int or value is float and is_finite(value) and value == floor(value)
