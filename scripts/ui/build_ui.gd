class_name BuildUI
extends PanelContainer
## 건축 조각 선택 패널. 망치를 들면 자동으로 나타난다.

const CATS := [
	["UI_CAT_MISC", 0], ["UI_CAT_WOOD", 1], ["UI_CAT_STONE", 2],
	["UI_CAT_FURNITURE", 3], ["UI_CAT_STATIONS", 4], ["UI_CAT_UPGRADES", 5],
	["UI_CAT_FARMING", 6],
]

var build_system: BuildSystem
var player: Player
var _cat := 1
var _grid: GridContainer
var _tabs: HBoxContainer
var _info: Label

func _ready() -> void:
	name = "build_ui"
	custom_minimum_size = Vector2(880, 190)
	visible = false
	add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.08, 0.07, 0.06, 0.93), UITheme.GOLD_DIM, 5, 2))
	_build()

func bind(p: Player, bs: BuildSystem) -> void:
	player = p
	build_system = bs
	bs.build_mode_changed.connect(func(a): visible = a; if a: refresh())
	p.inventory.changed.connect(func(): if visible: refresh())

func _build() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 4)
	v.add_child(_tabs)
	for i in range(CATS.size()):
		var c: Array = CATS[i]
		var b := UITheme.button(tr(str(c[0])), 14)
		b.custom_minimum_size = Vector2(112, 30)
		var idx: int = int(c[1])
		b.pressed.connect(func():
			_cat = idx
			Sfx.play("click", -20.0)
			refresh())
		_tabs.add_child(b)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(860, 108)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 32
	_grid.add_theme_constant_override("h_separation", 5)
	scroll.add_child(_grid)

	_info = UITheme.label("", 14, UITheme.TEXT_DIM)
	v.add_child(_info)

func refresh() -> void:
	if player == null or build_system == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	for id in RecipeDB.pieces_in_cat(_cat):
		var d: Dictionary = RecipeDB.piece(id)
		var ok: bool = player.inventory.has_materials(d.get("mats", {}))
		var b := Button.new()
		b.custom_minimum_size = Vector2(94, 94)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = _tooltip(id, d)
		var sb := UITheme.slot_box(false, build_system.current_id == id)
		if not ok:
			sb.bg_color = Color(0.12, 0.10, 0.09, 0.9)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", UITheme.slot_box(true,
			build_system.current_id == id))
		b.pressed.connect(func():
			build_system.select(id)
			Sfx.play("click", -20.0)
			refresh())
		_grid.add_child(b)

		var vv := VBoxContainer.new()
		vv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vv.alignment = BoxContainer.ALIGNMENT_CENTER
		b.add_child(vv)
		var l := UITheme.label(tr(str(d.get("n", id))), 13,
			UITheme.TEXT if ok else Color(0.6, 0.55, 0.5))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vv.add_child(l)
		var parts: Array[String] = []
		for mid in d.get("mats", {}):
			parts.append("%s %d" % [ItemDB.name_of(mid), int(d["mats"][mid])])
		var l2 := UITheme.label("\n".join(parts), 11,
			UITheme.TEXT_DIM if ok else Color(0.72, 0.36, 0.30))
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vv.add_child(l2)

	var cur := RecipeDB.piece(build_system.current_id)
	_info.text = tr("UI_BUILD_HINT") % tr(str(cur.get("n", build_system.current_id)))

func _tooltip(id: String, d: Dictionary) -> String:
	var parts: Array[String] = [tr(str(d.get("n", id)))]
	for mid in d.get("mats", {}):
		parts.append("· %s x%d" % [ItemDB.name_of(mid), int(d["mats"][mid])])
	if bool(d.get("needs_workbench", true)):
		parts.append(tr("UI_NEEDS_WORKBENCH"))
	return "\n".join(parts)
