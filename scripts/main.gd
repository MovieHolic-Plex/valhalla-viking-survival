extends Node3D
## 진입점: 타이틀 → 세계 생성 → 게임 루프.

var chunks: ChunkManager
var water: Water
var sky: SkySystem
var spawner: SpawnManager
var player: Player
var build_system: BuildSystem
var ui: UIRoot

var _title: CanvasLayer
var _seed_edit: LineEdit
var _name_edit: LineEdit
var _ip_edit: LineEdit
var _loading: Label
var started := false

const ONBOARDING_IDS := ["ORIENT", "EAT", "GATHER", "HAMMER", "BUILD", "REST",
	"GREYLING", "SAVE_RELOAD"]
const ONBOARDING_GATHER_IDS := ["wood", "stone"]
const ONBOARDING_ORIENT_DISTANCE := 2.0
const ONBOARDING_ORIENT_LOOK := 0.12
const STARTER_PENDING_PREFIX := "starter-pending:"
const STARTER_DELIVERED_PREFIX := "starter/v1/"

var _onboarding_store := OnboardingStore.new()
var _onboarding_progress: Dictionary = OnboardingStore.empty_progress()
var _onboarding_ready := false
var _onboarding_warning_shown := false
var _onboarding_store_warning_shown := false
var _onboarding_gather_needed: Dictionary = {}
var _onboarding_gathered: Dictionary = {}
var _onboarding_build_counts: Dictionary = {}
var _onboarding_orient_origin := Vector3.ZERO
var _onboarding_orient_yaw := 0.0
var _onboarding_moved := false
var _onboarding_looked := false
var _onboarding_recovery_needed := false
var _process_session_nonce := ""

func _ready() -> void:
	name = "main"
	_process_session_nonce = IdentityStore.create_uuid_v4()
	RenderingServer.set_default_clear_color(Color(0.05, 0.06, 0.08))
	_make_title()
	_handle_cli()

## 개발/검증용 커맨드라인 훅:  godot -- --auto --seed=1234 --shots=/경로
func _handle_cli() -> void:
	var args := OS.get_cmdline_user_args()
	var auto := false
	var sv := 424242
	var shots := ""
	var net_host := false
	var net_join := ""
	for a in args:
		if a == "--diag":
			_diag()
			return
		if a == "--auto":
			auto = true
		elif a.begins_with("--seed="):
			sv = int(a.substr(7))
		elif a.begins_with("--shots="):
			shots = a.substr(8)
			auto = true
		elif a == "--host":
			net_host = true
			auto = true
		elif a == "--server":
			# 전용 서버: 화면 없이 월드만 돌린다 (godot --headless -- --server)
			net_host = true
			auto = true
			Net.dedicated = true
		elif a.begins_with("--join="):
			net_join = a.substr(7)
			auto = true

	# 멀티플레이 자동 검증 경로
	if net_host:
		_seed_edit.text = str(sv)
		await get_tree().process_frame
		Net.my_name = "전용서버" if Net.dedicated else "호스트"
		Net.host_game()
		_begin(false)
		if not Net.dedicated:
			add_child(NetProbe.new())
		else:
			print("[SERVER] 전용 서버 가동. seed=", sv,
				" port=", Net.DEFAULT_PORT)
		return
	if net_join != "":
		await get_tree().process_frame
		Net.my_name = "손님"
		_ip_edit.text = net_join
		_begin_join()
		add_child(NetProbe.new())
		return

	if not auto:
		return
	_seed_edit.text = str(sv)
	await get_tree().process_frame
	_begin(false)
	if shots != "":
		var dir := ScreenshotDirector.new()
		dir.out_dir = shots
		dir.assert_title_layout(self)
		dir.ui_only = args.has("--uionly")
		dir.new_only = args.has("--newonly")
		dir.quick = args.has("--quick")
		add_child(dir)

