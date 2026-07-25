class_name ResourceNode
extends StaticBody3D
## 채집 대상: 나무 · 바위 · 광맥 · 덤불 · 바닥 채집물.
## 나무는 벌목(CHOP), 바위/광맥은 채광(PICKAXE) 데미지에만 반응하고
## 도구 등급이 모자라면 아예 흠집도 나지 않는다(발헤임과 동일).

signal destroyed(node)

enum Kind { TREE, LOG, STUMP, ROCK, ORE, BUSH, PICKABLE }

var kind: int = Kind.TREE
var sub: String = "beech"
var max_hp: float = 40.0
var hp: float = 40.0
var required_tier: int = 0
var accept: int = Const.Dmg.CHOP
var drops: Dictionary = {}          # id -> [min, max]
var seed_v: int = 0
var respawn_time: float = 0.0       # >0 이면 채집 후 재생성
var interact_pick := false          # 손으로 줍는가

var _visual: Node3D
var _base_scale := Vector3.ONE
var _shake := 0.0
var _dead := false
var _regrow := -1.0
var _tree_h := 8.0
var _tree_r := 0.4

# ═════════════════════════════════════════════ 팩토리
static func make_tree(subkind: String, sv: int) -> ResourceNode:
	var n := ResourceNode.new()
	n.kind = Kind.TREE
	n.sub = subkind
	n.seed_v = sv
	n.accept = Const.Dmg.CHOP
	match subkind:
		"pine":
			n.max_hp = 80.0; n.required_tier = 0
			n.drops = {"wood": [8, 12], "core_wood": [0, 0], "resin": [1, 3], "pine_cone": [0, 2]}
		"fir":
			n.max_hp = 90.0; n.required_tier = 1
			n.drops = {"core_wood": [8, 12], "resin": [1, 3], "pine_cone": [0, 2]}
		"birch":
			n.max_hp = 100.0; n.required_tier = 2
			n.drops = {"fine_wood": [8, 12], "resin": [1, 2], "beech_seeds": [0, 2]}
		"oak":
			n.max_hp = 180.0; n.required_tier = 3
			n.drops = {"fine_wood": [16, 24], "resin": [2, 5], "beech_seeds": [1, 3]}
		"ancient":
			n.max_hp = 160.0; n.required_tier = 2
			n.drops = {"ancient_bark": [10, 16], "resin": [1, 3]}
		"swamp_dead":
			n.max_hp = 60.0; n.required_tier = 0
			n.drops = {"wood": [5, 9]}
		"yggdrasil":
			n.max_hp = 220.0; n.required_tier = 3
			n.drops = {"yggdrasil_wood": [10, 18], "sap": [0, 2]}
		_:
			n.max_hp = 55.0; n.required_tier = 0
			n.drops = {"wood": [6, 10], "resin": [0, 2], "beech_seeds": [0, 2], "feathers": [0, 1]}
	n.hp = n.max_hp
	return n

static func make_rock(size: float, sv: int) -> ResourceNode:
	var n := ResourceNode.new()
	n.kind = Kind.ROCK
	n.sub = "stone"
	n.seed_v = sv
	n.accept = Const.Dmg.PICKAXE
	n.required_tier = 0
	n.max_hp = 60.0 + size * 40.0
	n.hp = n.max_hp
	n.drops = {"stone": [int(4 + size * 6), int(8 + size * 10)], "flint": [0, 1]}
	n.set_meta("size", size)
	return n

