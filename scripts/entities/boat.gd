class_name Boat
extends CharacterBody3D
## 배 — 뗏목 · 카르베 · 롱십.
## 파도에 따라 오르내리고, 돛은 바람 방향에 영향을 받는다.
## 물리 엔진의 부력 시뮬레이션 대신 수면 높이를 직접 따라가게 해 뒤집힘 버그를 없앴다.

signal destroyed(boat)

var kind := "raft"
var cfg: Dictionary = {}
var hp := 300.0
var max_hp := 300.0
var storage: Inventory = null

var speed_step := 0            # -1 후진 · 0 정지 · 1 저속 · 2 중속 · 3 전속
var rudder := 0.0              # -1 ~ 1
var pilot: Node3D = null

var _yaw := 0.0
var _vel := 0.0
var _sail: Node3D
var _sail_mesh: MeshInstance3D
var _seat: Node3D
var _label: Label3D
var _wave_t := 0.0

const KINDS := {
	"raft": {
		"n": "PIECE_RAFT", "len": 4.0, "wid": 3.0, "hp": 300.0,
		"speed": [0.0, 2.0, 3.2, 4.2], "turn": 0.9, "sail": 0.55,
		"cargo": 0, "col": Color(0.52, 0.38, 0.22),
		"mats": {"wood": 20, "leather_scraps": 6, "resin": 6},
	},
	"karve": {
		"n": "PIECE_KARVE", "len": 7.0, "wid": 2.6, "hp": 500.0,
		"speed": [0.0, 3.0, 5.5, 7.5], "turn": 1.15, "sail": 0.85,
		"cargo": 8, "col": Color(0.60, 0.45, 0.26),
		"mats": {"fine_wood": 30, "deer_hide": 10, "resin": 20, "bronze_nails": 80},
	},
	"longship": {
		"n": "PIECE_LONGSHIP", "len": 11.0, "wid": 3.4, "hp": 1000.0,
		"speed": [0.0, 3.4, 6.5, 9.5], "turn": 0.8, "sail": 1.0,
		"cargo": 18, "col": Color(0.46, 0.33, 0.20),
		"mats": {"ancient_bark": 40, "deer_hide": 10, "iron_nails": 100, "fine_wood": 40},
	},
}

static func make(k: String) -> Boat:
	var b := Boat.new()
	b.kind = k
	b.cfg = KINDS.get(k, KINDS["raft"])
	return b

func _ready() -> void:
	if cfg.is_empty():
		cfg = KINDS.get(kind, KINDS["raft"])
	add_to_group("boat")
	add_to_group("interactable")
	collision_layer = Const.L_BUILDING
	collision_mask = Const.L_WORLD
	max_hp = float(cfg["hp"])
	hp = max_hp
	_yaw = rotation.y

	var l: float = cfg["len"]
	var w: float = cfg["wid"]
	var col: Color = cfg["col"]

	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, 1.2, l)
	shape.shape = bs
	shape.position = Vector3(0, 0.6, 0)
	add_child(shape)

	_build_hull(l, w, col)

	if int(cfg.get("cargo", 0)) > 0:
		storage = Inventory.new(int(cfg["cargo"]) / 2, 2)

	_seat = Node3D.new()
	_seat.name = "seat"
	_seat.position = Vector3(0, 1.0, l * 0.34)
	add_child(_seat)

	_label = Label3D.new()
	_label.font_size = 34
	_label.pixel_size = 0.004
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 8
	_label.modulate = Color(0.92, 0.88, 0.75)
	_label.position = Vector3(0, 2.4, 0)
	_label.visible = false
	add_child(_label)

