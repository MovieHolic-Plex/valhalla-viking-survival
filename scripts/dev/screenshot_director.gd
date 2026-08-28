class_name ScreenshotDirector
extends Node
## 검증/홍보용 자동 스크린샷 촬영기.
## 플레이어를 각 바이옴·상황으로 옮기며 정해진 장면을 찍는다. 게임 로직은 건드리지 않는다.

var out_dir := "user://shots"
var _n := 0

var keep_alive := true
var ui_only := false
var new_only := false
var quick := false     # 그래픽 튜닝용 최소 세트 (초원/숲/해안)
var _failures: Array[String] = []
var _qa_width := -1
var _qa_height := -1
var _qa_locale := ""

func _ready() -> void:
	_parse_qa_args()
	DirAccess.make_dir_recursive_absolute(out_dir)
	call_deferred("_run")


func _parse_qa_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-width="):
			var width_value := arg.substr(11)
			if width_value.is_valid_int():
				_qa_width = int(width_value)
			else:
				_require(false, "invalid --qa-width value: " + width_value)
		elif arg.begins_with("--qa-height="):
			var height_value := arg.substr(12)
			if height_value.is_valid_int():
				_qa_height = int(height_value)
			else:
				_require(false, "invalid --qa-height value: " + height_value)
		elif arg.begins_with("--qa-locale="):
			_qa_locale = arg.substr(12)


func _assert_qa_invocation() -> void:
	var logical_size := Vector2i(get_viewport().get_visible_rect().size.round())
	var output_size := get_viewport().get_texture().get_size()
	var active_locale := TranslationServer.get_locale()
	print("[QA] expected output=%dx%d locale=%s; active output=%dx%d logical=%dx%d locale=%s" % [
		_qa_width, _qa_height, _qa_locale, output_size.x, output_size.y,
		logical_size.x, logical_size.y, active_locale])
	_require(_qa_width > 0, "UI QA requires a positive --qa-width argument")
	_require(_qa_height > 0, "UI QA requires a positive --qa-height argument")
	_require(not _qa_locale.is_empty(), "UI QA requires a non-empty --qa-locale argument")
	if _qa_width > 0 and _qa_height > 0:
		_require(output_size == Vector2i(_qa_width, _qa_height),
			"render output %dx%d does not match expected %dx%d" % [
				output_size.x, output_size.y, _qa_width, _qa_height])
	if not _qa_locale.is_empty():
		_require(active_locale == _qa_locale,
			"active locale %s does not match expected %s" % [active_locale, _qa_locale])

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
	var error := img.save_png(path)
	_require(error == OK, "failed to save screenshot %s: error %d" % [path, error])
	if error == OK:
		print("[SHOT] ", path)

func assert_title_layout(main: Node) -> void:
	var viewport := main.get_viewport() as Viewport
	var menu := main.find_child("title_menu", true, false) as Control
	_require(viewport != null, "title viewport was not found for layout validation")
	_require(menu != null, "title menu was not found for layout validation")
	if viewport == null or menu == null:
		return
	_require(_inside_rect(menu, viewport.get_visible_rect()), "title menu exceeds the viewport")
	for node_name in ["title_new_game", "title_join"]:
		var action := menu.find_child(node_name, true, false) as Control
		_require(action != null and action.is_visible_in_tree()
			and _inside_rect(action, viewport.get_visible_rect()),
			"title action %s is not visible inside the viewport" % node_name)
	var continue_action := menu.find_child("title_continue", true, false) as Control
	if continue_action != null:
		_require(continue_action.is_visible_in_tree()
			and _inside_rect(continue_action, viewport.get_visible_rect()),
			"title Continue action is not visible inside the viewport")


func _assert_control_contained(control: Control, label: String) -> void:
	_require(control != null and control.is_visible_in_tree(), "%s is not visible" % label)
	if control != null and control.is_visible_in_tree():
		_require(_inside_viewport(control), "%s exceeds the viewport safe area" % label)


func _inside_viewport(control: Control) -> bool:
	var viewport_rect := get_viewport().get_visible_rect().grow(-UITheme.SAFE_MARGIN_SMALL)
	return viewport_rect.encloses(control.get_global_rect())


func _inside_rect(control: Control, viewport_rect: Rect2) -> bool:
	return viewport_rect.encloses(control.get_global_rect())