static func make_ore(ore: String, size: float, sv: int) -> ResourceNode:
	var n := ResourceNode.new()
	n.kind = Kind.ORE
	n.sub = ore
	n.seed_v = sv
	n.accept = Const.Dmg.PICKAXE
	n.set_meta("size", size)
	match ore:
		"copper":
			n.required_tier = 1; n.max_hp = 220.0
			n.drops = {"copper_ore": [4, 7], "stone": [2, 4]}
		"tin":
			n.required_tier = 1; n.max_hp = 120.0
			n.drops = {"tin_ore": [3, 5]}
		"iron":
			n.required_tier = 2; n.max_hp = 260.0
			n.drops = {"iron_scrap": [4, 7], "withered_bone": [0, 1]}
		"silver":
			n.required_tier = 3; n.max_hp = 320.0
			n.drops = {"silver_ore": [4, 8], "stone": [2, 4]}
		"obsidian":
			n.required_tier = 3; n.max_hp = 280.0
			n.drops = {"obsidian": [4, 8]}
		"black_metal":
			n.required_tier = 3; n.max_hp = 340.0
			n.drops = {"black_metal_scrap": [3, 6]}
		"flametal":
			n.required_tier = 4; n.max_hp = 420.0
			n.drops = {"flametal_ore": [3, 6]}
		"surtling":
			n.required_tier = 1; n.max_hp = 140.0
			n.drops = {"surtling_core": [1, 2], "stone": [2, 4]}
		_:
			n.required_tier = 1; n.max_hp = 200.0
			n.drops = {"stone": [4, 8]}
	n.hp = n.max_hp
	return n

static func make_bush(subkind: String, sv: int) -> ResourceNode:
	var n := ResourceNode.new()
	n.kind = Kind.BUSH
	n.sub = subkind
	n.seed_v = sv
	n.interact_pick = true
	n.respawn_time = 300.0
	n.max_hp = 1.0
	n.hp = 1.0
	match subkind:
		"blueberry": n.drops = {"blueberries": [2, 4]}
		"cloudberry": n.drops = {"cloudberry": [2, 3]}
		"thistle": n.drops = {"thistle": [1, 2]}
		_: n.drops = {"raspberries": [2, 4]}
	return n

static func make_pickable(subkind: String, sv: int) -> ResourceNode:
	var n := ResourceNode.new()
	n.kind = Kind.PICKABLE
	n.sub = subkind
	n.seed_v = sv
	n.interact_pick = true
	n.respawn_time = 0.0
	n.max_hp = 1.0
	n.hp = 1.0
	match subkind:
		"branch": n.drops = {"wood": [1, 2]}
		"stone": n.drops = {"stone": [1, 2]}
		"flint": n.drops = {"flint": [1, 2]}
		"mushroom": n.drops = {"mushroom": [1, 1]}; n.respawn_time = 400.0
		"dandelion": n.drops = {"dandelion": [1, 1]}
		"thistle": n.drops = {"thistle": [1, 1]}; n.respawn_time = 400.0
		"carrot_seeds": n.drops = {"carrot_seeds": [1, 3]}
		"barley": n.drops = {"barley": [1, 2]}
		"flax": n.drops = {"flax": [1, 2]}
		"surtling_core": n.drops = {"surtling_core": [1, 1]}
		"bone": n.drops = {"bone_fragments": [1, 3]}
		"guck": n.drops = {"guck": [1, 3]}; n.respawn_time = 600.0
		_: n.drops = {"wood": [1, 1]}
	return n

static func make_log(sv: int, radius: float, length: float) -> ResourceNode:
	var n := ResourceNode.new()
	n.kind = Kind.LOG
	n.sub = "log"
	n.seed_v = sv
	n.accept = Const.Dmg.CHOP
	n.required_tier = 0
	n.max_hp = 40.0
	n.hp = 40.0
	n.drops = {"wood": [4, 7]}
	n.set_meta("radius", radius)
	n.set_meta("length", length)
	return n

