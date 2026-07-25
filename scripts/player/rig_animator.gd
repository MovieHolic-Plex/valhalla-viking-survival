class_name RigAnimator
extends RefCounted
## 절차적(코드 기반) 캐릭터 애니메이션.
## 스켈레톤/애니메이션 파일 없이 리그 노드의 회전만으로 걷기·공격·방어를 만든다.
## 인간형과 네발짐승 모두 지원.

var rig: Node3D
var hips: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var body: Node3D                # 네발짐승
var legs4: Array[Node3D] = []
var neck: Node3D
var tail: Node3D
var wings: Array[Node3D] = []

var is_quad := false
var is_flyer := false
var base_hips_y := 0.0

var t := 0.0
var swing := 0.0                # 0~1 공격 진행도
var swing_kind := "slash"
var block_amt := 0.0
var hit_flash := 0.0
var stagger := 0.0

func _init(r: Node3D) -> void:
	rig = r
	hips = r.get_node_or_null("hips")
	if hips:
		head = hips.get_node_or_null("head_pivot")
		arm_l = hips.get_node_or_null("arm_l")
		arm_r = hips.get_node_or_null("arm_r")
		leg_l = hips.get_node_or_null("leg_l")
		leg_r = hips.get_node_or_null("leg_r")
		base_hips_y = hips.position.y
	body = r.get_node_or_null("body")
	if body:
		is_quad = true
		base_hips_y = body.position.y
		neck = body.get_node_or_null("neck")
		tail = body.get_node_or_null("tail")
		for n in ["leg_fl", "leg_fr", "leg_bl", "leg_br"]:
			var l := body.get_node_or_null(n)
			if l:
				legs4.append(l)
		for n in ["wing_l", "wing_r"]:
			var w := body.get_node_or_null(n)
			if w:
				wings.append(w)
				is_flyer = true

## speed01: 0(정지)~1(전력질주), airborne: 공중, swimming: 수영
func update(delta: float, speed01: float, airborne: bool, swimming: bool,
		dead: bool = false) -> void:
	t += delta * (1.0 + speed01 * 5.0)
	if swing > 0.0:
		swing = maxf(0.0, swing - delta * 3.4)
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta * 4.0)
	if stagger > 0.0:
		stagger = maxf(0.0, stagger - delta * 2.0)

	if dead:
		_pose_dead(delta)
		return
	if is_quad:
		_anim_quad(delta, speed01, airborne)
	else:
		_anim_humanoid(delta, speed01, airborne, swimming)

