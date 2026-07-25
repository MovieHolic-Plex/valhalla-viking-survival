class_name HUD
extends Control
## 상시 표시 정보: 체력·스태미나·음식·상태이상·단축바·시계·바이옴·보스 체력·알림.

var player: Player

var hp_bar: ProgressBar
var sp_bar: ProgressBar
var hp_label: Label
var sp_label: Label
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

var _hotbar_slots: Array[Panel] = []
var _selected_hotbar := 0
var _boss: Boss = null

func _ready() -> void:
	name = "hud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

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
	left.position = Vector2(24, -156)
	left.add_theme_constant_override("separation", 5)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left)

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

	# ── 상호작용 안내 ──
	prompt_label = UITheme.label("", 19, UITheme.GOLD)
	prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	prompt_label.position = Vector2(-180, 46)
	prompt_label.custom_minimum_size = Vector2(360, 0)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt_label)

	build_hint = UITheme.label("", 15, UITheme.TEXT_DIM)
	build_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	build_hint.position = Vector2(-220, -120)
	build_hint.custom_minimum_size = Vector2(440, 0)
	build_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(build_hint)

	# ── 우상단: 시계 / 바이옴 / 날씨 ──
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-230, 18)
	right.custom_minimum_size = Vector2(210, 0)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right)
	clock_label = UITheme.title("07:00 · 1일차", 20)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(clock_label)
	biome_label = UITheme.label("초원", 17, UITheme.TEXT)
	biome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(biome_label)
	weather_label = UITheme.label("", 14, UITheme.TEXT_DIM)
	weather_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(weather_label)

	# ── 좌상단: 알림 ──
	msg_box = VBoxContainer.new()
	msg_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	msg_box.position = Vector2(24, 20)
	msg_box.add_theme_constant_override("separation", 3)
	msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(msg_box)

	# ── 상단 중앙: 보스 체력바 ──
	var boss_wrap := CenterContainer.new()
	boss_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boss_wrap.offset_top = 24
	boss_wrap.offset_bottom = -700
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
	var l := UITheme.label(text, 17, col)
	msg_box.add_child(l)
	if msg_box.get_child_count() > 6:
		msg_box.get_child(0).queue_free()
	var tw := l.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.2)
	tw.tween_callback(l.queue_free)

# ═══════════════════════════════════════════════ 보스 바
func show_boss_bar(boss: Boss) -> void:
	_boss = boss
	boss_panel.visible = true
	boss_name.text = tr(boss.name_key)
	boss_bar.value = 1.0

func hide_boss_bar() -> void:
	_boss = null
	boss_panel.visible = false
