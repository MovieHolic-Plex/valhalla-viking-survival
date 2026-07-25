class_name RemotePlayer
extends Node3D
## 다른 접속자의 아바타. 호스트가 중계한 위치/자세를 부드럽게 따라간다.
##
## 물리를 돌리지 않는다(권위는 각 피어 본인에게 있다). 받은 좌표로 보간만 하고,
## 이동 속도로 걷기 애니메이션을 흉내낸다. 15Hz 로 오는 갱신 사이를 메우는 게 목적.

const LERP_RATE := 12.0

var peer_id := 0
var player_name := "바이킹"

var rig: Node3D
var anim: RigAnimator
var _tag: Label3D
var _hp_bar: Sprite3D

var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _speed01 := 0.0
var _hp_frac := 1.0
var _first := true

func _ready() -> void:
	add_to_group("remote_player")
	rig = MeshFactory.humanoid_skeletal({
		"skin": Color(0.78, 0.62, 0.50),
		"cloth": Color(0.36, 0.30, 0.24),
		"hair": Color(0.32, 0.22, 0.13),
		"beard": true,
		"height": 1.8,
	})
	add_child(rig)
	anim = RigAnimator.new(rig)

	_tag = Label3D.new()
	_tag.text = player_name
	_tag.font_size = 30
	_tag.pixel_size = 0.0035
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.outline_size = 8
	_tag.modulate = Color(0.92, 0.90, 0.76)
	_tag.position = Vector3(0, 2.25, 0)
	add_child(_tag)

func set_player_name(n: String) -> void:
	player_name = n
	if _tag != null:
		_tag.text = n

func apply_state(pos: Vector3, yaw: float, vel: Vector3, hp_frac: float) -> void:
	_target_pos = pos
	_target_yaw = yaw
	_hp_frac = hp_frac
	_speed01 = clampf(Vector3(vel.x, 0.0, vel.z).length() / 5.0, 0.0, 1.0)
	if _first:
		_first = false
		global_position = pos
		rig.rotation.y = yaw

func _process(delta: float) -> void:
	var t: float = clampf(delta * LERP_RATE, 0.0, 1.0)
	global_position = global_position.lerp(_target_pos, t)
	rig.rotation.y = lerp_angle(rig.rotation.y, _target_yaw, t)
	if anim != null:
		anim.update(delta, _speed01, false, false)
	# 너무 멀어지면(순간이동/포탈) 보간을 포기하고 즉시 붙인다
	if global_position.distance_to(_target_pos) > 25.0:
		global_position = _target_pos
