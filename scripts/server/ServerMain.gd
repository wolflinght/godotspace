class_name ServerMain
extends Node

# 星河放置：暗面危机 - 服务端主节点
# 运行方式: godot --headless --path /server/godot_server res://scenes/server/ServerMain.tscn

const PORT = 7777
const TICK_INTERVAL = 1.0

var _tcp_server: TCPServer
var _db: DatabaseManager
var _gemini: GeminiClient
var _tick_timer: float = 0.0
var _minute_timer: float = 0.0
var _last_boss_day: int = -1   # 防止同一天重复触发
var _banter_timer: float = 0.0
const BANTER_INTERVAL = 1200.0  # 20分钟触发一次船员对话
# peer_id(int) -> {ws: WebSocketPeer, player: Dictionary}
var _clients: Dictionary = {}
var _next_id: int = 1

func _ready() -> void:
	print("[Server] 星河放置服务端启动中...")

	_gemini = GeminiClient.new()
	add_child(_gemini)

	_db = DatabaseManager.new()
	add_child(_db)
	if not _db.connect_db():
		push_error("[Server] 数据库连接失败")
		get_tree().quit(1)
		return

	_tcp_server = TCPServer.new()
	var err = _tcp_server.listen(PORT)
	if err != OK:
		push_error("[Server] 端口监听失败: %d" % err)
		get_tree().quit(1)
		return

	# 连接定时器
	var daily_timer = get_node_or_null("DailyResetTimer")
	if daily_timer:
		daily_timer.timeout.connect(_check_daily_reset)
	var salary_timer = get_node_or_null("SalaryTimer")
	if salary_timer:
		salary_timer.timeout.connect(_deduct_salaries)

	print("[Server] WebSocket 服务器监听端口 %d" % PORT)
	print("[Server] 服务端就绪，等待玩家连接...")

func _process(delta: float) -> void:
	if _tcp_server == null:
		return

	# 接受新连接
	while _tcp_server.is_connection_available():
		var tcp = _tcp_server.take_connection()
		var ws = WebSocketPeer.new()
		ws.accept_stream(tcp)
		var peer_id = _next_id
		_next_id += 1
		_clients[peer_id] = {"ws": ws, "player": null}
		print("[Server] 新连接 peer_id=%d" % peer_id)

	# 轮询所有客户端
	var to_remove = []
	for peer_id in _clients.keys():
		var entry = _clients[peer_id]
		var ws: WebSocketPeer = entry["ws"]
		ws.poll()
		var state = ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			while ws.get_available_packet_count() > 0:
				var pkt = ws.get_packet()
				var json_str = pkt.get_string_from_utf8()
				var data = JSON.parse_string(json_str)
				if data != null:
					_handle_client_message(peer_id, data)
		elif state == WebSocketPeer.STATE_CLOSED:
			to_remove.append(peer_id)

	for peer_id in to_remove:
		_on_peer_disconnected(peer_id)

	# Tick
	_tick_timer += delta
	if _tick_timer >= TICK_INTERVAL:
		_tick_timer -= TICK_INTERVAL
		_server_tick()

	# 每分钟检查一次定时事件（Boss / 资源重置）
	_minute_timer += delta
	if _minute_timer >= 60.0:
		_minute_timer -= 60.0
		_check_timed_events()

	# 每20分钟触发在线玩家的航行船员对话
	_banter_timer += delta
	if _banter_timer >= BANTER_INTERVAL:
		_banter_timer = 0.0
		_trigger_crew_banter()

func _server_tick() -> void:
	var now = Time.get_unix_time_from_system()
	for peer_id in _clients.keys():
		var entry = _clients[peer_id]
		var player = entry.get("player")
		if player == null:
			continue
		_process_player_tick(peer_id, player, now)

func _process_player_tick(peer_id: int, player: Dictionary, now: float) -> void:
	# 任务超时检查
	var timeout_events = MissionManager.check_timeouts(player, _db)
	for ev in timeout_events:
		_push_event(peer_id, "mission_failed", {"mission_id": ev["mission_id"], "penalty": ev["penalty"]})

	var ship = player.get("ship", {})
	match ship.get("status", "docked"):
		"in_transit": _tick_transit(peer_id, player, ship, now)
		"working":    _tick_working(peer_id, player, ship, now)
		"docked":     _tick_docked(peer_id, player, ship, now)

