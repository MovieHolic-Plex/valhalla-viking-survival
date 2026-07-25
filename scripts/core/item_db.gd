extends Node
## 아이템 데이터베이스. 오토로드 이름: ItemDB
##
## 스키마
##   n     번역 키(이름)          d    번역 키(설명)
##   t     Const.ItemType         st   최대 스택(기본 1)
##   w     무게                   col  대표 색(아이콘/메시 틴트)
##   dmg   {Const.Dmg: 값}        spd  초당 공격 횟수
##   stam  공격당 스태미나        rng  사거리(m)      kb  넉백
##   skill Const.Skill            tier 도구 등급(벌목/채광)
##   block 방어력                 parry 패링 배수
##   ar    방어도                 slot Const.ArmorSlot   mov 이동속도 보정
##   hp/sp 음식 최대체력·스태미나 dur  지속(초)   reg 초당 체력재생
##   up    최대 강화 단계         upmat 단계당 재료
##   tp    포탈 통과 가능 여부(금속은 false)

const T := Const.ItemType
const D := Const.Dmg
const S := Const.Skill
const A := Const.ArmorSlot

var items: Dictionary = {}
var _icons: Dictionary = {}

func _ready() -> void:
	_build()

func get_item(id: String) -> Dictionary:
	return items.get(id, {})

func has_item(id: String) -> bool:
	return items.has(id)

func name_of(id: String) -> String:
	var it: Dictionary = items.get(id, {})
	if it.is_empty():
		return id
	return tr(it.get("n", id))

func desc_of(id: String) -> String:
	var it: Dictionary = items.get(id, {})
	if it.is_empty():
		return ""
	return tr(it.get("d", ""))

func stack_of(id: String) -> int:
	return int(items.get(id, {}).get("st", 1))

func weight_of(id: String) -> float:
	return float(items.get(id, {}).get("w", 1.0))

func type_of(id: String) -> int:
	return int(items.get(id, {}).get("t", T.MATERIAL))

func color_of(id: String) -> Color:
	return items.get(id, {}).get("col", Color(0.7, 0.7, 0.7))

func is_teleportable(id: String) -> bool:
	return bool(items.get(id, {}).get("tp", true))

func max_quality(id: String) -> int:
	return int(items.get(id, {}).get("up", 1))

## 강화 단계에 따른 스탯 배수 (발헤임과 유사하게 완만한 선형 증가)
static func quality_mult(q: int) -> float:
	return 1.0 + 0.22 * float(maxi(q, 1) - 1)

## 무기 총 데미지(강화 반영)
func total_damage(id: String, q: int = 1) -> Dictionary:
	var base: Dictionary = items.get(id, {}).get("dmg", {})
	var m := quality_mult(q)
	var out := {}
	for k in base:
		out[k] = float(base[k]) * m
	return out

func armor_of(id: String, q: int = 1) -> float:
	var it: Dictionary = items.get(id, {})
	if not it.has("ar"):
		return 0.0
	# 방어구는 단계당 +2 방어도 (발헤임과 동일한 가산 방식)
	return float(it["ar"]) + 2.0 * float(maxi(q, 1) - 1)

func block_of(id: String, q: int = 1) -> float:
	var it: Dictionary = items.get(id, {})
	if not it.has("block"):
		return 0.0
	return float(it["block"]) * quality_mult(q)

## 강화에 필요한 재료 (단계 q -> q+1)
func upgrade_cost(id: String, to_q: int) -> Dictionary:
	var it: Dictionary = items.get(id, {})
	var base: Dictionary = it.get("upmat", {})
	if base.is_empty():
		return {}
	var mult := maxi(1, to_q - 1)
	var out := {}
	for k in base:
		out[k] = int(base[k]) * mult
	return out

# ────────────────────────────────────────────────────────────────── 정의
func _add(id: String, data: Dictionary) -> void:
	data["id"] = id
	if not data.has("n"):
		data["n"] = "ITEM_" + id.to_upper()
	if not data.has("d"):
		data["d"] = "ITEM_" + id.to_upper() + "_D"
	items[id] = data

func _mat(id: String, weight: float, col: Color, stack: int = 50, tp: bool = true) -> void:
	_add(id, {"t": T.MATERIAL, "st": stack, "w": weight, "col": col, "tp": tp})

func _trophy(id: String, col: Color) -> void:
	_add(id, {"t": T.TROPHY, "st": 1, "w": 1.0, "col": col})

