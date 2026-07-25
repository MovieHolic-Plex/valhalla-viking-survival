class_name Flicker
extends Node
## 불빛 떨림. 부모(또는 지정한) Light3D 의 밝기를 불규칙하게 흔든다.
##
## 횃불·모닥불이 일정한 밝기로 켜져 있으면 즉시 "게임 조명"처럼 보인다.
## 서로 다른 주파수의 사인파 셋을 겹쳐 반복 없는 흔들림을 만든다.

var light: Light3D
var base_energy := 1.0
var amount := 0.22       # 밝기 변동 폭(비율)
var speed := 1.0
var _phase := 0.0
var _seed := 0.0

static func attach(l: Light3D, amt: float = 0.22, spd: float = 1.0) -> Flicker:
	var f := Flicker.new()
	f.light = l
	f.base_energy = l.light_energy
	f.amount = amt
	f.speed = spd
	# 같은 장면의 불빛들이 동시에 깜빡이지 않도록 위상을 흩는다
	f._seed = float(l.get_instance_id() % 997) * 0.0631
	l.add_child(f)
	return f

func _process(delta: float) -> void:
	if light == null or not is_instance_valid(light):
		queue_free()
		return
	_phase += delta * speed
	var t := _phase + _seed
	var v := sin(t * 7.3) * 0.5 + sin(t * 3.1 + 1.7) * 0.32 + sin(t * 13.7 + 4.2) * 0.18
	light.light_energy = base_energy * (1.0 + v * amount)
