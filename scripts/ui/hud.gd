class_name HUD
extends Control
## 상시 표시 정보: 체력·스태미나·음식·상태이상·단축바·시계·바이옴·보스 체력·알림.

var player: Player

var hp_bar: ProgressBar
var sp_bar: ProgressBar
var hp_label: Label
var sp_label: Label
var eitr_bar: ProgressBar
var eitr_label: Label
var _eitr_row: HBoxContainer
var food_box: HBoxContainer
var status_box: HBoxContainer
var hotbar: HBoxContainer
var prompt_label: Label
var msg_box: VBoxContainer
var clock_label: Label
var biome_label: Label
var weather_label: Label
var crosshair: Control
var boss_panel: PanelContainer
var boss_bar: ProgressBar
var boss_name: Label
var build_hint: Label
var objective_panel: PanelContainer
var objective_title: Label
var objective_detail: Label
var objective_progress: Label
var objective_action: Label
var action_panel: PanelContainer
var action_feedback: Label
var _feedback_tween: Tween
var _safe_left: VBoxContainer
var _safe_right: VBoxContainer

var _hotbar_slots: Array[Panel] = []
var _selected_hotbar := 0
var _boss: Boss = null

func _ready() -> void:
	name = "hud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	get_viewport().size_changed.connect(_apply_safe_layout)
	_apply_safe_layout()

func bind(p: Player) -> void:
	player = p
	p.stats.hp_changed.connect(_on_hp)
	p.stats.stamina_changed.connect(_on_sp)
	p.stats.food_changed.connect(_refresh_food)
	p.stats.status_changed.connect(_refresh_status)
	p.stats.skill_up.connect(_on_skill_up)
	p.inventory.changed.connect(_refresh_hotbar)
	p.inventory.equipment_changed.connect(_refresh_hotbar)
	p.interact_target_changed.connect(_on_interact_target)
	p.notify.connect(push_message)
	GameState.message.connect(push_message)
	GameState.day_changed.connect(func(d): push_message(tr("MSG_NEW_DAY") % d))
	_on_hp(p.stats.hp, p.stats.max_hp())
	_on_sp(p.stats.stamina, p.stats.max_stamina())
	_refresh_food()
	_refresh_hotbar()

