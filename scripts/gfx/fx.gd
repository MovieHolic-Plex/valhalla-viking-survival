class_name Fx
extends RefCounted
## 타격 이펙트 · 부유 텍스트 · 파티클 헬퍼 (정적 함수 모음)

## 짧게 터지는 파편 파티클
static func burst(parent: Node, pos: Vector3, col: Color, count: int = 12,
		speed: float = 3.5, size: float = 0.08, life: float = 0.8) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := GPUParticles3D.new()
	p.amount = maxi(1, count)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = true
	p.local_coords = false

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 70.0
	mat.initial_velocity_min = speed * 0.4
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0, -9.0, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	mat.damping_min = 1.0
	mat.damping_max = 3.0
	mat.color = col
	p.process_material = mat

	var mb := MeshBuilder.new()
	mb.box(Transform3D.IDENTITY, Vector3(size, size, size), Color.WHITE)
	p.draw_pass_1 = mb.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.vertex_color_use_as_albedo = false
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.roughness = 0.9
	p.material_override = m

	parent.add_child(p)
	p.global_position = pos
	_autofree(p, life + 0.5)

## 위로 떠오르며 사라지는 데미지 숫자
static func float_text(parent: Node, pos: Vector3, text: String, col: Color,
		size: float = 0.5) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := Label3D.new()
	l.text = text
	l.modulate = col
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.outline_size = 8
	l.font_size = 48
	l.pixel_size = 0.0032 * size / 0.5
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	l.shaded = false
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position", pos + Vector3(randf_range(-0.3, 0.3), 1.4,
		randf_range(-0.3, 0.3)), 1.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)

## 불꽃(모닥불·횃불·용암)
static func fire(parent: Node, scale_v: float = 1.0, col: Color = Color(1.0, 0.55, 0.15)) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = int(18 * scale_v)
	p.lifetime = 0.9
	p.preprocess = 0.5
	p.local_coords = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 12.0
	mat.initial_velocity_min = 0.7 * scale_v
	mat.initial_velocity_max = 1.5 * scale_v
	mat.gravity = Vector3(0, 1.2 * scale_v, 0)
	mat.scale_min = 0.5 * scale_v
	mat.scale_max = 1.1 * scale_v
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.22 * scale_v
	var grad := Gradient.new()
	grad.set_color(0, col)
	grad.set_color(1, Color(0.25, 0.05, 0.02, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	mat.color_ramp = gt
	p.process_material = mat
	var mb := MeshBuilder.new()
	mb.box(Transform3D.IDENTITY, Vector3(0.16, 0.16, 0.16), Color.WHITE)
	p.draw_pass_1 = mb.commit()
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p.material_override = m
	parent.add_child(p)
	return p

## 연기 · 안개 기둥
static func smoke(parent: Node, scale_v: float = 1.0,
		col: Color = Color(0.5, 0.5, 0.5, 0.4)) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = int(10 * scale_v)
	p.lifetime = 3.5
	p.local_coords = false
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 20.0
	mat.initial_velocity_min = 0.6
	mat.initial_velocity_max = 1.3
	mat.gravity = Vector3(0.4, 0.8, 0.1)
	mat.scale_min = 0.8 * scale_v
	mat.scale_max = 2.2 * scale_v
	var grad := Gradient.new()
	grad.set_color(0, col)
	grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	mat.color_ramp = gt
	p.process_material = mat
	var mb := MeshBuilder.new()
	mb.box(Transform3D.IDENTITY, Vector3(0.4, 0.4, 0.4), Color.WHITE)
	p.draw_pass_1 = mb.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p.material_override = m
	parent.add_child(p)
	return p

static func _autofree(n: Node, t: float) -> void:
	var tm := Timer.new()
	tm.one_shot = true
	tm.wait_time = t
	n.add_child(tm)
	tm.timeout.connect(n.queue_free)
	tm.start()
