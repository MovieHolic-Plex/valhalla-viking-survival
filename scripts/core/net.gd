extends Node
## 멀티플레이(ENet). 오토로드 이름: Net
##
## 모델: **호스트 권위(host-authoritative)**
##  - 월드는 시드로 결정되므로 지형·자원 배치는 전송하지 않는다. 시드만 보낸다.
##  - 몬스터·시간은 호스트만 시뮬레이션하고 결과 좌표만 뿌린다.
##  - 각 플레이어의 위치/자세는 본인이 보내고 나머지가 받는다.
##  - 건축·지형 변형은 클라이언트가 "요청"하고 호스트가 승인 후 브로드캐스트한다.
##
## 오프라인이면 is_online == false 라서 아래 모든 경로가 그대로 no-op 이 되고
## 싱글플레이 동작에는 아무 영향이 없다.

signal peer_joined(id: int, pname: String)
signal peer_left(id: int)
signal chat_received(pname: String, text: String)
signal connection_failed()
signal world_received(sv: int, time: float, day: int, mods: Array)

const DEFAULT_PORT := 27015
const MAX_PEERS := 9
const SYNC_HZ := 15.0

var is_online := false
var is_host := false
var my_name := "바이킹"

var peer_names: Dictionary = {}           # peer_id -> 이름
var remote_players: Dictionary = {}       # peer_id -> RemotePlayer
var net_enemies: Dictionary = {}          # net_id -> Enemy
var net_pieces: Dictionary = {}           # net_id -> BuildPiece

var _next_net_id := 0
var _sync_acc := 0.0

## UPnP 로 공유기 포트를 열어 LAN 밖에서도 접속할 수 있게 한다.
## 실패해도 LAN 접속에는 영향이 없으므로 조용히 넘어간다.
var upnp_enabled := true
var external_ip := ""
var _upnp_thread: Thread = null
var dedicated := false      # 전용 서버 모드(플레이어 없이 서버만 돈다)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connect_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

## 긴 블로킹 작업(월드 생성) 중에 호출해 연결이 끊기지 않게 한다
func poll_now() -> void:
	if not is_online:
		return
	var mp := multiplayer.multiplayer_peer
	if mp != null:
		mp.poll()

## ENet 기본 타임아웃(5초)은 월드 생성 시간보다 짧다. 넉넉히 늘린다.
func _relax_timeout(peer: ENetMultiplayerPeer) -> void:
	var host := peer.host
	if host == null:
		return
	for p in host.get_peers():
		p.set_timeout(5000, 20000, 60000)

func new_net_id() -> int:
	_next_net_id += 1
	return _next_net_id

func my_id() -> int:
	return multiplayer.get_unique_id() if is_online else 1

func player_count() -> int:
	return maxi(1, peer_names.size())

func status_text() -> String:
	if not is_online:
		return tr("NET_OFFLINE")
	var role := tr("NET_HOSTING") if is_host else tr("NET_CLIENT")
	return "%s · %s" % [role, tr("NET_PLAYERS") % player_count()]

# ═══════════════════════════════════════════════ 연결
func host_game(port: int = DEFAULT_PORT, pname: String = "") -> bool:
	leave()
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
	peer_names.clear()
	peer_names[1] = my_name
	GameState.msg(tr("MSG_NET_HOSTING") % port)
	if upnp_enabled:
		_open_upnp_async(port)
	return true

## UPnP 매핑은 수 초가 걸릴 수 있어 별도 스레드에서 돌린다
func _open_upnp_async(port: int) -> void:
	if _upnp_thread != null:
		return
	_upnp_thread = Thread.new()
	_upnp_thread.start(_upnp_worker.bind(port))

func _upnp_worker(port: int) -> void:
	var up := UPNP.new()
	var dr := up.discover()
	if dr != UPNP.UPNP_RESULT_SUCCESS or up.get_gateway() == null \
			or not up.get_gateway().is_valid_gateway():
		call_deferred("_upnp_done", "", false)
		return
	var ok := up.add_port_mapping(port, port, "valhalla", "UDP", 0)
	ok = ok if ok == UPNP.UPNP_RESULT_SUCCESS else \
		up.add_port_mapping(port, port, "valhalla", "UDP")
	call_deferred("_upnp_done", up.query_external_address(),
		ok == UPNP.UPNP_RESULT_SUCCESS)

