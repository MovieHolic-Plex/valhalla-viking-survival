class_name Inventory
extends RefCounted
## 격자 인벤토리 + 장비 슬롯.
## 발헤임처럼 첫 줄이 단축바이고, 장비는 인벤토리에 남은 채로 "착용" 표시된다.

signal changed()
signal equipment_changed()

const SLOT_HEAD := "head"
const SLOT_CHEST := "chest"
const SLOT_LEGS := "legs"
const SLOT_CAPE := "cape"
const SLOT_RIGHT := "right"     # 무기 · 도구
const SLOT_LEFT := "left"       # 방패 · 횃불
const SLOT_AMMO := "ammo"

var cols: int
var rows: int
var slots: Array = []            # [{id, amount, quality}] 또는 {}
var equipped: Dictionary = {}    # slot 이름 -> 인벤토리 인덱스(-1 없음)
var max_weight := 300.0

const RESERVATION_INVALID := 0
const RESERVATION_INITIAL := 0
const _RESERVED := 1
const _COMMITTED := 2

var _next_reservation_id := RESERVATION_INITIAL
var _material_reservations: Dictionary = {}

func _init(c: int = Const.INV_COLS, r: int = Const.INV_ROWS) -> void:
	cols = c
	rows = r
	slots.resize(cols * rows)
	for i in slots.size():
		slots[i] = {}
	for s in [SLOT_HEAD, SLOT_CHEST, SLOT_LEGS, SLOT_CAPE, SLOT_RIGHT, SLOT_LEFT, SLOT_AMMO]:
		equipped[s] = -1

func size() -> int:
	return slots.size()

func is_empty_slot(i: int) -> bool:
	return i < 0 or i >= slots.size() or slots[i].is_empty()

func get_slot(i: int) -> Dictionary:
	if i < 0 or i >= slots.size():
		return {}
	return slots[i]

# ─────────────────────────────────────────────── 추가/제거
## 반환: 넣지 못하고 남은 개수
func add_item(id: String, amount: int, quality: int = 1) -> int:
	if amount <= 0 or not ItemDB.has_item(id):
		return amount
	var stack := ItemDB.stack_of(id)
	var left := amount
	# 1) 기존 스택에 합치기 (스택 가능한 것만)
	if stack > 1:
		for i in slots.size():
			var s: Dictionary = slots[i]
			if s.is_empty() or s["id"] != id or int(s.get("quality", 1)) != quality:
				continue
			var room: int = stack - int(s["amount"])
			if room <= 0:
				continue
			var put: int = mini(room, left)
			s["amount"] = int(s["amount"]) + put
			left -= put
			if left <= 0:
				break
	# 2) 빈 칸에 넣기
	while left > 0:
		var idx := _first_empty()
		if idx < 0:
			break
		var put: int = mini(stack, left)
		slots[idx] = {"id": id, "amount": put, "quality": quality}
		left -= put
	if left != amount:
		changed.emit()
	return left

func _first_empty() -> int:
	for i in slots.size():
		if slots[i].is_empty():
			return i
	return -1

func count(id: String) -> int:
	var n := 0
	for s in slots:
		if not s.is_empty() and s["id"] == id:
			n += int(s["amount"])
	return n

func remove_item(id: String, amount: int) -> bool:
	if count(id) < amount:
		return false
	var left := amount
	for i in slots.size():
		if left <= 0:
			break
		var s: Dictionary = slots[i]
		if s.is_empty() or s["id"] != id:
			continue
		var take: int = mini(int(s["amount"]), left)
		s["amount"] = int(s["amount"]) - take
		left -= take
		if int(s["amount"]) <= 0:
			_clear_slot(i)
	changed.emit()
	return true

func remove_at(i: int, amount: int = -1) -> Dictionary:
	if is_empty_slot(i):
		return {}
	var s: Dictionary = slots[i]
	var take: int = int(s["amount"]) if amount < 0 else mini(amount, int(s["amount"]))
	var out := {"id": s["id"], "amount": take, "quality": s.get("quality", 1)}
	s["amount"] = int(s["amount"]) - take
	if int(s["amount"]) <= 0:
		_clear_slot(i)
	changed.emit()
	return out

func _clear_slot(i: int) -> void:
	slots[i] = {}
	for k in equipped:
		if equipped[k] == i:
			equipped[k] = -1
			equipment_changed.emit()

func clear_all() -> void:
	for i in slots.size():
		slots[i] = {}
	for k in equipped:
		equipped[k] = -1
	_material_reservations.clear()
	_next_reservation_id = RESERVATION_INITIAL
	changed.emit()
	equipment_changed.emit()

# ─────────────────────────────────────────────── 재료 확인/소모
func has_materials(mats: Dictionary) -> bool:
	for id in mats:
		if count(id) < int(mats[id]):
			return false
	return true

