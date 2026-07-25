class_name ScreenshotDirector
extends Node
## 검증/홍보용 자동 스크린샷 촬영기.
## 플레이어를 각 바이옴·상황으로 옮기며 정해진 장면을 찍는다. 게임 로직은 건드리지 않는다.

var out_dir := "user://shots"
var _n := 0

var keep_alive := true
var ui_only := false

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	call_deferred("_run")

## 촬영 중에는 플레이어가 죽지 않게 유지한다(연출 목적)
func _process(_delta: float) -> void:
	if not keep_alive:
		return
	var p := _p()
	if p == null or not is_instance_valid(p):
		return
	if p.stats.is_dead:
		p.stats.revive()
		var m = _main()
		if m and m.ui:
			m.ui.close_all()
	p.stats.remove_status("freezing")
	p.stats.remove_status("burning")
	p.stats.remove_status("poison")
	p._iframes = 5.0
	if p.stats.hp < p.stats.max_hp() * 0.9:
		p.stats.set_hp(p.stats.max_hp())

func _main():
	return get_tree().current_scene

func _p() -> Player:
	return GameState.player

func _wait(frames: int = 6) -> void:
	for i in range(frames):
		await get_tree().process_frame

func _shot(tag: String) -> void:
	_n += 1
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%02d_%s.png" % [out_dir, _n, tag]
	img.save_png(path)
	print("[SHOT] ", path)

## 특정 바이옴의 보기 좋은 지점 찾기
func _find(biome: int, prefer_high: bool = false) -> Vector3:
	var gen := GameState.gen
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260725 + biome
	var best := Vector3.ZERO
	var best_score := -1e9
	for i in range(4000):
		var a := rng.randf() * TAU
		var d := rng.randf_range(40.0, Const.WORLD_RADIUS * 0.96)
		var x := cos(a) * d
		var z := sin(a) * d
		var h := gen.height(x, z)
		if h < Const.WATER_LEVEL + 1.0:
			continue
		if gen.biome_from(x, z, h) != biome:
			continue
		var score := -gen.slope_at(x, z) * 20.0
		if prefer_high:
			score += h * 0.15
		if score > best_score:
			best_score = score
			best = Vector3(x, h, z)
	if best == Vector3.ZERO:
		best = Vector3(0, gen.height(0, 0), 0)
	return best

func _goto(pos: Vector3, yaw: float = 0.7, pitch: float = -0.12,
		zoom: float = 4.6) -> void:
	var p := _p()
	if p == null:
		return
	# 오프셋을 더한 지점도 항상 지면 위로 스냅한다
	pos.y = GameState.height_at(pos.x, pos.z)
	p.global_position = pos + Vector3(0, 1.4, 0)
	p.velocity = Vector3.ZERO
	p.yaw = yaw
	p.pitch = pitch
	p.zoom = zoom
	p.spring.spring_length = zoom
	GameState.set_biome(GameState.biome_at(pos.x, pos.z))
	var m = _main()
	if m != null and m.chunks != null:
		m.chunks.preload_around(p.global_position)
	await _wait(10)
	print("[GOTO] want=", pos, " actual=", p.global_position,
		" terrain_h=", GameState.height_at(p.global_position.x, p.global_position.z),
		" cam_y=", p.cam.global_position.y, " water=", Const.WATER_LEVEL,
		" biome=", Const.BIOME_KEY.get(GameState.current_biome, "?"),
		" chunks=", m.chunks.loaded_count(),
		" onfloor=", p.is_on_floor())
	var space := p.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		p.global_position + Vector3(0, 60, 0), p.global_position - Vector3(0, 60, 0))
	q.collision_mask = Const.L_WORLD
	var hit := space.intersect_ray(q)
	var key := ChunkManager._to_chunk(p.global_position)
	var ch = m.chunks.chunks.get(key)
	var q2 := PhysicsRayQueryParameters3D.create(
		p.global_position + Vector3(0, 60, 0), p.global_position - Vector3(0, 60, 0))
	q2.collision_mask = 0xFFFFFFFF
	var hit2 := space.intersect_ray(q2)
	print("   raycast_hit=", hit.get("position", "NONE"), " anyLayer=",
		hit2.get("position", "NONE"), " chunk=", key)
	if ch:
		print("   chunk layer=", ch.collision_layer, " in_tree=", ch.is_inside_tree(),
			" gpos=", ch.global_position)
		for c in ch.get_children():
			if c is CollisionShape3D:
				print("     col shape=", c.shape, " disabled=", c.disabled,
					" faces=", (c.shape.get_faces().size() if c.shape is ConcavePolygonShape3D else -1),
					" gpos=", c.global_position)

