class_name Dungeon
extends Node3D
## 절차적 던전 — 매장지(검은 숲) · 수몰묘지(늪) · 얼음동굴(설산).
##
## 지상 세계와 섞이지 않도록 지하 깊은 곳(y = -900 아래)의 별도 공간에 만들고,
## 입구에서 내부로 순간이동시킨다. 지형 청크와 충돌하지 않아 안정적이다.

const CELL := 9.0            # 방 한 칸 크기(m)
const WALL_H := 5.0
const DEPTH := -900.0        # 던전 공간의 기준 높이

const KINDS := {
	"crypt": {
		"n": "DUNGEON_CRYPT", "biome": Const.Biome.BLACKFOREST,
		"rooms": 14, "mobs": ["skeleton", "greydwarf"], "boss_mob": "greydwarf_brute",
		"stone": Color(0.30, 0.28, 0.25), "floor": Color(0.21, 0.20, 0.18),
		"loot": [["bone_fragments", 3, 8], ["surtling_core", 1, 2], ["coal", 2, 6],
			["flint", 2, 5], ["wood_arrow", 5, 15], ["ancient_seed", 1, 1],
			["ruby", 0, 0]],
		"light": Color(1.0, 0.62, 0.26),
	},
	"sunken": {
		"n": "DUNGEON_SUNKEN", "biome": Const.Biome.SWAMP,
		"rooms": 18, "mobs": ["draugr", "blob", "skeleton"], "boss_mob": "draugr_elite",
		"stone": Color(0.22, 0.24, 0.20), "floor": Color(0.16, 0.17, 0.14),
		"loot": [["iron_scrap", 2, 5], ["withered_bone", 1, 3], ["entrails", 1, 4],
			["chain", 0, 1], ["guck", 1, 3], ["coal", 2, 6]],
		"light": Color(0.55, 0.95, 0.45),
	},
	"cave": {
		"n": "DUNGEON_CAVE", "biome": Const.Biome.MOUNTAIN,
		"rooms": 12, "mobs": ["fenring", "wolf"], "boss_mob": "stone_golem",
		"stone": Color(0.52, 0.57, 0.62), "floor": Color(0.44, 0.48, 0.53),
		"loot": [["obsidian", 2, 5], ["freeze_gland", 1, 3], ["wolf_pelt", 1, 3],
			["silver_ore", 0, 2], ["crystal", 1, 2]],
		"light": Color(0.70, 0.90, 1.0),
	},
}

## 특수 방 템플릿. 균일한 미로가 아니라 "무엇이 있는 방"이 되게 한다.
## w = 뽑기 가중치. hall 은 나머지를 채우는 기본 통로방.
const ROOMS := {
	"hall": {"w": 40},
	"treasure": {"w": 9},    # 보물방 — 상자 여럿 + 금화 더미
	"altar": {"w": 7},       # 제단방 — 공물대 + 촛불
	"prison": {"w": 8},      # 감옥방 — 뼈 창살 + 해골
	"trap": {"w": 8},        # 함정방 — 가시 바닥 + 몰려 있는 적
	"spawner": {"w": 6},     # 산란방 — 알집 + 무리
	"library": {"w": 6},     # 서고 — 룬석(전승 문구) + 촛대
	"mushroom": {"w": 8},    # 버섯방 — 발광 버섯 군락
	"flooded": {"w": 8},     # 침수방 — 물웅덩이 + 이끼
	"crypt_niche": {"w": 7}, # 납골당 — 벽감에 늘어선 관
	"forge": {"w": 5},       # 대장간 — 모루·화덕·부서진 도구
	"barracks": {"w": 6},    # 병영 — 침상과 무기걸이, 잠든 적
	"well": {"w": 5},        # 우물방 — 가운데 깊은 구멍과 두레박
	"pillar": {"w": 7},      # 열주실 — 기둥이 늘어선 큰 방
	"collapsed": {"w": 7},   # 붕괴실 — 무너진 천장과 잔해 더미
	"banquet": {"w": 5},     # 연회실 — 긴 식탁과 의자
	"shrine": {"w": 5},      # 사당 — 작은 신상과 공물
	"web": {"w": 6},         # 거미줄방 — 알집과 늘어진 실
	"bone_field": {"w": 6},  # 유해방 — 바닥에 흩어진 뼈
	"cellar": {"w": 6},      # 저장고 — 통과 자루가 쌓인 방
	"observatory": {"w": 4}, # 관측실 — 천장이 뚫린 방과 별빛
}

## 룬석 전승 문구 키
const LORE_KEYS := ["LORE_1", "LORE_2", "LORE_3", "LORE_4", "LORE_5",
	"LORE_6", "LORE_7", "LORE_8", "LORE_9", "LORE_10"]

var kind := "crypt"
var seed_v := 0
var origin := Vector3.ZERO      # 던전 내부 좌표계 원점
var exit_to := Vector3.ZERO     # 나갈 때 돌아갈 지상 좌표
var cells: Dictionary = {}      # Vector2i -> true (통로가 뚫린 칸)
var cell_kind: Dictionary = {}  # Vector2i -> 방 종류(ROOMS 참조)
var generated := false

