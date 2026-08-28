class_name BuildUI
extends PanelContainer
## 건축 조각 선택 패널. 망치를 들면 자동으로 나타난다.

signal palette_closed
signal piece_chosen
signal palette_focus_requested



const CATS := [
	["UI_CAT_MISC", 0], ["UI_CAT_WOOD", 1], ["UI_CAT_STONE", 2],
	["UI_CAT_FURNITURE", 3], ["UI_CAT_STATIONS", 4], ["UI_CAT_UPGRADES", 5],
	["UI_CAT_FARMING", 6],
]
const MAX_WIDTH := 880.0
const MAX_HEIGHT := 206.0


var build_system: BuildSystem
var player: Player
var _cat := 1
var _grid: GridContainer
var _tabs: HBoxContainer
var _info: Label
var _status: Label
var _scroll: ScrollContainer
var _root_box: VBoxContainer
var _palette_open := false
var _first_piece_button: Button
var _current_piece_button: Button



func _ready() -> void:
	name = "build_ui"
	custom_minimum_size = Vector2.ZERO
	visible = false
	focus_mode = Control.FOCUS_NONE
	add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.08, 0.07, 0.06, 0.93), UITheme.GOLD_DIM, 5, 2))
	_build()
	get_viewport().size_changed.connect(_apply_responsive_layout)
	_apply_responsive_layout()

func bind(p: Player, bs: BuildSystem) -> void:
	player = p
	build_system = bs
	bs.build_mode_changed.connect(_on_build_mode_changed)
	bs.piece_selected.connect(func(_id): refresh())
	bs.placement_resolved.connect(_on_placement_result)
	p.inventory.changed.connect(func(): if visible: refresh())
	set_process_unhandled_input(true)


func _build() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	_root_box = v

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 4)
	v.add_child(_tabs)
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(CATS.size()):
		var c: Array = CATS[i]
		var b := UITheme.button(tr(str(c[0])), 14)
		b.custom_minimum_size = Vector2(96, 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var idx: int = int(c[1])
		b.pressed.connect(_select_category.bind(idx, b))
		_tabs.add_child(b)


	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2.ZERO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	v.add_child(scroll)
	_scroll = scroll
	_grid = GridContainer.new()
	_grid.columns = 32
	_grid.add_theme_constant_override("h_separation", 5)
	scroll.add_child(_grid)

	_info = UITheme.wrap_label("", 14, UITheme.TEXT_DIM)
	_info.max_lines_visible = 2
	v.add_child(_info)
	_status = UITheme.wrap_label("", 14, UITheme.TEXT_DIM)
	_status.max_lines_visible = 2
	v.add_child(_status)

func open_palette() -> void:
	if build_system == null or not build_system.active:
		return
	_palette_open = true
	visible = true
	refresh()
	palette_focus_requested.emit()

func close_palette() -> void:
	_palette_open = false
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null and (owner == self or is_ancestor_of(owner)):
		owner.release_focus()
	visible = false

func is_palette_open() -> bool:
	return _palette_open

func focus_target() -> Control:
	if _current_piece_button != null and is_instance_valid(_current_piece_button):
		return _current_piece_button
	if _first_piece_button != null and is_instance_valid(_first_piece_button):
		return _first_piece_button
	return null

func _gui_input(event: InputEvent) -> void:
	if not _palette_open or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		close_palette()
		palette_closed.emit()
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		var owner := get_viewport().gui_get_focus_owner()
		if owner is Button:
			(owner as Button).pressed.emit()
		accept_event()



func _select_category(category: int, _button: Button) -> void:
	_cat = category
	Sfx.play("click", -20.0)
	refresh()
	palette_focus_requested.emit()

func refresh() -> void:
	if player == null or build_system == null:
		return
	if Net.is_online and not Net.is_host:
		_show_remote_limitation()
	_first_piece_button = null
	_current_piece_button = null

	for c in _grid.get_children():
		c.queue_free()
	var preview: Dictionary = Net.unsupported_build_result() if Net.is_online and not Net.is_host \
		else Net.build_result(_valid_preview(), Net.BUILD_STATUS_ACCEPTED if _valid_preview() \
		else Net.BUILD_STATUS_REJECTED, "" if _valid_preview() else "INVALID_PLACEMENT")
	if str(preview.get("reason", "")) == "UNSUPPORTED_IN_RT1":
		_show_remote_limitation()
	for id in RecipeDB.pieces_in_cat(_cat):
		var d: Dictionary = RecipeDB.piece(id)
		var ok: bool = player.inventory.has_materials(d.get("mats", {}))
		var b := Button.new()
		b.custom_minimum_size = Vector2(94, 94)
		b.focus_mode = Control.FOCUS_ALL
		b.tooltip_text = _tooltip(id, d)
		var sb := UITheme.slot_box(false, build_system.current_id == id)
		if not ok:
			sb.bg_color = Color(0.12, 0.10, 0.09, 0.9)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", UITheme.slot_box(true,
			build_system.current_id == id))
		b.add_theme_stylebox_override("focus", UITheme.slot_box(true,
			build_system.current_id == id))
		b.pressed.connect(_select_piece.bind(id, b))
		_grid.add_child(b)
		if _first_piece_button == null:
			_first_piece_button = b
		if build_system.current_id == id:
			_current_piece_button = b


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
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vv.add_child(l)
		var parts: Array[String] = []
		for mid in d.get("mats", {}):
			parts.append("%s %d" % [ItemDB.name_of(mid), int(d["mats"][mid])])
		var availability := _localized("[가능] ", "[AVAILABLE] ") if ok \
			else _localized("[재료 부족] ", "[MISSING MATERIALS] ")
		var l2 := UITheme.wrap_label(availability + "\n".join(parts), 11,
			UITheme.TEXT_DIM if ok else UITheme.DANGER_TEXT)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l2.max_lines_visible = 3
		l2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vv.add_child(l2)

	var cur := RecipeDB.piece(build_system.current_id)
	_info.text = "%s · %s" % [_localized("[선택됨]", "[SELECTED]"),
		tr("UI_BUILD_HINT") % tr(str(cur.get("n", build_system.current_id)))]
	if _status.text == "":
		_status.text = _localized("[안내] 초록 미리보기만 설치할 수 있습니다",
			"[INFO] Place only when the preview is green")
		_status.add_theme_color_override("font_color", UITheme.TEXT_DIM)