# ═══════════════════════════════════════════════ 타이틀
func _make_title() -> void:
	_title = CanvasLayer.new()
	_title.layer = 50
	add_child(_title)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UITheme.get_theme()
	_title.add_child(root)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.055, 0.06, 0.07)
	root.add_child(bg)

	# 배경 장식: 룬 원
	var deco := Control.new()
	deco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	deco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deco.draw.connect(func():
		var c := deco.size * 0.5
		for i in range(4):
			deco.draw_arc(c, 190.0 + float(i) * 46.0, 0, TAU, 96,
				Color(0.42, 0.34, 0.20, 0.16 - float(i) * 0.03), 2.0)
		for i in range(9):
			var a := TAU * float(i) / 9.0
			var p0 := c + Vector2(cos(a), sin(a)) * 190.0
			var p1 := c + Vector2(cos(a), sin(a)) * 328.0
			deco.draw_line(p0, p1, Color(0.42, 0.34, 0.20, 0.13), 2.0)
	)
	root.add_child(deco)

	var safe := MarginContainer.new()
	safe.name = "title_shell"
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		safe.add_theme_constant_override(side, int(UITheme.safe_margin(
			get_viewport().get_visible_rect().size.x)))
	root.add_child(safe)

	var scroll := ScrollContainer.new()
	scroll.name = "title_scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	safe.add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.custom_minimum_size.x = 500
	scroll.add_child(center)

	var v := VBoxContainer.new()
	v.name = "title_menu"
	v.custom_minimum_size = Vector2(460, 0)
	v.add_theme_constant_override("separation", 8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)

	var t := UITheme.title(tr("UI_TITLE"), 54)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UITheme.label(tr("UI_SUBTITLE"), 17, UITheme.TEXT_DIM)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	v.add_child(UITheme.label("", 4))

	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	v.add_child(seed_row)
	var sl := UITheme.label(tr("UI_SEED"), 17)
	sl.custom_minimum_size = Vector2(60, 0)
	seed_row.add_child(sl)
	_seed_edit = LineEdit.new()
	_seed_edit.text = str(randi() % 900000 + 100000)
	_seed_edit.custom_minimum_size = Vector2(240, 40)
	seed_row.add_child(_seed_edit)
	var rb := UITheme.button(tr("UI_RANDOM_SEED"), 15)
	rb.pressed.connect(func(): _seed_edit.text = str(randi() % 900000 + 100000))
	seed_row.add_child(rb)

	var b_new := UITheme.button(tr("UI_NEW_GAME"), 22)
	b_new.custom_minimum_size = Vector2(0, 48)
	b_new.name = "title_new_game"
	b_new.pressed.connect(func(): _begin(false))
	v.add_child(b_new)

	if SaveSystem.has_save():
		var b_cont := UITheme.button(tr("UI_CONTINUE"), 22)
		b_cont.custom_minimum_size = Vector2(0, 48)
		b_cont.name = "title_continue"
		b_cont.pressed.connect(func(): _begin(true))
		v.add_child(b_cont)

	# ── 멀티플레이 ──
	v.add_child(UITheme.label("", 4))
	var mp := UITheme.label(tr("UI_MULTIPLAYER"), 16, UITheme.TEXT_DIM)
	mp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(mp)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	v.add_child(name_row)
	var nl := UITheme.label(tr("UI_NICKNAME"), 15)
	nl.custom_minimum_size = Vector2(60, 0)
	name_row.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.text = Net.my_name
	_name_edit.custom_minimum_size = Vector2(150, 36)
	name_row.add_child(_name_edit)
	var b_host := UITheme.button(tr("UI_HOST"), 15)
	b_host.pressed.connect(func(): _begin_host())
	name_row.add_child(b_host)

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	v.add_child(join_row)
	var il := UITheme.label(tr("UI_IP"), 15)
	il.custom_minimum_size = Vector2(60, 0)
	join_row.add_child(il)
	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.custom_minimum_size = Vector2(150, 36)
	join_row.add_child(_ip_edit)
	var b_join := UITheme.button(tr("UI_JOIN"), 15)
	b_join.name = "title_join"
	b_join.pressed.connect(func(): _begin_join())
	join_row.add_child(b_join)

	var b_exit := UITheme.button(tr("UI_EXIT"), 18)
	b_exit.custom_minimum_size = Vector2(0, 40)
	b_exit.pressed.connect(func(): get_tree().quit())
	v.add_child(b_exit)

	var ctrl := UITheme.wrap_label(tr("UI_CONTROLS"), 13, UITheme.TEXT_DIM)
	ctrl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctrl.custom_minimum_size = Vector2(460, 0)
	v.add_child(ctrl)

	_loading = UITheme.title(tr("UI_LOADING"), 30)
	_loading.set_anchors_preset(Control.PRESET_CENTER)
	_loading.position = Vector2(-250, 210)
	_loading.custom_minimum_size = Vector2(500, 0)
	_loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading.visible = false
	root.add_child(_loading)

	# UIRoot가 단일 상호작용 컨트롤러를 만들기 전까지만 타이틀이 마우스를 표시한다.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

## 월드 생성기 통계 출력 (검증용)
func _diag() -> void:
	var sv := 778899
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			sv = int(a.substr(7))
	GameState.new_world(sv)
	var gen := GameState.gen
	var counts := {}
	var above := 0
	var total := 0
	var hmin := 1e9
	var hmax := -1e9
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in range(20000):
		var a2 := rng.randf() * TAU
		var d := sqrt(rng.randf()) * Const.WORLD_RADIUS
		var x := cos(a2) * d
		var z := sin(a2) * d
		var h := gen.height(x, z)
		var b := gen.biome_from(x, z, h)
		counts[b] = int(counts.get(b, 0)) + 1
		total += 1
		if h > Const.WATER_LEVEL:
			above += 1
		hmin = minf(hmin, h)
		hmax = maxf(hmax, h)
	print("=== WORLD DIAG seed=", sv, " ===")
	print("height range: ", hmin, " .. ", hmax, "  water=", Const.WATER_LEVEL)
	print("land fraction: ", float(above) / float(total))
	for b in counts:
		print("  ", Const.BIOME_KEY.get(b, "?"), ": ",
			"%.1f%%" % (float(counts[b]) / float(total) * 100.0))
	var sp := gen.find_spawn()
	print("spawn: ", sp, " biome=", Const.BIOME_KEY.get(gen.biome_at(sp.x, sp.z), "?"))
	# 중심부 단면
	var line := ""
	for i in range(0, 40):
		var h2 := gen.height(float(i) * 60.0, 0.0)
		line += "%.0f " % h2
	print("profile x=0..2400: ", line)
	get_tree().quit()

