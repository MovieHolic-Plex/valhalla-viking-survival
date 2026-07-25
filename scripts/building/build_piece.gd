class_name BuildPiece
extends StaticBody3D
## 설치된 건축 조각. 구조 무결성 · 제작대 기능 · 문/침대/화로 등의 동작을 담당한다.

signal removed(piece)

var piece_id := "wood_floor"
var net_id := 0        # 멀티플레이 동기화 ID (0 = 로컬 전용)
var data: Dictionary = {}
var hp := 100.0
var max_hp := 100.0
var support := 1.0
var grounded := false
var yaw := 0.0

var storage: Inventory = null       # 상자
var _mi: MeshInstance3D
var _door_open := false
var _fire_fx: GPUParticles3D
var _light: OmniLight3D
var _cook_slots: Array = []          # 요리대: [{id, t, done}]
var _smelt_in: Array = []            # 제련소 투입 광석
var _smelt_fuel := 0
var _smelt_t := 0.0
var _label: Label3D
var _grow_t := 0.0
var _grown := false

static func make(id: String) -> BuildPiece:
	var p := BuildPiece.new()
	p.piece_id = id
	p.data = RecipeDB.piece(id)
	return p

func _ready() -> void:
	if data.is_empty():
		data = RecipeDB.piece(piece_id)
	collision_layer = Const.L_BUILDING
	collision_mask = 0
	add_to_group("build_piece")
	add_to_group("interactable")

	max_hp = 100.0 * (2.0 if data.get("stone", false) else 1.0)
	hp = max_hp

	var size: Vector3 = data.get("size", Vector3.ONE)
	var col: Color = _material_color()
	_mi = MeshInstance3D.new()
	_mi.mesh = MeshFactory.piece(str(data.get("kind", "wall")), size, col)
	_mi.material_override = MatLib.flat(Color.WHITE, 0.92)
	add_child(_mi)

	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	add_child(cs)

	if data.get("comfort", 0) > 0 or data.get("fire", false):
		add_to_group("comfort_source")
		set_meta("comfort", int(data.get("comfort", 0)))
		set_meta("fire", bool(data.get("fire", false)))
		set_meta("piece_id", piece_id)

	if data.get("station", "") != "" or data.get("wb_up", 0) > 0 \
			or data.get("forge_up", 0) > 0:
		add_to_group("craft_station")
	if data.get("station", "") == RecipeDB.ST_WORKBENCH:
		add_to_group("spawn_blocker")

	if data.get("container", 0) > 0:
		storage = Inventory.new(int(data["container"]) / 4, 4)

	if data.get("fire", false):
		_fire_fx = Fx.fire(self, size.x * 0.8)
		_fire_fx.position = Vector3(0, size.y * 0.4, 0)
		_light = OmniLight3D.new()
		_light.light_color = Color(1.0, 0.62, 0.26)
		_light.light_energy = 3.4
		_light.omni_range = 14.0 * maxf(size.x * 0.6, 0.8)
		_light.shadow_enabled = true
		_light.position = Vector3(0, size.y * 0.6, 0)
		add_child(_light)
		Flicker.attach(_light, 0.26, 1.0)

	if data.get("smelter", false) or data.get("kiln", false) \
			or data.get("cook", false) or data.get("grind", false):
		_label = Label3D.new()
		_label.font_size = 32
		_label.pixel_size = 0.004
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.outline_size = 8
		_label.position = Vector3(0, size.y * 0.8 + 0.6, 0)
		add_child(_label)

	if data.has("crop") or data.has("tree"):
		_grow_t = float(data.get("grow", 300.0))
		_update_plant_visual()

func _material_color() -> Color:
	if data.get("stone", false):
		return Color(0.52, 0.52, 0.50)
	match str(data.get("kind", "")):
		"campfire", "smelter", "kiln", "forge": return Color(0.45, 0.43, 0.40)
		"cauldron": return Color(0.34, 0.34, 0.36)
		"plant": return Color(0.42, 0.60, 0.28)
		_: return Color(0.56, 0.42, 0.26)

