class_name CraftUI
extends PanelContainer
## 제작 창: 제작대별 레시피 목록 · 재료 확인 · 제작 · 강화.

var player: Player
var station := ""
var station_level := 1
var build_system: BuildSystem

var _list: VBoxContainer
var _detail: VBoxContainer
var _title: Label
var _selected := ""
var _selected_upgrade := -1     # 인벤토리 인덱스(강화 대상)
var _tabs: HBoxContainer
var _mode := "craft"            # craft | upgrade

func _ready() -> void:
	name = "craft_ui"
	custom_minimum_size = Vector2(880, 600)
	add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.08, 0.07, 0.06, 0.97), UITheme.GOLD_DIM, 6, 3))
	_build()

func bind(p: Player, bs: BuildSystem) -> void:
	player = p
	build_system = bs
	p.inventory.changed.connect(_refresh_if_visible)

func _build() -> void:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	_title = UITheme.title(tr("UI_CRAFTING"), 26)
	root.add_child(_title)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	root.add_child(_tabs)
	var b1 := UITheme.button(tr("UI_TAB_CRAFT"))
	b1.pressed.connect(func(): _mode = "craft"; _selected = ""; refresh())
	_tabs.add_child(b1)
	var b2 := UITheme.button(tr("UI_TAB_UPGRADE"))
	b2.pressed.connect(func(): _mode = "upgrade"; _selected = ""; refresh())
	_tabs.add_child(b2)

	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 16)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(split)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(430, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)

	var dpanel := PanelContainer.new()
	dpanel.add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.12, 0.10, 0.08, 0.9)))
	dpanel.custom_minimum_size = Vector2(390, 0)
	split.add_child(dpanel)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 8)
	dpanel.add_child(_detail)

func open(st: String, p: Player) -> void:
	station = st
	player = p
	_mode = "craft"
	_selected = ""
	station_level = 1
	if build_system != null and st != "":
		station_level = maxi(1, build_system.station_level(st, p.global_position))
	visible = true
	refresh()

func _refresh_if_visible() -> void:
	if visible:
		refresh()

func refresh() -> void:
	if player == null:
		return
	var st_name := tr("UI_HANDCRAFT") if station == "" else tr("STATION_" + station.to_upper())
	_title.text = "%s  ·  Lv.%d" % [st_name, station_level]
	for c in _list.get_children():
		c.queue_free()
	if _mode == "craft":
		_fill_craft()
	else:
		_fill_upgrade()
	_show_detail()

func _fill_craft() -> void:
	var recipes := RecipeDB.recipes_for_station(station, station_level)
	# 만들 수 있는 것 우선 정렬
	recipes.sort_custom(func(a, b):
		var ca: bool = player.inventory.has_materials(a["mats"])
		var cb: bool = player.inventory.has_materials(b["mats"])
		if ca != cb:
			return ca
		return ItemDB.name_of(a["out"]) < ItemDB.name_of(b["out"]))
	if recipes.is_empty():
		_list.add_child(UITheme.label(tr("UI_NO_RECIPES"), 16, UITheme.TEXT_DIM))
		return
	for r in recipes:
		_list.add_child(_recipe_row(str(r["out"]), r["mats"],
			player.inventory.has_materials(r["mats"]), int(r.get("amount", 1))))

func _fill_upgrade() -> void:
	var any := false
	for i in range(player.inventory.size()):
		var s: Dictionary = player.inventory.get_slot(i)
		if s.is_empty():
			continue
		var id := str(s["id"])
		var maxq := ItemDB.max_quality(id)
		var q := int(s.get("quality", 1))
		if maxq <= 1 or q >= maxq:
			continue
		var rec := RecipeDB.recipe_of(id)
		if rec.is_empty() or str(rec.get("station", "")) != station:
			continue
		if int(rec.get("level", 1)) > station_level:
			continue
		var cost := ItemDB.upgrade_cost(id, q + 1)
		if cost.is_empty():
			continue
		any = true
		var row := _recipe_row(id, cost, player.inventory.has_materials(cost), 1,
			"%s ★%d → ★%d" % [ItemDB.name_of(id), q, q + 1])
		row.set_meta("upgrade_idx", i)
		_list.add_child(row)
	if not any:
		_list.add_child(UITheme.label(tr("UI_NO_UPGRADES"), 16, UITheme.TEXT_DIM))

