class_name DungeonExit
extends StaticBody3D
## 던전 내부의 출구 계단. 상호작용하면 지상 입구로 돌아간다.

var dungeon: Dungeon = null

func _ready() -> void:
	collision_layer = Const.L_BUILDING
	collision_mask = 0
	add_to_group("interactable")

	var mb := MeshBuilder.new()
	for i in range(4):
		mb.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.25 * float(i), -0.5 * float(i))),
			Vector3(2.4, 0.25, 0.5), Color(0.48, 0.46, 0.42))
	mb.box(Transform3D(Basis.IDENTITY, Vector3(0, 1.6, -1.8)),
		Vector3(2.6, 0.4, 0.6), Color(0.55, 0.52, 0.46))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.commit()
	mi.material_override = MatLib.flat(Color.WHITE, 0.9)
	add_child(mi)

	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2.4, 1.0, 2.0)
	col.shape = bs
	col.position = Vector3(0, 0.5, -0.75)
	add_child(col)

	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.92, 0.70)
	l.light_energy = 3.6
	l.omni_range = 14.0
	l.position = Vector3(0, 2.0, -1.5)
	add_child(l)

	var lbl := Label3D.new()
	lbl.text = tr("UI_DUNGEON_EXIT")
	lbl.font_size = 34
	lbl.pixel_size = 0.004
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.outline_size = 8
	lbl.modulate = Color(1.0, 0.95, 0.78)
	lbl.position = Vector3(0, 2.6, -1.0)
	add_child(lbl)

func can_interact(_p) -> bool:
	return true

func prompt() -> String:
	return tr("PROMPT_EXIT_DUNGEON")

func interact(player) -> void:
	if dungeon == null or not is_instance_valid(dungeon):
		return
	player.global_position = dungeon.exit_to
	player.velocity = Vector3.ZERO
	player.remove_meta("in_dungeon")
	var lamp: Node = player.get_node_or_null("dungeon_lamp")
	if lamp != null:
		lamp.queue_free()
	Sfx.play("portal", -4.0, 1.1)
	GameState.msg(tr("MSG_EXIT_DUNGEON"))