func _upnp_done(ip: String, ok: bool) -> void:
	if _upnp_thread != null:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	external_ip = ip
	if ok and ip != "":
		GameState.msg(tr("MSG_NET_UPNP_OK") % ip)
		print("[NET] UPnP mapped, external IP = ", ip)
	else:
		print("[NET] UPnP unavailable — LAN/직접 IP 접속만 가능")

func join_game(ip: String, port: int = DEFAULT_PORT, pname: String = "") -> bool:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		GameState.msg(tr("MSG_NET_JOIN_FAIL"))
		return false
	multiplayer.multiplayer_peer = peer
	is_online = true
	is_host = false
	if pname != "":
		my_name = pname
	_relax_timeout(peer)
	GameState.msg(tr("MSG_NET_CONNECTING") % ip)
	return true

func leave() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	is_online = false
	is_host = false
	for id in remote_players:
		var rp = remote_players[id]
		if is_instance_valid(rp):
			rp.queue_free()
	remote_players.clear()
	peer_names.clear()
	net_enemies.clear()
	net_pieces.clear()

# ── 연결 이벤트 ──
func _on_peer_connected(id: int) -> void:
	if not is_host:
		return
	var mp := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if mp != null:
		_relax_timeout(mp)
	# 새 접속자에게 월드 정보를 먼저 보낸다. 그가 월드를 다 만들면 _register 로 답한다.
	var mods: Array = GameState.gen.mods_to_array() if GameState.gen != null else []
	_recv_world.rpc_id(id, GameState.world_seed, GameState.time_of_day,
		GameState.day, mods)

func _on_peer_disconnected(id: int) -> void:
	var nm := str(peer_names.get(id, "?"))
	if remote_players.has(id):
		var rp = remote_players[id]
		if is_instance_valid(rp):
			rp.queue_free()
		remote_players.erase(id)
	peer_names.erase(id)
	peer_left.emit(id)
	GameState.msg(tr("MSG_NET_LEFT_PEER") % nm)
	if is_host:
		_roster.rpc(peer_names)

func _on_connected() -> void:
	var mp := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if mp != null:
		_relax_timeout(mp)
	GameState.msg(tr("MSG_NET_CONNECTED"))

func _on_connect_failed() -> void:
	leave()
	connection_failed.emit()
	GameState.msg(tr("MSG_NET_JOIN_FAIL"))

func _on_server_disconnected() -> void:
	GameState.msg(tr("MSG_NET_SERVER_GONE"))
	leave()

# ═══════════════════════════════════════════════ 월드 / 명단
@rpc("authority", "call_remote", "reliable")
func _recv_world(sv: int, time: float, day: int, mods: Array) -> void:
	world_received.emit(sv, time, day, mods)

## 월드 생성을 마친 뒤 호출한다. 이때부터 동기화가 시작된다.
func announce_ready() -> void:
	if not is_online:
		return
	if is_host:
		peer_names[1] = my_name
		_roster.rpc(peer_names)
		return
	_register.rpc_id(1, my_name)

@rpc("any_peer", "call_remote", "reliable")
func _register(pname: String) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	peer_names[id] = pname
	peer_joined.emit(id, pname)
	GameState.msg(tr("MSG_NET_JOINED_PEER") % pname)
	_roster.rpc(peer_names)
	# 이미 놓여 있는 건축물을 새 접속자에게 재현시킨다
	for nid in net_pieces:
		var p = net_pieces[nid]
		if is_instance_valid(p):
			_place_piece.rpc_id(id, nid, p.piece_id, p.global_position, p.rotation.y)
	# 접속 전에 이미 살아 있던 몬스터도 마찬가지로 재현시킨다.
	# (register_enemy 는 스폰 순간에만 뿌리므로 늦게 들어온 피어에겐 안 보인다)
	for nid2 in net_enemies:
		var e = net_enemies[nid2]
		if is_instance_valid(e) and not e._dead:
			_spawn_enemy.rpc_id(id, nid2, str(e.cfg.get("id", "greyling")),
				e.global_position, e.tamed)

@rpc("authority", "call_remote", "reliable")
func _roster(names: Dictionary) -> void:
	peer_names = names.duplicate()
	for id in remote_players:
		var rp = remote_players[id]
		if is_instance_valid(rp) and names.has(id):
			rp.set_player_name(str(names[id]))