static func make(k: String, sv: int, exit_pos: Vector3, index: int) -> Dungeon:
	var d := Dungeon.new()
	d.kind = k
	d.seed_v = sv
	d.exit_to = exit_pos
	# 던전끼리 겹치지 않게 인덱스로 공간을 나눈다
	d.origin = Vector3(float(index % 32) * 400.0, DEPTH,
		floor(float(index) / 32.0) * 400.0)
	return d

func cfg() -> Dictionary:
	return KINDS.get(kind, KINDS["crypt"])

# ═══════════════════════════════════════════════ 생성
func generate() -> void:
	if generated:
		return
	generated = true
	var c := cfg()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v

	_carve(rng, int(c["rooms"]))
	_build_geometry(c)
	_populate(rng, c)

## 랜덤 워크 + 곁가지로 방을 뚫는다
func _carve(rng: RandomNumberGenerator, rooms: int) -> void:
	var cur := Vector2i.ZERO
	cells[cur] = true
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var placed := 1
	var guard := 0
	while placed < rooms and guard < 2000:
		guard += 1
		var d: Vector2i = dirs[rng.randi() % 4]
		var nxt := cur + d
		if absi(nxt.x) > 8 or absi(nxt.y) > 8:
			continue
		cur = nxt
		if not cells.has(cur):
			cells[cur] = true
			placed += 1
		# 가끔 갈림길을 만든다
		if rng.randf() < 0.28:
			var b: Vector2i = cur + dirs[rng.randi() % 4]
			if absi(b.x) <= 8 and absi(b.y) <= 8 and not cells.has(b):
				cells[b] = true
				placed += 1

	# 방마다 종류를 배정한다. 입구는 항상 통로방.
	var pool: Array = []
	for k in ROOMS:
		for i in range(int(ROOMS[k]["w"])):
			pool.append(k)
	for c in cells:
		cell_kind[c] = "hall" if c == Vector2i.ZERO \
			else str(pool[rng.randi() % pool.size()])

func _build_geometry(c: Dictionary) -> void:
	var stone: Color = c["stone"]
	var floor_col: Color = c["floor"]
	var mb := MeshBuilder.new()
	var body := StaticBody3D.new()
	body.name = "walls"
	body.collision_layer = Const.L_WORLD
	body.collision_mask = 0
	add_child(body)

	for cell in cells:
		var base := origin + Vector3(float(cell.x) * CELL, 0.0, float(cell.y) * CELL)
		# 바닥
		mb.box(Transform3D(Basis.IDENTITY, base + Vector3(0, -0.25, 0)),
			Vector3(CELL, 0.5, CELL), floor_col)
		# 천장
		mb.box(Transform3D(Basis.IDENTITY, base + Vector3(0, WALL_H + 0.25, 0)),
			Vector3(CELL, 0.5, CELL), stone.darkened(0.25))
		_add_box_col(body, base + Vector3(0, -0.25, 0), Vector3(CELL, 0.5, CELL))
		_add_box_col(body, base + Vector3(0, WALL_H + 0.25, 0), Vector3(CELL, 0.5, CELL))
		# 벽 — 이웃 칸이 없는 방향만
		var sides := {
			Vector2i(1, 0): Vector3(CELL * 0.5, 0, 0),
			Vector2i(-1, 0): Vector3(-CELL * 0.5, 0, 0),
			Vector2i(0, 1): Vector3(0, 0, CELL * 0.5),
			Vector2i(0, -1): Vector3(0, 0, -CELL * 0.5),
		}
		for dir in sides:
			if cells.has(cell + dir):
				continue
			var off: Vector3 = sides[dir]
			var size := Vector3(0.5, WALL_H, CELL) if dir.x != 0 \
				else Vector3(CELL, WALL_H, 0.5)
			var wpos := base + off + Vector3(0, WALL_H * 0.5, 0)
			mb.box(Transform3D(Basis.IDENTITY, wpos), size, stone)
			# 벽에 벽돌 결
			for i in range(3):
				var y := WALL_H * (0.25 + 0.25 * float(i))
				var line_size := Vector3(0.54, 0.06, CELL * 0.9) if dir.x != 0 \
					else Vector3(CELL * 0.9, 0.06, 0.54)
				mb.box(Transform3D(Basis.IDENTITY, base + off + Vector3(0, y, 0)),
					line_size, stone.darkened(0.22))
			_add_box_col(body, wpos, size)

	var mi := MeshInstance3D.new()
	mi.name = "geo"
	mi.mesh = mb.commit()
	# 지하는 태양광이 닿지 않으므로 아주 약한 자체발광을 더해 형태를 남긴다
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	mat.albedo_texture = MatLib.grain_tex
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.35, 0.35, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(0.28, 0.26, 0.24)
	mat.emission_energy_multiplier = 0.08
	mi.material_override = mat
	add_child(mi)