func _build_hull(l: float, w: float, col: Color) -> void:
	var mb := MeshBuilder.new()
	var dark := col.darkened(0.25)
	# 선체 바닥 판자
	var planks := 5
	for i in range(planks):
		var t := (float(i) + 0.5) / float(planks)
		var x: float = lerp(-w * 0.5, w * 0.5, t)
		mb.box(Transform3D(Basis.IDENTITY, Vector3(x, 0.25, 0)),
			Vector3(w / float(planks) * 0.92, 0.18, l * 0.94),
			col.lightened(float(i % 2) * 0.07))
	# 뱃전
	for sx in [-1.0, 1.0]:
		mb.box(Transform3D(Basis.IDENTITY, Vector3(w * 0.5 * sx, 0.55, 0)),
			Vector3(0.16, 0.55, l * 0.94), dark)
	# 뱃머리 / 고물 (뾰족하게)
	mb.tri(Vector3(-w * 0.5, 0.35, -l * 0.47), Vector3(w * 0.5, 0.35, -l * 0.47),
		Vector3(0, 0.55, -l * 0.62), dark)
	mb.tri(Vector3(w * 0.5, 0.35, l * 0.47), Vector3(-w * 0.5, 0.35, l * 0.47),
		Vector3(0, 0.55, l * 0.60), dark)
	if kind != "raft":
		# 용머리 장식
		mb.rod(Vector3(0, 0.5, -l * 0.60), Vector3(0, 1.7, -l * 0.72), 0.09, 6, dark)
		mb.sphere(Vector3(0, 1.8, -l * 0.74), 0.20, 6, 4, col.lightened(0.15))
	var hull := MeshInstance3D.new()
	hull.name = "hull"
	hull.mesh = mb.commit()
	hull.material_override = MatLib.flat(Color.WHITE, 0.85)
	add_child(hull)

	# 돛대 + 돛
	_sail = Node3D.new()
	_sail.name = "sail"
	_sail.position = Vector3(0, 0.5, -l * 0.05)
	add_child(_sail)
	var sm := MeshBuilder.new()
	var mast_h: float = l * 0.75
	sm.cyl(Transform3D.IDENTITY, 0.11, 0.08, mast_h, 6, Color(0.42, 0.31, 0.19))
	sm.box(Transform3D(Basis.IDENTITY, Vector3(0, mast_h * 0.82, 0)),
		Vector3(w * 1.25, 0.09, 0.09), Color(0.42, 0.31, 0.19))
	var mast := MeshInstance3D.new()
	mast.mesh = sm.commit()
	mast.material_override = MatLib.flat(Color.WHITE)
	_sail.add_child(mast)

	var cloth := MeshBuilder.new()
	cloth.quad(Vector3(-w * 0.6, mast_h * 0.80, 0), Vector3(w * 0.6, mast_h * 0.80, 0),
		Vector3(w * 0.6, mast_h * 0.30, 0.05), Vector3(-w * 0.6, mast_h * 0.30, 0.05),
		Color(0.88, 0.84, 0.74))
	# 붉은 줄무늬 — 바이킹 돛
	cloth.quad(Vector3(-w * 0.2, mast_h * 0.795, -0.01),
		Vector3(w * 0.2, mast_h * 0.795, -0.01),
		Vector3(w * 0.2, mast_h * 0.305, 0.04),
		Vector3(-w * 0.2, mast_h * 0.305, 0.04), Color(0.68, 0.22, 0.18))
	_sail_mesh = MeshInstance3D.new()
	_sail_mesh.mesh = cloth.commit()
	_sail_mesh.material_override = MatLib.foliage(Color.WHITE, 0.5, 0.035)
	_sail.add_child(_sail_mesh)
	_sail_mesh.visible = false

# ═══════════════════════════════════════════════ 조종
func can_interact(_p) -> bool:
	return true

func prompt() -> String:
	if pilot != null:
		return tr("PROMPT_DISEMBARK")
	return tr("PROMPT_EMBARK") % tr(str(cfg.get("n", "PIECE_RAFT")))

func interact(player) -> void:
	if pilot != null:
		_dismount()
	else:
		_mount(player)

func _mount(player) -> void:
	pilot = player
	player.set_meta("boat", self)
	player.velocity = Vector3.ZERO
	_label.visible = true
	Sfx.play_at("build", global_position, get_tree().current_scene, -14.0, 0.7)

func _dismount() -> void:
	if pilot != null and is_instance_valid(pilot):
		pilot.remove_meta("boat")
		# 배 옆 물가로 내린다
		var side := global_transform.basis.x * (float(cfg["wid"]) * 0.5 + 1.0)
		pilot.global_position = global_position + side + Vector3(0, 1.0, 0)
	pilot = null
	speed_step = 0
	_label.visible = false

