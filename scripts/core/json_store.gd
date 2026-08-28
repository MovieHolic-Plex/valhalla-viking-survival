class_name JsonStore
extends RefCounted
## Bounded duplicate-aware JSON loading and same-volume transactional replacement.

const MAX_BYTES := 4 * 1024 * 1024
const MAX_DEPTH := 64
const MAX_KEYS_PER_OBJECT := 4096
const MAX_KEY_LENGTH := 1024
const MAX_TOKENS := 500000

var last_error: String = ""

func load_document(file_path: String, validator: Callable = Callable()) -> Dictionary:
	last_error = ""
	var primary := _read_valid(file_path, validator)
	if bool(primary.get("ok", false)):
		return primary
	# A terminal schema rejection (for example, an explicit foreign owner) must not
	# be bypassed by selecting an older generation with weaker ownership data.
	if bool(primary.get("terminal", false)):
		last_error = str(primary.get("error", "document rejected"))
		return {"ok": false, "error": last_error}
	# .previous exists only after current was atomically moved during a write. It
	# is newer committed transaction evidence than .bak and must win recovery.
	var previous_path := file_path + ".previous"
	var previous := _read_valid(previous_path, validator)
	if bool(previous.get("ok", false)):
		var invalid_path := file_path + ".invalid"
		var quarantined_primary := false
		if FileAccess.file_exists(file_path):
			if FileAccess.file_exists(invalid_path):
				var stale_remove_error := DirAccess.remove_absolute(invalid_path)
				if stale_remove_error != OK:
					last_error = "cannot clear invalid current file for recovery"
					return {"ok": false, "error": last_error}
			var quarantine_error := DirAccess.rename_absolute(file_path, invalid_path)
			if quarantine_error != OK:
				last_error = "cannot quarantine invalid current file for recovery"
				return {"ok": false, "error": last_error}
			quarantined_primary = true
		var promotion_error := DirAccess.rename_absolute(previous_path, file_path)
		if promotion_error != OK:
			if quarantined_primary:
				var restore_error := DirAccess.rename_absolute(invalid_path, file_path)
				last_error = "cannot promote previous generation" if restore_error == OK \
					else "cannot promote previous generation or restore invalid current file"
			else:
				last_error = "cannot promote previous generation"
			return {"ok": false, "error": last_error}
		if quarantined_primary:
			DirAccess.remove_absolute(invalid_path)
		return previous
	if bool(previous.get("terminal", false)):
		last_error = str(previous.get("error", "previous generation rejected"))
		return {"ok": false, "error": last_error}
	var backup_path := file_path + ".bak"
	var backup := _read_valid(backup_path, validator)
	if bool(backup.get("ok", false)):
		return backup
	if bool(backup.get("terminal", false)):
		last_error = str(backup.get("error", "backup rejected"))
		return {"ok": false, "error": last_error}
	# A .tmp file has not crossed the commit rename. VERSION=1 documents carry no
	# ordering, so it cannot be promoted without a committed generation marker.
	var tmp_path := file_path + ".tmp"
	var staged := _read_valid(tmp_path, validator)
	last_error = str(primary.get("error", "missing file"))
	if FileAccess.file_exists(previous_path):
		last_error += "; previous: " + str(previous.get("error", "invalid"))
	if FileAccess.file_exists(backup_path):
		last_error += "; backup: " + str(backup.get("error", "invalid"))
	if FileAccess.file_exists(tmp_path):
		last_error += "; uncommitted temporary: " + str(staged.get("error", "valid"))
	return {"ok": false, "error": last_error}