# ═══════════════════════════════════════════════ 주기 동기화
func _process(delta: float) -> void:
	if not is_online:
		return
	_sync_acc += delta
	if _sync_acc < 1.0 / SYNC_HZ:
		return
	_sync_acc = 0.0

	var p = GameState.player
	if p != null and is_instance_valid(p):
		_player_state.rpc(p.global_position, p.yaw, p.velocity,
			p.stats.hp / maxf(p.stats.max_hp(), 1.0))

	if is_host:
		_broadcast_enemies()
		_time_sync.rpc(GameState.time_of_day, GameState.day)

func _ensure_remote(id: int):
	var rp = remote_players.get(id)
	if rp != null and is_instance_valid(rp):
		return rp
	var scene := get_tree().current_scene
	if scene == null:
		return null
	rp = RemotePlayer.new()
	rp.peer_id = id
	rp.player_name = str(peer_names.get(id, "바이킹"))
	scene.add_child(rp)
	remote_players[id] = rp
	return rp

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _player_state(pos: Vector3, yaw: float, vel: Vector3, hp_frac: float) -> void:
	var id := multiplayer.get_remote_sender_id()
	var rp = _ensure_remote(id)
	if rp == null:
		return
	rp.apply_state(pos, yaw, vel, hp_frac)
	# 호스트는 받은 위치를 나머지 피어에게 중계한다 (클라이언트끼리는 직접 연결이 없다)
	if is_host:
		for other in peer_names.keys():
			var oid := int(other)
			if oid != 1 and oid != id:
				_relay_player.rpc_id(oid, id, pos, yaw, vel, hp_frac)

@rpc("authority", "call_remote", "unreliable_ordered")
func _relay_player(id: int, pos: Vector3, yaw: float, vel: Vector3,
		hp_frac: float) -> void:
	if id == my_id():
		return
	var rp = _ensure_remote(id)
	if rp != null:
		rp.apply_state(pos, yaw, vel, hp_frac)

@rpc("authority", "call_remote", "unreliable")
func _time_sync(t: float, day: int) -> void:
	GameState.time_of_day = t
	GameState.day = day

# ═══════════════════════════════════════════════ 몬스터
## 호스트에서 몬스터가 생성될 때 호출된다. 오프라인/클라이언트면 무시.
func register_enemy(e) -> void:
	if not is_online or not is_host or e == null:
		return
	var nid := new_net_id()
	e.net_id = nid
	net_enemies[nid] = e
	_spawn_enemy.rpc(nid, str(e.cfg.get("id", "greyling")), e.global_position, e.tamed)

@rpc("authority", "call_remote", "reliable")
func _spawn_enemy(nid: int, id: String, pos: Vector3, tamed: bool) -> void:
	if net_enemies.has(nid) and is_instance_valid(net_enemies[nid]):
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var e = Enemy.spawn(id, scene, pos)
	if e == null:
		return
	e.net_id = nid
	e.net_remote = true       # AI 정지 — 호스트가 보내는 좌표만 따른다
	e.tamed = tamed
	net_enemies[nid] = e

func enemy_died(e) -> void:
	if not is_online or not is_host or e == null or e.net_id <= 0:
		return
	_despawn_enemy.rpc(e.net_id)
	net_enemies.erase(e.net_id)

@rpc("authority", "call_remote", "reliable")
func _despawn_enemy(nid: int) -> void:
	var e = net_enemies.get(nid)
	net_enemies.erase(nid)
	if e != null and is_instance_valid(e):
		e.net_kill()

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
		xs.append(e.rig.rotation.y if e.rig != null else 0.0)
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

## 클라이언트의 타격은 호스트가 판정한다. true 를 반환하면 로컬 판정을 건너뛴다.
func hit_enemy(e, dmg: Dictionary, from_pos: Vector3, kb: float) -> bool:
	if not is_online or is_host or e == null or e.net_id <= 0:
		return false
	_request_hit.rpc_id(1, e.net_id, dmg, from_pos, kb)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _request_hit(nid: int, dmg: Dictionary, from_pos: Vector3, kb: float) -> void:
	if not is_host:
		return
	var e = net_enemies.get(nid)
	if e != null and is_instance_valid(e):
		e.take_hit(dmg, from_pos, null, kb)

