extends Node3D

const WORLD_SIZE := 176.0
const TERRAIN_RESOLUTION := 64
const WATER_LEVEL := 0.0
const TREE_COUNT := 40
const GRASS_CLUSTER_COUNT := 280
const FOREST_CLEARING_RADIUS := 11.0
const CLOUD_TEXTURE_SIZE := Vector2i(128, 64)
const NORTH_FOREST_ANCHORS := [
	Vector2(-25.0, 27.0), Vector2(-16.0, 34.0), Vector2(-10.0, 21.0),
	Vector2(-3.0, 30.0), Vector2(6.0, 24.0), Vector2(14.0, 34.0),
	Vector2(22.0, 26.0), Vector2(-18.0, 48.0), Vector2(18.0, 50.0),
]

var game: Node
var terrain_noise := FastNoiseLite.new()
var detail_noise := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var environment: Environment
var sky_material: ProceduralSkyMaterial
var sun: DirectionalLight3D
var water_material: ShaderMaterial
var grass_material: ShaderMaterial
var grass_mesh: ArrayMesh
var cloud_cover_texture: ImageTexture
var cloud_layers_root: Node3D
var cloud_materials: Array[StandardMaterial3D] = []
var cloud_banks_root: Node3D
var cloud_card_texture: ImageTexture
var cloud_sprites: Array[Sprite3D] = []
var resources_root: Node3D
var foliage_root: Node3D
var terrain_ready := false
var altar: Node3D


func setup(owner_game: Node) -> void:
	game = owner_game
	rng.seed = 14471
	terrain_noise.seed = 38192
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terrain_noise.frequency = 0.022
	terrain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	terrain_noise.fractal_octaves = 4
	terrain_noise.fractal_gain = 0.48
	detail_noise.seed = 9185
	detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	detail_noise.frequency = 0.085
	detail_noise.fractal_octaves = 2
	_create_roots()
	_create_environment()
	_create_cloud_layers()
	_create_terrain()
	_create_water()
	_create_grass()
	_create_world_population()
	terrain_ready = true


func _process(delta: float) -> void:
	if cloud_layers_root == null:
		return
	for index in range(cloud_layers_root.get_child_count()):
		var layer := cloud_layers_root.get_child(index) as MeshInstance3D
		if layer != null:
			layer.rotation.y += delta * (0.0018 + float(index) * 0.0009)


func height_at(x: float, z: float) -> float:
	var shoreline := smoothstep(-47.0, -25.0, z + sin(x * 0.055) * 4.5)
	var broad := terrain_noise.get_noise_2d(x, z) * 4.4
	var detail := detail_noise.get_noise_2d(x, z) * 0.85
	var rolling := sin(x * 0.075) * 0.55 + cos(z * 0.052) * 0.45
	var land_height := 2.8 + broad + detail + rolling
	var seabed := -3.8 + detail * 0.35
	return lerpf(seabed, land_height, shoreline)


func set_daylight(phase: float, night: bool) -> void:
	if environment == null or sun == null:
		return
	var daylight := clampf(sin((phase - 0.18) / 0.56 * PI), 0.0, 1.0)
	if night:
		daylight *= 0.18
	sun.rotation_degrees.x = lerpf(-8.0, -158.0, clampf((phase - 0.16) / 0.66, 0.0, 1.0))
	sun.rotation_degrees.y = -32.0 + phase * 46.0
	sun.light_energy = lerpf(0.16, 1.30, daylight)
	sun.light_color = Color(0.43, 0.50, 0.61).lerp(Color(1.0, 0.82, 0.58), daylight)
	environment.ambient_light_energy = lerpf(0.34, 0.90, daylight)
	environment.ambient_light_color = Color(0.17, 0.22, 0.27).lerp(Color(0.67, 0.65, 0.55), daylight)
	environment.fog_light_color = Color(0.11, 0.16, 0.20).lerp(Color(0.57, 0.59, 0.50), daylight)
	environment.fog_density = lerpf(0.016, 0.0048, daylight)
	sky_material.sky_top_color = Color(0.04, 0.07, 0.12).lerp(Color(0.14, 0.27, 0.42), daylight)
	sky_material.sky_horizon_color = Color(0.14, 0.18, 0.23).lerp(Color(0.56, 0.58, 0.50), daylight)
	sky_material.ground_bottom_color = Color(0.03, 0.04, 0.05).lerp(Color(0.18, 0.23, 0.16), daylight)
	sky_material.ground_horizon_color = sky_material.sky_horizon_color.darkened(0.24)
	var cloud_tint := Color(0.19, 0.22, 0.27).lerp(Color(0.69, 0.72, 0.73), daylight)
	for index in range(cloud_materials.size()):
		var alpha := 0.26 if index == 0 else 0.08
		cloud_materials[index].albedo_color = Color(cloud_tint.r, cloud_tint.g, cloud_tint.b, alpha)
	var bank_tint := Color(0.23, 0.27, 0.32).lerp(Color(0.82, 0.84, 0.83), daylight)
	for cloud in cloud_sprites:
		cloud.modulate = Color(bank_tint.r, bank_tint.g, bank_tint.b, 0.72)


