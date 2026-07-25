class_name ItemDrop
extends Area3D
## 바닥에 떨어진 아이템. 물리 엔진 대신 간단한 낙하 + 회전으로 처리해
## 리지드바디 특유의 떨림/터널링 버그를 피한다.

var item_id: String = "wood"
var amount: int = 1
var quality: int = 1

var _vel := Vector3.ZERO
var _grounded := false
var _spin := 0.0
var _life := 0.0
var _mi: MeshInstance3D

const PICKUP_RADIUS := 1.9
const MAX_LIFE := 1800.0     # 30분 뒤 소멸(월드 오염 방지)

static func spawn(parent: Node, pos: Vector3, id: String, amt: int, q: int = 1,
		impulse: Vector3 = Vector3.ZERO) -> ItemDrop:
	if amt <= 0 or not ItemDB.has_item(id):
		return null
	var d := ItemDrop.new()
	d.item_id = id
	d.amount = amt
	d.quality = q
	parent.add_child(d)
	d.global_position = pos
	d._vel = impulse
	return d

func _ready() -> void:
	collision_layer = Const.L_ITEM
	collision_mask = 0
	monitoring = false
	monitorable = false
	add_to_group("item_drop")

	_mi = MeshInstance3D.new()
	_mi.mesh = MeshFactory.drop_mesh(item_id)
	_mi.material_override = MatLib.flat(ItemDB.color_of(item_id), 0.7, 0.15)
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)

	# 눈에 띄도록 은은한 빛
	var l := OmniLight3D.new()
	l.light_color = ItemDB.color_of(item_id).lightened(0.4)
	l.light_energy = 0.35
	l.omni_range = 3.0
	l.shadow_enabled = false
	add_child(l)

func _physics_process(delta: float) -> void:
	_life += delta
	if _life > MAX_LIFE:
		queue_free()
		return
	_spin += delta * 1.6
	if _mi:
		_mi.rotation.y = _spin
		_mi.position.y = 0.18 + sin(_spin * 1.7) * 0.06 if _grounded else 0.0

	if not _grounded:
		_vel.y -= 22.0 * delta
		var next := global_position + _vel * delta
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(
			global_position + Vector3(0, 0.4, 0), next - Vector3(0, 0.25, 0))
		q.collision_mask = Const.L_WORLD | Const.L_BUILDING
		var hit := space.intersect_ray(q)
		if hit:
			global_position = hit["position"]
			_grounded = true
			_vel = Vector3.ZERO
		else:
			global_position = next
			# 안전장치: 월드 밑으로 새면 제거
			if global_position.y < -200.0:
				queue_free()

## 플레이어가 근처에 오면 호출된다
func try_pickup(player) -> bool:
	if not is_instance_valid(player):
		return false
	var inv = player.inventory
	var left: int = inv.add_item(item_id, amount, quality)
	if left == amount:
		return false
	amount = left
	if amount <= 0:
		queue_free()
		return true
	return true

func label() -> String:
	if amount > 1:
		return "%s x%d" % [ItemDB.name_of(item_id), amount]
	return ItemDB.name_of(item_id)