func _recipe_row(out_id: String, mats: Dictionary, ok: bool, amount: int,
		override_name: String = "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(410, 52)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = false
	b.add_theme_color_override("font_color", UITheme.TEXT if ok else Color(0.55, 0.5, 0.45))

	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 10)
	b.add_child(h)

	var tex := TextureRect.new()
	tex.texture = ItemDB.icon(out_id)
	tex.custom_minimum_size = Vector2(40, 40)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(tex)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var nm := override_name if override_name != "" else ItemDB.name_of(out_id)
	if amount > 1:
		nm += " x%d" % amount
	var l1 := UITheme.label(nm, 17, UITheme.TEXT if ok else Color(0.6, 0.56, 0.5))
	l1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l1)
	var parts: Array[String] = []
	for id in mats:
		var have := player.inventory.count(id)
		var need := int(mats[id])
		parts.append("%s %d/%d" % [ItemDB.name_of(id), have, need])
	var l2 := UITheme.label(", ".join(parts), 13,
		UITheme.TEXT_DIM if ok else Color(0.72, 0.36, 0.30))
	l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l2)

	b.set_meta("out", out_id)
	b.pressed.connect(func():
		_selected = out_id
		_selected_upgrade = int(b.get_meta("upgrade_idx", -1))
		_show_detail()
	)
	return b

func _show_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	if _selected == "":
		_detail.add_child(UITheme.label(tr("UI_SELECT_RECIPE"), 16, UITheme.TEXT_DIM))
		return
	var info := RichTextLabel.new()
	info.bbcode_enabled = true
	info.custom_minimum_size = Vector2(360, 380)
	info.add_theme_font_override("normal_font", UITheme.body_font())
	info.add_theme_font_size_override("normal_font_size", 15)
	var q := 1
	if _mode == "upgrade" and _selected_upgrade >= 0:
		q = int(player.inventory.get_slot(_selected_upgrade).get("quality", 1)) + 1
	info.text = InventoryUI.item_tooltip(_selected, q)
	_detail.add_child(info)

	var btn := UITheme.button(tr("UI_CRAFT") if _mode == "craft" else tr("UI_UPGRADE"), 19)
	btn.custom_minimum_size = Vector2(0, 46)
	btn.pressed.connect(_do_craft)
	_detail.add_child(btn)

func _do_craft() -> void:
	if _selected == "":
		return
	if _mode == "upgrade":
		_do_upgrade()
		return
	var rec := RecipeDB.recipe_of(_selected)
	if rec.is_empty():
		return
	if not player.inventory.has_materials(rec["mats"]):
		Sfx.play("error", -8.0)
		GameState.msg(tr("MSG_NOT_ENOUGH"))
		return
	# 결과를 넣을 자리가 있는지 확인
	player.inventory.consume(rec["mats"])
	var left := player.inventory.add_item(_selected, int(rec.get("amount", 1)))
	if left > 0:
		ItemDrop.spawn(get_tree().current_scene,
			player.global_position + Vector3(0, 1, 0), _selected, left)
	GameState.stats["crafted"] = int(GameState.stats["crafted"]) + 1
	Sfx.play("craft", -6.0)
	GameState.msg(tr("MSG_CRAFTED") % ItemDB.name_of(_selected))
	refresh()

func _do_upgrade() -> void:
	if _selected_upgrade < 0:
		return
	var s: Dictionary = player.inventory.get_slot(_selected_upgrade)
	if s.is_empty() or str(s["id"]) != _selected:
		refresh()
		return
	var q := int(s.get("quality", 1))
	var cost := ItemDB.upgrade_cost(_selected, q + 1)
	if not player.inventory.has_materials(cost):
		Sfx.play("error", -8.0)
		return
	player.inventory.consume(cost)
	# consume 후에도 같은 칸인지 다시 확인
	var s2: Dictionary = player.inventory.get_slot(_selected_upgrade)
	if s2.is_empty() or str(s2["id"]) != _selected:
		# 재료 소모 과정에서 위치가 바뀌었으면 같은 아이템을 다시 찾는다
		for i in range(player.inventory.size()):
			var t: Dictionary = player.inventory.get_slot(i)
			if not t.is_empty() and str(t["id"]) == _selected \
					and int(t.get("quality", 1)) == q:
				_selected_upgrade = i
				s2 = t
				break
	if s2.is_empty():
		return
	s2["quality"] = q + 1
	player.inventory.changed.emit()
	player.inventory.equipment_changed.emit()
	Sfx.play("craft", -4.0, 0.85)
	GameState.msg(tr("MSG_UPGRADED") % [ItemDB.name_of(_selected), q + 1])
	refresh()
