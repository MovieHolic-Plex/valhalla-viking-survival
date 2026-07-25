class_name Tombstone
extends StorageBox
## 사망 지점에 남는 무덤. 모든 소지품을 보관하고, 비면 사라진다.

func _init() -> void:
	super._init(Const.INV_COLS, Const.INV_ROWS)
	title_key = "UI_TOMBSTONE"
	is_tomb = true

func _ready() -> void:
	super._ready()
	add_to_group("tombstone")
	var mi := MeshInstance3D.new()
	mi.mesh = MeshFactory.tombstone()
	mi.material_override = MatLib.flat(Color.WHITE, 0.95)
	add_child(mi)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.9, 1.3, 0.6)
	col.shape = bs
	col.position = Vector3(0, 0.65, 0)
	add_child(col)
	# 멀리서도 보이는 표식
	var l := OmniLight3D.new()
	l.light_color = Color(0.65, 0.80, 1.0)
	l.light_energy = 1.4
	l.omni_range = 9.0
	l.position = Vector3(0, 1.2, 0)
	add_child(l)
	var lbl := Label3D.new()
	lbl.text = tr("UI_TOMBSTONE")
	lbl.font_size = 42
	lbl.pixel_size = 0.004
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.modulate = Color(0.85, 0.92, 1.0)
	lbl.outline_size = 10
	lbl.position = Vector3(0, 1.9, 0)
	add_child(lbl)

func prompt() -> String:
	return tr("PROMPT_TAKE_ALL")

func interact(player) -> void:
	# 무덤은 한 번에 전부 회수
	var moved := 0
	for i in storage.size():
		var s: Dictionary = storage.get_slot(i)
		if s.is_empty():
			continue
		var left: int = player.inventory.add_item(str(s["id"]), int(s["amount"]),
			int(s.get("quality", 1)))
		var took: int = int(s["amount"]) - left
		if took > 0:
			storage.remove_at(i, took)
			moved += took
	Sfx.play_at("pickup", global_position, get_tree().current_scene, -4.0)
	if is_empty():
		queue_free()
	elif moved == 0:
		GameState.msg(tr("MSG_INVENTORY_FULL"))