func _build() -> void:
	# ── 기본 자원 ──────────────────────────────────────────────
	_mat("wood", 2.0, Color(0.45, 0.31, 0.18))
	_mat("core_wood", 2.0, Color(0.36, 0.25, 0.14))
	_mat("fine_wood", 2.0, Color(0.72, 0.62, 0.44))
	_mat("ancient_bark", 2.0, Color(0.28, 0.24, 0.20))
	_mat("yggdrasil_wood", 2.0, Color(0.55, 0.70, 0.52))
	_mat("stone", 2.0, Color(0.55, 0.55, 0.55))
	_mat("flint", 2.0, Color(0.36, 0.38, 0.40))
	_mat("resin", 0.3, Color(0.90, 0.70, 0.25))
	_mat("feathers", 0.1, Color(0.92, 0.92, 0.88))
	_mat("leather_scraps", 0.5, Color(0.58, 0.42, 0.28))
	_mat("deer_hide", 1.0, Color(0.64, 0.48, 0.32))
	_mat("troll_hide", 2.0, Color(0.42, 0.48, 0.40))
	_mat("wolf_pelt", 1.0, Color(0.82, 0.84, 0.88))
	_mat("lox_pelt", 2.0, Color(0.48, 0.34, 0.22))
	_mat("scale_hide", 2.0, Color(0.35, 0.55, 0.50))
	_mat("carapace", 4.0, Color(0.30, 0.32, 0.22), 50, false)
	_mat("greydwarf_eye", 0.5, Color(0.85, 0.90, 0.55))
	_mat("resin_lump", 0.3, Color(0.95, 0.78, 0.30))
	_mat("ancient_seed", 1.0, Color(0.30, 0.45, 0.22), 10)
	_mat("surtling_core", 8.0, Color(1.00, 0.42, 0.10), 20)
	_mat("withered_bone", 4.0, Color(0.80, 0.78, 0.68), 20)
	_mat("bone_fragments", 0.5, Color(0.86, 0.84, 0.76))
	_mat("guck", 1.0, Color(0.30, 0.75, 0.40))
	_mat("chain", 8.0, Color(0.42, 0.42, 0.46), 20, false)
	_mat("entrails", 0.5, Color(0.72, 0.28, 0.30))
	_mat("obsidian", 2.0, Color(0.12, 0.12, 0.16))
	_mat("freeze_gland", 0.5, Color(0.60, 0.86, 1.00))
	_mat("wolf_fang", 0.5, Color(0.94, 0.94, 0.90))
	_mat("dragon_egg", 20.0, Color(0.75, 0.88, 0.95), 3, false)
	_mat("crystal", 1.0, Color(0.72, 0.92, 1.00))
	_mat("thistle", 0.5, Color(0.55, 0.35, 0.70))
	_mat("black_core", 8.0, Color(0.10, 0.10, 0.14), 20)
	_mat("soft_tissue", 4.0, Color(0.72, 0.42, 0.44), 50, false)
	_mat("sap", 1.0, Color(0.45, 0.85, 0.65))
	_mat("eitr", 0.5, Color(0.55, 0.45, 0.95))
	_mat("mandible", 2.0, Color(0.45, 0.40, 0.28))
	_mat("charred_bone", 1.0, Color(0.22, 0.18, 0.16))
	_mat("blood_clot", 1.0, Color(0.55, 0.10, 0.12))
	_mat("morgen_sinew", 1.0, Color(0.62, 0.24, 0.20))
	_mat("needle", 0.5, Color(0.85, 0.80, 0.35))
	_mat("linen_thread", 0.2, Color(0.92, 0.90, 0.80))
	_mat("flax", 0.3, Color(0.75, 0.80, 0.55))
	_mat("barley", 0.3, Color(0.85, 0.75, 0.40))
	_mat("barley_flour", 0.3, Color(0.94, 0.90, 0.75))
	_mat("coal", 2.0, Color(0.10, 0.10, 0.10))
	_mat("iron_nails", 0.2, Color(0.50, 0.48, 0.45), 100, false)
	_mat("bronze_nails", 0.2, Color(0.72, 0.52, 0.24), 100, false)

	# ── 광물 (포탈 통과 불가) ─────────────────────────────────
	_mat("copper_ore", 8.0, Color(0.55, 0.35, 0.20), 30, false)
	_mat("tin_ore", 8.0, Color(0.62, 0.66, 0.70), 30, false)
	_mat("iron_scrap", 8.0, Color(0.45, 0.32, 0.26), 30, false)
	_mat("silver_ore", 12.0, Color(0.78, 0.80, 0.84), 30, false)
	_mat("black_metal_scrap", 10.0, Color(0.18, 0.18, 0.22), 30, false)
	_mat("flametal_ore", 12.0, Color(0.85, 0.30, 0.12), 30, false)
	_mat("copper", 12.0, Color(0.78, 0.44, 0.20), 30, false)
	_mat("tin", 8.0, Color(0.78, 0.82, 0.86), 30, false)
	_mat("bronze", 12.0, Color(0.80, 0.55, 0.22), 30, false)
	_mat("iron", 12.0, Color(0.58, 0.58, 0.60), 30, false)
	_mat("silver", 14.0, Color(0.86, 0.88, 0.92), 30, false)
	_mat("black_metal", 12.0, Color(0.22, 0.22, 0.26), 30, false)
	_mat("flametal", 14.0, Color(0.95, 0.42, 0.15), 30, false)

	# ── 보스 드롭 / 열쇠 ─────────────────────────────────────
	_add("hard_antler", {"t": T.MATERIAL, "st": 20, "w": 2.0, "col": Color(0.80, 0.72, 0.55)})
	_add("swamp_key", {"t": T.MATERIAL, "st": 1, "w": 1.0, "col": Color(0.45, 0.60, 0.30)})
	_add("wishbone", {"t": T.TOOL, "st": 1, "w": 2.0, "col": Color(0.88, 0.86, 0.70)})
	_add("dragon_tear", {"t": T.MATERIAL, "st": 10, "w": 2.0, "col": Color(0.65, 0.90, 1.00)})
	_add("torn_spirit", {"t": T.MATERIAL, "st": 10, "w": 2.0, "col": Color(0.85, 0.95, 0.80)})
	_add("queen_drop", {"t": T.MATERIAL, "st": 10, "w": 2.0, "col": Color(0.60, 0.50, 0.95)})
	_add("ember", {"t": T.MATERIAL, "st": 10, "w": 2.0, "col": Color(1.00, 0.50, 0.15)})

	# ── 트로피 (제단 공물) ───────────────────────────────────
	_trophy("trophy_deer", Color(0.70, 0.55, 0.35))
	_trophy("trophy_boar", Color(0.55, 0.40, 0.30))
	_trophy("trophy_neck", Color(0.45, 0.62, 0.42))
	_trophy("trophy_greyling", Color(0.35, 0.45, 0.30))
	_trophy("trophy_greydwarf", Color(0.40, 0.50, 0.34))
	_trophy("trophy_troll", Color(0.42, 0.50, 0.42))
	_trophy("trophy_skeleton", Color(0.88, 0.86, 0.78))
	_trophy("trophy_draugr", Color(0.35, 0.42, 0.30))
	_trophy("trophy_blob", Color(0.35, 0.72, 0.38))
	_trophy("trophy_wraith", Color(0.62, 0.65, 0.72))
	_trophy("trophy_wolf", Color(0.85, 0.87, 0.90))
	_trophy("trophy_drake", Color(0.70, 0.88, 0.95))
	_trophy("trophy_golem", Color(0.55, 0.60, 0.62))
	_trophy("trophy_fuling", Color(0.55, 0.50, 0.28))
	_trophy("trophy_lox", Color(0.48, 0.34, 0.22))
	_trophy("trophy_deathsquito", Color(0.75, 0.72, 0.30))
	_trophy("trophy_seeker", Color(0.32, 0.34, 0.24))
	_trophy("trophy_eikthyr", Color(0.85, 0.75, 0.55))
	_trophy("trophy_elder", Color(0.35, 0.50, 0.28))
	_trophy("trophy_bonemass", Color(0.40, 0.55, 0.35))
	_trophy("trophy_moder", Color(0.80, 0.92, 1.00))
	_trophy("trophy_yagluth", Color(0.85, 0.70, 0.30))
	_trophy("trophy_queen", Color(0.60, 0.45, 0.95))

	# ── 음식 ─────────────────────────────────────────────────
	_food("raspberries", 8, 15, 600, 1.0, Color(0.85, 0.20, 0.30))
	_food("blueberries", 9, 20, 600, 1.0, Color(0.30, 0.35, 0.75))
	_food("mushroom", 15, 15, 900, 1.0, Color(0.85, 0.70, 0.55))
	_food("carrot", 10, 32, 900, 1.0, Color(0.90, 0.52, 0.15))
	_food("turnip", 12, 26, 900, 1.0, Color(0.85, 0.80, 0.85))
	_food("onion", 14, 28, 1000, 1.0, Color(0.88, 0.82, 0.60))
	_food("honey", 8, 20, 800, 2.0, Color(0.95, 0.72, 0.18))
	_food("neck_tail", 15, 8, 600, 1.0, Color(0.60, 0.72, 0.50))
	_food("cooked_neck_tail", 20, 12, 900, 2.0, Color(0.75, 0.65, 0.45))
	_food("boar_meat", 15, 8, 600, 1.0, Color(0.80, 0.35, 0.35))
	_food("cooked_boar_meat", 30, 18, 1200, 2.0, Color(0.62, 0.36, 0.22))
	_food("deer_meat", 20, 10, 700, 1.0, Color(0.78, 0.32, 0.32))
	_food("cooked_deer_meat", 35, 22, 1300, 2.0, Color(0.58, 0.34, 0.20))
	_food("wolf_meat", 25, 12, 800, 1.0, Color(0.75, 0.30, 0.30))
	_food("cooked_wolf_meat", 50, 30, 1500, 3.0, Color(0.55, 0.32, 0.20))
	_food("lox_meat", 30, 14, 900, 1.0, Color(0.70, 0.28, 0.28))
	_food("cooked_lox_meat", 65, 32, 1600, 3.0, Color(0.52, 0.30, 0.18))
	_food("serpent_meat", 35, 16, 900, 1.0, Color(0.40, 0.70, 0.55))
	_food("cooked_serpent_meat", 80, 26, 1600, 4.0, Color(0.45, 0.62, 0.45))
	_food("fish", 20, 10, 700, 1.0, Color(0.60, 0.70, 0.80))
	_food("cooked_fish", 45, 22, 1300, 2.0, Color(0.70, 0.65, 0.55))
	_food("queens_jam", 20, 30, 1200, 2.0, Color(0.72, 0.25, 0.45))
	_food("bread", 40, 25, 1500, 2.0, Color(0.85, 0.70, 0.45))
	_food("carrot_soup", 15, 45, 1500, 2.0, Color(0.92, 0.60, 0.25))
	_food("turnip_stew", 18, 54, 1600, 2.0, Color(0.85, 0.72, 0.62))
	_food("onion_soup", 20, 60, 1600, 2.0, Color(0.88, 0.85, 0.62))
	_food("sausages", 60, 30, 1600, 3.0, Color(0.65, 0.32, 0.28))
	_food("blood_pudding", 75, 25, 1800, 3.0, Color(0.45, 0.14, 0.20))
	_food("lox_pie", 80, 55, 1800, 4.0, Color(0.80, 0.60, 0.35))
	_food("fish_wraps", 70, 65, 1800, 4.0, Color(0.75, 0.75, 0.60))
	_food("eitr_bread", 40, 30, 1800, 3.0, Color(0.70, 0.62, 0.95))
	items["eitr_bread"]["eitr"] = 40.0
	_food("sap_stew", 30, 25, 1700, 2.0, Color(0.55, 0.80, 0.62))
	items["sap_stew"]["eitr"] = 55.0
	_food("mushroom_omelette", 55, 22, 1600, 3.0, Color(0.92, 0.82, 0.45))
	items["mushroom_omelette"]["eitr"] = 30.0

	# 회복 물약 · 특수 소모품
	_add("mead_health", {"t": T.CONSUMABLE, "st": 10, "w": 1.0, "col": Color(0.90, 0.25, 0.30),
		"potion": {"heal": 50.0, "over": 10.0}})
	_add("mead_stamina", {"t": T.CONSUMABLE, "st": 10, "w": 1.0, "col": Color(0.95, 0.80, 0.25),
		"potion": {"stam": 80.0, "over": 10.0}})
	_add("mead_poison", {"t": T.CONSUMABLE, "st": 10, "w": 1.0, "col": Color(0.40, 0.85, 0.35),
		"potion": {"res_poison": 0.75, "dur": 600.0}})
	_add("mead_frost", {"t": T.CONSUMABLE, "st": 10, "w": 1.0, "col": Color(0.50, 0.80, 1.00),
		"potion": {"res_frost": 1.0, "dur": 600.0}})
	_add("mead_fire", {"t": T.CONSUMABLE, "st": 10, "w": 1.0, "col": Color(1.00, 0.45, 0.20),
		"potion": {"res_fire": 0.75, "dur": 600.0}})

	# ── 도구 ─────────────────────────────────────────────────
	_add("hammer", {"t": T.TOOL, "w": 2.0, "col": Color(0.60, 0.45, 0.30), "use": "build",
		"dmg": {D.BLUNT: 5.0}, "spd": 1.0, "stam": 4.0, "rng": 2.0, "skill": S.CLUBS})
	_add("hoe", {"t": T.TOOL, "w": 2.0, "col": Color(0.55, 0.42, 0.28), "use": "terrain",
		"dmg": {D.BLUNT: 4.0}, "spd": 0.9, "stam": 6.0, "rng": 2.4, "skill": S.CLUBS})
	_add("cultivator", {"t": T.TOOL, "w": 2.0, "col": Color(0.50, 0.40, 0.26), "use": "farm",
		"dmg": {D.BLUNT: 4.0}, "spd": 0.9, "stam": 6.0, "rng": 2.4, "skill": S.CLUBS})
	_add("torch", {"t": T.TOOL, "w": 1.0, "col": Color(1.00, 0.62, 0.20), "light": true,
		"dmg": {D.BLUNT: 5.0, D.FIRE: 10.0}, "spd": 1.1, "stam": 8.0, "rng": 2.0, "skill": S.CLUBS,
		"up": 3, "upmat": {"resin": 5}})

	_add("fishing_rod", {"t": T.TOOL, "w": 2.0, "col": Color(0.62, 0.48, 0.30),
		"fishing": true, "dmg": {D.BLUNT: 3.0}, "spd": 1.0, "stam": 6.0, "rng": 2.0,
		"skill": S.KNIVES})
	_mat("fishing_bait", 0.1, Color(0.85, 0.55, 0.40), 100)
	_food("leech_fish", 30, 14, 900, 1.0, Color(0.55, 0.25, 0.30))

	# 지팡이 — 에이트르를 소모해 시전한다
	_staff("staff_fire", {D.FIRE: 90.0}, 22.0, Color(1.0, 0.48, 0.14),
		{"eitr": 6, "surtling_core": 3, "fine_wood": 10, "yggdrasil_wood": 10})
	_staff("staff_frost", {D.FROST: 75.0, D.PIERCE: 20.0}, 20.0,
		Color(0.60, 0.88, 1.0), {"eitr": 6, "freeze_gland": 5, "yggdrasil_wood": 10})
	_staff("staff_shield", {}, 30.0, Color(0.75, 0.80, 0.95),
		{"eitr": 8, "silver": 10, "yggdrasil_wood": 10}, "shield")
	_staff("staff_skeleton", {}, 40.0, Color(0.85, 0.85, 0.78),
		{"eitr": 8, "withered_bone": 10, "yggdrasil_wood": 10}, "summon")

	_pick("antler_pickaxe", 1, 22.0, 0.9, Color(0.82, 0.74, 0.56), {"hard_antler": 4})
	_pick("bronze_pickaxe", 2, 30.0, 1.0, Color(0.80, 0.55, 0.22), {"bronze": 3})
	_pick("iron_pickaxe", 3, 40.0, 1.05, Color(0.60, 0.60, 0.62), {"iron": 5})
	_pick("blackmetal_pickaxe", 4, 55.0, 1.1, Color(0.24, 0.24, 0.28), {"black_metal": 5})

	# ── 무기 ─────────────────────────────────────────────────
	# 나무/돌 티어
	_wep("club", S.CLUBS, {D.BLUNT: 18.0}, 1.15, 12.0, 2.1, 40.0, Color(0.48, 0.34, 0.20), {"wood": 4})
	_wep("stone_axe", S.AXES, {D.SLASH: 14.0, D.CHOP: 20.0}, 1.0, 14.0, 2.1, 30.0, Color(0.55, 0.52, 0.50), {"wood": 4, "stone": 4}, 1)
	_wep("flint_axe", S.AXES, {D.SLASH: 22.0, D.CHOP: 35.0}, 1.0, 16.0, 2.2, 35.0, Color(0.42, 0.44, 0.46), {"wood": 4, "flint": 4}, 2)
	_wep("flint_spear", S.SPEARS, {D.PIERCE: 26.0}, 1.0, 16.0, 3.1, 30.0, Color(0.45, 0.42, 0.38), {"wood": 4, "flint": 4})
	_wep("flint_knife", S.KNIVES, {D.PIERCE: 12.0, D.SLASH: 12.0}, 1.9, 8.0, 1.8, 12.0, Color(0.44, 0.46, 0.48), {"flint": 4})
	# 청동 티어
	_wep("bronze_axe", S.AXES, {D.SLASH: 30.0, D.CHOP: 50.0}, 1.0, 18.0, 2.3, 40.0, Color(0.80, 0.55, 0.22), {"bronze": 4}, 3)
	_wep("bronze_sword", S.SWORDS, {D.SLASH: 35.0}, 1.25, 16.0, 2.4, 35.0, Color(0.82, 0.58, 0.24), {"bronze": 4})
	_wep("bronze_mace", S.CLUBS, {D.BLUNT: 38.0}, 0.95, 20.0, 2.2, 60.0, Color(0.78, 0.54, 0.22), {"bronze": 4})
	_wep("bronze_atgeir", S.SPEARS, {D.PIERCE: 42.0, D.SLASH: 12.0}, 0.8, 24.0, 3.6, 55.0, Color(0.80, 0.56, 0.23), {"bronze": 4})
	# 철 티어
	_wep("iron_axe", S.AXES, {D.SLASH: 45.0, D.CHOP: 70.0}, 1.0, 20.0, 2.4, 45.0, Color(0.62, 0.62, 0.64), {"iron": 5}, 4)
	_wep("iron_sword", S.SWORDS, {D.SLASH: 55.0}, 1.2, 18.0, 2.5, 40.0, Color(0.64, 0.64, 0.66), {"iron": 5})
	_wep("iron_mace", S.CLUBS, {D.BLUNT: 60.0}, 0.9, 22.0, 2.3, 75.0, Color(0.60, 0.60, 0.62), {"iron": 5})
	_wep("iron_atgeir", S.SPEARS, {D.PIERCE: 65.0, D.SLASH: 15.0}, 0.78, 26.0, 3.8, 65.0, Color(0.62, 0.62, 0.64), {"iron": 5})
	_wep("iron_spear", S.SPEARS, {D.PIERCE: 48.0}, 1.05, 18.0, 3.3, 35.0, Color(0.62, 0.62, 0.64), {"iron": 5})
	# 은 티어
	_wep("silver_sword", S.SWORDS, {D.SLASH: 70.0, D.SPIRIT: 20.0}, 1.2, 20.0, 2.6, 45.0, Color(0.88, 0.90, 0.94), {"silver": 5})
	_wep("silver_mace", S.CLUBS, {D.BLUNT: 68.0, D.SPIRIT: 25.0}, 0.9, 24.0, 2.4, 80.0, Color(0.86, 0.88, 0.92), {"silver": 5})
	_wep("frostner", S.CLUBS, {D.BLUNT: 55.0, D.FROST: 40.0, D.SPIRIT: 20.0}, 0.95, 24.0, 2.4, 80.0, Color(0.70, 0.90, 1.00), {"silver": 5, "freeze_gland": 5})
	# 흑금속 티어
	_wep("blackmetal_sword", S.SWORDS, {D.SLASH: 95.0}, 1.2, 22.0, 2.7, 50.0, Color(0.24, 0.24, 0.28), {"black_metal": 5})
	_wep("blackmetal_axe", S.AXES, {D.SLASH: 85.0, D.CHOP: 90.0}, 1.0, 24.0, 2.5, 55.0, Color(0.22, 0.22, 0.26), {"black_metal": 5}, 5)
	_wep("blackmetal_atgeir", S.SPEARS, {D.PIERCE: 105.0, D.SLASH: 20.0}, 0.78, 28.0, 4.0, 75.0, Color(0.24, 0.24, 0.28), {"black_metal": 5})
	# 후반 티어
	_wep("mistwalker", S.SWORDS, {D.SLASH: 110.0, D.FROST: 45.0}, 1.2, 24.0, 2.8, 55.0, Color(0.55, 0.75, 0.90), {"black_metal": 5, "eitr": 10})
	_wep("flametal_greatsword", S.SWORDS, {D.SLASH: 150.0, D.FIRE: 60.0}, 0.8, 32.0, 3.2, 90.0, Color(0.95, 0.45, 0.18), {"flametal": 6})

	# ── 활 · 화살 ────────────────────────────────────────────
	_bow("crude_bow", 22.0, 1.0, 0.7, Color(0.55, 0.42, 0.26), {"wood": 10, "leather_scraps": 8})
	_bow("finewood_bow", 32.0, 1.15, 0.8, Color(0.75, 0.64, 0.44), {"fine_wood": 10, "deer_hide": 2})
	_bow("huntsman_bow", 42.0, 1.25, 0.9, Color(0.60, 0.52, 0.38), {"fine_wood": 10, "iron": 2, "feathers": 10})
	_bow("draugr_fang", 52.0, 1.35, 1.0, Color(0.30, 0.42, 0.30), {"ancient_bark": 10, "silver": 2, "deer_hide": 2, "guck": 5})
	_bow("spine_snap", 62.0, 1.45, 1.1, Color(0.35, 0.32, 0.24), {"carapace": 6, "eitr": 6})

	_ammo("wood_arrow", {D.PIERCE: 22.0}, Color(0.55, 0.42, 0.26))
	_ammo("flint_arrow", {D.PIERCE: 32.0}, Color(0.44, 0.46, 0.48))
	_ammo("fire_arrow", {D.PIERCE: 18.0, D.FIRE: 32.0}, Color(1.00, 0.55, 0.18))
	_ammo("bronze_arrow", {D.PIERCE: 42.0}, Color(0.80, 0.55, 0.22))
	_ammo("iron_arrow", {D.PIERCE: 52.0}, Color(0.62, 0.62, 0.64))
	_ammo("poison_arrow", {D.PIERCE: 26.0, D.POISON: 52.0}, Color(0.45, 0.85, 0.35))
	_ammo("obsidian_arrow", {D.PIERCE: 62.0}, Color(0.15, 0.15, 0.20))
	_ammo("frost_arrow", {D.PIERCE: 52.0, D.FROST: 42.0}, Color(0.60, 0.88, 1.00))
	_ammo("needle_arrow", {D.PIERCE: 82.0}, Color(0.85, 0.80, 0.35))

	# ── 방패 ─────────────────────────────────────────────────
	_shield("wood_shield", 12.0, 1.5, Color(0.52, 0.38, 0.22), {"wood": 6, "leather_scraps": 6})
	_shield("banded_shield", 32.0, 1.5, Color(0.60, 0.52, 0.38), {"fine_wood": 10, "iron": 4})
	_shield("iron_buckler", 26.0, 2.5, Color(0.62, 0.62, 0.64), {"iron": 10})
	_shield("silver_shield", 42.0, 1.6, Color(0.86, 0.88, 0.92), {"silver": 8, "fine_wood": 10})
	_shield("blackmetal_shield", 52.0, 1.6, Color(0.24, 0.24, 0.28), {"black_metal": 8, "fine_wood": 10})
	_shield("carapace_buckler", 46.0, 2.6, Color(0.32, 0.34, 0.24), {"carapace": 8})

	# ── 방어구 ───────────────────────────────────────────────
	_armor("rag_hood", 1.0, A.HEAD, 0.0, Color(0.70, 0.66, 0.56), {"leather_scraps": 2})
	_armor("rag_tunic", 1.0, A.CHEST, 0.0, Color(0.70, 0.66, 0.56), {"leather_scraps": 4})
	_armor("leather_helmet", 3.0, A.HEAD, 0.0, Color(0.62, 0.45, 0.28), {"deer_hide": 3, "bone_fragments": 6})
	_armor("leather_tunic", 3.0, A.CHEST, 0.0, Color(0.62, 0.45, 0.28), {"deer_hide": 6, "bone_fragments": 6})
	_armor("leather_pants", 3.0, A.LEGS, 0.0, Color(0.62, 0.45, 0.28), {"deer_hide": 6, "bone_fragments": 6})
	_armor("troll_hood", 6.0, A.HEAD, 0.0, Color(0.44, 0.50, 0.42), {"troll_hide": 5, "bone_fragments": 5})
	_armor("troll_tunic", 6.0, A.CHEST, 0.0, Color(0.44, 0.50, 0.42), {"troll_hide": 10, "bone_fragments": 5})
	_armor("troll_pants", 6.0, A.LEGS, 0.0, Color(0.44, 0.50, 0.42), {"troll_hide": 10, "bone_fragments": 5})
	_armor("bronze_helmet", 10.0, A.HEAD, -0.05, Color(0.80, 0.55, 0.22), {"bronze": 5, "deer_hide": 2})
	_armor("bronze_cuirass", 10.0, A.CHEST, -0.05, Color(0.80, 0.55, 0.22), {"bronze": 5, "deer_hide": 2})
	_armor("bronze_greaves", 10.0, A.LEGS, -0.05, Color(0.80, 0.55, 0.22), {"bronze": 5, "deer_hide": 2})
	_armor("iron_helmet", 14.0, A.HEAD, -0.05, Color(0.62, 0.62, 0.64), {"iron": 20, "deer_hide": 2})
	_armor("iron_scale_mail", 14.0, A.CHEST, -0.05, Color(0.62, 0.62, 0.64), {"iron": 20, "deer_hide": 2})
	_armor("iron_greaves", 14.0, A.LEGS, -0.05, Color(0.62, 0.62, 0.64), {"iron": 20, "deer_hide": 2})
	_armor("wolf_headdress", 18.0, A.HEAD, 0.0, Color(0.86, 0.88, 0.92), {"wolf_pelt": 5, "silver": 2, "wolf_fang": 2})
	_armor("wolf_armor_chest", 18.0, A.CHEST, -0.05, Color(0.86, 0.88, 0.92), {"silver": 20, "wolf_pelt": 5, "chain": 1})
	_armor("wolf_armor_legs", 18.0, A.LEGS, -0.05, Color(0.86, 0.88, 0.92), {"silver": 20, "wolf_pelt": 5, "chain": 1})
	_armor("padded_helmet", 22.0, A.HEAD, -0.05, Color(0.82, 0.78, 0.68), {"iron": 10, "linen_thread": 15})
	_armor("padded_cuirass", 22.0, A.CHEST, -0.05, Color(0.82, 0.78, 0.68), {"iron": 10, "linen_thread": 20})
	_armor("padded_greaves", 22.0, A.LEGS, -0.05, Color(0.82, 0.78, 0.68), {"iron": 10, "linen_thread": 20})
	_armor("carapace_helmet", 26.0, A.HEAD, -0.05, Color(0.32, 0.34, 0.24), {"carapace": 10, "mandible": 2})
	_armor("carapace_breastplate", 26.0, A.CHEST, -0.05, Color(0.32, 0.34, 0.24), {"carapace": 16, "mandible": 2})
	_armor("carapace_legguards", 26.0, A.LEGS, -0.05, Color(0.32, 0.34, 0.24), {"carapace": 16, "mandible": 2})
	# 망토
	_armor("deer_cape", 1.0, A.CAPE, 0.0, Color(0.62, 0.45, 0.28), {"deer_hide": 4, "bone_fragments": 5})
	_armor("troll_cape", 1.0, A.CAPE, 0.0, Color(0.44, 0.50, 0.42), {"troll_hide": 10, "bone_fragments": 10})
	_armor("wolf_cape", 2.0, A.CAPE, 0.0, Color(0.86, 0.88, 0.92), {"wolf_pelt": 4, "silver": 4, "wolf_fang": 4},
		{"res_frost": 1.0})
	_armor("lox_cape", 2.0, A.CAPE, 0.0, Color(0.48, 0.34, 0.22), {"lox_pelt": 6, "silver": 2},
		{"res_frost": 1.0})
	_armor("feather_cape", 2.0, A.CAPE, 0.0, Color(0.75, 0.72, 0.90), {"feathers": 10, "eitr": 10},
		{"no_fall": true})

	# ── 씨앗 · 농작물 ────────────────────────────────────────
	_mat("carrot_seeds", 0.1, Color(0.90, 0.60, 0.25))
	_mat("turnip_seeds", 0.1, Color(0.86, 0.82, 0.86))
	_mat("onion_seeds", 0.1, Color(0.88, 0.84, 0.62))
	_mat("beech_seeds", 0.1, Color(0.62, 0.72, 0.40))
	_mat("pine_cone", 0.1, Color(0.42, 0.32, 0.20))
	_mat("bloodbag", 0.5, Color(0.60, 0.12, 0.16))
	_mat("dandelion", 0.1, Color(0.95, 0.85, 0.25))
	_food("cloudberry", 12, 40, 1000, 1.0, Color(0.92, 0.72, 0.25))


	# ── 확장: 채집물 · 부산물 ───────────────────────────────
	_mat("birch_seeds", 0.1, Color(0.72, 0.78, 0.52))
	_mat("fir_cone", 0.1, Color(0.38, 0.30, 0.20))
	_mat("raspberry_seeds", 0.1, Color(0.82, 0.28, 0.34))
	_mat("vine_seeds", 0.1, Color(0.45, 0.68, 0.36))
	_mat("jute_red", 0.3, Color(0.72, 0.20, 0.22))
	_mat("jute_blue", 0.3, Color(0.24, 0.32, 0.68))
	_mat("leather_belt", 1.0, Color(0.48, 0.34, 0.22), 20)
	_mat("wisp", 0.1, Color(0.90, 0.95, 0.70), 20)
	_mat("root", 1.0, Color(0.40, 0.34, 0.22))
	_mat("iron_ingot_scrap", 4.0, Color(0.52, 0.50, 0.48), 30, false)
	_mat("tar", 1.0, Color(0.10, 0.09, 0.08))
	_mat("bat_wing", 0.3, Color(0.28, 0.22, 0.26))
	_mat("serpent_scale", 1.0, Color(0.30, 0.58, 0.52))
	_mat("serpent_trophy_scale", 2.0, Color(0.26, 0.52, 0.46), 20)
	_mat("bone_mass", 3.0, Color(0.72, 0.72, 0.60), 20)
	_mat("chitin", 2.0, Color(0.62, 0.55, 0.30))
	_mat("marble", 3.0, Color(0.90, 0.88, 0.84), 50, false)
	_mat("grausten", 3.0, Color(0.45, 0.44, 0.42), 50, false)
	_mat("ceramic_plate", 2.0, Color(0.78, 0.72, 0.62), 20)
	_mat("proustite", 2.0, Color(0.72, 0.28, 0.24), 30, false)

	# ── 확장: 보물 (던전 상자) ──────────────────────────────
	_mat("ruby", 0.3, Color(0.85, 0.12, 0.22), 20)
	_mat("amber", 0.3, Color(0.92, 0.62, 0.18), 20)
	_mat("amber_pearl", 0.3, Color(0.96, 0.76, 0.32), 20)
	_mat("coins", 0.1, Color(0.92, 0.80, 0.30), 999)
	_mat("silver_necklace", 0.5, Color(0.88, 0.90, 0.94), 10)

	# ── 확장: 물고기 ────────────────────────────────────────
	_food("perch", 18, 9, 700, 1.0, Color(0.58, 0.68, 0.52))
	_food("pike", 24, 11, 800, 1.0, Color(0.48, 0.58, 0.44))
	_food("tuna", 30, 14, 900, 1.0, Color(0.42, 0.52, 0.66))
	_food("trollfish", 28, 12, 900, 1.0, Color(0.46, 0.56, 0.48))
	_food("magmafish", 40, 18, 1000, 1.0, Color(0.90, 0.42, 0.18))
	_food("northern_salmon", 34, 16, 950, 1.0, Color(0.88, 0.48, 0.40))
	_food("cooked_perch", 40, 20, 1200, 2.0, Color(0.72, 0.66, 0.50))
	_food("cooked_pike", 48, 24, 1300, 2.0, Color(0.70, 0.64, 0.48))
	_food("cooked_tuna", 55, 28, 1400, 3.0, Color(0.66, 0.62, 0.56))
	_food("cooked_magmafish", 78, 34, 1600, 4.0, Color(0.82, 0.52, 0.28))

	# ── 확장: 요리 ──────────────────────────────────────────
	_food("grilled_neck_tail", 26, 16, 1000, 2.0, Color(0.72, 0.62, 0.42))
	_food("honey_glazed_chicken", 60, 34, 1600, 3.0, Color(0.86, 0.62, 0.28))
	_food("boar_jerky", 23, 23, 1400, 2.0, Color(0.60, 0.34, 0.24))
	_food("deer_stew", 45, 40, 1600, 3.0, Color(0.62, 0.42, 0.28))
	_food("minced_meat_sauce", 55, 40, 1600, 3.0, Color(0.68, 0.30, 0.26))
	_food("bread_and_honey", 46, 34, 1500, 2.0, Color(0.90, 0.76, 0.42))
	_food("mushroom_stew", 40, 30, 1500, 2.0, Color(0.80, 0.70, 0.52))
	_food("berry_pie", 34, 46, 1500, 2.0, Color(0.78, 0.32, 0.42))
	_food("wolf_skewer", 58, 34, 1600, 3.0, Color(0.60, 0.38, 0.24))
	_food("serpent_stew", 80, 44, 1800, 4.0, Color(0.48, 0.66, 0.52))
	_food("fish_and_bread", 62, 52, 1700, 3.0, Color(0.80, 0.72, 0.56))
	_food("blood_sausage", 68, 30, 1700, 3.0, Color(0.48, 0.16, 0.20))
	_food("misthare_supreme", 85, 60, 1800, 4.0, Color(0.72, 0.68, 0.82))
	items["misthare_supreme"]["eitr"] = 35.0
	_food("yggdrasil_porridge", 55, 40, 1800, 3.0, Color(0.62, 0.80, 0.58))
	items["yggdrasil_porridge"]["eitr"] = 65.0
	_food("seeker_aspic", 60, 46, 1800, 3.0, Color(0.55, 0.62, 0.32))
	items["seeker_aspic"]["eitr"] = 45.0

	# ── 확장: 벌꿀술 ────────────────────────────────────────
	_add("mead_tasty", {"t": T.CONSUMABLE, "st": 10, "w": 1.0, "col": Color(0.92, 0.72, 0.30),
		"potion": {"stam": 40.0, "over": 5.0}})
	_add("mead_medium_health", {"t": T.CONSUMABLE, "st": 10, "w": 1.0,
		"col": Color(0.85, 0.20, 0.26), "potion": {"heal": 75.0, "over": 10.0}})
	_add("mead_minor_eitr", {"t": T.CONSUMABLE, "st": 10, "w": 1.0,
		"col": Color(0.62, 0.52, 0.95), "potion": {"eitr": 60.0, "over": 10.0}})
	_add("mead_lingering_stamina", {"t": T.CONSUMABLE, "st": 10, "w": 1.0,
		"col": Color(0.95, 0.85, 0.35), "potion": {"stam": 160.0, "over": 20.0}})
	_add("mead_bzerker", {"t": T.CONSUMABLE, "st": 10, "w": 1.0,
		"col": Color(0.85, 0.35, 0.15), "potion": {"rage": 1.5, "dur": 60.0}})

	# ── 확장: 무기 ──────────────────────────────────────────
	_wep("wood_club", S.CLUBS, {D.BLUNT: 12.0}, 1.2, 10.0, 2.0, 30.0, Color(0.42, 0.30, 0.18), {"wood": 3})
	_wep("bone_knife", S.KNIVES, {D.PIERCE: 16.0, D.SLASH: 8.0}, 1.95, 8.0, 1.8, 12.0, Color(0.80, 0.78, 0.68), {"bone_fragments": 6})
	_wep("bronze_knife", S.KNIVES, {D.PIERCE: 22.0, D.SLASH: 16.0}, 1.95, 9.0, 1.9, 14.0, Color(0.80, 0.55, 0.22), {"bronze": 2})
	_wep("iron_knife", S.KNIVES, {D.PIERCE: 32.0, D.SLASH: 24.0}, 2.0, 10.0, 1.9, 15.0, Color(0.62, 0.62, 0.64), {"iron": 3})
	_wep("silver_knife", S.KNIVES, {D.PIERCE: 42.0, D.SPIRIT: 20.0}, 2.0, 11.0, 2.0, 16.0, Color(0.86, 0.88, 0.92), {"silver": 3})
	_wep("blackmetal_knife", S.KNIVES, {D.PIERCE: 55.0, D.SLASH: 30.0}, 2.05, 12.0, 2.0, 18.0, Color(0.24, 0.24, 0.28), {"black_metal": 3})
	_wep("bronze_spear", S.SPEARS, {D.PIERCE: 34.0}, 1.05, 17.0, 3.2, 32.0, Color(0.80, 0.55, 0.22), {"bronze": 3})
	_wep("ancient_bark_spear", S.SPEARS, {D.PIERCE: 40.0, D.POISON: 20.0}, 1.05, 18.0, 3.3, 30.0, Color(0.30, 0.26, 0.20), {"ancient_bark": 6, "iron": 2})
	_wep("blackmetal_spear", S.SPEARS, {D.PIERCE: 78.0}, 1.0, 22.0, 3.5, 40.0, Color(0.24, 0.24, 0.28), {"black_metal": 4})
	_wep("battleaxe_crystal", S.AXES, {D.BLUNT: 90.0, D.SLASH: 40.0}, 0.75, 30.0, 3.0, 90.0, Color(0.70, 0.92, 1.00), {"crystal": 6, "silver": 4}, 4)
	_wep("porcupine", S.CLUBS, {D.BLUNT: 55.0, D.PIERCE: 40.0}, 0.95, 24.0, 2.4, 70.0, Color(0.55, 0.52, 0.48), {"iron": 4, "needle": 6})
	_wep("dagger_dyrnwyn", S.SWORDS, {D.SLASH: 82.0, D.FIRE: 55.0}, 1.25, 20.0, 2.5, 42.0, Color(1.00, 0.55, 0.20), {"flametal": 4, "surtling_core": 4})
	_wep("stagbreaker", S.CLUBS, {D.BLUNT: 60.0}, 0.7, 30.0, 2.6, 100.0, Color(0.70, 0.62, 0.42), {"wood": 8, "hard_antler": 4})
	_wep("crystal_battleaxe", S.AXES, {D.SLASH: 100.0, D.FROST: 30.0}, 0.72, 32.0, 3.1, 95.0, Color(0.72, 0.90, 1.00), {"crystal": 8}, 5)

	# ── 확장: 화살 · 볼트 ───────────────────────────────────
	_ammo("bone_arrow", {D.PIERCE: 26.0}, Color(0.84, 0.82, 0.72))
	_ammo("silver_arrow", {D.PIERCE: 58.0, D.SPIRIT: 20.0}, Color(0.88, 0.90, 0.94))
	_ammo("carapace_arrow", {D.PIERCE: 72.0}, Color(0.32, 0.34, 0.24))
	_ammo("flametal_arrow", {D.PIERCE: 68.0, D.FIRE: 40.0}, Color(0.95, 0.42, 0.15))

	# ── 확장: 방패 ──────────────────────────────────────────
	_shield("bronze_buckler", 20.0, 2.4, Color(0.80, 0.55, 0.22), {"bronze": 6})
	_shield("bone_tower_shield", 38.0, 1.2, Color(0.82, 0.80, 0.70), {"withered_bone": 10, "iron": 4})
	_shield("serpent_scale_shield", 46.0, 1.4, Color(0.32, 0.58, 0.52), {"serpent_scale": 12, "iron": 4})
	_shield("flametal_shield", 62.0, 1.6, Color(0.95, 0.45, 0.18), {"flametal": 8, "yggdrasil_wood": 8})

	# ── 확장: 방어구 ────────────────────────────────────────
	_armor("root_mask", 6.0, A.HEAD, 0.0, Color(0.42, 0.36, 0.24), {"root": 6, "ancient_bark": 4},
		{"res_poison": 0.5})
	_armor("root_harnesk", 6.0, A.CHEST, 0.0, Color(0.42, 0.36, 0.24), {"root": 10, "ancient_bark": 6},
		{"res_poison": 0.5})
	_armor("root_leggings", 6.0, A.LEGS, 0.0, Color(0.42, 0.36, 0.24), {"root": 10, "ancient_bark": 6})
	_armor("linen_hood", 20.0, A.HEAD, 0.0, Color(0.88, 0.86, 0.76), {"linen_thread": 10})
	_armor("fenris_hood", 16.0, A.HEAD, 0.05, Color(0.66, 0.62, 0.60), {"wolf_pelt": 4, "wolf_fang": 2},
		{"res_fire": 0.5})
	_armor("fenris_coat", 16.0, A.CHEST, 0.05, Color(0.66, 0.62, 0.60), {"wolf_pelt": 8, "wolf_fang": 4})
	_armor("fenris_leggings", 16.0, A.LEGS, 0.05, Color(0.66, 0.62, 0.60), {"wolf_pelt": 8, "wolf_fang": 4})
	_armor("eitr_weave_hood", 24.0, A.HEAD, 0.0, Color(0.62, 0.55, 0.90), {"eitr": 8, "linen_thread": 10})
	_armor("eitr_weave_robe", 24.0, A.CHEST, 0.0, Color(0.62, 0.55, 0.90), {"eitr": 12, "linen_thread": 16})
	_armor("eitr_weave_trousers", 24.0, A.LEGS, 0.0, Color(0.62, 0.55, 0.90), {"eitr": 12, "linen_thread": 16})
	_armor("flametal_helmet", 30.0, A.HEAD, -0.05, Color(0.95, 0.45, 0.18), {"flametal": 8, "ceramic_plate": 4})
	_armor("flametal_cuirass", 30.0, A.CHEST, -0.05, Color(0.95, 0.45, 0.18), {"flametal": 14, "ceramic_plate": 6})
	_armor("flametal_greaves", 30.0, A.LEGS, -0.05, Color(0.95, 0.45, 0.18), {"flametal": 14, "ceramic_plate": 6})
	_armor("linen_cape", 2.0, A.CAPE, 0.0, Color(0.90, 0.88, 0.78), {"linen_thread": 20, "silver": 2})
	_armor("ash_cape", 3.0, A.CAPE, 0.0, Color(0.45, 0.22, 0.16), {"flametal": 4, "charred_bone": 10},
		{"res_fire": 1.0})

	# ── 확장: 트로피 ────────────────────────────────────────
	_trophy("trophy_serpent", Color(0.32, 0.58, 0.52))
	_trophy("trophy_leech", Color(0.45, 0.20, 0.28))
	_trophy("trophy_surtling", Color(1.00, 0.50, 0.15))
	_trophy("trophy_bat", Color(0.30, 0.24, 0.28))
	_trophy("trophy_hare", Color(0.78, 0.76, 0.72))
	_trophy("trophy_gjall", Color(0.62, 0.30, 0.22))
	_trophy("trophy_tick", Color(0.50, 0.42, 0.26))
	_trophy("trophy_dvergr", Color(0.55, 0.58, 0.62))
	_trophy("trophy_asksvin", Color(0.60, 0.48, 0.38))
	_trophy("trophy_charred", Color(0.30, 0.20, 0.18))
	_trophy("trophy_fader", Color(0.90, 0.55, 0.25))

	# ── 건축 자재(아이템 형태) ───────────────────────────────
	for bid in ["wood_wall", "wood_floor", "wood_roof", "wood_beam", "wood_door",
			"stone_wall", "stone_floor", "workbench", "forge", "campfire",
			"bed", "chest", "cooking_station", "smelter", "charcoal_kiln", "portal"]:
		if not items.has(bid):
			_add(bid, {"t": T.BUILDING, "st": 1, "w": 1.0, "col": Color(0.6, 0.5, 0.35)})

