extends Node3D

const PIECE_ORDER := ["campfire", "workbench", "floor", "wall"]
const PIECE_DATA := {
	"campfire": {"name": "모닥불", "cost": {"wood": 5, "stone": 4}},
	"workbench": {"name": "작업대", "cost": {"wood": 8}},
	"floor": {"name": "나무 바닥", "cost": {"wood": 4}},
	"wall": {"name": "나무 벽", "cost": {"wood": 4}},
}
const VALID_COLOR := Color(0.28, 0.82, 0.48, 0.52)
const INVALID_COLOR := Color(0.92, 0.26, 0.20, 0.52)

var game: Node
var player: Node
var hud: CanvasLayer
var active := false
var piece_index := 0
var rotation_step := 0
var ghost: Node3D
var placement_valid := false
var invalid_reason := ""
var target_transform := Transform3D.IDENTITY
var campfire_effects: Array[Dictionary] = []


func setup(owner_game: Node, owner_player: Node, owner_hud: CanvasLayer) -> void:
	game = owner_game
	player = owner_player
	hud = owner_hud


func _process(_delta: float) -> void:
	_update_campfire_effects()
	if not active or game == null:
		return
	_update_ghost()
	if Input.is_action_just_pressed("rotate_piece"):
		rotation_step = (rotation_step + 1) % 8
	if Input.is_action_just_pressed("build_cycle"):
		piece_index = (piece_index + 1) % PIECE_ORDER.size()
		_rebuild_ghost()
	if Input.is_action_just_pressed("attack"):
		_place_current()
	if Input.is_action_just_pressed("block") or Input.is_action_just_pressed("cancel"):
		exit()


func enter() -> void:
	if active:
		return
	if player.item_count("hammer") <= 0:
		game.notify("망치가 있어야 건축할 수 있습니다.", Color(0.94, 0.66, 0.34))
		return
	active = true
	rotation_step = 0
	_rebuild_ghost()
	hud.show_build_hint(true)
	game.notify("건축 모드 · [Q] 부품  [R] 회전  [좌클릭] 설치  [우클릭] 종료", Color(0.63, 0.84, 0.77), 3.0)


func exit() -> void:
	if not active:
		return
	active = false
	if ghost != null:
		ghost.queue_free()
		ghost = null
	hud.show_build_hint(false)


func _rebuild_ghost() -> void:
	if ghost != null:
		ghost.queue_free()
	ghost = _make_visual(PIECE_ORDER[piece_index], true)
	ghost.name = "PlacementGhost"
	add_child(ghost)
	_update_build_label()


func _update_ghost() -> void:
	if ghost == null:
		return
	var camera: Camera3D = player.camera
	var origin := camera.global_position
	var direction := -camera.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 12.0, 17)
	query.exclude = [player.get_rid()]
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var point: Vector3
	if result.is_empty():
		point = player.global_position + direction * 5.5
		point.y = game.world.height_at(point.x, point.z)
	else:
		point = result.position
	point.x = snappedf(point.x, 0.5)
	point.z = snappedf(point.z, 0.5)
	point.y = game.world.height_at(point.x, point.z)
	var rotation_y := float(rotation_step) * PI * 0.25
	target_transform = Transform3D(Basis(Vector3.UP, rotation_y), point)
	ghost.global_transform = target_transform
	_validate_placement(point)
	_set_ghost_color(VALID_COLOR if placement_valid else INVALID_COLOR)
	_update_build_label()


func _validate_placement(point: Vector3) -> void:
	placement_valid = true
	invalid_reason = ""
	var horizontal_distance := Vector2(point.x - player.global_position.x, point.z - player.global_position.z).length()
	if horizontal_distance > 8.0:
		placement_valid = false
		invalid_reason = "너무 멉니다"
	elif point.y < game.world.WATER_LEVEL + 0.18:
		placement_valid = false
		invalid_reason = "물에는 설치할 수 없습니다"
	else:
		var height_delta := 0.0
		for offset in [Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(-0.8, 0.8), Vector2(0.8, 0.8)]:
			height_delta = maxf(height_delta, absf(game.world.height_at(point.x + offset.x, point.z + offset.y) - point.y))
		if height_delta > 1.05:
			placement_valid = false
			invalid_reason = "지면이 너무 가파릅니다"
	if placement_valid:
		for building in game.buildings.get_children():
			if building is Node3D and (building as Node3D).global_position.distance_to(point) < 1.15:
				placement_valid = false
				invalid_reason = "다른 건축물과 겹칩니다"
				break
	var cost: Dictionary = PIECE_DATA[PIECE_ORDER[piece_index]]["cost"]
	if placement_valid and not player.has_items(cost):
		placement_valid = false
		invalid_reason = "재료가 부족합니다"


