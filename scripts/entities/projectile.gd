class_name Projectile
extends Node3D
## 화살 · 투사체. 레이캐스트 스윕으로 이동해 빠른 속도에서도 관통 버그가 없다.

var dmg: Dictionary = {}
var vel := Vector3.ZERO
var shooter: Node = null
var life := 12.0
var gravity := 9.0
var hit_player := false     # 적이 쏜 투사체인가
var knockback := 15.0
var trail_col := Color(0.8, 0.8, 0.7)

static func make(damage: Dictionary, col: Color, from: Node,
		toward_player: bool = false) -> Projectile:
	var p := Projectile.new()
	p.dmg = damage.duplicate()
	p.shooter = from
	p.hit_player = toward_player
	p.trail_col = col
	return p

func launch(pos: Vector3, velocity: Vector3) -> void:
	global_position = pos
	vel = velocity
	look_at_safe(pos + velocity)

func _ready() -> void:
	var mb := MeshBuilder.new()
	mb.cyl(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, -0.4)),
		0.018, 0.018, 0.8, 5, Color(0.42, 0.30, 0.18))
	mb.cone(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -0.4)),
		0.035, 0.14, 5, trail_col)
	for i in range(3):
		var a := TAU * float(i) / 3.0
		mb.quad(Vector3(0, 0, 0.34), Vector3(cos(a) * 0.06, sin(a) * 0.06, 0.34),
			Vector3(cos(a) * 0.06, sin(a) * 0.06, 0.42), Vector3(0, 0, 0.42),
			Color(0.92, 0.92, 0.86))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	mi.material_override = MatLib.flat(Color.WHITE, 0.6)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if trail_col.get_luminance() > 0.55 or dmg.has(Const.Dmg.FIRE):
		var l := OmniLight3D.new()
		l.light_color = trail_col
		l.light_energy = 1.2
		l.omni_range = 4.0
		add_child(l)

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	vel.y -= gravity * delta
	var from := global_position
	var to := from + vel * delta
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = Const.L_WORLD | Const.L_BUILDING | Const.L_RESOURCE \
		| (Const.L_PLAYER if hit_player else Const.L_ENEMY)
	if shooter != null and is_instance_valid(shooter) and shooter is CollisionObject3D:
		q.exclude = [shooter.get_rid()]
	var hit := space.intersect_ray(q)
	if hit:
		_impact(hit["position"], hit["collider"])
		return
	global_position = to
	look_at_safe(to + vel)

func look_at_safe(target: Vector3) -> void:
	var d := target - global_position
	if d.length() > 0.001 and absf(d.normalized().dot(Vector3.UP)) < 0.999:
		look_at(target, Vector3.UP)

func _impact(pos: Vector3, col) -> void:
	var scene := get_tree().current_scene
	Sfx.play_at("arrow_hit", pos, scene, -6.0)
	Fx.burst(scene, pos, trail_col, 6, 2.0, 0.05, 0.5)
	if col != null and is_instance_valid(col):
		if col is ResourceNode:
			col.take_hit(dmg, 0, pos, shooter)
		elif col.has_method("take_hit"):
			col.take_hit(dmg, pos, shooter, knockback)
	queue_free()