func _food(id: String, hp: int, sp: int, dur: int, reg: float, col: Color) -> void:
	_add(id, {"t": T.CONSUMABLE, "st": 20, "w": 0.5, "col": col,
		"hp": float(hp), "sp": float(sp), "dur": float(dur), "reg": reg})

func _wep(id: String, skill: int, dmg: Dictionary, spd: float, stam: float, rng: float,
		kb: float, col: Color, upmat: Dictionary, tier: int = 0) -> void:
	_add(id, {"t": T.WEAPON, "w": 2.0, "col": col, "dmg": dmg, "spd": spd, "stam": stam,
		"rng": rng, "kb": kb, "skill": skill, "tier": tier, "up": 4, "upmat": upmat})

## 지팡이: eitr 소모, mode = bolt / shield / summon
func _staff(id: String, dmg: Dictionary, eitr_cost: float, col: Color,
		upmat: Dictionary, mode: String = "bolt") -> void:
	_add(id, {"t": T.WEAPON, "w": 3.0, "col": col, "dmg": dmg, "spd": 0.9,
		"stam": 4.0, "rng": 40.0, "kb": 30.0, "skill": S.KNIVES,
		"staff": mode, "eitr_cost": eitr_cost, "up": 4, "upmat": upmat})

func _pick(id: String, tier: int, dmg: float, spd: float, col: Color, upmat: Dictionary) -> void:
	_add(id, {"t": T.TOOL, "w": 3.0, "col": col, "dmg": {D.PICKAXE: dmg, D.BLUNT: dmg * 0.4},
		"spd": spd, "stam": 16.0, "rng": 2.2, "kb": 20.0, "skill": S.PICKAXES,
		"mine_tier": tier, "up": 4, "upmat": upmat})

