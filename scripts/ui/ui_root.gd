class_name UIRoot
extends CanvasLayer
## UI 총괄: HUD · 인벤토리 · 제작 · 건축 · 지도 · 스킬 · 일시정지 · 사망.

var player: Player
var build_system: BuildSystem

var hud: HUD
var inv_ui: InventoryUI
var craft_ui: CraftUI
var build_ui: BuildUI
var map_ui: MapUI
var skills_ui: PanelContainer
var pause_ui: PanelContainer
var death_ui: PanelContainer
var powers_ui: PanelContainer
var _dim: ColorRect
var _root: Control
var chat_log: RichTextLabel      # 멀티플레이 채팅 기록
var chat_edit: LineEdit
var _chat_box: VBoxContainer
var _chat_fade := 0.0
var _center: CenterContainer     # 중앙 정렬 패널 컨테이너
var _bottom: CenterContainer     # 하단 정렬(건축 패널)

var _open_panels: Array[Control] = []
var _open_box: StorageBox = null

func _ready() -> void:
	name = "ui"
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.get_theme()
	add_child(_root)

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.45)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.visible = false
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)

	hud = HUD.new()
	_root.add_child(hud)

	# 해상도가 바뀌어도 항상 중앙에 오도록 컨테이너에 담는다
	_center = CenterContainer.new()
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_center)

	_bottom = CenterContainer.new()
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bottom.offset_top = 320
	_bottom.offset_bottom = -110
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bottom)

	inv_ui = InventoryUI.new()
	inv_ui.visible = false
	_center.add_child(inv_ui)

	craft_ui = CraftUI.new()
	craft_ui.visible = false
	_center.add_child(craft_ui)

	build_ui = BuildUI.new()
	_bottom.add_child(build_ui)

	map_ui = MapUI.new()
	_center.add_child(map_ui)

	_make_skills()
	_make_powers()
	_make_pause()
	_make_death()
	_make_chat()

## 멀티플레이 채팅. 온라인이 아니면 만들어만 두고 숨겨둔다.
func _make_chat() -> void:
	_chat_box = VBoxContainer.new()
	_chat_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_chat_box.position = Vector2(18, -320)
	_chat_box.custom_minimum_size = Vector2(430, 0)
	_chat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_chat_box)

	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = true
	chat_log.fit_content = false
	chat_log.scroll_following = true
	chat_log.custom_minimum_size = Vector2(430, 150)
	chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_log.modulate = Color(1, 1, 1, 0)
	_chat_box.add_child(chat_log)

	chat_edit = LineEdit.new()
	chat_edit.custom_minimum_size = Vector2(430, 34)
	chat_edit.placeholder_text = tr("UI_CHAT_HINT")
	chat_edit.visible = false
	chat_edit.text_submitted.connect(_on_chat_submit)
	_chat_box.add_child(chat_edit)

	Net.chat_received.connect(_on_chat_received)

func _on_chat_received(pname: String, text: String) -> void:
	if chat_log == null:
		return
	chat_log.append_text("[color=#d8c48a]%s[/color]: %s\n" % [pname, text])
	_chat_fade = 9.0
	chat_log.modulate = Color(1, 1, 1, 1)

func _on_chat_submit(text: String) -> void:
	Net.say(text)
	chat_edit.text = ""
	close_chat()

func open_chat() -> void:
	if not Net.is_online:
		return
	chat_edit.visible = true
	chat_edit.grab_focus()
	chat_log.modulate = Color(1, 1, 1, 1)
	_chat_fade = 9.0
	player.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_chat() -> void:
	chat_edit.visible = false
	chat_edit.release_focus()
	if _open_panels.is_empty():
		player.input_locked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func bind(p: Player, bs: BuildSystem) -> void:
	player = p
	build_system = bs
	hud.bind(p)
	inv_ui.bind(p)
	craft_ui.bind(p, bs)
	build_ui.bind(p, bs)
	map_ui.bind(p)
	p.stats.died.connect(_on_died)

# ═══════════════════════════════════════════════ 입력
func _unhandled_input(event: InputEvent) -> void:
	if player == null or not is_instance_valid(player):
		return
	if event.is_action_pressed("inventory"):
		if _open_panels.has(inv_ui):
			close_all()
		else:
			close_all()
			open_panel(inv_ui)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map"):
		if _open_panels.has(map_ui):
			close_all()
		else:
			close_all()
			open_panel(map_ui)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if chat_edit != null and chat_edit.visible:
			close_chat()
			get_viewport().set_input_as_handled()
			return
		if not _open_panels.is_empty():
			close_all()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		# Enter: 멀티플레이 채팅 (온라인일 때만)
		if event.keycode == KEY_ENTER and Net.is_online and _open_panels.is_empty():
			if chat_edit != null and not chat_edit.visible:
				open_chat()
				get_viewport().set_input_as_handled()
				return
		match event.keycode:
			KEY_F5:
				SaveSystem.save_game(player, build_system)
			KEY_F9:
				SaveSystem.load_game(player, build_system)
			KEY_K:
				if _open_panels.has(skills_ui):
					close_all()
				else:
					close_all()
					_refresh_skills()
					open_panel(skills_ui)
			KEY_F:
				if GameState.activate_power():
					pass
			KEY_P:
				if _open_panels.has(powers_ui):
					close_all()
				else:
					close_all()
					_refresh_powers()
					open_panel(powers_ui)
	if _open_panels.is_empty() and not player.stats.is_dead:
		for i in range(Const.INV_COLS):
			if event.is_action_pressed("hotbar_%d" % (i + 1)):
				hud.use_hotbar(i)
				get_viewport().set_input_as_handled()
				return