func _weather(w: String) -> void:
	var m = _main()
	if m != null and m.sky != null:
		m.sky.weather = w
		m.sky.weather_timer = 999.0
		m.sky.rain.emitting = (w == "rain" or w == "storm")
		m.sky.snow.emitting = (w == "snow" or w == "ashfall")
		await _wait(30)

func _time(t: float) -> void:
	GameState.time_of_day = t
	await _wait(20)

func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			e.queue_free()
	await _wait(2)

func _spawn(id: String, n: int, radius: float = 7.0) -> void:
	var p := _p()
	for i in range(n):
		var a := TAU * float(i) / float(n)
		var pos := p.global_position + Vector3(cos(a), 0, sin(a)) * radius
		pos.y = GameState.height_at(pos.x, pos.z) + 0.4
		var e := Enemy.spawn(id, _main(), pos)
		if e:
			e.target = p
			e.state = Enemy.St.CHASE
	await _wait(50)

# ═══════════════════════════════════════════════ 촬영 시퀀스
func _run() -> void:
	await _wait(40)
	var m = _main()
	var p := _p()
	if p == null:
		push_error("no player")
		return
	print("[UI] ui=", m.ui, " in_tree=", m.ui.is_inside_tree() if m.ui else false,
		" layer=", m.ui.layer if m.ui else -1,
		" hud_vis=", m.ui.hud.visible, " hud_size=", m.ui.hud.size,
		" root_size=", m.ui._root.size, " hpbar=", m.ui.hud.hp_bar.global_position,
		" hpbar_size=", m.ui.hud.hp_bar.size, " vp=", get_viewport().get_visible_rect())
	# 촬영 동안은 스폰 매니저를 잠시 멈춘다
	if m.spawner:
		m.spawner.set_process(false)
	p.input_locked = true

	var give := ["flint_axe", "antler_pickaxe", "wood_shield", "finewood_bow",
		"iron_arrow", "leather_helmet", "leather_tunic", "leather_pants", "torch",
		"hammer", "iron_sword"]
	for g in give:
		p.inventory.add_item(g, 1 if g != "iron_arrow" else 40)
	p.inventory.add_item("wood", 200)
	p.inventory.add_item("stone", 200)
	p.inventory.add_item("fine_wood", 100)
	p.inventory.add_item("coal", 50)
	p.inventory.add_item("copper", 50)
	p.inventory.add_item("deer_hide", 30)
	p.inventory.add_item("cooked_deer_meat", 5)
	p.inventory.add_item("queens_jam", 5)
	p.inventory.add_item("bread", 5)
	p.stats.eat("cooked_deer_meat")
	p.stats.eat("queens_jam")
	p.stats.eat("bread")

	# 무기 장착 (검 + 방패)
	for i in range(p.inventory.size()):
		var s: Dictionary = p.inventory.get_slot(i)
		if s.is_empty():
			continue
		if str(s["id"]) in ["iron_sword", "wood_shield", "leather_helmet",
				"leather_tunic", "leather_pants", "iron_arrow"]:
			p.inventory.toggle_equip(i)

	if ui_only:
		await _ui_sequence(m, p)
		print("[SHOT] === UI 확인 완료 ===")
		get_tree().quit()
		return

	# 01 초원 아침
	await _time(0.42)
	await _weather("clear")
	await _goto(_find(Const.Biome.MEADOWS), 0.6, -0.10, 4.0)
	await _shot("meadows_morning")

	# 01b 캐릭터 클로즈업
	await _goto(_find(Const.Biome.MEADOWS), 3.14, 0.05, 2.4)
	await _shot("character")

	# 02 초원 황혼
	await _time(0.76)
	await _shot("meadows_dusk")

	# 03 초원 정오 · 원경
	await _time(0.5)
	await _goto(_find(Const.Biome.MEADOWS) + Vector3(30, 0, 20), 2.4, -0.05, 8.5)
	await _shot("meadows_vista")

	# 04 검은 숲
	await _time(0.42)
	await _weather("cloudy")
	await _goto(_find(Const.Biome.BLACKFOREST), 1.2, -0.08, 5.0)
	await _shot("blackforest")

	# 05 검은 숲 전투
	await _clear_enemies()
	await _spawn("greydwarf", 4, 6.0)
	await _shot("blackforest_combat")

	# 06 트롤
	await _clear_enemies()
	await _spawn("troll", 1, 9.0)
	await _shot("troll")

	# 07 늪지
	await _clear_enemies()
	await _time(0.36)
	await _weather("mist")
	await _goto(_find(Const.Biome.SWAMP), 0.9, -0.05, 5.2)
	await _shot("swamp")

	# 08 늪지 드라우그
	await _spawn("draugr", 3, 6.5)
	await _shot("swamp_draugr")

	# 09 설산
	await _clear_enemies()
	await _time(0.5)
	await _weather("snow")
	await _goto(_find(Const.Biome.MOUNTAIN, true), 1.8, -0.02, 6.0)
	await _shot("mountain")

	# 10 설산 늑대
	await _spawn("wolf", 3, 7.0)
	await _shot("mountain_wolves")

	# 11 평원
	await _clear_enemies()
	await _weather("clear")
	await _time(0.45)
	await _goto(_find(Const.Biome.PLAINS), 0.4, -0.06, 5.4)
	await _shot("plains")

	# 12 평원 록스 & 풀링
	await _spawn("lox", 1, 10.0)
	await _spawn("fuling", 3, 7.0)
	await _shot("plains_lox")

	# 13 안개의 땅
	await _clear_enemies()
	await _weather("mist")
	await _goto(_find(Const.Biome.MISTLANDS), 1.0, -0.05, 5.6)
	await _shot("mistlands")

	# 14 잿불의 땅
	await _clear_enemies()
	await _weather("ashfall")
	await _goto(_find(Const.Biome.ASHLANDS), 1.6, -0.04, 5.6)
	await _shot("ashlands")

	# 15 밤 · 횃불
	await _clear_enemies()
	await _weather("clear")
	await _time(0.94)
	await _goto(_find(Const.Biome.MEADOWS), 1.0, -0.08, 4.4)
	for i in range(p.inventory.size()):
		var s2: Dictionary = p.inventory.get_slot(i)
		if not s2.is_empty() and str(s2["id"]) == "torch":
			p.inventory.toggle_equip(i)
			break
	await _wait(20)
	await _shot("night_torch")

	# 16 폭풍우
	await _time(0.45)
	await _weather("storm")
	await _shot("storm")

	# 17 기지 건설 (모닥불 · 작업대 · 벽)
	await _weather("clear")
	await _time(0.34)
	var base := _find(Const.Biome.MEADOWS) + Vector3(12, 0, -8)
	await _goto(base, 0.9, -0.14, 7.0)
	_build_demo_base(base)
	await _wait(30)
	# 밖에서 기지 전체가 보이도록 물러난다
	var view := Vector3(base.x + 11.0, 0.0, base.z + 11.0)
	view.y = GameState.height_at(view.x, view.z)
	await _goto(view, PI * 0.25, -0.10, 7.5)
	await _shot("base_build")

	# 18 건축 모드 UI
	for i in range(p.inventory.size()):
		var s3: Dictionary = p.inventory.get_slot(i)
		if not s3.is_empty() and str(s3["id"]) == "hammer":
			p.inventory.toggle_equip(i)
			break
	p.input_locked = false
	m.build_system.select("wood_floor")
	await _wait(25)
	await _shot("build_mode")
	# 망치를 벗어 건축 패널을 닫는다(이후 장면을 가리지 않도록)
	for i in range(p.inventory.size()):
		var s4: Dictionary = p.inventory.get_slot(i)
		if not s4.is_empty() and str(s4["id"]) == "hammer" \
				and p.inventory.is_equipped(i):
			p.inventory.toggle_equip(i)
			break
	await _wait(6)
	p.input_locked = true

	# 19 인벤토리 UI
	m.ui.close_all()
	m.ui.open_panel(m.ui.inv_ui)
	await _wait(12)
	await _shot("ui_inventory")

	# 20 제작 UI
	m.ui.close_all()
	m.ui.open_craft(RecipeDB.ST_WORKBENCH, p)
	await _wait(12)
	await _shot("ui_crafting")

	# 21 지도
	m.ui.close_all()
	for dz in range(-40, 41):
		for dx in range(-40, 41):
			GameState.discovered[Vector2i(
				int(p.global_position.x / 32.0) + dx,
				int(p.global_position.z / 32.0) + dz)] = true
	m.ui.open_panel(m.ui.map_ui)
	await _wait(60)
	await _shot("ui_map")

	# 22 숙련도
	m.ui.close_all()
	for s in Const.Skill.values():
		p.stats.raise_skill(s, 30.0)
	m.ui._refresh_skills()
	m.ui.open_panel(m.ui.skills_ui)
	await _wait(12)
	await _shot("ui_skills")
	m.ui.close_all()

	# 23 보스: 에이크시르
	await _time(0.40)
	await _clear_enemies()
	var alt := _find(Const.Biome.MEADOWS) + Vector3(-20, 0, 25)
	await _goto(alt, 0.0, 0.04, 10.0)
	var b1 := Boss.spawn_boss("eikthyr", m, p.global_position
		+ Vector3(0, 0, -10).rotated(Vector3.UP, p.yaw))
	await _wait(70)
	await _shot("boss_eikthyr")

	# 24 보스: 고목의 왕
	if is_instance_valid(b1):
		b1.queue_free()
	await _clear_enemies()
	await _weather("cloudy")
	await _goto(_find(Const.Biome.BLACKFOREST) + Vector3(15, 0, 0), 0.0, 0.02, 12.0)
	var b2 := Boss.spawn_boss("elder", m, p.global_position
		+ Vector3(0, 0, -14).rotated(Vector3.UP, p.yaw))
	await _wait(70)
	await _shot("boss_elder")

	# 25 보스: 모데르 (설산 비룡)
	if is_instance_valid(b2):
		b2.queue_free()
	await _clear_enemies()
	await _weather("snow")
	await _goto(_find(Const.Biome.MOUNTAIN, true), 0.0, 0.10, 10.0)
	var b3 := Boss.spawn_boss("moder", m, p.global_position
		+ Vector3(0, 8, -16).rotated(Vector3.UP, p.yaw))
	await _wait(70)
	await _shot("boss_moder")
	if is_instance_valid(b3):
		b3.queue_free()

	# 26 해안 · 바다
	await _clear_enemies()
	await _weather("clear")
	await _time(0.24)
	await _goto(_coast(), 0.0, -0.02, 6.5)
	await _shot("coast_dawn")

	print("[SHOT] === 완료: ", _n, " 장 ===")
	await _wait(10)
	get_tree().quit()