func _bow(id: String, dmg: float, spd: float, drawspd: float, col: Color, upmat: Dictionary) -> void:
	_add(id, {"t": T.WEAPON, "w": 2.0, "col": col, "dmg": {D.PIERCE: dmg}, "spd": spd,
		"stam": 8.0, "rng": 100.0, "kb": 20.0, "skill": S.BOWS, "bow": true,
		"draw": drawspd, "up": 4, "upmat": upmat})

func _ammo(id: String, dmg: Dictionary, col: Color) -> void:
	_add(id, {"t": T.AMMO, "st": 100, "w": 0.1, "col": col, "dmg": dmg})

func _shield(id: String, block: float, parry: float, col: Color, upmat: Dictionary) -> void:
	_add(id, {"t": T.SHIELD, "w": 4.0, "col": col, "block": block, "parry": parry,
		"skill": S.BLOCK, "up": 4, "upmat": upmat})

func _armor(id: String, ar: float, slot: int, mov: float, col: Color, upmat: Dictionary,
		extra: Dictionary = {}) -> void:
	var d := {"t": T.ARMOR, "w": 4.0, "col": col, "ar": ar, "slot": slot, "mov": mov,
		"up": 4, "upmat": upmat}
	for k in extra:
		d[k] = extra[k]
	_add(id, d)

