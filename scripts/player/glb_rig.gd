extends Node3D
class_name GlbRig
## KayKit Adventurers "Barbarian" (CC0, Kay Lousberg) 기반 플레이어 리그.
##
## 코드 생성 스켈레탈 리그(MeshFactory.humanoid_skeletal) 대신 실제 리깅된
## GLB 모델 + AnimationPlayer 클립을 쓴다. RigAnimator 와 같은 인터페이스
## (update / attack / set_block / hit / knock)를 제공하므로 player.gd 는
## 어느 쪽이든 동일하게 호출한다. 파일이 없으면 player.gd 가 코드 리그로
## 대체한다.

const PATH := "res://assets/models/Barbarian.glb"
const CHAR_HEIGHT := 1.8
const BLEND := 0.12

## 무기 소품 — 게임의 절차적 무기 시스템과 겹치므로 숨긴다
const HIDE_PROPS := ["1H_Axe", "1H_Axe_Offhand", "2H_Axe", "Mug",
	"Barbarian_Round_Shield"]
## 루프 재생할 클립
const LOOPS := ["Idle", "Walking_A", "Walking_B", "Walking_Backwards",
	"Running_A", "Running_B", "Blocking", "Jump_Idle"]
const ATTACK_CLIPS := {
	"slash": "1H_Melee_Attack_Slice_Diagonal",
	"chop": "1H_Melee_Attack_Chop",
	"stab": "1H_Melee_Attack_Stab",
	"bow": "1H_Ranged_Shoot",
	"crush": "2H_Melee_Attack_Chop",
}

var hand_r: Node3D
var hand_l: Node3D

var _ap: AnimationPlayer
var _cur := ""
var _oneshot_left := 0.0
var _block := false
var _dead := false

## 파일이 있을 때만 리그를 만든다 (없으면 null — 호출측이 폴 fallback)
static func create() -> GlbRig:
	if not ResourceLoader.exists(PATH):
		return null
	return GlbRig.new()

func _init() -> void:
	var inst: Node3D = load(PATH).instantiate()
	add_child(inst)
	# 키 정규화 — 스킨드 메시(몸통) AABB 만으로 1.8m 에 맞춘다.
	# 무기/망토 등 부착 소품은 바인드 포즈가 제각각이라 범위에서 제외.
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).skin == null:
			continue
		var b: AABB = (mi as MeshInstance3D).get_aabb()
		mn = mn.min(b.position)
		mx = mx.max(b.position + b.size)
	var h: float = max(mx.y - mn.y, 0.01)
	var s := CHAR_HEIGHT / h
	inst.scale = Vector3.ONE * s
	inst.position.y = -mn.y * s
	for pn in HIDE_PROPS:
		var n := inst.find_child(pn, true, false)
		if n:
			n.visible = false
	_ap = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skel := inst.find_child("Skeleton3D", true, false) as Skeleton3D
	hand_r = _mk_slot(skel, "handslot.r")
	hand_l = _mk_slot(skel, "handslot.l")
	for lp in LOOPS:
		if _ap.has_animation(lp):
			_ap.get_animation(lp).loop_mode = Animation.LOOP_LINEAR
	_play("Idle")

func _mk_slot(skel: Skeleton3D, bone: String) -> BoneAttachment3D:
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skel.add_child(ba)
	return ba

func _play(clip: String, blend: float = BLEND) -> bool:
	if _cur == clip or not _ap.has_animation(clip):
		return false
	_ap.play(clip, blend)
	_cur = clip
	return true

## RigAnimator 호환 인터페이스 ─────────────────────────
func update(delta: float, speed01: float, airborne: bool, swimming: bool,
		dead: bool = false) -> void:
	if dead:
		if not _dead:
			_dead = true
			_play("Death_A", 0.08)
		return
	if _oneshot_left > 0.0:
		_oneshot_left -= delta
		return
	if airborne:
		_play("Jump_Idle")
	elif swimming:
		_play("Idle")
	elif _block:
		_play("Blocking")
	elif speed01 > 0.55:
		_play("Running_A")
	elif speed01 > 0.06:
		_play("Walking_A")
	else:
		_play("Idle")

func attack(kind: String = "slash") -> void:
	var clip: String = ATTACK_CLIPS.get(kind, ATTACK_CLIPS["slash"])
	if _play(clip, 0.06):
		_oneshot_left = _ap.get_animation(clip).length

func set_block(on: bool, _delta: float) -> void:
	_block = on

func hit() -> void:
	if _play("Hit_A", 0.05):
		_oneshot_left = _ap.get_animation("Hit_A").length

func knock(_strength: float) -> void:
	if _play("Hit_B", 0.05):
		_oneshot_left = _ap.get_animation("Hit_B").length
