extends Node
## 멀티플레이(ENet). 오토로드 이름: Net
##
## 모델: **호스트 권위(host-authoritative)**
##  - 월드는 시드로 결정되므로 지형/자원 배치는 전송하지 않는다.
##  - 몬스터·보스·아이템 드롭·시간은 호스트가 시뮬레이션하고 결과만 뿌린다.
##  - 각 플레이어의 위치/자세는 본인이 보내고 호스트가 중계한다.
##  - 건축/지형 변형/채집은 클라이언트가 "요청"하고 호스트가 승인 후 브로드캐스트한다.
##
## 오프라인일 때는 is_online == false 라 모든 경로가 그대로 싱글플레이로 동작한다.

signal peer_joined(id: int, pname: String)
signal peer_left(id: int)
signal chat_received(pname: String, text: String)
signal connection_failed()
signal connected_ok()

const DEFAULT_PORT := 27015
const MAX_PEERS := 8
const SYNC_HZ := 15.0

var is_online := false
var is_host := false
var my_name := "바이킹"
var peer_names: Dictionary = {}          # peer_id -> 이름
var remote_players: Dictionary = {}      # peer_id -> RemotePlayer
var net_enemies: Dictionary = {}         # net_id -> Enemy
var net_pieces: Dictionary = {}          # net_id -> BuildPiece
var net_drops: Dictionary = {}           # net_id -> ItemDrop
var _next_net_id := 1
var _sync_acc := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func new_net_id() -> int:
	_next_net_id += 1
	return _next_net_id

# ═══════════════════════════════════════════════ 연결
func host_game(port: int = DEFAULT_PORT, pname: String = "") -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PEERS)
	if err != OK:
		GameState.msg(tr("MSG_NET_HOST_FAIL") % err)
		return false
	multiplayer.multiplayer_peer = peer
	is_online = true
	is_host = true
	if pname != "":
		my_name = pname
	peer_names[1] = my_name
	GameState.msg(tr("MSG_NET_HOSTING") % port)
	return true

func join_game(ip: String, port: int = DEFAULT_PORT, pname: String = "") -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		GameState.msg(tr("MSG_NET_JOIN_FAIL") % err)
		return false
	multiplayer.multiplayer_peer = peer
	is_online = true
	is_host = false
	if pname != "":
		my_name = pname
	GameState.msg(tr("MSG_NET_CONNECTING") % ip)
	return true

func leave() -> void:
	if not is_online:
		return
	multiplayer.multiplayer_peer = null
	is_online = false
	is_host = false
	for id in remote_players:
		if is_instance_valid(remote_players[id]):
			remote_players[id].queue_free()
	remote_players.clear()
	peer_names.clear()
	net_enemies.clear()
	net_pieces.clear()
	net_drops.clear()
	GameState.msg(tr("MSG_NET_LEFT"))

func my_id() -> int:
	return multiplayer.get_unique_id() if is_online else 1

# ═══════════════════════════════════════════════ 연결 이벤트
func _on_peer_connected(id: int) -> void:
	if not is_host:
		return
	# 새 접속자에게 월드 정보를 먼저 보낸다
	_send_world.rpc_id(id, GameState.world_seed, GameState.time_of_day, GameState.day,
		GameState.gen.mods_to_array() if GameState.gen != null else [])
	# 현재 살아있는 것들을 재현시킨다
	for nid in net_pieces:
		var p = net_pieces[nid]
		if is_instance_valid(p):
			_place_piece.rpc_id(id, nid, p.piece_id, p.global_position, p.yaw)
	for nid in net_enemies:
		var e = net_enemies[nid]
		if is_instance_valid(e):
			_spawn_enemy.rpc_id(id, nid, str(e.cfg.get("id", "greyling")),
				e.global_position, e.tamed)

func _on_peer_disconnected(id: int) -> void:
	if remote_players.has(id):
		if is_instance_valid(remote_players[id]):
			remote_players[id].queue_free()
		remote_players.erase(id)
	var nm: String = str(peer_names.get(id, "?"))
	peer_names.erase(id)
	peer_left.emit(id)
	GameState.msg(tr("MSG_NET_LEFT_PEER") % nm)

func _on_connected() -> void:
	connected_ok.emit()
	_register.rpc_id(1, my_name)
	GameState.msg(tr("MSG_NET_CONNECTED"))

func _on_connect_failed() -> void:
	is_online = false
	connection_failed.emit()
	GameState.msg(tr("MSG_NET_JOIN_FAIL") % 0)

func _on_server_disconnected() -> void:
	GameState.msg(tr("MSG_NET_SERVER_GONE"))
	leave()