# ═════════════════════════════════════════════ 생성
func _ready() -> void:
	collision_layer = Const.L_RESOURCE
	collision_mask = 0
	add_to_group("resource_node")
	if interact_pick:
		add_to_group("interactable")
	_build_visual()

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "visual"
	add_child(_visual)
	var shape := CollisionShape3D.new()
	shape.name = "col"

	match kind:
		Kind.TREE:
			var t := MeshFactory.tree(sub, seed_v)
			_tree_h = t["h"]
			_tree_r = t["r"]
			var trunk := MeshInstance3D.new()
			trunk.name = "trunk"
			trunk.mesh = t["trunk"]
			trunk.material_override = MatLib.flat(Color.WHITE, 0.94, 0.0, 0.0, "bark")
			_visual.add_child(trunk)
			var leaves := MeshInstance3D.new()
			leaves.name = "leaves"
			leaves.mesh = t["leaves"]
			leaves.material_override = MatLib.leaf_card()
			_visual.add_child(leaves)
			var cap := CylinderShape3D.new()
			cap.radius = maxf(_tree_r * 1.6, 0.32)
			cap.height = _tree_h * 0.72
			shape.shape = cap
			shape.position = Vector3(0, _tree_h * 0.36, 0)
		Kind.LOG:
			var r: float = get_meta("radius", 0.35)
			var l: float = get_meta("length", 4.0)
			var mb := MeshBuilder.new()
			mb.cyl(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, r, -l * 0.5)),
				r, r * 0.85, l, 8, Color(0.38, 0.27, 0.17))
			var mi := MeshInstance3D.new()
			mi.mesh = mb.commit()
			mi.material_override = MatLib.flat(Color.WHITE, 0.94, 0.0, 0.0, "bark")
			_visual.add_child(mi)
			var bs := BoxShape3D.new()
			bs.size = Vector3(r * 2.0, r * 2.0, l)
			shape.shape = bs
			shape.position = Vector3(0, r, 0)
		Kind.STUMP:
			var mi2 := MeshInstance3D.new()
			mi2.mesh = MeshFactory.stump(get_meta("radius", 0.4))
			mi2.material_override = MatLib.flat(Color.WHITE, 0.94, 0.0, 0.0, "bark")
			_visual.add_child(mi2)
			var cs := CylinderShape3D.new()
			cs.radius = get_meta("radius", 0.4) * 1.2
			cs.height = 0.5
			shape.shape = cs
			shape.position = Vector3(0, 0.25, 0)
		Kind.ROCK:
			var size: float = get_meta("size", 1.0)
			var mi3 := MeshInstance3D.new()
			mi3.mesh = MeshFactory.boulder(size, seed_v)
			mi3.material_override = MatLib.flat(Color.WHITE, 0.98, 0.0, 0.0, "rock")
			_visual.add_child(mi3)
			var sp := SphereShape3D.new()
			sp.radius = size * 0.92
			shape.shape = sp
			shape.position = Vector3(0, size * 0.5, 0)
		Kind.ORE:
			var size2: float = get_meta("size", 1.2)
			var od := MeshFactory.ore_node(sub, size2, seed_v)
			var rock := MeshInstance3D.new()
			rock.mesh = od["rock"]
			rock.material_override = MatLib.flat(Color.WHITE, 0.98, 0.0, 0.0, "rock")
			_visual.add_child(rock)
			var vein := MeshInstance3D.new()
			vein.name = "vein"
			var em: float = od["emission"]
			if em > 0.0:
				vein.material_override = MatLib.glow(od["vein_color"], em)
				var l := OmniLight3D.new()
				l.light_color = od["vein_color"]
				l.light_energy = em
				l.omni_range = size2 * 6.0
				l.position = Vector3(0, size2 * 0.6, 0)
				_visual.add_child(l)
			else:
				vein.material_override = MatLib.flat(Color.WHITE, 0.45, 0.55)
			vein.mesh = od["vein"]
			_visual.add_child(vein)
			var sp2 := SphereShape3D.new()
			sp2.radius = size2 * 0.9
			shape.shape = sp2
			shape.position = Vector3(0, size2 * 0.5, 0)
		Kind.BUSH:
			var b := MeshFactory.bush(sub, seed_v)
			var lv := MeshInstance3D.new()
			lv.mesh = b["leaves"]
			lv.material_override = MatLib.foliage(Color.WHITE, 0.0, 0.10)
			_visual.add_child(lv)
			var fr := MeshInstance3D.new()
			fr.name = "fruit"
			fr.mesh = b["fruit"]
			fr.material_override = MatLib.flat(Color.WHITE, 0.55)
			_visual.add_child(fr)
			var sp3 := SphereShape3D.new()
			sp3.radius = 0.5
			shape.shape = sp3
			shape.position = Vector3(0, 0.35, 0)
		Kind.PICKABLE:
			_build_pickable()
			var sp4 := SphereShape3D.new()
			sp4.radius = 0.35
			shape.shape = sp4
			shape.position = Vector3(0, 0.2, 0)
	if shape.shape != null:
		add_child(shape)
	_base_scale = _visual.scale

