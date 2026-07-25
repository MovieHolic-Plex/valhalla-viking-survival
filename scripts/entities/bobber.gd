class_name Bobber
extends Node3D
## 낚시찌. 던지기 → 대기 → 입질 → 후킹 → 릴링 → 획득.

signal finished(fish_id: String)

enum St { FLY, WAIT, BITE, HOOKED, DONE }

var state: int = St.FLY
var vel := Vector3.ZERO
var owner_player: Node3D = null
var biome := Const.Biome.OCEAN

var _timer := 0.0
var _bite_window := 0.0
var _fish := ""
var _mi: MeshInstance3D
var _line: MeshInstance3D
var _bob := 0.0

## 바이옴마다 잡히는 어종이 다르다 — 낚시가 탐험의 이유가 되도록.
const FISH_BY_BIOME := {
	Const.Biome.OCEAN: ["tuna", "tuna", "perch", "serpent_meat"],
	Const.Biome.MEADOWS: ["perch", "perch", "pike", "fish"],
	Const.Biome.BLACKFOREST: ["perch", "pike", "trollfish"],
	Const.Biome.SWAMP: ["leech_fish", "pike", "trollfish"],
	Const.Biome.MOUNTAIN: ["northern_salmon", "northern_salmon", "perch"],
	Const.Biome.PLAINS: ["pike", "tuna", "perch"],
	Const.Biome.MISTLANDS: ["northern_salmon", "trollfish"],
	Const.Biome.ASHLANDS: ["magmafish", "magmafish", "charred_bone"],
}

func _ready() -> void:
	var mb := MeshBuilder.new()
	mb.sphere(Vector3(0, 0.05, 0), 0.09, 7, 4, Color(0.90, 0.22, 0.18))
	mb.sphere(Vector3(0, -0.04, 0), 0.07, 6, 3, Color(0.94, 0.94, 0.90))
	_mi = MeshInstance3D.new()
	_mi.mesh = mb.commit()
	_mi.material_override = MatLib.flat(Color.WHITE, 0.5)
	add_child(_mi)

	_line = MeshInstance3D.new()
	_line.material_override = MatLib.flat(Color(0.92, 0.92, 0.88), 0.7)
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)

func launch(from: Vector3, v: Vector3, player: Node3D) -> void:
	global_position = from
	vel = v
	owner_player = player

func _physics_process(delta: float) -> void:
	_update_line()
	match state:
		St.FLY:
			vel.y -= 16.0 * delta
			global_position += vel * delta
			if global_position.y <= Const.WATER_LEVEL:
				var ground := GameState.height_at(global_position.x, global_position.z)
				if Const.WATER_LEVEL - ground < 0.8:
					# 너무 얕다 — 찌를 회수
					GameState.msg(tr("MSG_FISH_TOO_SHALLOW"))
					_finish("")
					return
				global_position.y = Const.WATER_LEVEL
				state = St.WAIT
				biome = GameState.biome_at(global_position.x, global_position.z)
				_timer = randf_range(4.0, 12.0)
				Sfx.play_at("splash", global_position, get_tree().current_scene, -8.0)
				Fx.burst(get_tree().current_scene, global_position,
					Color(0.85, 0.92, 0.96), 10, 2.0, 0.05, 0.6)
			elif global_position.y < Const.WATER_LEVEL - 40.0:
				_finish("")
		St.WAIT:
			_bob += delta
			global_position.y = Const.WATER_LEVEL + sin(_bob * 2.0) * 0.06
			_timer -= delta
			if _timer <= 0.0:
				state = St.BITE
				_bite_window = 2.5
				var pool: Array = FISH_BY_BIOME.get(biome, ["fish"])
				_fish = str(pool[randi() % pool.size()])
				if not ItemDB.has_item(_fish):
					_fish = "fish"
				GameState.msg(tr("MSG_FISH_BITE"))
				Sfx.play_at("splash", global_position, get_tree().current_scene, -4.0, 1.4)
		St.BITE:
			_bob += delta * 9.0
			global_position.y = Const.WATER_LEVEL - 0.22 + sin(_bob) * 0.18
			_bite_window -= delta
			if _bite_window <= 0.0:
				state = St.WAIT
				_timer = randf_range(4.0, 10.0)
				GameState.msg(tr("MSG_FISH_ESCAPED"))
		St.HOOKED:
			if owner_player == null or not is_instance_valid(owner_player):
				_finish("")
				return
			var to: Vector3 = owner_player.global_position + Vector3(0, 0.6, 0) - global_position
			var dist := to.length()
			if dist < 2.2:
				_finish(_fish)
				return
			if Input.is_action_pressed("attack"):
				if owner_player.stats.use_stamina(9.0 * delta):
					global_position += to.normalized() * 3.0 * delta
					owner_player.stats.raise_skill(Const.Skill.KNIVES, delta * 0.3)
				else:
					GameState.msg(tr("MSG_FISH_LOST"))
					_finish("")
					return
			_bob += delta * 6.0
			global_position.y = Const.WATER_LEVEL - 0.1 + sin(_bob) * 0.12

	# 너무 멀어지면 줄이 끊긴다
	if owner_player != null and is_instance_valid(owner_player) and state != St.DONE:
		if global_position.distance_to(owner_player.global_position) > 40.0:
			_finish("")

## 플레이어가 후킹을 시도했다
func try_hook() -> bool:
	if state == St.BITE:
		state = St.HOOKED
		Sfx.play_at("swing", global_position, get_tree().current_scene, -8.0)
		GameState.msg(tr("MSG_FISH_HOOKED"))
		return true
	if state == St.WAIT or state == St.FLY:
		_finish("")
		return false
	return false

func _update_line() -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		return
	var a := to_local(owner_player.global_position + Vector3(0, 1.4, 0))
	var mb := MeshBuilder.new()
	mb.rod(a, Vector3.ZERO, 0.012, 3, Color(0.92, 0.92, 0.88))
	_line.mesh = mb.commit()

func _finish(fish_id: String) -> void:
	if state == St.DONE:
		return
	state = St.DONE
	if fish_id != "" and owner_player != null and is_instance_valid(owner_player):
		var amt := randi_range(1, 2)
		var left: int = owner_player.inventory.add_item(fish_id, amt)
		if left < amt:
			owner_player.notify_pickup(fish_id, amt - left)
		Sfx.play_at("pickup", global_position, get_tree().current_scene, -4.0)
		Fx.burst(get_tree().current_scene, global_position, Color(0.7, 0.85, 0.95),
			16, 3.0, 0.07, 0.9)
	finished.emit(fish_id)
	queue_free()