func _create_roots() -> void:
	resources_root = Node3D.new()
	resources_root.name = "Resources"
	add_child(resources_root)
	foliage_root = Node3D.new()
	foliage_root.name = "WindFoliage"
	add_child(foliage_root)


func _create_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "NordicEnvironment"
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.66, 0.65, 0.56)
	environment.ambient_light_energy = 0.9
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.08
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.62, 0.64, 0.54)
	environment.fog_density = 0.007
	environment.fog_height = 1.0
	environment.fog_height_density = 0.045
	environment.glow_enabled = true
	environment.glow_intensity = 0.72
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 0.9
	environment.adjustment_contrast = 1.04
	var sky := Sky.new()
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.30, 0.43, 0.54)
	sky_material.sky_horizon_color = Color(0.77, 0.70, 0.55)
	sky_material.ground_bottom_color = Color(0.19, 0.23, 0.17)
	sky_material.ground_horizon_color = Color(0.48, 0.48, 0.37)
	sky_material.sky_curve = 0.32
	sky_material.ground_curve = 0.2
	sky_material.sun_angle_max = 12.0
	sky_material.sun_curve = 0.08
	sky.sky_material = sky_material
	environment.sky = sky
	world_environment.environment = environment
	add_child(world_environment)

	sun = DirectionalLight3D.new()
	sun.name = "LowNorthernSun"
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color(1.0, 0.82, 0.60)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	sun.directional_shadow_fade_start = 0.78
	sun.shadow_blur = 1.4
	add_child(sun)


func _create_cloud_layers() -> void:
	var cloud_noise := FastNoiseLite.new()
	cloud_noise.seed = 60431
	cloud_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cloud_noise.frequency = 0.055
	cloud_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	cloud_noise.fractal_octaves = 4
	cloud_noise.fractal_gain = 0.52
	var image := Image.create(CLOUD_TEXTURE_SIZE.x, CLOUD_TEXTURE_SIZE.y, false, Image.FORMAT_RGBA8)
	for y in range(CLOUD_TEXTURE_SIZE.y):
		var v := float(y) / float(CLOUD_TEXTURE_SIZE.y - 1)
		var horizon_fade := clampf((0.62 - v) / 0.22, 0.0, 1.0)
		for x in range(CLOUD_TEXTURE_SIZE.x):
			var angle := TAU * float(x) / float(CLOUD_TEXTURE_SIZE.x)
			var sample_position := Vector3(cos(angle) * 28.0, sin(angle) * 28.0, v * 34.0)
			var broad := cloud_noise.get_noise_3dv(sample_position) * 0.5 + 0.5
			var detail := cloud_noise.get_noise_3dv(sample_position * 2.1 + Vector3(17.0, -9.0, 31.0)) * 0.5 + 0.5
			var density := broad * 0.76 + detail * 0.24
			var cover := smoothstep(0.42, 0.66, density) * horizon_fade
			image.set_pixel(x, y, Color(0.91, 0.92, 0.90, cover * 0.88))
	cloud_cover_texture = ImageTexture.create_from_image(image)
	cloud_cover_texture.resource_name = "ProceduralCloudCover"
	cloud_layers_root = Node3D.new()
	cloud_layers_root.name = "ProceduralSkyDepth"
	add_child(cloud_layers_root)
	cloud_materials.clear()
	for index in range(2):
		var sphere := SphereMesh.new()
		var radius := 138.0 + float(index) * 9.0
		sphere.radius = radius
		sphere.height = radius * 2.0
		sphere.radial_segments = 32
		sphere.rings = 16
		var layer := MeshInstance3D.new()
		layer.name = "CloudCover%d" % (index + 1)
		layer.mesh = sphere
		layer.position.y = -20.0 - float(index) * 5.0
		layer.rotation.y = float(index) * 1.83
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.albedo_texture = cloud_cover_texture
		material.albedo_color = Color(0.78, 0.79, 0.75, 0.18 if index == 0 else 0.09)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_FRONT
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		layer.material_override = material
		cloud_layers_root.add_child(layer)
		cloud_materials.append(material)
	_create_cloud_banks()