func save_document(file_path: String, document: Dictionary,
		validator: Callable = Callable()) -> bool:
	last_error = ""
	var text := JSON.stringify(document)
	if text.to_utf8_buffer().size() > MAX_BYTES:
		last_error = "document exceeds byte limit"
		return false
	var parent := file_path.get_base_dir()
	if parent != "":
		var dir_error := DirAccess.make_dir_recursive_absolute(parent)
		if dir_error != OK and not DirAccess.dir_exists_absolute(parent):
			last_error = "cannot create store directory"
			return false
	var tmp_path := file_path + ".tmp"
	var tmp := FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp == null:
		last_error = "cannot open temporary file"
		return false
	tmp.store_string(text)
	tmp.flush()
	tmp.close()
	var staged := _read_valid(tmp_path, validator)
	if not bool(staged.get("ok", false)):
		last_error = "temporary verification failed: " + str(staged.get("error", "invalid"))
		DirAccess.remove_absolute(tmp_path)
		return false

	var backup_path := file_path + ".bak"
	var current_valid := false
	var backup_valid := bool(_read_valid(backup_path, validator).get("ok", false))
	if FileAccess.file_exists(file_path):
		current_valid = bool(_read_valid(file_path, validator).get("ok", false))
	if current_valid:
		# Keep the prior committed generation at its installed path until there is
		# no fallible work left before the replacement rename.
		var previous_path := file_path + ".previous"
		if FileAccess.file_exists(previous_path):
			var previous_remove_error := DirAccess.remove_absolute(previous_path)
			if previous_remove_error != OK:
				last_error = "cannot clear previous generation"
				DirAccess.remove_absolute(tmp_path)
				return false
		var preserve_error := DirAccess.rename_absolute(file_path, previous_path)
		if preserve_error != OK:
			last_error = "cannot preserve current generation"
			DirAccess.remove_absolute(tmp_path)
			return false
		var install_error := DirAccess.rename_absolute(tmp_path, file_path)
		if install_error != OK:
			var restore_error := DirAccess.rename_absolute(previous_path, file_path)
			last_error = "cannot install temporary file" if restore_error == OK \
				else "cannot install temporary file or restore current generation"
			return false
		var installed := _read_valid(file_path, validator)
		if not bool(installed.get("ok", false)):
			var invalid_path := file_path + ".invalid"
			if FileAccess.file_exists(invalid_path):
				DirAccess.remove_absolute(invalid_path)
			var quarantine_error := DirAccess.rename_absolute(file_path, invalid_path)
			var rollback_error := DirAccess.rename_absolute(previous_path, file_path) \
				if quarantine_error == OK else ERR_CANT_ACQUIRE_RESOURCE
			last_error = "installed file verification failed" if rollback_error == OK \
				else "installed file verification failed and rollback failed"
			return false
		# The new current is committed. Preserve the previous current as backup;
		# deleting an older backup is safe because two valid generations exist.
		if FileAccess.file_exists(backup_path):
			var remove_backup_error := DirAccess.remove_absolute(backup_path)
			if remove_backup_error != OK:
				# The primary already crossed the verified commit boundary. Keep both
				# committed generations and report success rather than lying to callers.
				last_error = "new generation installed; old backup retained"
				return true
		var backup_error := DirAccess.rename_absolute(previous_path, backup_path)
		if backup_error != OK:
			# `.previous` remains valid recovery evidence when backup rotation fails.
			last_error = "new generation installed; previous generation retained"
			return true
		return true

	if backup_valid:
		var invalid_path := file_path + ".invalid"
		var quarantined_current := false
		if FileAccess.file_exists(file_path):
			if FileAccess.file_exists(invalid_path):
				var stale_remove_error := DirAccess.remove_absolute(invalid_path)
				if stale_remove_error != OK:
					last_error = "cannot clear invalid current file"
					DirAccess.remove_absolute(tmp_path)
					return false
			var quarantine_error := DirAccess.rename_absolute(file_path, invalid_path)
			if quarantine_error != OK:
				last_error = "cannot quarantine invalid current file"
				DirAccess.remove_absolute(tmp_path)
				return false
			quarantined_current = true
		var replace_error := DirAccess.rename_absolute(tmp_path, file_path)
		if replace_error != OK:
			if quarantined_current:
				var restore_error := DirAccess.rename_absolute(invalid_path, file_path)
				if restore_error != OK:
					last_error = "cannot install temporary file or restore invalid current file"
					return false
			last_error = "cannot install temporary file"
			return false
		var installed := _read_valid(file_path, validator)
		if not bool(installed.get("ok", false)):
			last_error = "installed file verification failed; valid backup preserved"
			return false
		if quarantined_current:
			DirAccess.remove_absolute(invalid_path)
		return true

	if FileAccess.file_exists(file_path):
		var remove_error := DirAccess.remove_absolute(file_path)
		if remove_error != OK:
			last_error = "cannot replace invalid current file"
			DirAccess.remove_absolute(tmp_path)
			return false
	var replace_error := DirAccess.rename_absolute(tmp_path, file_path)
	if replace_error != OK:
		last_error = "cannot install temporary file"
		return false
	var installed := _read_valid(file_path, validator)
	if not bool(installed.get("ok", false)):
		last_error = "installed file verification failed"
		return false
	return true

func _read_valid(file_path: String, validator: Callable) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {"ok": false, "error": "missing file"}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "cannot open file"}
	var length := file.get_length()
	if length < 0 or length > MAX_BYTES:
		file.close()
		return {"ok": false, "error": "document exceeds byte limit"}
	var bytes := file.get_buffer(length)
	file.close()
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes:
		return {"ok": false, "error": "invalid UTF-8"}
	var scan := _scan(text)
	if not bool(scan.get("ok", false)):
		return scan
	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK:
		return {"ok": false, "error": "malformed JSON"}
	var value = json.data
	if not (value is Dictionary):
		return {"ok": false, "error": "root must be an object"}
	if validator.is_valid():
		var validation = validator.call(value)
		if not (validation is Dictionary) or not bool(validation.get("ok", false)):
			var rejected := {"ok": false, "error": str(validation.get("error", "schema rejected")) \
				if validation is Dictionary else "schema rejected"}
			if validation is Dictionary and bool(validation.get("terminal", false)):
				rejected["terminal"] = true
			return rejected
	return {"ok": true, "value": value}

