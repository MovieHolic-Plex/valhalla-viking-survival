class_name Boss
extends Enemy
## 보스. 페이즈 · 특수 공격 · 포세이큰 파워 부여.

signal boss_hp_changed(frac: float, name_key: String)
signal boss_started(name_key: String)
signal boss_ended()

var boss_id := "eikthyr"
var power_id := "eikthyr"
var name_key := "BOSS_EIKTHYR"
var phase := 1
var _special_cd := 0.0
var _attack_idx := 0
var _summon_cd := 0.0

static var DB: Dictionary = {
	"eikthyr": {
		"n": "BOSS_EIKTHYR", "power": "eikthyr", "biome": Const.Biome.MEADOWS,
		"offering": {"trophy_deer": 2}, "hp": 1200.0, "armor": 6.0,
		"dmg": {Const.Dmg.BLUNT: 45.0, Const.Dmg.LIGHTNING: 25.0},
		"speed": 3.0, "run": 6.2, "range": 3.6, "cd": 2.4, "size": 2.2,
		"kb": 90.0, "stagger_hp": 350.0, "aggro": 60.0,
		"rig": "quad", "rig_cfg": {"fur": Color(0.36, 0.30, 0.24), "length": 3.0,
			"height": 2.4, "girth": 1.0, "head": 0.55, "horn": "antler",
			"neck": 0.8, "tail": 0.3, "eye": Color(0.6, 0.85, 1.0)},
		"glow": Color(0.55, 0.80, 1.0),
		"drops": {"hard_antler": [3, 3, 1.0], "trophy_eikthyr": [1, 1, 1.0]},
		"specials": ["lightning_volley", "charge"],
	},
	"elder": {
		"n": "BOSS_ELDER", "power": "elder", "biome": Const.Biome.BLACKFOREST,
		"offering": {"ancient_seed": 3}, "hp": 2500.0, "armor": 12.0,
		"dmg": {Const.Dmg.BLUNT: 70.0}, "speed": 1.6, "run": 2.6, "range": 6.0,
		"cd": 3.2, "size": 4.0, "kb": 150.0, "stagger_hp": 700.0, "aggro": 60.0,
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.30, 0.28, 0.20),
			"cloth": Color(0.24, 0.32, 0.20), "height": 8.0, "bulk": 1.8,
			"head": 1.1, "eye": Color(0.85, 0.95, 0.40), "mossy": true},
		"drops": {"swamp_key": [1, 1, 1.0], "trophy_elder": [1, 1, 1.0],
			"ancient_bark": [10, 15, 1.0]},
		"specials": ["root_slam", "summon_roots"],
	},
	"bonemass": {
		"n": "BOSS_BONEMASS", "power": "bonemass", "biome": Const.Biome.SWAMP,
		"offering": {"withered_bone": 10}, "hp": 5000.0, "armor": 30.0,
		"dmg": {Const.Dmg.BLUNT: 90.0, Const.Dmg.POISON: 40.0},
		"speed": 1.3, "run": 2.2, "range": 5.0, "cd": 3.4, "size": 3.6,
		"kb": 160.0, "stagger_hp": 1200.0, "aggro": 55.0,
		"rig": "blob", "rig_cfg": {"color": Color(0.32, 0.46, 0.28), "size": 2.6},
		"drops": {"wishbone": [1, 1, 1.0], "trophy_bonemass": [1, 1, 1.0]},
		"specials": ["poison_cloud", "summon_skeletons"],
	},
	"moder": {
		"n": "BOSS_MODER", "power": "moder", "biome": Const.Biome.MOUNTAIN,
		"offering": {"dragon_egg": 3}, "hp": 5000.0, "armor": 20.0,
		"dmg": {Const.Dmg.FROST: 110.0, Const.Dmg.SLASH: 40.0},
		"speed": 3.6, "run": 6.0, "range": 26.0, "cd": 2.8, "size": 3.0,
		"kb": 90.0, "stagger_hp": 900.0, "aggro": 70.0, "flying": true,
		"ranged": {"speed": 26.0, "color": Color(0.65, 0.90, 1.0)},
		"rig": "flyer", "rig_cfg": {"color": Color(0.78, 0.90, 0.98), "size": 3.0,
			"wing": 5.0},
		"glow": Color(0.6, 0.9, 1.0),
		"drops": {"dragon_tear": [10, 10, 1.0], "trophy_moder": [1, 1, 1.0]},
		"specials": ["frost_breath", "ice_shards"],
	},
	"yagluth": {
		"n": "BOSS_YAGLUTH", "power": "yagluth", "biome": Const.Biome.PLAINS,
		"offering": {"trophy_fuling": 5}, "hp": 8000.0, "armor": 40.0,
		"dmg": {Const.Dmg.FIRE: 130.0, Const.Dmg.BLUNT: 90.0},
		"speed": 1.5, "run": 2.4, "range": 7.0, "cd": 3.6, "size": 5.0,
		"kb": 200.0, "stagger_hp": 2000.0, "aggro": 70.0,
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.72, 0.66, 0.48),
			"cloth": Color(0.42, 0.34, 0.16), "height": 9.0, "bulk": 1.7,
			"head": 1.0, "eye": Color(1.0, 0.55, 0.15), "horns": true},
		"glow": Color(1.0, 0.55, 0.12),
		"drops": {"torn_spirit": [5, 5, 1.0], "trophy_yagluth": [1, 1, 1.0]},
		"specials": ["meteor_rain", "fire_beam"],
	},
	"queen": {
		"n": "BOSS_QUEEN", "power": "queen", "biome": Const.Biome.MISTLANDS,
		"offering": {"carapace": 10, "black_core": 3}, "hp": 12000.0, "armor": 55.0,
		"dmg": {Const.Dmg.PIERCE: 160.0, Const.Dmg.SPIRIT: 50.0},
		"speed": 2.6, "run": 4.6, "range": 5.0, "cd": 2.6, "size": 3.4,
		"kb": 160.0, "stagger_hp": 2500.0, "aggro": 70.0,
		"rig": "quad", "rig_cfg": {"fur": Color(0.26, 0.28, 0.20), "length": 4.0,
			"height": 2.6, "girth": 1.5, "head": 0.9, "horn": "tusk",
			"eye": Color(1.0, 0.85, 0.20), "tail": 0.8},
		"drops": {"queen_drop": [5, 5, 1.0], "trophy_queen": [1, 1, 1.0]},
		"specials": ["summon_seekers", "eitr_burst"],
	},
	"fader": {
		"n": "BOSS_FADER", "power": "fader", "biome": Const.Biome.ASHLANDS,
		"offering": {"charred_bone": 10, "morgen_sinew": 5}, "hp": 18000.0,
		"armor": 70.0, "dmg": {Const.Dmg.FIRE: 200.0, Const.Dmg.BLUNT: 120.0},
		"speed": 2.2, "run": 4.0, "range": 8.0, "cd": 3.0, "size": 6.0,
		"kb": 220.0, "stagger_hp": 3500.0, "aggro": 80.0,
		"rig": "humanoid", "rig_cfg": {"skin": Color(0.35, 0.14, 0.10),
			"cloth": Color(0.20, 0.09, 0.07), "height": 11.0, "bulk": 1.8,
			"head": 1.0, "eye": Color(1.0, 0.75, 0.20), "horns": true},
		"glow": Color(1.0, 0.40, 0.10),
		"drops": {"ember": [5, 5, 1.0], "flametal": [10, 10, 1.0]},
		"specials": ["meteor_rain", "fire_beam", "summon_charred"],
	},
}