func _build_pickable() -> void:
	var mi := MeshInstance3D.new()
	var mb := MeshBuilder.new()
	match sub:
		"branch":
			mb.rod(Vector3(-0.35, 0.06, 0), Vector3(0.35, 0.08, 0.1), 0.045, 5,
				Color(0.36, 0.26, 0.16))
			mb.rod(Vector3(0.05, 0.07, 0.02), Vector3(0.25, 0.10, -0.2), 0.03, 4,
				Color(0.34, 0.24, 0.15))
			mi.material_override = MatLib.flat(Color.WHITE)
		"stone":
			for i in range(3):
				mb.rock(Vector3(randf_range(-0.15, 0.15), 0.07, randf_range(-0.15, 0.15)),
					0.10, seed_v + i, Color(0.50, 0.50, 0.52), 5, 3, 0.3)
			mi.material_override = MatLib.flat(Color.WHITE, 0.98, 0.0, 0.0, "rock")
		"flint":
			for i in range(2):
				mb.rock(Vector3(randf_range(-0.12, 0.12), 0.06, randf_range(-0.12, 0.12)),
					0.09, seed_v + i, Color(0.32, 0.34, 0.36), 5, 3, 0.45)
			mi.material_override = MatLib.flat(Color.WHITE, 0.6)
		"mushroom":
			mi.mesh = MeshFactory.mushroom(seed_v)
			mi.material_override = MatLib.flat(Color.WHITE)
			_visual.add_child(mi)
			return
		"dandelion":
			mi.mesh = MeshFactory.flower(Color(0.95, 0.85, 0.25), seed_v)
			mi.material_override = MatLib.foliage(Color.WHITE, 0.2, 0.08)
			_visual.add_child(mi)
			return
		"thistle":
			mi.mesh = MeshFactory.flower(Color(0.62, 0.36, 0.78), seed_v)
			mi.material_override = MatLib.foliage(Color.WHITE, 0.2, 0.06)
			_visual.add_child(mi)
			var gl := OmniLight3D.new()
			gl.light_color = Color(0.75, 0.55, 0.95)
			gl.light_energy = 0.6
			gl.omni_range = 3.0
			_visual.add_child(gl)
			return
		"barley", "flax":
			var cc := Color(0.85, 0.75, 0.40) if sub == "barley" else Color(0.72, 0.78, 0.58)
			mi.mesh = MeshFactory.crop_plant(1.0, cc, true)
			mi.material_override = MatLib.foliage(Color.WHITE, 0.1, 0.09)
			_visual.add_child(mi)
			return
		"surtling_core":
			mb.box(Transform3D(Basis(Vector3.UP, 0.6), Vector3(0, 0.2, 0)),
				Vector3(0.16, 0.4, 0.16), Color(1.0, 0.45, 0.10))
			mi.material_override = MatLib.glow(Color(1.0, 0.45, 0.10), 2.5)
			var l2 := OmniLight3D.new()
			l2.light_color = Color(1.0, 0.5, 0.15)
			l2.light_energy = 2.0
			l2.omni_range = 6.0
			l2.position = Vector3(0, 0.3, 0)
			_visual.add_child(l2)
		"bone":
			mb.rod(Vector3(-0.25, 0.05, 0), Vector3(0.25, 0.05, 0.06), 0.04, 5,
				Color(0.86, 0.84, 0.76))
			mb.sphere(Vector3(-0.25, 0.05, 0), 0.07, 5, 3, Color(0.88, 0.86, 0.78))
			mb.sphere(Vector3(0.25, 0.05, 0.06), 0.07, 5, 3, Color(0.88, 0.86, 0.78))
			mi.material_override = MatLib.flat(Color.WHITE, 0.7)
		"guck":
			mb.sphere(Vector3(0, 0.18, 0), 0.22, 7, 4, Color(0.30, 0.78, 0.42),
				Vector3(1, 1.3, 1))
			mi.material_override = MatLib.flat(Color.WHITE, 0.25)
			var l3 := OmniLight3D.new()
			l3.light_color = Color(0.35, 0.95, 0.45)
			l3.light_energy = 0.9
			l3.omni_range = 4.0
			_visual.add_child(l3)
		"carrot_seeds":
			mi.mesh = MeshFactory.flower(Color(0.92, 0.92, 0.86), seed_v)
			mi.material_override = MatLib.foliage(Color.WHITE, 0.2, 0.08)
			_visual.add_child(mi)
			return
		_:
			mb.sphere(Vector3(0, 0.12, 0), 0.12, 6, 4, Color(0.6, 0.6, 0.6))
			mi.material_override = MatLib.flat(Color.WHITE)
	mi.mesh = mb.commit()
	_visual.add_child(mi)