func _scan(text: String) -> Dictionary:
	var context: Array = []
	var root_state := 0
	var index := 0
	var token_count := 0
	while true:
		index = _skip_ws(text, index)
		if index >= text.length():
			break
		if context.is_empty() and root_state == 0 and text[index] != "{":
			return {"ok": false, "error": "root must be an object"}
		token_count += 1
		if token_count > MAX_TOKENS:
			return {"ok": false, "error": "token limit exceeded"}

		var expected := root_state if context.is_empty() else int(context[-1]["state"])
		var kind := str(context[-1]["kind"]) if not context.is_empty() else "root"
		var ch := text[index]
		if kind == "object" and expected == 0:
			if ch == "}":
				index += 1
				context.pop_back()
				var complete := _value_complete(context, root_state)
				root_state = int(complete[0])
				if not bool(complete[1]):
					return {"ok": false, "error": "unexpected object close"}
				continue
			if ch != "\"":
				return {"ok": false, "error": "object key must be a string"}
			var key_result := _read_string(text, index)
			if not bool(key_result.get("ok", false)):
				return key_result
			var key := str(key_result["value"])
			if key.length() > MAX_KEY_LENGTH:
				return {"ok": false, "error": "key length limit exceeded"}
			var keys: Dictionary = context[-1]["keys"]
			if keys.has(key):
				return {"ok": false, "error": "duplicate object key"}
			if keys.size() >= MAX_KEYS_PER_OBJECT:
				return {"ok": false, "error": "object key limit exceeded"}
			keys[key] = true
			context[-1]["keys"] = keys
			context[-1]["state"] = 1
			index = int(key_result["next"])
			continue
		if kind == "object" and expected == 1:
			if ch != ":":
				return {"ok": false, "error": "missing object colon"}
			context[-1]["state"] = 2
			index += 1
			continue
		if kind == "object" and expected == 3:
			if ch == ",":
				context[-1]["state"] = 0
				index += 1
				continue
			if ch == "}":
				index += 1
				context.pop_back()
				var complete := _value_complete(context, root_state)
				root_state = int(complete[0])
				if not bool(complete[1]):
					return {"ok": false, "error": "unexpected object close"}
				continue
			return {"ok": false, "error": "missing object separator"}
		if kind == "array" and expected == 1:
			if ch == ",":
				context[-1]["state"] = 0
				index += 1
				continue
			if ch == "]":
				index += 1
				context.pop_back()
				var complete := _value_complete(context, root_state)
				root_state = int(complete[0])
				if not bool(complete[1]):
					return {"ok": false, "error": "unexpected array close"}
				continue
			return {"ok": false, "error": "missing array separator"}
		if kind == "array" and expected == 0 and ch == "]":
			index += 1
			context.pop_back()
			var complete := _value_complete(context, root_state)
			root_state = int(complete[0])
			if not bool(complete[1]):
				return {"ok": false, "error": "unexpected array close"}
			continue
		if kind == "root" and expected != 0:
			return {"ok": false, "error": "trailing JSON data"}
		if ch == "{":
			if context.size() >= MAX_DEPTH:
				return {"ok": false, "error": "depth limit exceeded"}
			context.append({"kind": "object", "state": 0, "keys": {}})
			index += 1
			continue
		if ch == "[":
			if context.size() >= MAX_DEPTH:
				return {"ok": false, "error": "depth limit exceeded"}
			context.append({"kind": "array", "state": 0})
			index += 1
			continue
		var scalar := _read_scalar(text, index)
		if not bool(scalar.get("ok", false)):
			return scalar
		index = int(scalar["next"])
		var complete := _value_complete(context, root_state)
		root_state = int(complete[0])
		if not bool(complete[1]):
			return {"ok": false, "error": "unexpected value"}
	if not context.is_empty() or root_state != 1:
		return {"ok": false, "error": "incomplete JSON document"}
	return {"ok": true}

func _value_complete(context: Array, root_state: int) -> Array:
	if context.is_empty():
		return [1, root_state == 0]
	var state := int(context[-1]["state"])
	if str(context[-1]["kind"]) == "object":
		if state != 2:
			return [root_state, false]
		context[-1]["state"] = 3
		return [root_state, true]
	if state != 0:
		return [root_state, false]
	context[-1]["state"] = 1
	return [root_state, true]