func _assert_actionable_focus(label: String) -> void:
	var owner := get_viewport().gui_get_focus_owner()
	var actionable := owner != null and (bool(owner.get_meta("keyboard_actionable", false)) \
		or owner is BaseButton and not (owner as BaseButton).disabled \
		or owner is LineEdit and (owner as LineEdit).editable \
		or owner is Range or owner is ItemList or owner is Tree)
	_require(owner != null and owner.is_visible_in_tree() and actionable,
		"%s did not restore focus to an actionable control" % label)


func _assert_ui_feedback_contained(hud) -> void:
	_assert_control_contained(hud.objective_panel, "objective panel")
	if hud.objective_action != null and hud.objective_action.is_visible_in_tree():
		_assert_control_contained(hud.objective_action, "objective action")
	if hud.action_panel != null and hud.action_panel.is_visible_in_tree():
		_assert_control_contained(hud.action_panel, "action feedback")
		if hud.action_feedback != null and hud.action_feedback.is_visible_in_tree():
			_assert_control_contained(hud.action_feedback, "action feedback text")
	if hud.msg_box != null:
		for child in hud.msg_box.get_children():
			if child is Control and child.is_visible_in_tree():
				_assert_control_contained(child as Control, "toast feedback")

## 특정 바이옴의 보기 좋은 지점 찾기.
## 1차는 "사방 260m 가 육지"인 내륙 지점만 노린다(바다가 화면을 덮지 않게).
## 산악/늪처럼 해안에만 있는 바이옴은 1차에서 못 찾으므로 조건을 풀어 2차를 돈다.
func _find(biome: int, prefer_high: bool = false) -> Vector3:
	var p1 := _find_pass(biome, prefer_high, true)
	if p1 != Vector3.INF:
		return p1
	var p2 := _find_pass(biome, prefer_high, false)
	if p2 != Vector3.INF:
		return p2
	var gen := GameState.gen
	return Vector3(0, gen.height(0, 0), 0)

func _find_pass(biome: int, prefer_high: bool, strict: bool) -> Vector3:
	var gen := GameState.gen
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260725 + biome
	var best := Vector3.INF
	var best_score := -1e9
	for i in range(4000):
		var a := rng.randf() * TAU
		var d := rng.randf_range(40.0, Const.WORLD_RADIUS * 0.96)
		var x := cos(a) * d
		var z := sin(a) * d
		var h := gen.height(x, z)
		if h < Const.WATER_LEVEL + (8.0 if strict else 1.5):
			continue
		if gen.biome_from(x, z, h) != biome:
			continue
		# 주변이 얼마나 같은 바이옴 육지인지 센다
		var inland := true
		var same := 0
		for j in range(12):
			var aa := TAU * float(j) / 12.0
			var rr := 130.0 if j % 2 == 0 else 260.0
			var sx := x + cos(aa) * rr
			var sz := z + sin(aa) * rr
			var sh := gen.height(sx, sz)
			if sh < Const.WATER_LEVEL + 6.0:
				inland = false
			if gen.biome_from(sx, sz, sh) == biome:
				same += 1
		if strict and (not inland or same < 7):
			continue
		# 협곡 바닥은 하늘이 안 보여 화면이 어두운 벽뿐이다 — 주변이 나보다
		# 크게 솟아 있으면 버린다
		var boxed := false
		for j2 in range(8):
			var a3 := TAU * float(j2) / 8.0
			if gen.height(x + cos(a3) * 30.0, z + sin(a3) * 30.0) > h + 14.0:
				boxed = true
				break
		if boxed:
			continue
		var sl := gen.slope_at(x, z)
		var score := -absf(sl - 0.12) * 24.0 + float(same) * 2.0
		if not strict and inland:
			score += 6.0
		if prefer_high:
			score += h * 0.15
		if score > best_score:
			best_score = score
			best = Vector3(x, h, z)
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
	if ui_only:
		_assert_qa_invocation()
	var p := _p()
	if p == null:
		_require(false, "no player")
		_finish("촬영")
		return
	print("[UI] ui=", m.ui, " in_tree=", m.ui.is_inside_tree() if m.ui else false,
		" layer=", m.ui.layer if m.ui else -1,
		" hud_vis=", m.ui.hud.visible, " hud_size=", m.ui.hud.size,
		" root_size=", m.ui._root.size, " hpbar=", m.ui.hud.hp_bar.global_position,
		" hpbar_size=", m.ui.hud.hp_bar.size, " vp=", get_viewport().get_visible_rect())
	# 촬영 동안은 스폰 매니저를 잠시 멈춘다
	if m.spawner:
		m.spawner.set_process(false)
	m.ui.set_transition(true)

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
	# QA용 대량 재료가 과적 상태를 만들어 첫 세션 UI를 왜곡하지 않게 한다.
	p.inventory.max_weight = 2500.0

	# 무기 장착 (검 + 방패)
	for i in range(p.inventory.size()):
		var s: Dictionary = p.inventory.get_slot(i)
		if s.is_empty():
			continue
		if str(s["id"]) in ["iron_sword", "wood_shield", "leather_helmet",
				"leather_tunic", "leather_pants", "iron_arrow"]:
			p.inventory.toggle_equip(i)

	# UI 검증은 실제 플레이 상태에서 모달 자체가 입력 잠금을 소유해야 한다.
	# TRANSITION 우선순위를 남겨두면 패널 포커스 경로를 검증하지 못한다.
	if ui_only:
		m.ui.set_transition(false)
		await _ui_sequence(m, p)
		_finish("UI 확인")
		return
	if new_only:
		await _new_systems(m, p)
		_finish("신규 시스템 확인")
		return
	if quick:
		await _time(0.38)
		await _weather("clear")
		await _goto(_find(Const.Biome.MEADOWS), 0.6, -0.10, 4.0)
		await _shot("q_meadows")
		await _goto(_find(Const.Biome.MEADOWS), 3.14, 0.05, 2.4)
		await _shot("q_character")
		await _time(0.72)
		await _goto(_find(Const.Biome.MEADOWS) + Vector3(30, 0, 20), 2.4, -0.05, 8.5)
		await _shot("q_dusk_vista")
		await _time(0.42)
		await _weather("cloudy")
		await _goto(_find(Const.Biome.BLACKFOREST), 1.2, -0.08, 5.0)
		await _shot("q_blackforest")
		_finish("퀵 확인")
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
	await _time(0.72)
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
	m.ui.set_transition(false)
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
	m.ui.set_transition(true)

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

	await _new_systems(m, p)

	# 26 해안 · 바다
	await _clear_enemies()
	await _weather("clear")
	await _time(0.24)
	await _goto(_coast(), 0.0, -0.02, 6.5)
	await _shot("coast_dawn")

	_finish("완료: %d 장" % _n)