func _place_current() -> void:
	var piece_kind: String = PIECE_ORDER[piece_index]
	var data: Dictionary = PIECE_DATA[piece_kind]
	var cost: Dictionary = data["cost"]
	if not placement_valid:
		game.notify("설치 불가 · %s" % invalid_reason, Color(0.96, 0.44, 0.34), 1.0)
		return
	if not player.consume_items(cost):
		game.notify("%s 재료가 부족합니다." % data["name"], Color(0.96, 0.58, 0.32))
		return
	create_piece(piece_kind, target_transform)
	game.building_placed(piece_kind)
	game.feedback.play_sfx("build")
	game.feedback.burst(target_transform.origin + Vector3.UP * 0.15, Color(0.76, 0.65, 0.42, 0.72), 1.2)
	game.notify("%s 설치 완료" % data["name"], Color(0.62, 0.84, 0.62), 1.2)


func create_piece(piece_kind: String, piece_transform: Transform3D) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "%s_%d" % [piece_kind.capitalize(), Time.get_ticks_msec()]
	body.collision_layer = 16
	body.collision_mask = 0
	body.set_meta("build_kind", piece_kind)
	body.global_transform = piece_transform
	body.add_to_group("placed_building")
	body.add_child(_make_visual(piece_kind, false))
	var collision := CollisionShape3D.new()
	match piece_kind:
		"campfire":
			var shape := CylinderShape3D.new()
			shape.radius = 0.85
			shape.height = 0.28
			collision.shape = shape
			collision.position.y = 0.14
		"workbench":
			var shape := BoxShape3D.new()
			shape.size = Vector3(2.25, 0.9, 0.82)
			collision.shape = shape
			collision.position.y = 0.45
		"floor":
			var shape := BoxShape3D.new()
			shape.size = Vector3(2.5, 0.18, 2.5)
			collision.shape = shape
			collision.position.y = 0.09
		"wall":
			var shape := BoxShape3D.new()
			shape.size = Vector3(2.5, 2.4, 0.18)
			collision.shape = shape
			collision.position.y = 1.2
	body.add_child(collision)
	game.buildings.add_child(body)
	return body


func serialize_buildings() -> Array:
	var output: Array = []
	for child in game.buildings.get_children():
		if not child.has_meta("build_kind"):
			continue
		var node := child as Node3D
		output.append({
			"kind": str(child.get_meta("build_kind")),
			"position": [node.global_position.x, node.global_position.y, node.global_position.z],
			"rotation_y": node.global_rotation.y,
		})
	return output


func restore_buildings(data: Array) -> void:
	for entry: Variant in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var piece_kind := str(entry.get("kind", ""))
		var position_data: Array = entry.get("position", [])
		if piece_kind not in PIECE_ORDER or position_data.size() != 3:
			continue
		var position := Vector3(float(position_data[0]), float(position_data[1]), float(position_data[2]))
		var piece_transform := Transform3D(Basis(Vector3.UP, float(entry.get("rotation_y", 0.0))), position)
		create_piece(piece_kind, piece_transform)


func clear_buildings() -> void:
	for child in game.buildings.get_children():
		game.buildings.remove_child(child)
		child.queue_free()


func placed_kinds() -> Array[String]:
	var kinds: Array[String] = []
	for child in game.buildings.get_children():
		if child.has_meta("build_kind"):
			kinds.append(str(child.get_meta("build_kind")))
	return kinds


func _update_build_label() -> void:
	if not active:
		return
	var piece_kind: String = PIECE_ORDER[piece_index]
	var data: Dictionary = PIECE_DATA[piece_kind]
	var cost: Dictionary = data["cost"]
	var cost_text_parts: Array[String] = []
	for item: String in cost:
		cost_text_parts.append("%s %d/%d" % [player.ITEM_NAMES.get(item, item), player.item_count(item), int(cost[item])])
	var suffix := "설치 가능" if placement_valid else invalid_reason
	hud.update_build_hint("%s  ·  %s\n[Q] 변경  [R] 회전  [좌클릭] 설치  [우클릭] 종료\n%s" % [data["name"], " · ".join(cost_text_parts), suffix], placement_valid)


