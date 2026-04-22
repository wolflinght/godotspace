extends Node

# 星河放置：暗面危机 - 服务端主节点
# 运行方式: godot --headless --path /server/godot_server res://scenes/server/ServerMain.tscn

const PORT = 7777
const TICK_INTERVAL = 1.0  # 每秒 tick 一次

var _ws_server: WebSocketMultiplayerPeer
var _db: DatabaseManager
var _tick_timer: float = 0.0
var _clients: Dictionary = {}  # peer_id -> player_data

func _ready() -> void:
	print("[Server] 星河放置服务端启动中...")

	# 初始化数据库连接
	_db = DatabaseManager.new()
	add_child(_db)
	if not _db.connect_db():
		push_error("[Server] 数据库连接失败，服务端退出")
		get_tree().quit(1)
		return

	# 连接定时器信号
	var daily_timer = get_node_or_null("DailyResetTimer")
	if daily_timer:
		daily_timer.timeout.connect(_check_daily_reset)

	var salary_timer = get_node_or_null("SalaryTimer")
	if salary_timer:
		salary_timer.timeout.connect(_deduct_salaries)

	# 启动 WebSocket 服务器
	_ws_server = WebSocketMultiplayerPeer.new()
	var err = _ws_server.create_server(PORT)
	if err != OK:
		push_error("[Server] WebSocket 服务器启动失败: " + str(err))
		get_tree().quit(1)
		return

	get_tree().get_multiplayer().multiplayer_peer = _ws_server
	get_tree().get_multiplayer().peer_connected.connect(_on_peer_connected)
	get_tree().get_multiplayer().peer_disconnected.connect(_on_peer_disconnected)

	print("[Server] WebSocket 服务器监听端口 %d" % PORT)
	print("[Server] 服务端就绪，等待玩家连接...")

func _process(delta: float) -> void:
	_tick_timer += delta
	if _tick_timer >= TICK_INTERVAL:
		_tick_timer -= TICK_INTERVAL
		_server_tick()

func _server_tick() -> void:
	# 每秒推进所有玩家状态
	var now = Time.get_unix_time_from_system()

	for peer_id in _clients.keys():
		var player = _clients[peer_id]
		if player == null:
			continue
		_process_player_tick(peer_id, player, now)

func _process_player_tick(peer_id: int, player: Dictionary, now: float) -> void:
	var ship = player.get("ship", {})
	var status = ship.get("status", "docked")

	match status:
		"in_transit":
			_tick_transit(peer_id, player, ship, now)
		"working":
			_tick_working(peer_id, player, ship, now)
		"stranded":
			_tick_stranded(peer_id, player, ship, now)

func _tick_transit(peer_id: int, player: Dictionary, ship: Dictionary, now: float) -> void:
	# 动态耗电：每分钟耗电率 = 总耗电 / 总分钟数（四舍五入）
	var depart_time: float = ship.get("depart_time", now)
	var eta: float = ship.get("eta", now)
	var total_minutes: float = (eta - depart_time) / 60.0
	var total_power_cost: int = ship.get("total_power_cost", 0)

	if total_minutes <= 0:
		return

	var drain_per_minute: int = roundi(float(total_power_cost) / total_minutes)
	var elapsed_minutes: float = (now - depart_time) / 60.0
	var expected_power_used: int = roundi(elapsed_minutes * drain_per_minute)
	var actual_power_used: int = ship.get("power_used_so_far", 0)

	var drain_this_tick: int = expected_power_used - actual_power_used
	if drain_this_tick > 0:
		ship["power"] = max(0, ship.get("power", 0) - drain_this_tick)
		ship["power_used_so_far"] = expected_power_used

		# 检查是否抛锚
		if ship["power"] <= 0:
			_handle_stranded(peer_id, player, ship)
			return

	# 检查是否到达目的地
	if now >= eta:
		_handle_arrival(peer_id, player, ship)
		return

	# 遭遇战判定（每10距离单位一次）
	_check_encounter(peer_id, player, ship, now)

	# 推送状态更新（每10秒推一次，不每秒推）
	var last_push: float = ship.get("last_state_push", 0.0)
	if now - last_push >= 10.0:
		ship["last_state_push"] = now
		_push_state_update(peer_id, ship)

func _tick_working(peer_id: int, player: Dictionary, ship: Dictionary, now: float) -> void:
	# 作业中：按矿机产出累计资源
	var last_tick: float = ship.get("last_work_tick", now)
	var elapsed_hours: float = (now - last_tick) / 3600.0
	ship["last_work_tick"] = now

	if elapsed_hours <= 0:
		return

	var mining_rate: float = ship.get("mining_rate", 0.0)
	var gain: float = mining_rate * elapsed_hours
	if gain <= 0:
		return

	var poi_id: String = ship.get("current_poi", "")
	var resource_type: String = ship.get("mining_resource", "")

	if poi_id == "" or resource_type == "":
		return

	# 从 POI 资源池扣除
	var actual_gain: float = _db.consume_poi_resource(poi_id, resource_type, gain)
	if actual_gain > 0:
		_db.add_player_resource(player.get("player_id", 0), resource_type, actual_gain)
		player["resources"][resource_type] = player["resources"].get(resource_type, 0.0) + actual_gain