## UI 배치 확인용 짧은 시퀀스
func _ui_sequence(m, p) -> void:
	await _time(0.42)
	await _goto(_find(Const.Biome.MEADOWS), 0.6, -0.10, 4.5)
	m.ui.close_all(); m.ui.open_panel(m.ui.inv_ui); await _wait(14)
	_assert_ui_feedback_contained(m.ui.hud)
	_assert_control_contained(m.ui.inv_ui, "inventory panel")
	_assert_actionable_focus("inventory panel")
	await _shot("ui_inventory")
	m.ui.close_all(); m.ui.open_craft(RecipeDB.ST_WORKBENCH, p); await _wait(14)
	_assert_ui_feedback_contained(m.ui.hud)
	_assert_control_contained(m.ui.craft_ui, "crafting panel")
	_assert_actionable_focus("crafting panel")
	await _shot("ui_crafting")
	m.ui.close_all()
	for s2 in Const.Skill.values():
		p.stats.skills[s2] = {"lvl": 8.0, "xp": 0.0}
	m.ui._refresh_skills(); m.ui.open_panel(m.ui.skills_ui); await _wait(14)
	await _shot("ui_skills")
	m.ui.close_all()
	for dz in range(-30, 31):
		for dx in range(-30, 31):
			GameState.discovered[Vector2i(int(p.global_position.x / 32.0) + dx,
				int(p.global_position.z / 32.0) + dz)] = true
	m.ui.open_panel(m.ui.map_ui); await _wait(60)
	_assert_ui_feedback_contained(m.ui.hud)
	_assert_control_contained(m.ui.map_ui, "map panel")
	await _shot("ui_map")
	m.ui.close_all()
	m.ui.toggle_pause(); await _wait(14)
	_assert_ui_feedback_contained(m.ui.hud)
	_assert_control_contained(m.ui.pause_ui, "pause panel")
	_assert_actionable_focus("pause panel")
	await _shot("ui_pause")
	m.ui.close_all()
	for i in range(p.inventory.size()):
		var s3: Dictionary = p.inventory.get_slot(i)
		if not s3.is_empty() and str(s3["id"]) == "hammer":
			if not p.inventory.is_equipped(i):
				p.inventory.toggle_equip(i)
			break
	m.ui.set_transition(false)
	m.build_system.select("wood_wall")
	await _wait(4)
	m.ui.build_ui.open_palette()
	await _wait(25)
	_assert_ui_feedback_contained(m.ui.hud)
	_assert_control_contained(m.ui.build_ui, "build palette")
	_assert_actionable_focus("build palette")
	await _shot("ui_build")

	# 저장/불러오기 왕복 검증
	var before_wood: int = p.inventory.count("wood")
	var before_pos: Vector3 = p.global_position
	var ok_save: bool = SaveSystem.save_game(p, m.build_system)
	if not ok_save:
		_require(false, "save round-trip setup failed: " + SaveSystem.last_error)
		SaveSystem.delete_save()
		return
	p.inventory.remove_item("wood", before_wood)
	p.global_position = before_pos + Vector3(50, 0, 50)
	var ok_load: bool = SaveSystem.load_game(p, m.build_system)
	var after_wood: int = p.inventory.count("wood")
	var position_restored: bool = p.global_position.distance_to(before_pos) < 1.0
	print("[TEST] save=", ok_save, " load=", ok_load,
		" wood ", before_wood, "->", after_wood,
		" pos_delta=", p.global_position.distance_to(before_pos))
	_require(ok_load, "save round-trip load failed: " + SaveSystem.last_error)
	_require(after_wood == before_wood, "save round-trip did not restore inventory")
	_require(position_restored, "save round-trip did not restore player position")
	SaveSystem.delete_save()

