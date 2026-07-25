class_name EnemyDB
extends RefCounted
## 몬스터 도감. 바이옴별 등장 · 능력치 · 드롭.

const B := Const.Biome
const D := Const.Dmg

static var _db: Dictionary = {}

static func all() -> Dictionary:
	if _db.is_empty():
		_build()
	return _db

static func get_cfg(id: String) -> Dictionary:
	return all().get(id, {})

static func in_biome(biome: int, night: bool) -> Array:
	var out: Array = []
	for id in all():
		var c: Dictionary = all()[id]
		if not (biome in c.get("biomes", [])):
			continue
		if c.get("night_only", false) and not night:
			continue
		if c.get("day_only", false) and night:
			continue
		out.append(id)
	return out

static func _e(id: String, d: Dictionary) -> void:
	d["id"] = id
	if not d.has("n"):
		d["n"] = "MOB_" + id.to_upper()
	if not d.has("speed"): d["speed"] = 2.2
	if not d.has("run"): d["run"] = 3.6
	if not d.has("range"): d["range"] = 2.0
	if not d.has("cd"): d["cd"] = 2.0
	if not d.has("aggro"): d["aggro"] = 22.0
	if not d.has("size"): d["size"] = 1.0
	if not d.has("armor"): d["armor"] = 0.0
	if not d.has("kb"): d["kb"] = 25.0
	if not d.has("drops"): d["drops"] = {}
	_db[id] = d