# ═════════════════════════════════════════════ 상호작용
func prompt() -> String:
	if kind == Kind.BUSH or kind == Kind.PICKABLE:
		var first := ""
		for k in drops:
			first = k
			break
		return tr("PROMPT_PICK") % ItemDB.name_of(first)
	return ""

func can_interact(_player) -> bool:
	return interact_pick and not _dead

func interact(player) -> void:
	if not interact_pick or _dead:
		return
	_give_drops(player)
	Sfx.play_at("pickup", global_position, get_tree().current_scene, -6.0)
	if respawn_time > 0.0:
		_hide_for_respawn()
	else:
		_finish_destroy()

func _hide_for_respawn() -> void:
	_dead = true
	_regrow = respawn_time
	if _visual:
		_visual.visible = false
	set_process(true)

func _process(delta: float) -> void:
	if _regrow > 0.0:
		_regrow -= delta
		if _regrow <= 0.0:
			_regrow = -1.0
			_dead = false
			hp = max_hp
			if _visual:
				_visual.visible = true
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 4.0)
		if _visual:
			var s := 1.0 + _shake * 0.06
			_visual.scale = _base_scale * Vector3(s, 2.0 - s, s)
			_visual.rotation.z = sin(Time.get_ticks_msec() * 0.05) * _shake * 0.04

# ═════════════════════════════════════════════ 피격
## dmg: {Const.Dmg: 값}, tool_tier: 도구 등급, 반환: 유효 타격 여부
func take_hit(dmg: Dictionary, tool_tier: int, from: Vector3, attacker = null) -> Dictionary:
	if _dead:
		return {"ok": false, "reason": "gone"}
	if interact_pick:
		# 덤불/채집물은 때리면 그냥 채집된다
		if attacker != null and attacker.has_method("get_inventory"):
			_give_drops(attacker)
		if respawn_time > 0.0:
			_hide_for_respawn()
		else:
			_finish_destroy()
		return {"ok": true, "damage": 0.0}

	var amount: float = float(dmg.get(accept, 0.0))
	if amount <= 0.0:
		return {"ok": false, "reason": "wrong_tool"}
	if tool_tier < required_tier:
		Sfx.play_at("metal_hit", global_position, get_tree().current_scene, -4.0, 1.5)
		Fx.float_text(get_tree().current_scene, global_position + Vector3(0, 1.5, 0),
			tr("MSG_TOO_WEAK"), Color(1, 0.5, 0.3), 0.4)
		return {"ok": false, "reason": "too_weak"}

	hp -= amount
	_shake = 1.0
	var col := Color(0.55, 0.38, 0.22)
	var snd := "chop"
	if kind == Kind.ROCK or kind == Kind.ORE:
		col = Color(0.6, 0.6, 0.6)
		snd = "stone_hit"
	Sfx.play_at(snd, from, get_tree().current_scene, -3.0)
	Fx.burst(get_tree().current_scene, from, col, 8, 3.0, 0.07, 0.7)
	Fx.float_text(get_tree().current_scene, from + Vector3(0, 0.4, 0),
		str(int(round(amount))), Color(0.95, 0.95, 0.85), 0.38)

	if hp <= 0.0:
		_on_destroyed(attacker)
		return {"ok": true, "damage": amount, "killed": true}
	return {"ok": true, "damage": amount}