func _tick_docked(_peer_id: int, _player: Dictionary, ship: Dictionary, now: float) -> void:
	if not ship.get("grid_connected", false):
		return
	if not ActionHandler.POI_INFO.get(ship.get("current_poi", ""), {}).get("is_station", false):
		ship["grid_connected"] = false
		_db.save_ship(ship)
		return
	# 电网充电：10 电力/分钟
	var last = ship.get("last_grid_tick", now)
	ship["last_grid_tick"] = now
	var elapsed_min = (now - last) / 60.0
	var gain = int(elapsed_min * 10.0)
	if gain > 0:
		ship["power"] = min(ship.get("max_power", 500), ship.get("power", 0) + gain)
		_db.save_ship(ship)

func _tick_transit(peer_id: int, player: Dictionary, ship: Dictionary, now: float) -> void:
	var depart_time: float = ship.get("depart_time", now)
	var eta: float = ship.get("eta", now)
	var total_minutes: float = (eta - depart_time) / 60.0
	var total_cost: int = ship.get("total_power_cost", 0)

	if total_minutes > 0 and total_cost > 0:
		var elapsed_min = (now - depart_time) / 60.0
		var expected_used = roundi(elapsed_min * (float(total_cost) / total_minutes))
		var already_used = ship.get("power_used_so_far", 0)
		var drain = expected_used - already_used
		if drain > 0:
			ship["power"] = max(0, ship.get("power", 0) - drain)
			ship["power_used_so_far"] = expected_used
			if ship["power"] <= 0:
				_handle_stranded(peer_id, player, ship)
				return

	if now >= eta:
		_handle_arrival(peer_id, player, ship)
		return

	_check_encounter(peer_id, player, ship, now)

	var last_push = ship.get("last_state_push", 0.0)
	if now - last_push >= 10.0:
		ship["last_state_push"] = now
		_push_state_update(peer_id, ship)
		_db.save_ship(ship)

func _tick_working(peer_id: int, player: Dictionary, ship: Dictionary, now: float) -> void:
	var last = ship.get("last_work_tick", now)
	ship["last_work_tick"] = now
	var elapsed_h = (now - last) / 3600.0
	if elapsed_h <= 0:
		return
	var rate: float = ship.get("mining_rate", 0.0)
	var gain = rate * elapsed_h
	if gain <= 0:
		return
	var poi_id = ship.get("current_poi", "")
	var res_type = ship.get("mining_resource", "钛")
	var actual = _db.consume_poi_resource(poi_id, res_type, gain)
	if actual > 0:
		_db.add_player_resource(player.get("player_id", 0), res_type, actual)
		player["resources"][res_type] = player["resources"].get(res_type, 0.0) + actual
		# 检查采矿任务进度
		var mine_events = MissionManager.check_mining_progress(player, res_type, actual, _db)
		for ev in mine_events:
			_push_event(peer_id, "mission_completed", ev)
		_db.save_ship(ship)
	elif actual == 0:
		_push_event(peer_id, "poi_depleted", {"poi": poi_id, "message": "本星区资源已枯竭"})
		_db.save_ship(ship)

func _handle_stranded(peer_id: int, _player: Dictionary, ship: Dictionary) -> void:
	ship["status"] = "stranded"
	_push_event(peer_id, "stranded", {"message": "电力耗尽！飞船进入抛锚状态！"})
	_db.save_ship(ship)

func _handle_arrival(peer_id: int, player: Dictionary, ship: Dictionary) -> void:
	ship["status"] = "working"
	ship["current_poi"] = ship.get("target_poi", "")
	ship["target_poi"] = ""
	ship["last_work_tick"] = Time.get_unix_time_from_system()
	_push_event(peer_id, "arrival", {"poi": ship["current_poi"]})
	_db.save_ship(ship)
	var arrival_events = MissionManager.check_arrival(player, ship, _db)
	for ev in arrival_events:
		if ev["type"] == "completed":
			_push_event(peer_id, "mission_completed", {"mission_id": ev["mission_id"], "reward": ev["reward"]})
		else:
			_push_event(peer_id, "mission_failed", {"mission_id": ev["mission_id"], "penalty": ev["penalty"]})

