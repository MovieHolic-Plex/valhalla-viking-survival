extends StaticBody3D

const STONE := Color(0.24, 0.29, 0.27)
const RUNE := Color(0.46, 0.82, 0.68)

var game: Node
var awakened := false

@onready var visual: Node3D = $Visual


func setup(owner_game: Node) -> void:
	game = owner_game
	_build_visual()


func get_prompt() -> String:
	if awakened:
		return "제단의 뿌리가 깨어났습니다"
	return "[E] 뿔 파편 바치기  ×1"


func interact(player: Node) -> void:
	if awakened:
		game.notify("이미 숲의 수호자가 깨어났습니다.", Color(0.62, 0.82, 0.69))
		return
	if not player.remove_item("trophy", 1):
		game.notify("그레이링의 뿔 파편이 필요합니다.", Color(0.94, 0.68, 0.35))
		return
	awakened = true
	game.altar_activated(global_position)
	var tween := visual.create_tween()
	tween.tween_property(visual, "scale", Vector3(1.1, 0.92, 1.1), 0.18)
	tween.tween_property(visual, "scale", Vector3.ONE, 0.26).set_trans(Tween.TRANS_BACK)


func _build_visual() -> void:
	for child in visual.get_children():
		child.queue_free()
	for index in range(9):
		var angle := TAU * float(index) / 9.0
		var height := 1.15 + sin(float(index) * 2.3) * 0.18
		var stone := CylinderMesh.new()
		stone.top_radius = 0.38
		stone.bottom_radius = 0.52
		stone.height = height
		stone.radial_segments = 6
		var node := _mesh(stone, STONE.lightened(float(index % 3) * 0.025), Vector3(cos(angle) * 1.25, height * 0.5, sin(angle) * 1.25), Vector3.ONE)
		node.rotation.y = -angle
	var slab := CylinderMesh.new()
	slab.top_radius = 1.15
	slab.bottom_radius = 1.35
	slab.height = 0.38
	slab.radial_segments = 9
	_mesh(slab, STONE.lightened(0.07), Vector3(0, 0.65, 0), Vector3.ONE)

	var rune := TorusMesh.new()
	rune.inner_radius = 0.53
	rune.outer_radius = 0.65
	rune.rings = 18
	rune.ring_segments = 6
	var rune_node := _mesh(rune, RUNE, Vector3(0, 0.87, 0), Vector3.ONE)
	rune_node.rotation.x = PI * 0.5
	var rune_material := rune_node.material_override as StandardMaterial3D
	rune_material.emission_enabled = true
	rune_material.emission = RUNE
	rune_material.emission_energy_multiplier = 2.4

	for side in [-1.0, 1.0]:
		var antler := CylinderMesh.new()
		antler.top_radius = 0.06
		antler.bottom_radius = 0.12
		antler.height = 2.15
		antler.radial_segments = 6
		var antler_node := _mesh(antler, Color(0.42, 0.35, 0.25), Vector3(side * 0.62, 1.65, 0), Vector3.ONE)
		antler_node.rotation.z = side * 0.42
		for tine_index in range(2):
			var tine := CylinderMesh.new()
			tine.top_radius = 0.025
			tine.bottom_radius = 0.06
			tine.height = 0.7
			tine.radial_segments = 5
			var tine_node := _mesh(tine, Color(0.45, 0.38, 0.27), Vector3(side * (0.86 + tine_index * 0.18), 1.62 + tine_index * 0.48, 0), Vector3.ONE)
			tine_node.rotation.z = side * 0.85

	var light := OmniLight3D.new()
	light.light_color = RUNE
	light.light_energy = 2.8
	light.omni_range = 7.0
	light.position = Vector3(0, 1.3, 0)
	light.shadow_enabled = true
	visual.add_child(light)


func _mesh(mesh: PrimitiveMesh, color: Color, at: Vector3, mesh_scale: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.scale = mesh_scale
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	node.material_override = material
	visual.add_child(node)
	return node