func _add_box_col(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	body.add_child(cs)

func _populate(rng: RandomNumberGenerator, c: Dictionary) -> void:
	var keys: Array = cells.keys()
	var mobs: Array = c["mobs"]
	var light_col: Color = c["light"]
	var far_cell: Vector2i = Vector2i.ZERO
	var far_d := -1.0

	for cell in keys:
		var base := origin + Vector3(float(cell.x) * CELL, 0.0, float(cell.y) * CELL)
		var dd := Vector2(cell).length()
		if dd > far_d:
			far_d = dd
			far_cell = cell
		# 횃불 — 입구 칸에는 반드시, 그 외는 절반쯤
		if cell == Vector2i.ZERO or rng.randf() < 0.62:
			var t := MeshInstance3D.new()
			t.mesh = MeshFactory.piece("torch_stand", Vector3(0.4, 1.6, 0.4),
				Color(0.35, 0.30, 0.24))
			add_child(t)
			t.global_position = base + Vector3(rng.randf_range(-1.6, 1.6), 0.8,
				rng.randf_range(-1.6, 1.6))
			var l := OmniLight3D.new()
			l.light_color = light_col
			l.light_energy = 1.9
			l.omni_range = 10.0
			l.shadow_enabled = false
			l.position = t.position + Vector3(0, 1.0, 0)
			add_child(l)
			Flicker.attach(l, 0.28, 0.9)
			var f := Fx.fire(self, 0.7, light_col)
			f.position = l.position

		if cell == Vector2i.ZERO:
			continue

		# 방 종류별 장식 — 균일한 미로가 아니게 만드는 부분
		var rk := str(cell_kind.get(cell, "hall"))
		_decorate(rk, base, rng, c, light_col)
		if rk == "trap" or rk == "spawner":
			# 이 두 방은 아래 일반 규칙 대신 전용 배치를 쓴다
			continue

		# 몬스터
		if rng.randf() < 0.62 and not mobs.is_empty():
			var id: String = str(mobs[rng.randi() % mobs.size()])
			var e := Enemy.spawn(id, self, base + Vector3(rng.randf_range(-1.5, 1.5),
				0.3, rng.randf_range(-1.5, 1.5)))
			if e:
				e.set_meta("dungeon", true)

		# 상자
		if rng.randf() < 0.33:
			_place_chest(base + Vector3(rng.randf_range(-1.8, 1.8), 0.45,
				rng.randf_range(-1.8, 1.8)), rng, c)

	# 가장 깊은 방: 우두머리 + 큰 보물
	var bpos := origin + Vector3(float(far_cell.x) * CELL, 0.4,
		float(far_cell.y) * CELL)
	var boss := Enemy.spawn(str(c.get("boss_mob", "skeleton")), self, bpos)
	if boss:
		boss.set_meta("dungeon", true)
	_place_chest(bpos + Vector3(1.6, 0.05, 0.0), rng, c, 2)

	# 입구 칸에 출구 표식
	var ex := DungeonExit.new()
	ex.dungeon = self
	add_child(ex)
	ex.global_position = origin + Vector3(0, 0.4, 0)

func _place_chest(pos: Vector3, rng: RandomNumberGenerator, c: Dictionary,
		bonus: int = 1) -> void:
	var box := StorageBox.new(5, 2)
	box.title_key = "UI_CHEST"
	add_child(box)
	box.global_position = pos
	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.piece("chest", Vector3(1.2, 0.9, 0.8), Color(0.46, 0.34, 0.22))
	box.add_child(mi)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.2, 0.9, 0.8)
	cs.shape = bs
	box.add_child(cs)
	var loot: Array = c["loot"]
	for i in range(rng.randi_range(2, 4) * bonus):
		var e: Array = loot[rng.randi() % loot.size()]
		var id := str(e[0])
		if not ItemDB.has_item(id):
			continue
		var amt := rng.randi_range(int(e[1]), int(e[2])) * bonus
		if amt > 0:
			box.storage.add_item(id, amt)

## ══════════════════════════════════════════════ 방 템플릿
func _decorate(rk: String, base: Vector3, rng: RandomNumberGenerator,
		c: Dictionary, light_col: Color) -> void:
	match rk:
		"treasure": _room_treasure(base, rng, c)
		"altar": _room_altar(base, rng, c)
		"prison": _room_prison(base, rng, c)
		"trap": _room_trap(base, rng, c)
		"spawner": _room_spawner(base, rng, c)
		"library": _room_library(base, rng, light_col)
		"mushroom": _room_mushroom(base, rng)
		"flooded": _room_flooded(base, rng, c)
		"crypt_niche": _room_niche(base, rng, c)
		"forge": _room_forge(base, rng, c)
		"barracks": _room_barracks(base, rng, c)
		"well": _room_well(base, rng, c)
		"pillar": _room_pillar(base, rng, c)
		"collapsed": _room_collapsed(base, rng, c)
		"banquet": _room_banquet(base, rng, c)
		"shrine": _room_shrine(base, rng, c, light_col)
		"web": _room_web(base, rng, c)
		"bone_field": _room_bones(base, rng, c)
		"cellar": _room_cellar(base, rng, c)
		"observatory": _room_observatory(base, rng, light_col)

