extends Node
## 전역 상수 · 열거형 · 튜닝 값.
## 오토로드 이름: Const

# ─────────────────────────────────────────────── 월드
const WORLD_RADIUS := 2400.0          # 월드 반지름(m). 이 밖은 낙하하는 바다 끝.
const WATER_LEVEL := 30.0             # 해수면 높이
const CHUNK_SIZE := 64.0              # 지형 청크 한 변 길이(m)
const CHUNK_RES := 32                 # 청크당 격자 분할 수 (LOD0)
const VIEW_CHUNKS := 6                # 플레이어 기준 로드 반경(청크)
const DAY_LENGTH := 1800.0            # 하루 길이(초) = 30분

# ─────────────────────────────────────────────── 물리 레이어 (1-indexed 비트)
const L_WORLD := 1
const L_PLAYER := 2
const L_ENEMY := 4
const L_RESOURCE := 8
const L_BUILDING := 16
const L_ITEM := 32
const L_WATER := 64
const L_PROJECTILE := 128

# ─────────────────────────────────────────────── 바이옴
enum Biome { OCEAN, MEADOWS, BLACKFOREST, SWAMP, MOUNTAIN, PLAINS, MISTLANDS, ASHLANDS }

const BIOME_KEY := {
	Biome.OCEAN: "BIOME_OCEAN",
	Biome.MEADOWS: "BIOME_MEADOWS",
	Biome.BLACKFOREST: "BIOME_BLACKFOREST",
	Biome.SWAMP: "BIOME_SWAMP",
	Biome.MOUNTAIN: "BIOME_MOUNTAIN",
	Biome.PLAINS: "BIOME_PLAINS",
	Biome.MISTLANDS: "BIOME_MISTLANDS",
	Biome.ASHLANDS: "BIOME_ASHLANDS",
}

## 바이옴별 지면 색 (로우폴리 버텍스 컬러용)
const BIOME_GROUND := {
	Biome.OCEAN: Color(0.42, 0.40, 0.31),
	Biome.MEADOWS: Color(0.26, 0.45, 0.14),
	Biome.BLACKFOREST: Color(0.16, 0.26, 0.14),
	Biome.SWAMP: Color(0.21, 0.20, 0.13),
	Biome.MOUNTAIN: Color(0.86, 0.89, 0.94),
	Biome.PLAINS: Color(0.60, 0.55, 0.26),
	Biome.MISTLANDS: Color(0.16, 0.17, 0.19),
	Biome.ASHLANDS: Color(0.26, 0.13, 0.11),
}

## 바이옴별 안개 색 / 밀도 — 발헤임 특유의 분위기를 좌우하는 값
const BIOME_FOG := {
	Biome.OCEAN: {"c": Color(0.55, 0.66, 0.76), "d": 0.0030},
	Biome.MEADOWS: {"c": Color(0.62, 0.72, 0.78), "d": 0.0026},
	Biome.BLACKFOREST: {"c": Color(0.32, 0.40, 0.38), "d": 0.0075},
	Biome.SWAMP: {"c": Color(0.28, 0.30, 0.24), "d": 0.0110},
	Biome.MOUNTAIN: {"c": Color(0.78, 0.84, 0.92), "d": 0.0060},
	Biome.PLAINS: {"c": Color(0.72, 0.70, 0.55), "d": 0.0032},
	Biome.MISTLANDS: {"c": Color(0.36, 0.38, 0.42), "d": 0.0260},
	Biome.ASHLANDS: {"c": Color(0.42, 0.16, 0.10), "d": 0.0090},
}

## 바이옴 위험도(0~6). 진행 순서와 동일.
const BIOME_TIER := {
	Biome.OCEAN: 0,
	Biome.MEADOWS: 0,
	Biome.BLACKFOREST: 1,
	Biome.SWAMP: 2,
	Biome.MOUNTAIN: 3,
	Biome.PLAINS: 4,
	Biome.MISTLANDS: 5,
	Biome.ASHLANDS: 6,
}

# ─────────────────────────────────────────────── 데미지
enum Dmg { BLUNT, SLASH, PIERCE, CHOP, PICKAXE, FIRE, FROST, POISON, LIGHTNING, SPIRIT }

const DMG_KEY := {
	Dmg.BLUNT: "DMG_BLUNT", Dmg.SLASH: "DMG_SLASH", Dmg.PIERCE: "DMG_PIERCE",
	Dmg.CHOP: "DMG_CHOP", Dmg.PICKAXE: "DMG_PICKAXE", Dmg.FIRE: "DMG_FIRE",
	Dmg.FROST: "DMG_FROST", Dmg.POISON: "DMG_POISON",
	Dmg.LIGHTNING: "DMG_LIGHTNING", Dmg.SPIRIT: "DMG_SPIRIT",
}

# ─────────────────────────────────────────────── 스킬
enum Skill { RUN, JUMP, SWIM, SNEAK, BLOCK, AXES, CLUBS, SWORDS, SPEARS, KNIVES, BOWS, UNARMED, PICKAXES, WOODCUTTING }

const SKILL_KEY := {
	Skill.RUN: "SKILL_RUN", Skill.JUMP: "SKILL_JUMP", Skill.SWIM: "SKILL_SWIM",
	Skill.SNEAK: "SKILL_SNEAK", Skill.BLOCK: "SKILL_BLOCK", Skill.AXES: "SKILL_AXES",
	Skill.CLUBS: "SKILL_CLUBS", Skill.SWORDS: "SKILL_SWORDS", Skill.SPEARS: "SKILL_SPEARS",
	Skill.KNIVES: "SKILL_KNIVES", Skill.BOWS: "SKILL_BOWS", Skill.UNARMED: "SKILL_UNARMED",
	Skill.PICKAXES: "SKILL_PICKAXES", Skill.WOODCUTTING: "SKILL_WOODCUTTING",
}

const SKILL_MAX := 100.0

# ─────────────────────────────────────────────── 아이템 분류
enum ItemType { MATERIAL, CONSUMABLE, WEAPON, SHIELD, ARMOR, TOOL, AMMO, BUILDING, TROPHY }

enum ArmorSlot { NONE, HEAD, CHEST, LEGS, CAPE }

# ─────────────────────────────────────────────── 플레이어 기본치
const BASE_HP := 25.0
const BASE_STAMINA := 50.0
const FOOD_SLOTS := 3
const STAMINA_REGEN := 5.0          # 초당
const STAMINA_REGEN_DELAY := 1.0    # 소모 후 재생까지 대기(초)
const SPRINT_DRAIN := 10.0          # 초당
const JUMP_COST := 10.0
const SWIM_DRAIN := 4.0
const DODGE_COST := 10.0
const ATTACK_COST_MULT := 1.0

const INV_COLS := 8
const INV_ROWS := 4

# ─────────────────────────────────────────────── 유틸
static func dmg_color(t: int) -> Color:
	match t:
		Dmg.FIRE: return Color(1.0, 0.45, 0.15)
		Dmg.FROST: return Color(0.55, 0.85, 1.0)
		Dmg.POISON: return Color(0.45, 0.90, 0.30)
		Dmg.LIGHTNING: return Color(0.75, 0.80, 1.0)
		Dmg.SPIRIT: return Color(0.85, 0.95, 0.85)
		_: return Color(1, 1, 1)

## 발헤임의 스킬 배율: 레벨이 오를수록 데미지 하한이 올라간다.
static func skill_damage_mult(level: float) -> float:
	var t := clampf(level / SKILL_MAX, 0.0, 1.0)
	return lerpf(0.55, 1.0, t)
