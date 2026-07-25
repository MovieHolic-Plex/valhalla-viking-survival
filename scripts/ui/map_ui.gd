class_name MapUI
extends PanelContainer
## 지도. 탐색한 지역만 드러나며, 바이옴 색으로 그려진다. 미니맵과 전체지도 겸용.

const TILE := 32.0            # 지도 1픽셀 = 32m
const TEX_SIZE := 256         # 월드 전체를 담는 텍스처 한 변

var player: Player
var _tex_rect: TextureRect
var _img: Image
var _tex: ImageTexture
var _marker_layer: Control
var _dirty := true
var _refresh_t := 0.0
var _painted: Dictionary = {}
var _pins: Array = []

func _ready() -> void:
	name = "map_ui"
	custom_minimum_size = Vector2(880, 860)
	visible = false
	add_theme_stylebox_override("panel",
		UITheme.panel_box(Color(0.10, 0.09, 0.07, 0.98), UITheme.GOLD_DIM, 6, 3))

	var v := VBoxContainer.new()
	add_child(v)
	v.add_child(UITheme.title(tr("UI_MAP"), 26))

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(860, 820)
	v.add_child(holder)

	_img = Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0.06, 0.06, 0.07, 1.0))
	_tex = ImageTexture.create_from_image(_img)
	_tex_rect = TextureRect.new()
	_tex_rect.texture = _tex
	_tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.add_child(_tex_rect)

	_marker_layer = Control.new()
	_marker_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker_layer.draw.connect(_draw_markers)
	holder.add_child(_marker_layer)

func bind(p: Player) -> void:
	player = p

func _process(delta: float) -> void:
	if not visible:
		return
	_refresh_t -= delta
	if _refresh_t <= 0.0:
		_refresh_t = 0.5
		_paint_discovered()
		_marker_layer.queue_redraw()

## 월드 좌표 -> 텍스처 픽셀
static func world_to_px(x: float, z: float) -> Vector2i:
	var half := float(TEX_SIZE) * 0.5
	return Vector2i(int(x / (Const.WORLD_RADIUS * 2.0 / float(TEX_SIZE)) + half),
		int(z / (Const.WORLD_RADIUS * 2.0 / float(TEX_SIZE)) + half))

static func px_to_ui(px: Vector2i, rect: Vector2) -> Vector2:
	return Vector2(float(px.x) / float(TEX_SIZE) * rect.x,
		float(px.y) / float(TEX_SIZE) * rect.y)

func _paint_discovered() -> void:
	if GameState.gen == null:
		return
	var changed := false
	var scale_m := Const.WORLD_RADIUS * 2.0 / float(TEX_SIZE)
	for tile in GameState.discovered:
		var wx := float(tile.x) * TILE
		var wz := float(tile.y) * TILE
		var px := world_to_px(wx, wz)
		var key := Vector2i(px.x, px.y)
		if _painted.has(key):
			continue
		if px.x < 0 or px.y < 0 or px.x >= TEX_SIZE or px.y >= TEX_SIZE:
			continue
		_painted[key] = true
		changed = true
		# 탐색 타일(32m)이 지도 픽셀보다 크므로 주변 픽셀까지 함께 칠해 구멍을 없앤다
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var tx := px.x + dx
				var ty := px.y + dy
				if tx < 0 or ty < 0 or tx >= TEX_SIZE or ty >= TEX_SIZE:
					continue
				var sx := (float(tx) - float(TEX_SIZE) * 0.5) * scale_m
				var sz := (float(ty) - float(TEX_SIZE) * 0.5) * scale_m
				var h := GameState.gen.height(sx, sz)
				var b := GameState.gen.biome_from(sx, sz, h)
				var c: Color = Const.BIOME_GROUND.get(b, Color(0.3, 0.3, 0.3))
				if b == Const.Biome.OCEAN:
					c = Color(0.10, 0.20, 0.34).lerp(Color(0.18, 0.36, 0.48),
						clampf((h - (Const.WATER_LEVEL - 40.0)) / 40.0, 0.0, 1.0))
				else:
					var shade: float = clampf((h - Const.WATER_LEVEL) / 90.0, 0.0, 1.0)
					c = c.lerp(Color(0.95, 0.96, 1.0), shade * 0.55)
				c.a = 1.0
				_img.set_pixel(tx, ty, c)
	if changed:
		_tex.update(_img)

func _draw_markers() -> void:
	var rect := _marker_layer.size
	# 보스 제단
	for a in get_tree().get_nodes_in_group("altar"):
		if not is_instance_valid(a):
			continue
		var px := world_to_px(a.global_position.x, a.global_position.z)
		if not _painted.has(Vector2i(px.x, px.y)):
			continue
		var p := px_to_ui(px, rect)
		_marker_layer.draw_circle(p, 7.0, Color(0.95, 0.75, 0.30, 0.95))
		_marker_layer.draw_arc(p, 10.0, 0, TAU, 20, Color(0.2, 0.15, 0.05), 2.0)
	# 포탈 / 침대
	for b in get_tree().get_nodes_in_group("build_piece"):
		if not is_instance_valid(b):
			continue
		if b.data.get("portal", false):
			var pp := px_to_ui(world_to_px(b.global_position.x, b.global_position.z), rect)
			_marker_layer.draw_circle(pp, 5.0, Color(0.35, 0.85, 0.95, 0.9))
		elif b.data.get("bed", false):
			var pb := px_to_ui(world_to_px(b.global_position.x, b.global_position.z), rect)
			_marker_layer.draw_circle(pb, 5.0, Color(0.95, 0.55, 0.55, 0.9))
	# 무덤
	for t in get_tree().get_nodes_in_group("tombstone"):
		if not is_instance_valid(t):
			continue
		var pt := px_to_ui(world_to_px(t.global_position.x, t.global_position.z), rect)
		_marker_layer.draw_circle(pt, 6.0, Color(0.75, 0.85, 1.0, 0.95))
	# 플레이어
	if player != null and is_instance_valid(player):
		var pl := px_to_ui(world_to_px(player.global_position.x,
			player.global_position.z), rect)
		var dir := -player.global_transform.basis.z
		var ang := atan2(dir.x, dir.z)
		var tip := pl + Vector2(sin(ang), cos(ang)) * 13.0
		var l := pl + Vector2(sin(ang + 2.4), cos(ang + 2.4)) * 9.0
		var r := pl + Vector2(sin(ang - 2.4), cos(ang - 2.4)) * 9.0
		_marker_layer.draw_colored_polygon(PackedVector2Array([tip, l, r]),
			Color(1.0, 0.95, 0.75))
		_marker_layer.draw_arc(pl, 14.0, 0, TAU, 24, Color(0, 0, 0, 0.6), 2.0)