# ────────────────────────────────────────────────── 아이콘(절차 생성)
func icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var tex := _make_icon(id)
	_icons[id] = tex
	return tex

func _make_icon(id: String) -> Texture2D:
	var sz := 64
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var it: Dictionary = items.get(id, {})
	var col: Color = it.get("col", Color(0.7, 0.7, 0.7))
	var t: int = it.get("t", T.MATERIAL)
	var dark := col.darkened(0.45)
	var light := col.lightened(0.35)
	match t:
		T.WEAPON:
			if it.get("bow", false):
				_arc(img, Vector2(38, 32), 22.0, -1.2, 1.2, 5.0, col)
				_line(img, Vector2(22, 12), Vector2(22, 52), 1.5, light)
			else:
				_quad(img, Vector2(30, 6), Vector2(40, 16), Vector2(24, 46), Vector2(16, 40), light)
				_quad(img, Vector2(22, 40), Vector2(28, 46), Vector2(16, 58), Vector2(10, 52), dark)
		T.TOOL:
			_line(img, Vector2(18, 54), Vector2(42, 16), 4.0, dark)
			_quad(img, Vector2(30, 6), Vector2(52, 16), Vector2(46, 26), Vector2(28, 18), col)
		T.SHIELD:
			_shield_shape(img, col, dark, light)
		T.ARMOR:
			_quad(img, Vector2(18, 14), Vector2(46, 14), Vector2(50, 52), Vector2(14, 52), col)
			_quad(img, Vector2(26, 14), Vector2(38, 14), Vector2(38, 26), Vector2(26, 26), dark)
		T.AMMO:
			_line(img, Vector2(12, 52), Vector2(48, 16), 3.0, dark)
			_quad(img, Vector2(44, 10), Vector2(54, 10), Vector2(54, 20), Vector2(44, 20), col)
		T.CONSUMABLE:
			_disc(img, Vector2(32, 36), 20.0, col)
			_disc(img, Vector2(26, 28), 6.0, light)
		T.TROPHY:
			_quad(img, Vector2(24, 24), Vector2(40, 24), Vector2(44, 52), Vector2(20, 52), col)
			_line(img, Vector2(24, 24), Vector2(14, 8), 3.0, light)
			_line(img, Vector2(40, 24), Vector2(50, 8), 3.0, light)
		T.BUILDING:
			_quad(img, Vector2(10, 30), Vector2(32, 12), Vector2(54, 30), Vector2(32, 30), light)
			_quad(img, Vector2(16, 30), Vector2(48, 30), Vector2(48, 54), Vector2(16, 54), col)
		_:
			# 재료: 다듬어진 돌덩이 실루엣
			_quad(img, Vector2(14, 40), Vector2(30, 16), Vector2(52, 30), Vector2(38, 52), col)
			_quad(img, Vector2(14, 40), Vector2(30, 16), Vector2(32, 34), Vector2(22, 46), light)
	var tex := ImageTexture.create_from_image(img)
	return tex

