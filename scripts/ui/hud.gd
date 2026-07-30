extends CanvasLayer

const FONT: FontFile = preload("res://assets/fonts/NanumBarunGothic.ttf")
const FONT_BOLD: FontFile = preload("res://assets/fonts/NanumBarunGothicBold.ttf")
const INK := Color(0.86, 0.87, 0.81)
const MUTED := Color(0.61, 0.65, 0.61)
const GOLD := Color(0.83, 0.66, 0.35)
const PANEL := Color(0.045, 0.062, 0.062, 0.90)

var game: Node
var player: Node
var root: Control
var hp_bar: ProgressBar
var stamina_bar: ProgressBar
var hp_label: Label
var stamina_label: Label
var food_labels: Array[Label] = []
var day_label: Label
var objective_label: RichTextLabel
var objective_step_label: Label
var prompt_label: Label
var notification_label: Label
var notification_tween: Tween
var quick_panels: Array[PanelContainer] = []
var quick_labels: Array[Label] = []
var craft_panel: PanelContainer
var craft_inventory: RichTextLabel
var build_panel: PanelContainer
var build_label: Label
var boss_panel: PanelContainer
var boss_bar: ProgressBar
var boss_value_label: Label
var title_overlay: Control
var damage_overlay: ColorRect
var raid_banner: Label
var victory_overlay: Control


func _ready() -> void:
	_build_ui()


func setup(owner_game: Node, owner_player: Node) -> void:
	game = owner_game
	player = owner_player
	player.inventory_changed.connect(_on_inventory_changed)
	player.stats_changed.connect(_on_stats_changed)
	player.selection_changed.connect(_on_selection_changed)
	_on_inventory_changed()
	_on_stats_changed()
	_on_selection_changed(player.selected_slot)


func set_day(day_number: int, night: bool, phase_name: String) -> void:
	day_label.text = "제 %d일  ·  %s\n해안 초원" % [day_number, "밤 · " + phase_name if night else phase_name]
	day_label.modulate = Color(0.68, 0.78, 0.92) if night else INK


func set_objective(step: int, title: String, description: String) -> void:
	objective_step_label.text = "여정  %02d / 08" % (step + 1)
	objective_label.text = "[font_size=22][b]%s[/b][/font_size]\n[color=#a8afa4]%s[/color]" % [title, description]


func set_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = not text.is_empty()


func notify(text: String, color: Color = INK, duration: float = 2.2) -> void:
	if notification_tween != null and notification_tween.is_valid():
		notification_tween.kill()
	notification_label.text = text
	notification_label.modulate = Color(color.r, color.g, color.b, 0.0)
	notification_label.visible = true
	notification_tween = create_tween()
	notification_tween.tween_property(notification_label, "modulate:a", 1.0, 0.16)
	notification_tween.tween_interval(duration)
	notification_tween.tween_property(notification_label, "modulate:a", 0.0, 0.34)


func set_crafting_visible(open: bool) -> void:
	craft_panel.visible = open
	if open:
		_refresh_inventory_text()


func show_build_hint(show: bool) -> void:
	build_panel.visible = show


func update_build_hint(text: String, valid: bool) -> void:
	build_label.text = text
	build_label.modulate = Color(0.62, 0.90, 0.68) if valid else Color(0.98, 0.54, 0.42)


func show_boss(boss_name: String, value: float, maximum: float) -> void:
	boss_panel.visible = true
	boss_panel.tooltip_text = boss_name
	boss_bar.max_value = maximum
	boss_bar.value = value
	boss_value_label.text = "%s    %d / %d" % [boss_name, int(value), int(maximum)]


func update_boss(value: float, maximum: float) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = maxf(0.0, value)
	var boss_name := boss_value_label.text.split("    ")[0]
	boss_value_label.text = "%s    %d / %d" % [boss_name, maxi(0, int(value)), int(maximum)]


func hide_boss() -> void:
	boss_panel.visible = false


func show_title(show: bool) -> void:
	title_overlay.visible = show


func show_raid(text: String) -> void:
	raid_banner.text = "⚔  %s  ⚔" % text
	raid_banner.visible = true
	raid_banner.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(raid_banner, "modulate:a", 1.0, 0.35)
	tween.tween_interval(3.5)
	tween.tween_property(raid_banner, "modulate:a", 0.0, 0.7)
	tween.tween_callback(func() -> void: raid_banner.visible = false)


func show_victory() -> void:
	victory_overlay.visible = true
	victory_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(victory_overlay, "modulate:a", 1.0, 0.8)