static func spawn_boss(id: String, parent: Node, pos: Vector3) -> Boss:
	var c: Dictionary = DB.get(id, {})
	if c.is_empty():
		return null
	var b := Boss.new()
	b.boss_id = id
	b.name_key = str(c["n"])
	b.power_id = str(c["power"])
	b.cfg = c.duplicate(true)
	b.cfg["id"] = id
	parent.add_child(b)
	b.global_position = pos
	return b

func _ready() -> void:
	super._ready()
	add_to_group("boss")
	if _hp_bar:
		_hp_bar.visible = false
	Sfx.play_at("boss_roar", global_position, get_tree().current_scene, 4.0)
	boss_started.emit(name_key)
	var ui = get_tree().current_scene.get_node_or_null("ui")
	if ui != null and ui.has_method("show_boss_bar"):
		ui.show_boss_bar(self)
	# 보스는 항상 플레이어를 인지한다
	target = GameState.player
	state = St.CHASE

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _dead:
		return
	_special_cd = maxf(0.0, _special_cd - delta)
	_summon_cd = maxf(0.0, _summon_cd - delta)
	if phase == 1 and hp < max_hp * 0.5:
		phase = 2
		Sfx.play_at("boss_roar", global_position, get_tree().current_scene, 4.0, 0.8)
		GameState.msg(tr("MSG_BOSS_ENRAGED") % tr(name_key))
		_stagger_time = 0.0

