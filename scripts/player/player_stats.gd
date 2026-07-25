class_name PlayerStats
extends RefCounted
## 체력 · 스태미나 · 음식 · 스킬 · 상태이상.

signal died()
signal hp_changed(hp: float, max_hp: float)
signal stamina_changed(sp: float, max_sp: float)
signal food_changed()
signal skill_up(skill: int, level: float)
signal status_changed()

var hp := Const.BASE_HP
var stamina := Const.BASE_STAMINA
var eitr := 0.0
var max_eitr := 0.0

var foods: Array = []           # [{id, t, dur, hp, sp, reg}]
var skills: Dictionary = {}     # Const.Skill -> {"lvl": float, "xp": float}
var status: Dictionary = {}     # id -> {"t": 남은시간, ...}

var _regen_timer := 0.0
var _stam_delay := 0.0
var _hp_regen_acc := 0.0
var is_dead := false

func _init() -> void:
	for s in Const.Skill.values():
		skills[s] = {"lvl": 0.0, "xp": 0.0}

# ─────────────────────────────────────────────── 최대치
func max_hp() -> float:
	var v := Const.BASE_HP
	for f in foods:
		v += float(f["hp"]) * _food_falloff(f)
	if has_status("rested"):
		v += 0.0
	return v

func max_eitr_value() -> float:
	var v := 0.0
	for f in foods:
		v += float(f.get("eitr", 0.0)) * _food_falloff(f)
	return v

func max_stamina() -> float:
	var v := Const.BASE_STAMINA
	for f in foods:
		v += float(f["sp"]) * _food_falloff(f)
	return v

func food_regen() -> float:
	var v := 0.0
	for f in foods:
		v += float(f["reg"])
	# 휴식 상태면 회복이 크게 빨라진다 (발헤임의 Rested 버프)
	if has_status("rested"):
		v *= 2.0
	return v

## 음식은 시간이 지나면 효과가 서서히 줄어든다(마지막 30%)
static func _food_falloff(f: Dictionary) -> float:
	var t := float(f["t"])
	var dur := float(f["dur"])
	if dur <= 0.0:
		return 0.0
	var frac := t / dur
	if frac > 0.3:
		return 1.0
	return clampf(frac / 0.3, 0.0, 1.0)

# ─────────────────────────────────────────────── 갱신
func update(delta: float, moving: bool) -> void:
	if is_dead:
		return
	# 음식 소모
	var dirty := false
	for i in range(foods.size() - 1, -1, -1):
		foods[i]["t"] = float(foods[i]["t"]) - delta
		if float(foods[i]["t"]) <= 0.0:
			foods.remove_at(i)
			dirty = true
	if dirty:
		food_changed.emit()
		hp = minf(hp, max_hp())

	# 체력 재생
	_hp_regen_acc += delta
	if _hp_regen_acc >= 1.0:
		_hp_regen_acc -= 1.0
		var r := food_regen()
		if r > 0.0 and hp < max_hp():
			heal(r * 0.5)

	# 스태미나 재생
	if _stam_delay > 0.0:
		_stam_delay -= delta
	else:
		var rate := Const.STAMINA_REGEN
		if has_status("rested"):
			rate *= 1.5
		if has_status("wet"):
			rate *= 0.75
		if foods.is_empty():
			rate *= 0.6
		set_stamina(stamina + rate * delta)

	# 에이트르 재생
	max_eitr = max_eitr_value()
	if max_eitr > 0.0:
		var er := 4.0
		if GameState.power_is_active("queen"):
			er *= 2.0
		eitr = clampf(eitr + er * delta, 0.0, max_eitr)
	else:
		eitr = 0.0

	_update_status(delta)

func _update_status(delta: float) -> void:
	var to_remove: Array = []
	for id in status:
		var s: Dictionary = status[id]
		s["t"] = float(s["t"]) - delta
		match id:
			"poison":
				_tick_dot(s, delta, 1.0, false)
			"burning":
				_tick_dot(s, delta, 2.5, false)
			"freezing":
				_tick_dot(s, delta, 1.5, false)
			"cold":
				pass
		if float(s["t"]) <= 0.0:
			to_remove.append(id)
	for id in to_remove:
		status.erase(id)
		status_changed.emit()

func _tick_dot(s: Dictionary, delta: float, dps: float, _lethal: bool) -> void:
	s["acc"] = float(s.get("acc", 0.0)) + delta
	while float(s["acc"]) >= 1.0:
		s["acc"] = float(s["acc"]) - 1.0
		var d: float = float(s.get("dps", dps))
		# 독은 체력을 1 아래로는 못 내린다 (발헤임과 동일)
		if hp - d < 1.0 and s.get("nonlethal", true):
			hp = maxf(hp, 1.0)
		else:
			hp -= d
		hp_changed.emit(hp, max_hp())
		if hp <= 0.0:
			_die()

# ─────────────────────────────────────────────── 체력/스태미나
func set_hp(v: float) -> void:
	hp = clampf(v, 0.0, max_hp())
	hp_changed.emit(hp, max_hp())
	if hp <= 0.0:
		_die()

func heal(v: float) -> void:
	if is_dead:
		return
	set_hp(hp + v)

func set_stamina(v: float) -> void:
	stamina = clampf(v, 0.0, max_stamina())
	stamina_changed.emit(stamina, max_stamina())

func use_eitr(v: float) -> bool:
	if eitr < v:
		return false
	eitr -= v
	return true

func use_stamina(v: float) -> bool:
	if stamina < v:
		return false
	stamina -= v
	_stam_delay = Const.STAMINA_REGEN_DELAY
	stamina_changed.emit(stamina, max_stamina())
	return true

func has_stamina(v: float) -> bool:
	return stamina >= v