func flash_damage() -> void:
	damage_overlay.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(damage_overlay, "modulate:a", 0.46, 0.06)
	tween.tween_property(damage_overlay, "modulate:a", 0.0, 0.48)


func _on_inventory_changed() -> void:
	if player == null:
		return
	for index in range(quick_labels.size()):
		var item: String = player.HOTBAR[index]
		var count: int = player.item_count(item)
		quick_labels[index].text = "%d\n%s\n×%d" % [index + 1, player.ITEM_NAMES[item], count]
		quick_labels[index].modulate = INK if count > 0 else Color(0.43, 0.46, 0.43)
	_refresh_inventory_text()


func _on_stats_changed() -> void:
	if player == null:
		return
	hp_bar.max_value = player.max_hp
	hp_bar.value = player.hp
	stamina_bar.max_value = player.max_stamina
	stamina_bar.value = player.stamina
	hp_label.text = "체력   %d / %d" % [int(ceil(player.hp)), int(player.max_hp)]
	stamina_label.text = "기력   %d / %d" % [int(ceil(player.stamina)), int(player.max_stamina)]
	for index in range(3):
		var label := food_labels[index]
		if index < player.food_slots.size():
			var food: Dictionary = player.food_slots[index]
			var food_id := str(food["id"])
			label.text = "%s\n%d:%02d" % [player.ITEM_NAMES.get(food_id, food_id), int(float(food["time"])) / 60, int(float(food["time"])) % 60]
			label.modulate = food["color"]
		else:
			label.text = "빈 음식\n슬롯"
			label.modulate = Color(0.39, 0.43, 0.40)


func _on_selection_changed(slot: int) -> void:
	for index in range(quick_panels.size()):
		quick_panels[index].add_theme_stylebox_override("panel", _panel_style(Color(0.10, 0.14, 0.13, 0.94), GOLD if index == slot else Color(0.22, 0.28, 0.26), 2 if index == slot else 1, 6))


func _craft_pressed(recipe_id: String) -> void:
	if game != null:
		game.craft_item(recipe_id)


func _start_pressed() -> void:
	if game != null:
		game.start_game()


func _refresh_inventory_text() -> void:
	if player == null or craft_inventory == null:
		return
	var parts: Array[String] = []
	for item in ["branch", "stone", "wood", "mushroom", "berry", "meat", "trophy"]:
		parts.append("[color=#c8cbbf]%s[/color]  [b]%d[/b]" % [player.ITEM_NAMES[item], player.item_count(item)])
	craft_inventory.text = "  ·  ".join(parts)


func _build_ui() -> void:
	root = Control.new()
	root.name = "Interface"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = FONT
	theme.default_font_size = 17
	root.theme = theme
	add_child(root)
	_build_status_panel()
	_build_top_bar()
	_build_objective_panel()
	_build_crosshair()
	_build_quickbar()
	_build_crafting_panel()
	_build_build_panel()
	_build_boss_panel()
	_build_overlays()


func _build_status_panel() -> void:
	var panel := PanelContainer.new()
	panel.name = "SurvivalStatus"
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.position = Vector2(24, -216)
	panel.size = Vector2(358, 192)
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, Color(0.20, 0.27, 0.24), 1, 8))
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	margin.add_child(stack)
	hp_label = _label("체력", 17, FONT_BOLD)
	stack.add_child(hp_label)
	hp_bar = _bar(Color(0.63, 0.16, 0.13), 17)
	stack.add_child(hp_bar)
	stamina_label = _label("기력", 17, FONT_BOLD)
	stack.add_child(stamina_label)
	stamina_bar = _bar(Color(0.69, 0.60, 0.20), 14)
	stack.add_child(stamina_bar)
	var food_row := HBoxContainer.new()
	food_row.add_theme_constant_override("separation", 8)
	stack.add_child(food_row)
	for index in range(3):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(98, 50)
		slot.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.09, 0.085, 0.9), Color(0.24, 0.29, 0.26), 1, 5))
		var food_label := _label("빈 음식\n슬롯", 14, FONT)
		food_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		food_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(food_label)
		food_row.add_child(slot)
		food_labels.append(food_label)


func _build_top_bar() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-165, 18)
	panel.size = Vector2(330, 66)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.06, 0.065, 0.86), Color(0.34, 0.39, 0.35), 1, 8))
	root.add_child(panel)
	day_label = _label("제 1일 · 아침\n해안 초원", 18, FONT_BOLD)
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(day_label)


