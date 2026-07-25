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

func entry_point() -> Vector3:
	return origin + Vector3(0, 1.0, 2.0)
