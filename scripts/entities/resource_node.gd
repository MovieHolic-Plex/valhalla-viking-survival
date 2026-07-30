extends StaticBody3D

const BARK := Color(0.24, 0.19, 0.14)
const BARK_LIGHT := Color(0.38, 0.30, 0.20)
const PINE := Color(0.16, 0.25, 0.19)
const MOSS := Color(0.30, 0.39, 0.27)
const STONE := Color(0.35, 0.38, 0.37)

var game: Node
var resource_kind := "branch"
var item_id := "branch"
var amount := 1
var health := 1.0
var max_health := 1.0
var seed_offset := 0.0
var canopy: Node3D
var base_canopy_rotation := Vector3.ZERO
var depleted := false

@onready var visual: Node3D = $Visual
@onready var collision: CollisionShape3D = $CollisionShape3D


func setup(new_kind: String, owner_game: Node, variant_seed: int = 0, pickup_amount: int = 1) -> void:
	game = owner_game
	resource_kind = new_kind
	amount = pickup_amount
	seed_offset = float(variant_seed) * 0.73
	_build_visual()


func get_prompt() -> String:
	match resource_kind:
		"branch":
			return "[E] 가지 줍기"
		"stone_pickup":
			return "[E] 부싯돌 줍기"
		"mushroom":
			return "[E] 붉은버섯 따기"
		"wood_drop":
			return "[E] 목재 줍기  ×%d" % amount
		"stone_drop":
			return "[E] 돌 줍기  ×%d" % amount
		"trophy_drop":
			return "[E] 뿔 파편 줍기"
		"meat_drop":
			return "[E] 훈제고기 줍기"
		_:
			return "돌도끼로 채집" if resource_kind == "tree" else "도구로 채굴"


func interact(player: Node) -> void:
	if depleted or resource_kind in ["tree", "rock"]:
		return
	depleted = true
	player.add_item(item_id, amount)
	if game != null:
		game.resource_collected(item_id, amount)
		game.feedback.play_sfx("pickup")
		game.feedback.hit(global_position + Vector3.UP * 0.25, amount, _item_color(), false, false)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y + 0.5, 0.16)
	tween.chain().tween_callback(queue_free)