func _create_cloud_banks() -> void:
	cloud_banks_root = Node3D.new()
	cloud_banks_root.name = "SoftCloudBanks"
	add_child(cloud_banks_root)
	var card_size := Vector2i(64, 24)
	var image := Image.create(card_size.x, card_size.y, false, Image.FORMAT_RGBA8)
	var blobs := [
		[Vector2(-0.58, 0.12), Vector2(0.48, 0.58)],
		[Vector2(-0.18, -0.08), Vector2(0.52, 0.76)],
		[Vector2(0.24, 0.02), Vector2(0.55, 0.68)],
		[Vector2(0.62, 0.18), Vector2(0.42, 0.52)],
	]
	var card_noise := FastNoiseLite.new()
	card_noise.seed = 17321
	card_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	card_noise.frequency = 0.075
	for y in range(card_size.y):
		var normalized_y := float(y) / float(card_size.y - 1) * 2.0 - 1.0
		for x in range(card_size.x):
			var normalized_x := float(x) / float(card_size.x - 1) * 2.0 - 1.0
			var density := -1.0
			for blob: Array in blobs:
				var center: Vector2 = blob[0]
				var radius: Vector2 = blob[1]
				var distance := Vector2((normalized_x - center.x) / radius.x, (normalized_y - center.y) / radius.y).length()
				density = maxf(density, 1.0 - distance)
			var soft_noise := card_noise.get_noise_2d(float(x), float(y)) * 0.10
			var edge := smoothstep(-0.06, 0.52, density + soft_noise)
			var shade_noise := card_noise.get_noise_2d(float(x) + 83.0, float(y) - 41.0) * 0.035
			var shade := clampf(lerpf(0.74, 0.98, clampf(1.0 - normalized_y, 0.0, 1.0)) + shade_noise, 0.0, 1.0)
			image.set_pixel(x, y, Color(shade, shade, shade * 0.98, edge * 0.82))
	image.generate_mipmaps()
	cloud_card_texture = ImageTexture.create_from_image(image)
	cloud_card_texture.resource_name = "ProceduralSoftCloudCard"
	cloud_sprites.clear()
	var centers := [
		Vector3(-62.0, 18.0, 66.0), Vector3(-28.0, 19.0, 94.0),
		Vector3(10.0, 17.0, 72.0), Vector3(48.0, 20.0, 98.0),
		Vector3(73.0, 16.0, 64.0), Vector3(-78.0, 22.0, 112.0),
	]
	for index in range(centers.size()):
		var cloud := Sprite3D.new()
		cloud.name = "CloudBank%d" % (index + 1)
		cloud.texture = cloud_card_texture
		cloud.pixel_size = 0.52
		cloud.position = centers[index]
		cloud.scale = Vector3(0.82 + float(index % 3) * 0.16, 0.82 + float((index + 1) % 2) * 0.13, 1.0)
		cloud.modulate = Color(0.82, 0.84, 0.83, 0.82)
		cloud.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		cloud.shaded = false
		cloud.no_depth_test = true
		cloud.double_sided = true
		cloud.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		cloud_banks_root.add_child(cloud)
		cloud_sprites.append(cloud)