func _begin(from_save: bool) -> void:
	if started:
		return
	started = true
	_loading.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	var sv := int(_seed_edit.text.hash()) if not _seed_edit.text.is_valid_int() \
		else int(_seed_edit.text)
	_start_world(sv, from_save)

## 호스트로 시작: 평소처럼 월드를 만든 뒤 서버를 연다
func _begin_host() -> void:
	if started:
		return
	Net.my_name = _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" \
		else "바이킹"
	if not Net.host_game(Net.DEFAULT_PORT, Net.my_name):
		return
	_begin(false)

## 클라이언트로 접속: 서버가 시드를 보내주면 그때 월드를 만든다
func _begin_join() -> void:
	if started:
		return
	Net.my_name = _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" \
		else "바이킹"
	var ip := _ip_edit.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	if not Net.join_game(ip, Net.DEFAULT_PORT, Net.my_name):
		return
	_loading.text = tr("MSG_NET_CONNECTING") % ip
	_loading.visible = true
	if not Net.world_received.is_connected(_on_world_received):
		Net.world_received.connect(_on_world_received)
	if not Net.connection_failed.is_connected(_on_join_failed):
		Net.connection_failed.connect(_on_join_failed)

func _on_world_received(sv: int, time: float, day: int, mods: Array) -> void:
	if started:
		return
	started = true
	_loading.text = tr("UI_LOADING")
	await get_tree().process_frame
	_start_world(sv, false)
	GameState.time_of_day = time
	GameState.day = day
	if GameState.gen != null:
		GameState.gen.mods_from_array(mods)
		if chunks != null and not mods.is_empty():
			chunks.rebuild(GameState.gen.mod_chunks.keys())
	Net.announce_ready()

func _on_join_failed() -> void:
	_loading.visible = false

# ═══════════════════════════════════════════════ 세계 생성
func _start_world(sv: int, from_save: bool) -> void:
	GameState.new_world(sv)
	GameState.world_root = self

	sky = SkySystem.new()
	add_child(sky)

	chunks = ChunkManager.new()
	chunks.name = "chunks"
	chunks.setup(GameState.gen)
	add_child(chunks)

	water = Water.new()
	add_child(water)

	add_child(PostFX.new())
	add_child(Ambience.new())

	player = Player.new()
	player.name = "player"
	add_child(player)
	var spawn := GameState.gen.find_spawn()
	player.global_position = spawn + Vector3(0, 1.5, 0)
	player.set_meta("spawn_point", spawn)
	GameState.player = player

	build_system = BuildSystem.new()
	build_system.name = "build"
	build_system.setup(player)
	add_child(build_system)
	player.set_build_system(build_system)

	ui = UIRoot.new()
	# The controller exists before binding, so it is the only gameplay mouse/input writer.
	add_child(ui)
	ui.bind(player, build_system)
	ui.set_transition(true)

	spawner = SpawnManager.new()
	spawner.name = "spawner"
	add_child(spawner)

	_place_altars()
	_place_dungeons()

	# 첫 지형을 미리 만들어 낙하 방지
	chunks.preload_around(player.global_position)
	player.global_position.y = GameState.height_at(
		player.global_position.x, player.global_position.z) + 1.2
	var initial_load_succeeded := false
	if from_save:
		initial_load_succeeded = SaveSystem.load_game(player, build_system)
		chunks.preload_around(player.global_position)
	_setup_onboarding(initial_load_succeeded)

	_title.queue_free()
	ui.set_transition(false)
	GameState.msg(tr("MSG_WELCOME"))
	if Net.is_host:
		Net.announce_ready()

	# 은은한 바람 소리
	var wind := AudioStreamPlayer.new()
	wind.stream = Sfx.stream_for("wind")
	Sfx.apply_ambient(wind, -26.0)
	wind.autoplay = false
	add_child(wind)
	wind.play()

## 던전 입구 배치 — 검은 숲 매장지, 늪 수몰묘지, 설산 얼음동굴
func _place_dungeons() -> void:
	var plan := [["crypt", Const.Biome.BLACKFOREST, 10],
		["sunken", Const.Biome.SWAMP, 8], ["cave", Const.Biome.MOUNTAIN, 5]]
	var idx := 0
	for entry in plan:
		var k: String = str(entry[0])
		var biome: int = int(entry[1])
		var n: int = int(entry[2])
		for pos in GameState.gen.dungeon_sites(biome, n):
			var e := DungeonEntrance.make(k, GameState.world_seed + idx * 7919, idx)
			add_child(e)
			e.global_position = pos
			idx += 1