## 신규 시스템 전용 촬영 (지형변형·낚시·항해·길들이기·마법·던전)
func _new_systems(m, p) -> void:
	await _clear_enemies()
	await _weather("clear")
	await _time(0.40)

	# 지형 변형 (괭이)
	var thome := _find(Const.Biome.MEADOWS) + Vector3(-18, 0, 14)
	await _goto(thome, 0.8, -0.22, 7.0)
	p.inventory.add_item("hoe", 1)
	for i in range(p.inventory.size()):
		var sh: Dictionary = p.inventory.get_slot(i)
		if not sh.is_empty() and str(sh["id"]) == "hoe":
			p.inventory.toggle_equip(i)
			break
	# 계단식 단을 만들어 보여준다
	var gen := GameState.gen
	var keys: Array = []
	for i in range(5):
		var c: Vector3 = p.global_position + Vector3(0, 0, -3.0 - float(i) * 2.6)
		c.y = GameState.height_at(c.x, c.z) + float(i) * 0.7
		keys += gen.modify(c, 2.4, "level", 0.0)
	for i in range(3):
		var c2: Vector3 = p.global_position + Vector3(5.0 + float(i) * 2.0, 0, -4.0)
		c2.y = GameState.height_at(c2.x, c2.z)
		keys += gen.modify(c2, 2.0, "dig", 1.6)
	m.chunks.rebuild(keys)
	await _wait(20)
	# 만든 계단식 단이 한눈에 보이도록 뒤로 물러나 내려다본다
	var view := thome + Vector3(9.0, 0, 9.0)
	await _goto(view, PI * 0.25, -0.40, 11.0)
	await _wait(20)
	await _shot("terrain_hoe")

	# 낚시
	await _clear_enemies()
	var coast := _coast()
	await _goto(coast, 0.0, -0.05, 5.0)
	p.inventory.add_item("fishing_rod", 1)
	p.inventory.add_item("fishing_bait", 20)
	for i in range(p.inventory.size()):
		var sf: Dictionary = p.inventory.get_slot(i)
		if not sf.is_empty() and str(sf["id"]) == "fishing_rod":
			p.inventory.toggle_equip(i)
			break
	# 바다 쪽을 향하게 회전
	var sea_dir := (Vector3(0, 0, 0) - coast).normalized()
	p.yaw = atan2(-sea_dir.x, -sea_dir.z) + PI
	await _wait(6)
	p._cast_charge = 0.9
	p._throw_bobber()
	await _wait(60)
	await _shot("fishing")
	if p._bobber != null and is_instance_valid(p._bobber):
		p._bobber.queue_free()

	# 배 · 항해
	var boat := Boat.make("longship")
	m.add_child(boat)
	var bpos := coast
	# 물 쪽으로 조금 밀어 띄운다
	for i in range(40):
		var t := bpos + sea_dir * 4.0
		if GameState.height_at(t.x, t.z) < Const.WATER_LEVEL - 2.5:
			bpos = t
			break
		bpos = t
	boat.global_position = Vector3(bpos.x, Const.WATER_LEVEL, bpos.z)
	boat.rotation.y = atan2(sea_dir.x, sea_dir.z)
	await _wait(20)
	boat._mount(p)
	boat.speed_step = 3
	p.yaw = boat.rotation.y + PI
	p.pitch = -0.08
	p.zoom = 12.0
	p.spring.spring_length = 12.0
	await _wait(90)
	await _shot("sailing")
	boat._dismount()
	await _goto(coast, 0.0, -0.05, 6.0)

	# 길들이기
	await _clear_enemies()
	await _goto(_find(Const.Biome.MEADOWS), 1.0, -0.10, 6.0)
	for i in range(3):
		var a := TAU * float(i) / 3.0
		var bp: Vector3 = p.global_position + Vector3(cos(a), 0, sin(a)) * 4.5
		bp.y = GameState.height_at(bp.x, bp.z) + 0.4
		var boar := Enemy.spawn("boar", m, bp)
		if boar:
			boar.tame_progress = 2
			boar._become_tamed(false)
			boar._refresh_tag()
	await _wait(40)
	await _shot("taming")

	# 마법 시전
	await _clear_enemies()
	p.inventory.add_item("eitr_bread", 5)
	p.inventory.add_item("staff_fire", 1)
	# 음식 슬롯이 3칸뿐이라 마법 음식을 넣으려면 자리를 비워야 한다
	p.stats.foods.clear()
	p.stats.eat("eitr_bread")
	p.stats.eat("cooked_deer_meat")
	p.stats.eat("queens_jam")
	p.stats.max_eitr = p.stats.max_eitr_value()
	p.stats.eitr = p.stats.max_eitr
	for i in range(p.inventory.size()):
		var ss: Dictionary = p.inventory.get_slot(i)
		if not ss.is_empty() and str(ss["id"]) == "staff_fire":
			p.inventory.toggle_equip(i)
			break
	await _spawn("greydwarf", 3, 9.0)
	await _wait(10)
	for i in range(3):
		p.stats.max_eitr = p.stats.max_eitr_value()
		p.stats.eitr = p.stats.max_eitr
		p._attack_cd = 0.0
		p._cast_staff("staff_fire", ItemDB.get_item("staff_fire"))
		await _wait(5)
	await _shot("magic_staff")

	# 던전 내부
	await _clear_enemies()
	var dent := DungeonEntrance.make("crypt", 4242, 99)
	m.add_child(dent)
	var dpos := _find(Const.Biome.MEADOWS) + Vector3(8, 0, -8)
	dpos.y = GameState.height_at(dpos.x, dpos.z)
	dent.global_position = dpos
	await _goto(dpos + Vector3(0, 0, 7.0), PI, -0.02, 7.0)
	await _shot("dungeon_entrance")
	dent.interact(p)
	await _wait(40)
	# 복도가 길게 보이는 방향을 찾아 그쪽을 바라본다
	var dgn = null
	for ch in m.get_children():
		if ch is Dungeon:
			dgn = ch
	if dgn != null:
		var best_dir := 0.0
		var best_len := -1
		var dirs := {0.0: Vector2i(0, 1), PI: Vector2i(0, -1),
			PI * 0.5: Vector2i(-1, 0), -PI * 0.5: Vector2i(1, 0)}
		for ang in dirs:
			var step: Vector2i = dirs[ang]
			var n := 0
			var c := Vector2i.ZERO
			while dgn.cells.has(c + step) and n < 9:
				c += step
				n += 1
			if n > best_len:
				best_len = n
				best_dir = ang
		p.yaw = best_dir
		p.global_position = dgn.origin + Vector3(0, 1.0, 0)
	await _wait(30)
	var dg = null
	for ch in m.get_children():
		if ch is Dungeon:
			dg = ch
			break
	if dg != null:
		var geo := dg.get_node_or_null("geo") as MeshInstance3D
		print("[DUNGEON] origin=", dg.origin, " cells=", dg.cells.size(),
			" generated=", dg.generated,
			" geo=", (geo.get_aabb() if geo else "none"),
			" player=", p.global_position, " onfloor=", p.is_on_floor(),
			" children=", dg.get_child_count())
	else:
		print("[DUNGEON] not found")
	p.zoom = 3.2
	p.spring.spring_length = 3.2
	p.pitch = -0.05
	await _wait(25)
	await _shot("dungeon_inside")
	# 나오기
	p.remove_meta("in_dungeon")
	await _goto(_find(Const.Biome.MEADOWS), 0.6, -0.10, 5.0)


func _require(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)

func _finish(label: String) -> void:
	var succeeded := _failures.is_empty()
	if succeeded:
		print("[SHOT] === %s 완료 ===" % label)
	else:
		for failure in _failures:
			push_error("[SHOT] FAIL: " + failure)
	get_tree().quit(0 if succeeded else 1)

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
