class_name DungeonEntrance
extends StaticBody3D
## 지상에 서 있는 던전 입구. 상호작용하면 내부가 생성되고 순간이동한다.

var kind := "crypt"
var seed_v := 0
var index := 0
var _dungeon: Dungeon = null
var _label: Label3D

static func make(k: String, sv: int, idx: int) -> DungeonEntrance:
	var e := DungeonEntrance.new()
	e.kind = k
	e.seed_v = sv
	e.index = idx
	return e

func _ready() -> void:
	collision_layer = Const.L_BUILDING
	collision_mask = 0
	add_to_group("interactable")
	add_to_group("dungeon_entrance")

	var c: Dictionary = Dungeon.KINDS.get(kind, Dungeon.KINDS["crypt"])
	var stone: Color = c["stone"]
	var mb := MeshBuilder.new()
	# 무너진 석조 아치
	mb.box(Transform3D(Basis.IDENTITY, Vector3(-1.6, 1.6, 0)), Vector3(0.9, 3.2, 1.1),
		stone)
	mb.box(Transform3D(Basis.IDENTITY, Vector3(1.6, 1.6, 0)), Vector3(0.9, 3.2, 1.1),
		stone)
	mb.box(Transform3D(Basis.IDENTITY, Vector3(0, 3.4, 0)), Vector3(4.2, 0.8, 1.2),
		stone.darkened(0.12))
	mb.box(Transform3D(Basis(Vector3.FORWARD, 0.08), Vector3(0, 4.0, 0)),
		Vector3(4.8, 0.5, 1.4), stone.darkened(0.2))
	# 계단으로 내려가는 어두운 입구
	mb.box(Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 0)), Vector3(2.2, 2.6, 0.3),
		Color(0.04, 0.04, 0.05))
	# 바닥 포석
	mb.cyl(Transform3D(Basis.IDENTITY, Vector3(0, -0.15, 0)), 3.6, 3.4, 0.35, 10,
		stone.darkened(0.28))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	mi.material_override = MatLib.flat(Color.WHITE, 0.95)
	add_child(mi)

	for sx in [-1.0, 1.0]:
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.9, 3.2, 1.1)
		col.shape = bs
		col.position = Vector3(1.6 * sx, 1.6, 0)
		add_child(col)

	var l := OmniLight3D.new()
	l.light_color = c["light"]
	l.light_energy = 1.8
	l.omni_range = 9.0
	l.position = Vector3(0, 2.2, 0.6)
	add_child(l)
	Flicker.attach(l, 0.24, 0.8)

	_label = Label3D.new()
	_label.text = tr(str(c["n"]))
	_label.font_size = 40
	_label.pixel_size = 0.005
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.outline_size = 10
	_label.modulate = Color(0.90, 0.86, 0.72)
	_label.position = Vector3(0, 5.0, 0)
	add_child(_label)

func can_interact(_p) -> bool:
	return true

func prompt() -> String:
	var c: Dictionary = Dungeon.KINDS.get(kind, Dungeon.KINDS["crypt"])
	return tr("PROMPT_ENTER_DUNGEON") % tr(str(c["n"]))

func interact(player) -> void:
	if _dungeon == null or not is_instance_valid(_dungeon):
		_dungeon = Dungeon.make(kind, seed_v, global_position + Vector3(0, 1.0, 2.5),
			index)
		get_tree().current_scene.add_child(_dungeon)
		_dungeon.generate()
	_dungeon.exit_to = global_position + Vector3(0, 1.0, 2.5)
	player.global_position = _dungeon.entry_point()
	player.velocity = Vector3.ZERO
	player.set_meta("in_dungeon", true)
	# 지하에서는 손등불이 있어야 길이 보인다
	if player.get_node_or_null("dungeon_lamp") == null:
		var lamp := OmniLight3D.new()
		lamp.name = "dungeon_lamp"
		lamp.light_color = Color(1.0, 0.86, 0.66)
		lamp.light_energy = 1.5
		lamp.omni_range = 16.0
		lamp.shadow_enabled = false
		lamp.position = Vector3(0, 1.6, 0)
		player.add_child(lamp)
	Sfx.play("portal", -4.0, 0.7)
	GameState.msg(tr("MSG_ENTER_DUNGEON"))