# ═══════════════════════════════════════════════ 구성
func _build() -> void:
	# ── 좌하단: 체력 / 스태미나 / 음식 ──
	var left := VBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left.add_theme_constant_override("separation", 5)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)
	_safe_left = left

	food_box = HBoxContainer.new()
	food_box.add_theme_constant_override("separation", 4)
	left.add_child(food_box)

	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 6)
	left.add_child(hp_row)
	hp_bar = UITheme.make_bar(Color(0.78, 0.20, 0.18), 300, 20)
	hp_row.add_child(hp_bar)
	hp_label = UITheme.label("25 / 25", 15)
	hp_row.add_child(hp_label)

	var sp_row := HBoxContainer.new()
	sp_row.add_theme_constant_override("separation", 6)
	left.add_child(sp_row)
	sp_bar = UITheme.make_bar(Color(0.88, 0.76, 0.28), 300, 14)
	sp_row.add_child(sp_bar)
	sp_label = UITheme.label("50 / 50", 13, UITheme.TEXT_DIM)
	sp_row.add_child(sp_label)

	var eitr_row := HBoxContainer.new()
	eitr_row.add_theme_constant_override("separation", 6)
	left.add_child(eitr_row)
	eitr_bar = UITheme.make_bar(Color(0.55, 0.45, 0.95), 300, 12)
	eitr_row.add_child(eitr_bar)
	eitr_label = UITheme.label("", 12, UITheme.TEXT_DIM)
	eitr_row.add_child(eitr_label)
	eitr_row.visible = false
	_eitr_row = eitr_row

	status_box = HBoxContainer.new()
	status_box.add_theme_constant_override("separation", 5)
	left.add_child(status_box)

	# ── 하단 중앙: 단축바 ──
	hotbar = HBoxContainer.new()
	hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar.position = Vector2(-4 * 62, -84)
	hotbar.add_theme_constant_override("separation", 6)
	hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hotbar)
	for i in range(Const.INV_COLS):
		var slot := Panel.new()
		slot.custom_minimum_size = Vector2(56, 56)
		slot.add_theme_stylebox_override("panel", UITheme.slot_box())
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hotbar.add_child(slot)
		_hotbar_slots.append(slot)

		var tex := TextureRect.new()
		tex.name = "icon"
		tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tex.offset_left = 5; tex.offset_top = 5
		tex.offset_right = -5; tex.offset_bottom = -5
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tex)

		var amt := UITheme.label("", 13)
		amt.name = "amount"
		amt.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		amt.position = Vector2(-26, -20)
		amt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(amt)

		var num := UITheme.label(str(i + 1), 11, UITheme.TEXT_DIM)
		num.position = Vector2(4, 1)
		num.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(num)

	# ── 조준점 ──
	crosshair = Control.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.custom_minimum_size = Vector2(18, 18)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.draw.connect(func():
		var c := Color(1, 1, 1, 0.55)
		crosshair.draw_line(Vector2(-7, 0), Vector2(-2, 0), c, 1.5)
		crosshair.draw_line(Vector2(7, 0), Vector2(2, 0), c, 1.5)
		crosshair.draw_line(Vector2(0, -7), Vector2(0, -2), c, 1.5)
		crosshair.draw_line(Vector2(0, 7), Vector2(0, 2), c, 1.5)
	)
	add_child(crosshair)

	# ── 상호작용 안내: 240x160 중앙 조준 제외 영역 아래 ──
	var prompt_wrap := MarginContainer.new()
	prompt_wrap.set_anchors_preset(Control.PRESET_CENTER)
	prompt_wrap.offset_left = -240
	prompt_wrap.offset_right = 240
	prompt_wrap.offset_top = 92
	prompt_wrap.offset_bottom = 152
	prompt_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt_wrap)
	prompt_label = UITheme.wrap_label("", 19, UITheme.GOLD)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_wrap.add_child(prompt_label)

	build_hint = UITheme.wrap_label("", 15, UITheme.TEXT_DIM)
	build_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	build_hint.position = Vector2(-280, -120)
	build_hint.custom_minimum_size = Vector2(560, 0)
	build_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(build_hint)

	# ── 우상단: 시계 / 바이옴 / 날씨 ──
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.custom_minimum_size = Vector2(250, 0)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	_safe_right = right
	clock_label = UITheme.title("07:00 · 1일차", 20)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(clock_label)
	biome_label = UITheme.label("초원", 17, UITheme.TEXT)
	biome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(biome_label)
	weather_label = UITheme.label("", 14, UITheme.TEXT_DIM)
	weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(weather_label)
	for label in [clock_label, biome_label, weather_label]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# ── 좌상단: 현재 목표. 긴 한국어/영어는 줄바꿈한다. ──
	objective_panel = PanelContainer.new()
	objective_panel.custom_minimum_size = Vector2(420, 0)
	objective_panel.add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.07, 0.06, 0.05, 0.90), UITheme.GOLD_DIM, 5, 2))
	objective_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(objective_panel)
	var objective_box := VBoxContainer.new()
	objective_box.add_theme_constant_override("separation", 3)
	objective_panel.add_child(objective_box)
	objective_title = UITheme.wrap_label(_localized("현재 목표", "CURRENT OBJECTIVE"), 13,
		UITheme.GOLD)
	objective_box.add_child(objective_title)
	objective_detail = UITheme.wrap_label("", 18, UITheme.TEXT)
	objective_detail.max_lines_visible = 3
	objective_box.add_child(objective_detail)
	objective_progress = UITheme.wrap_label("", 14, UITheme.TEXT_DIM)
	objective_box.add_child(objective_progress)
	objective_action = UITheme.wrap_label("", 15, UITheme.GOLD)
	objective_action.max_lines_visible = 3
	objective_box.add_child(objective_action)
	objective_panel.visible = false

	# ── 중앙 하단: 행동 결과. 색상과 [완료]/[불가] 표기를 함께 사용한다. ──
	action_panel = PanelContainer.new()
	action_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	action_panel.position = Vector2(-260, -176)
	action_panel.custom_minimum_size = Vector2(520, 0)
	action_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_panel.visible = false
	add_child(action_panel)
	action_feedback = UITheme.wrap_label("", 16, UITheme.TEXT)
	action_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_panel.add_child(action_feedback)

	# ── 목표 아래: 읽을 수 있는 독립 알림 카드 ──
	msg_box = VBoxContainer.new()
	msg_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	msg_box.position = Vector2(0, 132)
	msg_box.custom_minimum_size = Vector2(420, 0)
	msg_box.add_theme_constant_override("separation", 4)
	msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(msg_box)

	# ── 상단 중앙: 보스 체력바 ──
	var boss_wrap := CenterContainer.new()
	boss_wrap.anchor_right = 1.0
	boss_wrap.offset_top = 24.0
	boss_wrap.offset_bottom = 112.0
	boss_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(boss_wrap)
	boss_panel = PanelContainer.new()
	boss_panel.custom_minimum_size = Vector2(520, 0)
	boss_panel.visible = false
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.08, 0.06, 0.05, 0.92), UITheme.GOLD))
	boss_wrap.add_child(boss_panel)
	var bv := VBoxContainer.new()
	boss_panel.add_child(bv)
	boss_name = UITheme.title("", 22)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(boss_name)
	boss_bar = UITheme.make_bar(Color(0.72, 0.16, 0.14), 500, 16)
	bv.add_child(boss_bar)