# ═══════════════════════════════════════════════ 건축
## 호스트에서 건축물이 놓였을 때 호출. 모두에게 재현시킨다.
func piece_placed(piece) -> void:
	if not is_online or not is_host or piece == null:
		return
	var nid := new_net_id()
	piece.net_id = nid
	net_pieces[nid] = piece
	_place_piece.rpc(nid, piece.piece_id, piece.global_position, piece.rotation.y)

## 클라이언트가 건축을 시도할 때. true 를 반환하면 로컬 생성을 건너뛴다.
func request_place(piece_id: String, pos: Vector3, yaw: float) -> bool:
	if not is_online or is_host:
		return false
	_request_place.rpc_id(1, piece_id, pos, yaw)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _request_place(piece_id: String, pos: Vector3, yaw: float) -> void:
	if not is_host:
		return
	var bs = _build_system()
	if bs == null:
		return
	var piece = bs.place_remote(piece_id, pos, yaw)
	if piece != null:
		piece_placed(piece)

@rpc("authority", "call_remote", "reliable")
func _place_piece(nid: int, piece_id: String, pos: Vector3, yaw: float) -> void:
	if net_pieces.has(nid) and is_instance_valid(net_pieces[nid]):
		return
	var bs = _build_system()
	if bs == null:
		return
	var piece = bs.place_remote(piece_id, pos, yaw)
	if piece != null:
		piece.net_id = nid
		net_pieces[nid] = piece

func piece_removed(piece) -> void:
	if not is_online or piece == null or piece.net_id <= 0:
		return
	if is_host:
		var nid: int = piece.net_id
		net_pieces.erase(nid)
		_remove_piece.rpc(nid)
	else:
		_request_remove.rpc_id(1, piece.net_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_remove(nid: int) -> void:
	if not is_host:
		return
	var p = net_pieces.get(nid)
	net_pieces.erase(nid)
	_remove_piece.rpc(nid)
	if p != null and is_instance_valid(p):
		p.net_id = 0
		p.destroy(true)

@rpc("authority", "call_remote", "reliable")
func _remove_piece(nid: int) -> void:
	var p = net_pieces.get(nid)
	net_pieces.erase(nid)
	if p != null and is_instance_valid(p):
		p.net_id = 0
		p.destroy(true)

func _build_system():
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var bs = scene.get_node_or_null("build")
	if bs == null or not bs.has_method("place_remote"):
		return null
	return bs

# ═══════════════════════════════════════════════ 지형 변형
## true 반환 시 호출자는 로컬 적용을 건너뛴다(호스트 승인 대기).
func request_terrain(center: Vector3, radius: float, mode: String,
		amount: float) -> bool:
	if not is_online:
		return false
	if is_host:
		_terrain.rpc(center, radius, mode, amount)
		return false      # 호스트는 로컬에서도 그대로 적용한다
	_request_terrain.rpc_id(1, center, radius, mode, amount)
	return true

@rpc("any_peer", "call_remote", "reliable")
func _request_terrain(center: Vector3, radius: float, mode: String,
		amount: float) -> void:
	if not is_host:
		return
	_terrain.rpc(center, radius, mode, amount)
	_apply_terrain(center, radius, mode, amount)

@rpc("authority", "call_remote", "reliable")
func _terrain(center: Vector3, radius: float, mode: String, amount: float) -> void:
	_apply_terrain(center, radius, mode, amount)

func _apply_terrain(center: Vector3, radius: float, mode: String,
		amount: float) -> void:
	if GameState.gen == null:
		return
	var keys := GameState.gen.modify(center, radius, mode, amount)
	var scene := get_tree().current_scene
	var cm = scene.get_node_or_null("chunks") if scene != null else null
	if cm != null:
		cm.rebuild(keys)

# ═══════════════════════════════════════════════ 채팅
func say(text: String) -> void:
	var t := text.strip_edges()
	if t == "":
		return
	chat_received.emit(my_name, t)
	if is_online:
		_chat.rpc(my_name, t)

@rpc("any_peer", "call_remote", "reliable")
func _chat(pname: String, text: String) -> void:
	chat_received.emit(pname, text)
	# 호스트는 다른 피어에게도 전달한다
	if is_host:
		var from := multiplayer.get_remote_sender_id()
		for other in peer_names.keys():
			var oid := int(other)
			if oid != 1 and oid != from:
				_chat.rpc_id(oid, pname, text)
