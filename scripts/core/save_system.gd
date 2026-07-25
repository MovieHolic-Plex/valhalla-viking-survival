extends Node
## 저장/불러오기. 오토로드 이름: SaveSystem
## user:// 아래에 JSON 으로 저장한다. 월드는 시드로 재생성되므로 변경분만 기록한다.

const DIR := "user://saves"
const SLOT := "world1"
const VERSION := 1

signal saved()
signal loaded()

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

func path(slot: String = SLOT) -> String:
	return "%s/%s.json" % [DIR, slot]

func has_save(slot: String = SLOT) -> bool:
	return FileAccess.file_exists(path(slot))

func save_game(player, build_system, slot: String = SLOT) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	var d := {
		"version": VERSION,
		"seed": GameState.world_seed,
		"world_name": GameState.world_name,
		"time": GameState.time_of_day,
		"day": GameState.day,
		"bosses": GameState.bosses_killed.duplicate(),
		"powers": GameState.known_powers.duplicate(),
		"active_power": GameState.active_power,
		"stats": GameState.stats.duplicate(),
		"player": player.to_dict(),
		"spawn": _v3_arr(player.get_meta("spawn_point", Vector3.ZERO)),
		"removed": _pack_removed(),
		"discovered": _pack_discovered(),
		"pieces": build_system.to_dict() if build_system != null else [],
		"tombs": _pack_tombs(player),
	}
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f == null:
		GameState.msg(tr("MSG_SAVE_FAILED"))
		return false
	f.store_string(JSON.stringify(d))
	f.close()
	GameState.msg(tr("MSG_SAVED"))
	Sfx.play("click", -12.0)
	saved.emit()
	return true

func load_game(player, build_system, slot: String = SLOT) -> bool:
	if not has_save(slot):
		GameState.msg(tr("MSG_NO_SAVE"))
		return false
	var f := FileAccess.open(path(slot), FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		GameState.msg(tr("MSG_SAVE_CORRUPT"))
		return false
	var d: Dictionary = parsed

	GameState.new_world(int(d.get("seed", 0)), str(d.get("world_name", "미드가르드")))
	GameState.time_of_day = float(d.get("time", 0.28))
	GameState.day = int(d.get("day", 1))
	GameState.bosses_killed = _str_keys(d.get("bosses", {}))
	GameState.known_powers = _str_keys(d.get("powers", {}))
	GameState.active_power = str(d.get("active_power", ""))
	var st: Dictionary = d.get("stats", {})
	for k in GameState.stats:
		if st.has(k):
			GameState.stats[k] = st[k]
	_unpack_removed(d.get("removed", {}))
	_unpack_discovered(d.get("discovered", []))

	if player != null and is_instance_valid(player):
		player.from_dict(d.get("player", {}))
		var sp: Array = d.get("spawn", [0, 0, 0])
		player.set_meta("spawn_point", Vector3(float(sp[0]), float(sp[1]), float(sp[2])))
	if build_system != null:
		build_system.from_dict(d.get("pieces", []))
	_unpack_tombs(d.get("tombs", []), player)

	GameState.msg(tr("MSG_LOADED"))
	loaded.emit()
	return true

func delete_save(slot: String = SLOT) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(path(slot))

# ─────────────────────────────────────────────── 직렬화 헬퍼
static func _v3_arr(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

static func _str_keys(d) -> Dictionary:
	var out := {}
	if d is Dictionary:
		for k in d:
			out[str(k)] = d[k]
	return out

func _pack_removed() -> Dictionary:
	var out := {}
	for key in GameState.removed_props:
		var idxs: Array = []
		for i in GameState.removed_props[key]:
			idxs.append(int(i))
		out["%d,%d" % [key.x, key.y]] = idxs
	return out

func _unpack_removed(d) -> void:
	GameState.removed_props.clear()
	if not (d is Dictionary):
		return
	for k in d:
		var parts := str(k).split(",")
		if parts.size() != 2:
			continue
		var key := Vector2i(int(parts[0]), int(parts[1]))
		var m := {}
		for i in d[k]:
			m[int(i)] = true
		GameState.removed_props[key] = m

func _pack_discovered() -> Array:
	var out: Array = []
	for k in GameState.discovered:
		out.append([k.x, k.y])
	return out

func _unpack_discovered(a) -> void:
	GameState.discovered.clear()
	if not (a is Array):
		return
	for e in a:
		if e is Array and e.size() == 2:
			GameState.discovered[Vector2i(int(e[0]), int(e[1]))] = true

func _pack_tombs(player) -> Array:
	var out: Array = []
	if player == null or not player.is_inside_tree():
		return out
	for t in player.get_tree().get_nodes_in_group("tombstone"):
		if is_instance_valid(t):
			out.append(t.to_dict())
	return out

func _unpack_tombs(arr, player) -> void:
	if player == null or not player.is_inside_tree() or not (arr is Array):
		return
	var tree: SceneTree = player.get_tree()
	for t in tree.get_nodes_in_group("tombstone"):
		if is_instance_valid(t):
			t.queue_free()
	for d in arr:
		if not (d is Dictionary):
			continue
		var tomb := Tombstone.new()
		tree.current_scene.add_child(tomb)
		var p: Array = d.get("pos", [0, 0, 0])
		tomb.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		tomb.from_dict(d)
