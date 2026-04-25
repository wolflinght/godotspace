class_name ClientMain
extends Node

@onready var network: NetworkClient = $NetworkClient
@onready var game_state: GameState = $GameState
@onready var ui: UI = $UI

var _ping_timer: float = 0.0
const PING_INTERVAL = 30.0

func _ready() -> void:
	network.connected.connect(_on_connected)
	network.disconnected.connect(_on_disconnected)
	network.message_received.connect(_on_message_received)

func _process(delta: float) -> void:
	if network.is_connected_to_server():
		_ping_timer += delta
		if _ping_timer >= PING_INTERVAL:
			_ping_timer = 0.0
			network.send_ping()

func _on_connected() -> void:
	var saved = _load_saved_credentials()
	if saved.size() > 0:
		network.send_login(saved["username"], saved["password_raw"])
	else:
		ui.show_login_screen()

func _on_disconnected() -> void:
	ui.show_connecting_screen()

func _on_message_received(data: Dictionary) -> void:
	var msg_type: String = data.get("type", "")
	match msg_type:
		"state_snapshot":
			game_state.apply_snapshot(data.get("payload", {}))
			ui.show_main_screen()
		"state_update":
			game_state.apply_state_update(data.get("payload", {}))
			ui.update_ship_status()
		"event":
			var event_name = data.get("event", "")
			var payload = data.get("payload", {})
			game_state.apply_event(event_name, payload)
			_handle_event(event_name, payload)
		"action_result":
			if not data.get("success", true):
				ui.show_error(data.get("message", "操作失败"))
			else:
				_apply_action_result(data)
			ui.handle_action_result(data)
		"error":
			var msg = data.get("message", "未知错误")
			# 登录失败时通知登录界面
			var login_screen = ui.get_node_or_null("LoginScreen")
			if login_screen and login_screen.visible:
				login_screen.show_error(msg)
			else:
				ui.show_error(msg)
		"pong":
			pass

func _apply_action_result(data: Dictionary) -> void:
	# 将 action_result 中的增量数据同步到 GameState，避免重新登录才刷新
	var action = data.get("action", "")
	match action:
		"recruit":
			var new_crew = data.get("crew", {})
			if not new_crew.is_empty():
				game_state.crew.append(new_crew)
				game_state.ship["credits"] = game_state.ship.get("credits", 0) - data.get("cost", 0)
				game_state.state_updated.emit()
		"fire_crew":
			var role = data.get("role", "")
			game_state.crew = game_state.crew.filter(func(c): return c.get("slot") != role)
			game_state.state_updated.emit()
		"buy_fuel":
			var p = data.get("payload", {})
			if p.has("power"):
				game_state.ship["power"] = p["power"]
			if p.has("credits"):
				game_state.ship["credits"] = p["credits"]
			game_state.state_updated.emit()
		"accept_mission":
			var mid = data.get("mission_id", "")
			var deadline = data.get("deadline", 0.0)
			if mid != "":
				# 更新或添加到本地任务列表
				var found = false
				for m in game_state.missions:
					if m.get("mission_id") == mid:
						m["status"] = "active"
						m["deadline"] = deadline
						m["progress"] = 0
						found = true
						break
				if not found:
					game_state.missions.append({"mission_id": mid, "status": "active", "deadline": deadline, "progress": 0})
				game_state.state_updated.emit()

func _handle_event(event_name: String, payload: Dictionary) -> void:
	match event_name:
		"encounter":
			ui.show_combat_log(payload)
		"arrival":
			ui.show_arrival_notification(payload.get("poi", ""))
		"stranded":
			ui.show_stranded_alert()
		"global_event":
			ui.show_global_event(payload)
		"mission_completed":
			var mid = payload.get("mission_id", "")
			var reward = payload.get("reward", 0)
			game_state.apply_mission_status(mid, "completed")
			ui.show_mission_notification("任务完成：%s  +%d ★" % [mid, reward], false)
		"mission_failed":
			var mid = payload.get("mission_id", "")
			var penalty = payload.get("penalty", 0)
			game_state.apply_mission_status(mid, "failed")
			var msg = "任务失败：%s" % mid
			if penalty > 0:
				msg += "  违约金 -%d ★" % penalty
			ui.show_mission_notification(msg, true)
		"salary_warning":
			ui.show_mission_notification(payload.get("message", "薪水不足！"), true)
		"poi_depleted":
			ui.show_mission_notification(payload.get("message", "资源枯竭"), true)
		"sos_distress":
			ui.show_mission_notification(payload.get("message", ""), false)
		"slot_broken":
			ui.show_mission_notification(payload.get("message", "骨架受损！"), true)
		"crew_banter":
			ui.show_crew_banter(payload.get("log", ""))

# 操作接口
func login(username: String, password: String) -> void:
	_save_credentials(username, password)
	network.send_login(username, password)

func register(username: String, password: String) -> void:
	network.send({"type": "register", "username": username, "password": password.sha256_text()})

func action_depart(target_poi: String) -> void:
	network.send_action("depart", {"target_poi": target_poi})

func action_dock() -> void:
	network.send_action("dock")

func action_buy_fuel(amount: int) -> void:
	network.send_action("buy_fuel", {"amount": amount})

func action_equip(component_id: String, slot: String) -> void:
	network.send_action("equip", {"component_id": component_id, "slot": slot})

func action_unequip(component_id: String) -> void:
	network.send_action("unequip", {"component_id": component_id})

func action_accept_mission(mission_id: String, deadline_hours: float) -> void:
	network.send_action("accept_mission", {"mission_id": mission_id, "deadline_hours": deadline_hours})

func action_recruit(role: String, tier: String) -> void:
	network.send_action("recruit", {"role": role, "tier": tier})

func action_fire_crew(role: String) -> void:
	network.send_action("fire_crew", {"role": role})

func action_connect_grid() -> void:
	network.send_action("connect_grid")

func action_sos() -> void:
	network.send_action("sos")

func _save_credentials(username: String, password: String) -> void:
	var config = ConfigFile.new()
	config.set_value("auth", "username", username)
	config.set_value("auth", "password_raw", password)
	config.save("user://credentials.cfg")

func _load_saved_credentials() -> Dictionary:
	var config = ConfigFile.new()
	if config.load("user://credentials.cfg") != OK:
		return {}
	return {
		"username": config.get_value("auth", "username", ""),
		"password_raw": config.get_value("auth", "password_raw", "")
	}