# ── 아주 작은 소프트웨어 래스터라이저 헬퍼 ───────────────────
func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var d := img.get_pixel(x, y)
	img.set_pixel(x, y, d.blend(c) if d.a > 0.0 else c)

func _disc(img: Image, ctr: Vector2, r: float, c: Color) -> void:
	var r2 := r * r
	for y in range(int(ctr.y - r) - 1, int(ctr.y + r) + 2):
		for x in range(int(ctr.x - r) - 1, int(ctr.x + r) + 2):
			var dx := float(x) - ctr.x
			var dy := float(y) - ctr.y
			if dx * dx + dy * dy <= r2:
				_px(img, x, y, c)

func _line(img: Image, a: Vector2, b: Vector2, w: float, c: Color) -> void:
	var steps := int(a.distance_to(b)) + 1
	for i in range(steps + 1):
		var p := a.lerp(b, float(i) / float(steps))
		_disc(img, p, w, c)

func _tri(img: Image, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	var minx := int(floor(min(a.x, min(b.x, c.x))))
	var maxx := int(ceil(max(a.x, max(b.x, c.x))))
	var miny := int(floor(min(a.y, min(b.y, c.y))))
	var maxy := int(ceil(max(a.y, max(b.y, c.y))))
	var d := (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
	if absf(d) < 0.0001:
		return
	for y in range(miny, maxy + 1):
		for x in range(minx, maxx + 1):
			var p := Vector2(float(x), float(y))
			var w0 := ((b.y - c.y) * (p.x - c.x) + (c.x - b.x) * (p.y - c.y)) / d
			var w1 := ((c.y - a.y) * (p.x - c.x) + (a.x - c.x) * (p.y - c.y)) / d
			var w2 := 1.0 - w0 - w1
			if w0 >= 0.0 and w1 >= 0.0 and w2 >= 0.0:
				_px(img, x, y, col)

func _quad(img: Image, a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	_tri(img, a, b, c, col)
	_tri(img, a, c, d, col)

func _arc(img: Image, ctr: Vector2, r: float, a0: float, a1: float, w: float, col: Color) -> void:
	var steps := 48
	for i in range(steps + 1):
		var ang: float = lerp(a0, a1, float(i) / float(steps))
		_disc(img, ctr + Vector2(cos(ang), sin(ang)) * r, w * 0.5, col)

func _shield_shape(img: Image, col: Color, dark: Color, light: Color) -> void:
	_quad(img, Vector2(14, 10), Vector2(50, 10), Vector2(50, 36), Vector2(14, 36), col)
	_tri(img, Vector2(14, 36), Vector2(50, 36), Vector2(32, 58), col)
	_line(img, Vector2(32, 10), Vector2(32, 56), 2.0, dark)
	_line(img, Vector2(16, 24), Vector2(48, 24), 2.0, light)