## 보물방 — 상자 셋과 금화 더미. 밝게 밝혀 눈에 띄게 한다.
func _room_treasure(base: Vector3, rng: RandomNumberGenerator, c: Dictionary) -> void:
	for i in range(3):
		var a := TAU * float(i) / 3.0 + rng.randf()
		_place_chest(base + Vector3(cos(a) * 2.4, 0.45, sin(a) * 2.4), rng, c, 2)
	var mb := MeshBuilder.new()
	for i in range(24):
		var a2 := rng.randf() * TAU
		var d := rng.randf_range(0.0, 1.6)
		mb.cyl(Transform3D(Basis(Vector3.RIGHT, PI * 0.5),
			Vector3(cos(a2) * d, rng.randf_range(0.02, 0.22), sin(a2) * d)),
			0.09, 0.09, 0.03, 6, Color(0.92, 0.78, 0.28))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	mi.material_override = MatLib.flat(Color.WHITE, 0.30, 0.75)
	add_child(mi)
	mi.global_position = base
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.86, 0.45)
	l.light_energy = 1.3
	l.omni_range = 7.5
	l.shadow_enabled = false
	l.position = base + Vector3(0, 2.2, 0)
	add_child(l)
	Flicker.attach(l, 0.18, 0.7)

## 제단방 — 돌 공물대와 촛불. 상자 하나가 제단 위에 놓인다.
func _room_altar(base: Vector3, rng: RandomNumberGenerator, c: Dictionary) -> void:
	var stone: Color = c["stone"]
	var mb := MeshBuilder.new()
	mb.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.35, 0)), Vector3(3.0, 0.7, 3.0),
		stone.darkened(0.10))
	mb.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.85, 0)), Vector3(2.2, 0.3, 2.2),
		stone.lightened(0.08))
	for i in range(4):
		var a := TAU * float(i) / 4.0 + PI * 0.25
		mb.cyl(Transform3D(Basis.IDENTITY, Vector3(cos(a) * 1.7, 1.0, sin(a) * 1.7)),
			0.12, 0.10, 0.9, 6, Color(0.90, 0.86, 0.72))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	mi.material_override = MatLib.flat(Color.WHITE, 0.92)
	add_child(mi)
	mi.global_position = base
	for i in range(4):
		var a2 := TAU * float(i) / 4.0 + PI * 0.25
		var lp := base + Vector3(cos(a2) * 1.7, 2.0, sin(a2) * 1.7)
		var fl := Fx.fire(self, 0.35, Color(1.0, 0.80, 0.40))
		fl.global_position = lp
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.78, 0.40)
		l.light_energy = 0.75
		l.omni_range = 4.5
		l.shadow_enabled = false
		add_child(l)
		l.global_position = lp
		Flicker.attach(l, 0.34, 1.3)
	_place_chest(base + Vector3(0, 1.15, 0), rng, c, 2)

## 감옥방 — 뼈 창살과 그 안의 해골
func _room_prison(base: Vector3, rng: RandomNumberGenerator, c: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var bone := Color(0.78, 0.76, 0.66)
	for side in [-1.0, 1.0]:
		for i in range(7):
			var x := -2.7 + float(i) * 0.9
			mb.cyl(Transform3D(Basis.IDENTITY, Vector3(x, 1.4, 2.6 * side)),
				0.09, 0.09, 2.8, 5, bone)
		mb.box(Transform3D(Basis.IDENTITY, Vector3(0, 2.85, 2.6 * side)),
			Vector3(6.0, 0.16, 0.16), bone.darkened(0.15))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	mi.material_override = MatLib.flat(Color.WHITE, 0.90)
	add_child(mi)
	mi.global_position = base
	for i in range(rng.randi_range(1, 2)):
		var e := Enemy.spawn("skeleton", self,
			base + Vector3(rng.randf_range(-2.0, 2.0), 0.3, 3.2 * (1.0 if i % 2 == 0 else -1.0)))
		if e:
			e.set_meta("dungeon", true)
	if rng.randf() < 0.5:
		_place_chest(base + Vector3(rng.randf_range(-1.5, 1.5), 0.45, 0.0), rng, c)

## 함정방 — 가시 바닥과 매복한 무리
func _room_trap(base: Vector3, rng: RandomNumberGenerator, c: Dictionary) -> void:
	var mb := MeshBuilder.new()
	for i in range(26):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 3.2)
		mb.cone(Transform3D(Basis.IDENTITY,
			Vector3(cos(a) * d, 0.0, sin(a) * d)), 0.10, rng.randf_range(0.4, 0.8), 5,
			Color(0.42, 0.40, 0.36))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	mi.material_override = MatLib.flat(Color.WHITE, 0.75, 0.25)
	add_child(mi)
	mi.global_position = base
	var mobs: Array = c["mobs"]
	for i in range(rng.randi_range(2, 3)):
		if mobs.is_empty():
			break
		var e := Enemy.spawn(str(mobs[rng.randi() % mobs.size()]), self,
			base + Vector3(rng.randf_range(-3.0, 3.0), 0.3, rng.randf_range(-3.0, 3.0)))
		if e:
			e.set_meta("dungeon", true)