func _create_terrain() -> void:
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var row := TERRAIN_RESOLUTION + 1
	var step := WORLD_SIZE / float(TERRAIN_RESOLUTION)
	for z_index in range(row):
		for x_index in range(row):
			var x := -WORLD_SIZE * 0.5 + float(x_index) * step
			var z := -WORLD_SIZE * 0.5 + float(z_index) * step
			var y := height_at(x, z)
			vertices.append(Vector3(x, y, z))
			var normal := Vector3(
				height_at(x - 0.7, z) - height_at(x + 0.7, z),
				1.4,
				height_at(x, z - 0.7) - height_at(x, z + 0.7)
			).normalized()
			normals.append(normal)
			uvs.append(Vector2(x, z) * 0.095)
			var slope := 1.0 - normal.y
			var tint := Color(0.45, 0.49, 0.31)
			if y < 1.0:
				tint = Color(0.69, 0.60, 0.39).lerp(Color(0.43, 0.46, 0.29), smoothstep(0.1, 1.3, y))
			elif slope > 0.22:
				tint = Color(0.49, 0.46, 0.36)
			else:
				tint = tint.lerp(Color(0.31, 0.39, 0.25), clampf((z + 10.0) / 75.0, 0.0, 0.42))
			colors.append(tint)
	for z_index in range(TERRAIN_RESOLUTION):
		for x_index in range(TERRAIN_RESOLUTION):
			var current := z_index * row + x_index
			indices.append(current)
			indices.append(current + row)
			indices.append(current + 1)
			indices.append(current + 1)
			indices.append(current + row)
			indices.append(current + row + 1)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var terrain_material := StandardMaterial3D.new()
	terrain_material.albedo_texture = load("res://assets/textures/grass.png")
	terrain_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.roughness = 0.98
	terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	terrain_material.albedo_color = Color(1.0, 0.98, 0.88)
	mesh.surface_set_material(0, terrain_material)

	var terrain_mesh := MeshInstance3D.new()
	terrain_mesh.name = "CoastalTerrain"
	terrain_mesh.mesh = mesh
	terrain_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(terrain_mesh)
	var terrain_body := StaticBody3D.new()
	terrain_body.name = "TerrainCollision"
	terrain_body.collision_layer = 1
	terrain_body.collision_mask = 0
	var terrain_shape := CollisionShape3D.new()
	terrain_shape.shape = mesh.create_trimesh_shape()
	terrain_body.add_child(terrain_shape)
	add_child(terrain_body)


func _create_water() -> void:
	var water := MeshInstance3D.new()
	water.name = "NorthernSea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(WORLD_SIZE * 1.45, WORLD_SIZE * 1.45)
	plane.subdivide_width = 48
	plane.subdivide_depth = 48
	water.mesh = plane
	water.position.y = WATER_LEVEL
	water_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
uniform vec3 shallow_color : source_color = vec3(0.18, 0.38, 0.42);
uniform vec3 deep_color : source_color = vec3(0.035, 0.13, 0.20);
void vertex() {
	float wave = sin(VERTEX.x * 0.17 + TIME * 0.72) * 0.10;
	wave += cos(VERTEX.z * 0.12 - TIME * 0.53) * 0.08;
	VERTEX.y += wave;
}
void fragment() {
	float ripple = sin((UV.x + UV.y) * 92.0 + TIME * 1.2) * 0.035;
	ALBEDO = mix(deep_color, shallow_color, 0.48 + ripple);
	ROUGHNESS = 0.18;
	METALLIC = 0.08;
	ALPHA = 0.74;
}
"""
	water_material.shader = shader
	water.material_override = water_material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _create_grass() -> void:
	grass_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 grass_color : source_color = vec3(0.30, 0.38, 0.20);
void vertex() {
	float anchor = clamp(VERTEX.y / 1.15, 0.0, 1.0);
	float gust = sin(TIME * 1.65 + MODEL_MATRIX[3].x * 0.21 + MODEL_MATRIX[3].z * 0.17);
	VERTEX.x += gust * 0.13 * anchor;
}
void fragment() {
	ALBEDO = grass_color;
	ROUGHNESS = 1.0;
}
"""
	grass_material.shader = shader
	grass_mesh = _create_grass_silhouette_mesh()
	var created := 0
	while created < GRASS_CLUSTER_COUNT:
		var x := rng.randf_range(-68.0, 68.0)
		var z := rng.randf_range(-16.0, 74.0)
		var y := height_at(x, z)
		if y < 0.65:
			continue
		var cluster := MeshInstance3D.new()
		cluster.name = "GrassCluster"
		cluster.mesh = grass_mesh
		cluster.position = Vector3(x, y + 0.02, z)
		cluster.rotation.y = rng.randf_range(0.0, TAU)
		cluster.scale = Vector3.ONE * rng.randf_range(0.75, 1.35)
		cluster.material_override = grass_material
		cluster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		foliage_root.add_child(cluster)
		created += 1