static func _build() -> void:
	# ═══════════ 초원 ═══════════
	_e("greyling", {
		"biomes": [B.MEADOWS], "tier": 0, "hp": 20.0, "dmg": {D.SLASH: 8.0},
		"speed": 1.9, "run": 3.1, "range": 1.9, "cd": 2.0, "size": 0.85,
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.34, 0.40, 0.28),
			"cloth": Color(0.28, 0.33, 0.24), "height": 1.35, "mossy": true,
			"eye": Color(0.95, 0.85, 0.30)},
		"drops": {"wood": [1, 2, 0.6], "resin": [1, 1, 0.4],
			"greydwarf_eye": [1, 1, 0.3]},
		"trophy": ["trophy_greyling", 0.07],
	})
	_e("neck", {
		"biomes": [B.MEADOWS, B.SWAMP], "tier": 0, "hp": 12.0, "dmg": {D.SLASH: 5.0},
		"speed": 2.4, "run": 4.0, "range": 1.6, "cd": 1.6, "size": 0.55,
		"rig": "quad", "rig_cfg": {"fur": Color(0.36, 0.52, 0.36), "length": 1.0,
			"height": 0.5, "girth": 0.30, "head": 0.24, "tail": 0.7, "horn": "none"},
		"drops": {"neck_tail": [1, 1, 0.9], "leather_scraps": [1, 2, 0.5]},
		"trophy": ["trophy_neck", 0.07],
	})
	_e("boar", {
		"biomes": [B.MEADOWS], "tier": 0, "hp": 30.0, "dmg": {D.SLASH: 10.0},
		"speed": 2.0, "run": 4.6, "range": 1.7, "cd": 2.2, "size": 0.8,
		"passive": true,
		"rig": "quad", "rig_cfg": {"fur": Color(0.42, 0.30, 0.20), "length": 1.3,
			"height": 0.85, "girth": 0.55, "head": 0.30, "horn": "tusk", "tail": 0.25},
		"drops": {"boar_meat": [1, 2, 1.0], "leather_scraps": [1, 3, 0.8]},
		"trophy": ["trophy_boar", 0.10],
		"tame": {"food": ["raspberries", "blueberries", "carrot", "turnip", "mushroom"],
			"needed": 3, "baby": "boar"},
	})
	_e("deer", {
		"biomes": [B.MEADOWS, B.BLACKFOREST], "tier": 0, "hp": 30.0, "dmg": {D.BLUNT: 6.0},
		"speed": 3.0, "run": 7.0, "range": 1.8, "cd": 2.5, "size": 1.0,
		"flee": true,
		"rig": "quad", "rig_cfg": {"fur": Color(0.62, 0.45, 0.28), "length": 1.7,
			"height": 1.35, "girth": 0.55, "head": 0.30, "horn": "antler",
			"neck": 0.55, "tail": 0.2},
		"drops": {"deer_meat": [2, 3, 1.0], "deer_hide": [1, 2, 0.9]},
		"trophy": ["trophy_deer", 0.15],
	})

	# ═══════════ 검은 숲 ═══════════
	_e("greydwarf", {
		"biomes": [B.BLACKFOREST], "tier": 1, "hp": 40.0, "dmg": {D.SLASH: 15.0},
		"speed": 2.2, "run": 3.7, "range": 2.0, "cd": 1.8, "size": 1.0,
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.30, 0.36, 0.26),
			"cloth": Color(0.24, 0.30, 0.22), "height": 1.7, "mossy": true,
			"eye": Color(0.95, 0.85, 0.30)},
		"drops": {"wood": [1, 2, 0.6], "stone": [1, 2, 0.4],
			"resin": [1, 2, 0.5], "greydwarf_eye": [1, 2, 0.7]},
		"trophy": ["trophy_greydwarf", 0.08],
	})
	_e("greydwarf_brute", {
		"biomes": [B.BLACKFOREST], "tier": 1, "hp": 120.0, "dmg": {D.BLUNT: 32.0},
		"speed": 1.9, "run": 3.2, "range": 2.4, "cd": 2.6, "size": 1.4, "armor": 4.0,
		"kb": 45.0,
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.26, 0.32, 0.22),
			"cloth": Color(0.20, 0.26, 0.18), "height": 2.3, "bulk": 1.5,
			"mossy": true, "eye": Color(1.0, 0.55, 0.20)},
		"drops": {"wood": [2, 4, 0.8], "resin": [2, 4, 0.8],
			"stone": [2, 4, 0.5], "fine_wood": [1, 2, 0.3]},
		"trophy": ["trophy_greydwarf", 0.12],
	})
	_e("greydwarf_shaman", {
		"biomes": [B.BLACKFOREST], "tier": 1, "hp": 90.0, "dmg": {D.POISON: 20.0},
		"speed": 2.0, "run": 3.4, "range": 14.0, "cd": 3.0, "size": 1.05,
		"ranged": {"speed": 22.0, "color": Color(0.4, 0.9, 0.35)},
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.34, 0.42, 0.28),
			"cloth": Color(0.45, 0.35, 0.55), "height": 1.75, "mossy": true,
			"horns": true, "eye": Color(0.6, 1.0, 0.4)},
		"drops": {"greydwarf_eye": [2, 3, 0.9], "resin": [1, 3, 0.5]},
		"trophy": ["trophy_greydwarf", 0.10],
	})
	_e("troll", {
		"biomes": [B.BLACKFOREST], "tier": 2, "hp": 600.0, "dmg": {D.BLUNT: 70.0},
		"speed": 2.2, "run": 4.0, "range": 4.2, "cd": 3.2, "size": 3.0,
		"armor": 12.0, "kb": 120.0, "stagger_hp": 200.0,
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.40, 0.48, 0.42),
			"cloth": Color(0.34, 0.40, 0.35), "height": 4.6, "bulk": 1.6,
			"head": 1.2, "eye": Color(0.95, 0.75, 0.25)},
		"drops": {"troll_hide": [3, 5, 1.0], "coal": [3, 6, 0.8],
			"ancient_bark": [0, 2, 0.3]},
		"trophy": ["trophy_troll", 0.15],
	})
	_e("skeleton", {
		"biomes": [B.BLACKFOREST, B.SWAMP], "tier": 1, "hp": 60.0, "dmg": {D.SLASH: 20.0},
		"speed": 2.1, "run": 3.5, "range": 2.1, "cd": 1.9, "size": 1.0,
		"night_only": true,
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.86, 0.84, 0.76),
			"cloth": Color(0.74, 0.72, 0.66), "height": 1.75,
			"eye": Color(0.9, 0.2, 0.1), "hair": Color(0.7, 0.68, 0.6)},
		"drops": {"bone_fragments": [1, 3, 0.9], "wood_arrow": [0, 5, 0.3]},
		"trophy": ["trophy_skeleton", 0.10],
	})

	# ═══════════ 늪 ═══════════
	_e("draugr", {
		"biomes": [B.SWAMP], "tier": 2, "hp": 150.0, "dmg": {D.SLASH: 35.0},
		"speed": 2.0, "run": 3.6, "range": 2.2, "cd": 2.0, "size": 1.05, "armor": 6.0,
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.38, 0.44, 0.32),
			"cloth": Color(0.26, 0.28, 0.22), "height": 1.85,
			"eye": Color(0.95, 0.85, 0.20), "beard": true},
		"drops": {"entrails": [1, 2, 0.7], "withered_bone": [0, 1, 0.2]},
		"trophy": ["trophy_draugr", 0.08],
	})
	_e("draugr_elite", {
		"biomes": [B.SWAMP], "tier": 3, "hp": 300.0, "dmg": {D.SLASH: 60.0},
		"speed": 2.2, "run": 4.0, "range": 2.5, "cd": 2.2, "size": 1.25, "armor": 12.0,
		"kb": 60.0,
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.30, 0.38, 0.28),
			"cloth": Color(0.20, 0.24, 0.20), "height": 2.1, "bulk": 1.25,
			"eye": Color(1.0, 0.75, 0.15), "beard": true, "horns": true},
		"drops": {"entrails": [2, 3, 0.9], "iron_scrap": [0, 1, 0.15]},
		"trophy": ["trophy_draugr", 0.12],
	})
	_e("blob", {
		"biomes": [B.SWAMP], "tier": 2, "hp": 130.0, "dmg": {D.POISON: 30.0, D.BLUNT: 10.0},
		"speed": 1.3, "run": 1.9, "range": 2.0, "cd": 2.4, "size": 1.0, "armor": 4.0,
		"rig": "blob", "rig_cfg": {"color": Color(0.32, 0.72, 0.36), "size": 0.75},
		"drops": {"guck": [1, 2, 0.6], "ooze": [0, 0, 0.0]},
		"trophy": ["trophy_blob", 0.10],
	})
	_e("oozer", {
		"biomes": [B.SWAMP], "tier": 3, "hp": 260.0, "dmg": {D.POISON: 50.0, D.BLUNT: 18.0},
		"speed": 1.2, "run": 1.8, "range": 2.6, "cd": 2.6, "size": 1.6, "armor": 8.0,
		"rig": "blob", "rig_cfg": {"color": Color(0.22, 0.55, 0.28), "size": 1.15},
		"drops": {"guck": [2, 4, 0.9], "iron_scrap": [0, 1, 0.1]},
		"trophy": ["trophy_blob", 0.14],
	})
	_e("wraith", {
		"biomes": [B.SWAMP], "tier": 3, "hp": 150.0, "dmg": {D.SLASH: 55.0, D.SPIRIT: 20.0},
		"speed": 2.6, "run": 4.4, "range": 2.3, "cd": 2.2, "size": 1.2,
		"night_only": true, "flying": true,
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.55, 0.60, 0.68),
			"cloth": Color(0.20, 0.22, 0.28), "height": 2.1,
			"eye": Color(0.9, 0.95, 1.0)},
		"drops": {"chain": [1, 1, 0.4], "withered_bone": [0, 1, 0.2]},
		"trophy": ["trophy_wraith", 0.15],
	})
	_e("surtling", {
		"biomes": [B.SWAMP, B.ASHLANDS], "tier": 2, "hp": 60.0,
		"dmg": {D.FIRE: 30.0}, "speed": 1.6, "run": 2.4, "range": 12.0, "cd": 2.6,
		"size": 0.7, "ranged": {"speed": 18.0, "color": Color(1.0, 0.45, 0.10)},
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.95, 0.35, 0.10),
			"cloth": Color(0.30, 0.10, 0.06), "height": 1.1,
			"eye": Color(1.0, 0.9, 0.4)},
		"glow": Color(1.0, 0.45, 0.12),
		"drops": {"surtling_core": [1, 1, 0.5], "coal": [1, 3, 0.8]},
	})
	_e("leech", {
		"biomes": [B.SWAMP], "tier": 2, "hp": 90.0, "dmg": {D.PIERCE: 40.0, D.POISON: 20.0},
		"speed": 1.8, "run": 2.8, "range": 1.8, "cd": 2.2, "size": 0.7, "water": true,
		"rig": "blob", "rig_cfg": {"color": Color(0.55, 0.14, 0.18), "size": 0.5},
		"drops": {"bloodbag": [1, 2, 0.9]},
	})

	# ═══════════ 산 ═══════════
	_e("wolf", {
		"biomes": [B.MOUNTAIN], "tier": 3, "hp": 160.0, "dmg": {D.SLASH: 50.0},
		"speed": 3.2, "run": 6.4, "range": 2.0, "cd": 1.7, "size": 1.0,
		"rig": "quad", "rig_cfg": {"fur": Color(0.82, 0.84, 0.88), "length": 1.5,
			"height": 1.0, "girth": 0.42, "head": 0.28, "horn": "ear",
			"eye": Color(0.9, 0.75, 0.2), "tail": 0.45},
		"drops": {"wolf_meat": [1, 2, 0.9], "wolf_pelt": [1, 2, 0.9],
			"wolf_fang": [0, 1, 0.4], "bone_fragments": [1, 2, 0.6]},
		"trophy": ["trophy_wolf", 0.10],
		"tame": {"food": ["boar_meat", "deer_meat", "cooked_boar_meat",
			"cooked_deer_meat", "neck_tail"], "needed": 5, "baby": "wolf"},
	})
	_e("fenring", {
		"biomes": [B.MOUNTAIN], "tier": 4, "hp": 220.0, "dmg": {D.SLASH: 65.0},
		"speed": 3.0, "run": 6.0, "range": 2.3, "cd": 1.8, "size": 1.2,
		"night_only": true,
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.30, 0.30, 0.34),
			"cloth": Color(0.22, 0.22, 0.26), "height": 2.1, "bulk": 1.1,
			"eye": Color(1.0, 0.30, 0.15), "horns": true},
		"drops": {"wolf_pelt": [1, 2, 0.7], "wolf_fang": [1, 2, 0.6]},
		"trophy": ["trophy_wolf", 0.12],
	})
	_e("drake", {
		"biomes": [B.MOUNTAIN], "tier": 3, "hp": 100.0, "dmg": {D.FROST: 55.0},
		"speed": 3.4, "run": 5.4, "range": 20.0, "cd": 3.0, "size": 1.0,
		"flying": true, "ranged": {"speed": 24.0, "color": Color(0.6, 0.9, 1.0)},
		"rig": "flyer", "rig_cfg": {"color": Color(0.68, 0.86, 0.94), "size": 1.1,
			"wing": 1.6},
		"drops": {"freeze_gland": [1, 2, 0.9], "dragon_egg": [0, 1, 0.02]},
		"trophy": ["trophy_drake", 0.10],
	})
	_e("stone_golem", {
		"biomes": [B.MOUNTAIN], "tier": 4, "hp": 800.0, "dmg": {D.BLUNT: 90.0},
		"speed": 1.6, "run": 2.6, "range": 3.6, "cd": 3.6, "size": 2.4,
		"armor": 30.0, "kb": 150.0, "stagger_hp": 300.0,
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.52, 0.56, 0.60),
			"cloth": Color(0.44, 0.48, 0.52), "height": 3.6, "bulk": 1.7,
			"head": 0.8, "eye": Color(0.4, 0.8, 1.0)},
		"drops": {"stone": [4, 8, 1.0], "crystal": [1, 3, 0.6]},
		"trophy": ["trophy_golem", 0.15],
	})

	# ═══════════ 평원 ═══════════
	_e("fuling", {
		"biomes": [B.PLAINS], "tier": 4, "hp": 200.0, "dmg": {D.SLASH: 70.0},
		"speed": 2.6, "run": 4.6, "range": 2.2, "cd": 1.9, "size": 0.9, "armor": 10.0,
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.55, 0.50, 0.28),
			"cloth": Color(0.40, 0.30, 0.18), "height": 1.55,
			"eye": Color(0.95, 0.30, 0.20)},
		"drops": {"coins": [0, 0, 0.0], "black_metal_scrap": [0, 1, 0.15],
			"bone_fragments": [1, 2, 0.5]},
		"trophy": ["trophy_fuling", 0.08],
	})
	_e("fuling_berserker", {
		"biomes": [B.PLAINS], "tier": 5, "hp": 500.0, "dmg": {D.SLASH: 110.0},
		"speed": 2.8, "run": 5.2, "range": 3.0, "cd": 2.4, "size": 1.5,
		"armor": 20.0, "kb": 90.0, "stagger_hp": 200.0,
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.48, 0.44, 0.24),
			"cloth": Color(0.34, 0.24, 0.14), "height": 2.5, "bulk": 1.5,
			"eye": Color(1.0, 0.25, 0.15), "horns": true},
		"drops": {"black_metal_scrap": [1, 3, 0.8], "bone_fragments": [2, 4, 0.6]},
		"trophy": ["trophy_fuling", 0.12],
	})
	_e("fuling_shaman", {
		"biomes": [B.PLAINS], "tier": 4, "hp": 220.0, "dmg": {D.FIRE: 60.0},
		"speed": 2.4, "run": 4.2, "range": 16.0, "cd": 3.0, "size": 0.95,
		"ranged": {"speed": 24.0, "color": Color(1.0, 0.55, 0.20)},
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.58, 0.52, 0.30),
			"cloth": Color(0.62, 0.24, 0.18), "height": 1.6, "horns": true,
			"eye": Color(1.0, 0.85, 0.30)},
		"drops": {"black_metal_scrap": [0, 1, 0.3], "thistle": [1, 2, 0.4]},
		"trophy": ["trophy_fuling", 0.10],
	})
	_e("deathsquito", {
		"biomes": [B.PLAINS], "tier": 4, "hp": 10.0, "dmg": {D.PIERCE: 90.0},
		"speed": 5.0, "run": 8.0, "range": 2.0, "cd": 2.2, "size": 0.5,
		"flying": true, "aggro": 30.0,
		"rig": "flyer", "rig_cfg": {"color": Color(0.75, 0.72, 0.30), "size": 0.55,
			"wing": 0.7},
		"drops": {"needle": [1, 2, 0.9]},
		"trophy": ["trophy_deathsquito", 0.10],
	})
	_e("lox", {
		"biomes": [B.PLAINS], "tier": 5, "hp": 1000.0, "dmg": {D.BLUNT: 90.0},
		"speed": 1.8, "run": 3.6, "range": 3.4, "cd": 3.0, "size": 2.2,
		"armor": 25.0, "kb": 140.0, "passive": true, "stagger_hp": 350.0,
		"rig": "quad", "rig_cfg": {"fur": Color(0.46, 0.32, 0.20), "length": 3.2,
			"height": 2.2, "girth": 1.4, "head": 0.75, "horn": "tusk", "tail": 0.4},
		"drops": {"lox_meat": [2, 4, 1.0], "lox_pelt": [2, 4, 0.9]},
		"trophy": ["trophy_lox", 0.10],
		"tame": {"food": ["barley", "cloudberry", "flax"], "needed": 6, "baby": "lox"},
	})

	# ═══════════ 미스트랜드 ═══════════
	_e("seeker", {
		"biomes": [B.MISTLANDS], "tier": 5, "hp": 500.0, "dmg": {D.PIERCE: 110.0},
		"speed": 3.0, "run": 5.6, "range": 2.6, "cd": 2.0, "size": 1.4, "armor": 25.0,
		"rig": "quad", "rig_cfg": {"fur": Color(0.30, 0.32, 0.22), "length": 2.0,
			"height": 1.4, "girth": 0.75, "head": 0.45, "horn": "tusk",
			"eye": Color(1.0, 0.85, 0.20), "tail": 0.5},
		"drops": {"carapace": [1, 3, 0.8], "mandible": [0, 1, 0.2]},
		"trophy": ["trophy_seeker", 0.10],
	})
	_e("seeker_soldier", {
		"biomes": [B.MISTLANDS], "tier": 6, "hp": 900.0, "dmg": {D.BLUNT: 130.0},
		"speed": 2.4, "run": 4.4, "range": 3.0, "cd": 2.6, "size": 1.9, "armor": 40.0,
		"kb": 120.0, "stagger_hp": 400.0,
		"rig": "quad", "rig_cfg": {"fur": Color(0.24, 0.26, 0.18), "length": 2.6,
			"height": 1.8, "girth": 1.0, "head": 0.6, "horn": "tusk",
			"eye": Color(1.0, 0.6, 0.15), "tail": 0.5},
		"drops": {"carapace": [2, 4, 0.9], "mandible": [1, 1, 0.4]},
		"trophy": ["trophy_seeker", 0.14],
	})
	_e("gjall", {
		"biomes": [B.MISTLANDS], "tier": 6, "hp": 700.0, "dmg": {D.FIRE: 120.0},
		"speed": 2.2, "run": 3.4, "range": 22.0, "cd": 3.4, "size": 2.4,
		"flying": true, "ranged": {"speed": 20.0, "color": Color(1.0, 0.50, 0.15)},
		"rig": "flyer", "rig_cfg": {"color": Color(0.55, 0.32, 0.18), "size": 2.2,
			"wing": 2.4},
		"drops": {"sap": [1, 3, 0.8], "eitr": [1, 2, 0.4]},
	})
	_e("tick", {
		"biomes": [B.MISTLANDS], "tier": 5, "hp": 120.0,
		"dmg": {D.PIERCE: 70.0, D.POISON: 20.0},
		"speed": 3.6, "run": 6.2, "range": 1.8, "cd": 1.6, "size": 0.6,
		"rig": "quad", "rig_cfg": {"fur": Color(0.42, 0.30, 0.26), "length": 0.9,
			"height": 0.6, "girth": 0.45, "head": 0.25, "tail": 0.1},
		"drops": {"soft_tissue": [0, 1, 0.3]},
	})

	# ═══════════ 애쉬랜드 ═══════════
	_e("charred_warrior", {
		"biomes": [B.ASHLANDS], "tier": 6, "hp": 700.0,
		"dmg": {D.SLASH: 130.0, D.FIRE: 30.0},
		"speed": 2.6, "run": 4.8, "range": 2.5, "cd": 2.0, "size": 1.1, "armor": 35.0,
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.22, 0.18, 0.16),
			"cloth": Color(0.30, 0.14, 0.10), "height": 1.9,
			"eye": Color(1.0, 0.40, 0.10)},
		"glow": Color(1.0, 0.35, 0.08),
		"drops": {"charred_bone": [1, 3, 0.9], "flametal_ore": [0, 1, 0.1]},
	})
	_e("morgen", {
		"biomes": [B.ASHLANDS], "tier": 7, "hp": 1400.0, "dmg": {D.BLUNT: 170.0},
		"speed": 2.0, "run": 3.6, "range": 4.0, "cd": 3.2, "size": 2.6,
		"armor": 50.0, "kb": 160.0, "stagger_hp": 500.0,
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.42, 0.20, 0.18),
			"cloth": Color(0.28, 0.12, 0.10), "height": 4.0, "bulk": 1.6,
			"head": 1.0, "eye": Color(1.0, 0.6, 0.2)},
		"drops": {"morgen_sinew": [1, 3, 0.9], "blood_clot": [1, 2, 0.7]},
	})
	_e("volture", {
		"biomes": [B.ASHLANDS], "tier": 6, "hp": 300.0, "dmg": {D.PIERCE: 100.0},
		"speed": 4.0, "run": 6.6, "range": 2.2, "cd": 2.0, "size": 1.3,
		"flying": true,
		"rig": "flyer", "rig_cfg": {"color": Color(0.42, 0.20, 0.15), "size": 1.3,
			"wing": 1.9},
		"drops": {"charred_bone": [1, 2, 0.6], "feathers": [1, 3, 0.7]},
	})

	# ═══════════ 확장: 추가 생물 ═══════════
	_e("chicken", {
		"biomes": [B.MEADOWS], "tier": 0, "hp": 10.0, "dmg": {D.PIERCE: 3.0},
		"speed": 2.6, "run": 5.0, "range": 1.2, "cd": 2.0, "size": 0.4,
		"passive": true, "flee": true,
		"rig": "quad", "rig_cfg": {"fur": Color(0.90, 0.86, 0.76), "length": 0.5,
			"height": 0.42, "girth": 0.24, "head": 0.16, "tail": 0.3, "horn": "none"},
		"drops": {"boar_meat": [1, 1, 0.8], "feathers": [1, 3, 0.9]},
		"tame": {"food": ["barley", "carrot", "onion"], "needed": 2, "baby": "chicken"},
	})
	_e("bat", {
		"biomes": [B.BLACKFOREST, B.MOUNTAIN], "tier": 1, "hp": 22.0,
		"dmg": {D.SLASH: 14.0}, "speed": 4.4, "run": 7.0, "range": 1.6, "cd": 1.4,
		"size": 0.5, "flying": true, "night_only": true,
		"rig": "flyer", "rig_cfg": {"color": Color(0.30, 0.24, 0.28), "size": 0.5,
			"wing": 0.9},
		"drops": {"bat_wing": [1, 2, 0.7], "leather_scraps": [1, 1, 0.3]},
		"trophy": ["trophy_bat", 0.06],
	})
	_e("serpent", {
		"biomes": [B.OCEAN], "tier": 3, "hp": 500.0, "dmg": {D.SLASH: 70.0},
		"speed": 3.4, "run": 5.4, "range": 3.6, "cd": 2.8, "size": 2.4,
		"armor": 20.0, "kb": 90.0,
		"rig": "quad", "rig_cfg": {"fur": Color(0.24, 0.46, 0.42), "length": 4.5,
			"height": 1.2, "girth": 0.7, "head": 0.55, "neck": 1.6, "tail": 2.4,
			"horn": "none"},
		"drops": {"serpent_meat": [2, 4, 1.0], "serpent_scale": [3, 6, 0.9],
			"serpent_trophy_scale": [0, 1, 0.2]},
		"trophy": ["trophy_serpent", 0.15],
	})
	_e("hare", {
		"biomes": [B.MISTLANDS], "tier": 5, "hp": 90.0, "dmg": {D.BLUNT: 12.0},
		"speed": 4.2, "run": 8.0, "range": 1.4, "cd": 2.0, "size": 0.5,
		"passive": true, "flee": true,
		"rig": "quad", "rig_cfg": {"fur": Color(0.74, 0.72, 0.70), "length": 0.7,
			"height": 0.55, "girth": 0.28, "head": 0.22, "tail": 0.2, "horn": "none"},
		"drops": {"boar_meat": [1, 2, 0.9], "leather_scraps": [1, 2, 0.6]},
		"trophy": ["trophy_hare", 0.10],
	})
	_e("dvergr", {
		"biomes": [B.MISTLANDS], "tier": 5, "hp": 260.0, "dmg": {D.SLASH: 70.0},
		"speed": 2.2, "run": 3.8, "range": 2.2, "cd": 2.2, "size": 1.0,
		"armor": 12.0,
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.72, 0.62, 0.52),
			"cloth": Color(0.30, 0.34, 0.42), "height": 1.55, "bulk": 1.2,
			"beard": true, "eye": Color(0.6, 0.85, 1.0)},
		"drops": {"eitr": [1, 2, 0.4], "yggdrasil_wood": [1, 3, 0.6],
			"coins": [10, 40, 0.8]},
		"trophy": ["trophy_dvergr", 0.08],
	})
	_e("asksvin", {
		"biomes": [B.ASHLANDS], "tier": 6, "hp": 420.0, "dmg": {D.PIERCE: 110.0},
		"speed": 3.2, "run": 6.2, "range": 2.6, "cd": 2.4, "size": 1.8,
		"armor": 18.0, "kb": 80.0,
		"rig": "quad", "rig_cfg": {"fur": Color(0.58, 0.46, 0.36), "length": 2.6,
			"height": 1.7, "girth": 0.6, "head": 0.42, "neck": 0.9, "tail": 1.4,
			"horn": "none"},
		"drops": {"charred_bone": [2, 4, 0.8], "leather_scraps": [2, 4, 0.7]},
		"trophy": ["trophy_asksvin", 0.10],
	})
	_e("charred_archer", {
		"biomes": [B.ASHLANDS], "tier": 6, "hp": 260.0, "dmg": {D.PIERCE: 90.0},
		"speed": 2.0, "run": 3.4, "range": 22.0, "cd": 2.6, "size": 1.0,
		"ranged": true,
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.28, 0.20, 0.18),
			"cloth": Color(0.20, 0.12, 0.10), "height": 1.85,
			"eye": Color(1.0, 0.5, 0.15)},
		"glow": Color(1.0, 0.35, 0.08),
		"drops": {"charred_bone": [1, 3, 0.9], "coal": [1, 3, 0.6]},
		"trophy": ["trophy_charred", 0.08],
	})
	_e("skeleton_archer", {
		"biomes": [B.BLACKFOREST, B.SWAMP], "tier": 2, "hp": 70.0,
		"dmg": {D.PIERCE: 40.0}, "speed": 1.9, "run": 3.0, "range": 20.0, "cd": 2.8,
		"size": 1.0, "ranged": true,
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.86, 0.84, 0.76),
			"cloth": Color(0.42, 0.38, 0.30), "height": 1.8,
			"eye": Color(0.20, 0.75, 0.55)},
		"drops": {"bone_fragments": [1, 3, 0.9], "wood_arrow": [3, 8, 0.6]},
		"trophy": ["trophy_skeleton", 0.06],
	})