func _apply_safe_layout() -> void:
	var margin := UITheme.safe_margin(get_viewport_rect().size.x)
	if _safe_left != null:
		_safe_left.position = Vector2(margin, -156.0)
	if _safe_right != null:
		_safe_right.position = Vector2(-250.0 - margin, margin)
	if objective_panel != null:
		objective_panel.position = Vector2(margin, margin)
	if msg_box != null:
		var message_y := margin
		if objective_panel != null and objective_panel.visible:
			message_y += objective_panel.size.y + 8.0
		msg_box.position = Vector2(margin, message_y)

func _localized(ko: String, en: String) -> String:
	return ko if TranslationServer.get_locale().begins_with("ko") else en

func set_objective(title: String, detail: String, progress_text: String = "") -> void:
	objective_panel.visible = title != "" or detail != ""
	objective_title.text = title if title != "" else _localized("현재 목표", "CURRENT OBJECTIVE")
	objective_detail.text = detail
	objective_progress.text = progress_text
	objective_progress.visible = progress_text != ""
	_apply_safe_layout.call_deferred()

func set_action_hint(text: String) -> void:
	if objective_action == null:
		return
	objective_action.text = text
	objective_action.visible = text != ""
	_apply_safe_layout.call_deferred()

func set_action_feedback(text: String, is_success: bool = false) -> void:
	if text == "":
		clear_action_feedback()
		return
	var prefix := _localized("[완료] ", "[DONE] ") if is_success \
		else _localized("[불가] ", "[UNAVAILABLE] ")
	action_feedback.text = prefix + text
	action_feedback.add_theme_color_override("font_color",
		UITheme.SUCCESS if is_success else UITheme.DANGER_TEXT)
	action_panel.add_theme_stylebox_override("panel", UITheme.feedback_box(is_success))
	action_panel.modulate.a = 1.0
	action_panel.visible = true
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = action_panel.create_tween()
	_feedback_tween.tween_interval(3.0)
	_feedback_tween.tween_property(action_panel, "modulate:a", 0.0, 0.6)
	_feedback_tween.tween_callback(clear_action_feedback)

func clear_action_feedback() -> void:
	if action_panel != null:
		action_panel.visible = false
		action_panel.modulate.a = 1.0

