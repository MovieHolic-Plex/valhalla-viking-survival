class_name StorageBox
extends StaticBody3D
## 상자 · 무덤 공통 보관함. 열면 인벤토리 UI 가 양쪽을 함께 보여준다.

signal opened(box)

var storage: Inventory
var title_key := "UI_CHEST"
var is_tomb := false

func _init(cols: int = 5, rows: int = 4) -> void:
	storage = Inventory.new(cols, rows)

func _ready() -> void:
	collision_layer = Const.L_BUILDING
	collision_mask = 0
	add_to_group("interactable")
	add_to_group("storage")

func can_interact(_player) -> bool:
	return true

func prompt() -> String:
	return tr("PROMPT_OPEN") % tr(title_key)

func interact(player) -> void:
	Sfx.play_at("build", global_position, get_tree().current_scene, -12.0, 1.4)
	opened.emit(self)
	var ui = get_tree().current_scene.get_node_or_null("ui")
	if ui != null and ui.has_method("open_container"):
		ui.open_container(self, player)

func store_from(inv: Inventory) -> void:
	for i in inv.size():
		var s: Dictionary = inv.get_slot(i)
		if s.is_empty():
			continue
		storage.add_item(s["id"], int(s["amount"]), int(s.get("quality", 1)))

func is_empty() -> bool:
	for i in storage.size():
		if not storage.get_slot(i).is_empty():
			return false
	return true

func to_dict() -> Dictionary:
	return {"inv": storage.to_dict(), "tomb": is_tomb,
		"pos": [global_position.x, global_position.y, global_position.z]}

func from_dict(d: Dictionary) -> void:
	storage.from_dict(d.get("inv", {}))
	is_tomb = bool(d.get("tomb", false))