func _check_encounter(peer_id: int, player: Dictionary, ship: Dictionary, now: float) -> void:
	var depart_time: float = ship.get("depart_time", now)
	var eta: float = ship.get("eta", now)
	var total_dist: float = ship.get("travel_distance", 0.0)
	if total_dist <= 0 or eta <= depart_time:
		return
	var progress = (now - depart_time) / (eta - depart_time)
	var cur_dist = progress * total_dist
	var last_dist: float = ship.get("last_encounter_dist", 0.0)
	var segs = int(cur_dist / 10.0)
	var last_segs = int(last_dist / 10.0)
	if segs <= last_segs:
		return
	ship["last_encounter_dist"] = float(segs * 10)
	var danger: int = ship.get("target_danger", 0)
	var chance = [0.05, 0.10, 0.15, 0.20, 0.25, 0.30][clampi(danger, 0, 5)]
	if randf() < chance:
		_trigger_encounter(peer_id, player, ship)

func _trigger_encounter(peer_id: int, player: Dictionary, ship: Dictionary) -> void:
	var danger: int = ship.get("target_danger", 0)
	var result = CombatSystem.resolve(player, ship, danger)
	if result["player_wins"]:
		var credits = result["credits_gained"]
		# 资本家特性：遭遇战星币+30%
		if ActionHandler._has_trait(player, "captain_t3_capitalist"):
			credits = int(credits * 1.30)
		ship["credits"] = ship.get("credits", 0) + credits
		result["credits_gained"] = credits
		_db.add_credits(player.get("player_id", 0), credits)
		var kill_events = MissionManager.check_kill(player, result["enemy_name"], 1, _db)
		for ev in kill_events:
			_push_event(peer_id, "mission_completed", {"mission_id": ev["mission_id"], "reward": ev["reward"]})
	else:
		ship["hp"] = max(0, ship.get("hp", 1000) - result["hull_damage"])
		ship["status"] = "docked"
		var nearest = ActionHandler._get_nearest_station(ship.get("current_poi", "CYG-SS-01"))
		ship["current_poi"] = nearest
		ship["target_poi"] = ""
		_apply_slot_damage(peer_id, ship, result.get("slot_damage", {}))
		_db.save_ship(ship)
		var defeat_events = MissionManager.check_defeat_missions(player, _db)
		for ev in defeat_events:
			_push_event(peer_id, "mission_failed", {"mission_id": ev["mission_id"], "penalty": ev["penalty"]})
	_push_event(peer_id, "encounter", {
		"result": "victory" if result["player_wins"] else "defeat",
		"enemy": result["enemy_name"],
		"credits_gained": result["credits_gained"],
		"combat_log": result["log"],
		"ejected_to": ship.get("current_poi", "")
	})

func _on_peer_disconnected(peer_id: int) -> void:
	print("[Server] 断开连接: peer_id=%d" % peer_id)
	var entry = _clients.get(peer_id, {})
	var player = entry.get("player")
	if player != null:
		_db.save_player_state(player)
	_clients.erase(peer_id)

func _handle_client_message(peer_id: int, data: Dictionary) -> void:
	match data.get("type", ""):
		"login":    _handle_login(peer_id, data)
		"register": _handle_register(peer_id, data)
		"action":   _handle_action(peer_id, data)
		"ping":     _send_to_peer(peer_id, {"type": "pong"})

func _handle_login(peer_id: int, data: Dictionary) -> void:
	var username = data.get("username", "")
	var password = data.get("password", "")
	var player = _db.authenticate_player(username, password)
	if player.is_empty():
		_send_to_peer(peer_id, {"type": "error", "message": "用户名或密码错误"})
		return
	_clients[peer_id]["player"] = player
	print("[Server] 玩家 %s 登录 (peer_id=%d)" % [username, peer_id])
	_send_to_peer(peer_id, {"type": "state_snapshot", "payload": player})