func take_hit(damage: float, tool: String, attacker: Node) -> void:
	if depleted or resource_kind not in ["tree", "rock"]:
		return
	if tool != "stone_axe":
		game.notify("%s에는 돌도끼가 필요합니다." % ("나무" if resource_kind == "tree" else "바위"), Color(0.95, 0.68, 0.34))
		game.feedback.hit(global_position + Vector3.UP, 0, Color(0.66, 0.69, 0.67), false)
		return
	health -= damage
	game.feedback.hit(global_position + Vector3.UP * (2.0 if resource_kind == "tree" else 0.7), int(damage), Color(0.93, 0.74, 0.42), damage >= 18.0)
	_hit_pulse()
	if health <= 0.0:
		depleted = true
		game.resource_broken(resource_kind)
		_drop_harvest(attacker)
		var fall_direction := Vector3(attacker.global_position.x - global_position.x, 0, attacker.global_position.z - global_position.z).normalized()
		if fall_direction.length_squared() < 0.1:
			fall_direction = Vector3.RIGHT
		var tween := create_tween().set_parallel(true)
		tween.tween_property(self, "rotation", Vector3(fall_direction.z * 1.25, rotation.y, -fall_direction.x * 1.25), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(self, "scale", Vector3(0.05, 0.05, 0.05), 0.25).set_delay(0.52)
		tween.chain().tween_callback(queue_free)


func _process(_delta: float) -> void:
	if canopy != null and is_instance_valid(canopy):
		var wind := sin(Time.get_ticks_msec() * 0.0015 + seed_offset) * 0.025
		canopy.rotation = base_canopy_rotation + Vector3(wind * 0.55, 0, wind)


func _build_visual() -> void:
	for child in visual.get_children():
		child.queue_free()
	set_process(false)
	match resource_kind:
		"tree":
			item_id = "wood"
			health = 52.0
			max_health = health
			_set_cylinder_collision(0.48, 4.2, 2.1)
			_mesh(CylinderMesh.new(), BARK, Vector3(0, 2.1, 0), Vector3(0.85, 2.1, 0.85), visual, "Trunk")
			canopy = Node3D.new()
			canopy.name = "WindCrown"
			canopy.position = Vector3(0, 3.4, 0)
			visual.add_child(canopy)
			_mesh(CylinderMesh.new(), BARK_LIGHT, Vector3(0, 1.15, 0), Vector3(0.25, 1.4, 0.25), canopy, "TopTrunk")
			for layer in range(3):
				var crown := CylinderMesh.new()
				crown.top_radius = 0.12
				crown.bottom_radius = 1.55 - layer * 0.25
				crown.height = 1.8
				crown.radial_segments = 7
				_mesh(crown, PINE.lerp(MOSS, float(layer) * 0.13), Vector3(0, 1.0 + layer * 1.05, 0), Vector3.ONE, canopy, "PineCrown")
			base_canopy_rotation = canopy.rotation
			set_process(true)
		"rock":
			item_id = "stone"
			health = 64.0
			max_health = health
			var box := BoxShape3D.new()
			box.size = Vector3(2.4, 1.5, 2.0)
			collision.shape = box
			collision.position = Vector3(0, 0.65, 0)
			var rock_mesh := SphereMesh.new()
			rock_mesh.radius = 1.0
			rock_mesh.height = 1.7
			rock_mesh.radial_segments = 7
			rock_mesh.rings = 4
			_mesh(rock_mesh, STONE, Vector3(0, 0.62, 0), Vector3(1.25, 0.8, 1.0), visual, "Boulder")
			_mesh(rock_mesh, STONE.lightened(0.08), Vector3(0.65, 0.35, 0.28), Vector3(0.52, 0.42, 0.48), visual, "BoulderChip")
		"branch":
			item_id = "branch"
			_set_sphere_collision(0.45, 0.18)
			var branch := CylinderMesh.new()
			branch.top_radius = 0.055
			branch.bottom_radius = 0.075
			branch.height = 1.25
			branch.radial_segments = 6
			var node := _mesh(branch, BARK_LIGHT, Vector3(0, 0.18, 0), Vector3.ONE, visual, "Branch")
			node.rotation.z = PI * 0.5
			node.rotation.y = 0.4
		"stone_pickup", "stone_drop":
			item_id = "stone"
			_set_sphere_collision(0.4, 0.2)
			var pebble := SphereMesh.new()
			pebble.radius = 0.32
			pebble.height = 0.42
			pebble.radial_segments = 6
			pebble.rings = 3
			_mesh(pebble, STONE.lightened(0.08), Vector3(0, 0.18, 0), Vector3(1.0, 0.65, 0.8), visual, "Stone")
		"wood_drop":
			item_id = "wood"
			_set_sphere_collision(0.5, 0.28)
			var log_mesh := CylinderMesh.new()
			log_mesh.top_radius = 0.16
			log_mesh.bottom_radius = 0.18
			log_mesh.height = 1.25
			log_mesh.radial_segments = 7
			var log_node := _mesh(log_mesh, BARK_LIGHT, Vector3(0, 0.24, 0), Vector3.ONE, visual, "Log")
			log_node.rotation.z = PI * 0.5
		"mushroom":
			item_id = "mushroom"
			_set_sphere_collision(0.38, 0.2)
			var stem := CylinderMesh.new()
			stem.top_radius = 0.07
			stem.bottom_radius = 0.09
			stem.height = 0.35
			stem.radial_segments = 7
			_mesh(stem, Color(0.78, 0.72, 0.58), Vector3(0, 0.19, 0), Vector3.ONE, visual, "Stem")
			var cap := SphereMesh.new()
			cap.radius = 0.24
			cap.height = 0.2
			cap.radial_segments = 8
			cap.rings = 3
			_mesh(cap, Color(0.54, 0.12, 0.09), Vector3(0, 0.4, 0), Vector3(1, 0.55, 1), visual, "RedCap")
		"trophy_drop":
			item_id = "trophy"
			_set_sphere_collision(0.4, 0.25)
			for side in [-1.0, 1.0]:
				var horn := CylinderMesh.new()
				horn.top_radius = 0.02
				horn.bottom_radius = 0.09
				horn.height = 0.65
				horn.radial_segments = 6
				var horn_node := _mesh(horn, Color(0.66, 0.59, 0.43), Vector3(side * 0.16, 0.28, 0), Vector3.ONE, visual, "HornFragment")
				horn_node.rotation.z = side * 0.72
		"meat_drop":
			item_id = "meat"
			_set_sphere_collision(0.42, 0.22)
			var meat := SphereMesh.new()
			meat.radius = 0.32
			meat.height = 0.34
			meat.radial_segments = 7
			meat.rings = 3
			_mesh(meat, Color(0.48, 0.20, 0.14), Vector3(0, 0.22, 0), Vector3(1.25, 0.6, 0.82), visual, "SmokedMeat")


func _drop_harvest(_attacker: Node) -> void:
	var drop_kind := "wood_drop" if resource_kind == "tree" else "stone_drop"
	var count := 3 if resource_kind == "tree" else 2
	var each_amount := 4 if resource_kind == "tree" else 3
	for index in range(count):
		var angle := TAU * float(index) / float(count)
		game.spawn_pickup(drop_kind, global_position + Vector3(cos(angle) * 0.8, 0.2, sin(angle) * 0.8), each_amount)


func _hit_pulse() -> void:
	var start_scale := visual.scale
	var tween := visual.create_tween()
	tween.tween_property(visual, "scale", start_scale * 1.06, 0.06)
	tween.tween_property(visual, "scale", start_scale, 0.12)


func _set_cylinder_collision(radius: float, height: float, y: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	collision.position = Vector3(0, y, 0)


func _set_sphere_collision(radius: float, y: float) -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius
	collision.shape = shape
	collision.position = Vector3(0, y, 0)


func _mesh(mesh: PrimitiveMesh, color: Color, at: Vector3, mesh_scale: Vector3, parent: Node3D, node_name: String) -> MeshInstance3D:
	if mesh is CylinderMesh:
		var cylinder := mesh as CylinderMesh
		if cylinder.top_radius == 0.5 and cylinder.bottom_radius == 0.5:
			cylinder.top_radius = 0.5
			cylinder.bottom_radius = 0.62
			cylinder.height = 2.0
			cylinder.radial_segments = 7
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = at
	node.scale = mesh_scale
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	node.material_override = material
	parent.add_child(node)
	return node


func _item_color() -> Color:
	match item_id:
		"wood", "branch":
			return Color(0.66, 0.48, 0.28)
		"mushroom":
			return Color(0.72, 0.23, 0.17)
		_:
			return Color(0.58, 0.62, 0.60)