func _physics_process(delta: float) -> void:
	_wave_t += delta

	if pilot != null and is_instance_valid(pilot):
		_read_controls(delta)
		pilot.global_position = _seat.global_position
		pilot.velocity = Vector3.ZERO
		_label.text = "%s  %d/3" % [tr(str(cfg.get("n", ""))), speed_step]
	else:
		speed_step = 0
		rudder = 0.0

	# 바람: 돛을 편 상태에서 순풍이면 빨라진다
	var wind_bonus := 1.0
	var sky = get_tree().current_scene.get_node_or_null("sky")
	if sky != null and speed_step > 0:
		var wind_dir := Vector3(cos(GameState.time_of_day * TAU * 0.3), 0,
			sin(GameState.time_of_day * TAU * 0.3))
		var fwd := -global_transform.basis.z
		var align: float = clampf(wind_dir.dot(fwd), -1.0, 1.0)
		if GameState.power_is_active("moder"):
			align = 1.0
		wind_bonus = lerpf(0.55, 1.35, (align + 1.0) * 0.5) \
			* (1.0 + float(sky.wind_strength) * 0.25 * float(cfg["sail"]))
	_sail_mesh.visible = speed_step > 0

	var speeds: Array = cfg["speed"]
	var target: float = 0.0
	if speed_step > 0:
		target = float(speeds[mini(speed_step, speeds.size() - 1)]) * wind_bonus
	elif speed_step < 0:
		target = -float(speeds[1]) * 0.6
	_vel = move_toward(_vel, target, delta * 2.2)

	if absf(_vel) > 0.05:
		_yaw -= rudder * float(cfg["turn"]) * delta * clampf(absf(_vel) / 4.0, 0.25, 1.4) \
			* signf(_vel)
	rotation.y = _yaw

	var fwd2 := -Vector3(sin(_yaw), 0, cos(_yaw))
	velocity = fwd2 * _vel

	# 수면 추종: 파도 높이 + 좌우 흔들림
	var surf := Const.WATER_LEVEL + sin(_wave_t * 0.9 + global_position.x * 0.05) * 0.22 \
		+ sin(_wave_t * 1.3 + global_position.z * 0.04) * 0.14
	var ground := GameState.height_at(global_position.x, global_position.z)
	if ground > Const.WATER_LEVEL - 0.4:
		# 좌초 — 속도를 잃고 멈춘다
		_vel = move_toward(_vel, 0.0, delta * 6.0)
		surf = maxf(surf, ground + 0.3)
	velocity.y = (surf - global_position.y) * 4.0
	move_and_slide()

	rotation.x = sin(_wave_t * 1.1) * 0.035
	rotation.z = sin(_wave_t * 0.8 + 1.2) * 0.045 - rudder * 0.06

	# 항적 물보라
	if absf(_vel) > 2.0 and randf() < delta * 6.0:
		Fx.burst(get_tree().current_scene,
			global_position - global_transform.basis.z * float(cfg["len"]) * -0.45
			+ Vector3(0, 0.2, 0), Color(0.85, 0.92, 0.96), 4, 1.5, 0.05, 0.5)

func _read_controls(delta: float) -> void:
	if pilot.input_locked:
		return
	if Input.is_action_just_pressed("move_forward"):
		speed_step = clampi(speed_step + 1, -1, 3)
	if Input.is_action_just_pressed("move_back"):
		speed_step = clampi(speed_step - 1, -1, 3)
	var turn := Input.get_axis("move_left", "move_right")
	rudder = move_toward(rudder, turn, delta * 3.0)

# ═══════════════════════════════════════════════ 내구도
func take_hit(dmg: Dictionary, from_pos: Vector3, _attacker = null,
		_kb: float = 0.0) -> void:
	var total := 0.0
	for k in dmg:
		total += float(dmg[k])
	hp -= total
	Fx.burst(get_tree().current_scene, from_pos, Color(0.55, 0.42, 0.26), 8, 2.5, 0.06, 0.6)
	if hp <= 0.0:
		_break()

func _break() -> void:
	if pilot != null:
		_dismount()
	var mats: Dictionary = cfg.get("mats", {})
	for id in mats:
		ItemDrop.spawn(get_tree().current_scene, global_position + Vector3(0, 1, 0),
			id, maxi(1, int(mats[id]) / 3))
	if storage != null:
		for i in storage.size():
			var s: Dictionary = storage.get_slot(i)
			if not s.is_empty():
				ItemDrop.spawn(get_tree().current_scene,
					global_position + Vector3(0, 1, 0), s["id"], int(s["amount"]))
	Fx.burst(get_tree().current_scene, global_position + Vector3(0, 0.5, 0),
		Color(0.55, 0.42, 0.26), 30, 5.0, 0.12, 1.2)
	Sfx.play_at("tree_fall", global_position, get_tree().current_scene, -2.0)
	destroyed.emit(self)
	queue_free()

func to_dict() -> Dictionary:
	var d := {"kind": kind, "p": [global_position.x, global_position.y, global_position.z],
		"y": _yaw, "hp": hp}
	if storage != null:
		d["inv"] = storage.to_dict()
	return d

func from_dict(d: Dictionary) -> void:
	hp = float(d.get("hp", max_hp))
	_yaw = float(d.get("y", 0.0))
	rotation.y = _yaw
	if storage != null and d.has("inv"):
		storage.from_dict(d["inv"])