func _st_attack(delta: float) -> void:
	if target == null:
		state = St.CHASE
		return
	if _special_cd <= 0.0 and _telegraph < 0.0:
		var sp: Array = cfg.get("specials", [])
		if not sp.is_empty():
			_special_cd = (7.0 if phase == 1 else 4.5)
			_attack_idx = (_attack_idx + 1) % sp.size()
			_do_special(str(sp[_attack_idx]))
			return
	super._st_attack(delta)

func take_hit(dmg: Dictionary, from_pos: Vector3, attacker = null,
		knockback: float = 0.0) -> void:
	super.take_hit(dmg, from_pos, attacker, knockback * 0.25)
	if _hp_bar:
		_hp_bar.visible = false
	boss_hp_changed.emit(clampf(hp / max_hp, 0.0, 1.0), name_key)

func _die(killer) -> void:
	if _dead:
		return
	super._die(killer)
	boss_ended.emit()
	GameState.kill_boss(boss_id, power_id)
	# 승리 연출
	var scene := get_tree().current_scene
	Fx.burst(scene, global_position + Vector3(0, 2.0, 0), Color(1.0, 0.92, 0.60),
		80, 10.0, 0.2, 2.4)
	Sfx.play("boss_roar", 2.0, 0.55)
	Sfx.play("level_up", -2.0, 0.7)

