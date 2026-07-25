class_name BossAltar
extends StaticBody3D
## 보스 제단. 공물을 바치면 보스가 소환된다.

var boss_id := "eikthyr"
var _spawned: Boss = null
var _label: Label3D

static func make(id: String) -> BossAltar:
	var a := BossAltar.new()
	a.boss_id = id
	return a

func _ready() -> void:
	collision_layer = Const.L_BUILDING
	collision_mask = 0
	add_to_group("interactable")
	add_to_group("altar")

	var c: Dictionary = Boss.DB.get(boss_id, {})
	var tier: int = Const.BIOME_TIER.get(int(c.get("biome", Const.Biome.MEADOWS)), 0)

	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.altar(tier)
	mi.material_override = MatLib.flat(Color.WHITE, 0.95)
	add_child(mi)

	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.4
	cyl.height = 1.8
	col.shape = cyl
	col.position = Vector3(0, 0.9, 0)
	add_child(col)

	_label = Label3D.new()
	_label.font_size = 46
	_label.pixel_size = 0.006
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 12
	_label.modulate = Color(1.0, 0.90, 0.60)
	_label.position = Vector3(0, 3.4, 0)
	add_child(_label)
	_refresh_label()

	# 제단 불빛
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.72, 0.35)
	l.light_energy = 2.2
	l.omni_range = 14.0
	l.position = Vector3(0, 2.0, 0)
	add_child(l)
	var f := Fx.fire(self, 1.4, Color(1.0, 0.65, 0.25))
	f.position = Vector3(0, 1.5, 0)

func _refresh_label() -> void:
	if GameState.bosses_killed.has(boss_id):
		_label.text = tr("ALTAR_DEFEATED") % tr(str(Boss.DB[boss_id]["n"]))
		_label.modulate = Color(0.65, 0.70, 0.75)
	else:
		_label.text = tr(str(Boss.DB[boss_id]["n"]))

func can_interact(_player) -> bool:
	return _spawned == null or not is_instance_valid(_spawned)

func prompt() -> String:
	var c: Dictionary = Boss.DB.get(boss_id, {})
	var off: Dictionary = c.get("offering", {})
	var parts: Array[String] = []
	for id in off:
		parts.append("%s x%d" % [ItemDB.name_of(id), int(off[id])])
	return tr("PROMPT_OFFER") % [tr(str(c.get("n", "?"))), ", ".join(parts)]

func interact(player) -> void:
	if _spawned != null and is_instance_valid(_spawned):
		return
	var c: Dictionary = Boss.DB.get(boss_id, {})
	var off: Dictionary = c.get("offering", {})
	if not player.inventory.has_materials(off):
		GameState.msg(tr("MSG_NEED_OFFERING"))
		Sfx.play("error", -8.0)
		return
	player.inventory.consume(off)
	Sfx.play_at("portal", global_position, get_tree().current_scene, 2.0, 0.6)
	Fx.burst(get_tree().current_scene, global_position + Vector3(0, 1.5, 0),
		Color(1.0, 0.85, 0.4), 60, 8.0, 0.16, 1.8)

	var pos := global_position + Vector3(0, 1.0, 0)
	pos.y = GameState.height_at(pos.x, pos.z) + 1.0
	_spawned = Boss.spawn_boss(boss_id, get_tree().current_scene, pos)
	if _spawned:
		_spawned.died.connect(func(_e): _refresh_label())
	GameState.msg(tr("MSG_BOSS_SUMMONED") % tr(str(c.get("n", "?"))))
