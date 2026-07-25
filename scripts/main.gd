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
var _loading: Label
var started := false

func _ready() -> void:
	name = "main"
	RenderingServer.set_default_clear_color(Color(0.05, 0.06, 0.08))
	_make_title()
	_handle_cli()

## 개발/검증용 커맨드라인 훅:  godot -- --auto --seed=1234 --shots=/경로
func _handle_cli() -> void:
	var args := OS.get_cmdline_user_args()
	var auto := false
	var sv := 424242
	var shots := ""
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
	if not auto:
		return
	_seed_edit.text = str(sv)
	await get_tree().process_frame
	_begin(false)
	if shots != "":
		var dir := ScreenshotDirector.new()
		dir.out_dir = shots
		dir.ui_only = args.has("--uionly")
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

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.custom_minimum_size = Vector2(460, 0)
	v.position = Vector2(-230, -220)
	v.add_theme_constant_override("separation", 14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(v)

	var t := UITheme.title(tr("UI_TITLE"), 68)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := UITheme.label(tr("UI_SUBTITLE"), 17, UITheme.TEXT_DIM)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	v.add_child(UITheme.label("", 14))

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
	b_new.custom_minimum_size = Vector2(0, 56)
	b_new.pressed.connect(func(): _begin(false))
	v.add_child(b_new)

	if SaveSystem.has_save():
		var b_cont := UITheme.button(tr("UI_CONTINUE"), 22)
		b_cont.custom_minimum_size = Vector2(0, 56)
		b_cont.pressed.connect(func(): _begin(true))
		v.add_child(b_cont)

	var b_exit := UITheme.button(tr("UI_EXIT"), 18)
	b_exit.custom_minimum_size = Vector2(0, 44)
	b_exit.pressed.connect(func(): get_tree().quit())
	v.add_child(b_exit)

	var ctrl := UITheme.label(tr("UI_CONTROLS"), 13, UITheme.TEXT_DIM)
	ctrl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctrl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ctrl.position = Vector2(-330, -120)
	ctrl.custom_minimum_size = Vector2(660, 0)
	root.add_child(ctrl)

	_loading = UITheme.title(tr("UI_LOADING"), 30)
	_loading.set_anchors_preset(Control.PRESET_CENTER)
	_loading.position = Vector2(-250, 250)
	_loading.custom_minimum_size = Vector2(500, 0)
	_loading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading.visible = false
	root.add_child(_loading)

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
	add_child(ui)
	ui.bind(player, build_system)

	spawner = SpawnManager.new()
	spawner.name = "spawner"
	add_child(spawner)

	_place_altars()

	# 첫 지형을 미리 만들어 낙하 방지
	chunks.preload_around(player.global_position)
	player.global_position.y = GameState.height_at(
		player.global_position.x, player.global_position.z) + 1.2

	if from_save:
		SaveSystem.load_game(player, build_system)
		chunks.preload_around(player.global_position)

	_title.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameState.msg(tr("MSG_WELCOME"))

	# 은은한 바람 소리
	var wind := AudioStreamPlayer.new()
	wind.stream = Sfx.stream_for("wind")
	wind.volume_db = -26.0
	wind.autoplay = true
	add_child(wind)
	wind.play()

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
	# 월드 밖으로 떨어지면 되돌린다
	if player.global_position.y < -300.0:
		var sp: Vector3 = player.get_meta("spawn_point", Vector3.ZERO)
		player.global_position = sp + Vector3(0, 2, 0)
		player.velocity = Vector3.ZERO