# ═══════════════════════════════════════════════ 특수 공격
func _do_special(kind: String) -> void:
	var scene := get_tree().current_scene
	var p := target
	if p == null or not is_instance_valid(p):
		return
	anim.attack("chop")
	match kind:
		"lightning_volley":
			Sfx.play_at("thunder", global_position, scene, -2.0, 1.4)
			for i in range(6):
				var ang := TAU * float(i) / 6.0 + _rng.randf()
				var dir := (p.global_position + Vector3(cos(ang), 0.3, sin(ang)) * 4.0
					- global_position).normalized()
				var pr := Projectile.make({Const.Dmg.LIGHTNING: 35.0},
					Color(0.75, 0.85, 1.0), self, true)
				scene.add_child(pr)
				pr.gravity = 2.0
				pr.launch(global_position + Vector3(0, 2.0, 0), dir * 26.0)
		"charge":
			var to := p.global_position - global_position
			to.y = 0
			if to.length() > 0.1:
				velocity += to.normalized() * 16.0
				velocity.y = 3.0
			Sfx.play_at("growl", global_position, scene, 0.0, 0.7)
		"root_slam":
			_aoe(scene, global_position, 9.0, {Const.Dmg.BLUNT: 60.0},
				Color(0.35, 0.45, 0.22))
		"summon_roots", "summon_skeletons", "summon_seekers", "summon_charred":
			if _summon_cd > 0.0:
				return
			_summon_cd = 22.0
			var summon_map := {"summon_roots": "greydwarf", "summon_skeletons": "skeleton",
				"summon_seekers": "seeker", "summon_charred": "charred_warrior"}
			var who: String = str(summon_map.get(kind, "greydwarf"))
			for i in range(3 if phase == 1 else 5):
				var a := TAU * float(i) / 5.0
				var pos := global_position + Vector3(cos(a), 0, sin(a)) * (5.0 + _size)
				pos.y = GameState.height_at(pos.x, pos.z) + 0.5
				var e := Enemy.spawn(who, scene, pos)
				if e:
					e.target = p
					e.state = Enemy.St.CHASE
			GameState.msg(tr("MSG_BOSS_SUMMONS"))
		"poison_cloud":
			_aoe(scene, p.global_position, 8.0, {Const.Dmg.POISON: 55.0},
				Color(0.35, 0.85, 0.35))
			if p.has_method("get_inventory"):
				p.stats.add_status("poison", 12.0, {"dps": 4.0, "nonlethal": true})
		"frost_breath":
			for i in range(9):
				var spread := Vector3(_rng.randf_range(-0.18, 0.18),
					_rng.randf_range(-0.05, 0.12), _rng.randf_range(-0.18, 0.18))
				var dir := (p.global_position + Vector3(0, 1, 0) - global_position)\
					.normalized() + spread
				var pr := Projectile.make({Const.Dmg.FROST: 45.0},
					Color(0.65, 0.92, 1.0), self, true)
				scene.add_child(pr)
				pr.gravity = 1.5
				pr.launch(global_position + Vector3(0, 1.0, 0), dir.normalized() * 30.0)
		"ice_shards":
			for i in range(12):
				var a := TAU * float(i) / 12.0
				var pos := p.global_position + Vector3(cos(a), 0, sin(a)) * 6.0
				_delayed_spike(scene, pos, {Const.Dmg.FROST: 40.0},
					Color(0.7, 0.92, 1.0), 0.9)
		"meteor_rain":
			for i in range(8):
				var off := Vector3(_rng.randf_range(-11, 11), 0, _rng.randf_range(-11, 11))
				_delayed_spike(scene, p.global_position + off,
					{Const.Dmg.FIRE: 70.0}, Color(1.0, 0.45, 0.12),
					0.7 + float(i) * 0.12)
		"fire_beam":
			var dir := (p.global_position + Vector3(0, 1, 0) - global_position).normalized()
			for i in range(10):
				var pr := Projectile.make({Const.Dmg.FIRE: 40.0},
					Color(1.0, 0.5, 0.12), self, true)
				scene.add_child(pr)
				pr.gravity = 0.0
				pr.launch(global_position + Vector3(0, 2.0 * _size * 0.5, 0)
					+ dir * float(i) * 0.6, dir * 34.0)
		"eitr_burst":
			_aoe(scene, global_position, 12.0, {Const.Dmg.SPIRIT: 80.0},
				Color(0.62, 0.45, 0.95))

func _aoe(scene: Node, center: Vector3, radius: float, dmg: Dictionary,
		col: Color) -> void:
	Fx.burst(scene, center + Vector3(0, 0.4, 0), col, 50, radius * 0.8, 0.16, 1.4)
	Sfx.play_at("thunder", center, scene, -4.0, 0.9)
	var p := GameState.player
	if p != null and is_instance_valid(p) \
			and p.global_position.distance_to(center) <= radius:
		p.take_hit(dmg.duplicate(), center, self, 80.0)

## 잠시 후 폭발하는 표식 — 회피 가능한 공격
func _delayed_spike(scene: Node, pos: Vector3, dmg: Dictionary, col: Color,
		delay: float) -> void:
	pos.y = GameState.height_at(pos.x, pos.z)
	var marker := MeshInstance3D.new()
	var mb := MeshBuilder.new()
	mb.cyl(Transform3D.IDENTITY, 2.2, 2.2, 0.06, 16, col)
	marker.mesh = mb.commit()
	marker.material_override = MatLib.translucent(col, 0.45)
	scene.add_child(marker)
	marker.global_position = pos + Vector3(0, 0.06, 0)
	var tw := marker.create_tween()
	tw.tween_property(marker, "scale", Vector3(1.15, 1, 1.15), delay)
	tw.tween_callback(func():
		if not is_instance_valid(marker):
			return
		Fx.burst(scene, pos + Vector3(0, 0.5, 0), col, 32, 7.0, 0.14, 1.0)
		Sfx.play_at("thunder", pos, scene, -6.0, 1.3)
		var p := GameState.player
		if p != null and is_instance_valid(p) \
				and p.global_position.distance_to(pos) < 2.6:
			p.take_hit(dmg.duplicate(), pos, self, 60.0)
		marker.queue_free()
	)
