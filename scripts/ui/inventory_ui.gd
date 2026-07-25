class_name InventoryUI
extends PanelContainer
## 인벤토리 창: 격자 · 장비 · 상자 연동.
## 드래그 대신 "집기 → 놓기" 방식이라 조작이 단순하고 오작동이 없다.

var player: Player
var container_inv: Inventory = null
var container_title := ""

var _grid: GridContainer
var _cgrid: GridContainer
var _cbox: VBoxContainer
var _held: Dictionary = {}         # 집어든 아이템
var _held_from := -1
var _held_from_container := false
var _held_icon: TextureRect
var _info: RichTextLabel
var _weight_label: Label
var _armor_label: Label
var _equip_box: HBoxContainer

func _ready() -> void:
	name = "inventory_ui"
	custom_minimum_size = Vector2(1080, 620)
	add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.08, 0.07, 0.06, 0.97), UITheme.GOLD_DIM, 6, 3))
	_build()

func bind(p: Player) -> void:
	player = p
	p.inventory.changed.connect(refresh)
	p.inventory.equipment_changed.connect(refresh)
	refresh()

func _build() -> void:
	var root := HBoxContainer.new()
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	# ── 왼쪽: 플레이어 인벤토리 ──
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	root.add_child(left)

	left.add_child(UITheme.title(tr("UI_INVENTORY"), 26))

	_equip_box = HBoxContainer.new()
	_equip_box.add_theme_constant_override("separation", 6)
	left.add_child(_equip_box)

	_grid = GridContainer.new()
	_grid.columns = Const.INV_COLS
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	left.add_child(_grid)
	for i in range(Const.INV_COLS * Const.INV_ROWS):
		_grid.add_child(_make_slot(i, false))

	var info_row := HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 20)
	left.add_child(info_row)
	_weight_label = UITheme.label("", 15, UITheme.TEXT_DIM)
	info_row.add_child(_weight_label)
	_armor_label = UITheme.label("", 15, UITheme.TEXT_DIM)
	info_row.add_child(_armor_label)

	# ── 오른쪽: 아이템 정보 / 상자 ──
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.custom_minimum_size = Vector2(340, 0)
	root.add_child(right)

	_cbox = VBoxContainer.new()
	_cbox.add_theme_constant_override("separation", 8)
	_cbox.visible = false
	right.add_child(_cbox)
	_cbox.add_child(UITheme.title(tr("UI_CHEST"), 22))
	_cgrid = GridContainer.new()
	_cgrid.columns = 5
	_cgrid.add_theme_constant_override("h_separation", 6)
	_cgrid.add_theme_constant_override("v_separation", 6)
	_cbox.add_child(_cgrid)

	var infopanel := PanelContainer.new()
	infopanel.add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.12, 0.10, 0.08, 0.9)))
	infopanel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(infopanel)
	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.fit_content = false
	_info.scroll_active = true
	_info.custom_minimum_size = Vector2(320, 220)
	_info.add_theme_font_override("normal_font", UITheme.body_font())
	_info.add_theme_font_size_override("normal_font_size", 15)
	infopanel.add_child(_info)

	var hint := UITheme.label(tr("UI_INV_HINT"), 13, UITheme.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(320, 0)
	right.add_child(hint)

	# 집어든 아이템을 커서에 표시
	_held_icon = TextureRect.new()
	_held_icon.custom_minimum_size = Vector2(46, 46)
	_held_icon.size = Vector2(46, 46)
	_held_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_held_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_held_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_icon.visible = false
	_held_icon.top_level = true
	add_child(_held_icon)

func _make_slot(idx: int, is_container: bool) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(60, 60)
	p.add_theme_stylebox_override("panel", UITheme.slot_box())
	p.set_meta("idx", idx)
	p.set_meta("container", is_container)

	var tex := TextureRect.new()
	tex.name = "icon"
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.offset_left = 5; tex.offset_top = 5
	tex.offset_right = -5; tex.offset_bottom = -5
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(tex)

	var amt := UITheme.label("", 14)
	amt.name = "amount"
	amt.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	amt.position = Vector2(-28, -22)
	amt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(amt)

	var q := UITheme.label("", 12, UITheme.GOLD)
	q.name = "quality"
	q.position = Vector2(5, 2)
	q.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(q)

	p.gui_input.connect(_on_slot_input.bind(idx, is_container))
	p.mouse_entered.connect(_on_slot_hover.bind(idx, is_container))
	return p

# ═══════════════════════════════════════════════ 갱신
func refresh() -> void:
	if player == null:
		return
	for i in range(_grid.get_child_count()):
		_paint(_grid.get_child(i) as Panel, player.inventory, i)
	if container_inv != null:
		for i in range(_cgrid.get_child_count()):
			_paint(_cgrid.get_child(i) as Panel, container_inv, i)
	_weight_label.text = tr("UI_WEIGHT") % [int(player.inventory.weight()),
		int(player.inventory.max_weight)]
	_weight_label.add_theme_color_override("font_color",
		UITheme.RED if player.inventory.is_overweight() else UITheme.TEXT_DIM)
	_armor_label.text = tr("UI_ARMOR") % int(player.inventory.total_armor())
	_refresh_equip()

func _paint(p: Panel, inv: Inventory, i: int) -> void:
	if p == null:
		return
	var s: Dictionary = inv.get_slot(i)
	var icon := p.get_node("icon") as TextureRect
	var amt := p.get_node("amount") as Label
	var q := p.get_node("quality") as Label
	if s.is_empty():
		icon.texture = null
		amt.text = ""
		q.text = ""
		p.add_theme_stylebox_override("panel", UITheme.slot_box())
	else:
		icon.texture = ItemDB.icon(str(s["id"]))
		amt.text = str(int(s["amount"])) if int(s["amount"]) > 1 else ""
		var qq := int(s.get("quality", 1))
		q.text = ("★" + str(qq)) if qq > 1 else ""
		var equipped: bool = inv == player.inventory and player.inventory.is_equipped(i)
		p.add_theme_stylebox_override("panel", UITheme.slot_box(false, equipped))

func _refresh_equip() -> void:
	for c in _equip_box.get_children():
		c.queue_free()
	var slots := [Inventory.SLOT_HEAD, Inventory.SLOT_CHEST, Inventory.SLOT_LEGS,
		Inventory.SLOT_CAPE, Inventory.SLOT_RIGHT, Inventory.SLOT_LEFT,
		Inventory.SLOT_AMMO]
	for s in slots:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		_equip_box.add_child(v)
		var lbl := UITheme.label(tr("SLOT_" + s.to_upper()), 12, UITheme.TEXT_DIM)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.custom_minimum_size = Vector2(56, 0)
		v.add_child(lbl)
		var p := Panel.new()
		p.custom_minimum_size = Vector2(56, 56)
		var id := player.inventory.equipped_id(s)
		p.add_theme_stylebox_override("panel", UITheme.slot_box(false, id != ""))
		v.add_child(p)
		if id != "":
			var tex := TextureRect.new()
			tex.texture = ItemDB.icon(id)
			tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			tex.offset_left = 4; tex.offset_top = 4
			tex.offset_right = -4; tex.offset_bottom = -4
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p.add_child(tex)

# ═══════════════════════════════════════════════ 입력
func _on_slot_input(event: InputEvent, idx: int, is_container: bool) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	var inv := container_inv if is_container else player.inventory
	if inv == null:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if Input.is_key_pressed(KEY_SHIFT) and container_inv != null:
			_quick_move(inv, idx, is_container)
			return
		_click_move(inv, idx, is_container)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if _held.is_empty() and not is_container:
			_use_slot(idx)

func _click_move(inv: Inventory, idx: int, is_container: bool) -> void:
	if _held.is_empty():
		var s: Dictionary = inv.get_slot(idx)
		if s.is_empty():
			return
		_held = inv.remove_at(idx)
		_held_from = idx
		_held_from_container = is_container
		_held_icon.texture = ItemDB.icon(str(_held["id"]))
		_held_icon.visible = true
		Sfx.play("click", -20.0)
	else:
		var target: Dictionary = inv.get_slot(idx)
		if target.is_empty():
			inv.slots[idx] = _held
			inv.changed.emit()
		elif target["id"] == _held["id"] \
				and int(target.get("quality", 1)) == int(_held.get("quality", 1)):
			var stack := ItemDB.stack_of(str(_held["id"]))
			var room: int = stack - int(target["amount"])
			var mv: int = mini(room, int(_held["amount"]))
			target["amount"] = int(target["amount"]) + mv
			_held["amount"] = int(_held["amount"]) - mv
			inv.changed.emit()
			if int(_held["amount"]) > 0:
				refresh()
				return
		else:
			# 교환
			var tmp: Dictionary = inv.get_slot(idx).duplicate()
			inv.slots[idx] = _held
			_held = tmp
			inv.changed.emit()
			refresh()
			return
		_held = {}
		_held_icon.visible = false
		Sfx.play("click", -20.0)
	refresh()

func _quick_move(inv: Inventory, idx: int, is_container: bool) -> void:
	var s: Dictionary = inv.get_slot(idx)
	if s.is_empty():
		return
	var dest := player.inventory if is_container else container_inv
	if dest == null:
		return
	var left := dest.add_item(str(s["id"]), int(s["amount"]), int(s.get("quality", 1)))
	var moved := int(s["amount"]) - left
	if moved > 0:
		inv.remove_at(idx, moved)
		Sfx.play("click", -18.0)
	refresh()

func _use_slot(idx: int) -> void:
	var s: Dictionary = player.inventory.get_slot(idx)
	if s.is_empty():
		return
	var id := str(s["id"])
	var it := ItemDB.get_item(id)
	if it.has("hp") or it.has("potion"):
		var hud = get_parent().get_node_or_null("hud")
		if hud != null:
			hud._consume(idx, id, it)
	else:
		player.inventory.toggle_equip(idx)
		Sfx.play("click", -16.0)
	refresh()

func _on_slot_hover(idx: int, is_container: bool) -> void:
	var inv := container_inv if is_container else player.inventory
	if inv == null:
		return
	var s: Dictionary = inv.get_slot(idx)
	if s.is_empty():
		_info.text = ""
		return
	_info.text = item_tooltip(str(s["id"]), int(s.get("quality", 1)))

static func _t(k: String) -> String:
	return TranslationServer.translate(k)

static func item_tooltip(id: String, q: int = 1) -> String:
	var it := ItemDB.get_item(id)
	if it.is_empty():
		return id
	var lines: Array[String] = []
	lines.append("[b][color=#cba861]%s[/color][/b]" % ItemDB.name_of(id))
	var desc := ItemDB.desc_of(id)
	if desc != "" and not desc.begins_with("ITEM_"):
		lines.append("[i][color=#9a958a]%s[/color][/i]" % desc)
	lines.append("")
	if it.has("dmg"):
		var d := ItemDB.total_damage(id, q)
		for k in d:
			lines.append("%s: [color=#e0d5b0]%d[/color]"
				% [_t(Const.DMG_KEY.get(k, "?")), int(round(float(d[k])))])
		if it.has("spd"):
			lines.append(_t("UI_ATTACK_SPEED") % float(it["spd"]))
		if it.has("stam"):
			lines.append(_t("UI_STAMINA_COST") % int(it["stam"]))
	if it.has("block"):
		lines.append(_t("UI_BLOCK_POWER") % int(ItemDB.block_of(id, q)))
		lines.append(_t("UI_PARRY") % float(it.get("parry", 1.0)))
	if it.has("ar"):
		lines.append(_t("UI_ARMOR_VALUE") % int(ItemDB.armor_of(id, q)))
	if it.has("hp"):
		lines.append(_t("UI_FOOD_HP") % int(it["hp"]))
		lines.append(_t("UI_FOOD_SP") % int(it["sp"]))
		lines.append(_t("UI_FOOD_TIME") % int(float(it["dur"]) / 60.0))
		lines.append(_t("UI_FOOD_REGEN") % float(it["reg"]))
	if it.has("mine_tier"):
		lines.append(_t("UI_TOOL_TIER") % int(it["mine_tier"]))
	if it.has("tier") and int(it.get("tier", 0)) > 0:
		lines.append(_t("UI_CHOP_TIER") % int(it["tier"]))
	lines.append("")
	lines.append("[color=#8a857a]%s[/color]" % (_t("UI_WEIGHT_ONE") % ItemDB.weight_of(id)))
	if not ItemDB.is_teleportable(id):
		lines.append("[color=#c07050]%s[/color]" % _t("UI_NO_TELEPORT"))
	if ItemDB.max_quality(id) > 1:
		lines.append("[color=#8a857a]%s[/color]" % (_t("UI_QUALITY")
			% [q, ItemDB.max_quality(id)]))
	return "\n".join(lines)

func _process(_delta: float) -> void:
	if _held_icon.visible:
		_held_icon.global_position = get_global_mouse_position() - Vector2(23, 23)

## 창을 닫을 때 집어든 아이템을 되돌린다
func drop_held() -> void:
	if _held.is_empty():
		return
	var inv := container_inv if _held_from_container else player.inventory
	if inv != null:
		var left := inv.add_item(str(_held["id"]), int(_held["amount"]),
			int(_held.get("quality", 1)))
		if left > 0 and player != null:
			ItemDrop.spawn(get_tree().current_scene,
				player.global_position + Vector3(0, 1, 0), str(_held["id"]), left)
	_held = {}
	_held_icon.visible = false

func open_container(inv: Inventory, title: String) -> void:
	container_inv = inv
	container_title = title
	_cbox.visible = true
	(_cbox.get_child(0) as Label).text = title
	for c in _cgrid.get_children():
		c.queue_free()
	_cgrid.columns = inv.cols
	for i in range(inv.size()):
		_cgrid.add_child(_make_slot(i, true))
	inv.changed.connect(refresh)
	call_deferred("refresh")

func close_container() -> void:
	if container_inv != null and container_inv.changed.is_connected(refresh):
		container_inv.changed.disconnect(refresh)
	container_inv = null
	_cbox.visible = false