func _handle_register(peer_id: int, data: Dictionary) -> void:
	var username = data.get("username", "")
	var password = data.get("password", "")
	if username.length() < 2 or username.length() > 20:
		_send_to_peer(peer_id, {"type": "error", "message": "用户名长度需 2-20 个字符"})
		return
	var player = _db.register_player(username, password)
	if player.is_empty():
		_send_to_peer(peer_id, {"type": "error", "message": "用户名已存在"})
		return
	_clients[peer_id]["player"] = player
	print("[Server] 新玩家注册: %s (peer_id=%d)" % [username, peer_id])
	_send_to_peer(peer_id, {"type": "state_snapshot", "payload": player})

func _handle_action(peer_id: int, data: Dictionary) -> void:
	var entry = _clients.get(peer_id, {})
	var player = entry.get("player")
	if player == null:
		_send_to_peer(peer_id, {"type": "error", "message": "请先登录"})
		return
	var action = data.get("action", "")
	var payload = data.get("payload", {})
	match action:
		"depart":        ActionHandler.handle_depart(peer_id, player, payload, _db, self)
		"dock":          ActionHandler.handle_dock(peer_id, player, payload, _db, self)
		"equip":         ActionHandler.handle_equip(peer_id, player, payload, _db, self)
		"unequip":       ActionHandler.handle_unequip(peer_id, player, payload, _db, self)
		"accept_mission":ActionHandler.handle_accept_mission(peer_id, player, payload, _db, self)
		"buy_fuel":      ActionHandler.handle_buy_fuel(peer_id, player, payload, _db, self)
		"connect_grid":  ActionHandler.handle_connect_grid(peer_id, player, payload, _db, self)
		"sos":           ActionHandler.handle_sos(peer_id, player, payload, _db, self)
		"recruit":       ActionHandler.handle_recruit(peer_id, player, payload, _db, self)
		"fire_crew":     ActionHandler.handle_fire_crew(peer_id, player, payload, _db, self)
		_: _send_to_peer(peer_id, {"type": "error", "message": "未知操作: " + action})

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
			"hp": ship.get("hp", 1000),
			"shield": ship.get("shield", 0),
			"credits": ship.get("credits", 0)
		}
	})

func _push_event(peer_id: int, event_name: String, payload: Dictionary) -> void:
	_send_to_peer(peer_id, {"type": "event", "event": event_name, "payload": payload})

func get_gemini() -> GeminiClient:
	return _gemini

func send_to_peer(peer_id: int, data: Dictionary) -> void:
	_send_to_peer(peer_id, data)

# 广播事件给所有在线玩家（exclude_peer_id=-1 表示全部，否则跳过该 peer）
func _apply_slot_damage(peer_id: int, ship: Dictionary, slot_damage: Dictionary) -> void:
	if slot_damage.is_empty():
		return
	var slot_hp: Dictionary = ship.get("slot_hp", {})
	var broken_slots = []
	for slot in slot_damage.keys():
		var dmg = slot_damage[slot]
		var current = slot_hp.get(slot, 1000)
		slot_hp[slot] = max(0, current - dmg)
		if slot_hp[slot] == 0 and current > 0:
			broken_slots.append(slot)
	ship["slot_hp"] = slot_hp
	if broken_slots.size() > 0:
		_push_event(peer_id, "slot_broken", {
			"slots": broken_slots,
			"message": "骨架受损！槽位 [%s] 结构归零，相关组件已失效！" % ", ".join(broken_slots)
		})

func broadcast_event(event_name: String, payload: Dictionary, exclude_peer_id: int = -1) -> void:
	for pid in _clients.keys():
		if pid == exclude_peer_id:
			continue
		_push_event(pid, event_name, payload)

func _send_to_peer(peer_id: int, data: Dictionary) -> void:
	var entry = _clients.get(peer_id)
	if entry == null:
		return
	var ws: WebSocketPeer = entry["ws"]
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(data))