func _set_ghost_color(color: Color) -> void:
	if ghost == null:
		return
	for child in ghost.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		var material := mesh_instance.material_override as StandardMaterial3D
		if material != null:
			material.albedo_color = color
			material.emission_enabled = true
			material.emission = Color(color.r, color.g, color.b)
			material.emission_energy_multiplier = 0.65


func _make_visual(piece_kind: String, is_ghost: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "GhostVisual" if is_ghost else "BuiltVisual"
	match piece_kind:
		"campfire":
			for index in range(9):
				var angle := TAU * float(index) / 9.0
				var stone := SphereMesh.new()
				stone.radius = 0.23
				stone.height = 0.32
				stone.radial_segments = 6
				stone.rings = 3
				_add_mesh(root, stone, Color(0.34, 0.36, 0.34), Vector3(cos(angle) * 0.65, 0.16, sin(angle) * 0.65), Vector3(1.2, 0.7, 0.9), is_ghost)
			for turn in [-0.52, 0.52]:
				var log_mesh := CylinderMesh.new()
				log_mesh.top_radius = 0.09
				log_mesh.bottom_radius = 0.11
				log_mesh.height = 1.05
				log_mesh.radial_segments = 6
				var log_node := _add_mesh(root, log_mesh, Color(0.34, 0.20, 0.11), Vector3(0, 0.2, 0), Vector3.ONE, is_ghost)
				log_node.rotation.z = PI * 0.5
				log_node.rotation.y = turn
			var flame := SphereMesh.new()
			flame.radius = 0.34
			flame.height = 0.9
			flame.radial_segments = 7
			flame.rings = 4
			var flame_node := _add_mesh(root, flame, Color(1.0, 0.40, 0.10), Vector3(0, 0.55, 0), Vector3(0.72, 1.1, 0.72), is_ghost)
			if not is_ghost:
				var flame_material := flame_node.material_override as StandardMaterial3D
				flame_material.emission_enabled = true
				flame_material.emission = Color(1.0, 0.24, 0.05)
				flame_material.emission_energy_multiplier = 3.2
				var light := OmniLight3D.new()
				light.position = Vector3(0, 1.1, 0)
				light.light_color = Color(1.0, 0.48, 0.20)
				light.light_energy = 4.2
				light.omni_range = 9.0
				light.shadow_enabled = true
				root.add_child(light)
				_register_campfire_effect(root, flame_node, light)
		"workbench":
			var top := BoxMesh.new()
			top.size = Vector3(2.25, 0.18, 0.82)
			_add_mesh(root, top, Color(0.38, 0.26, 0.15), Vector3(0, 0.88, 0), Vector3.ONE, is_ghost)
			for x in [-0.86, 0.86]:
				for z in [-0.27, 0.27]:
					var leg := BoxMesh.new()
					leg.size = Vector3(0.14, 0.85, 0.14)
					_add_mesh(root, leg, Color(0.27, 0.18, 0.11), Vector3(x, 0.43, z), Vector3.ONE, is_ghost)
			var back := BoxMesh.new()
			back.size = Vector3(2.0, 0.68, 0.12)
			_add_mesh(root, back, Color(0.32, 0.22, 0.13), Vector3(0, 1.18, 0.35), Vector3.ONE, is_ghost)
		"floor":
			for index in range(6):
				var plank := BoxMesh.new()
				plank.size = Vector3(0.39, 0.16, 2.45)
				_add_mesh(root, plank, Color(0.37 + float(index % 2) * 0.025, 0.25, 0.14), Vector3(-1.04 + index * 0.415, 0.08, 0), Vector3.ONE, is_ghost)
		"wall":
			for index in range(6):
				var plank := BoxMesh.new()
				plank.size = Vector3(0.39, 2.32, 0.16)
				_add_mesh(root, plank, Color(0.35 + float(index % 2) * 0.03, 0.23, 0.13), Vector3(-1.04 + index * 0.415, 1.16, 0), Vector3.ONE, is_ghost)
			for y in [0.22, 2.1]:
				var beam := BoxMesh.new()
				beam.size = Vector3(2.5, 0.16, 0.23)
				_add_mesh(root, beam, Color(0.24, 0.16, 0.09), Vector3(0, y, 0), Vector3.ONE, is_ghost)
	return root


func _register_campfire_effect(root: Node3D, flame: MeshInstance3D, light: OmniLight3D) -> void:
	var smoke_nodes: Array[MeshInstance3D] = []
	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.18
	smoke_mesh.height = 0.34
	smoke_mesh.radial_segments = 7
	smoke_mesh.rings = 4
	var smoke_material := StandardMaterial3D.new()
	smoke_material.albedo_color = Color(0.30, 0.31, 0.29, 0.26)
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index in range(2):
		var smoke := MeshInstance3D.new()
		smoke.name = "CampfireSmoke%d" % (index + 1)
		smoke.mesh = smoke_mesh
		smoke.material_override = smoke_material
		smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(smoke)
		smoke_nodes.append(smoke)

	var ember_nodes: Array[MeshInstance3D] = []
	var ember_mesh := SphereMesh.new()
	ember_mesh.radius = 0.026
	ember_mesh.height = 0.052
	ember_mesh.radial_segments = 5
	ember_mesh.rings = 3
	var ember_material := StandardMaterial3D.new()
	ember_material.albedo_color = Color(1.0, 0.48, 0.08, 0.9)
	ember_material.emission_enabled = true
	ember_material.emission = Color(1.0, 0.24, 0.03)
	ember_material.emission_energy_multiplier = 2.2
	ember_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ember_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for index in range(3):
		var ember := MeshInstance3D.new()
		ember.name = "CampfireEmber%d" % (index + 1)
		ember.mesh = ember_mesh
		ember.material_override = ember_material
		ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ember)
		ember_nodes.append(ember)
	campfire_effects.append({
		"root": root,
		"flame": flame,
		"light": light,
		"smoke": smoke_nodes,
		"embers": ember_nodes,
		"phase": float(campfire_effects.size()) * 1.37,
	})