## 재료를 눈에 보이게 변경하지 않고 정확한 수량을 예약한다. 0은 예약 실패다.
func reserve_materials(mats: Dictionary) -> int:
	var exact := _normalize_materials(mats)
	if exact.is_empty() and not mats.is_empty():
		return RESERVATION_INVALID
	for id in exact:
		if _available_material_count(id) < int(exact[id]):
			return RESERVATION_INVALID
	_next_reservation_id += 1
	_material_reservations[_next_reservation_id] = {
		"state": _RESERVED,
		"mats": exact,
	}
	return _next_reservation_id

## 예약분을 조용히 차감한다. publish_reservation 전에는 어떤 신호도 내보내지 않는다.
func commit_reservation(reservation_id: int) -> bool:
	var reservation: Dictionary = _material_reservations.get(reservation_id, {})
	if reservation.is_empty() or int(reservation.get("state", 0)) != _RESERVED:
		return false
	var mats: Dictionary = reservation["mats"]
	if not _has_unreserved_materials(mats, reservation_id):
		return false
	reservation["slots_before"] = slots.duplicate(true)
	reservation["equipped_before"] = equipped.duplicate(true)
	var equipment_changed_silently := false
	for id in mats:
		var left := int(mats[id])
		for i in slots.size():
			if left <= 0:
				break
			var slot: Dictionary = slots[i]
			if slot.is_empty() or str(slot.get("id", "")) != id:
				continue
			var take := mini(int(slot.get("amount", 0)), left)
			slot["amount"] = int(slot["amount"]) - take
			left -= take
			if int(slot["amount"]) <= 0:
				slots[i] = {}
				for equipment_slot in equipped:
					if int(equipped[equipment_slot]) == i:
						equipped[equipment_slot] = -1
						equipment_changed_silently = true
	reservation["equipment_changed"] = equipment_changed_silently
	reservation["state"] = _COMMITTED
	_material_reservations[reservation_id] = reservation
	return true

## 커밋된 예약의 단일 변경 알림을 발행하고 토큰을 닫는다.
func publish_reservation(reservation_id: int) -> bool:
	var reservation: Dictionary = _material_reservations.get(reservation_id, {})
	if reservation.is_empty() or int(reservation.get("state", 0)) != _COMMITTED:
		return false
	# Close the token only after every precondition has passed. Signal emission is the
	# irreversible publication boundary; callers may still rollback before this point.
	_material_reservations.erase(reservation_id)
	changed.emit()
	if bool(reservation.get("equipment_changed", false)):
		equipment_changed.emit()
	return true

## 미커밋 예약을 취소하거나 커밋을 신호 없이 원상 복구한다.
func cancel_reservation(reservation_id: int) -> bool:
	var reservation: Dictionary = _material_reservations.get(reservation_id, {})
	if reservation.is_empty():
		return false
	if int(reservation.get("state", 0)) == _COMMITTED:
		slots = (reservation["slots_before"] as Array).duplicate(true)
		equipped = (reservation["equipped_before"] as Dictionary).duplicate(true)
	_material_reservations.erase(reservation_id)
	return true

func _normalize_materials(mats: Dictionary) -> Dictionary:
	var exact := {}
	for raw_id in mats:
		var id := str(raw_id)
		var amount := int(mats[raw_id])
		if id == "" or amount <= 0 or not ItemDB.has_item(id):
			return {}
		exact[id] = int(exact.get(id, 0)) + amount
	return exact

func _available_material_count(id: String) -> int:
	var available := count(id)
	for reservation in _material_reservations.values():
		if int(reservation.get("state", 0)) == _RESERVED:
			available -= int((reservation.get("mats", {}) as Dictionary).get(id, 0))
	return available

func _has_unreserved_materials(mats: Dictionary, own_reservation_id: int) -> bool:
	for id in mats:
		var available := count(id)
		for other_id in _material_reservations:
			if int(other_id) == own_reservation_id:
				continue
			var other: Dictionary = _material_reservations[other_id]
			if int(other.get("state", 0)) == _RESERVED:
				available -= int((other.get("mats", {}) as Dictionary).get(id, 0))
		if available < int(mats[id]):
			return false
	return true

func consume(mats: Dictionary) -> bool:
	var reservation_id := reserve_materials(mats)
	if reservation_id == RESERVATION_INVALID:
		return false
	if not commit_reservation(reservation_id):
		cancel_reservation(reservation_id)
		return false
	if not publish_reservation(reservation_id):
		cancel_reservation(reservation_id)
		return false
	return true

func missing(mats: Dictionary) -> Dictionary:
	var out := {}
	for id in mats:
		var need := int(mats[id]) - count(id)
		if need > 0:
			out[id] = need
	return out