## 산란방 — 알집 더미와 그 주변에 몰려 있는 무리
func _room_spawner(base: Vector3, rng: RandomNumberGenerator, c: Dictionary) -> void:
	var mb := MeshBuilder.new()
	for i in range(9):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 1.5)
		mb.sphere(Vector3(cos(a) * d, rng.randf_range(0.25, 0.75), sin(a) * d),
			rng.randf_range(0.28, 0.5), 7, 5, Color(0.42, 0.62, 0.34),
			Vector3(1.0, 1.2, 1.0))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	mi.material_override = MatLib.glow(Color(0.40, 0.72, 0.36), 0.55)
	add_child(mi)
	mi.global_position = base
	var l := OmniLight3D.new()
	l.light_color = Color(0.45, 0.95, 0.40)
	l.light_energy = 1.2
	l.omni_range = 7.0
	l.shadow_enabled = false
	l.position = base + Vector3(0, 1.2, 0)
	add_child(l)
	Flicker.attach(l, 0.30, 0.6)
	var mobs: Array = c["mobs"]
	for i in range(rng.randi_range(3, 4)):
		if mobs.is_empty():
			break
		var e := Enemy.spawn(str(mobs[rng.randi() % mobs.size()]), self,
			base + Vector3(rng.randf_range(-3.2, 3.2), 0.3, rng.randf_range(-3.2, 3.2)))
		if e:
			e.set_meta("dungeon", true)

## 서고 — 전승이 새겨진 룬석. 읽으면 세계관 문구가 뜬다.
func _room_library(base: Vector3, rng: RandomNumberGenerator, light_col: Color) -> void:
	var rs := Runestone.make(str(LORE_KEYS[rng.randi() % LORE_KEYS.size()]))
	add_child(rs)
	rs.global_position = base + Vector3(0, 0.0, 0)
	# 양옆 촛대
	for sx in [-2.2, 2.2]:
		var lp := base + Vector3(sx, 1.6, 0)
		var fl := Fx.fire(self, 0.3, light_col)
		fl.global_position = lp
		var l := OmniLight3D.new()
		l.light_color = light_col
		l.light_energy = 0.8
		l.omni_range = 5.5
		l.shadow_enabled = false
		add_child(l)
		l.global_position = lp
		Flicker.attach(l, 0.30, 1.1)

## 버섯방 — 발광 버섯 군락. 채집 가능한 버섯이 여럿 난다.
func _room_mushroom(base: Vector3, rng: RandomNumberGenerator) -> void:
	var mb := MeshBuilder.new()
	for i in range(16):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.4, 3.6)
		var hh := rng.randf_range(0.2, 0.7)
		var p := Vector3(cos(a) * d, 0.0, sin(a) * d)
		mb.cyl(Transform3D(Basis.IDENTITY, p), 0.06, 0.05, hh, 5,
			Color(0.86, 0.84, 0.72))
		mb.sphere(p + Vector3(0, hh, 0), rng.randf_range(0.16, 0.30), 7, 4,
			Color(0.45, 0.85, 0.72), Vector3(1.0, 0.5, 1.0))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	mi.material_override = MatLib.glow(Color(0.50, 0.90, 0.75), 0.85)
	add_child(mi)
	mi.global_position = base
	var l := OmniLight3D.new()
	l.light_color = Color(0.42, 0.90, 0.72)
	l.light_energy = 1.0
	l.omni_range = 8.0
	l.shadow_enabled = false
	l.position = base + Vector3(0, 1.0, 0)
	add_child(l)
	Flicker.attach(l, 0.16, 0.5)
	for i in range(3):
		var a2 := rng.randf() * TAU
		var n := ResourceNode.make_pickable("mushroom", int(rng.randi()))
		add_child(n)
		n.global_position = base + Vector3(cos(a2) * 2.6, 0.0, sin(a2) * 2.6)

## 침수방 — 얕은 물웅덩이와 이끼. 바닥이 젖어 반사가 생긴다.
func _room_flooded(base: Vector3, rng: RandomNumberGenerator, c: Dictionary) -> void:
	var pool := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(CELL - 0.6, CELL - 0.6)
	pool.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.10, 0.20, 0.20, 0.82)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.06
	m.metallic = 0.25
	pool.material_override = m
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pool)
	pool.global_position = base + Vector3(0, 0.06, 0)
	# 물이끼 덩어리
	var mb := MeshBuilder.new()
	for i in range(10):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.5, 3.6)
		mb.sphere(Vector3(cos(a) * d, 0.10, sin(a) * d), rng.randf_range(0.2, 0.45),
			6, 4, Color(0.24, 0.44, 0.26), Vector3(1.3, 0.35, 1.3))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	mi.material_override = MatLib.foliage(Color.WHITE, 0.6, 0.02)
	add_child(mi)
	mi.global_position = base
	if rng.randf() < 0.4:
		_place_chest(base + Vector3(rng.randf_range(-2.0, 2.0), 0.45,
			rng.randf_range(-2.0, 2.0)), rng, c)