func _on_destroyed(attacker) -> void:
	if kind == Kind.TREE:
		_fell_tree(attacker)
	else:
		_spawn_drops()
		if kind == Kind.ROCK or kind == Kind.ORE:
			Fx.burst(get_tree().current_scene, global_position + Vector3(0, 0.6, 0),
				Color(0.6, 0.6, 0.6), 22, 5.0, 0.11, 1.1)
			Sfx.play_at("stone_hit", global_position, get_tree().current_scene, 2.0, 0.6)
		_finish_destroy()

## 나무가 넘어간다 — 쓰러지는 연출 후 통나무로 변한다
func _fell_tree(attacker) -> void:
	_dead = true
	var scene := get_tree().current_scene
	Sfx.play_at("tree_fall", global_position, scene, 2.0)

	var dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	if attacker != null and is_instance_valid(attacker) and attacker is Node3D:
		var d: Vector3 = global_position - attacker.global_position
		d.y = 0.0
		if d.length() > 0.1:
			dir = d.normalized()

	# 쓰러질 몸통 (원본 비주얼을 떼어내 사용)
	var faller := Node3D.new()
	scene.add_child(faller)
	faller.global_position = global_position
	if _visual:
		var vis := _visual
		remove_child(vis)
		faller.add_child(vis)
		vis.position = Vector3.ZERO
		_visual = null

	var axis := Vector3(dir.z, 0, -dir.x).normalized()
	var tw := faller.create_tween()
	tw.tween_property(faller, "quaternion",
		Quaternion(axis, PI * 0.52) * faller.quaternion, 1.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		Sfx.play_at("land", faller.global_position, scene, 0.0, 0.6)
		Fx.burst(scene, faller.global_position, Color(0.5, 0.4, 0.25), 20, 3.0, 0.1, 1.0)
	)
	tw.tween_interval(0.4)
	tw.tween_callback(func():
		var log_node := ResourceNode.make_log(seed_v, _tree_r * 1.2, _tree_h * 0.5)
		scene.add_child(log_node)
		log_node.global_position = faller.global_position + dir * (_tree_h * 0.25)
		log_node.rotation.y = atan2(dir.x, dir.z)
		faller.queue_free()
	)

	# 그루터기
	var st := ResourceNode.new()
	st.kind = Kind.STUMP
	st.seed_v = seed_v
	st.accept = Const.Dmg.CHOP
	st.required_tier = required_tier
	st.max_hp = 25.0
	st.hp = 25.0
	st.drops = {"wood": [2, 4]}
	st.set_meta("radius", _tree_r * 1.1)
	scene.add_child(st)
	st.global_position = global_position

	_spawn_drops()
	_finish_destroy()

func _spawn_drops() -> void:
	var scene := get_tree().current_scene
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v ^ int(Time.get_ticks_msec())
	for id in drops:
		var r: Array = drops[id]
		var amt := rng.randi_range(int(r[0]), int(r[1]))
		if amt <= 0:
			continue
		ItemDrop.spawn(scene, global_position + Vector3(0, 0.8, 0), id, amt, 1,
			Vector3(rng.randf_range(-2, 2), rng.randf_range(2, 4), rng.randf_range(-2, 2)))

func _give_drops(player) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v ^ int(Time.get_ticks_msec())
	var inv = player.inventory if "inventory" in player else null
	for id in drops:
		var r: Array = drops[id]
		var amt := rng.randi_range(int(r[0]), int(r[1]))
		if amt <= 0:
			continue
		var left := amt
		if inv != null:
			left = inv.add_item(id, amt)
			if amt - left > 0 and player.has_method("notify_pickup"):
				player.notify_pickup(id, amt - left)
		if left > 0:
			ItemDrop.spawn(get_tree().current_scene,
				global_position + Vector3(0, 0.6, 0), id, left)

func _finish_destroy() -> void:
	_dead = true
	destroyed.emit(self)
	if respawn_time <= 0.0:
		queue_free()