# ═══════════════════════════════════════════════ 등록 / 월드
@rpc("any_peer", "call_remote", "reliable")
func _register(pname: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	peer_names[id] = pname
	peer_joined.emit(id, pname)
	GameState.msg(tr("MSG_NET_JOINED_PEER") % pname)
	if is_host:
		# 모두에게 명단을 다시 알린다
		_roster.rpc(peer_names)

@rpc("authority", "call_remote", "reliable")
func _roster(names: Dictionary) -> void:
	peer_names = names.duplicate()

@rpc("authority", "call_remote", "reliable")
func _send_world(sv: int, time: float, day: int, mods: Array) -> void:
	# 클라이언트는 같은 시드로 월드를 다시 만든다 (지형 데이터는 전송 불필요)
	GameState.new_world(sv)
	GameState.time_of_day = time
	GameState.day = day
	if GameState.gen != null:
		GameState.gen.mods_from_array(mods)
	var main = get_tree().current_scene
	if main != null and main.has_method("rebuild_world_after_net"):
		main.rebuild_world_after_net()

# ═══════════════════════════════════════════════ 플레이어 동기화
func _process(delta: float) -> void:
	if not is_online:
		return
	_sync_acc += delta
	if _sync_acc < 1.0 / SYNC_HZ:
		return
	_sync_acc = 0.0

	var p := GameState.player
	if p != null and is_instance_valid(p):
		_player_state.rpc(p.global_position, p.rig.rotation.y + p.rotation.y,
			Vector3(p.velocity.x, p.velocity.y, p.velocity.z),
			p.stats.hp / maxf(p.stats.max_hp(), 1.0),
			p.inventory.equipped_id(Inventory.SLOT_RIGHT))

	if is_host:
		_broadcast_enemies()
		_broadcast_time()

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _player_state(pos: Vector3, yaw: float, vel: Vector3, hp_frac: float,
		weapon: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	var rp = remote_players.get(id)
	if rp == null or not is_instance_valid(rp):
		rp = RemotePlayer.new()
		rp.peer_id = id
		rp.player_name = str(peer_names.get(id, "바이킹"))
		get_tree().current_scene.add_child(rp)
		remote_players[id] = rp
	rp.apply_state(pos, yaw, vel, hp_frac, weapon)

# ═══════════════════════════════════════════════ 몬스터 동기화
func register_enemy(e) -> void:
	if not is_online or not is_host:
		return
	var nid := new_net_id()
	e.net_id = nid
	net_enemies[nid] = e
	_spawn_enemy.rpc(nid, str(e.cfg.get("id", "greyling")), e.global_position, e.tamed)

@rpc("authority", "call_remote", "reliable")
func _spawn_enemy(nid: int, id: String, pos: Vector3, tamed: bool) -> void:
	if net_enemies.has(nid) and is_instance_valid(net_enemies[nid]):
		return
	var e = Enemy.spawn(id, get_tree().current_scene, pos)
	if e == null:
		return
	e.net_id = nid
	e.net_remote = true          # AI 정지, 호스트가 보내는 상태만 반영
	e.tamed = tamed
	net_enemies[nid] = e

@rpc("authority", "call_remote", "reliable")
func _despawn_enemy(nid: int) -> void:
	var e = net_enemies.get(nid)
	if e != null and is_instance_valid(e):
		e.net_kill()
	net_enemies.erase(nid)

func enemy_died(e) -> void:
	if is_online and is_host and e.net_id > 0:
		_despawn_enemy.rpc(e.net_id)
		net_enemies.erase(e.net_id)

func _broadcast_enemies() -> void:
	var ids := PackedInt32Array()
	var xs := PackedFloat32Array()
	for nid in net_enemies:
		var e = net_enemies[nid]
		if not is_instance_valid(e) or e._dead:
			continue
		ids.append(nid)
		xs.append(e.global_position.x)
		xs.append(e.global_position.y)
		xs.append(e.global_position.z)
		xs.append(e.rotation.y)
		xs.append(e.hp / maxf(e.max_hp, 1.0))
	if ids.is_empty():
		return
	_enemy_states.rpc(ids, xs)

@rpc("authority", "call_remote", "unreliable_ordered")
func _enemy_states(ids: PackedInt32Array, xs: PackedFloat32Array) -> void:
	for i in ids.size():
		var e = net_enemies.get(ids[i])
		if e == null or not is_instance_valid(e):
			continue
		var b := i * 5
		e.net_apply(Vector3(xs[b], xs[b + 1], xs[b + 2]), xs[b + 3], xs[b + 4])

## 클라이언트가 몬스터를 때렸다 → 호스트가 판정
@rpc("any_peer", "call_remote", "reliable")
func request_hit_enemy(nid: int, dmg: Dictionary, from_pos: Vector3, kb: float) -> void:
	if not is_host:
		return
	var e = net_enemies.get(nid)
	if e != null and is_instance_valid(e):
		e.take_hit(dmg, from_pos, null, kb)

func hit_enemy(e, dmg: Dictionary, from_pos: Vector3, kb: float) -> bool:
	# 클라이언트면 호스트에 요청만 하고 로컬 판정은 하지 않는다
	if is_online and not is_host and e.net_id > 0:
		request_hit_enemy.rpc_id(1, e.net_id, dmg, from_pos, kb)
		return true
	return false

# ═══════════════════════════════════════════════ 시간
func _broadcast_time() -> void:
	_time_sync.rpc(GameState.time_of_day, GameState.day)

@rpc("authority", "call_remote", "unreliable")
func _time_sync(t: float, day: int) -> void:
	GameState.time_of_day = t
	GameState.day = day

# ═══════════════════════════════════════════════ 건축
func request_place(piece_id: String, pos: Vector3, yaw: float) -> void:
	if is_host:
		_do_place(piece_id, pos, yaw)
	else:
		_request_place.rpc_id(1, piece_id, pos, yaw)

@rpc("any_peer", "call_remote", "reliable")
func _request_place(piece_id: String, pos: Vector3, yaw: float) -> void:
	if is_host:
		_do_place(piece_id, pos, yaw)

func _do_place(piece_id: String, pos: Vector3, yaw: float) -> void:
	var nid := new_net_id()
	_place_piece.rpc(nid, piece_id, pos, yaw)
	_place_piece(nid, piece_id, pos, yaw)

@rpc("authority", "call_remote", "reliable")
func _place_piece(nid: int, piece_id: String, pos: Vector3, yaw: float) -> void:
	if net_pieces.has(nid) and is_instance_valid(net_pieces[nid]):
		return
	var main = get_tree().current_scene
	var bs = main.get_node_or_null("build")
	var piece := BuildPiece.make(piece_id)
	main.add_child(piece)
	piece.global_position = pos
	piece.rotation.y = yaw
	piece.yaw = yaw
	piece.net_id = nid
	net_pieces[nid] = piece
	if bs != null:
		piece.removed.connect(bs._on_piece_removed)
		bs.pieces.append(piece)
		bs.call_deferred("recompute_support")

func request_remove(nid: int) -> void:
	if nid <= 0:
		return
	if is_host:
		_remove_piece.rpc(nid)
		_remove_piece(nid)
	else:
		_request_remove.rpc_id(1, nid)

@rpc("any_peer", "call_remote", "reliable")
func _request_remove(nid: int) -> void:
	if is_host:
		_remove_piece.rpc(nid)
		_remove_piece(nid)

@rpc("authority", "call_remote", "reliable")
func _remove_piece(nid: int) -> void:
	var p = net_pieces.get(nid)
	if p != null and is_instance_valid(p):
		p.net_id = 0
		p.destroy(true)
	net_pieces.erase(nid)

# ═══════════════════════════════════════════════ 지형 변형
func request_terrain(center: Vector3, radius: float, mode: String, amount: float) -> void:
	if is_host:
		_terrain.rpc(center, radius, mode, amount)
		_terrain(center, radius, mode, amount)
	else:
		_request_terrain.rpc_id(1, center, radius, mode, amount)

@rpc("any_peer", "call_remote", "reliable")
func _request_terrain(center: Vector3, radius: float, mode: String,
		amount: float) -> void:
	if is_host:
		_terrain.rpc(center, radius, mode, amount)
		_terrain(center, radius, mode, amount)

@rpc("authority", "call_remote", "reliable")
func _terrain(center: Vector3, radius: float, mode: String, amount: float) -> void:
	if GameState.gen == null:
		return
	var keys := GameState.gen.modify(center, radius, mode, amount)
	var cm = get_tree().current_scene.get_node_or_null("chunks")
	if cm != null:
		cm.rebuild(keys)

# ═══════════════════════════════════════════════ 채팅
func say(text: String) -> void:
	if text.strip_edges() == "":
		return
	if is_online:
		_chat.rpc(my_name, text)
	chat_received.emit(my_name, text)

@rpc("any_peer", "call_remote", "reliable")
func _chat(pname: String, text: String) -> void:
	chat_received.emit(pname, text)

# ═══════════════════════════════════════════════ 유틸
func player_count() -> int:
	if not is_online:
		return 1
	return peer_names.size()

func status_text() -> String:
	if not is_online:
		return tr("NET_OFFLINE")
	return (tr("NET_HOSTING") if is_host else tr("NET_CLIENT")) \
		+ "  ·  %d명" % player_count()
