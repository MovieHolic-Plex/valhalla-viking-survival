extends Node
## 전역 게임 상태. 오토로드 이름: GameState

signal day_changed(day: int)
signal boss_defeated(boss_id: String)
signal power_changed(power_id: String)
signal message(text: String)
signal biome_changed(biome: int)

var world_seed: int = 0
var world_name: String = "미드가르드"
var world_id: String = ""
var local_player_id: String = ""
var gen: WorldGen

var player: Node3D = null
var world_root: Node3D = null

## 시간 (0.0 ~ 1.0 = 하루). 0.25 = 아침, 0.5 = 정오, 0.75 = 저녁
var time_of_day: float = 0.28
var day: int = 1
var paused_time := false

## 진행도
var bosses_killed: Dictionary = {}      # boss_id -> true
var active_power: String = ""           # 현재 장착한 포세이큰 파워
var power_cooldown: float = 0.0
var power_active_time: float = 0.0
var known_powers: Dictionary = {}

## 월드 변경 사항
var removed_props: Dictionary = {}      # Vector2i(청크) -> {idx: true}
var current_biome: int = Const.Biome.MEADOWS
var discovered: Dictionary = {}         # Vector2i(맵타일) -> true

var stats: Dictionary = {
	"kills": 0, "deaths": 0, "crafted": 0, "built": 0, "trees": 0, "distance": 0.0,
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var identity := IdentityStore.new().load_or_create()
	if bool(identity.get("ok", false)):
		local_player_id = str(identity["local_player_id"])

func snapshot_loaded_world_state() -> Dictionary:
	return {
		"world_seed": world_seed,
		"world_name": world_name,
		"world_id": world_id,
		"local_player_id": local_player_id,
		"gen": gen,
		"time_of_day": time_of_day,
		"day": day,
		"bosses_killed": bosses_killed.duplicate(true),
		"known_powers": known_powers.duplicate(true),
		"active_power": active_power,
		"power_cooldown": power_cooldown,
		"power_active_time": power_active_time,
		"removed_props": removed_props.duplicate(true),
		"discovered": discovered.duplicate(true),
		"stats": stats.duplicate(true),
	}

func restore_loaded_world_state(snapshot: Dictionary) -> bool:
	var required := ["world_seed", "world_name", "world_id", "local_player_id", "gen",
		"time_of_day", "day", "bosses_killed", "known_powers", "active_power",
		"power_cooldown", "power_active_time", "removed_props", "discovered", "stats"]
	if not _valid_loaded_world_shape(snapshot, required, true):
		return false
	world_seed = snapshot["world_seed"]
	world_name = snapshot["world_name"]
	world_id = snapshot["world_id"]
	local_player_id = snapshot["local_player_id"]
	gen = snapshot["gen"]
	time_of_day = snapshot["time_of_day"]
	day = snapshot["day"]
	bosses_killed = snapshot["bosses_killed"].duplicate(true)
	known_powers = snapshot["known_powers"].duplicate(true)
	active_power = snapshot["active_power"]
	power_cooldown = snapshot["power_cooldown"]
	power_active_time = snapshot["power_active_time"]
	removed_props = snapshot["removed_props"].duplicate(true)
	discovered = snapshot["discovered"].duplicate(true)
	stats = snapshot["stats"].duplicate(true)
	return true

func _valid_loaded_world_shape(value: Dictionary, required: Array, snapshot: bool) -> bool:
	if value.size() != required.size():
		return false
	for field in required:
		if not value.has(field):
			return false
	var seed_key := "world_seed" if snapshot else "seed"
	var time_key := "time_of_day" if snapshot else "time"
	var bosses_key := "bosses_killed" if snapshot else "bosses"
	var powers_key := "known_powers" if snapshot else "powers"
	var removed_key := "removed_props" if snapshot else "removed"
	if not (value[seed_key] is int) or not (value["world_name"] is String) \
			or not IdentityStore.is_uuid(value["world_id"]) \
			or not IdentityStore.is_uuid(value["local_player_id"]) \
			or not (value["gen"] is WorldGen) or not (value[time_key] is int or value[time_key] is float) \
			or not (value["day"] is int) or not (value[bosses_key] is Dictionary) \
			or not (value[powers_key] is Dictionary) or not (value[removed_key] is Dictionary) \
			or not (value["discovered"] is Dictionary) or not (value["stats"] is Dictionary) \
			or not (value["active_power"] is String):
		return false
	if snapshot and (not (value["power_cooldown"] is int or value["power_cooldown"] is float) \
			or not (value["power_active_time"] is int or value["power_active_time"] is float)):
		return false
	if value["stats"].size() != stats.size():
		return false
	for key in stats:
		if not value["stats"].has(key):
			return false
	return true

func apply_loaded_world(candidate: Dictionary) -> bool:
	var required := ["seed", "world_name", "world_id", "local_player_id", "gen", "time", "day",
		"bosses", "powers", "active_power", "removed", "discovered", "stats"]
	if not _valid_loaded_world_shape(candidate, required, false):
		return false
	world_seed = candidate["seed"]
	world_name = candidate["world_name"]
	world_id = candidate["world_id"]
	local_player_id = candidate["local_player_id"]
	gen = candidate["gen"]
	time_of_day = candidate["time"]
	day = candidate["day"]
	bosses_killed = candidate["bosses"].duplicate(true)
	known_powers = candidate["powers"].duplicate(true)
	active_power = candidate["active_power"]
	power_cooldown = 0.0
	power_active_time = 0.0
	removed_props = candidate["removed"].duplicate(true)
	discovered = candidate["discovered"].duplicate(true)
	stats = candidate["stats"].duplicate(true)
	return true
func new_world(sv: int, wname: String = "") -> void:
	world_seed = sv
	world_id = IdentityStore.create_uuid_v4()
	if wname != "":
		world_name = wname
	gen = WorldGen.new(sv)
	time_of_day = 0.28
	day = 1
	bosses_killed.clear()
	removed_props.clear()
	discovered.clear()
	known_powers.clear()
	active_power = ""
	power_cooldown = 0.0
	power_active_time = 0.0
	for k in stats:
		stats[k] = 0.0 if k == "distance" else 0

func _process(delta: float) -> void:
	if paused_time or gen == null:
		return
	var prev := time_of_day
	time_of_day += delta / Const.DAY_LENGTH
	if time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1
		day_changed.emit(day)
	if power_cooldown > 0.0:
		power_cooldown = maxf(0.0, power_cooldown - delta)
	if power_active_time > 0.0:
		power_active_time = maxf(0.0, power_active_time - delta)

# ─────────────────────────────────────────────── 시간
func is_night() -> bool:
	return time_of_day < 0.20 or time_of_day > 0.80

func is_dawn_or_dusk() -> bool:
	return (time_of_day > 0.18 and time_of_day < 0.30) \
		or (time_of_day > 0.72 and time_of_day < 0.84)

func clock_string() -> String:
	var total := int(time_of_day * 1440.0)
	return "%02d:%02d" % [total / 60, total % 60]

func skip_to_morning() -> void:
	if time_of_day > 0.75:
		day += 1
		day_changed.emit(day)
	time_of_day = 0.26

# ─────────────────────────────────────────────── 배치물 제거 기록
func mark_prop_removed(chunk: Vector2i, idx: int) -> void:
	if not removed_props.has(chunk):
		removed_props[chunk] = {}
	removed_props[chunk][idx] = true

func removed_in(chunk: Vector2i) -> Dictionary:
	return removed_props.get(chunk, {})

# ─────────────────────────────────────────────── 보스 · 파워
func kill_boss(boss_id: String, power_id: String) -> void:
	bosses_killed[boss_id] = true
	known_powers[power_id] = true
	boss_defeated.emit(boss_id)
	msg(tr("MSG_BOSS_DEFEATED") % tr("BOSS_" + boss_id.to_upper()))

func has_power(power_id: String) -> bool:
	return known_powers.has(power_id)

func set_power(power_id: String) -> void:
	active_power = power_id
	power_changed.emit(power_id)

func activate_power() -> bool:
	if active_power == "" or power_cooldown > 0.0:
		return false
	power_cooldown = 300.0
	power_active_time = _power_duration(active_power)
	Sfx.play("level_up", -4.0, 0.8)
	msg(tr("MSG_POWER_ACTIVATED") % tr("POWER_" + active_power.to_upper()))
	return true

func power_is_active(power_id: String) -> bool:
	return active_power == power_id and power_active_time > 0.0

static func _power_duration(power_id: String) -> float:
	match power_id:
		"eikthyr": return 300.0
		"elder": return 300.0
		"bonemass": return 300.0
		"moder": return 300.0
		"yagluth": return 300.0
		"queen": return 300.0
	return 300.0

# ─────────────────────────────────────────────── 알림
func msg(text: String) -> void:
	message.emit(text)

func set_biome(b: int) -> void:
	if b == current_biome:
		return
	current_biome = b
	biome_changed.emit(b)

# ─────────────────────────────────────────────── 지형 질의
func height_at(x: float, z: float) -> float:
	return gen.height(x, z) if gen != null else 0.0

func biome_at(x: float, z: float) -> int:
	return gen.biome_at(x, z) if gen != null else Const.Biome.MEADOWS