func _build_objective_panel() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-390, 112)
	panel.size = Vector2(366, 158)
	panel.add_theme_stylebox_override("panel", _panel_style(PANEL, Color(0.36, 0.43, 0.35), 1, 8))
	root.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 13)
	margin.add_theme_constant_override("margin_bottom", 13)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	margin.add_child(stack)
	objective_step_label = _label("여정  01 / 08", 13, FONT_BOLD)
	objective_step_label.modulate = GOLD
	stack.add_child(objective_step_label)
	objective_label = RichTextLabel.new()
	objective_label.bbcode_enabled = true
	objective_label.fit_content = true
	objective_label.scroll_active = false
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	objective_label.custom_minimum_size.y = 95
	stack.add_child(objective_label)


func _build_crosshair() -> void:
	var crosshair := _label("◇", 27, FONT_BOLD)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-18, -20)
	crosshair.size = Vector2(36, 40)
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.modulate = Color(0.87, 0.90, 0.83, 0.9)
	root.add_child(crosshair)
	prompt_label = _label("", 18, FONT_BOLD)
	prompt_label.set_anchors_preset(Control.PRESET_CENTER)
	prompt_label.position = Vector2(-260, 34)
	prompt_label.size = Vector2(520, 36)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	prompt_label.add_theme_constant_override("shadow_offset_x", 2)
	prompt_label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(prompt_label)
	notification_label = _label("", 20, FONT_BOLD)
	notification_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	notification_label.position = Vector2(-390, 106)
	notification_label.size = Vector2(780, 40)
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	notification_label.add_theme_constant_override("shadow_offset_x", 2)
	notification_label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(notification_label)


func _build_quickbar() -> void:
	var row := HBoxContainer.new()
	row.name = "QuickSlots"
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.position = Vector2(-300, -112)
	row.size = Vector2(600, 88)
	row.add_theme_constant_override("separation", 8)
	root.add_child(row)
	for index in range(5):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(112, 84)
		var label := _label("%d\n-\n×0" % (index + 1), 15, FONT_BOLD)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(label)
		row.add_child(slot)
		quick_panels.append(slot)
		quick_labels.append(label)


func _build_crafting_panel() -> void:
	craft_panel = PanelContainer.new()
	craft_panel.name = "CraftingPanel"
	craft_panel.set_anchors_preset(Control.PRESET_CENTER)
	craft_panel.position = Vector2(-340, -265)
	craft_panel.size = Vector2(680, 530)
	craft_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.052, 0.05, 0.97), Color(0.48, 0.40, 0.25), 2, 10))
	craft_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	craft_panel.visible = false
	root.add_child(craft_panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 24)
	craft_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 14)
	margin.add_child(stack)
	var title := _label("제작 · 손으로 만들기", 29, FONT_BOLD)
	title.modulate = Color(0.89, 0.78, 0.54)
	stack.add_child(title)
	var help := _label("[Tab / C] 닫기   ·   음식은 3~4번 퀵슬롯에서 먹습니다", 15, FONT)
	help.modulate = MUTED
	stack.add_child(help)
	stack.add_child(HSeparator.new())
	craft_inventory = RichTextLabel.new()
	craft_inventory.bbcode_enabled = true
	craft_inventory.fit_content = true
	craft_inventory.custom_minimum_size.y = 55
	craft_inventory.scroll_active = false
	stack.add_child(craft_inventory)
	var recipes := [
		{"id": "stone_axe", "title": "돌도끼", "cost": "가지 3 · 돌 2", "description": "나무와 바위를 채집하고 적과 싸우는 첫 도구"},
		{"id": "hammer", "title": "망치", "cost": "목재 3 · 돌 1", "description": "모닥불·작업대·바닥·벽을 배치하는 건축 도구"},
	]
	for recipe: Dictionary in recipes:
		var card := Button.new()
		card.custom_minimum_size.y = 104
		card.text = "%s\n%s\n%s" % [recipe["title"], recipe["description"], recipe["cost"]]
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.add_theme_font_override("font", FONT_BOLD)
		card.add_theme_font_size_override("font_size", 17)
		card.add_theme_stylebox_override("normal", _panel_style(Color(0.075, 0.095, 0.085, 0.95), Color(0.23, 0.30, 0.25), 1, 6))
		card.add_theme_stylebox_override("hover", _panel_style(Color(0.12, 0.15, 0.12, 0.98), GOLD, 1, 6))
		card.add_theme_stylebox_override("pressed", _panel_style(Color(0.16, 0.18, 0.12, 0.98), GOLD, 2, 6))
		card.pressed.connect(_craft_pressed.bind(str(recipe["id"])))
		stack.add_child(card)


