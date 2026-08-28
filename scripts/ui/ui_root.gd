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
var settings_ui: PanelContainer
var death_ui: PanelContainer
var powers_ui: PanelContainer
var interaction_controller: InteractionModeController
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
var _settings := SettingsStore.new()
var _settings_values: Dictionary = {}
var _pause_labels: Dictionary = {}
var _settings_labels: Dictionary = {}
var _setting_controls: Dictionary = {}
var _pause_claimed := false


func _ready() -> void:
	name = "ui"
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	interaction_controller = InteractionModeController.new()
	interaction_controller.name = "interaction_mode_controller"
	add_child(interaction_controller)

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UITheme.get_theme()
	add_child(_root)
	_settings_values = _settings.load()
	_apply_settings(_settings_values)

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
	_bottom.offset_top = 300
	_bottom.offset_bottom = -96
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bottom)

	inv_ui = InventoryUI.new()
	inv_ui.visible = false
	inv_ui.focus_mode = Control.FOCUS_ALL
	_center.add_child(inv_ui)

	craft_ui = CraftUI.new()
	craft_ui.visible = false
	craft_ui.focus_mode = Control.FOCUS_ALL
	_center.add_child(craft_ui)

	build_ui = BuildUI.new()
	_bottom.add_child(build_ui)

	map_ui = MapUI.new()
	map_ui.focus_mode = Control.FOCUS_ALL
	_center.add_child(map_ui)

	_make_skills()
	_make_powers()
	_make_settings()
	_make_pause()
	_make_death()
	_make_chat()

## 멀티플레이 채팅. 온라인이 아니면 만들어만 두고 숨겨둔다.
func _make_chat() -> void:
	_chat_box = VBoxContainer.new()
	_chat_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_chat_box.position = Vector2(24, -320)
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
	chat_log.modulate = Color(1, 1, 1, 1)
	_chat_fade = 9.0
	interaction_controller.set_mode_active(InteractionModeController.Mode.CHAT, true, chat_edit)

func close_chat() -> void:
	chat_edit.visible = false
	interaction_controller.set_mode_active(InteractionModeController.Mode.CHAT, false)

func bind(p: Player, bs: BuildSystem) -> void:
	player = p
	build_system = bs
	interaction_controller.bind_player(p)
	hud.bind(p)
	inv_ui.bind(p)
	craft_ui.bind(p, bs)
	build_ui.bind(p, bs)
	build_ui.palette_closed.connect(_update_mode)
	build_ui.piece_chosen.connect(_update_mode)
	build_ui.palette_focus_requested.connect(_update_mode)
	map_ui.bind(p)
	p.stats.died.connect(_on_died)
	_apply_settings(_settings_values)

# ═══════════════════════════════════════════════ 입력
func _unhandled_input(event: InputEvent) -> void:
	if player == null or not is_instance_valid(player):
		return
	# A higher-priority mode owns the event stream; only its explicit escape action is handled.
	if interaction_controller.current_mode in [InteractionModeController.Mode.DISCONNECTED,
			InteractionModeController.Mode.TRANSITION, InteractionModeController.Mode.DEATH]:
		get_viewport().set_input_as_handled()
		return
	if build_ui.is_palette_open():
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("build_mode"):
			build_ui.close_palette()
			_update_mode()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("ui_accept"):
			var owner := get_viewport().gui_get_focus_owner()
			if owner is Button:
				(owner as Button).pressed.emit()
			get_viewport().set_input_as_handled()
			return
		var palette_navigation := event.is_action_pressed("ui_up") \
			or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") \
			or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_focus_next") \
			or event.is_action_pressed("ui_focus_prev")
		if not palette_navigation:
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("build_mode") and build_system != null and build_system.active:
		build_ui.open_palette()
		_update_mode()
		get_viewport().set_input_as_handled()
		return
	if interaction_controller.blocks_gameplay_input() and event.is_action_pressed("inventory") \
			and not _open_panels.has(inv_ui):
		get_viewport().set_input_as_handled()
		return
	if interaction_controller.blocks_gameplay_input() and event.is_action_pressed("map") \
			and not _open_panels.has(map_ui):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory"):
		if _open_panels.has(inv_ui):
			close_all()
		else:
			close_all()
			open_panel(inv_ui)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("map"):
		if _open_panels.has(map_ui):
			close_all()
		else:
			close_all()
			open_panel(map_ui)
		get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("ui_cancel"):
		if chat_edit != null and chat_edit.visible:
			close_chat()
		elif _open_panels.has(settings_ui):
			_open_pause_from_settings()
		elif not _open_panels.is_empty():
			close_all()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()
		return

	elif event is InputEventKey and event.pressed and not event.echo:
		# Enter: 멀티플레이 채팅 (온라인일 때만)
		if event.keycode == KEY_ENTER and Net.is_online and _open_panels.is_empty():
			if chat_edit != null and not chat_edit.visible:
				open_chat()
				get_viewport().set_input_as_handled()
				return
		if interaction_controller.blocks_gameplay_input():
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
	if interaction_controller.blocks_gameplay_input():
		get_viewport().set_input_as_handled()
		return
	if interaction_controller.is_gameplay() and not player.stats.is_dead:
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
	if build_system != null and build_system.active and interaction_controller.is_gameplay():
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
	_close_all(true)