func _process(_delta: float) -> void:
	# 채팅 로그는 잠시 뒤 흐려진다 (입력창이 열려 있으면 유지)
	if chat_log != null:
		if chat_edit != null and chat_edit.visible:
			_chat_fade = 9.0
		elif _chat_fade > 0.0:
			_chat_fade -= _delta
			chat_log.modulate.a = clampf(_chat_fade / 2.0, 0.0, 1.0)
	if build_system != null and build_system.active and _open_panels.is_empty():
		hud.set_build_hint(tr("UI_BUILD_KEYS"))
	else:
		hud.set_build_hint("")

# ═══════════════════════════════════════════════ 패널 관리
func open_panel(p: Control) -> void:
	if p == null or _open_panels.has(p):
		return
	_open_panels.append(p)
	p.visible = true
	_update_mode()

func close_all() -> void:
	for p in _open_panels:
		if is_instance_valid(p):
			p.visible = false
	_open_panels.clear()
	inv_ui.drop_held()
	inv_ui.close_container()
	_open_box = null
	_update_mode()

func _update_mode() -> void:
	var open := not _open_panels.is_empty()
	_dim.visible = open
	if player != null and is_instance_valid(player):
		player.input_locked = open
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if open else Input.MOUSE_MODE_CAPTURED
	get_tree().paused = _open_panels.has(pause_ui)

# ═══════════════════════════════════════════════ 외부 호출 진입점
func open_craft(station: String, p: Player) -> void:
	close_all()
	craft_ui.open(station, p)
	open_panel(craft_ui)

func open_container(box: StorageBox, p: Player) -> void:
	open_container_inv(box, box.storage, p)

func open_container_inv(node: Node, inv: Inventory, p: Player) -> void:
	close_all()
	var title := tr("UI_CHEST")
	if node is StorageBox:
		title = tr(node.title_key)
	inv_ui.open_container(inv, title)
	open_panel(inv_ui)

func show_boss_bar(b: Boss) -> void:
	hud.show_boss_bar(b)

func hide_boss_bar() -> void:
	hud.hide_boss_bar()

# ═══════════════════════════════════════════════ 스킬 창
func _make_skills() -> void:
	skills_ui = PanelContainer.new()
	skills_ui.custom_minimum_size = Vector2(560, 640)
	skills_ui.visible = false
	skills_ui.add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.08, 0.07, 0.06, 0.97), UITheme.GOLD_DIM, 6, 3))
	_center.add_child(skills_ui)
	var v := VBoxContainer.new()
	v.name = "list"
	v.add_theme_constant_override("separation", 6)
	skills_ui.add_child(v)

func _refresh_skills() -> void:
	var v := skills_ui.get_node("list") as VBoxContainer
	for c in v.get_children():
		c.queue_free()
	v.add_child(UITheme.title(tr("UI_SKILLS"), 26))
	var keys: Array = Const.Skill.values()
	keys.sort_custom(func(a, b):
		return player.stats.skill_level(a) > player.stats.skill_level(b))
	for s in keys:
		var lvl := player.stats.skill_level(s)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		v.add_child(row)
		var nm := UITheme.label(tr(Const.SKILL_KEY.get(s, "?")), 16)
		nm.custom_minimum_size = Vector2(150, 0)
		row.add_child(nm)
		var bar := UITheme.make_bar(UITheme.GOLD, 300, 16)
		bar.value = lvl / Const.SKILL_MAX
		row.add_child(bar)
		row.add_child(UITheme.label(str(int(lvl)), 16, UITheme.TEXT_DIM))

	v.add_child(UITheme.label("", 8))
	v.add_child(UITheme.title(tr("UI_STATS"), 20))
	var st := GameState.stats
	for k in ["kills", "deaths", "crafted", "built", "trees"]:
		v.add_child(UITheme.label("%s: %d" % [tr("STAT_" + k.to_upper()), int(st[k])], 15,
			UITheme.TEXT_DIM))
	v.add_child(UITheme.label("%s: %.0f m" % [tr("STAT_DISTANCE"),
		float(st["distance"])], 15, UITheme.TEXT_DIM))