func _read_scalar(text: String, start: int) -> Dictionary:
	if text[start] == "\"":
		return _read_string(text, start)
	for literal in ["true", "false", "null"]:
		if text.substr(start, literal.length()) == literal:
			var end: int = start + literal.length()
			if end < text.length() and not _is_delimiter(text[end]):
				return {"ok": false, "error": "invalid literal"}
			return {"ok": true, "next": end}
	return _read_number(text, start)

func _read_number(text: String, start: int) -> Dictionary:
	var i := start
	if i < text.length() and text[i] == "-":
		i += 1
	if i >= text.length():
		return {"ok": false, "error": "invalid number"}
	if text[i] == "0":
		i += 1
	elif text[i] >= "1" and text[i] <= "9":
		while i < text.length() and text[i] >= "0" and text[i] <= "9":
			i += 1
	else:
		return {"ok": false, "error": "invalid number"}
	if i < text.length() and text[i] == ".":
		i += 1
		var fraction_start := i
		while i < text.length() and text[i] >= "0" and text[i] <= "9":
			i += 1
		if i == fraction_start:
			return {"ok": false, "error": "invalid number fraction"}
	if i < text.length() and (text[i] == "e" or text[i] == "E"):
		i += 1
		if i < text.length() and (text[i] == "+" or text[i] == "-"):
			i += 1
		var exponent_start := i
		while i < text.length() and text[i] >= "0" and text[i] <= "9":
			i += 1
		if i == exponent_start:
			return {"ok": false, "error": "invalid number exponent"}
	if i < text.length() and not _is_delimiter(text[i]):
		return {"ok": false, "error": "invalid number suffix"}
	return {"ok": true, "next": i}

func _read_string(text: String, start: int) -> Dictionary:
	var i := start + 1
	var decoded := ""
	while i < text.length():
		var ch := text[i]
		if ch == "\"":
			return {"ok": true, "value": decoded, "next": i + 1}
		if ch == "\\":
			i += 1
			if i >= text.length():
				return {"ok": false, "error": "unterminated escape"}
			var escaped := text[i]
			match escaped:
				"\"", "\\", "/": decoded += escaped
				"b": decoded += "\b"
				"f": decoded += "\f"
				"n": decoded += "\n"
				"r": decoded += "\r"
				"t": decoded += "\t"
				"u":
					var unicode := _read_unicode_escape(text, i)
					if not bool(unicode.get("ok", false)):
						return unicode
					decoded += String.chr(int(unicode["codepoint"]))
					i = int(unicode["last"])
				_:
					return {"ok": false, "error": "invalid string escape"}
		else:
			if ch.unicode_at(0) < 0x20:
				return {"ok": false, "error": "control character in string"}
			decoded += ch
		i += 1
	return {"ok": false, "error": "unterminated string"}

func _read_unicode_escape(text: String, u_index: int) -> Dictionary:
	if u_index + 4 >= text.length():
		return {"ok": false, "error": "short Unicode escape"}
	var high := _hex4(text, u_index + 1)
	if high < 0:
		return {"ok": false, "error": "invalid Unicode escape"}
	if high >= 0xd800 and high <= 0xdbff:
		var next := u_index + 5
		if next + 5 >= text.length() or text[next] != "\\" or text[next + 1] != "u":
			return {"ok": false, "error": "missing low surrogate"}
		var low := _hex4(text, next + 2)
		if low < 0xdc00 or low > 0xdfff:
			return {"ok": false, "error": "invalid low surrogate"}
		return {"ok": true, "codepoint": 0x10000 + ((high - 0xd800) << 10) + low - 0xdc00,
			"last": next + 5}
	if high >= 0xdc00 and high <= 0xdfff:
		return {"ok": false, "error": "unexpected low surrogate"}
	return {"ok": true, "codepoint": high, "last": u_index + 4}

func _hex4(text: String, start: int) -> int:
	var value := 0
	for offset in range(4):
		var digit := text[start + offset]
		var n := -1
		if digit >= "0" and digit <= "9": n = digit.unicode_at(0) - 48
		elif digit >= "a" and digit <= "f": n = digit.unicode_at(0) - 87
		elif digit >= "A" and digit <= "F": n = digit.unicode_at(0) - 55
		if n < 0:
			return -1
		value = value * 16 + n
	return value

func _skip_ws(text: String, start: int) -> int:
	var i := start
	while i < text.length() and (text[i] == " " or text[i] == "\t" \
			or text[i] == "\r" or text[i] == "\n"):
		i += 1
	return i

func _is_delimiter(ch: String) -> bool:
	return ch == " " or ch == "\t" or ch == "\r" or ch == "\n" \
		or ch == "," or ch == "]" or ch == "}"