func _close_all(release_pause: bool) -> void:
	if release_pause:
		_pause_claimed = false
	for p in _open_panels:
		if is_instance_valid(p):
			p.visible = false
	_open_panels.clear()
	inv_ui.drop_held()
	inv_ui.close_container()
	_open_box = null
	_update_mode()

func _update_mode() -> void:
	interaction_controller.set_offline_pause_claimed(_pause_claimed)

	var panels_open := not _open_panels.is_empty()
	var open := panels_open or build_ui.is_palette_open()
	_dim.visible = open
	var menu := _highest_open_panel()
	interaction_controller.set_mode_states({
		InteractionModeController.Mode.DEATH: _open_panels.has(death_ui),
		InteractionModeController.Mode.PAUSE: _open_panels.has(pause_ui),
		InteractionModeController.Mode.SETTINGS_HELP: _open_panels.has(settings_ui)
			or _open_panels.has(skills_ui) or _open_panels.has(powers_ui),
		InteractionModeController.Mode.INVENTORY_CRAFT_BUILD_MENU: build_ui.is_palette_open()
			or panels_open and not _open_panels.has(death_ui) and not _open_panels.has(pause_ui)
			and not _open_panels.has(settings_ui) and not _open_panels.has(skills_ui)
			and not _open_panels.has(powers_ui),
	}, {
		InteractionModeController.Mode.DEATH: death_ui,
		InteractionModeController.Mode.PAUSE: pause_ui,
		InteractionModeController.Mode.SETTINGS_HELP: menu,
		InteractionModeController.Mode.INVENTORY_CRAFT_BUILD_MENU: \
			build_ui.focus_target() if build_ui.is_palette_open() else menu,

	})

func _highest_open_panel() -> Control:
	return _open_panels.back() if not _open_panels.is_empty() else null

func set_disconnected(active: bool) -> void:
	interaction_controller.set_mode_active(InteractionModeController.Mode.DISCONNECTED, active)

func set_transition(active: bool) -> void:
	interaction_controller.set_mode_active(InteractionModeController.Mode.TRANSITION, active)

func set_settings_help(active: bool, focus_target: Control = null) -> void:
	interaction_controller.set_mode_active(InteractionModeController.Mode.SETTINGS_HELP,
		active, focus_target)

func set_chat_mode(active: bool, focus_target: Control = null) -> void:
	interaction_controller.set_mode_active(InteractionModeController.Mode.CHAT,
		active, focus_target)

func set_objective(title: String, detail: String, progress_text: String = "") -> void:
	hud.set_objective(title, detail, progress_text)

func set_action_feedback(text: String, is_success: bool = false) -> void:
	hud.set_action_feedback(text, is_success)

# ═══════════════════════════════════════════════ 외부 호출 진입점
func open_craft(station: String, p: Player) -> void:
	_close_all(false)
	craft_ui.open(station, p)
	open_panel(craft_ui)

func open_container(box: StorageBox, p: Player) -> void:
	open_container_inv(box, box.storage, p)

func open_container_inv(node: Node, inv: Inventory, p: Player) -> void:
	_close_all(false)
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