## UI 배치 확인용 짧은 시퀀스
func _ui_sequence(m, p) -> void:
	await _time(0.42)
	await _goto(_find(Const.Biome.MEADOWS), 0.6, -0.10, 4.5)
	m.ui.close_all(); m.ui.open_panel(m.ui.inv_ui); await _wait(14)
	await _shot("ui_inventory")
	m.ui.close_all(); m.ui.open_craft(RecipeDB.ST_WORKBENCH, p); await _wait(14)
	await _shot("ui_crafting")
	m.ui.close_all()
	for s2 in Const.Skill.values():
		p.stats.raise_skill(s2, 30.0)
	m.ui._refresh_skills(); m.ui.open_panel(m.ui.skills_ui); await _wait(14)
	await _shot("ui_skills")
	m.ui.close_all()
	for dz in range(-30, 31):
		for dx in range(-30, 31):
			GameState.discovered[Vector2i(int(p.global_position.x / 32.0) + dx,
				int(p.global_position.z / 32.0) + dz)] = true
	m.ui.open_panel(m.ui.map_ui); await _wait(60)
	await _shot("ui_map")
	m.ui.close_all()
	m.ui.toggle_pause(); await _wait(14)
	await _shot("ui_pause")
	m.ui.close_all()
	for i in range(p.inventory.size()):
		var s3: Dictionary = p.inventory.get_slot(i)
		if not s3.is_empty() and str(s3["id"]) == "hammer":
			p.inventory.toggle_equip(i)
			break
	p.input_locked = false
	m.build_system.select("wood_wall")
	await _wait(25)
	await _shot("ui_build")