func _update_campfire_effects() -> void:
	var time := Time.get_ticks_msec() * 0.001
	for effect_index in range(campfire_effects.size() - 1, -1, -1):
		var effect: Dictionary = campfire_effects[effect_index]
		var root := effect["root"] as Node3D
		if root == null or not is_instance_valid(root) or not root.is_inside_tree():
			campfire_effects.remove_at(effect_index)
			continue
		var phase := float(effect["phase"])
		var flutter := sin(time * 13.0 + phase) * 0.055 + sin(time * 21.0 + phase * 0.7) * 0.025
		var flame := effect["flame"] as MeshInstance3D
		var light := effect["light"] as OmniLight3D
		flame.scale = Vector3(0.72 + flutter, 1.10 - flutter * 1.8, 0.72 - flutter * 0.45)
		flame.position = Vector3(flutter * 0.7, 0.55 + absf(flutter) * 0.35, -flutter * 0.35)
		light.light_energy = 4.0 + sin(time * 11.0 + phase) * 0.34 + sin(time * 17.0) * 0.16
		light.position = Vector3(flutter * 0.5, 1.08 + flutter * 0.4, -flutter * 0.25)

		var smoke_nodes: Array = effect["smoke"]
		for index in range(smoke_nodes.size()):
			var smoke := smoke_nodes[index] as MeshInstance3D
			var travel := fposmod(time * 0.34 + float(index) * 0.53 + phase * 0.11, 1.0)
			var drift := sin(travel * TAU + phase + float(index)) * 0.16
			smoke.position = Vector3(drift, 0.82 + travel * 1.65, cos(travel * 4.7 + phase) * 0.09)
			smoke.scale = Vector3.ONE * (0.72 + travel * 0.78)
			smoke.transparency = 0.28 + travel * 0.68

		var ember_nodes: Array = effect["embers"]
		for index in range(ember_nodes.size()):
			var ember := ember_nodes[index] as MeshInstance3D
			var travel := fposmod(time * 0.82 + float(index) * 0.34 + phase * 0.19, 1.0)
			ember.position = Vector3(sin(travel * 8.0 + index) * 0.18, 0.62 + travel * 1.15, cos(travel * 6.0 + index) * 0.14)
			ember.scale = Vector3.ONE * (1.0 - travel * 0.72)
			ember.transparency = travel


func _add_mesh(parent: Node3D, mesh: PrimitiveMesh, color: Color, at: Vector3, mesh_scale: Vector3, is_ghost: bool) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.scale = mesh_scale
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if is_ghost:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
	node.material_override = material
	parent.add_child(node)
	return node