# ─────────────────────────────────────────────── 이동/교환
func swap(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0 or a >= slots.size() or b >= slots.size():
		return
	# 같은 아이템이면 합치기 시도
	var sa: Dictionary = slots[a]
	var sb: Dictionary = slots[b]
	if not sa.is_empty() and not sb.is_empty() and sa["id"] == sb["id"] \
			and int(sa.get("quality", 1)) == int(sb.get("quality", 1)):
		var stack := ItemDB.stack_of(sa["id"])
		var room: int = stack - int(sb["amount"])
		if room > 0:
			var mv: int = mini(room, int(sa["amount"]))
			sb["amount"] = int(sb["amount"]) + mv
			sa["amount"] = int(sa["amount"]) - mv
			if int(sa["amount"]) <= 0:
				_clear_slot(a)
			changed.emit()
			return
	var tmp = slots[a]
	slots[a] = slots[b]
	slots[b] = tmp
	# 장비 인덱스 추적
	for k in equipped:
		if equipped[k] == a:
			equipped[k] = b
		elif equipped[k] == b:
			equipped[k] = a
	changed.emit()
	equipment_changed.emit()

# ─────────────────────────────────────────────── 장비
static func slot_for(id: String) -> String:
	var it := ItemDB.get_item(id)
	if it.is_empty():
		return ""
	match int(it.get("t", -1)):
		Const.ItemType.WEAPON, Const.ItemType.TOOL:
			return SLOT_LEFT if id == "torch" else SLOT_RIGHT
		Const.ItemType.SHIELD:
			return SLOT_LEFT
		Const.ItemType.AMMO:
			return SLOT_AMMO
		Const.ItemType.ARMOR:
			match int(it.get("slot", Const.ArmorSlot.NONE)):
				Const.ArmorSlot.HEAD: return SLOT_HEAD
				Const.ArmorSlot.CHEST: return SLOT_CHEST
				Const.ArmorSlot.LEGS: return SLOT_LEGS
				Const.ArmorSlot.CAPE: return SLOT_CAPE
	return ""

func toggle_equip(i: int) -> bool:
	if is_empty_slot(i):
		return false
	var id: String = slots[i]["id"]
	var s := slot_for(id)
	if s == "":
		return false
	if equipped[s] == i:
		equipped[s] = -1
	else:
		equipped[s] = i
		# 양손 무기는 방패를 벗긴다
		if s == SLOT_RIGHT and is_two_handed(id):
			equipped[SLOT_LEFT] = -1
		if s == SLOT_LEFT and equipped[SLOT_RIGHT] >= 0:
			var rid := equipped_id(SLOT_RIGHT)
			if rid != "" and is_two_handed(rid):
				equipped[SLOT_RIGHT] = -1
	equipment_changed.emit()
	return true

static func is_two_handed(id: String) -> bool:
	var it := ItemDB.get_item(id)
	if it.get("bow", false):
		return true
	if int(it.get("skill", -1)) == Const.Skill.SPEARS and float(it.get("rng", 0.0)) > 3.4:
		return true   # 아트게일 계열
	return id.ends_with("greatsword")

func equipped_id(slot: String) -> String:
	var i: int = equipped.get(slot, -1)
	if is_empty_slot(i):
		return ""
	return slots[i]["id"]

func equipped_quality(slot: String) -> int:
	var i: int = equipped.get(slot, -1)
	if is_empty_slot(i):
		return 1
	return int(slots[i].get("quality", 1))

func is_equipped(i: int) -> bool:
	for k in equipped:
		if equipped[k] == i:
			return true
	return false

func total_armor() -> float:
	var a := 0.0
	for s in [SLOT_HEAD, SLOT_CHEST, SLOT_LEGS, SLOT_CAPE]:
		var id := equipped_id(s)
		if id != "":
			a += ItemDB.armor_of(id, equipped_quality(s))
	return a

func move_speed_mod() -> float:
	var m := 0.0
	for s in [SLOT_HEAD, SLOT_CHEST, SLOT_LEGS, SLOT_CAPE]:
		var id := equipped_id(s)
		if id != "":
			m += float(ItemDB.get_item(id).get("mov", 0.0))
	return m

## 장비/음식이 주는 저항 (res_frost, res_fire, res_poison ...)
func resistances() -> Dictionary:
	var out := {}
	for s in equipped:
		var id := equipped_id(s)
		if id == "":
			continue
		var it := ItemDB.get_item(id)
		for k in it:
			if str(k).begins_with("res_"):
				out[k] = maxf(float(out.get(k, 0.0)), float(it[k]))
	return out

# ─────────────────────────────────────────────── 무게
func weight() -> float:
	var w := 0.0
	for s in slots:
		if not s.is_empty():
			w += ItemDB.weight_of(s["id"]) * float(s["amount"])
	return w

func is_overweight() -> bool:
	return weight() > max_weight

# ─────────────────────────────────────────────── 직렬화
func to_dict() -> Dictionary:
	return {"cols": cols, "rows": rows, "slots": slots.duplicate(true),
		"equipped": equipped.duplicate()}

func from_dict(d: Dictionary) -> void:
	cols = int(d.get("cols", cols))
	rows = int(d.get("rows", rows))
	_material_reservations.clear()
	_next_reservation_id = RESERVATION_INITIAL
	var src: Array = d.get("slots", [])
	slots.resize(cols * rows)
	for i in slots.size():
		slots[i] = src[i].duplicate() if i < src.size() and src[i] is Dictionary else {}
	var eq: Dictionary = d.get("equipped", {})
	for k in equipped:
		equipped[k] = int(eq.get(k, -1))
	changed.emit()
	equipment_changed.emit()