func _place_altars() -> void:
	for id in Boss.DB:
		var c: Dictionary = Boss.DB[id]
		var biome: int = int(c.get("biome", Const.Biome.MEADOWS))
		var pos := GameState.gen.altar_position(biome)
		var a := BossAltar.make(str(id))
		add_child(a)
		a.global_position = pos

func _process(_delta: float) -> void:
	if not started or player == null or not is_instance_valid(player):
		return
	if _onboarding_ready and int(_onboarding_progress["cursor"]) == 0:
		_onboarding_moved = _onboarding_moved or player.global_position.distance_to(
			_onboarding_orient_origin) >= ONBOARDING_ORIENT_DISTANCE
		_onboarding_looked = _onboarding_looked or absf(wrapf(player.yaw - _onboarding_orient_yaw,
			-PI, PI)) >= ONBOARDING_ORIENT_LOOK
		if _onboarding_moved and _onboarding_looked:
			var candidate := _onboarding_progress.duplicate(true)
			_candidate_advance(candidate)
			if candidate != _onboarding_progress:
				_commit_onboarding_candidate(candidate)
			_refresh_onboarding_ui()
	# 월드 밖으로 떨어지면 되돌린다 (던전 안은 예외)
	if player.global_position.y < -300.0 and not player.has_meta("in_dungeon"):
		var sp: Vector3 = player.get_meta("spawn_point", Vector3.ZERO)
		player.global_position = sp + Vector3(0, 2, 0)
		player.velocity = Vector3.ZERO

func _onboarding_can_advance(id: String) -> bool:
	var cursor := int(_onboarding_progress.get("cursor", 0))
	return cursor < ONBOARDING_IDS.size() and ONBOARDING_IDS[cursor] == id

func _onboarding_event_relevant(event_id: String) -> bool:
	match event_id:
		"FOOD_EATEN":
			return _onboarding_can_advance("EAT")
		"RESOURCE_ACQUIRED":
			return _onboarding_can_advance("GATHER")
		"HAMMER_CRAFTED":
			return _onboarding_can_advance("GATHER") or _onboarding_can_advance("HAMMER")
		"HAMMER_EQUIPPED":
			return _onboarding_can_advance("HAMMER")
		"LOCAL_BUILD_COMMITTED":
			return _onboarding_can_advance("GATHER") or _onboarding_can_advance("BUILD")
		"RESTED_APPLIED":
			return _onboarding_can_advance("REST")
		"GREYLING_DEFEATED":
			return _onboarding_can_advance("GREYLING")
	return false

func _setup_onboarding(initial_load_succeeded: bool = false) -> void:
	if not IdentityStore.is_uuid(GameState.world_id) \
			or not IdentityStore.is_uuid(GameState.local_player_id):
		_onboarding_recovery_needed = true
		_recover_onboarding(_onboarding_recovery_message())
	else:
		var loaded := _onboarding_store.load(GameState.world_id, GameState.local_player_id)
		if bool(loaded.get("ok", false)):
			_onboarding_progress = loaded.get("progress", OnboardingStore.empty_progress())
		else:
			_onboarding_recovery_needed = true
			_recover_onboarding(_onboarding_recovery_message())
	_normalize_onboarding_progress()
	player.semantic_event.connect(_on_player_semantic_event)
	_reconcile_starter_delivery()
	SaveSystem.saved.connect(_on_game_saved)
	SaveSystem.loaded.connect(_on_game_loaded)
	get_tree().node_added.connect(_on_scene_node_added)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		_connect_enemy_adapter(enemy)
	_onboarding_orient_origin = player.global_position
	_onboarding_orient_yaw = player.yaw
	if _onboarding_recovery_needed:
		_recover_onboarding_from_durable_predicates()
	_rebuild_durable_onboarding_state()
	_onboarding_ready = true
	var setup_candidate := _onboarding_progress.duplicate(true)
	if int(setup_candidate.get("cursor", 0)) == 2 and not _has_gather_snapshot(setup_candidate):
		_candidate_capture_gather_shortfall(setup_candidate)
	_candidate_advance(setup_candidate)
	if setup_candidate != _onboarding_progress:
		_commit_onboarding_candidate(setup_candidate)
	if initial_load_succeeded:
		_consume_pending_reload_from_prior_session()
	_refresh_onboarding_ui()

func _recover_onboarding(message: String) -> void:
	_onboarding_progress = OnboardingStore.empty_progress()
	if not _onboarding_warning_shown:
		_onboarding_warning_shown = true
		GameState.msg(message)

func _onboarding_recovery_message() -> String:
	return "온보딩 진행 정보가 손상되어 확인 가능한 상태부터 다시 시작합니다." \
		if TranslationServer.get_locale().begins_with("ko") \
		else "Onboarding progress was corrupt; restarting from durable game state."