## ── 추가 방 템플릿 ───────────────────────────────────────────
func _mesh_at(mb: MeshBuilder, base: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	mi.material_override = mat
	add_child(mi)
	mi.global_position = base
	return mi

func _stone_mat() -> Material:
	return MatLib.flat(Color.WHITE, 0.94, 0.0, 0.0, "masonry")

func _wood_mat() -> Material:
	return MatLib.flat(Color.WHITE, 0.94, 0.0, 0.0, "plank")

## 납골당 — 벽을 따라 늘어선 석관
func _room_niche(base: Vector3, rng: RandomNumberGenerator, c: Dictionary) -> void:
	var stone: Color = c["stone"]
	var mb := MeshBuilder.new()
	for side in [-1.0, 1.0]:
		for i in range(3):
			var z := -2.6 + float(i) * 2.6
			mb.box(Transform3D(Basis.IDENTITY, Vector3(3.2 * side, 0.45, z)),
				Vector3(1.6, 0.9, 2.0), stone.lightened(0.06))
			mb.box(Transform3D(Basis.IDENTITY, Vector3(3.2 * side, 0.95, z)),
				Vector3(1.7, 0.14, 2.1), stone.darkened(0.14))
	_mesh_at(mb, base, _stone_mat())
	for i in range(rng.randi_range(1, 2)):
		var e := Enemy.spawn("skeleton", self, base + Vector3(
			rng.randf_range(-1.5, 1.5), 0.3, rng.randf_range(-3.0, 3.0)))
		if e:
			e.set_meta("dungeon", true)
	if rng.randf() < 0.45:
		_place_chest(base + Vector3(0, 0.45, 0), rng, c)

## 대장간 — 모루와 화덕
func _room_forge(base: Vector3, rng: RandomNumberGenerator, c: Dictionary) -> void:
	var stone: Color = c["stone"]
	var mb := MeshBuilder.new()
	mb.box_up(Vector3(-1.6, 0, 0), Vector3(1.4, 0.8, 1.0), stone.darkened(0.10))
	mb.box_up(Vector3(-1.6, 0.8, 0), Vector3(1.7, 0.35, 0.6), Color(0.32, 0.31, 0.30))
	mb.box_up(Vector3(2.0, 0, 0.4), Vector3(2.2, 1.5, 2.2), stone.darkened(0.16))
	mb.cyl(Transform3D(Basis.IDENTITY, Vector3(2.0, 1.5, 0.4)), 0.5, 0.36, 2.6, 7,
		stone.darkened(0.22))
	_mesh_at(mb, base, _stone_mat())
	var fire := Fx.fire(self, 0.55, Color(1.0, 0.60, 0.20))
	fire.global_position = base + Vector3(2.0, 1.3, 0.4)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.58, 0.20)
	l.light_energy = 1.4
	l.omni_range = 8.0
	l.shadow_enabled = false
	add_child(l)
	l.global_position = base + Vector3(2.0, 1.6, 0.4)
	Flicker.attach(l, 0.32, 1.2)
	if rng.randf() < 0.6:
		_place_chest(base + Vector3(-2.6, 0.45, 2.0), rng, c)

## 병영 — 침상과 무기걸이
func _room_barracks(base: Vector3, rng: RandomNumberGenerator, c: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var wood := Color(0.36, 0.27, 0.18)
	for i in range(4):
		var x := -2.7 + float(i) * 1.8
		mb.box_up(Vector3(x, 0, 2.6), Vector3(1.2, 0.42, 2.2), wood)
		mb.box_up(Vector3(x, 0.42, 3.4), Vector3(1.1, 0.18, 0.6),
			Color(0.55, 0.50, 0.40))
	# 무기걸이
	mb.box_up(Vector3(0, 0, -3.2), Vector3(6.0, 0.2, 0.3), wood.darkened(0.1))
	for i in range(5):
		mb.cyl(Transform3D(Basis.IDENTITY, Vector3(-2.4 + float(i) * 1.2, 0.2, -3.2)),
			0.05, 0.05, 1.6, 5, Color(0.48, 0.46, 0.44))
	_mesh_at(mb, base, _wood_mat())
	var mobs: Array = c["mobs"]
	for i in range(rng.randi_range(2, 3)):
		if mobs.is_empty():
			break
		var e := Enemy.spawn(str(mobs[rng.randi() % mobs.size()]), self,
			base + Vector3(rng.randf_range(-3.0, 3.0), 0.3, rng.randf_range(-1.0, 2.5)))
		if e:
			e.set_meta("dungeon", true)

## 우물방 — 가운데 깊은 구멍
func _room_well(base: Vector3, rng: RandomNumberGenerator, c: Dictionary) -> void:
	var stone: Color = c["stone"]
	var mb := MeshBuilder.new()
	mb.cyl(Transform3D(Basis.IDENTITY, Vector3.ZERO), 1.8, 1.8, 0.9, 12,
		stone.lightened(0.05))
	mb.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.9, 0)), 1.55, 1.55, 0.12, 12,
		Color(0.05, 0.06, 0.07))
	for sx in [-1.6, 1.6]:
		mb.cyl(Transform3D(Basis.IDENTITY, Vector3(sx, 0.9, 0)), 0.09, 0.09, 2.0, 5,
			Color(0.34, 0.26, 0.18))
	mb.box(Transform3D(Basis.IDENTITY, Vector3(0, 2.9, 0)), Vector3(3.6, 0.16, 0.16),
		Color(0.34, 0.26, 0.18))
	_mesh_at(mb, base, _stone_mat())
	if rng.randf() < 0.5:
		_place_chest(base + Vector3(2.8, 0.45, 1.4), rng, c)