func _check_timed_events() -> void:
	var now = Time.get_datetime_dict_from_system()
	var today = now.day

	# 00:00 资源重置
	if now.hour == 0 and now.minute == 0:
		_db.reset_all_poi_resources()
		for peer_id in _clients.keys():
			_push_event(peer_id, "global_event", {"message": "宇宙引力潮汐爆发！所有星区资源储量已恢复！"})

	# 20:00 全服 Boss 防守事件（每天只触发一次）
	if now.hour == 20 and now.minute == 0 and _last_boss_day != today:
		_last_boss_day = today
		_trigger_global_boss_event()

func _check_daily_reset() -> void:
	pass  # 已合并至 _check_timed_events

func _trigger_global_boss_event() -> void:
	print("[Server] 全服 Boss 防守事件触发！")
	# 广播预警
	for peer_id in _clients.keys():
		_push_event(peer_id, "global_event", {
			"message": "⚠ 月之暗面大规模入侵！全星系进入紧急防御状态！",
			"event_type": "boss_warning"
		})

	# 对所有在线且处于停泊/作业中状态的玩家触发一次强制 Boss 遭遇
	for peer_id in _clients.keys():
		var entry = _clients[peer_id]
		var player = entry.get("player")
		if player == null:
			continue
		var ship = player.get("ship", {})
		var status = ship.get("status", "")
		# 仅对停泊/作业中玩家触发（航行中不打扰）
		if status != "docked" and status != "working":
			continue
		# Boss 固定为最高危险度 5
		var result = CombatSystem.resolve(player, ship, 5)
		var credits = result["credits_gained"]
		if result["player_wins"]:
			if ActionHandler._has_trait(player, "captain_t3_capitalist"):
				credits = int(credits * 1.30)
			ship["credits"] = ship.get("credits", 0) + credits
			_db.add_credits(player.get("player_id", 0), credits)
		else:
			ship["hp"] = max(0, ship.get("hp", 1000) - result["hull_damage"])
			var nearest = ActionHandler._get_nearest_station(ship.get("current_poi", "CYG-SS-01"))
			ship["status"] = "docked"
			ship["current_poi"] = nearest
			ship["target_poi"] = ""
			_db.save_ship(ship)
		_push_event(peer_id, "encounter", {
			"result": "victory" if result["player_wins"] else "defeat",
			"enemy": result["enemy_name"],
			"credits_gained": credits,
			"combat_log": result["log"],
			"ejected_to": ship.get("current_poi", ""),
			"is_boss_event": true
		})

	# Boss 战后 AI 终局真相播报
	var boss_names = ["吞星者·机械利维坦", "虚空腐化体·奥米伽", "暗面枢机·毁灭之核"]
	var boss_name = boss_names[randi() % boss_names.size()]
	_gemini.generate_boss_truth(boss_name, func(text):
		if text != null and text != "":
			for pid in _clients.keys():
				_push_event(pid, "global_event", {
					"message": "【奇点圣约·太虚监察者】" + text,
					"event_type": "boss_truth"
				})
	)

func _trigger_crew_banter() -> void:
	for peer_id in _clients.keys():
		var entry = _clients[peer_id]
		var player = entry.get("player")
		if player == null:
			continue
		var ship = player.get("ship", {})
		if ship.get("status", "") != "in_transit":
			continue
		var crew = player.get("crew", [])
		if crew.size() < 2:
			continue
		_gemini.generate_banter(ship, crew, func(data):
			if data == null:
				return
			var lines = []
			if data is Dictionary:
				lines = data.get("lines", [])
			elif data is String:
				lines = [{"speaker": "通讯频道", "dialog": data}]
			if lines.size() > 0:
				var log_text = ""
				for line in lines:
					log_text += "[%s]：%s\n" % [line.get("speaker","?"), line.get("dialog","")]
				_push_event(peer_id, "crew_banter", {"log": log_text.strip_edges()})
		)

func _deduct_salaries() -> void:
	_db.deduct_crew_salaries()
	for peer_id in _clients.keys():
		var player = _clients[peer_id].get("player")
		if player == null:
			continue
		for crew_member in player.get("crew", []):
			if crew_member.get("debt", 0) > 0:
				_push_event(peer_id, "salary_warning", {"message": "船员薪水不足，进入负债状态！"})
				break