func _onboarding_store_failure() -> void:
	if _onboarding_store_warning_shown:
		return
	_onboarding_store_warning_shown = true
	var detail := _onboarding_store.last_error
	var message := ("온보딩 진행을 저장하지 못했습니다. 진행 상태를 변경하지 않았습니다." \
		if TranslationServer.get_locale().begins_with("ko") \
		else "Onboarding progress could not be saved; progress was not changed.")
	if not detail.is_empty():
		message += " (" + detail + ")"
	GameState.msg(message)
	if ui != null:
		ui.set_action_feedback(message, false)

func _normalize_onboarding_progress() -> void:
	var cursor := clampi(int(_onboarding_progress.get("cursor", 0)), 0, ONBOARDING_IDS.size())
	var completed: Array = _onboarding_progress.get("completed_ids", [])
	while cursor > completed.size() or cursor > 0 and \
			not completed.has(ONBOARDING_IDS[cursor - 1]):
		cursor -= 1
	_onboarding_progress["objective_version"] = OnboardingStore.OBJECTIVE_VERSION
	_onboarding_progress["cursor"] = cursor
	_onboarding_progress["completed_ids"] = completed
	_onboarding_progress["skipped"] = bool(_onboarding_progress.get("skipped", false))
	_onboarding_progress["evidence_ids"] = _onboarding_progress.get("evidence_ids", [])

func _recover_onboarding_from_durable_predicates() -> void:
	var candidate := OnboardingStore.empty_progress()
	var completed: Array = []
	if not player.stats.foods.is_empty():
		completed = ["ORIENT", "EAT"]
		candidate["cursor"] = 2
	var has_hammer := player.inventory.count(RecipeDB.RT1_HAMMER_ID) > 0 \
		or player.inventory.equipped_id(Inventory.SLOT_RIGHT) == RecipeDB.RT1_HAMMER_ID
	if has_hammer:
		completed = ["ORIENT", "EAT", "GATHER", "HAMMER"]
		candidate["cursor"] = 4
	candidate["completed_ids"] = completed
	if _commit_onboarding_candidate(candidate):
		_onboarding_recovery_needed = false

func _rebuild_durable_onboarding_state() -> void:
	_onboarding_gather_needed.clear()
	_onboarding_gathered.clear()
	_onboarding_build_counts.clear()
	for value in _onboarding_progress.get("evidence_ids", []):
		var fields := str(value).split(":", false, 3)
		if fields.size() >= 3 and fields[0] == "gather-required" \
				and fields[1] in ONBOARDING_GATHER_IDS:
			_onboarding_gather_needed[fields[1]] = maxi(0, int(fields[2]))
		elif fields.size() >= 3 and fields[0] == "gather-amount" \
				and fields[1] in ONBOARDING_GATHER_IDS:
			_onboarding_gathered[fields[1]] = int(_onboarding_gathered.get(fields[1], 0)) \
				+ maxi(0, int(fields[2]))
		elif fields.size() >= 2 and fields[0] == "build-piece" \
				and fields[1] in RecipeDB.RT1_SHELTER_PIECES:
			_onboarding_build_counts[fields[1]] = int(
				_onboarding_build_counts.get(fields[1], 0)) + 1

func _has_gather_snapshot(progress: Dictionary) -> bool:
	for value in progress.get("evidence_ids", []):
		if str(value).begins_with("gather-snapshot:"):
			return true
	return false

func _starter_pending_evidence(progress: Dictionary) -> String:
	for value in progress.get("evidence_ids", []):
		if str(value).begins_with(STARTER_PENDING_PREFIX):
			return str(value)
	return ""

func _starter_baseline_from_pending(evidence: String) -> Dictionary:
	var fields := evidence.split(":", false)
	if fields.size() != 6:
		return {}
	var baseline := {}
	for i in Player.STARTER_CONTENTS.size():
		var id: String = Player.STARTER_CONTENTS.keys()[i]
		baseline[id] = maxi(0, int(fields[i + 2]))
	return baseline

func _reconcile_starter_delivery() -> void:
	var pending := _starter_pending_evidence(_onboarding_progress)
	var delivered := _evidence_has_prefix(STARTER_DELIVERED_PREFIX) \
		or pending.is_empty() and from_loaded_player_starter()
	var provenance := {
		"source": "starter/v1",
		"contents": Player.STARTER_CONTENTS.duplicate(true),
		"world_id": GameState.world_id,
		"local_player_id": GameState.local_player_id,
	}
	if delivered:
		player.configure_starter_delivery(true, provenance)
		return
	var baseline := _starter_baseline_from_pending(pending)
	if baseline.is_empty():
		baseline = {}
		for id in Player.STARTER_CONTENTS:
			baseline[id] = player.inventory.count(id)
		var values := []
		for id in Player.STARTER_CONTENTS:
			values.append(str(int(baseline[id])))
		pending = STARTER_PENDING_PREFIX + GameState.world_id + ":" + ":".join(values)
		var pending_candidate := _onboarding_progress.duplicate(true)
		_candidate_add_evidence(pending_candidate, pending)
		if not _commit_onboarding_candidate(pending_candidate):
			return
	var delta := {}
	for id in Player.STARTER_CONTENTS:
		var target := int(baseline[id]) + int(Player.STARTER_CONTENTS[id])
		delta[id] = maxi(0, target - player.inventory.count(id))
	if not player.apply_starter_delta(delta, provenance):
		return
	var delivered_candidate := _onboarding_progress.duplicate(true)
	var evidence: Array = delivered_candidate["evidence_ids"]
	evidence.erase(pending)
	_candidate_add_evidence(delivered_candidate, STARTER_DELIVERED_PREFIX + GameState.world_id \
		+ "/" + GameState.local_player_id)
	if _commit_onboarding_candidate(delivered_candidate):
		if int(delivered_candidate["cursor"]) == 2:
			var gather_candidate := delivered_candidate.duplicate(true)
			_candidate_capture_gather_shortfall(gather_candidate)
			_commit_onboarding_candidate(gather_candidate)
	else:
		player.configure_starter_delivery(false)