## 방어도 반영 데미지 계산 (발헤임 공식 근사)
static func mitigate(raw: float, armor: float) -> float:
	if raw <= 0.0:
		return 0.0
	if armor < raw * 0.5:
		return maxf(raw - armor, 0.0)
	return raw * raw / (armor * 4.0)

func take_damage(dmg: Dictionary, armor: float, resist: Dictionary = {}) -> float:
	if is_dead:
		return 0.0
	var total := 0.0
	for t in dmg:
		var v := float(dmg[t])
		match t:
			Const.Dmg.FIRE:
				v *= 1.0 - float(resist.get("res_fire", 0.0))
			Const.Dmg.FROST:
				v *= 1.0 - float(resist.get("res_frost", 0.0))
			Const.Dmg.POISON:
				v *= 1.0 - float(resist.get("res_poison", 0.0))
			Const.Dmg.SPIRIT:
				v *= 1.0 - float(resist.get("res_spirit", 0.0))
			Const.Dmg.LIGHTNING:
				v *= 1.0 - float(resist.get("res_lightning", 0.0))
		total += v
	# 원소 데미지는 방어도 영향을 덜 받지만, 여기선 단순화해 전체에 적용
	var final := mitigate(total, armor)
	if GameState.power_is_active("elder"):
		final *= 0.4
	set_hp(hp - final)
	return final

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	died.emit()

func revive() -> void:
	is_dead = false
	foods.clear()
	status.clear()
	hp = max_hp()
	stamina = max_stamina()
	hp_changed.emit(hp, max_hp())
	stamina_changed.emit(stamina, max_stamina())
	food_changed.emit()
	status_changed.emit()

# ─────────────────────────────────────────────── 음식
func can_eat(id: String) -> bool:
	var it := ItemDB.get_item(id)
	if not it.has("hp"):
		return false
	for f in foods:
		if f["id"] == id:
			# 같은 음식은 절반 이상 남았으면 못 먹는다
			return float(f["t"]) < float(f["dur"]) * 0.5
	return foods.size() < Const.FOOD_SLOTS

func eat(id: String) -> bool:
	var it := ItemDB.get_item(id)
	if not it.has("hp"):
		return false
	for f in foods:
		if f["id"] == id:
			if float(f["t"]) >= float(f["dur"]) * 0.5:
				return false
			f["t"] = float(it["dur"])
			food_changed.emit()
			return true
	if foods.size() >= Const.FOOD_SLOTS:
		return false
	foods.append({"id": id, "t": float(it["dur"]), "dur": float(it["dur"]),
		"hp": float(it["hp"]), "sp": float(it["sp"]), "reg": float(it["reg"]),
		"eitr": float(it.get("eitr", 0.0))})
	food_changed.emit()
	hp_changed.emit(hp, max_hp())
	stamina_changed.emit(stamina, max_stamina())
	return true

# ─────────────────────────────────────────────── 상태이상
func add_status(id: String, dur: float, extra: Dictionary = {}) -> void:
	var s: Dictionary = status.get(id, {})
	s["t"] = maxf(float(s.get("t", 0.0)), dur)
	for k in extra:
		s[k] = extra[k]
	status[id] = s
	status_changed.emit()

func has_status(id: String) -> bool:
	return status.has(id)

func remove_status(id: String) -> void:
	if status.erase(id):
		status_changed.emit()

func status_list() -> Array:
	var out: Array = []
	for id in status:
		out.append({"id": id, "t": float(status[id]["t"])})
	return out

# ─────────────────────────────────────────────── 스킬
func skill_level(s: int) -> float:
	return float(skills.get(s, {}).get("lvl", 0.0))

func raise_skill(s: int, amount: float = 1.0) -> void:
	if not skills.has(s):
		skills[s] = {"lvl": 0.0, "xp": 0.0}
	var e: Dictionary = skills[s]
	var lvl := float(e["lvl"])
	if lvl >= Const.SKILL_MAX:
		return
	e["xp"] = float(e["xp"]) + amount
	var need := _xp_needed(lvl)
	while float(e["xp"]) >= need and float(e["lvl"]) < Const.SKILL_MAX:
		e["xp"] = float(e["xp"]) - need
		e["lvl"] = float(e["lvl"]) + 1.0
		need = _xp_needed(float(e["lvl"]))
		skill_up.emit(s, float(e["lvl"]))
		Sfx.play("level_up", -8.0, 1.1)

static func _xp_needed(lvl: float) -> float:
	return 0.5 + lvl * lvl * 0.045 + lvl * 0.65

## 사망 시 모든 스킬 5% 손실
func skill_death_penalty() -> void:
	for s in skills:
		skills[s]["lvl"] = maxf(0.0, float(skills[s]["lvl"]) * 0.95)
		skills[s]["xp"] = 0.0

# ─────────────────────────────────────────────── 직렬화
func to_dict() -> Dictionary:
	return {"hp": hp, "stamina": stamina, "foods": foods.duplicate(true),
		"skills": skills.duplicate(true), "status": status.duplicate(true)}

func from_dict(d: Dictionary) -> void:
	foods = d.get("foods", []).duplicate(true)
	var sk: Dictionary = d.get("skills", {})
	for k in sk:
		skills[int(k)] = sk[k].duplicate()
	status = d.get("status", {}).duplicate(true)
	hp = clampf(float(d.get("hp", Const.BASE_HP)), 1.0, max_hp())
	stamina = clampf(float(d.get("stamina", Const.BASE_STAMINA)), 0.0, max_stamina())
	is_dead = false
	hp_changed.emit(hp, max_hp())
	stamina_changed.emit(stamina, max_stamina())
	food_changed.emit()
	status_changed.emit()