# ─────────────────────────────────────────────── 인간형
func _anim_humanoid(delta: float, speed01: float, airborne: bool, swimming: bool) -> void:
	if hips == null:
		return
	var amp: float = lerpf(0.06, 0.95, speed01)
	var s := sin(t * 2.0)
	var c := cos(t * 2.0)

	if swimming:
		hips.position.y = base_hips_y - 0.45
		hips.rotation.x = lerp_angle(hips.rotation.x, -1.15, delta * 6.0)
		if arm_l: arm_l.rotation.x = -1.4 + s * 0.9
		if arm_r: arm_r.rotation.x = -1.4 - s * 0.9
		if leg_l: leg_l.rotation.x = -1.2 + c * 0.35
		if leg_r: leg_r.rotation.x = -1.2 - c * 0.35
		return

	hips.rotation.x = lerp_angle(hips.rotation.x, 0.0, delta * 8.0)
	# 걷기: 몸이 위아래로 통통
	hips.position.y = base_hips_y + absf(s) * 0.05 * speed01 - (0.06 if airborne else 0.0)
	hips.rotation.y = sin(t * 2.0) * 0.06 * speed01

	if airborne:
		if leg_l: leg_l.rotation.x = -0.5
		if leg_r: leg_r.rotation.x = 0.25
	else:
		if leg_l: leg_l.rotation.x = s * amp * 0.75
		if leg_r: leg_r.rotation.x = -s * amp * 0.75

	# 팔: 공격/방어가 우선
	var idle_l := -s * amp * 0.55 + sin(t * 0.6) * 0.03
	var idle_r := s * amp * 0.55 + cos(t * 0.55) * 0.03

	if swing > 0.0:
		var p := 1.0 - swing         # 0 -> 1 진행
		match swing_kind:
			"stab":
				if arm_r:
					arm_r.rotation.x = lerpf(-0.4, -1.75, sin(p * PI))
					arm_r.rotation.z = 0.0
			"bow":
				if arm_r:
					arm_r.rotation.x = -1.45
					arm_r.rotation.z = 0.25
				if arm_l:
					arm_l.rotation.x = -1.45
					arm_l.rotation.z = -0.25
			"chop":
				if arm_r:
					arm_r.rotation.x = lerpf(-2.5, 0.9, smoothstep(0.0, 0.55, p))
					arm_r.rotation.z = 0.15
			_:  # slash — 위에서 대각선으로
				if arm_r:
					arm_r.rotation.x = lerpf(-2.3, 0.75, smoothstep(0.0, 0.5, p))
					arm_r.rotation.z = lerpf(-0.9, 0.7, smoothstep(0.0, 0.6, p))
		if arm_l and swing_kind != "bow":
			arm_l.rotation.x = lerpf(arm_l.rotation.x, idle_l * 0.3, delta * 10.0)
	else:
		if arm_r:
			arm_r.rotation.x = lerp_angle(arm_r.rotation.x, idle_r, delta * 9.0)
			arm_r.rotation.z = lerp_angle(arm_r.rotation.z, 0.0, delta * 9.0)
		if arm_l:
			var target_l: float = lerpf(idle_l, -1.5, block_amt)
			arm_l.rotation.x = lerp_angle(arm_l.rotation.x, target_l, delta * 9.0)
			arm_l.rotation.z = lerp_angle(arm_l.rotation.z, -0.35 * block_amt, delta * 9.0)

	# 피격 경직
	if stagger > 0.0:
		hips.rotation.x += sin(t * 30.0) * 0.06 * stagger
	if head:
		head.rotation.y = sin(t * 0.4) * 0.10

# ─────────────────────────────────────────────── 네발짐승
func _anim_quad(delta: float, speed01: float, airborne: bool) -> void:
	if body == null:
		return
	var amp: float = lerpf(0.05, 0.85, speed01)
	body.position.y = base_hips_y + absf(sin(t * 2.0)) * 0.04 * speed01
	body.rotation.x = sin(t * 2.0) * 0.03 * speed01
	for i in legs4.size():
		var phase: float = t * 2.0 + (PI if (i == 0 or i == 3) else 0.0)
		legs4[i].rotation.x = sin(phase) * amp * 0.8
	if neck:
		neck.rotation.x = sin(t * 1.0) * 0.06 - speed01 * 0.12
		if swing > 0.0:
			neck.rotation.x = lerpf(0.6, -0.5, 1.0 - swing)
	if tail:
		tail.rotation.y = sin(t * 3.0) * 0.35
		tail.rotation.x = 0.2 + sin(t * 2.2) * 0.15
	for i in wings.size():
		var dir := 1.0 if i == 1 else -1.0
		wings[i].rotation.z = sin(t * 5.0) * 0.9 * dir
	if stagger > 0.0:
		body.rotation.z = sin(t * 26.0) * 0.08 * stagger

func _pose_dead(delta: float) -> void:
	var root := hips if hips else body
	if root == null:
		return
	root.rotation.z = lerp_angle(root.rotation.z, PI * 0.5, delta * 3.0)
	root.position.y = lerpf(root.position.y, 0.25, delta * 3.0)

# ─────────────────────────────────────────────── 트리거
func attack(kind: String = "slash") -> void:
	swing_kind = kind
	swing = 1.0

func set_block(on: bool, delta: float) -> void:
	block_amt = move_toward(block_amt, 1.0 if on else 0.0, delta * 6.0)

func hit() -> void:
	hit_flash = 1.0
	stagger = maxf(stagger, 0.6)

func knock(strength: float) -> void:
	stagger = clampf(strength, 0.0, 1.5)