## 열주실 — 기둥이 늘어선 큰 방
func _room_pillar(base: Vector3, rng: RandomNumberGenerator, c: Dictionary) -> void:
	var stone: Color = c["stone"]
	var mb := MeshBuilder.new()
	for sx in [-2.4, 2.4]:
		for sz in [-2.4, 2.4]:
			mb.cyl(Transform3D(Basis.IDENTITY, Vector3(sx, 0, sz)), 0.55, 0.48,
				WALL_H, 9, stone.lightened(0.04))
			mb.box(Transform3D(Basis.IDENTITY, Vector3(sx, WALL_H - 0.2, sz)),
				Vector3(1.4, 0.4, 1.4), stone.darkened(0.08))
			mb.box(Transform3D(Basis.IDENTITY, Vector3(sx, 0.2, sz)),
				Vector3(1.5, 0.4, 1.5), stone.darkened(0.08))
	_mesh_at(mb, base, _stone_mat())
	var mobs: Array = c["mobs"]
	if not mobs.is_empty() and rng.randf() < 0.7:
		var e := Enemy.spawn(str(mobs[rng.randi() % mobs.size()]), self,
			base + Vector3(0, 0.3, 0))
		if e:
			e.set_meta("dungeon", true)

## 붕괴실 — 무너진 천장과 잔해
func _room_collapsed(base: Vector3, rng: RandomNumberGenerator, c: Dictionary) -> void:
	var stone: Color = c["stone"]
	var mb := MeshBuilder.new()
	for i in range(rng.randi_range(6, 10)):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 3.4)
		var sz := rng.randf_range(0.35, 0.9)
		mb.rock(Vector3(cos(a) * d, sz * 0.4, sin(a) * d), sz, int(rng.randi()),
			stone.darkened(rng.randf_range(0.0, 0.2)), 6, 4, 0.34,
			Vector3(1.0, 0.6, 1.0))
	# 무너져 기울어진 대들보
	for i in range(2):
		var a2 := rng.randf() * TAU
		mb.rod(Vector3(cos(a2) * 3.0, 0.3, sin(a2) * 3.0),
			Vector3(cos(a2) * 0.6, WALL_H * 0.75, sin(a2) * 0.6), 0.20, 5,
			Color(0.32, 0.24, 0.16))
	_mesh_at(mb, base, _stone_mat())