func show_remote_building_limitation() -> void:
	set_action_feedback(_localized("이 릴리스에서는 원격 건축을 지원하지 않습니다",
		"Remote building is unavailable in this release"), false)

func _process(_delta: float) -> void:
	clock_label.text = "%s · %s" % [GameState.clock_string(), tr("UI_DAY") % GameState.day]
	biome_label.text = tr(Const.BIOME_KEY.get(GameState.current_biome, "BIOME_MEADOWS"))
	var sky = get_tree().current_scene.get_node_or_null("sky")
	if sky != null:
		weather_label.text = sky.weather_name()
	if _boss != null and is_instance_valid(_boss) and not _boss._dead:
		boss_bar.value = clampf(_boss.hp / _boss.max_hp, 0.0, 1.0)
	elif boss_panel.visible and (_boss == null or not is_instance_valid(_boss)):
		hide_boss_bar()

	if player != null and is_instance_valid(player):
		# 에이트르는 마법 음식을 먹었을 때만 표시한다
		if _eitr_row != null:
			var me := player.stats.max_eitr
			_eitr_row.visible = me > 0.0
			if me > 0.0:
				eitr_bar.value = clampf(player.stats.eitr / me, 0.0, 1.0)
				eitr_label.text = "%d / %d" % [ceili(player.stats.eitr), ceili(me)]
		var rid := player.inventory.equipped_id(Inventory.SLOT_RIGHT)
		crosshair.visible = player.spring.spring_length < 2.0 \
			or bool(ItemDB.get_item(rid).get("bow", false))

# ═══════════════════════════════════════════════ 갱신
func _on_hp(hp: float, mx: float) -> void:
	hp_bar.value = clampf(hp / maxf(mx, 1.0), 0.0, 1.0)
	hp_label.text = "%d / %d" % [ceili(hp), ceili(mx)]

func _on_sp(sp: float, mx: float) -> void:
	sp_bar.value = clampf(sp / maxf(mx, 1.0), 0.0, 1.0)
	sp_label.text = "%d / %d" % [ceili(sp), ceili(mx)]

func _refresh_food() -> void:
	for c in food_box.get_children():
		c.queue_free()
	if player == null:
		return
	for i in range(Const.FOOD_SLOTS):
		var p := Panel.new()
		p.custom_minimum_size = Vector2(38, 38)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i < player.stats.foods.size():
			var f: Dictionary = player.stats.foods[i]
			var frac := float(f["t"]) / maxf(float(f["dur"]), 1.0)
			var sb := UITheme.slot_box()
			sb.bg_color = ItemDB.color_of(str(f["id"])).darkened(0.35)
			sb.border_color = UITheme.GOLD if frac > 0.3 else UITheme.RED
			p.add_theme_stylebox_override("panel", sb)
			var tex := TextureRect.new()
			tex.texture = ItemDB.icon(str(f["id"]))
			tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tex.offset_left = 3; tex.offset_top = 3
			tex.offset_right = -3; tex.offset_bottom = -3
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p.add_child(tex)
		else:
			var sb2 := UITheme.slot_box()
			sb2.bg_color = Color(0.10, 0.09, 0.08, 0.75)
			p.add_theme_stylebox_override("panel", sb2)
		food_box.add_child(p)

func _refresh_status() -> void:
	for c in status_box.get_children():
		c.queue_free()
	if player == null:
		return
	for s in player.stats.status_list():
		var id := str(s["id"])
		var col := UITheme.TEXT
		match id:
			"wet": col = UITheme.BLUE
			"cold", "freezing": col = Color(0.6, 0.85, 1.0)
			"poison": col = UITheme.GREEN
			"burning": col = Color(1.0, 0.5, 0.2)
			"rested": col = UITheme.YELLOW
		var l := UITheme.label(tr("STATUS_" + id.to_upper()), 14, col)
		l.text = "[%s] %s" % [_localized("상태", "STATUS"), l.text]
		l.tooltip_text = l.text
		status_box.add_child(l)

