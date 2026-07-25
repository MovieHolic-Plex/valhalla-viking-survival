extends Node
## 제작 · 요리 · 제련 · 건축 레시피. 오토로드 이름: RecipeDB

## 제작대 종류
const ST_NONE := ""
const ST_WORKBENCH := "workbench"
const ST_FORGE := "forge"
const ST_CAULDRON := "cauldron"
const ST_ARTISAN := "artisan_table"
const ST_STONECUTTER := "stonecutter"

## 제작 레시피: {out, amount, station, level, mats:{}}
var craft: Array[Dictionary] = []
## 요리대 레시피: raw -> {out, time}
var cook: Dictionary = {}
## 제련소/가마: 입력 -> {out, time}
var smelt: Dictionary = {}
var kiln: Dictionary = {}
## 건축 조각 정의
var pieces: Dictionary = {}
var piece_order: Array[String] = []

func _ready() -> void:
	_build_craft()
	_build_cook()
	_build_smelt()
	_build_pieces()

# ────────────────────────────────────────────────────────── 제작
func _c(out: String, mats: Dictionary, station: String = ST_NONE, level: int = 1, amount: int = 1) -> void:
	craft.append({"out": out, "amount": amount, "station": station, "level": level, "mats": mats})

func recipes_for_station(station: String, level: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in craft:
		if r["station"] == station and int(r["level"]) <= level:
			out.append(r)
	return out

func recipe_of(item_id: String) -> Dictionary:
	for r in craft:
		if r["out"] == item_id:
			return r
	return {}

func _build_craft() -> void:
	# 맨손 제작
	_c("hammer", {"wood": 3, "stone": 2})
	_c("torch", {"wood": 1, "resin": 1})
	_c("club", {"wood": 6})
	_c("stone_axe", {"wood": 5, "stone": 4})
	_c("hoe", {"wood": 5, "stone": 2}, ST_WORKBENCH)
	_c("cultivator", {"core_wood": 5, "bronze": 5}, ST_FORGE)

	# 작업대 lv1
	_c("flint_axe", {"wood": 4, "flint": 6}, ST_WORKBENCH)
	_c("flint_spear", {"wood": 5, "flint": 10, "leather_scraps": 2}, ST_WORKBENCH)
	_c("flint_knife", {"wood": 2, "flint": 4, "leather_scraps": 2}, ST_WORKBENCH)
	_c("crude_bow", {"wood": 10, "leather_scraps": 8}, ST_WORKBENCH)
	_c("wood_arrow", {"wood": 8}, ST_WORKBENCH, 1, 20)
	_c("flint_arrow", {"wood": 8, "flint": 8, "feathers": 2}, ST_WORKBENCH, 1, 20)
	_c("fire_arrow", {"wood": 8, "resin": 8, "feathers": 2}, ST_WORKBENCH, 1, 20)
	_c("wood_shield", {"wood": 10, "leather_scraps": 6}, ST_WORKBENCH)
	_c("rag_hood", {"leather_scraps": 4}, ST_WORKBENCH)
	_c("rag_tunic", {"leather_scraps": 6}, ST_WORKBENCH)
	_c("antler_pickaxe", {"hard_antler": 1, "wood": 10}, ST_WORKBENCH)

	# 작업대 lv2 — 가죽/사슴
	_c("leather_helmet", {"deer_hide": 6, "bone_fragments": 8}, ST_WORKBENCH, 2)
	_c("leather_tunic", {"deer_hide": 8, "bone_fragments": 10}, ST_WORKBENCH, 2)
	_c("leather_pants", {"deer_hide": 8, "bone_fragments": 10}, ST_WORKBENCH, 2)
	_c("deer_cape", {"deer_hide": 4, "bone_fragments": 5}, ST_WORKBENCH, 2)
	_c("finewood_bow", {"fine_wood": 10, "core_wood": 10, "deer_hide": 2}, ST_WORKBENCH, 2)

	# 작업대 lv3 — 트롤 가죽
	_c("troll_hood", {"troll_hide": 5, "bone_fragments": 5}, ST_WORKBENCH, 3)
	_c("troll_tunic", {"troll_hide": 10, "bone_fragments": 5}, ST_WORKBENCH, 3)
	_c("troll_pants", {"troll_hide": 10, "bone_fragments": 5}, ST_WORKBENCH, 3)
	_c("troll_cape", {"troll_hide": 10, "bone_fragments": 10}, ST_WORKBENCH, 3)
	_c("banded_shield", {"fine_wood": 10, "iron": 4}, ST_WORKBENCH, 3)
	_c("huntsman_bow", {"fine_wood": 10, "iron": 20, "feathers": 10}, ST_WORKBENCH, 4)
	_c("draugr_fang", {"ancient_bark": 20, "silver": 10, "deer_hide": 2, "guck": 10}, ST_WORKBENCH, 4)

	# 대장간 (청동/철/은/흑금속)
	_c("bronze", {"copper": 1, "tin": 1}, ST_FORGE)
	_c("bronze_nails", {"bronze": 1}, ST_FORGE, 1, 20)
	_c("iron_nails", {"iron": 1}, ST_FORGE, 1, 20)
	_c("bronze_axe", {"wood": 4, "bronze": 8}, ST_FORGE)
	_c("bronze_pickaxe", {"core_wood": 3, "bronze": 10}, ST_FORGE)
	_c("bronze_sword", {"wood": 2, "bronze": 8, "leather_scraps": 2}, ST_FORGE)
	_c("bronze_mace", {"wood": 4, "bronze": 8, "leather_scraps": 2}, ST_FORGE)
	_c("bronze_atgeir", {"core_wood": 10, "bronze": 8, "deer_hide": 2}, ST_FORGE)
	_c("bronze_arrow", {"wood": 8, "bronze": 1, "feathers": 2}, ST_FORGE, 1, 20)
	_c("bronze_helmet", {"bronze": 5, "deer_hide": 2}, ST_FORGE)
	_c("bronze_cuirass", {"bronze": 5, "deer_hide": 2}, ST_FORGE)
	_c("bronze_greaves", {"bronze": 5, "deer_hide": 2}, ST_FORGE)

	_c("iron_axe", {"core_wood": 4, "iron": 8}, ST_FORGE, 2)
	_c("iron_pickaxe", {"core_wood": 3, "iron": 10}, ST_FORGE, 2)
	_c("iron_sword", {"wood": 2, "iron": 20, "leather_scraps": 3}, ST_FORGE, 2)
	_c("iron_mace", {"wood": 4, "iron": 20, "leather_scraps": 3}, ST_FORGE, 2)
	_c("iron_atgeir", {"core_wood": 10, "iron": 20, "deer_hide": 2}, ST_FORGE, 2)
	_c("iron_spear", {"core_wood": 6, "iron": 10, "leather_scraps": 3}, ST_FORGE, 2)
	_c("iron_buckler", {"iron": 10}, ST_FORGE, 2)
	_c("iron_arrow", {"wood": 8, "iron": 1, "feathers": 2}, ST_FORGE, 2, 20)
	_c("iron_helmet", {"iron": 20, "deer_hide": 2}, ST_FORGE, 2)
	_c("iron_scale_mail", {"iron": 20, "deer_hide": 2}, ST_FORGE, 2)
	_c("iron_greaves", {"iron": 20, "deer_hide": 2}, ST_FORGE, 2)
	_c("chain", {"iron": 10}, ST_FORGE, 2)

	_c("silver_sword", {"wood": 2, "silver": 40, "leather_scraps": 5}, ST_FORGE, 3)
	_c("silver_mace", {"wood": 4, "silver": 40, "leather_scraps": 5}, ST_FORGE, 3)
	_c("frostner", {"ancient_bark": 10, "silver": 30, "freeze_gland": 5, "iron": 5}, ST_FORGE, 3)
	_c("silver_shield", {"silver": 8, "fine_wood": 10}, ST_FORGE, 3)
	_c("wolf_headdress", {"wolf_pelt": 5, "silver": 20, "wolf_fang": 2}, ST_FORGE, 3)
	_c("wolf_armor_chest", {"silver": 20, "wolf_pelt": 5, "chain": 1}, ST_FORGE, 3)
	_c("wolf_armor_legs", {"silver": 20, "wolf_pelt": 5, "chain": 1}, ST_FORGE, 3)
	_c("wolf_cape", {"wolf_pelt": 6, "silver": 4, "wolf_fang": 4}, ST_FORGE, 3)
	_c("obsidian_arrow", {"wood": 8, "obsidian": 4, "feathers": 2}, ST_FORGE, 3, 20)
	_c("frost_arrow", {"wood": 8, "obsidian": 4, "feathers": 2, "freeze_gland": 1}, ST_FORGE, 3, 20)
	_c("poison_arrow", {"wood": 8, "obsidian": 4, "feathers": 2, "guck": 2}, ST_FORGE, 3, 20)

	_c("blackmetal_sword", {"fine_wood": 2, "black_metal": 20, "leather_scraps": 5}, ST_FORGE, 4)
	_c("blackmetal_axe", {"fine_wood": 6, "black_metal": 20, "leather_scraps": 5}, ST_FORGE, 4)
	_c("blackmetal_atgeir", {"fine_wood": 10, "black_metal": 20, "linen_thread": 5}, ST_FORGE, 4)
	_c("blackmetal_pickaxe", {"core_wood": 5, "black_metal": 20}, ST_FORGE, 4)
	_c("blackmetal_shield", {"black_metal": 8, "fine_wood": 10}, ST_FORGE, 4)
	_c("needle_arrow", {"wood": 8, "needle": 4, "feathers": 2}, ST_FORGE, 4, 20)
	_c("padded_helmet", {"iron": 10, "linen_thread": 15}, ST_FORGE, 4)
	_c("padded_cuirass", {"iron": 10, "linen_thread": 20}, ST_FORGE, 4)
	_c("padded_greaves", {"iron": 10, "linen_thread": 20}, ST_FORGE, 4)
	_c("lox_cape", {"lox_pelt": 6, "silver": 2}, ST_FORGE, 4)

	_c("carapace_helmet", {"carapace": 10, "mandible": 2}, ST_FORGE, 5)
	_c("carapace_breastplate", {"carapace": 16, "mandible": 2}, ST_FORGE, 5)
	_c("carapace_legguards", {"carapace": 16, "mandible": 2}, ST_FORGE, 5)
	_c("carapace_buckler", {"carapace": 8}, ST_FORGE, 5)
	_c("spine_snap", {"carapace": 10, "eitr": 10, "linen_thread": 5}, ST_FORGE, 5)
	_c("mistwalker", {"black_metal": 20, "eitr": 10, "fine_wood": 5}, ST_FORGE, 5)
	_c("feather_cape", {"feathers": 10, "eitr": 20, "sap": 5}, ST_FORGE, 5)
	_c("flametal_greatsword", {"flametal": 25, "charred_bone": 10, "blood_clot": 5}, ST_FORGE, 6)

	# 가마솥 — 조리 레시피
	_c("queens_jam", {"raspberries": 8, "blueberries": 8}, ST_CAULDRON, 1, 4)
	_c("carrot_soup", {"mushroom": 1, "carrot": 3}, ST_CAULDRON, 2)
	_c("turnip_stew", {"turnip": 3, "boar_meat": 1}, ST_CAULDRON, 2)
	_c("onion_soup", {"onion": 3, "mushroom": 1}, ST_CAULDRON, 3)
	_c("sausages", {"entrails": 2, "boar_meat": 1, "thistle": 4}, ST_CAULDRON, 2)
	_c("blood_pudding", {"thistle": 2, "blood_clot": 2, "barley_flour": 4}, ST_CAULDRON, 4)
	_c("bread", {"barley_flour": 10}, ST_CAULDRON, 3)
	_c("lox_pie", {"barley_flour": 10, "cloudberry": 2, "lox_meat": 2}, ST_CAULDRON, 4)
	_c("fish_wraps", {"cooked_fish": 2, "barley_flour": 4}, ST_CAULDRON, 4)
	_c("eitr_bread", {"barley_flour": 10, "sap": 2}, ST_CAULDRON, 5)
	_c("mead_health", {"honey": 10, "raspberries": 5, "blueberries": 10}, ST_CAULDRON, 1, 6)
	_c("mead_stamina", {"honey": 10, "mushroom": 10, "thistle": 10}, ST_CAULDRON, 2, 6)
	_c("mead_poison", {"honey": 10, "thistle": 5, "neck_tail": 1, "coal": 10}, ST_CAULDRON, 2, 6)
	_c("mead_frost", {"honey": 10, "thistle": 5, "bloodbag": 2, "greydwarf_eye": 1}, ST_CAULDRON, 3, 6)
	_c("mead_fire", {"honey": 10, "thistle": 5, "coal": 5, "resin": 5}, ST_CAULDRON, 3, 6)
	_c("barley_flour", {"barley": 1}, ST_CAULDRON, 3, 1)
	_c("linen_thread", {"flax": 1}, ST_CAULDRON, 3, 1)

func _build_cook() -> void:
	# 요리 화로: 생고기 -> 익은 고기 (시간 초). 방치하면 탄다.
	cook = {
		"neck_tail": {"out": "cooked_neck_tail", "time": 25.0},
		"boar_meat": {"out": "cooked_boar_meat", "time": 30.0},
		"deer_meat": {"out": "cooked_deer_meat", "time": 30.0},
		"wolf_meat": {"out": "cooked_wolf_meat", "time": 35.0},
		"lox_meat": {"out": "cooked_lox_meat", "time": 40.0},
		"serpent_meat": {"out": "cooked_serpent_meat", "time": 45.0},
		"fish": {"out": "cooked_fish", "time": 30.0},
		"mushroom": {"out": "mushroom", "time": 20.0},
	}

func _build_smelt() -> void:
	smelt = {
		"copper_ore": {"out": "copper", "time": 30.0},
		"tin_ore": {"out": "tin", "time": 30.0},
		"iron_scrap": {"out": "iron", "time": 30.0},
		"silver_ore": {"out": "silver", "time": 30.0},
		"black_metal_scrap": {"out": "black_metal", "time": 30.0},
		"flametal_ore": {"out": "flametal", "time": 40.0},
	}
	kiln = {
		"wood": {"out": "coal", "time": 25.0},
		"core_wood": {"out": "coal", "time": 25.0},
		"fine_wood": {"out": "coal", "time": 25.0},
		"ancient_bark": {"out": "coal", "time": 25.0},
	}

# ────────────────────────────────────────────────────────── 건축
## 조각 정의
##   n      번역 키                cat  카테고리(0 잡화 1 목재 2 석재 3 가구 4 제작대)
##   mats   재료                   size 바운딩 크기(m)
##   kind   메시 종류(MeshFactory) support 자체 지지력 0~1
##   ground true면 지면 지지 필요  comfort 안락도  fire 화염 여부
##   station 이 조각이 제공하는 제작대 종류
func _p(id: String, cat: int, mats: Dictionary, kind: String, size: Vector3,
		extra: Dictionary = {}) -> void:
	var d := {"id": id, "n": "PIECE_" + id.to_upper(), "cat": cat, "mats": mats,
		"kind": kind, "size": size, "support": 1.0, "comfort": 0, "station": "",
		"needs_workbench": true}
	for k in extra:
		d[k] = extra[k]
	pieces[id] = d
	piece_order.append(id)

func _build_pieces() -> void:
	# 0 · 잡화
	_p("campfire", 0, {"stone": 5, "wood": 2}, "campfire", Vector3(1.4, 0.6, 1.4),
		{"fire": true, "comfort": 1, "ground": true, "needs_workbench": false})
	_p("workbench", 0, {"wood": 10}, "workbench", Vector3(2.0, 1.2, 2.0),
		{"station": ST_WORKBENCH, "ground": true, "needs_workbench": false})
	_p("chest", 0, {"wood": 10}, "chest", Vector3(1.2, 0.9, 0.8), {"container": 12})
	_p("chest_large", 0, {"fine_wood": 8, "iron": 2}, "chest", Vector3(1.6, 1.1, 1.0), {"container": 24})
	_p("bed", 0, {"wood": 10}, "bed", Vector3(1.0, 0.6, 2.2), {"comfort": 1, "bed": true})
	_p("portal", 0, {"fine_wood": 20, "surtling_core": 2, "greydwarf_eye": 10}, "portal",
		Vector3(2.2, 3.0, 0.6), {"portal": true})
	_p("sign", 0, {"wood": 2, "coal": 1}, "sign", Vector3(1.2, 1.4, 0.2))

	# 1 · 목재 구조물
	_p("wood_floor", 1, {"wood": 2}, "floor", Vector3(2, 0.2, 2), {"support": 1.0})
	_p("wood_wall", 1, {"wood": 2}, "wall", Vector3(2, 2, 0.2), {"support": 1.0})
	_p("wood_wall_half", 1, {"wood": 1}, "wall_half", Vector3(2, 1, 0.2))
	_p("wood_beam", 1, {"wood": 1}, "beam", Vector3(0.2, 2, 0.2), {"support": 1.2})
	_p("wood_beam_26", 1, {"wood": 1}, "beam_diag", Vector3(0.25, 1.0, 2.2))
	_p("wood_pole", 1, {"wood": 1}, "pole", Vector3(0.2, 2, 0.2), {"support": 1.2})
	_p("wood_roof", 1, {"wood": 2}, "roof", Vector3(2, 1, 2))
	_p("wood_roof_top", 1, {"wood": 2}, "roof_top", Vector3(2, 0.4, 2))
	_p("wood_door", 1, {"wood": 4}, "door", Vector3(1.0, 2.0, 0.2), {"door": true})
	_p("wood_stair", 1, {"wood": 2}, "stair", Vector3(2, 2, 2))
	_p("wood_ladder", 1, {"wood": 2}, "ladder", Vector3(0.8, 2, 0.2), {"ladder": true})
	_p("wood_fence", 1, {"wood": 1}, "fence", Vector3(2, 1.4, 0.15))

	# 2 · 석재
	_p("stone_floor", 2, {"stone": 4}, "floor", Vector3(2, 0.4, 2), {"support": 1.4, "stone": true})
	_p("stone_wall", 2, {"stone": 4}, "wall", Vector3(2, 2, 0.4), {"support": 1.4, "stone": true})
	_p("stone_pillar", 2, {"stone": 4}, "pole", Vector3(0.4, 2, 0.4), {"support": 1.6, "stone": true})
	_p("stone_stair", 2, {"stone": 4}, "stair", Vector3(2, 2, 2), {"stone": true})

	# 3 · 가구 · 조명
	_p("hearth", 3, {"stone": 15}, "campfire", Vector3(2.0, 0.8, 2.0), {"fire": true, "comfort": 2, "ground": true})
	_p("torch_stand", 3, {"wood": 2, "resin": 2, "coal": 2}, "torch_stand", Vector3(0.4, 1.6, 0.4), {"fire": true})
	_p("chair", 3, {"wood": 4}, "chair", Vector3(0.8, 1.2, 0.8), {"comfort": 1, "chair": true})
	_p("table", 3, {"wood": 6}, "table", Vector3(2.0, 1.0, 1.2), {"comfort": 1})
	_p("banner", 3, {"fine_wood": 2, "leather_scraps": 6}, "banner", Vector3(1.2, 2.4, 0.15), {"comfort": 1})
	_p("rug_deer", 3, {"deer_hide": 4, "bone_fragments": 4}, "rug", Vector3(2.0, 0.06, 2.0), {"comfort": 1})

	# 4 · 제작 시설
	_p("forge", 4, {"stone": 4, "coal": 4, "copper": 6, "wood": 10}, "forge",
		Vector3(2.0, 1.6, 2.0), {"station": "forge", "ground": true})
	_p("cauldron", 4, {"tin": 10}, "cauldron", Vector3(1.2, 1.2, 1.2), {"station": "cauldron"})
	_p("cooking_station", 4, {"wood": 2}, "cooking_station", Vector3(2.0, 0.6, 0.5), {"cook": true})
	_p("smelter", 4, {"stone": 20, "surtling_core": 5}, "smelter", Vector3(2.4, 3.2, 2.4),
		{"smelter": true, "ground": true, "fuel": "coal"})
	_p("charcoal_kiln", 4, {"stone": 20, "surtling_core": 5}, "kiln", Vector3(2.6, 2.4, 2.6),
		{"kiln": true, "ground": true})
	_p("blast_furnace", 4, {"stone": 20, "surtling_core": 5, "iron": 10, "fine_wood": 20}, "smelter",
		Vector3(2.8, 3.6, 2.8), {"smelter": true, "ground": true, "fuel": "coal", "tier": 2})
	_p("windmill", 4, {"stone": 20, "wood": 30, "iron": 10}, "windmill", Vector3(3.0, 5.0, 3.0),
		{"grind": true, "ground": true})
	_p("spinning_wheel", 4, {"fine_wood": 20, "iron": 10, "leather_scraps": 10}, "spinning_wheel",
		Vector3(1.6, 1.8, 1.0), {"spin": true})
	_p("artisan_table", 4, {"wood": 10, "dragon_tear": 2}, "workbench", Vector3(2.0, 1.4, 2.0),
		{"station": "artisan_table", "ground": true})
	_p("stonecutter", 4, {"wood": 10, "iron": 2, "stone": 4}, "workbench", Vector3(2.0, 1.4, 2.0),
		{"station": "stonecutter", "ground": true})
	_p("fermenter", 4, {"fine_wood": 30, "bronze": 5, "resin": 10}, "fermenter",
		Vector3(1.6, 1.6, 1.6), {"ferment": true, "ground": true})

	# 5 · 작업대 업그레이드 (근처에 있으면 작업대 레벨 상승)
	_p("wb_chopping_block", 5, {"wood": 10, "flint": 10}, "table", Vector3(1.0, 1.0, 1.0), {"wb_up": 1})
	_p("wb_tanning_rack", 5, {"wood": 10, "flint": 15, "deer_hide": 20, "leather_scraps": 5},
		"banner", Vector3(1.6, 1.8, 0.4), {"wb_up": 1})
	_p("wb_adze", 5, {"fine_wood": 10, "bronze": 3}, "table", Vector3(1.0, 1.2, 1.0), {"wb_up": 1})
	_p("wb_tool_shelf", 5, {"fine_wood": 10, "iron": 4}, "banner", Vector3(1.8, 1.0, 0.3), {"wb_up": 1})
	_p("forge_bellows", 5, {"deer_hide": 5, "chain": 5, "wood": 5}, "table", Vector3(1.2, 1.0, 1.2), {"forge_up": 1})
	_p("forge_anvils", 5, {"bronze": 2, "wood": 5}, "table", Vector3(1.0, 1.0, 1.0), {"forge_up": 1})
	_p("forge_grindstone", 5, {"wood": 1, "stone": 1}, "table", Vector3(1.2, 1.2, 1.2), {"forge_up": 1})
	_p("forge_toolrack", 5, {"fine_wood": 10, "iron": 15, "obsidian": 4}, "banner",
		Vector3(1.8, 1.2, 0.3), {"forge_up": 1})

	# 6 · 농사
	_p("plant_carrot", 6, {"carrot_seeds": 1}, "plant", Vector3(0.5, 0.5, 0.5),
		{"crop": "carrot", "grow": 300.0, "yield": 3, "ground": true, "needs_cultivated": true})
	_p("plant_turnip", 6, {"turnip_seeds": 1}, "plant", Vector3(0.5, 0.5, 0.5),
		{"crop": "turnip", "grow": 300.0, "yield": 3, "ground": true, "needs_cultivated": true})
	_p("plant_onion", 6, {"onion_seeds": 1}, "plant", Vector3(0.5, 0.5, 0.5),
		{"crop": "onion", "grow": 320.0, "yield": 3, "ground": true, "needs_cultivated": true})
	_p("plant_barley", 6, {"barley": 1}, "plant", Vector3(0.5, 0.8, 0.5),
		{"crop": "barley", "grow": 360.0, "yield": 2, "ground": true, "needs_cultivated": true})
	_p("plant_flax", 6, {"flax": 1}, "plant", Vector3(0.5, 0.8, 0.5),
		{"crop": "flax", "grow": 360.0, "yield": 2, "ground": true, "needs_cultivated": true})
	_p("plant_beech", 6, {"beech_seeds": 1}, "plant", Vector3(0.6, 1.0, 0.6),
		{"tree": "beech", "grow": 480.0, "ground": true})
	_p("plant_pine", 6, {"pine_cone": 1}, "plant", Vector3(0.6, 1.0, 0.6),
		{"tree": "pine", "grow": 480.0, "ground": true})

func piece(id: String) -> Dictionary:
	return pieces.get(id, {})

func pieces_in_cat(cat: int) -> Array[String]:
	var out: Array[String] = []
	for id in piece_order:
		if int(pieces[id]["cat"]) == cat:
			out.append(id)
	return out