# ═══════════════════════════════════════════════ 포세이큰 파워
func _make_powers() -> void:
	powers_ui = PanelContainer.new()
	powers_ui.custom_minimum_size = Vector2(560, 480)
	powers_ui.visible = false
	powers_ui.add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.08, 0.07, 0.06, 0.97), UITheme.GOLD_DIM, 6, 3))
	_center.add_child(powers_ui)
	var v := VBoxContainer.new()
	v.name = "list"
	v.add_theme_constant_override("separation", 8)
	powers_ui.add_child(v)

func _refresh_powers() -> void:
	var v := powers_ui.get_node("list") as VBoxContainer
	for c in v.get_children():
		c.queue_free()
	v.add_child(UITheme.title(tr("UI_POWERS"), 26))
	if GameState.known_powers.is_empty():
		v.add_child(UITheme.label(tr("UI_NO_POWERS"), 16, UITheme.TEXT_DIM))
		return
	for pid in GameState.known_powers:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		v.add_child(row)
		var b := UITheme.button(tr("POWER_" + str(pid).to_upper()), 17)
		b.custom_minimum_size = Vector2(200, 40)
		var id := str(pid)
		b.pressed.connect(func():
			GameState.set_power(id)
			Sfx.play("click", -14.0)
			_refresh_powers())
		row.add_child(b)
		var d := UITheme.label(tr("POWER_" + str(pid).to_upper() + "_D"), 14,
			UITheme.TEXT_DIM)
		d.custom_minimum_size = Vector2(300, 0)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(d)
		if GameState.active_power == id:
			row.add_child(UITheme.label("✔", 20, UITheme.GOLD))
	v.add_child(UITheme.label(tr("UI_POWER_HINT"), 14, UITheme.TEXT_DIM))

# ═══════════════════════════════════════════════ 일시정지
func _make_pause() -> void:
	pause_ui = PanelContainer.new()
	pause_ui.custom_minimum_size = Vector2(400, 440)
	pause_ui.visible = false
	pause_ui.add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.07, 0.06, 0.05, 0.98), UITheme.GOLD, 6, 3))
	_center.add_child(pause_ui)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pause_ui.add_child(v)
	var t := UITheme.title(tr("UI_PAUSED"), 30)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)

	var b_resume := UITheme.button(tr("UI_RESUME"), 19)
	b_resume.custom_minimum_size = Vector2(0, 46)
	b_resume.pressed.connect(close_all)
	v.add_child(b_resume)

	var b_save := UITheme.button(tr("UI_SAVE"), 19)
	b_save.custom_minimum_size = Vector2(0, 46)
	b_save.pressed.connect(func(): SaveSystem.save_game(player, build_system))
	v.add_child(b_save)

	var b_load := UITheme.button(tr("UI_LOAD"), 19)
	b_load.custom_minimum_size = Vector2(0, 46)
	b_load.pressed.connect(func():
		SaveSystem.load_game(player, build_system)
		close_all())
	v.add_child(b_load)

	var b_lang := UITheme.button("한국어 / English", 17)
	b_lang.custom_minimum_size = Vector2(0, 40)
	b_lang.pressed.connect(_toggle_lang)
	v.add_child(b_lang)

	v.add_child(UITheme.label(tr("UI_CONTROLS"), 13, UITheme.TEXT_DIM))

	var b_quit := UITheme.button(tr("UI_QUIT"), 19)
	b_quit.custom_minimum_size = Vector2(0, 46)
	b_quit.pressed.connect(func():
		SaveSystem.save_game(player, build_system)
		get_tree().quit())
	v.add_child(b_quit)

func toggle_pause() -> void:
	if _open_panels.has(pause_ui):
		close_all()
	else:
		close_all()
		open_panel(pause_ui)

func _toggle_lang() -> void:
	var cur := TranslationServer.get_locale()
	TranslationServer.set_locale("en" if cur.begins_with("ko") else "ko")
	Sfx.play("click", -14.0)
	# 텍스트 갱신을 위해 패널을 다시 만든다
	close_all()
	GameState.msg(tr("MSG_LANG_CHANGED"))

# ═══════════════════════════════════════════════ 사망
func _make_death() -> void:
	death_ui = PanelContainer.new()
	death_ui.custom_minimum_size = Vector2(520, 300)
	death_ui.visible = false
	death_ui.add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.10, 0.03, 0.03, 0.97), Color(0.6, 0.2, 0.16), 6, 3))
	_center.add_child(death_ui)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	death_ui.add_child(v)
	var t := UITheme.title(tr("UI_YOU_DIED"), 40, Color(0.85, 0.25, 0.20))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var d := UITheme.label(tr("UI_DEATH_DESC"), 16, UITheme.TEXT_DIM)
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(460, 0)
	v.add_child(d)
	var b := UITheme.button(tr("UI_RESPAWN"), 22)
	b.custom_minimum_size = Vector2(0, 56)
	b.pressed.connect(_respawn)
	v.add_child(b)

func _on_died() -> void:
	close_all()
	open_panel(death_ui)

func _respawn() -> void:
	var pos: Vector3 = player.get_meta("spawn_point", Vector3.ZERO)
	if pos == Vector3.ZERO:
		pos = GameState.gen.find_spawn()
	player.respawn_at(pos)
	close_all()
