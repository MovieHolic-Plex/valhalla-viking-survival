class_name NetProbe
extends Node
## 멀티플레이 2인스턴스 자동 검증기.
## 주기적으로 동기화 상태를 stdout 에 찍고, 일정 시간 뒤 종료한다.
## 게임 로직은 건드리지 않는다(움직임만 흉내낸다).

var _t := 0.0
var _chat_seen := 0
var _life := 0.0
const RUN_TIME := 26.0

func _ready() -> void:
	Net.chat_received.connect(func(pname: String, text: String):
		_chat_seen += 1
		print("[NET CHAT] <%s> %s" % [pname, text]))

func _process(delta: float) -> void:
	_life += delta
	_t += delta

	# 서로 다른 위치로 움직여야 동기화가 눈에 보인다
	var p = GameState.player
	if p != null and is_instance_valid(p):
		p.input_locked = true
		p.stats.set_hp(p.stats.max_hp())
		var dir := 1.0 if Net.is_host else -1.0
		p.global_position.x += dir * delta * 2.0
		p.global_position.y = GameState.height_at(
			p.global_position.x, p.global_position.z) + 0.6

	if _t >= 2.0:
		_t = 0.0
		var me := "HOST" if Net.is_host else "CLIENT"
		var pos := Vector3.ZERO
		if p != null and is_instance_valid(p):
			pos = p.global_position
		var remotes := ""
		for id in Net.remote_players:
			var rp = Net.remote_players[id]
			if is_instance_valid(rp):
				remotes += " peer%d@%.1f,%.1f" % [id, rp.global_position.x,
					rp.global_position.z]
		print("[NET %s] online=%s seed=%d peers=%d me=(%.1f,%.1f) remotes:%s enemies=%d"
			% [me, str(Net.is_online), GameState.world_seed, Net.player_count(),
			pos.x, pos.z, remotes if remotes != "" else " none",
			Net.net_enemies.size()])
		if Net.is_host and _life > 6.0 and _life < 8.5:
			Net.say("동기화 확인 메시지")

	if _life > RUN_TIME:
		print("[NET] === 종료 (peers=%d, remotes=%d, chat=%d) ===" % [Net.player_count(),
			Net.remote_players.size(), _chat_seen])
		Net.leave()
		get_tree().quit()