## 연회실 — 긴 식탁과 의자
func _room_banquet(base: Vector3, rng: RandomNumberGenerator, c: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var wood := Color(0.38, 0.28, 0.18)
	mb.box_up(Vector3(0, 0.75, 0), Vector3(5.2, 0.16, 1.6), wood.lightened(0.08))
	for i in range(4):
		var x := -2.2 + float(i) * 1.47
		for sz in [-0.6, 0.6]:
			mb.cyl(Transform3D(Basis.IDENTITY, Vector3(x, 0, sz)), 0.09, 0.09, 0.75,
				5, wood)
	for i in range(6):
		var x2 := -2.2 + float(i) * 0.9
		var sz2 := 1.5 if i % 2 == 0 else -1.5
		mb.box_up(Vector3(x2, 0, sz2), Vector3(0.5, 0.45, 0.5), wood.darkened(0.1))
	_mesh_at(mb, base, _wood_mat())
	if rng.randf() < 0.5:
		_place_chest(base + Vector3(rng.randf_range(-3.0, 3.0), 0.45, 3.0), rng, c)

## 사당 — 작은 신상과 공물
func _room_shrine(base: Vector3, rng: RandomNumberGenerator, c: Dictionary,
		light_col: Color) -> void:
	var stone: Color = c["stone"]
	var mb := MeshBuilder.new()
	mb.box_up(Vector3.ZERO, Vector3(2.2, 0.5, 2.2), stone.darkened(0.08))
	mb.box_up(Vector3(0, 0.5, 0), Vector3(1.0, 1.6, 0.8), stone.lightened(0.10))
	mb.sphere(Vector3(0, 2.3, 0), 0.42, 7, 5, stone.lightened(0.16),
		Vector3(1.0, 1.15, 1.0))
	_mesh_at(mb, base, _stone_mat())
	var l := OmniLight3D.new()
	l.light_color = light_col
	l.light_energy = 1.0
	l.omni_range = 6.5
	l.shadow_enabled = false
	add_child(l)
	l.global_position = base + Vector3(0, 2.4, 0)
	Flicker.attach(l, 0.26, 0.9)
	_place_chest(base + Vector3(0, 0.55, 1.6), rng, c)

## 거미줄방 — 알집과 늘어진 실
func _room_web(base: Vector3, rng: RandomNumberGenerator, c: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var web := Color(0.80, 0.80, 0.76)
	for i in range(14):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.5, 3.6)
		var p := Vector3(cos(a) * d, WALL_H - 0.2, sin(a) * d)
		mb.rod(p, p + Vector3(rng.randf_range(-0.5, 0.5),
			-rng.randf_range(1.0, 3.2), rng.randf_range(-0.5, 0.5)), 0.035, 4, web)
	for i in range(rng.randi_range(2, 4)):
		var a2 := rng.randf() * TAU
		var d2 := rng.randf_range(0.4, 2.6)
		mb.sphere(Vector3(cos(a2) * d2, rng.randf_range(0.3, 0.7), sin(a2) * d2),
			rng.randf_range(0.28, 0.48), 6, 4, Color(0.72, 0.72, 0.64),
			Vector3(1.0, 1.15, 1.0))
	_mesh_at(mb, base, MatLib.flat(Color.WHITE, 0.92, 0.0, 0.0, "cloth"))
	var mobs: Array = c["mobs"]
	for i in range(rng.randi_range(1, 2)):
		if mobs.is_empty():
			break
		var e := Enemy.spawn(str(mobs[rng.randi() % mobs.size()]), self,
			base + Vector3(rng.randf_range(-2.5, 2.5), 0.3, rng.randf_range(-2.5, 2.5)))
		if e:
			e.set_meta("dungeon", true)

## 유해방 — 바닥에 흩어진 뼈
func _room_bones(base: Vector3, rng: RandomNumberGenerator, c: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var bone := Color(0.78, 0.76, 0.66)
	for i in range(rng.randi_range(14, 22)):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.0, 3.6)
		var p := Vector3(cos(a) * d, 0.06, sin(a) * d)
		var a2 := rng.randf() * TAU
		mb.rod(p, p + Vector3(cos(a2), 0.02, sin(a2)) * rng.randf_range(0.3, 0.8),
			rng.randf_range(0.035, 0.07), 4, bone)
		if rng.randf() < 0.25:
			mb.sphere(p + Vector3(0, 0.12, 0), 0.16, 6, 4, bone, Vector3(1, 0.9, 1.1))
	_mesh_at(mb, base, MatLib.flat(Color.WHITE, 0.92))
	if rng.randf() < 0.4:
		_place_chest(base + Vector3(rng.randf_range(-2.0, 2.0), 0.45,
			rng.randf_range(-2.0, 2.0)), rng, c)

## 저장고 — 통과 자루
func _room_cellar(base: Vector3, rng: RandomNumberGenerator, c: Dictionary) -> void:
	var mb := MeshBuilder.new()
	var wood := Color(0.40, 0.29, 0.19)
	for i in range(rng.randi_range(4, 7)):
		var a := rng.randf() * TAU
		var d := rng.randf_range(1.2, 3.4)
		var p := Vector3(cos(a) * d, 0, sin(a) * d)
		mb.cyl(Transform3D(Basis.IDENTITY, p), 0.42, 0.36, 1.0, 9, wood)
		mb.cyl(Transform3D(Basis.IDENTITY, p + Vector3(0, 0.3, 0)), 0.45, 0.45, 0.08,
			9, Color(0.32, 0.30, 0.28))
		mb.cyl(Transform3D(Basis.IDENTITY, p + Vector3(0, 0.65, 0)), 0.44, 0.44, 0.08,
			9, Color(0.32, 0.30, 0.28))
	for i in range(rng.randi_range(2, 4)):
		var a2 := rng.randf() * TAU
		var d2 := rng.randf_range(0.6, 2.8)
		mb.sphere(Vector3(cos(a2) * d2, 0.34, sin(a2) * d2), 0.42, 6, 4,
			Color(0.62, 0.56, 0.42), Vector3(1.0, 0.85, 1.0))
	_mesh_at(mb, base, _wood_mat())
	_place_chest(base + Vector3(0, 0.45, 0), rng, c)

## 관측실 — 천장이 뚫려 별빛이 들어온다
func _room_observatory(base: Vector3, rng: RandomNumberGenerator,
		light_col: Color) -> void:
	var mb := MeshBuilder.new()
	# 뚫린 천장 테두리
	mb.cyl(Transform3D(Basis.IDENTITY, Vector3(0, WALL_H - 0.4, 0)), 2.2, 2.0, 0.6,
		12, Color(0.40, 0.39, 0.37))
	# 가운데 관측대
	mb.cyl(Transform3D(Basis.IDENTITY, Vector3.ZERO), 1.2, 1.0, 0.7, 10,
		Color(0.38, 0.37, 0.35))
	mb.rod(Vector3(0, 0.7, 0), Vector3(0.6, 2.4, 0.4), 0.10, 6,
		Color(0.50, 0.48, 0.44))
	_mesh_at(mb, base, _stone_mat())
	# 위에서 내려오는 창백한 빛
	var l := OmniLight3D.new()
	l.light_color = Color(0.72, 0.82, 1.0)
	l.light_energy = 1.6
	l.omni_range = 12.0
	l.shadow_enabled = false
	add_child(l)
	l.global_position = base + Vector3(0, WALL_H - 1.0, 0)
	var l2 := OmniLight3D.new()
	l2.light_color = light_col
	l2.light_energy = 0.5
	l2.omni_range = 5.0
	l2.shadow_enabled = false
	add_child(l2)
	l2.global_position = base + Vector3(0, 1.2, 0)

func entry_point() -> Vector3:
	return origin + Vector3(0, 1.0, 2.0)