# ═══════════════════════════════════════════════ 설정
func _make_settings() -> void:
	settings_ui = PanelContainer.new()
	settings_ui.custom_minimum_size = Vector2(500, 600)
	settings_ui.visible = false
	settings_ui.focus_mode = Control.FOCUS_ALL
	settings_ui.add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.07, 0.06, 0.05, 0.98), UITheme.GOLD, 6, 3))
	_center.add_child(settings_ui)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	settings_ui.add_child(v)
	_settings_labels["title"] = UITheme.title("", 28)
	v.add_child(_settings_labels["title"])
	_add_option_button(v, "locale", ["한국어", "English"], ["ko", "en"])
	_add_option_button(v, "ui_scale", ["75%", "100%", "125%"], [0.75, 1.0, 1.25])
	_add_slider(v, "master_volume", 0.0, 1.0, 0.05)
	_add_slider(v, "sfx_volume", 0.0, 1.0, 0.05)
	_add_slider(v, "ambient_volume", 0.0, 1.0, 0.05)
	_add_slider(v, "mouse_sensitivity", 0.0005, 0.01, 0.0005)
	_add_check(v, "invert_y")
	_add_check(v, "reduced_shake")
	var back := UITheme.button("", 18)
	back.name = "back"
	back.pressed.connect(_open_pause_from_settings)
	v.add_child(back)
	_settings_labels["back"] = back
	_refresh_settings_labels()

func _add_option_button(parent: VBoxContainer, key: String, labels: Array,
		values: Array) -> void:
	var row := HBoxContainer.new()
	var label := UITheme.label("", 16)
	label.custom_minimum_size.x = 230
	row.add_child(label)
	var option := OptionButton.new()
	option.focus_mode = Control.FOCUS_ALL
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for text in labels:
		option.add_item(str(text))
	option.set_meta("setting_values", values.duplicate())

	var current = _settings_values.get(key)
	for i in values.size():
		if values[i] == current:
			option.select(i)
	option.item_selected.connect(func(index: int): _set_setting(key, values[index]))
	row.add_child(option)
	parent.add_child(row)
	_settings_labels[key] = label
	_setting_controls[key] = option

func _add_slider(parent: VBoxContainer, key: String, minimum: float, maximum: float,
		step: float) -> void:
	var row := HBoxContainer.new()
	var label := UITheme.label("", 16)
	label.custom_minimum_size.x = 230
	row.add_child(label)
	var slider := HSlider.new()
	slider.focus_mode = Control.FOCUS_ALL
	slider.custom_minimum_size.x = 220
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(_settings_values[key])
	slider.value_changed.connect(func(value: float): _set_setting(key, value))
	row.add_child(slider)
	parent.add_child(row)
	_settings_labels[key] = label
	_setting_controls[key] = slider

func _add_check(parent: VBoxContainer, key: String) -> void:
	var check := CheckButton.new()
	check.focus_mode = Control.FOCUS_ALL
	check.button_pressed = bool(_settings_values[key])
	check.toggled.connect(func(value: bool): _set_setting(key, value))
	parent.add_child(check)
	_settings_labels[key] = check
	_setting_controls[key] = check


func _set_setting(key: String, value) -> void:
	if not _settings.set_value(key, value):
		_restore_setting_control(key)
		GameState.msg(_settings.last_error)
		return
	_settings_values = _settings.snapshot()
	_apply_settings(_settings_values)
	if key == "locale":
		_refresh_localized_labels()
		GameState.msg(tr("MSG_LANG_CHANGED"))

func _restore_setting_control(key: String) -> void:
	var control: Control = _setting_controls.get(key)
	var persisted = _settings_values.get(key)
	if control is OptionButton:
		var values: Array = control.get_meta("setting_values", [])
		for i in values.size():
			if values[i] == persisted:
				(control as OptionButton).select(i)
				break
	elif control is Range:
		(control as Range).set_value_no_signal(float(persisted))
	elif control is BaseButton:
		(control as BaseButton).set_pressed_no_signal(bool(persisted))


func _apply_settings(values: Dictionary) -> void:
	var scale_value := float(values.get("ui_scale", 1.0))
	get_tree().root.content_scale_factor = scale_value
	if inv_ui != null and is_instance_valid(inv_ui):
		inv_ui.call_deferred("apply_responsive_layout")
	if craft_ui != null and is_instance_valid(craft_ui):
		craft_ui.call_deferred("apply_responsive_layout")
	if build_ui != null and is_instance_valid(build_ui):
		build_ui.call_deferred("apply_responsive_layout")
	if player != null and is_instance_valid(player):
		player.apply_settings(values)

func _open_settings() -> void:
	if not _open_panels.has(pause_ui):
		return
	_pause_claimed = true
	_replace_panel(pause_ui, settings_ui)