func _tick_stranded(_peer_id: int, _player: Dictionary, _ship: Dictionary, _now: float) -> void:
	# 抛锚状态：速度降为1，等待救援或购买救援
	pass

func _handle_stranded(peer_id: int, _player: Dictionary, ship: Dictionary) -> void:
	ship["status"] = "stranded"
	ship["speed_override"] = 1
	print("[Server] 玩家 %d 飞船抛锚！" % peer_id)
	_push_event(peer_id, "stranded", {"message": "电力耗尽，飞船进入抛锚状态！"})
	_db.save_ship(ship)

func _handle_arrival(peer_id: int, player: Dictionary, ship: Dictionary) -> void:
	ship["status"] = "working"
	ship["current_poi"] = ship.get("target_poi", "")
	ship["last_work_tick"] = Time.get_unix_time_from_system()
	print("[Server] 玩家 %d 抵达 %s" % [peer_id, ship["current_poi"]])
	_push_event(peer_id, "arrival", {"poi": ship["current_poi"]})
	_db.save_ship(ship)

	# 检查任务进度
	MissionManager.check_arrival(player, ship)

func _check_encounter(peer_id: int, player: Dictionary, ship: Dictionary, now: float) -> void:
	# 按距离分段判定：每飞行10距离单位触发一次
	var depart_time: float = ship.get("depart_time", now)
	var eta: float = ship.get("eta", now)
	var total_distance: float = ship.get("travel_distance", 0.0)

	if total_distance <= 0 or eta <= depart_time:
		return

	var progress: float = (now - depart_time) / (eta - depart_time)
	var current_dist: float = progress * total_distance
	var last_encounter_dist: float = ship.get("last_encounter_dist", 0.0)

	# 每10距离单位检查一次
	var segments_passed: int = int(current_dist / 10.0)
	var last_segments: int = int(last_encounter_dist / 10.0)

	if segments_passed <= last_segments:
		return

	ship["last_encounter_dist"] = float(segments_passed * 10)

	# 危险度 → 遭遇概率
	var danger: int = ship.get("target_danger", 0)
	var encounter_chance: float = _danger_to_chance(danger)

	if randf() < encounter_chance:
		_trigger_encounter(peer_id, player, ship)

func _danger_to_chance(danger: int) -> float:
	match danger:
		0: return 0.05
		1: return 0.10
		2: return 0.15
		3: return 0.20
		4: return 0.25
		5: return 0.30
		_: return 0.05

func _trigger_encounter(peer_id: int, player: Dictionary, ship: Dictionary) -> void:
	# 暂停航行，执行战斗结算
	var danger: int = ship.get("target_danger", 0)
	var combat_result = CombatSystem.resolve(player, ship, danger)

	if combat_result.player_wins:
		_push_event(peer_id, "encounter", {
			"result": "victory",
			"enemy": combat_result.enemy_name,
			"credits_gained": combat_result.credits_gained,
			"combat_log": combat_result.log
		})
		# 增加星币
		ship["credits"] = ship.get("credits", 0) + combat_result.credits_gained
		_db.add_credits(player.get("player_id", 0), combat_result.credits_gained)
	else:
		# 战败：飞船受损，强制返回最近空间站
		ship["hp"] = max(0, ship.get("hp", 100) - combat_result.hull_damage)
		_handle_defeat(peer_id, player, ship, combat_result)

func _handle_defeat(peer_id: int, _player: Dictionary, ship: Dictionary, combat_result: Dictionary) -> void:
	ship["status"] = "docked"
	ship["current_poi"] = ship.get("nearest_station", "CYG-ST-01")
	ship["target_poi"] = ""
	print("[Server] 玩家 %d 战败，弹射回 %s" % [peer_id, ship["current_poi"]])
	_push_event(peer_id, "encounter", {
		"result": "defeat",
		"enemy": combat_result.enemy_name,
		"combat_log": combat_result.log,
		"ejected_to": ship["current_poi"]
	})
	_db.save_ship(ship)

func _on_peer_connected(peer_id: int) -> void:
	print("[Server] 新连接: peer_id=%d" % peer_id)
	# 等待客户端发送登录消息

func _on_peer_disconnected(peer_id: int) -> void:
	print("[Server] 断开连接: peer_id=%d" % peer_id)
	if _clients.has(peer_id):
		var player = _clients[peer_id]
		# 保存最新状态到数据库
		_db.save_player_state(player)
		_clients.erase(peer_id)