func _refresh_hotbar() -> void:
	if player == null:
		return
	for i in range(_hotbar_slots.size()):
		var slot := _hotbar_slots[i]
		var s: Dictionary = player.inventory.get_slot(i)
		var icon := slot.get_node("icon") as TextureRect
		var amt := slot.get_node("amount") as Label
		if s.is_empty():
			icon.texture = null
			amt.text = ""
			slot.add_theme_stylebox_override("panel",
				UITheme.slot_box(i == _selected_hotbar, false))
		else:
			icon.texture = ItemDB.icon(str(s["id"]))
			amt.text = str(int(s["amount"])) if int(s["amount"]) > 1 else ""
			slot.add_theme_stylebox_override("panel",
				UITheme.slot_box(i == _selected_hotbar, player.inventory.is_equipped(i)))

func select_hotbar(i: int) -> void:
	_selected_hotbar = clampi(i, 0, Const.INV_COLS - 1)
	_refresh_hotbar()

func use_hotbar(i: int) -> void:
	if player == null:
		return
	select_hotbar(i)
	var s: Dictionary = player.inventory.get_slot(i)
	if s.is_empty():
		return
	var id := str(s["id"])
	var it := ItemDB.get_item(id)
	if it.has("hp") or it.has("potion"):
		_consume(i, id, it)
	else:
		player.inventory.toggle_equip(i)
	_refresh_hotbar()

func _consume(i: int, id: String, it: Dictionary) -> void:
	if it.has("potion"):
		var p: Dictionary = it["potion"]
		if p.has("heal"):
			player.stats.heal(float(p["heal"]))
		if p.has("stam"):
			player.stats.set_stamina(player.stats.stamina + float(p["stam"]))
		for k in p:
			if str(k).begins_with("res_"):
				player.stats.add_status(str(k), float(p.get("dur", 600.0)))
		player.inventory.remove_at(i, 1)
		Sfx.play("eat", -8.0)
		push_message(tr("MSG_DRANK") % ItemDB.name_of(id))
		return
	if player.stats.can_eat(id):
		if player.stats.eat(id):
			player.inventory.remove_at(i, 1)
			Sfx.play("eat", -8.0)
			push_message(tr("MSG_ATE") % ItemDB.name_of(id))
			player.notify_food_eaten(id)
	else:
		push_message(tr("MSG_TOO_FULL"))
		Sfx.play("error", -14.0)

func _on_interact_target(node) -> void:
	if node == null or not is_instance_valid(node):
		prompt_label.text = ""
		return
	var txt := ""
	if node.has_method("prompt"):
		txt = node.prompt()
	prompt_label.text = ("[E] " + txt) if txt != "" else ""

func _on_skill_up(skill: int, level: float) -> void:
	push_message(tr("MSG_SKILL_UP") % [tr(Const.SKILL_KEY.get(skill, "?")), int(level)],
		UITheme.YELLOW)

func set_build_hint(text: String) -> void:
	build_hint.text = text

# ═══════════════════════════════════════════════ 알림
func push_message(text: String, col: Color = UITheme.TEXT) -> void:
	if text == "":
		return
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.055, 0.05, 0.045, 0.90), UITheme.GOLD_DIM, 4, 1))
	var l := UITheme.wrap_label(text, 16, col)
	l.max_lines_visible = 2
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(l)
	msg_box.add_child(card)
	if msg_box.get_child_count() > 3:
		msg_box.get_child(0).queue_free()
	var tw := card.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(card, "modulate:a", 0.0, 1.0)
	tw.tween_callback(card.queue_free)

# ═══════════════════════════════════════════════ 보스 바
func show_boss_bar(boss: Boss) -> void:
	_boss = boss
	boss_panel.visible = true
	boss_name.text = tr(boss.name_key)
	boss_bar.value = 1.0

func hide_boss_bar() -> void:
	_boss = null
	boss_panel.visible = false