func _tooltip(id: String, d: Dictionary) -> String:
	var parts: Array[String] = [tr(str(d.get("n", id)))]
	for mid in d.get("mats", {}):
		parts.append("· %s x%d" % [ItemDB.name_of(mid), int(d["mats"][mid])])
	if bool(d.get("needs_workbench", true)):
		parts.append(tr("UI_NEEDS_WORKBENCH"))
	return "\n".join(parts)

func _select_piece(id: String, _button: Button) -> void:
	build_system.select(id)
	Sfx.play("click", -20.0)
	_status.text = ""
	close_palette()
	piece_chosen.emit()


func _on_build_mode_changed(active: bool) -> void:
	if not active:
		close_palette()
		palette_closed.emit()
		_status.text = ""


func _on_placement_result(result: Dictionary) -> void:
	if bool(result.get("accepted", false)):
		match str(result.get("operation", "")):
			"PLACE":
				_status.text = _localized("[완료] 설치했습니다", "[DONE] Piece placed")
			"REMOVE":
				_status.text = _localized("[완료] 철거했습니다", "[DONE] Piece removed")
			_:
				_status.text = _localized("[완료] 작업을 마쳤습니다", "[DONE] Operation completed")
		_status.add_theme_color_override("font_color", UITheme.SUCCESS)
		return

	if str(result.get("reason", "")) == "UNSUPPORTED_IN_RT1":
		_show_remote_limitation()
		return
	_status.text = _localized("[불가] 이 위치에는 설치할 수 없습니다",
		"[UNAVAILABLE] Cannot place at this location")
	_status.add_theme_color_override("font_color", UITheme.DANGER_TEXT)

func _show_remote_limitation() -> void:
	_status.text = _localized("[불가] 이 릴리스에서는 원격 건축을 지원하지 않습니다",
		"[UNAVAILABLE] Remote building is unavailable in this release")
	_status.add_theme_color_override("font_color", UITheme.DANGER_TEXT)

func _localized(ko: String, en: String) -> String:
	return ko if TranslationServer.get_locale().begins_with("ko") else en

func apply_responsive_layout() -> void:
	_apply_responsive_layout()

func _apply_responsive_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var ui_scale := maxf(get_tree().root.content_scale_factor, 0.01)
	var margin := UITheme.safe_margin(viewport_size.x)
	var available := viewport_size / ui_scale - Vector2.ONE * margin * 2.0
	var max_panel_size := Vector2(MAX_WIDTH, MAX_HEIGHT)
	custom_minimum_size = Vector2(clampf(available.x, 0.0, max_panel_size.x),
		clampf(available.y, 0.0, max_panel_size.y))
	if _grid != null:
		_grid.columns = maxi(1, int((custom_minimum_size.x - 28.0) / 99.0))
	if _scroll != null:
		_scroll.custom_minimum_size.y = minf(108.0, maxf(0.0, available.y - 92.0))

func _valid_preview() -> bool:
	return build_system != null and bool(build_system.get("_valid"))