func _coast() -> Vector3:
	var gen := GameState.gen
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var best := Vector3.ZERO
	var best_score := -1e9
	for i in range(4000):
		var a := rng.randf() * TAU
		var d := rng.randf_range(200.0, 900.0)
		var x := cos(a) * d
		var z := sin(a) * d
		var h := gen.height(x, z)
		if h < Const.WATER_LEVEL + 0.6 or h > Const.WATER_LEVEL + 3.0:
			continue
		var score := -absf(h - (Const.WATER_LEVEL + 1.4)) * 10.0 - gen.slope_at(x, z) * 8.0
		if score > best_score:
			best_score = score
			best = Vector3(x, h, z)
	if best == Vector3.ZERO:
		best = Vector3(0, gen.height(0, 0), 0)
	return best

## 시연용 간이 기지
func _build_demo_base(center: Vector3) -> void:
	var m = _main()
	var bs: BuildSystem = m.build_system
	var gh := GameState.height_at(center.x, center.z)

	var place := func(id: String, off: Vector3, yaw: float) -> void:
		var d := RecipeDB.piece(id)
		if d.is_empty():
			return
		var piece := BuildPiece.make(id)
		m.add_child(piece)
		var size: Vector3 = d.get("size", Vector3.ONE)
		piece.global_position = center + off + Vector3(0, size.y * 0.5, 0)
		piece.global_position.y = maxf(piece.global_position.y, gh + size.y * 0.5 + off.y)
		piece.rotation.y = yaw
		piece.yaw = yaw
		bs.pieces.append(piece)

	# 바닥 3x3
	for ix in range(-1, 2):
		for iz in range(-1, 2):
			place.call("wood_floor", Vector3(float(ix) * 2.0, 0.0, float(iz) * 2.0), 0.0)
	# 벽
	for ix in range(-1, 2):
		place.call("wood_wall", Vector3(float(ix) * 2.0, 1.1, -3.0), 0.0)
		if ix != 0:
			place.call("wood_wall", Vector3(float(ix) * 2.0, 1.1, 3.0), 0.0)
	for iz in range(-1, 2):
		place.call("wood_wall", Vector3(-3.0, 1.1, float(iz) * 2.0), PI * 0.5)
		place.call("wood_wall", Vector3(3.0, 1.1, float(iz) * 2.0), PI * 0.5)
	place.call("wood_door", Vector3(0.0, 1.1, 3.0), 0.0)
	# 지붕
	for ix in range(-1, 2):
		place.call("wood_roof", Vector3(float(ix) * 2.0, 2.6, -1.0), 0.0)
		place.call("wood_roof", Vector3(float(ix) * 2.0, 2.6, 1.0), PI)
	# 내부 시설
	place.call("campfire", Vector3(0.0, 0.3, 0.0), 0.0)
	place.call("workbench", Vector3(-1.6, 0.3, -1.6), 0.6)
	place.call("chest", Vector3(1.6, 0.3, -1.6), -0.4)
	place.call("bed", Vector3(1.6, 0.3, 1.2), 0.0)
	place.call("torch_stand", Vector3(-3.4, 0.9, 3.4), 0.0)
	place.call("torch_stand", Vector3(3.4, 0.9, 3.4), 0.0)
	bs.call_deferred("recompute_support")