# ═══════════════════════════════════════════════ 처리
func _process(delta: float) -> void:
	if data.get("cook", false):
		_tick_cook(delta)
	if data.get("smelter", false):
		_tick_smelt(delta, RecipeDB.smelt)
	if data.get("kiln", false):
		_tick_smelt(delta, RecipeDB.kiln)
	if _grow_t > 0.0 and not _grown:
		_grow_t -= delta
		if _grow_t <= 0.0:
			_grown = true
			_update_plant_visual()

func _update_plant_visual() -> void:
	if _mi == null:
		return
	var total := float(data.get("grow", 300.0))
	var stage := 1.0 if _grown else clampf(1.0 - _grow_t / maxf(total, 1.0), 0.12, 1.0)
	var cid := str(data.get("crop", ""))
	var col := ItemDB.color_of(cid) if cid != "" else Color(0.35, 0.55, 0.25)
	var tall := cid in ["barley", "flax"]
	_mi.mesh = MeshFactory.crop_plant(stage, col, tall)
	_mi.material_override = MatLib.foliage(Color.WHITE, 0.15, 0.08)

func _tick_cook(delta: float) -> void:
	var changed := false
	for s in _cook_slots:
		if s.get("burnt", false) or s["t"] <= 0.0:
			continue
		s["t"] = float(s["t"]) - delta
		if float(s["t"]) <= 0.0:
			if s.get("done", false):
				s["burnt"] = true
			else:
				s["done"] = true
				s["t"] = 40.0     # 방치하면 탄다
				Sfx.play_at("fire", global_position, get_tree().current_scene, -20.0)
			changed = true
	if changed and _label:
		_refresh_label()

func _tick_smelt(delta: float, table: Dictionary) -> void:
	if _smelt_in.is_empty():
		if _label:
			_refresh_label()
		return
	var needs_fuel: bool = data.has("fuel")
	if needs_fuel and _smelt_fuel <= 0:
		if _label:
			_label.text = tr("UI_NEEDS_FUEL")
		return
	_smelt_t += delta
	var first: String = _smelt_in[0]
	var rec: Dictionary = table.get(first, {})
	if rec.is_empty():
		_smelt_in.pop_front()
		return
	if _smelt_t >= float(rec["time"]):
		_smelt_t = 0.0
		_smelt_in.pop_front()
		if needs_fuel:
			_smelt_fuel -= 1
		ItemDrop.spawn(get_tree().current_scene,
			global_position + Vector3(0, 0.6, 0) + Vector3(0, 0, 1.2).rotated(Vector3.UP, yaw),
			str(rec["out"]), 1)
		Sfx.play_at("metal_hit", global_position, get_tree().current_scene, -12.0, 0.7)
	if _label:
		_refresh_label()

func _refresh_label() -> void:
	if _label == null:
		return
	if data.get("cook", false):
		var parts: Array[String] = []
		for s in _cook_slots:
			if s.get("burnt", false):
				parts.append(tr("UI_BURNT"))
			elif s.get("done", false):
				parts.append(tr("UI_COOKED"))
			else:
				parts.append("%.0fs" % float(s["t"]))
		_label.text = " · ".join(parts)
	elif data.get("smelter", false) or data.get("kiln", false):
		if _smelt_in.is_empty():
			_label.text = ""
		else:
			_label.text = "%d ⛏  %d 🔥" % [_smelt_in.size(), _smelt_fuel]

# ═══════════════════════════════════════════════ 상호작용
func can_interact(_player) -> bool:
	return true

func prompt() -> String:
	if data.get("door", false):
		return tr("PROMPT_DOOR")
	if data.get("bed", false):
		return tr("PROMPT_SLEEP")
	if data.get("chair", false):
		return tr("PROMPT_SIT")
	if storage != null:
		return tr("PROMPT_OPEN") % tr("UI_CHEST")
	if data.get("cook", false):
		return tr("PROMPT_COOK")
	if data.get("smelter", false) or data.get("kiln", false):
		return tr("PROMPT_INSERT")
	if data.get("station", "") != "":
		return tr("PROMPT_CRAFT")
	if data.has("crop") and _grown:
		return tr("PROMPT_HARVEST")
	if data.get("portal", false):
		return tr("PROMPT_PORTAL")
	return ""