func _open_pause_from_settings() -> void:
	if not _open_panels.has(settings_ui):
		return
	_pause_claimed = true
	_replace_panel(settings_ui, pause_ui)

func _replace_panel(from: Control, to: Control) -> void:
	var index := _open_panels.find(from)
	if index >= 0:
		_open_panels.remove_at(index)
	from.visible = false
	if not _open_panels.has(to):
		_open_panels.append(to)
	to.visible = true
	_update_mode()


func _refresh_settings_labels() -> void:
	var ko := TranslationServer.get_locale().begins_with("ko")
	var labels := {
		"title": "설정" if ko else "Settings",
		"locale": "언어" if ko else "Language",
		"ui_scale": "UI 크기" if ko else "UI Scale",
		"master_volume": "전체 음량" if ko else "Master Volume",
		"sfx_volume": "효과음 음량" if ko else "SFX Volume",
		"ambient_volume": "환경음 음량" if ko else "Ambient Volume",
		"mouse_sensitivity": "마우스 감도" if ko else "Mouse Sensitivity",
		"invert_y": "Y축 반전" if ko else "Invert Y",
		"reduced_shake": "화면 흔들림 줄이기" if ko else "Reduced Shake",
		"back": "뒤로" if ko else "Back",
	}
	for key in labels:
		var control: Control = _settings_labels.get(key)
		if control is Label or control is Button:
			control.text = labels[key]

func _refresh_localized_labels() -> void:
	for key in _pause_labels:
		var control: Control = _pause_labels[key]
		control.text = ("설정" if TranslationServer.get_locale().begins_with("ko") else "Settings") \
			if key == "UI_SETTINGS" else tr(key)
	_refresh_settings_labels()
	if chat_edit != null:
		chat_edit.placeholder_text = tr("UI_CHAT_HINT")
	if _open_panels.has(skills_ui):
		_refresh_skills()
	if _open_panels.has(powers_ui):
		_refresh_powers()

# ═══════════════════════════════════════════════ 일시정지
func _make_pause() -> void:
	pause_ui = PanelContainer.new()
	pause_ui.custom_minimum_size = Vector2(400, 440)
	pause_ui.visible = false
	pause_ui.focus_mode = Control.FOCUS_ALL
	pause_ui.add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.07, 0.06, 0.05, 0.98), UITheme.GOLD, 6, 3))
	_center.add_child(pause_ui)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pause_ui.add_child(v)
	var t := UITheme.title(tr("UI_PAUSED"), 30)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_pause_labels["UI_PAUSED"] = t

	var b_resume := UITheme.button(tr("UI_RESUME"), 19)
	b_resume.custom_minimum_size = Vector2(0, 46)
	b_resume.pressed.connect(_resume_game)

	v.add_child(b_resume)
	_pause_labels["UI_RESUME"] = b_resume

	var b_save := UITheme.button(tr("UI_SAVE"), 19)
	b_save.custom_minimum_size = Vector2(0, 46)
	b_save.pressed.connect(_save_game)
	v.add_child(b_save)
	_pause_labels["UI_SAVE"] = b_save

	var b_load := UITheme.button(tr("UI_LOAD"), 19)
	b_load.custom_minimum_size = Vector2(0, 46)
	b_load.pressed.connect(func():
		SaveSystem.load_game(player, build_system)
		_resume_game())

	v.add_child(b_load)
	_pause_labels["UI_LOAD"] = b_load

	var b_settings := UITheme.button("", 17)
	b_settings.custom_minimum_size = Vector2(0, 40)
	b_settings.pressed.connect(_open_settings)
	v.add_child(b_settings)
	_pause_labels["UI_SETTINGS"] = b_settings

	v.add_child(UITheme.label(tr("UI_CONTROLS"), 13, UITheme.TEXT_DIM))

	var b_quit := UITheme.button(tr("UI_QUIT"), 19)
	b_quit.custom_minimum_size = Vector2(0, 46)
	b_quit.pressed.connect(_save_and_quit)
	v.add_child(b_quit)
	_pause_labels["UI_QUIT"] = b_quit
	_refresh_localized_labels()

func _save_game() -> bool:
	return SaveSystem.save_game(player, build_system)

func _save_and_quit() -> void:
	if _save_game():
		get_tree().quit()

func _resume_game() -> void:
	close_all()

func toggle_pause() -> void:
	if _open_panels.has(pause_ui):
		close_all()
	else:
		close_all()
		_pause_claimed = true
		open_panel(pause_ui)


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