func _candidate_record_spend(candidate: Dictionary, material: String, amount: int,
		evidence_key: String) -> void:
	if material in ONBOARDING_GATHER_IDS and amount > 0:
		_candidate_add_evidence(candidate, "rt1-spend:%s:%d:%s" % [material, amount,
			evidence_key])

func _candidate_record_cost(candidate: Dictionary, cost: Dictionary,
		evidence_key: String) -> void:
	for material in cost:
		_candidate_record_spend(candidate, str(material), int(cost[material]), evidence_key)

func _candidate_capture_gather_shortfall(candidate: Dictionary) -> void:
	if _has_gather_snapshot(candidate):
		return
	var available := {}
	for material in ONBOARDING_GATHER_IDS:
		available[material] = player.inventory.count(material)
	var shortfall := RecipeDB.rt1_shortfall(available)
	_candidate_add_evidence(candidate, "gather-snapshot:1:1")
	for material in ONBOARDING_GATHER_IDS:
		if shortfall.has(material):
			_candidate_add_evidence(candidate, "gather-required:%s:%d" % [
				material, int(shortfall[material])])

func _on_player_semantic_event(event_id: String, data: Dictionary) -> void:
	if not _onboarding_ready or int(_onboarding_progress["cursor"]) >= ONBOARDING_IDS.size() \
			or not _onboarding_event_relevant(event_id):
		return
	var candidate := _onboarding_progress.duplicate(true)
	var sequence := int(data.get("sequence", 0))
	var raw_evidence := str(data.get("evidence_id", "%s/%d" % [event_id, sequence]))
	if raw_evidence.is_empty() or sequence <= 0:
		return
	var evidence_key := raw_evidence.sha256_text()
	match event_id:
		"FOOD_EATEN":
			var food_id := str(data.get("item_id", ""))
			if food_id.is_empty() or not _candidate_complete(candidate, "EAT"):
				return
			_candidate_add_evidence(candidate, "food-eaten:%s:%s" % [food_id, evidence_key])
			_candidate_capture_gather_shortfall(candidate)
		"RESOURCE_ACQUIRED":
			var item_id := str(data.get("item_id", ""))
			var amount := int(data.get("amount", 0))
			if not bool(data.get("eligible", false)) or item_id not in ONBOARDING_GATHER_IDS \
					or amount <= 0:
				return
			_candidate_add_evidence(candidate, "gather-amount:%s:%d:%s" % [
				item_id, amount, evidence_key])
		"HAMMER_CRAFTED":
			if str(data.get("item_id", "")) != RecipeDB.RT1_HAMMER_ID \
					or int(data.get("amount", 0)) <= 0:
				return
			_candidate_record_cost(candidate,
				RecipeDB.recipe_of(RecipeDB.RT1_HAMMER_ID).get("mats", {}), evidence_key)
			_candidate_advance(candidate)
			_candidate_add_evidence(candidate, "hammer-crafted:%s" % evidence_key)
		"HAMMER_EQUIPPED":
			if str(data.get("item_id", "")) != RecipeDB.RT1_HAMMER_ID \
					or player.inventory.equipped_id(Inventory.SLOT_RIGHT) != RecipeDB.RT1_HAMMER_ID \
					or not _candidate_complete(candidate, "HAMMER"):
				return
			_candidate_add_evidence(candidate, "hammer-equipped:%s" % evidence_key)
		"LOCAL_BUILD_COMMITTED":
			var piece_id := str(data.get("piece_id", ""))
			var piece_position = data.get("piece_position")
			if not bool(data.get("local", false)) or piece_id not in RecipeDB.RT1_SHELTER_PIECES \
					or str(data.get("owner_id", "")) != GameState.local_player_id \
					or not (piece_position is Vector3):
				return
			var pos: Vector3 = piece_position
			if not is_finite(pos.x) or not is_finite(pos.y) or not is_finite(pos.z):
				return
			_candidate_record_cost(candidate, RecipeDB.piece_cost(piece_id), evidence_key)
			if _onboarding_can_advance("BUILD"):
				_candidate_add_evidence(candidate, "build-piece:%s:%s:%s:%s" % [piece_id,
					snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)])
		"RESTED_APPLIED":
			if int(data.get("seconds", 0)) < Player.RT1_REST_SECONDS \
					or int(data.get("comfort", 0)) <= 0 \
					or int(data.get("campfire_id", 0)) <= 0 \
					or not _candidate_complete(candidate, "REST"):
				return
			_candidate_add_evidence(candidate, "rested-applied:%s" % evidence_key)
		"GREYLING_DEFEATED":
			if str(data.get("enemy_id", "")) != "greyling" \
					or not bool(data.get("local", false)) \
					or int(data.get("killer_instance_id", 0)) != player.get_instance_id() \
					or not _candidate_complete(candidate, "GREYLING"):
				return
			_candidate_add_evidence(candidate, "greyling-defeated:%s" % evidence_key)
		_:
			return
	_candidate_advance(candidate)
	if candidate != _onboarding_progress:
		_commit_onboarding_candidate(candidate)
	_refresh_onboarding_ui()