func interact(player) -> void:
	var scene := get_tree().current_scene
	if data.get("door", false):
		_door_open = not _door_open
		var tw := create_tween()
		tw.tween_property(self, "rotation:y", yaw + (PI * 0.5 if _door_open else 0.0), 0.3)
		Sfx.play_at("build", global_position, scene, -14.0, 1.3)
		return
	if data.get("bed", false):
		var ui = scene.get_node_or_null("ui")
		if GameState.is_night():
			GameState.skip_to_morning()
			player.stats.add_status("rested", 480.0, {"comfort": 2})
			GameState.msg(tr("MSG_SLEPT"))
		else:
			GameState.msg(tr("MSG_CANT_SLEEP"))
		player.set_meta("spawn_point", global_position + Vector3(0, 0.5, 0))
		return
	if data.get("chair", false):
		player.global_position = global_position + Vector3(0, 0.6, 0)
		return
	if storage != null:
		var ui2 = scene.get_node_or_null("ui")
		if ui2 != null and ui2.has_method("open_container_inv"):
			ui2.open_container_inv(self, storage, player)
		return
	if data.get("cook", false):
		_try_cook(player)
		return
	if data.get("smelter", false) or data.get("kiln", false):
		_try_insert(player)
		return
	if data.get("station", "") != "":
		var ui3 = scene.get_node_or_null("ui")
		if ui3 != null and ui3.has_method("open_craft"):
			ui3.open_craft(str(data["station"]), player)
		return
	if data.has("crop") and _grown:
		var amt := int(data.get("yield", 3))
		ItemDrop.spawn(scene, global_position + Vector3(0, 0.4, 0),
			str(data["crop"]), amt)
		removed.emit(self)
		queue_free()
		return
	if data.get("portal", false):
		_use_portal(player)

func _try_cook(player) -> void:
	# 완성품 회수 우선
	for i in range(_cook_slots.size() - 1, -1, -1):
		var s: Dictionary = _cook_slots[i]
		if s.get("done", false) or s.get("burnt", false):
			var out: String = "coal" if s.get("burnt", false) else str(s["out"])
			player.inventory.add_item(out, 1)
			player.notify_pickup(out, 1)
			_cook_slots.remove_at(i)
			_refresh_label()
			return
	if _cook_slots.size() >= 4:
		GameState.msg(tr("MSG_STATION_FULL"))
		return
	for raw in RecipeDB.cook:
		if player.inventory.count(raw) > 0:
			player.inventory.remove_item(raw, 1)
			var rec: Dictionary = RecipeDB.cook[raw]
			_cook_slots.append({"id": raw, "out": rec["out"], "t": float(rec["time"]),
				"done": false, "burnt": false})
			Sfx.play_at("fire", global_position, get_tree().current_scene, -16.0)
			_refresh_label()
			return
	GameState.msg(tr("MSG_NOTHING_TO_COOK"))

func _try_insert(player) -> void:
	var table: Dictionary = RecipeDB.smelt if data.get("smelter", false) else RecipeDB.kiln
	if data.has("fuel") and player.inventory.count("coal") > 0 and _smelt_fuel < 20:
		player.inventory.remove_item("coal", 1)
		_smelt_fuel += 1
		Sfx.play_at("build", global_position, get_tree().current_scene, -16.0)
		_refresh_label()
		return
	if _smelt_in.size() >= 10:
		GameState.msg(tr("MSG_STATION_FULL"))
		return
	for ore in table:
		if player.inventory.count(ore) > 0:
			player.inventory.remove_item(ore, 1)
			_smelt_in.append(ore)
			Sfx.play_at("build", global_position, get_tree().current_scene, -16.0)
			_refresh_label()
			return
	GameState.msg(tr("MSG_NOTHING_TO_SMELT"))