@rpc("any_peer", "reliable")
func receive_message(json_str: String) -> void:
	var peer_id = get_tree().get_multiplayer().get_remote_sender_id()
	var data = JSON.parse_string(json_str)
	if data == null:
		return
	_handle_client_message(peer_id, data)

func _handle_client_message(peer_id: int, data: Dictionary) -> void:
	var msg_type: String = data.get("type", "")

	match msg_type:
		"login":
			_handle_login(peer_id, data)
		"action":
			_handle_action(peer_id, data)
		"ping":
			_send_pong(peer_id)
		_:
			print("[Server] 未知消息类型: " + msg_type)

func _handle_login(peer_id: int, data: Dictionary) -> void:
	var username: String = data.get("username", "")
	var password: String = data.get("password", "")

	var player = _db.authenticate_player(username, password)
	if player == null:
		_send_to_peer(peer_id, {"type": "error", "message": "登录失败：用户名或密码错误"})
		return

	_clients[peer_id] = player
	print("[Server] 玩家 %s 登录成功 (peer_id=%d)" % [username, peer_id])

	# 推送完整状态快照
	_send_to_peer(peer_id, {
		"type": "state_snapshot",
		"payload": player
	})

func _handle_action(peer_id: int, data: Dictionary) -> void:
	if not _clients.has(peer_id):
		_send_to_peer(peer_id, {"type": "error", "message": "请先登录"})
		return

	var player = _clients[peer_id]
	var action: String = data.get("action", "")
	var payload: Dictionary = data.get("payload", {})

	match action:
		"depart":
			ActionHandler.handle_depart(peer_id, player, payload, _db, self)
		"dock":
			ActionHandler.handle_dock(peer_id, player, payload, _db, self)
		"equip":
			ActionHandler.handle_equip(peer_id, player, payload, _db, self)
		"unequip":
			ActionHandler.handle_unequip(peer_id, player, payload, _db, self)
		"accept_mission":
			ActionHandler.handle_accept_mission(peer_id, player, payload, _db, self)
		"buy_fuel":
			ActionHandler.handle_buy_fuel(peer_id, player, payload, _db, self)
		"connect_grid":
			ActionHandler.handle_connect_grid(peer_id, player, payload, _db, self)
		"sos":
			ActionHandler.handle_sos(peer_id, player, payload, _db, self)
		_:
			_send_to_peer(peer_id, {"type": "error", "message": "未知操作: " + action})

func _send_pong(peer_id: int) -> void:
	_send_to_peer(peer_id, {"type": "pong"})

func _push_state_update(peer_id: int, ship: Dictionary) -> void:
	_send_to_peer(peer_id, {
		"type": "state_update",
		"payload": {
			"power": ship.get("power", 0),
			"max_power": ship.get("max_power", 500),
			"status": ship.get("status", "docked"),
			"current_poi": ship.get("current_poi", ""),
			"target_poi": ship.get("target_poi", ""),
			"eta": ship.get("eta", 0),
			"hp": ship.get("hp", 100),
			"shield": ship.get("shield", 0),
			"credits": ship.get("credits", 0)
		}
	})

func _push_event(peer_id: int, event_name: String, payload: Dictionary) -> void:
	_send_to_peer(peer_id, {
		"type": "event",
		"event": event_name,
		"payload": payload
	})

func send_to_peer(peer_id: int, data: Dictionary) -> void:
	_send_to_peer(peer_id, data)

func _send_to_peer(peer_id: int, data: Dictionary) -> void:
	var json_str = JSON.stringify(data)
	rpc_id(peer_id, "receive_message", json_str)

# 每日 00:00 重置 POI 资源池
func _check_daily_reset() -> void:
	var now = Time.get_datetime_dict_from_system()
	# 每分钟检查一次，判断是否是 00:00
	if now.hour == 0 and now.minute == 0:
		_db.reset_all_poi_resources()
		# 广播全服事件
		for peer_id in _clients.keys():
			_push_event(peer_id, "global_event", {
				"event_type": "daily_reset",
				"message": "宇宙引力潮汐爆发！所有星区资源储量已恢复！"
			})

# 每30分钟扣除船员薪水
func _deduct_salaries() -> void:
	_db.deduct_crew_salaries()
	# 通知在线玩家
	for peer_id in _clients.keys():
		var player = _clients[peer_id]
		# 检查是否有负债
		for crew_member in player.get("crew", []):
			if crew_member.get("debt", 0) > 0:
				_push_event(peer_id, "salary_warning", {
					"message": "船员薪水不足，进入负债状态！请补充星币。",
					"debt": crew_member.get("debt", 0)
				})
				break