func _build_build_panel() -> void:
	build_panel = PanelContainer.new()
	build_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	build_panel.position = Vector2(-500, -220)
	build_panel.size = Vector2(476, 144)
	build_panel.add_theme_stylebox_override("panel", _panel_style(PANEL, Color(0.36, 0.45, 0.37), 1, 8))
	build_panel.visible = false
	root.add_child(build_panel)
	build_label = _label("", 16, FONT_BOLD)
	build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	build_panel.add_child(build_label)


func _build_boss_panel() -> void:
	boss_panel = PanelContainer.new()
	boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_panel.position = Vector2(-390, 96)
	boss_panel.size = Vector2(780, 72)
	boss_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.035, 0.035, 0.94), Color(0.58, 0.22, 0.17), 2, 7))
	boss_panel.visible = false
	root.add_child(boss_panel)
	boss_bar = _bar(Color(0.58, 0.12, 0.10), 32)
	boss_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)
	boss_panel.add_child(boss_bar)
	boss_value_label = _label("숲 수호자", 18, FONT_BOLD)
	boss_value_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	boss_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_panel.add_child(boss_value_label)


func _build_overlays() -> void:
	damage_overlay = ColorRect.new()
	damage_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_overlay.color = Color(0.55, 0.02, 0.01, 0.52)
	damage_overlay.modulate.a = 0.0
	damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(damage_overlay)
	raid_banner = _label("", 31, FONT_BOLD)
	raid_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	raid_banner.position = Vector2(-450, 190)
	raid_banner.size = Vector2(900, 60)
	raid_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raid_banner.modulate = Color(0.92, 0.40, 0.28)
	raid_banner.visible = false
	root.add_child(raid_banner)
	_build_title_overlay()
	_build_victory_overlay()


func _build_title_overlay() -> void:
	title_overlay = Control.new()
	title_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(title_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.018, 0.027, 0.029, 0.82)
	title_overlay.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-330, -230)
	panel.size = Vector2(660, 460)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.052, 0.05, 0.97), Color(0.49, 0.40, 0.25), 2, 12))
	title_overlay.add_child(panel)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 18)
	panel.add_child(stack)
	var eyebrow := _label("해안 숲 생존 기록", 17, FONT_BOLD)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.modulate = GOLD
	stack.add_child(eyebrow)
	var title := _label("북해의 잿불", 52, FONT_BOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var subtitle := _label("안개 낀 해안에서 채집하고, 짓고, 밤을 버티고,\n뿔 달린 숲 수호자를 깨우십시오.", 20, FONT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(0.70, 0.74, 0.69)
	stack.add_child(subtitle)
	var start := Button.new()
	start.text = "해안에 발을 딛기"
	start.custom_minimum_size = Vector2(300, 62)
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.add_theme_font_override("font", FONT_BOLD)
	start.add_theme_font_size_override("font_size", 22)
	start.add_theme_stylebox_override("normal", _panel_style(Color(0.17, 0.23, 0.18, 1), Color(0.48, 0.55, 0.38), 2, 7))
	start.add_theme_stylebox_override("hover", _panel_style(Color(0.24, 0.31, 0.22, 1), GOLD, 2, 7))
	start.pressed.connect(_start_pressed)
	stack.add_child(start)
	var controls := _label("WASD 이동 · Shift 질주 · Space 점프 · Ctrl/Alt 회피\nE 상호작용 · 좌클릭 공격 · 우클릭 방어 · Tab/C 제작", 15, FONT)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.modulate = MUTED
	stack.add_child(controls)


func _build_victory_overlay() -> void:
	victory_overlay = Control.new()
	victory_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	victory_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	victory_overlay.visible = false
	root.add_child(victory_overlay)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.07, 0.055, 0.74)
	victory_overlay.add_child(shade)
	var text := _label("숲이 숨을 고릅니다\n\n에이크비드가 쓰러졌습니다\n해안의 첫 밤을 정복했습니다", 48, FONT_BOLD)
	text.set_anchors_preset(Control.PRESET_CENTER)
	text.position = Vector2(-470, -130)
	text.size = Vector2(940, 260)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.modulate = Color(0.83, 0.86, 0.66)
	victory_overlay.add_child(text)


func _label(text: String, size: int, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", INK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _bar(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = height
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _panel_style(Color(0.018, 0.025, 0.024, 0.95), Color(0.16, 0.19, 0.18), 1, 4))
	bar.add_theme_stylebox_override("fill", _panel_style(color, color.lightened(0.12), 1, 4))
	return bar


func _panel_style(color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