func _use_portal(player) -> void:
	var others: Array = []
	for p in get_tree().get_nodes_in_group("build_piece"):
		if p != self and is_instance_valid(p) and p.data.get("portal", false):
			others.append(p)
	if others.is_empty():
		GameState.msg(tr("MSG_NO_PORTAL"))
		return
	# 포탈로 못 가져가는 물건 확인
	for i in player.inventory.size():
		var s: Dictionary = player.inventory.get_slot(i)
		if not s.is_empty() and not ItemDB.is_teleportable(s["id"]):
			GameState.msg(tr("MSG_PORTAL_BLOCKED") % ItemDB.name_of(s["id"]))
			Sfx.play("error", -8.0)
			return
	var dest: BuildPiece = others[0]
	Sfx.play("portal", -2.0)
	player.global_position = dest.global_position + Vector3(0, 1.0, 0) \
		+ Vector3(0, 0, 1.5).rotated(Vector3.UP, dest.yaw)
	Fx.burst(get_tree().current_scene, player.global_position, Color(0.4, 0.9, 1.0),
		40, 6.0, 0.12, 1.2)

# ═══════════════════════════════════════════════ 내구도
func take_hit(dmg: Dictionary, from_pos: Vector3, attacker = null,
		_kb: float = 0.0) -> void:
	var total := 0.0
	for k in dmg:
		# 나무 구조물은 도끼(CHOP)에, 석재는 곡괭이에 약하다
		if k == Const.Dmg.CHOP and not data.get("stone", false):
			total += float(dmg[k])
		elif k == Const.Dmg.PICKAXE and data.get("stone", false):
			total += float(dmg[k])
		else:
			total += float(dmg[k]) * 0.5
	hp -= total
	Fx.burst(get_tree().current_scene, from_pos, _material_color(), 8, 2.5, 0.06, 0.6)
	Sfx.play_at("build", from_pos, get_tree().current_scene, -8.0, 1.2)
	if hp <= 0.0:
		destroy(true)

func destroy(drop_mats: bool) -> void:
	if drop_mats:
		var mats: Dictionary = data.get("mats", {})
		for id in mats:
			var amt := maxi(1, int(mats[id]) / 2)
			ItemDrop.spawn(get_tree().current_scene, global_position + Vector3(0, 0.4, 0),
				id, amt)
	if storage != null:
		for i in storage.size():
			var s: Dictionary = storage.get_slot(i)
			if not s.is_empty():
				ItemDrop.spawn(get_tree().current_scene,
					global_position + Vector3(0, 0.6, 0), s["id"], int(s["amount"]),
					int(s.get("quality", 1)))
	Fx.burst(get_tree().current_scene, global_position, _material_color(), 20, 4.0, 0.1, 1.0)
	Sfx.play_at("build", global_position, get_tree().current_scene, -4.0, 0.7)
	removed.emit(self)
	queue_free()

func to_dict() -> Dictionary:
	var d := {"id": piece_id, "p": [global_position.x, global_position.y, global_position.z],
		"y": yaw, "hp": hp}
	if storage != null:
		d["inv"] = storage.to_dict()
	if not _smelt_in.is_empty():
		d["smelt"] = _smelt_in.duplicate()
		d["fuel"] = _smelt_fuel
	if _grown:
		d["grown"] = true
	return d

func from_dict(d: Dictionary) -> void:
	hp = float(d.get("hp", max_hp))
	yaw = float(d.get("y", 0.0))
	if storage != null and d.has("inv"):
		storage.from_dict(d["inv"])
	if d.has("smelt"):
		_smelt_in = d["smelt"].duplicate()
		_smelt_fuel = int(d.get("fuel", 0))
	if bool(d.get("grown", false)):
		_grown = true
		_grow_t = 0.0
		_update_plant_visual()