func _candidate_add_evidence(candidate: Dictionary, evidence_id: String) -> bool:
	if evidence_id.is_empty() or evidence_id.length() > 256:
		return false
	var evidence: Array = candidate["evidence_ids"]
	if evidence.has(evidence_id):
		return false
	evidence.append(evidence_id)
	return true

func _candidate_complete(candidate: Dictionary, id: String) -> bool:
	var cursor := int(candidate["cursor"])
	if cursor >= ONBOARDING_IDS.size() or ONBOARDING_IDS[cursor] != id:
		return false
	var completed: Array = candidate["completed_ids"]
	if not completed.has(id):
		completed.append(id)
	candidate["cursor"] = cursor + 1
	return true

func _candidate_advance(candidate: Dictionary) -> void:
	if bool(candidate.get("skipped", false)):
		return
	var advanced := true
	while advanced:
		advanced = false
		var cursor := int(candidate["cursor"])
		if cursor >= ONBOARDING_IDS.size():
			break
		match ONBOARDING_IDS[cursor]:
			"ORIENT":
				advanced = _onboarding_moved and _onboarding_looked \
					and _candidate_complete(candidate, "ORIENT")
			"GATHER":
				if not _has_gather_snapshot(candidate):
					break
				var needed := {}
				var gathered := {}
				var spent := {}
				for value in candidate.get("evidence_ids", []):
					var fields := str(value).split(":", false, 3)
					if fields.size() >= 3 and fields[0] == "gather-required":
						needed[fields[1]] = int(fields[2])
					elif fields.size() >= 3 and fields[0] == "gather-amount":
						gathered[fields[1]] = int(gathered.get(fields[1], 0)) + int(fields[2])
					elif fields.size() >= 3 and fields[0] == "rt1-spend":
						spent[fields[1]] = int(spent.get(fields[1], 0)) + int(fields[2])
				var ready := true
				for material in needed:
					var required := int(needed[material])
					if required <= 0 or int(gathered.get(material, 0)) < required \
							or player.inventory.count(material) + int(spent.get(material, 0)) < required:
						ready = false
				advanced = ready and _candidate_complete(candidate, "GATHER")
			"HAMMER":
				advanced = _evidence_has_prefix_in(candidate, "hammer-crafted:") \
					and player.inventory.equipped_id(Inventory.SLOT_RIGHT) \
					== RecipeDB.RT1_HAMMER_ID and _candidate_complete(candidate, "HAMMER")
			"BUILD":
				var counts := {}
				for value in candidate.get("evidence_ids", []):
					var fields := str(value).split(":", false, 2)
					if fields.size() >= 2 and fields[0] == "build-piece":
						counts[fields[1]] = int(counts.get(fields[1], 0)) + 1
				var ready := true
				for piece_id in RecipeDB.RT1_SHELTER_PIECES:
					if int(counts.get(piece_id, 0)) < int(RecipeDB.RT1_SHELTER_PIECES[piece_id]):
						ready = false
				advanced = ready and _candidate_complete(candidate, "BUILD")

func _commit_onboarding_candidate(candidate: Dictionary) -> bool:
	if not IdentityStore.is_uuid(GameState.world_id) \
			or not IdentityStore.is_uuid(GameState.local_player_id) \
			or not _onboarding_store.save(GameState.world_id, GameState.local_player_id, candidate):
		_onboarding_store_failure()
		return false
	var old_cursor := int(_onboarding_progress.get("cursor", 0))
	_onboarding_progress = candidate
	_onboarding_store_warning_shown = false
	_rebuild_durable_onboarding_state()
	var new_cursor := int(_onboarding_progress.get("cursor", 0))
	if ui != null and new_cursor > old_cursor:
		for completed_index in range(old_cursor, new_cursor):
			var completed_id: String = ONBOARDING_IDS[completed_index]
			ui.set_action_feedback(tr("RT1_OBJECTIVE_" + (
				"SAVE" if completed_id == "SAVE_RELOAD" else completed_id)), true)
	return true