func _create_grass_silhouette_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var blade_data := [
		[Vector3(-0.24, 0, -0.16), 0.10, 0.16, 0.82, 0.06],
		[Vector3(0.05, 0, -0.24), 1.34, 0.13, 1.04, -0.05],
		[Vector3(0.28, 0, -0.04), 2.42, 0.14, 0.72, 0.04],
		[Vector3(-0.12, 0, 0.06), 0.82, 0.15, 1.15, -0.07],
		[Vector3(0.18, 0, 0.20), 1.92, 0.12, 0.88, 0.05],
		[Vector3(-0.31, 0, 0.22), 2.86, 0.11, 0.67, -0.03],
		[Vector3(0.02, 0, 0.29), 0.42, 0.13, 0.94, 0.04],
	]
	for entry: Array in blade_data:
		var center: Vector3 = entry[0]
		var angle := float(entry[1])
		var half_width := float(entry[2])
		var height := float(entry[3])
		var bend := float(entry[4])
		var tangent := Vector3(cos(angle), 0.0, sin(angle))
		var normal := Vector3(-tangent.z, 0.0, tangent.x)
		vertices.append(center - tangent * half_width)
		vertices.append(center + tangent * half_width)
		vertices.append(center + normal * bend + Vector3.UP * height)
		for unused in range(3):
			normals.append(normal)
		uvs.append(Vector2(0.0, 1.0))
		uvs.append(Vector2(1.0, 1.0))
		uvs.append(Vector2(0.5, 0.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.set_meta("silhouette", "tapered_triangles")
	return mesh


func _create_world_population() -> void:
	# 채집 동선은 야영지 주변에서 시작해 북쪽 숲으로 자연스럽게 이어진다.
	var pickup_layout := [
		["branch", Vector3(-3.5, 0, -2.0)], ["branch", Vector3(3.2, 0, -4.0)],
		["branch", Vector3(-6.5, 0, 3.0)], ["branch", Vector3(7.0, 0, 4.5)],
		["stone_pickup", Vector3(-2.0, 0, 5.5)], ["stone_pickup", Vector3(4.5, 0, 6.0)],
		["stone_pickup", Vector3(7.0, 0, -1.0)], ["mushroom", Vector3(-7.5, 0, 8.0)],
		["mushroom", Vector3(5.5, 0, 11.0)], ["mushroom", Vector3(-1.5, 0, 13.0)],
	]
	for index in range(pickup_layout.size()):
		var entry: Array = pickup_layout[index]
		var position_2d: Vector3 = entry[1]
		position_2d.y = height_at(position_2d.x, position_2d.z)
		game.spawn_resource(str(entry[0]), position_2d, index)

	var tree_index := 0
	for anchor: Vector2 in NORTH_FOREST_ANCHORS:
		var anchored_tree := Vector3(anchor.x, height_at(anchor.x, anchor.y), anchor.y)
		game.spawn_resource("tree", anchored_tree, 100 + tree_index)
		tree_index += 1
	while tree_index < TREE_COUNT:
		var position_2d := _random_land_position(-68.0, 68.0, -6.0, 74.0)
		if Vector2(position_2d.x, position_2d.z).length() < FOREST_CLEARING_RADIUS or position_2d.y < 0.65:
			continue
		game.spawn_resource("tree", position_2d, 100 + tree_index)
		tree_index += 1
	for index in range(9):
		var position_2d := _random_land_position(-60.0, 60.0, -8.0, 62.0)
		if Vector2(position_2d.x, position_2d.z).length() < 8.0:
			position_2d.z += 10.0
		game.spawn_resource("rock", position_2d, 300 + index)

	# 멀리 보이는 해안 바위가 수평선과 초원의 경계를 잡아준다.
	for index in range(11):
		var x := -58.0 + float(index) * 11.5
		var z := -34.0 + sin(float(index) * 1.37) * 4.0
		var rock := MeshInstance3D.new()
		var rock_mesh := SphereMesh.new()
		rock_mesh.radius = 1.0
		rock_mesh.height = 1.45
		rock_mesh.radial_segments = 7
		rock_mesh.rings = 4
		rock.mesh = rock_mesh
		rock.position = Vector3(x, height_at(x, z) + 0.35, z)
		rock.scale = Vector3(rng.randf_range(0.8, 1.8), rng.randf_range(0.5, 1.2), rng.randf_range(0.7, 1.5))
		rock.rotation.y = rng.randf_range(0.0, TAU)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.31, 0.35, 0.34)
		material.roughness = 0.96
		rock.material_override = material
		add_child(rock)

	var altar_position := Vector3(17.0, 0, -13.0)
	altar_position.y = height_at(altar_position.x, altar_position.z)
	altar = game.spawn_altar(altar_position)


func _random_land_position(min_x: float, max_x: float, min_z: float, max_z: float) -> Vector3:
	var x := rng.randf_range(min_x, max_x)
	var z := rng.randf_range(min_z, max_z)
	return Vector3(x, height_at(x, z), z)


func clear_capture_camp_corridor(origin: Vector3) -> int:
	if game == null or not bool(game.capture_mode):
		return 0
	var removed := 0
	for resource in resources_root.get_children():
		if not resource.has_method("take_hit"):
			continue
		var kind := str(resource.get("resource_kind"))
		if kind not in ["rock", "branch", "stone_pickup"]:
			continue
		var offset: Vector3 = (resource as Node3D).global_position - origin
		if offset.z < 3.0 or offset.z > 12.0:
			continue
		var depth := (offset.z - 3.0) / 9.0
		if absf(offset.x) > lerpf(4.6, 8.0, depth):
			continue
		resources_root.remove_child(resource)
		resource.queue_free()
		removed += 1
	return removed


func grass_silhouette_contract_valid() -> bool:
	if grass_mesh == null or grass_mesh.get_surface_count() != 1:
		return false
	if grass_mesh.surface_get_primitive_type(0) != Mesh.PRIMITIVE_TRIANGLES:
		return false
	if str(grass_mesh.get_meta("silhouette", "")) != "tapered_triangles":
		return false
	var arrays := grass_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.size() < 9 or vertices.size() % 3 != 0:
		return false
	for index in range(0, vertices.size(), 3):
		if vertices[index + 2].y <= maxf(vertices[index].y, vertices[index + 1].y):
			return false
	return true


func sky_depth_contract_valid() -> bool:
	return (
		sky_material != null
		and sky_material.sky_curve > 0.0
		and cloud_cover_texture != null
		and cloud_cover_texture.get_width() == CLOUD_TEXTURE_SIZE.x
		and cloud_cover_texture.get_height() == CLOUD_TEXTURE_SIZE.y
		and cloud_layers_root != null
		and cloud_layers_root.get_child_count() == 2
		and cloud_materials.size() == 2
		and cloud_banks_root != null
		and cloud_banks_root.get_child_count() == 6
		and cloud_card_texture != null
		and cloud_card_texture.get_width() == 64
		and cloud_card_texture.get_height() == 24
		and cloud_sprites.size() == 6
	)
