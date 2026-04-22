extends Node

# 客户端主控制器 - 处理所有服务端消息，协调 UI 更新

@onready var network: NetworkClient = $NetworkClient
@onready var game_state: GameState = $GameState
@onready var ui: CanvasLayer = $UI

# Ping 心跳（每30秒）
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
	# 尝试自动登录（从本地存储读取）
	var saved_user = _load_saved_credentials()
	if saved_user.size() > 0:
		network.send_login(saved_user["username"], saved_user["password"])
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
			ui.handle_action_result(data)
		"error":
			ui.show_error(data.get("message", "未知错误"))
		"pong":
			pass  # 心跳响应

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

# 操作接口（供 UI 调用）
func action_depart(target_poi: String) -> void:
	network.send_action("depart", {"target_poi": target_poi})

func action_dock() -> void:
	network.send_action("dock")

func action_equip(component_id: String, slot: String) -> void:
	network.send_action("equip", {"component_id": component_id, "slot": slot})

func action_unequip(component_id: String) -> void:
	network.send_action("unequip", {"component_id": component_id})

func action_accept_mission(mission_id: String, deadline_hours: float) -> void:
	network.send_action("accept_mission", {"mission_id": mission_id, "deadline_hours": deadline_hours})

func action_buy_fuel(amount: int) -> void:
	network.send_action("buy_fuel", {"amount": amount})

func action_connect_grid() -> void:
	network.send_action("connect_grid")

func action_sos() -> void:
	network.send_action("sos")

func login(username: String, password: String) -> void:
	_save_credentials(username, password)
	network.send_login(username, password)

func _save_credentials(username: String, password: String) -> void:
	var config = ConfigFile.new()
	config.set_value("auth", "username", username)
	config.set_value("auth", "password", password)
	config.save("user://credentials.cfg")

func _load_saved_credentials() -> Dictionary:
	var config = ConfigFile.new()
	if config.load("user://credentials.cfg") != OK:
		return {}
	return {
		"username": config.get_value("auth", "username", ""),
		"password": config.get_value("auth", "password", "")
	}