func _refresh_onboarding_ui() -> void:
	if not _onboarding_ready or ui == null or ui.hud == null:
		return
	var cursor := int(_onboarding_progress["cursor"])
	if bool(_onboarding_progress.get("skipped", false)) or cursor >= ONBOARDING_IDS.size():
		ui.set_objective("", "")
		ui.hud.set_action_hint("")
		return
	var id: String = ONBOARDING_IDS[cursor]
	var loc_id := "SAVE" if id == "SAVE_RELOAD" else id
	ui.set_objective("", tr("RT1_OBJECTIVE_" + loc_id), _onboarding_progress_text(id))
	ui.hud.set_action_hint(tr("RT1_ACTION_" + loc_id))

func _onboarding_progress_text(id: String) -> String:
	if id == "GATHER":
		var parts: Array[String] = []
		for material in ONBOARDING_GATHER_IDS:
			var needed := int(_onboarding_gather_needed.get(material, 0))
			if needed > 0:
				parts.append("%s %d/%d" % [ItemDB.name_of(material),
					mini(int(_onboarding_gathered.get(material, 0)), needed), needed])
		return ", ".join(parts)
	if id == "BUILD":
		var parts: Array[String] = []
		for piece_id in RecipeDB.RT1_SHELTER_PIECES:
			parts.append("%s %d/%d" % [piece_id,
				mini(int(_onboarding_build_counts.get(piece_id, 0)),
				int(RecipeDB.RT1_SHELTER_PIECES[piece_id])),
				int(RecipeDB.RT1_SHELTER_PIECES[piece_id])])
		return ", ".join(parts)
	return ""

func _evidence_has_prefix_in(progress: Dictionary, prefix: String) -> bool:
	for value in progress.get("evidence_ids", []):
		if str(value).begins_with(prefix):
			return true
	return false

func _evidence_has_prefix(prefix: String) -> bool:
	return _evidence_has_prefix_in(_onboarding_progress, prefix)

func _on_game_saved() -> void:
	if not _onboarding_ready or not _onboarding_can_advance("SAVE_RELOAD"):
		return
	var candidate := _onboarding_progress.duplicate(true)
	var evidence: Array = candidate["evidence_ids"]
	for value in evidence.duplicate():
		if str(value).begins_with("save-pending:%s:" % GameState.world_id):
			evidence.erase(value)
	_candidate_add_evidence(candidate, "save-pending:%s:%s" % [GameState.world_id,
		_process_session_nonce])
	_commit_onboarding_candidate(candidate)
	_refresh_onboarding_ui()

func _on_game_loaded() -> void:
	if not _onboarding_ready:
		return
	_onboarding_reload_after_world_load()
	_consume_pending_reload(false)
	_refresh_onboarding_ui()

func _consume_pending_reload_from_prior_session() -> void:
	_consume_pending_reload(true)

func _consume_pending_reload(require_prior_session: bool) -> void:
	if not _onboarding_ready or not _onboarding_can_advance("SAVE_RELOAD"):
		return
	var marker := ""
	for value in _onboarding_progress.get("evidence_ids", []):
		var fields := str(value).split(":", false)
		if fields.size() != 3 or fields[0] != "save-pending" \
				or fields[1] != GameState.world_id:
			continue
		if require_prior_session and fields[2] == _process_session_nonce:
			continue
		marker = str(value)
		break
	if marker.is_empty():
		return
	var candidate := _onboarding_progress.duplicate(true)
	var candidate_evidence: Array = candidate["evidence_ids"]
	candidate_evidence.erase(marker)
	if not _candidate_complete(candidate, "SAVE_RELOAD"):
		return
	_candidate_add_evidence(candidate, "reload-complete:%s" % GameState.world_id)
	_commit_onboarding_candidate(candidate)

func _onboarding_reload_after_world_load() -> void:
	if not IdentityStore.is_uuid(GameState.world_id) \
			or not IdentityStore.is_uuid(GameState.local_player_id):
		return
	var loaded := _onboarding_store.load(GameState.world_id, GameState.local_player_id)
	if bool(loaded.get("ok", false)):
		_onboarding_progress = loaded["progress"]
		_normalize_onboarding_progress()
		_rebuild_durable_onboarding_state()
	else:
		_onboarding_store_failure()

func _on_scene_node_added(node: Node) -> void:
	call_deferred("_connect_enemy_adapter", node)

func _connect_enemy_adapter(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_in_group("enemy") \
			or not node.has_signal("greyling_defeated"):
		return
	var callback := _on_enemy_greyling_defeated
	if not node.is_connected("greyling_defeated", callback):
		node.connect("greyling_defeated", callback)

func _on_enemy_greyling_defeated(data: Dictionary) -> void:
	if player != null and is_instance_valid(player):
		player.notify_greyling_defeated(data)

func from_loaded_player_starter() -> bool:
	var snapshot: Dictionary = player.to_dict()
	return int(snapshot.get("starter_grant_version", 0)) >= Player.STARTER_GRANT_VERSION
